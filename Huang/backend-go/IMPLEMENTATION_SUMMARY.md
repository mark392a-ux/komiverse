# Implementation Summary

This file explains what is implemented in this backend and how code flows at runtime.

## 1. High-Level Architecture

The project is a Go HTTP API (`Gin`) that standardizes multiple content sources behind one interface:

- Manga sources
- Novel sources
- Anime source (via Consumet-compatible upstream)

Main components:

- `cmd/server/main.go`: bootstrap, dependency wiring, source registration, server lifecycle
- `internal/api`: routes + handlers
- `internal/scrapers`: source interface, HTTP fetch/retry/throttle/circuit helpers, source adapters
- `internal/registry`: source lookup by ID
- `internal/cache`: in-memory TTL response cache
- `internal/jobs`: in-memory async job queue/worker manager
- `internal/observability`: metrics collectors + Prometheus renderer
- `internal/config`: environment-driven config

## 2. Boot and Runtime Wiring (`cmd/server/main.go`)

Startup sequence:

1. Load config from environment (`config.Load()`).
2. Configure global scraper runtime options (`scrapers.Configure(...)`):
   - timeouts
   - retries/backoff
   - random delay
   - per-domain rate limits
   - failure threshold + cooldown
   - robots.txt behavior
3. Initialize TTL cache.
4. Initialize async job manager only when `ASYNC_ENABLED=true`.
5. Inject runtime dependencies into handlers (`handlers.ConfigureRuntime`).
6. Build source registry and register all provider implementations.
7. Build Gin router (`api.SetupRouter`).
8. Start HTTP server with configured read/write/idle timeouts.
9. Start graceful shutdown listener for `SIGINT`/`SIGTERM`.

Outcome: API starts with all sources available under a common contract.

## 3. Request Pipeline (`internal/api/routes.go`)

Middleware order:

1. `gin.Recovery()`
2. `RequestID()` -> attaches/echoes `X-Request-ID`
3. `StructuredLogger()` -> JSON-style per-request logs
4. `CORSAndSecurity()` -> CORS + security headers
5. `RateLimit()` -> global + per-IP token buckets
6. `RequestMetrics()` -> HTTP metrics observation

Registered routes:

- Health: `/`, `/api/health`, `/api/health/sites`
- Jobs: `/api/jobs/:id`
- Sources + content APIs:
  - `/api/sources`
  - `/api/browse`
  - `/api/search`
  - `/api/info/:source/*id`
  - `/api/chapters/:source/*id`
  - `/api/pages/:source/*id`
- Metrics: `/metrics` (conditional by config)
- Debug routes (conditional by config)

## 4. Handler Behavior (`internal/api/handlers/source_handler.go`)

### 4.1 Endpoint logic

Core content handlers (`Browse`, `Search`, `Info`, `Chapters`, `Pages`) follow the same pattern:

1. Validate runtime dependencies.
2. Parse/validate inputs:
   - `source`
   - `id` or query
   - `page` with max bound (`MAX_PAGE`)
3. Resolve source from registry.
4. Create deterministic cache key.
5. Execute via shared `respond(...)` wrapper.

### 4.2 `respond(...)` execution strategy

`respond(...)` centralizes response behavior:

1. Check cache (if enabled).
2. If `async=true` and async manager exists:
   - Submit job
   - Return `202 Accepted` with `job_id` + poll path
3. Else execute synchronously.
4. On execution error:
   - Try stale cache fallback (`GetStale`) and return with `X-Cache-Stale: true`
   - If no stale value, return `500`
5. On success:
   - Save payload to cache
   - Return `200`

This means sync and async share the same endpoint code path and output shape.

### 4.3 Async job status

- `/api/jobs/:id` returns:
  - `202` for in-progress jobs
  - `200` for completed/failed jobs
  - `404` if job missing
  - `503` when async manager disabled

### 4.4 Debug route safety

Debug endpoints only allow specific hosts (`mangafire.to` and related hostnames) via URL validation.

## 5. Runtime State (`internal/api/handlers/runtime.go`)

