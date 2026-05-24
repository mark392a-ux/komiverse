# Internship Showcase Notes

Use this as your talking guide when presenting KomiVerse for internship applications.

## 1. One-Minute Project Pitch

KomiVerse is a full-stack media platform I built with Flutter, Go, and TypeScript.  
I designed the mobile UX, implemented a unified backend API with scraper adapters, added caching/retry/rate-limit patterns for reliability, and set up a multi-service local environment for real testing.

## 2. What Skills This Project Proves

- Mobile engineering:
  - Flutter architecture, navigation, feature modules, persisted settings
- Backend engineering:
  - API design, middleware, source abstraction, graceful error handling
- Reliability:
  - timeout/retry/backoff, per-domain throttling, stale cache fallback
- Product thinking:
  - runtime backend configuration, default sources, reader usability
- Ownership:
  - built and connected client + backend + provider service end-to-end

## 3. Demo Flow for Interview

1. Run all services locally.
2. Show manga list -> detail -> reader (most complete vertical flow).
3. Change backend URL in Settings live (no rebuild).
4. Show source defaults and reading direction preferences.
5. Explain backend pipeline from `/api` endpoint to source adapter and response.

## 4. Honest Limitations (Say This Clearly)

- Anime playback depth is still evolving.
- History/novel experiences are partly scaffolded.
- Test coverage is not yet where I want it.

Then immediately add:
- exact next steps you planned (tests, CI, streaming completion).

## 5. Resume Bullet Templates

- Built a Flutter mobile client with modular routing and persisted user preferences for theme, reading direction, and source selection.
- Implemented a Go backend unifying multiple manga/novel/anime sources through adapter interfaces and middleware-driven API routing.
- Added resilience patterns including retry with backoff, rate limiting, in-memory TTL caching, and health/metrics endpoints.
- Orchestrated multi-service local development across Flutter, Go, and TypeScript services to deliver an end-to-end product workflow.
