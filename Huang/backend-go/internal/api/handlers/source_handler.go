package handlers

import (
	"context"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"HUANG/backend/internal/normalization"
	"HUANG/backend/internal/observability"
	"HUANG/backend/internal/registry"
	"HUANG/backend/internal/scrapers"

	"github.com/gin-gonic/gin"
)

var allowedDebugHosts = map[string]struct{}{
	"mangafire.to":     {},
	"s.mfcdn.cc":       {},
	"www.mangafire.to": {},
}

func Health(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}

func Root(c *gin.Context) {
	c.String(http.StatusOK, "API is running")
}

func SiteHealth(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"sites": scrapers.SiteHealthSnapshot(),
	})
}

func Metrics(c *gin.Context) {
	c.Data(http.StatusOK, "text/plain; version=0.0.4; charset=utf-8", []byte(observability.RenderPrometheus()))
}

func JobStatus() gin.HandlerFunc {
	return func(c *gin.Context) {
		deps := getRuntime()
		if deps == nil || deps.Jobs == nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": "job manager not configured"})
			return
		}

		jobID := strings.TrimSpace(c.Param("id"))
		if jobID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "job id is required"})
			return
		}

		job, err := deps.Jobs.Get(jobID)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "job not found"})
			return
		}

		statusCode := http.StatusAccepted
		if job.Status == "completed" || job.Status == "failed" {
			statusCode = http.StatusOK
		}
		c.JSON(statusCode, job)
	}
}

func ListSources(reg *registry.Registry) gin.HandlerFunc {
	return func(c *gin.Context) {
		type sourceInfo struct {
			ID      string `json:"id"`
			Name    string `json:"name"`
			BaseURL string `json:"base_url"`
			Type    string `json:"type"`
		}
		var list []sourceInfo
		for _, s := range reg.All() {
			list = append(list, sourceInfo{
				ID:      s.ID(),
				Name:    s.Name(),
				BaseURL: s.GetBaseURL(),
				Type:    s.GetType(),
			})
		}
		c.JSON(http.StatusOK, gin.H{"sources": list})
	}
}

func Browse(reg *registry.Registry) gin.HandlerFunc {
	return func(c *gin.Context) {
		deps, ok := requireRuntime(c)
		if !ok {
			return
		}

		sourceID := strings.TrimSpace(c.Query("source"))
		sortBy := strings.TrimSpace(c.DefaultQuery("sort", "popular"))
		page, ok := parsePage(c, deps)
		if !ok {
			return
		}

		if sortBy != "popular" && sortBy != "latest" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "sort must be 'popular' or 'latest'"})
			return
		}

		source, exists := reg.Get(sourceID)
		if !exists {
			c.JSON(http.StatusBadRequest, gin.H{"error": "unknown source: " + sourceID})
			return
		}

		key := fmt.Sprintf("browse:%s:%s:%d", sourceID, sortBy, page)
		jobType := fmt.Sprintf("browse:%s", sourceID)
		respond(c, deps, key, jobType, func() (interface{}, error) {
			var (
				items []scrapers.MediaItem
				err   error
			)
			if sortBy == "latest" {
				items, err = source.Latest(page)
			} else {
				items, err = source.Popular(page)
			}
			if err != nil {
				return nil, err
			}
			items = normalization.DedupeMediaItems(items)
			return gin.H{
				"source": sourceID,
				"sort":   sortBy,
				"page":   page,
				"items":  items,
			}, nil
		})
	}
}

func Search(reg *registry.Registry) gin.HandlerFunc {
	return func(c *gin.Context) {
		deps, ok := requireRuntime(c)
		if !ok {
			return
		}

		sourceID := strings.TrimSpace(c.Query("source"))
		query := strings.TrimSpace(c.Query("q"))
		page, ok := parsePage(c, deps)
		if !ok {
			return
		}

		if query == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "query (q) is required"})
			return
		}

		source, exists := reg.Get(sourceID)
		if !exists {
			c.JSON(http.StatusBadRequest, gin.H{"error": "unknown source: " + sourceID})
			return
		}

		key := fmt.Sprintf("search:%s:%s:%d", sourceID, query, page)
		jobType := fmt.Sprintf("search:%s", sourceID)
		respond(c, deps, key, jobType, func() (interface{}, error) {
			items, err := source.Search(query, page)
			if err != nil {
				return nil, err
			}
			items = normalization.DedupeMediaItems(items)
			return gin.H{
				"source": sourceID,
				"query":  query,
				"page":   page,
				"items":  items,
			}, nil
		})
	}
}

