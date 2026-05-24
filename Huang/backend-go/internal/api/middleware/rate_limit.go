package middleware

import (
	"math"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

type tokenBucket struct {
	rate   float64
	burst  float64
	tokens float64
	last   time.Time
}

func newTokenBucket(rate float64, burst int) *tokenBucket {
	if rate <= 0 {
		rate = 1
	}
	if burst <= 0 {
		burst = 1
	}
	now := time.Now()
	return &tokenBucket{
		rate:   rate,
		burst:  float64(burst),
		tokens: float64(burst),
		last:   now,
	}
}

func (b *tokenBucket) allow(now time.Time) bool {
	elapsed := now.Sub(b.last).Seconds()
	if elapsed > 0 {
		b.tokens = math.Min(b.burst, b.tokens+elapsed*b.rate)
		b.last = now
	}
	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}

type ipLimiterEntry struct {
	bucket   *tokenBucket
	lastSeen time.Time
}

func RateLimit(globalRPS float64, globalBurst int, perIPRPS float64, perIPBurst int) gin.HandlerFunc {
	var (
		mu          sync.Mutex
		global      *tokenBucket
		perIP       = make(map[string]*ipLimiterEntry)
		lastCleanup time.Time
	)

	if globalRPS > 0 && globalBurst > 0 {
		global = newTokenBucket(globalRPS, globalBurst)
	}

	cleanup := func(now time.Time) {
		if now.Sub(lastCleanup) < time.Minute {
			return
		}
		lastCleanup = now
		for ip, entry := range perIP {
			if now.Sub(entry.lastSeen) > 10*time.Minute {
				delete(perIP, ip)
			}
		}
	}

	return func(c *gin.Context) {
		now := time.Now()
		mu.Lock()
		defer mu.Unlock()

		cleanup(now)

		if global != nil && !global.allow(now) {
			c.Header("Retry-After", "1")
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error": "global rate limit exceeded",
			})
			return
		}

		if perIPRPS > 0 && perIPBurst > 0 {
			ip := c.ClientIP()
			if ip == "" {
				ip = "unknown"
			}
			entry, ok := perIP[ip]
			if !ok {
				entry = &ipLimiterEntry{
					bucket:   newTokenBucket(perIPRPS, perIPBurst),
					lastSeen: now,
				}
				perIP[ip] = entry
			}
			entry.lastSeen = now
			if !entry.bucket.allow(now) {
				c.Header("Retry-After", "1")
				c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
					"error": "ip rate limit exceeded",
				})
				return
			}
		}

		c.Next()
	}
}