Handlers use a shared runtime dependency object:

- `Config`
- `Cache`
- `Jobs`

This is set once during startup by `ConfigureRuntime`.

## 6. Configuration Model (`internal/config/config.go`)

All runtime settings are environment-driven with defaults:

- HTTP server behavior (`PORT`, read/write/idle/shutdown timeouts)
- Security/network (`CORS_ALLOWED_ORIGINS`, `TRUSTED_PROXIES`)
- API rate limiting (global/per-IP)
- Pagination cap (`MAX_PAGE`)
- Cache toggles and TTL
- Async job toggles, workers, queue, TTL
- Metrics toggle
- Scraper behavior (timeouts, retries, random delay, per-domain throttle, circuit options, robots mode)

Parsing supports typed values:

- bools (`true/false/1/0/yes/no/on/off`)
- ints
- float64
- durations (Go duration format)
- CSV lists

## 7. Cache Implementation (`internal/cache/ttl.go`)

Implemented cache behavior:

- Thread-safe map with RW mutex
- Per-entry expiration (`expiresAt`)
- Max size with eviction:
  - Prefer deleting expired entries
  - Else delete oldest entry
- Background cleanup ticker
- `GetStale(key)` intentionally returns cached value even if expired (used for graceful degradation)

Important limitation: cache is process-local (not distributed).

## 8. Async Jobs (`internal/jobs/manager.go`)

Implemented model:

- Job states: `queued`, `running`, `completed`, `failed`
- Bounded queue + worker pool
- Per-job timeout via context
- Random hex job IDs
- Periodic cleanup for terminal jobs older than job TTL
- Non-blocking submit:
  - if queue full, job marked failed with `"queue is full"`

Important limitation: jobs are in-memory and non-persistent.

## 9. Middleware Details

### 9.1 Request ID (`request_id.go`)

- Uses inbound `X-Request-ID` if provided.
- Else generates random 8-byte hex ID.
- Stores under Gin context key `request_id`.
- Echoes response header `X-Request-ID`.

### 9.2 Structured logging (`logging.go`)

Logs method/path/status/latency/ip in JSON-like single-line format.

### 9.3 CORS + headers (`cors_security.go`)

Adds:

- Dynamic origin allowlist (supports exact and `*.` suffix wildcard style)
- `Access-Control-*` headers
- Security headers (`X-Frame-Options`, CSP, HSTS, etc.)
- Handles `OPTIONS` preflight with `204`

### 9.4 API rate limiting (`rate_limit.go`)

Token bucket implementation with:

- Optional global limiter
- Optional per-IP limiter
- Per-IP bucket map with periodic stale entry cleanup
- Returns `429` and `Retry-After: 1` when exceeded

### 9.5 HTTP metrics middleware (`metrics.go`)

Tracks per-route latency/count only when metrics enabled.

## 10. Observability (`internal/observability/metrics.go`)

In-memory counters/gauges for:

- HTTP request counts by method/path/status
- HTTP latency sum/count by method/path
- Scrape request counts by domain/result
- Scrape latency sum/count by domain
- Site circuit state by domain
- Cache hit/miss counters

Exposed as Prometheus text format via `/metrics`.

## 11. Scraper Core Runtime (`internal/scrapers/helpers.go`)

This is the most important execution engine shared by all source adapters.

Implemented features:

- Shared HTTP client with runtime timeout
- Randomized modern browser user-agent rotation
- Standard and AJAX headers
- Request helpers:
  - `FetchHTML`
  - `FetchAjax`
  - `FetchAjaxPost`
  - `FetchAPI`
- Retry behavior:
  - total attempts = `retryCount + 1`
  - exponential backoff + jitter
- Domain-level controls:
  - token bucket throttling
  - random inter-request delay
- Circuit-breaker-like protection:
  - count consecutive failures per domain
  - open domain for cooldown when threshold hit
- Optional robots.txt policy:
  - caches robots rules for 6 hours
  - applies longest-match allow/disallow logic
- Site health snapshot API (`SiteHealthSnapshot`)
- Utility helpers:
  - `ExtractLastSegment`
  - `CleanText`
  - `AbsoluteURL`

