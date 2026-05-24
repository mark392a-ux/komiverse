## Fresh Production Deploy (`huang-api.duckdns.org`)

This is a clean rebuild flow using:
- `docker-compose.production.yml` (new, production-only stack)
- Nginx TLS edge + Certbot renew
- optional DuckDNS updater

Use this when old images/containers are messy and you want a new production setup from zero.

## 1. Environment

Set values in `.env`:

```env
DOMAIN=huang-api.duckdns.org
GIN_MODE=release
CORS_ALLOWED_ORIGINS=https://huang-api.duckdns.org
DUCKDNS_SUBDOMAINS=huang-api
DUCKDNS_TOKEN=your-duckdns-token
LETSENCRYPT_EMAIL=your-real-email@example.com
```

## 2. Clean Old Stack (one time)

```bash
docker compose -f docker-compose.production.yml --profile prod down --remove-orphans
docker compose -f docker-compose.production.yml --profile bootstrap down --remove-orphans
```

Optional: remove old API image so it rebuilds fully:

```bash
docker image rm huang-api:latest
```

## 3. Issue First TLS Certificate (DuckDNS DNS challenge)

This avoids opening inbound port 80.

```bash
docker run --rm \
  -v huang-prod_letsencrypt:/etc/letsencrypt \
  -e DUCKDNS_TOKEN=your-duckdns-token \
  infinityofspace/certbot_dns_duckdns:latest \
  certonly \
  --non-interactive --agree-tos \
  --email your-real-email@example.com \
  --preferred-challenges dns \
  --authenticator dns-duckdns \
  --dns-duckdns-propagation-seconds 300 \
  -d huang-api.duckdns.org
```

If DNS is slow, retry with a higher propagation value (for example `600`).

## 4. Start Production Stack

```bash
docker compose -f docker-compose.production.yml --profile prod up --build -d
```

Services:
- `api` (`huang-api:latest`)
- `edge` (Nginx TLS reverse proxy)
- `certbot` (auto renew loop every 12h)
- `duckdns` (dynamic DNS updater)

## 5. Verify

```bash
curl https://huang-api.duckdns.org/api/health
docker compose -f docker-compose.production.yml --profile prod ps
docker compose -f docker-compose.production.yml --profile prod logs -f edge
```

## Flutter Connection

Use:

```dart
const kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://huang-api.duckdns.org',
);
```

Run/build:

```bash
flutter run --dart-define=API_BASE_URL=https://huang-api.duckdns.org
```

For Flutter web, add your frontend domain to backend CORS:

```env
CORS_ALLOWED_ORIGINS=https://your-frontend-domain.com
```
