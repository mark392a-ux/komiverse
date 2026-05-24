package observability

import (
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"
)

type metrics struct {
	mu sync.RWMutex

	httpCount       map[string]uint64
	httpLatencySum  map[string]float64
	httpLatencyHits map[string]uint64

	scrapeCount       map[string]uint64
	scrapeLatencySum  map[string]float64
	scrapeLatencyHits map[string]uint64

	siteState map[string]string

	cacheHit  uint64
	cacheMiss uint64
}

var globalMetrics = &metrics{
	httpCount:         make(map[string]uint64),
	httpLatencySum:    make(map[string]float64),
	httpLatencyHits:   make(map[string]uint64),
	scrapeCount:       make(map[string]uint64),
	scrapeLatencySum:  make(map[string]float64),
	scrapeLatencyHits: make(map[string]uint64),
	siteState:         make(map[string]string),
}

func ObserveHTTP(method, path string, status int, duration time.Duration) {
	key := fmt.Sprintf("%s|%s|%d", method, path, status)
	latKey := fmt.Sprintf("%s|%s", method, path)

	globalMetrics.mu.Lock()
	globalMetrics.httpCount[key]++
	globalMetrics.httpLatencySum[latKey] += duration.Seconds()
	globalMetrics.httpLatencyHits[latKey]++
	globalMetrics.mu.Unlock()
}

func ObserveScrape(domain string, success bool, duration time.Duration) {
	result := "failure"
	if success {
		result = "success"
	}
	key := fmt.Sprintf("%s|%s", domain, result)
	latKey := domain

	globalMetrics.mu.Lock()
	globalMetrics.scrapeCount[key]++
	globalMetrics.scrapeLatencySum[latKey] += duration.Seconds()
	globalMetrics.scrapeLatencyHits[latKey]++
	globalMetrics.mu.Unlock()
}

func SetSiteState(domain, state string) {
	globalMetrics.mu.Lock()
	globalMetrics.siteState[domain] = state
	globalMetrics.mu.Unlock()
}

func IncCacheHit() {
	globalMetrics.mu.Lock()
	globalMetrics.cacheHit++
	globalMetrics.mu.Unlock()
}

func IncCacheMiss() {
	globalMetrics.mu.Lock()
	globalMetrics.cacheMiss++
	globalMetrics.mu.Unlock()
}

func RenderPrometheus() string {
	globalMetrics.mu.RLock()
	defer globalMetrics.mu.RUnlock()

	var lines []string
	lines = append(lines,
		"# HELP huang_http_requests_total Total HTTP requests.",
		"# TYPE huang_http_requests_total counter",
	)
	for _, key := range sortedKeys(globalMetrics.httpCount) {
		parts := strings.Split(key, "|")
		if len(parts) != 3 {
			continue
		}
		lines = append(lines,
			fmt.Sprintf(
				`huang_http_requests_total{method=%q,path=%q,status=%q} %d`,
				escape(parts[0]), escape(parts[1]), escape(parts[2]),
				globalMetrics.httpCount[key],
			),
		)
	}

	lines = append(lines,
		"# HELP huang_http_request_duration_seconds_sum Sum of request durations.",
		"# TYPE huang_http_request_duration_seconds_sum counter",
	)
	for _, key := range sortedKeys(globalMetrics.httpLatencySum) {
		parts := strings.Split(key, "|")
		if len(parts) != 2 {
			continue
		}
		lines = append(lines,
			fmt.Sprintf(
				`huang_http_request_duration_seconds_sum{method=%q,path=%q} %.6f`,
				escape(parts[0]), escape(parts[1]),
				globalMetrics.httpLatencySum[key],
			),
		)
	}

	lines = append(lines,
		"# HELP huang_http_request_duration_seconds_count Number of requests observed for duration.",
		"# TYPE huang_http_request_duration_seconds_count counter",
	)
	for _, key := range sortedKeys(globalMetrics.httpLatencyHits) {
		parts := strings.Split(key, "|")
		if len(parts) != 2 {
			continue
		}
		lines = append(lines,
			fmt.Sprintf(
				`huang_http_request_duration_seconds_count{method=%q,path=%q} %d`,
				escape(parts[0]), escape(parts[1]),
				globalMetrics.httpLatencyHits[key],
			),
		)
	}

	lines = append(lines,
		"# HELP huang_scrape_requests_total Total scrape requests by domain/result.",
		"# TYPE huang_scrape_requests_total counter",
	)
	for _, key := range sortedKeys(globalMetrics.scrapeCount) {
		parts := strings.Split(key, "|")
		if len(parts) != 2 {
			continue
		}
		lines = append(lines,
			fmt.Sprintf(
				`huang_scrape_requests_total{domain=%q,result=%q} %d`,
				escape(parts[0]), escape(parts[1]),
				globalMetrics.scrapeCount[key],
			),
		)
	}

	lines = append(lines,
		"# HELP huang_scrape_duration_seconds_sum Sum of scrape durations by domain.",
		"# TYPE huang_scrape_duration_seconds_sum counter",
	)
	for _, key := range sortedKeys(globalMetrics.scrapeLatencySum) {
		lines = append(lines,
			fmt.Sprintf(
				`huang_scrape_duration_seconds_sum{domain=%q} %.6f`,
				escape(key),
				globalMetrics.scrapeLatencySum[key],
			),
		)
	}

	lines = append(lines,
		"# HELP huang_scrape_duration_seconds_count Number of scrape duration observations.",
		"# TYPE huang_scrape_duration_seconds_count counter",
	)
	for _, key := range sortedKeys(globalMetrics.scrapeLatencyHits) {
		lines = append(lines,
			fmt.Sprintf(
				`huang_scrape_duration_seconds_count{domain=%q} %d`,
				escape(key),
				globalMetrics.scrapeLatencyHits[key],
			),
		)
	}

	lines = append(lines,
		"# HELP huang_scrape_site_state Site circuit state (1=open, 0=closed).",
		"# TYPE huang_scrape_site_state gauge",
	)
	for _, key := range sortedKeys(globalMetrics.siteState) {
		value := 0
		if globalMetrics.siteState[key] == "open" {
			value = 1
		}
		lines = append(lines,
			fmt.Sprintf(
				`huang_scrape_site_state{domain=%q,state=%q} %d`,
				escape(key), escape(globalMetrics.siteState[key]), value,
			),
		)
	}

	lines = append(lines,
		"# HELP huang_cache_hits_total Total cache hits.",
		"# TYPE huang_cache_hits_total counter",
		fmt.Sprintf("huang_cache_hits_total %d", globalMetrics.cacheHit),
		"# HELP huang_cache_misses_total Total cache misses.",
		"# TYPE huang_cache_misses_total counter",
		fmt.Sprintf("huang_cache_misses_total %d", globalMetrics.cacheMiss),
	)

	return strings.Join(lines, "\n") + "\n"
}

func sortedKeys[V any](m map[string]V) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func escape(v string) string {
	v = strings.ReplaceAll(v, `\`, `\\`)
	v = strings.ReplaceAll(v, `"`, `\"`)
	return v
}
