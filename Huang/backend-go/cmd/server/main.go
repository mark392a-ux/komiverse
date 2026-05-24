package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os/signal"
	"syscall"
	"time"

	"HUANG/backend/internal/api"
	"HUANG/backend/internal/api/handlers"
	"HUANG/backend/internal/cache"
	"HUANG/backend/internal/config"
	"HUANG/backend/internal/jobs"
	"HUANG/backend/internal/registry"
	"HUANG/backend/internal/scrapers"
	consumet "HUANG/backend/internal/scrapers/anime/consumet"
	madarascans "HUANG/backend/internal/scrapers/manga/madarascans"
	mangageko "HUANG/backend/internal/scrapers/manga/mangageko"
	manhwatop "HUANG/backend/internal/scrapers/manga/manhwatop"
	manhwaz "HUANG/backend/internal/scrapers/manga/manhwaz"
	omegascans "HUANG/backend/internal/scrapers/manga/omegascans"
	thunderscans "HUANG/backend/internal/scrapers/manga/thunderscans"
	toonily "HUANG/backend/internal/scrapers/manga/toonily"
	novelbin "HUANG/backend/internal/scrapers/novel/novelbin"
	novelfull "HUANG/backend/internal/scrapers/novel/novelfull"
	novelhi "HUANG/backend/internal/scrapers/novel/novelhi"
	wetriedtls "HUANG/backend/internal/scrapers/novel/wetriedtls"
)

func main() {
	cfg := config.Load()

	scrapers.Configure(scrapers.Options{
		Timeout:          cfg.ScrapeTimeoutSeconds,
		RetryCount:       cfg.ScrapeRetryCount,
		RetryBaseDelay:   cfg.ScrapeRetryBaseDelay,
		MinDelay:         cfg.ScrapeMinDelay,
		MaxDelay:         cfg.ScrapeMaxDelay,
		PerDomainRPS:     cfg.ScrapeDomainRPS,
		PerDomainBurst:   cfg.ScrapeDomainBurst,
		FailureThreshold: cfg.ScrapeFailThreshold,
		Cooldown:         cfg.ScrapeCooldown,
		RespectRobots:    cfg.ScrapeRespectRobots,
	})

	cacheStore := cache.NewTTLCache(cfg.CacheTTL, cfg.CacheMaxEntries)
	var jobManager *jobs.Manager
	if cfg.AsyncEnabled {
		jobManager = jobs.NewManager(cfg.AsyncWorkers, cfg.AsyncQueueSize, cfg.AsyncJobTimeout, cfg.AsyncJobTTL)
	}
	handlers.ConfigureRuntime(cfg, cacheStore, jobManager)

	reg := registry.New()
	reg.Register(toonily.New())
	reg.Register(manhwaz.New())
	reg.Register(madarascans.New())
	reg.Register(manhwatop.New())
	reg.Register(thunderscans.New())
	reg.Register(mangageko.New())
	reg.Register(omegascans.New())
	reg.Register(novelbin.New())
	reg.Register(novelhi.New())
	reg.Register(novelfull.New())
	reg.Register(wetriedtls.New())
	reg.Register(consumet.NewAnimePahe())

	log.Println("Registered scrapers:")
	for _, s := range reg.All() {
		log.Printf("  -> [%s] %s (%s)", s.GetType(), s.Name(), s.GetBaseURL())
	}

	router := api.SetupRouter(cfg, reg)
	addr := fmt.Sprintf(":%s", cfg.Port)
	server := &http.Server{
		Addr:         addr,
		Handler:      router,
		ReadTimeout:  cfg.ReadTimeout,
		WriteTimeout: cfg.WriteTimeout,
		IdleTimeout:  cfg.IdleTimeout,
	}

	go func() {
		sigCtx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
		defer stop()
		<-sigCtx.Done()

		shutdownTimeout := cfg.ShutdownTimeout
		if shutdownTimeout <= 0 {
			shutdownTimeout = 20 * time.Second
		}
		ctx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
		defer cancel()
		if err := server.Shutdown(ctx); err != nil {
			log.Printf("graceful shutdown failed: %v", err)
			_ = server.Close()
		}
	}()

	log.Printf("KomiVerse Scraper starting on %s", addr)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("server failed to start: %v", err)
	}
}
