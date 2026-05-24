package scrapers

import (
	"compress/gzip"
	"context"
	"fmt"
	"io"
	"log"
	"math"
	"math/rand"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"HUANG/backend/internal/observability"
)

type Options struct {
	Timeout int

	RetryCount     int
	RetryBaseDelay time.Duration

	MinDelay time.Duration
	MaxDelay time.Duration

	PerDomainRPS   float64
	PerDomainBurst int

	FailureThreshold int
	Cooldown         time.Duration
	RespectRobots    bool
}

type runtimeOptions struct {
	timeout int

	retryCount     int
	retryBaseDelay time.Duration

	minDelay time.Duration
	maxDelay time.Duration

	perDomainRPS   float64
	perDomainBurst int

	failureThreshold int
	cooldown         time.Duration
	respectRobots    bool
}

var (
	optionsMu sync.RWMutex
	opts      = runtimeOptions{
		timeout:          15,
		retryCount:       1,
		retryBaseDelay:   250 * time.Millisecond,
		minDelay:         120 * time.Millisecond,
		maxDelay:         350 * time.Millisecond,
		perDomainRPS:     4,
		perDomainBurst:   8,
		failureThreshold: 6,
		cooldown:         2 * time.Minute,
		respectRobots:    false,
	}
)

var SharedClient = &http.Client{
	Timeout: 15 * time.Second,
}

type tokenBucket struct {
	rate   float64
	burst  float64
	tokens float64
	last   time.Time
}

type domainState struct {
	bucket    *tokenBucket
	failures  int
	openUntil time.Time
}

var (
	domainMu    sync.Mutex
	domainStats = make(map[string]*domainState)

	robotsMu    sync.Mutex
	robotsCache = make(map[string]robotsRules)

	rndMu sync.Mutex
	rnd   = rand.New(rand.NewSource(time.Now().UnixNano()))
)

type SiteHealth struct {
	Domain              string    `json:"domain"`
	State               string    `json:"state"`
	OpenUntil           time.Time `json:"open_until,omitempty"`
	ConsecutiveFailures int       `json:"consecutive_failures"`
}

type robotsRules struct {
	fetchedAt time.Time
	allow     []string
	disallow  []string
}

var userAgents = []string{
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36",
	"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36",
	"Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36",
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:139.0) Gecko/20100101 Firefox/139.0",
	"Mozilla/5.0 (Macintosh; Intel Mac OS X 14.6; rv:139.0) Gecko/20100101 Firefox/139.0",
}

func Configure(input Options) {
	optionsMu.Lock()
	defer optionsMu.Unlock()

	if input.Timeout > 0 {
		opts.timeout = input.Timeout
	}
	if input.RetryCount >= 0 {
		opts.retryCount = input.RetryCount
	}
	if input.RetryBaseDelay > 0 {
		opts.retryBaseDelay = input.RetryBaseDelay
	}
	if input.MinDelay >= 0 {
		opts.minDelay = input.MinDelay
	}
	if input.MaxDelay >= 0 {
		opts.maxDelay = input.MaxDelay
	}
	if input.PerDomainRPS > 0 {
		opts.perDomainRPS = input.PerDomainRPS
	}
	if input.PerDomainBurst > 0 {
		opts.perDomainBurst = input.PerDomainBurst
	}
	if input.FailureThreshold > 0 {
		opts.failureThreshold = input.FailureThreshold
	}
	if input.Cooldown > 0 {
		opts.cooldown = input.Cooldown
	}
	opts.respectRobots = input.RespectRobots

	SharedClient.Timeout = time.Duration(opts.timeout) * time.Second
}

func CommonHeaders(req *http.Request, referer string) {
	req.Header.Set("User-Agent", randomUserAgent())
	req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
	req.Header.Set("Accept-Language", "en-US,en;q=0.8")
	req.Header.Set("Connection", "keep-alive")
	if referer != "" {
		req.Header.Set("Referer", referer)
	}
}

func AjaxHeaders(req *http.Request, referer string) {
	CommonHeaders(req, referer)
	req.Header.Set("X-Requested-With", "XMLHttpRequest")
	req.Header.Set("Accept", "application/json, text/javascript, */*; q=0.01")
}