Net effect: source adapters stay focused on parsing while helpers enforce reliability constraints.

## 12. Data Contracts (`internal/scrapers/interface.go`)

Every source implements:

- `Popular(page)`
- `Latest(page)`
- `Search(query, page)`
- `GetInfo(id)`
- `GetChapters(id)`
- `GetPages(chapterID)`

Shared output models:

- `MediaItem`
- `MediaInfo`
- `Chapter`

This contract enables generic API handlers that do not know source-specific internals.

## 13. Normalization (`internal/normalization/normalization.go`)

Implemented normalization:

- Trim and clean text fields for output stability
- De-duplicate list items by:
  - `ID` when present
  - normalized title fallback

Applied in handlers on browse/search/info responses.

## 14. Source Registry (`internal/registry/registery.go`)

Registry is a map of source ID -> source implementation.

Capabilities:

- register source
- resolve source by ID
- list all sources
- list by media type

This is the indirection layer between API and concrete scrapers.

## 15. Source Implementations

### 15.1 Manga sources

- `toonily`: Madara-like HTML scraping, chapter AJAX fallback, `ts_reader.run` pages fallback to image tags.
- `manhwaz`: custom URL patterns (`/webtoon/*`), Madara + alternate selectors + AJAX fallback.
- `madarascans`: custom card/chapter selectors with Madara fallbacks.
- `manhwatop`: Madara-style listing/info/chapters, AJAX fallback.
- `thunderscans`: custom selectors for cards and chapter list; pages from `ts_reader.run` JSON.
- `mangageko`: custom listing/reader paths with `ts_reader` and image-tag fallback.
- `omegascans`: API-based adapter (`api.omegascans.org`) for list/info/chapters/pages.

### 15.2 Novel sources

- `novelbin`: HTML + AJAX chapter archive endpoint; chapter content from `#chr-content`.
- `novelhi`: mixed API + HTML:
  - listing/search via JSON APIs
  - info page + genre API
  - chapters via API with ascending reorder
  - content from `#showReading`
- `novelfull`: HTML with pagination crawling for chapters and content from `#chapter-content`.
- `wetriedtls`: API-based for list/info/chapters; chapter content extracted from Next.js push payload in HTML.

### 15.3 Anime source

- `animepahe` via `internal/scrapers/anime/consumet`:
  - expects Consumet-compatible service at `http://localhost:3000/anime`
  - search/info/recent/watch passthrough and transformation
  - episodes returned as `Chapter` entries
  - pages endpoint returns stream URL and JSON payload string

## 16. Deployment Assets

- `Dockerfile`: multi-stage build, distroless runtime image
- `docker-compose.yml`: dev and edge profiles (API, nginx, certbot, duckdns)
- `docker-compose.production.yml`: production stack with bootstrap and prod profiles
- `deploy/prod-rebuild.ps1`: scripted certificate bootstrap and production rollout
- `README.production.md`: production deployment instructions

## 17. What Is Implemented vs Not

Implemented:

- Complete end-to-end API pipeline for multiple sources
- Resilience and throttling layers
- Metrics and runtime health visibility
- Local + production containerization assets

Not present yet (as of this snapshot):

- Persistent/distributed cache or queue backend
- Multi-node job coordination
- Automated tests in this repository
- Multiple anime providers registered (currently one)

## 18. End-to-End Runtime Flow Example

For `GET /api/search?source=novelhi&q=martial&page=1`:

1. Request enters middleware chain (ID, log, CORS/security, rate limit, metrics).
2. Handler validates source/query/page.
3. Cache key generated (`search:novelhi:martial:1`).
4. Cache lookup:
   - hit -> return cached JSON
   - miss -> execute source search
5. `novelhi.Search` calls upstream API through shared scraper helper.
6. Scraper helper applies delay/throttle/retry/circuit behavior.
7. Handler de-duplicates items, caches payload, returns response.
8. Metrics update HTTP counters/latency and cache miss/hit stats.

This same pattern is reused across all main content routes.

