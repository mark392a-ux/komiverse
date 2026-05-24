# HUANG Backend API

Go-based scraping API for manga, novels, and anime providers.

This service exposes a unified HTTP API on top of multiple source adapters, with:

- Pluggable scraper registry
- Sync and async execution modes
- In-memory TTL caching with stale fallback
- Per-request and per-domain rate controls
- Basic observability and Prometheus metrics output
- Docker and production deployment templates

## Features

- Unified endpoints for:
  - Browse popular/latest titles
  - Search titles
  - Get title metadata
  - Get chapter/episode lists
  - Get chapter pages (image URLs) or novel content
- Runtime-configurable:
  - HTTP server timeouts
  - CORS and trusted proxies
  - API rate limits (global and per IP)
  - Scrape retries, backoff, and domain throttling
  - Cache and async job settings
- Site resilience:
  - Retry with exponential backoff + jitter
  - Per-domain token bucket throttling
  - Circuit-breaker-style cooldown after repeated failures
  - Optional robots.txt enforcement

## Tech Stack

- Go `1.24+` (module target currently `go 1.24.0`)
- Gin (`github.com/gin-gonic/gin`) for HTTP routing/middleware
- GoQuery (`github.com/PuerkitoBio/goquery`) for HTML parsing

## Project Structure

```txt
backend-go/
  cmd/server/main.go                 # app bootstrap
  internal/api/routes.go             # routes and middleware wiring
  internal/api/handlers/             # endpoint logic
  internal/api/middleware/           # request ID, logging, CORS, rate limit, metrics
  internal/scrapers/                 # source interface + HTTP helpers + source adapters
  internal/registry/                 # source registration/lookup
  internal/cache/                    # in-memory TTL cache
  internal/jobs/                     # in-memory async job manager
  internal/observability/            # Prometheus-style metrics rendering
  internal/config/                   # env-driven runtime config
  docker-compose.yml                 # local/dev + optional edge profiles
  docker-compose.production.yml      # production profile stack
  README.production.md               # production rebuild and TLS guide
```

## Registered Sources

Current providers registered in `cmd/server/main.go`:

- Manga: `toonily`, `manhwaz`, `madarascans`, `manhwatop`, `thunderscans`, `mangageko`, `omegascans`
- Novel: `novelbin`, `novelhi`, `novelfull`, `wetriedtls`
- Anime: `animepahe` (via local Consumet-compatible API)

## API Endpoints

Base path: `/api`

- `GET /` root ping
- `GET /anime` built-in browser UI for anime search and browse
- `GET /api/health` service health
- `GET /api/health/sites` scraper domain health/circuit snapshot
- `GET /api/sources` list all registered sources
- `GET /api/browse?source={id}&sort=popular|latest&page=1`
- `GET /api/search?source={id}&q={query}&page=1`
- `GET /api/info/{source}/{id}`
- `GET /api/chapters/{source}/{id}`
- `GET /api/pages/{source}/{chapterOrEpisodeId}`
- `GET /api/jobs/{jobId}` async job polling
- `GET /metrics` Prometheus text format (when enabled)

Optional debug routes (only when `ENABLE_DEBUG_ROUTES=true`):

- `GET /api/debug/page?url=...`
- `GET /api/debug/ajax?url=...`
- `GET /api/debug/script`

### Async mode

For supported endpoints (`browse`, `search`, `info`, `chapters`, `pages`), add:

- `?async=true` (or `1`, `yes`)

Response:

- `202 Accepted` with `job_id` and `poll` URL

Then poll:

- `GET /api/jobs/{job_id}`

## Built-In Browser Page

Open:

```txt
http://localhost:8080/anime
```

This page:

- loads registered anime sources from `/api/sources`
- supports mode filter: `Search`, `Browse Popular`, `Browse Latest`
- searches via `/api/search`
- browses via `/api/browse`

## Local Development

1. Copy env template:

```powershell
Copy-Item .env.example .env
```

2. Run server:

```bash
go run ./cmd/server
```

3. Check health:

```bash
curl http://localhost:8080/api/health
```

## Docker

Build/run development profile with direct API port:

```bash
docker compose --profile dev up --build
```

Run edge profile (HTTP reverse proxy):

```bash
docker compose --profile edge up -d
```

Run TLS edge profile (existing certs expected):

```bash
docker compose --profile edge-tls up -d
```

For full production rebuild and TLS bootstrap, see [README.production.md](./README.production.md).

## Important Environment Variables

Core:

- `PORT` (default `8080`)
- `ENABLE_DEBUG_ROUTES` (`false`)
- `METRICS_ENABLED` (`true`)

CORS and proxies:

- `CORS_ALLOWED_ORIGINS` (comma-separated)
- `TRUSTED_PROXIES` (comma-separated CIDRs)

API rate limiting:

- `GLOBAL_RATE_LIMIT_RPS`, `GLOBAL_RATE_LIMIT_BURST`
- `PER_IP_RATE_LIMIT_RPS`, `PER_IP_RATE_LIMIT_BURST`

Caching:

- `CACHE_ENABLED`
- `CACHE_TTL`
- `CACHE_MAX_ENTRIES`

Async jobs:

- `ASYNC_ENABLED`
- `ASYNC_WORKERS`
- `ASYNC_QUEUE_SIZE`
- `ASYNC_JOB_TIMEOUT`
- `ASYNC_JOB_TTL`

Scraping behavior:

- `SCRAPE_TIMEOUT_SECONDS`
- `SCRAPE_RETRY_COUNT`
- `SCRAPE_RETRY_BASE_DELAY`
- `SCRAPE_MIN_DELAY`
- `SCRAPE_MAX_DELAY`
- `SCRAPE_DOMAIN_RPS`
- `SCRAPE_DOMAIN_BURST`
- `SCRAPE_FAIL_THRESHOLD`
- `SCRAPE_COOLDOWN`
- `SCRAPE_RESPECT_ROBOTS`

Server timeouts:

- `READ_TIMEOUT`
- `WRITE_TIMEOUT`
- `IDLE_TIMEOUT`
- `SHUTDOWN_TIMEOUT`

## Notes and Constraints

- Cache and async jobs are in-memory only (not shared across instances).
- Source HTML/API structures can change; scrapers may require periodic selector updates.
- Only one anime provider (`animepahe`) is currently registered.
- Anime provider depends on a local Consumet-style upstream at `http://localhost:3000/anime`.

## Extending the Project

To add a new source:

1. Implement `internal/scrapers.Source` interface.
2. Add it under `internal/scrapers/{type}/{source}/`.
3. Register it in `cmd/server/main.go`.
4. Verify `/api/sources` and endpoint behavior.