func Info(reg *registry.Registry) gin.HandlerFunc {
	return func(c *gin.Context) {
		deps, ok := requireRuntime(c)
		if !ok {
			return
		}

		sourceID := strings.TrimSpace(c.Param("source"))
		id := strings.TrimPrefix(c.Param("id"), "/")
		if id == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "id is required"})
			return
		}

		source, exists := reg.Get(sourceID)
		if !exists {
			c.JSON(http.StatusBadRequest, gin.H{"error": "unknown source: " + sourceID})
			return
		}

		key := fmt.Sprintf("info:%s:%s", sourceID, id)
		jobType := fmt.Sprintf("info:%s", sourceID)
		respond(c, deps, key, jobType, func() (interface{}, error) {
			info, err := source.GetInfo(id)
			if err != nil {
				return nil, err
			}
			return normalization.NormalizeMediaInfo(info), nil
		})
	}
}

func Chapters(reg *registry.Registry) gin.HandlerFunc {
	return func(c *gin.Context) {
		deps, ok := requireRuntime(c)
		if !ok {
			return
		}

		sourceID := strings.TrimSpace(c.Param("source"))
		id := strings.TrimPrefix(c.Param("id"), "/")
		if id == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "id is required"})
			return
		}

		source, exists := reg.Get(sourceID)
		if !exists {
			c.JSON(http.StatusBadRequest, gin.H{"error": "unknown source: " + sourceID})
			return
		}

		key := fmt.Sprintf("chapters:%s:%s", sourceID, id)
		jobType := fmt.Sprintf("chapters:%s", sourceID)
		respond(c, deps, key, jobType, func() (interface{}, error) {
			chapters, err := source.GetChapters(id)
			if err != nil {
				return nil, err
			}
			return gin.H{
				"source":   sourceID,
				"id":       id,
				"chapters": chapters,
			}, nil
		})
	}
}

func Pages(reg *registry.Registry) gin.HandlerFunc {
	return func(c *gin.Context) {
		deps, ok := requireRuntime(c)
		if !ok {
			return
		}

		sourceID := strings.TrimSpace(c.Param("source"))
		id := strings.TrimPrefix(c.Param("id"), "/")
		if id == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "id is required"})
			return
		}

		source, exists := reg.Get(sourceID)
		if !exists {
			c.JSON(http.StatusBadRequest, gin.H{"error": "unknown source: " + sourceID})
			return
		}

		key := fmt.Sprintf("pages:%s:%s", sourceID, id)
		jobType := fmt.Sprintf("pages:%s", sourceID)
		respond(c, deps, key, jobType, func() (interface{}, error) {
			pages, err := source.GetPages(id)
			if err != nil {
				return nil, err
			}
			return gin.H{
				"source": sourceID,
				"pages":  pages,
			}, nil
		})
	}
}

// Debug - GET /api/debug/page?url=https://mangafire.to/manga/one-piecee.dkw
func DebugPage(reg *registry.Registry) gin.HandlerFunc {
	return func(c *gin.Context) {
		targetURL, err := validateDebugURL(c.Query("url"))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		body, err := scrapers.FetchHTML(targetURL, "https://mangafire.to")
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		full := string(body)
		start := strings.Index(full, "<main")
		if start == -1 {
			start = strings.Index(full, "<body")
		}
		if start == -1 {
			start = 0
		}
		preview := full[start:]
		if len(preview) > 5000 {
			preview = preview[:5000]
		}
		c.JSON(http.StatusOK, gin.H{"preview": preview})
	}
}

func DebugAjax(reg *registry.Registry) gin.HandlerFunc {
	return func(c *gin.Context) {
		targetURL, err := validateDebugURL(c.Query("url"))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		body, err := scrapers.FetchAjax(targetURL, "https://mangafire.to")
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		preview := string(body)
		if len(preview) > 3000 {
			preview = preview[:3000]
		}
		c.JSON(http.StatusOK, gin.H{"preview": preview})
	}
}

func DebugScript(reg *registry.Registry) gin.HandlerFunc {
	return func(c *gin.Context) {
		body, err := scrapers.FetchHTML("https://s.mfcdn.cc/assets/t2/min/scripts.js?6934e07c", "https://mangafire.to")
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		full := string(body)
		idx := strings.Index(full, "ajax/read")
		if idx == -1 {
			c.String(http.StatusOK, "NOT FOUND - searching for 'read'...")
			return
		}
		start := idx - 100
		if start < 0 {
			start = 0
		}
		end := idx + 300
		if end > len(full) {
			end = len(full)
		}
		c.String(http.StatusOK, full[start:end])
	}
}

