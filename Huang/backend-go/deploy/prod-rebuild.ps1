param(
  [string]$Domain = "huang-api.duckdns.org",
  [string]$Email = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Email)) {
  Write-Error "Provide a valid Let's Encrypt email: .\\deploy\\prod-rebuild.ps1 -Email you@example.com"
}

Write-Host "Stopping old production containers..."
docker compose -f docker-compose.production.yml --profile prod down --remove-orphans
docker compose -f docker-compose.production.yml --profile bootstrap down --remove-orphans

Write-Host "Starting bootstrap stack (HTTP only)..."
docker compose -f docker-compose.production.yml --profile bootstrap up --build -d api edge-bootstrap

Write-Host "Requesting first certificate for $Domain..."
docker compose -f docker-compose.production.yml --profile bootstrap run --rm certbot-init `
  certonly --webroot -w /var/www/certbot `
  -d $Domain `
  --email $Email `
  --agree-tos --no-eff-email

Write-Host "Stopping bootstrap stack..."
docker compose -f docker-compose.production.yml --profile bootstrap down

Write-Host "Starting production stack..."
docker compose -f docker-compose.production.yml --profile prod up --build -d

Write-Host "Done. Verify with:"
Write-Host "  curl https://$Domain/api/health"
