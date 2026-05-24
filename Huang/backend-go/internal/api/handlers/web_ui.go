package handlers

import (
	_ "embed"
	"html/template"
	"net/http"

	"github.com/gin-gonic/gin"
)

var (
	//go:embed static/anime.html
	animePageHTML string
	animePageTmpl = template.Must(template.New("anime").Parse(animePageHTML))
)

func AnimePage() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Content-Type", "text/html; charset=utf-8")
		if err := animePageTmpl.Execute(c.Writer, nil); err != nil {
			c.String(http.StatusInternalServerError, "failed to render anime page")
			return
		}
	}
}
