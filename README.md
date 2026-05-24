# KomiVerse

**A Full-Stack Media Consumption Platform** built with **Go** (Backend) + **Flutter** (Mobile App).

A personal project focused on building scalable backend systems and smooth mobile experiences for reading manga, novels, and watching anime.

## 🚀 Project Highlights

- Production-grade **Go backend** with resilient scraping architecture
- Modern **Flutter** mobile application with complete manga reading flow
- Multi-service local development setup
- Strong emphasis on clean architecture, reliability, and observability

## 🛠 Tech Stack

**Backend**
- Go (Gin Framework)
- GoQuery (HTML parsing)
- Prometheus Metrics
- Rate Limiting & Caching
- Docker & Docker Compose

**Frontend**
- Flutter + Dart
- Riverpod (State Management)
- Dio (Networking)
- go_router + PhotoView (Reader)

**Other**
- Structured Logging
- Async Job Processing
- Modular Source Registry

## ✨ Key Features

### Backend
- Unified REST API for Manga, Novels & Anime
- Pluggable scraper system (11+ sources)
- Advanced resilience: retries with jitter, per-domain rate limiting, circuit breaker
- TTL Cache with stale fallback
- Async jobs with polling support
- Prometheus metrics & health checks

### Frontend
- Beautiful dark-themed UI with bottom navigation
- Complete Manga flow: Browse → Detail → Chapter Reader
- Vertical & Horizontal reading modes with zoom
- Local reading progress persistence
- Extension management system
- Runtime backend URL configuration

## 📁 Repository Structure

```text
komiverse/
├── backend/                    # Go API + scrapers
├── frontend/                   # Flutter mobile app
├── Huang/api.consumet.org/     # Self-hosted anime provider
├── docker-compose.yml
└── docs/                       # Architecture & implementation notes
⚠️ Important Disclaimer
This project is built for educational and portfolio purposes only.
It scrapes publicly available data from various websites. Please respect all websites' robots.txt and Terms of Service. No copyrighted content is hosted or distributed.
🚀 How to Run Locally
Prerequisites

Go 1.24+
Flutter SDK
Node.js (for anime provider)

Setup
1. Anime Provider
Bashcd Huang/api.consumet.org
npm install
npm run dev
2. Go Backend
Bashcd backend
go run ./cmd/server
3. Flutter App
Bashcd frontend
flutter pub get
flutter run
📸 Screenshots
(Add your screenshots here)
<img src="screenshots/manga-list.png" alt="Manga List">
<img src="screenshots/manga-reader.png" alt="Manga Reader">
<img src="screenshots/api-health.png" alt="Backend Health">
What I Learned

Designing resilient and observable backend systems in Go
Building maintainable scraper engines
Full-stack development with proper separation of concerns
Implementing production-grade patterns (rate limiting, caching, async processing, graceful shutdown)

Future Plans

Complete anime video playback
History & Library synchronization
Automated tests
CI/CD pipeline