func FetchHTML(targetURL string, referer string) ([]byte, error) {
	return doRequest("GET", targetURL, referer, "", false, "")
}

func FetchAjax(targetURL string, referer string) ([]byte, error) {
	return doRequest("GET", targetURL, referer, "", true, "")
}

func FetchAjaxPost(targetURL, referer, body string) ([]byte, error) {
	return doRequest("POST", targetURL, referer, body, true, "application/x-www-form-urlencoded")
}

func FetchAPI(targetURL, referer string) ([]byte, error) {
	return doRequest("GET", targetURL, referer, "", false, "application/json")
}

func doRequest(method, rawURL, referer, body string, ajax bool, acceptOverride string) ([]byte, error) {
	current := getOptions()
	totalAttempts := current.retryCount + 1
	if totalAttempts < 1 {
		totalAttempts = 1
	}

	parsedURL, err := url.Parse(rawURL)
	if err != nil {
		return nil, err
	}
	domain := parsedURL.Hostname()
	if domain == "" {
		return nil, fmt.Errorf("invalid host in url: %s", rawURL)
	}
	if current.respectRobots {
		allowed, err := allowedByRobots(parsedURL)
		if err == nil && !allowed {
			return nil, fmt.Errorf("blocked by robots.txt: %s", rawURL)
		}
	}

	var lastErr error
	for attempt := 0; attempt < totalAttempts; attempt++ {
		start := time.Now()

		if err := waitForDomainSlot(domain, current); err != nil {
			observability.ObserveScrape(domain, false, time.Since(start))
			return nil, err
		}

		if err := applyRandomDelay(current.minDelay, current.maxDelay); err != nil {
			observability.ObserveScrape(domain, false, time.Since(start))
			return nil, err
		}

		ctx, cancel := context.WithTimeout(context.Background(), time.Duration(current.timeout)*time.Second)
		req, err := http.NewRequestWithContext(ctx, method, rawURL, strings.NewReader(body))
		if err != nil {
			cancel()
			observability.ObserveScrape(domain, false, time.Since(start))
			return nil, err
		}

		if ajax {
			AjaxHeaders(req, referer)
		} else {
			CommonHeaders(req, referer)
		}
		if acceptOverride != "" {
			req.Header.Set("Accept", acceptOverride)
		}
		req.Header.Set("Accept-Encoding", "identity")
		if body != "" && req.Header.Get("Content-Type") == "" {
			req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
		}

		resp, err := SharedClient.Do(req)
		if err != nil {
			cancel()
			lastErr = err
			registerFailure(domain, current)
			observability.ObserveScrape(domain, false, time.Since(start))
			if attempt < totalAttempts-1 {
				sleepBackoff(attempt, current.retryBaseDelay)
				continue
			}
			return nil, err
		}

		if resp.StatusCode < 200 || resp.StatusCode >= 300 {
			lastErr = fmt.Errorf("upstream status %d for %s", resp.StatusCode, rawURL)
			_ = resp.Body.Close()
			cancel()

			retryable := resp.StatusCode == http.StatusTooManyRequests || resp.StatusCode >= 500
			registerFailure(domain, current)
			observability.ObserveScrape(domain, false, time.Since(start))
			if retryable && attempt < totalAttempts-1 {
				sleepBackoff(attempt, current.retryBaseDelay)
				continue
			}
			return nil, lastErr
		}

		data, err := readBody(resp)
		cancel()
		if err != nil {
			lastErr = err
			registerFailure(domain, current)
			observability.ObserveScrape(domain, false, time.Since(start))
			if attempt < totalAttempts-1 {
				sleepBackoff(attempt, current.retryBaseDelay)
				continue
			}
			return nil, err
		}

		registerSuccess(domain)
		observability.ObserveScrape(domain, true, time.Since(start))
		return data, nil
	}

	if lastErr == nil {
		lastErr = fmt.Errorf("request failed: %s", rawURL)
	}
	return nil, lastErr
}

func readBody(resp *http.Response) ([]byte, error) {
	defer resp.Body.Close()

	var reader io.Reader = resp.Body
	if resp.Header.Get("Content-Encoding") == "gzip" {
		gzReader, err := gzip.NewReader(resp.Body)
		if err != nil {
			return nil, err
		}
		defer gzReader.Close()
		reader = gzReader
	}
	return io.ReadAll(reader)
}

