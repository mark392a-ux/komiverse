package middleware

import (
	"crypto/rand"
	"encoding/hex"
	"net/http"

	"github.com/gin-gonic/gin"
)

const RequestIDHeader = "X-Request-ID"

// RequestID injects a unique request ID into every request and echoes it back
// in the response header. Use c.GetString("request_id") in handlers to log it.
func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Accept a client-supplied ID (e.g. from a Flutter retry), otherwise generate one.
		id := c.GetHeader(RequestIDHeader)
		if id == "" {
			id = newRequestID()
		}
		c.Set("request_id", id)
		c.Header(RequestIDHeader, id)
		c.Next()
	}
}

func newRequestID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "fallback"
	}
	return hex.EncodeToString(b[:])
}

// RequestIDFromContext returns the request ID stored by the middleware,
// or an empty string if not set.
func RequestIDFromContext(c *gin.Context) string {
	id, _ := c.Get("request_id")
	if s, ok := id.(string); ok {
		return s
	}
	return ""
}

// RequestIDFromHeader reads the request ID from an http.Request directly.
func RequestIDFromHeader(r *http.Request) string {
	return r.Header.Get(RequestIDHeader)
}
