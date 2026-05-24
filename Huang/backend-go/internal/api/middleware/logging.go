package middleware

import (
	"log"
	"time"

	"github.com/gin-gonic/gin"
)

func StructuredLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()

		path := c.FullPath()
		if path == "" {
			path = c.Request.URL.Path
		}

		log.Printf(
			`{"ts":%q,"level":"info","method":%q,"path":%q,"status":%d,"latency_ms":%d,"ip":%q}`,
			time.Now().UTC().Format(time.RFC3339Nano),
			c.Request.Method,
			path,
			c.Writer.Status(),
			time.Since(start).Milliseconds(),
			c.ClientIP(),
		)
	}
}