func waitForDomainSlot(domain string, current runtimeOptions) error {
	now := time.Now()

	domainMu.Lock()
	state := domainStats[domain]
	if state == nil {
		state = &domainState{
			bucket: &tokenBucket{
				rate:   current.perDomainRPS,
				burst:  float64(current.perDomainBurst),
				tokens: float64(current.perDomainBurst),
				last:   now,
			},
		}
		domainStats[domain] = state
	}

	if now.Before(state.openUntil) {
		openUntil := state.openUntil
		domainMu.Unlock()
		observability.SetSiteState(domain, "open")
		return fmt.Errorf("site temporarily disabled due to repeated failures until %s", openUntil.Format(time.RFC3339))
	}

	wait := state.bucket.reserve(now)
	domainMu.Unlock()

	if wait > 0 {
		time.Sleep(wait)
	}
	return nil
}

func (b *tokenBucket) reserve(now time.Time) time.Duration {
	if b.rate <= 0 {
		return 0
	}
	if b.burst <= 0 {
		b.burst = 1
	}

	elapsed := now.Sub(b.last).Seconds()
	if elapsed > 0 {
		b.tokens = math.Min(b.burst, b.tokens+elapsed*b.rate)
		b.last = now
	}
	if b.tokens >= 1 {
		b.tokens--
		return 0
	}

	shortage := 1 - b.tokens
	waitSeconds := shortage / b.rate
	b.tokens = 0
	b.last = now.Add(time.Duration(waitSeconds * float64(time.Second)))
	return time.Duration(waitSeconds * float64(time.Second))
}

func registerFailure(domain string, current runtimeOptions) {
	domainMu.Lock()
	defer domainMu.Unlock()

	state := domainStats[domain]
	if state == nil {
		return
	}
	state.failures++
	if state.failures >= current.failureThreshold {
		state.openUntil = time.Now().Add(current.cooldown)
		state.failures = 0
		log.Printf("site circuit opened for %s until %s", domain, state.openUntil.Format(time.RFC3339))
		observability.SetSiteState(domain, "open")
		return
	}
	observability.SetSiteState(domain, "closed")
}

func registerSuccess(domain string) {
	domainMu.Lock()
	defer domainMu.Unlock()

	state := domainStats[domain]
	if state == nil {
		return
	}
	state.failures = 0
	state.openUntil = time.Time{}
	observability.SetSiteState(domain, "closed")
}

func SiteHealthSnapshot() []SiteHealth {
	domainMu.Lock()
	defer domainMu.Unlock()

	now := time.Now()
	out := make([]SiteHealth, 0, len(domainStats))
	for domain, st := range domainStats {
		state := "closed"
		if now.Before(st.openUntil) {
			state = "open"
		}
		out = append(out, SiteHealth{
			Domain:              domain,
			State:               state,
			OpenUntil:           st.openUntil,
			ConsecutiveFailures: st.failures,
		})
	}
	return out
}

func sleepBackoff(attempt int, base time.Duration) {
	if base <= 0 {
		base = 200 * time.Millisecond
	}
	multiplier := math.Pow(2, float64(attempt))
	backoff := time.Duration(float64(base) * multiplier)
	jitter := randomDuration(0, base/2)
	time.Sleep(backoff + jitter)
}

func applyRandomDelay(minDelay, maxDelay time.Duration) error {
	if minDelay <= 0 && maxDelay <= 0 {
		return nil
	}
	delay := randomDuration(minDelay, maxDelay)
	if delay > 0 {
		time.Sleep(delay)
	}
	return nil
}

func randomDuration(minDelay, maxDelay time.Duration) time.Duration {
	if maxDelay < minDelay {
		maxDelay = minDelay
	}
	if maxDelay <= 0 {
		return 0
	}
	if minDelay < 0 {
		minDelay = 0
	}
	if minDelay == maxDelay {
		return minDelay
	}

	delta := maxDelay - minDelay
	rndMu.Lock()
	n := rnd.Int63n(int64(delta) + 1)
	rndMu.Unlock()
	return minDelay + time.Duration(n)
}

