# KomiVerse Architecture

This document gives a high-level engineering view of the system.

## 1. Services

### Flutter Client (`frontend/`)
- UI, navigation, local preferences, and content rendering
- Calls backend using `ApiClient` (`/api` prefixed routes)
- Supports runtime backend URL updates from Settings

### Go Backend (`Huang/backend-go/`)
- Unified API layer for manga/anime/novel
- Source registry and adapter abstraction
- Middleware for request ID, logs, CORS/security, rate limits, and metrics
- In-memory cache + optional async jobs
- Scraper resilience controls (retry, delay, throttle, cooldown)

### Provider Service (`Huang/api.consumet.org/`)
- Self-hosted service used by anime adapter
- Runs on port `3000` by default
- Backend points to it using `CONSUMET_BASE_URL`

## 2. Request Path

```text
Mobile UI action
  -> ApiClient request
  -> Go API endpoint (/api/...)
  -> Resolve source adapter
  -> Fetch/scrape upstream or provider API
  -> Normalize + cache + respond
  -> Flutter render + optional local persistence
```

## 3. Frontend Runtime Notes

- Backend base URL candidates are defined in `frontend/lib/core/config/app_config.dart`
- `ApiClient.init()` probes reachable backend and stores selected URL
- User can override backend URL from app settings without rebuilding
- Reader progress is saved via `SharedPreferences`

## 4. Backend Runtime Notes

- Default server port is `8080`; portfolio setup typically runs it at `8081`
- Anime source uses `http://localhost:3000/anime` unless overridden
- Health endpoint: `/api/health`
- Source discovery endpoint: `/api/sources`
- Metrics endpoint: `/metrics` (if enabled)

## 5. Tradeoffs and Current Limits

- Cache and async jobs are in-memory only
- Scrapers depend on external site structure and can require maintenance
- Public deployment is intentionally not included
- Automated tests are currently limited across all services

## 6. Next Technical Upgrades

1. Add integration tests for core API contracts
2. Add persistent cache/job storage for multi-instance reliability
3. Complete anime playback flow in mobile app
4. Add CI for lint/analyze/test/build checks
