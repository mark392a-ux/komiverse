package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

func CORSAndSecurity(allowedOrigins []string) gin.HandlerFunc {
	origins := normalizeOrigins(allowedOrigins)
	allowAll := len(origins) == 1 && origins[0] == "*"

	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")
		if allowAll {
			c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		} else if origin != "" && isOriginAllowed(origin, origins) {
			c.Writer.Header().Set("Access-Control-Allow-Origin", origin)
			c.Writer.Header().Set("Vary", "Origin")
		}

		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type,Authorization,X-Requested-With")
		c.Writer.Header().Set("Access-Control-Max-Age", "86400")

		c.Writer.Header().Set("X-Content-Type-Options", "nosniff")
		c.Writer.Header().Set("X-Frame-Options", "DENY")
		c.Writer.Header().Set("Referrer-Policy", "no-referrer")
		c.Writer.Header().Set("X-XSS-Protection", "1; mode=block")
		c.Writer.Header().Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'; base-uri 'none'")

		// HSTS is safe to serve even behind TLS-terminating proxies.
		c.Writer.Header().Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")

		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}

func normalizeOrigins(in []string) []string {
	if len(in) == 0 {
		return []string{"*"}
	}
	out := make([]string, 0, len(in))
	for _, item := range in {
		trimmed := strings.TrimSpace(strings.ToLower(item))
		if trimmed != "" {
			out = append(out, trimmed)
		}
	}
	if len(out) == 0 {
		return []string{"*"}
	}
	return out
}

func isOriginAllowed(origin string, allowed []string) bool {
	origin = strings.ToLower(strings.TrimSpace(origin))
	for _, allow := range allowed {
		if allow == origin {
			return true
		}
		if strings.HasPrefix(allow, "*.") {
			suffix := strings.TrimPrefix(allow, "*")
			if strings.HasSuffix(origin, suffix) {
				return true
			}
		}
	}
	return false
}