func randomUserAgent() string {
	if len(userAgents) == 0 {
		return "Mozilla/5.0"
	}
	rndMu.Lock()
	idx := rnd.Intn(len(userAgents))
	rndMu.Unlock()
	return userAgents[idx]
}

func getOptions() runtimeOptions {
	optionsMu.RLock()
	defer optionsMu.RUnlock()
	return opts
}

func allowedByRobots(target *url.URL) (bool, error) {
	host := strings.ToLower(target.Hostname())
	if host == "" {
		return false, fmt.Errorf("invalid host")
	}

	rules, err := getRobotsRules(target)
	if err != nil {
		return true, err
	}
	path := target.EscapedPath()
	if path == "" {
		path = "/"
	}

	longestAllow := ""
	longestDisallow := ""
	for _, allow := range rules.allow {
		if allow != "" && strings.HasPrefix(path, allow) && len(allow) > len(longestAllow) {
			longestAllow = allow
		}
	}
	for _, disallow := range rules.disallow {
		if disallow != "" && strings.HasPrefix(path, disallow) && len(disallow) > len(longestDisallow) {
			longestDisallow = disallow
		}
	}

	if longestDisallow == "" {
		return true, nil
	}
	if len(longestAllow) >= len(longestDisallow) {
		return true, nil
	}
	return false, nil
}

func getRobotsRules(target *url.URL) (robotsRules, error) {
	host := strings.ToLower(target.Hostname())
	now := time.Now()

	robotsMu.Lock()
	cached, ok := robotsCache[host]
	robotsMu.Unlock()
	if ok && now.Sub(cached.fetchedAt) < 6*time.Hour {
		return cached, nil
	}

	scheme := target.Scheme
	if scheme == "" {
		scheme = "https"
	}
	robotsURL := fmt.Sprintf("%s://%s/robots.txt", scheme, host)

	client := &http.Client{Timeout: 5 * time.Second}
	req, err := http.NewRequest(http.MethodGet, robotsURL, nil)
	if err != nil {
		return robotsRules{}, err
	}
	req.Header.Set("User-Agent", "HUANGBot/1.0 (+https://example.local)")

	resp, err := client.Do(req)
	if err != nil {
		return robotsRules{}, err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		r := robotsRules{fetchedAt: now}
		robotsMu.Lock()
		robotsCache[host] = r
		robotsMu.Unlock()
		return r, nil
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return robotsRules{}, err
	}
	rules := parseRobots(body)
	rules.fetchedAt = now

	robotsMu.Lock()
	robotsCache[host] = rules
	robotsMu.Unlock()

	return rules, nil
}

func parseRobots(body []byte) robotsRules {
	lines := strings.Split(string(body), "\n")
	var out robotsRules
	matchAll := false

	for _, raw := range lines {
		line := strings.TrimSpace(raw)
		if line == "" {
			continue
		}
		if idx := strings.Index(line, "#"); idx >= 0 {
			line = strings.TrimSpace(line[:idx])
		}
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, ":", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.ToLower(strings.TrimSpace(parts[0]))
		value := strings.TrimSpace(parts[1])
		switch key {
		case "user-agent":
			matchAll = value == "*"
		case "allow":
			if matchAll {
				out.allow = append(out.allow, value)
			}
		case "disallow":
			if matchAll && value != "" {
				out.disallow = append(out.disallow, value)
			}
		}
	}
	return out
}

func ExtractLastSegment(input string) string {
	input = strings.TrimRight(input, "/")
	parts := strings.Split(input, "/")
	if len(parts) == 0 {
		return input
	}
	return parts[len(parts)-1]
}

func CleanText(s string) string {
	s = strings.TrimSpace(s)
	s = strings.ReplaceAll(s, "\n", " ")
	s = strings.ReplaceAll(s, "\t", " ")
	for strings.Contains(s, "  ") {
		s = strings.ReplaceAll(s, "  ", " ")
	}
	return s
}

func AbsoluteURL(base, path string) string {
	if strings.HasPrefix(path, "http") {
		return path
	}
	base = strings.TrimRight(base, "/")
	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}
	return base + path
}
