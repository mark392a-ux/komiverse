# KomiVerse

KomiVerse is a full-stack media reading platform built with Flutter + Go, with a self-hosted anime provider service.

This repository is portfolio-focused for internship applications and demonstrates:
- Mobile app architecture and UX implementation in Flutter
- API and scraping system design in Go
- Multi-service local development workflow
- Practical configuration, caching, retry, and observability patterns

## Project Status
- Client: actively implemented with core manga/anime/extension flows
- Backend API: working multi-source Go service
- Provider service: self-hosted Consumet-compatible API included
- Public deployment: intentionally disabled (no public APK and no public API URL)

## Repository Layout
```text
komiverse/
  frontend/                   # Flutter mobile app
  Huang/backend-go/           # Go API (scrapers, caching, jobs, metrics)
  Huang/api.consumet.org/     # Consumet-compatible provider service (TypeScript)
  README.md
  IMPLEMENTATION_SUMMARY.md
  docs/
```

## Architecture
```text
Flutter App (frontend)
  -> Go API (Huang/backend-go)
      -> Manga + Novel scrapers
      -> Anime provider adapter
          -> Consumet-compatible API (Huang/api.consumet.org)
```

Detailed technical notes:
- [Architecture](/docs/ARCHITECTURE.md)
- [Implementation Summary](/IMPLEMENTATION_SUMMARY.md)

## Key Features
- Animated splash + onboarding flow
- Bottom navigation shell with Manga, Anime, Novel, History, Extensions, More
- Manga browse -> detail -> chapter reader with:
  - Vertical/horizontal reading modes
  - Saved per-chapter reading progress
- Anime browse and detail with episode listing
- Backend URL configuration from app settings at runtime
- Default source selection per media type (manga/anime/novel)
- Theme mode + reading direction preferences persisted locally
- Extension browse/install/uninstall flows backed by API

## Tech Stack
- Mobile: Flutter, Dart, Riverpod, go_router
- API Client: Dio
- Backend: Go, Gin, GoQuery
- Provider Service: Node.js + TypeScript + Fastify (Consumet-compatible)
- Persistence: SharedPreferences (mobile), in-memory TTL/cache/jobs (backend)
- Infra: Docker Compose (backend + provider templates)

## Run Locally
Use 3 terminals.

### 1. Start anime provider service (port 3000)
```powershell
cd Huang\api.consumet.org
npm install
npm run dev
```

### 2. Start Go backend (recommended on port 8081 for mobile defaults)
```powershell
cd Huang\backend-go
$env:PORT="8081"
$env:CONSUMET_BASE_URL="http://localhost:3000/anime"
go run ./cmd/server
```

### 3. Start Flutter app
```powershell
cd frontend
flutter pub get
flutter run --dart-define=BACKEND_BASE_URL=http://127.0.0.1:8081
```

For Android physical device via USB:
```powershell
adb reverse tcp:8081 tcp:8081
```

## Why No Live APK / Public API
This repository is intentionally self-hosted for safety and legal control:
- No public scraping API endpoint
- No publicly shared APK
- Reviewers can run everything locally from source

## Documentation
- [GitHub Publishing Checklist](/docs/GITHUB_PUBLISH_CHECKLIST.md)
- [Internship Showcase Notes](/docs/INTERNSHIP_SHOWCASE.md)
- [Architecture](/docs/ARCHITECTURE.md)
- [Implementation Summary](/IMPLEMENTATION_SUMMARY.md)

## Roadmap
- Complete anime streaming playback integration
- Build real history sync across manga/anime/novel
- Add automated tests across mobile + backend flows
- Add CI pipeline (lint, analyze, build, smoke tests)
