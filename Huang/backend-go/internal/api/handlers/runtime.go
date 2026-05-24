package handlers

import (
	"HUANG/backend/internal/cache"
	"HUANG/backend/internal/config"
	"HUANG/backend/internal/jobs"
)

type Runtime struct {
	Config *config.Config
	Cache  *cache.TTLCache
	Jobs   *jobs.Manager
}

var runtimeDeps *Runtime

func ConfigureRuntime(cfg *config.Config, cacheStore *cache.TTLCache, jobManager *jobs.Manager) {
	runtimeDeps = &Runtime{
		Config: cfg,
		Cache:  cacheStore,
		Jobs:   jobManager,
	}
}

func getRuntime() *Runtime {
	return runtimeDeps
}
