package middleware

import (
	"time"

	"HUANG/backend/internal/observability"

	"github.com/gin-gonic/gin"
)

func RequestMetrics(enabled bool) gin.HandlerFunc {
	if !enabled {
		return func(c *gin.Context) { c.Next() }
	}

	return func(c *gin.Context) {
		start := time.Now()
		c.Next()

		path := c.FullPath()
		if path == "" {
			path = c.Request.URL.Path
		}
		observability.ObserveHTTP(c.Request.Method, path, c.Writer.Status(), time.Since(start))
	}
}