func requireRuntime(c *gin.Context) (*Runtime, bool) {
	deps := getRuntime()
	if deps == nil || deps.Config == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "runtime not initialized"})
		return nil, false
	}
	return deps, true
}

func parsePage(c *gin.Context, deps *Runtime) (int, bool) {
	pageRaw := strings.TrimSpace(c.DefaultQuery("page", "1"))
	page, err := strconv.Atoi(pageRaw)
	if err != nil || page < 1 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "page must be a positive integer"})
		return 0, false
	}
	maxPage := deps.Config.MaxPage
	if maxPage <= 0 {
		maxPage = 100
	}
	if page > maxPage {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("page must be <= %d", maxPage)})
		return 0, false
	}
	return page, true
}

func shouldAsync(c *gin.Context, deps *Runtime) bool {
	if !deps.Config.AsyncEnabled || deps.Jobs == nil {
		return false
	}
	v := strings.ToLower(strings.TrimSpace(c.DefaultQuery("async", "false")))
	return v == "1" || v == "true" || v == "yes"
}

func respond(
	c *gin.Context,
	deps *Runtime,
	cacheKey string,
	jobType string,
	exec func() (interface{}, error),
) {
	if deps.Config.CacheEnabled && deps.Cache != nil {
		if cached, ok := deps.Cache.Get(cacheKey); ok {
			observability.IncCacheHit()
			c.JSON(http.StatusOK, cached)
			return
		}
		observability.IncCacheMiss()
	}

	if shouldAsync(c, deps) {
		job, err := deps.Jobs.Submit(jobType, func(ctx context.Context) (interface{}, error) {
			return executeWithTimeout(ctx, deps.Config.AsyncJobTimeout, exec)
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusAccepted, gin.H{
			"job_id": job.ID,
			"status": job.Status,
			"type":   job.Type,
			"poll":   "/api/jobs/" + job.ID,
		})
		return
	}

	// Synchronous requests should not inherit async timeout limits.
	// Long chapter lists can legitimately take longer than async job timeout.
	payload, err := exec()
	if err != nil {
		if deps.Config.CacheEnabled && deps.Cache != nil {
			if stale, ok := deps.Cache.GetStale(cacheKey); ok {
				c.Header("X-Cache-Stale", "true")
				c.JSON(http.StatusOK, stale)
				return
			}
		}
		c.JSON(classifyScrapeErrorStatus(err), gin.H{"error": err.Error()})
		return
	}

	if deps.Config.CacheEnabled && deps.Cache != nil {
		deps.Cache.Set(cacheKey, payload)
	}
	c.JSON(http.StatusOK, payload)
}

func classifyScrapeErrorStatus(err error) int {
	if err == nil {
		return http.StatusInternalServerError
	}
	msg := strings.ToLower(err.Error())
	switch {
	case strings.Contains(msg, "temporarily disabled due to repeated failures"):
		return http.StatusServiceUnavailable
	case strings.Contains(msg, "consumet unreachable"):
		return http.StatusServiceUnavailable
	case strings.Contains(msg, "timed out"):
		return http.StatusGatewayTimeout
	case strings.Contains(msg, "upstream status"):
		return http.StatusBadGateway
	default:
		return http.StatusInternalServerError
	}
}

func executeWithTimeout(ctx context.Context, timeout time.Duration, fn func() (interface{}, error)) (interface{}, error) {
	if timeout <= 0 {
		return fn()
	}

	type result struct {
		value interface{}
		err   error
	}
	done := make(chan result, 1)
	go func() {
		value, err := fn()
		done <- result{value: value, err: err}
	}()

	timer := time.NewTimer(timeout)
	defer timer.Stop()

	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	case <-timer.C:
		return nil, fmt.Errorf("operation timed out after %s", timeout.String())
	case out := <-done:
		return out.value, out.err
	}
}

func validateDebugURL(raw string) (string, error) {
	if strings.TrimSpace(raw) == "" {
		return "", fmt.Errorf("url is required")
	}

	u, err := url.Parse(raw)
	if err != nil {
		return "", fmt.Errorf("invalid url")
	}

	if u.Scheme != "http" && u.Scheme != "https" {
		return "", fmt.Errorf("invalid url scheme")
	}

	host := strings.ToLower(u.Hostname())
	if host == "" {
		return "", fmt.Errorf("invalid host")
	}

	if _, ok := allowedDebugHosts[host]; ok {
		return u.String(), nil
	}
	if strings.HasSuffix(host, ".mangafire.to") {
		return u.String(), nil
	}
	return "", fmt.Errorf("host not allowed")
}
