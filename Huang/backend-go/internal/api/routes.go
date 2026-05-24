package api

import (
	"HUANG/backend/internal/api/handlers"
	"HUANG/backend/internal/api/middleware"
	"HUANG/backend/internal/config"
	"HUANG/backend/internal/registry"
	"log"

	"github.com/gin-gonic/gin"
)

func SetupRouter(cfg *config.Config, reg *registry.Registry) *gin.Engine {
	router := gin.New()
	if err := router.SetTrustedProxies(cfg.TrustedProxies); err != nil {
		log.Fatalf("invalid TRUSTED_PROXIES: %v", err)
	}
	router.Use(gin.Recovery())
	router.Use(middleware.RequestID())
	router.Use(middleware.StructuredLogger())
	router.Use(middleware.CORSAndSecurity(cfg.AllowedOrigins))
	router.Use(middleware.RateLimit(
		cfg.GlobalRateLimitRPS,
		cfg.GlobalRateLimitBurst,
		cfg.PerIPRateLimitRPS,
		cfg.PerIPRateLimitBurst,
	))
	router.Use(middleware.RequestMetrics(cfg.MetricsEnabled))
	router.GET("/", handlers.Root)
	router.GET("/anime", handlers.AnimePage())

	api := router.Group("/api")
	{
		api.GET("/health", handlers.Health)
		api.GET("/health/sites", handlers.SiteHealth)
		api.GET("/jobs/:id", handlers.JobStatus())
		api.GET("/sources", handlers.ListSources(reg))
		api.GET("/browse", handlers.Browse(reg))
		api.GET("/search", handlers.Search(reg))
		api.GET("/info/:source/*id", handlers.Info(reg))
		api.GET("/chapters/:source/*id", handlers.Chapters(reg))
		api.GET("/pages/:source/*id", handlers.Pages(reg))
		if cfg.EnableDebugRoutes {
			api.GET("/debug/page", handlers.DebugPage(reg))
			api.GET("/debug/ajax", handlers.DebugAjax(reg))
			api.GET("/debug/script", handlers.DebugScript(reg))
		}
	}

	if cfg.MetricsEnabled {
		router.GET("/metrics", handlers.Metrics)
	}

	return router
}
