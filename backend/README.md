# CrmHotel Backend

FastAPI backend for reservation, unit lifecycle, operations, CRM, and finance workflows.

## Quick Start

1. Copy `.env.example` to `.env`.
2. Run `docker compose -f compose.yml up --build`.
3. Open `http://localhost:8000/docs`.

## Production Deployment

Run the production stack from the `backend/` directory with the standalone compose file:

```bash
docker compose -f compose.prod.yml up -d --pull always
```

The production deploy now rebuilds the frontend locally with `API_BASE_URL=https://crm.clo0.net/api/v1` so the compiled web bundle always targets the public API origin, even before a new GHCR frontend image is published.

When the server has access to the Cloudflare API token through `/etc/caddy/caddy.env`, `deploy/deploy-prod.sh` also attempts to purge the cached frontend entry files after deployment. If the token is missing or lacks purge permission, the script logs a warning and continues because the frontend build now cache-busts entry assets with Flutter's per-build `.last_build_id`.

The default production images come from GHCR:

- `ghcr.io/ahmadmdm/crmhotel-api:latest`
- `ghcr.io/ahmadmdm/crmhotel-worker:latest`
- `ghcr.io/ahmadmdm/crmhotel-frontend:latest`

You can override the registry, owner, or tag with these optional environment variables:

- `CRMHOTEL_IMAGE_REGISTRY`
- `CRMHOTEL_IMAGE_OWNER`
- `CRMHOTEL_IMAGE_TAG`

For example, to deploy a specific image tag:

```bash
CRMHOTEL_IMAGE_TAG=main docker compose -f compose.prod.yml up -d --pull always
```

Or use the helper script:

```bash
./deploy/deploy-prod.sh
./deploy/deploy-prod.sh main
./deploy/deploy-prod.sh --skip-build
./deploy/deploy-prod.sh --verify-only
```

The helper script now performs a post-deploy verification pass after `docker compose`, cache-purge attempt, and Caddy reload. It confirms local and public `/api/v1/health` responses and checks that the frontend entry page is serving the Flutter bootstrap loader.

Useful helper-script modes:

- `--skip-build`: update or restart the production stack without forcing a frontend rebuild.
- `--verify-only`: run only the verification checks against the current deployment.
- `./deploy/deploy-prod.sh --skip-build main`: reuse the already-published `main` images without rebuilding locally.

The production stack binds only these services to loopback on the host:

- Frontend: `127.0.0.1:3810`
- API: `127.0.0.1:3811`
- Media: `127.0.0.1:3812`

Use the Caddy site block in `deploy/crm.clo0.net.Caddyfile` so the public domain reaches the correct container by path:

```caddyfile
crm.clo0.net {
	encode zstd gzip

	@api path /api/*
	reverse_proxy @api 127.0.0.1:3811

	@media path /media/*
	reverse_proxy @media 127.0.0.1:3812

	reverse_proxy 127.0.0.1:3810
}
```

Typical host-level deployment steps:

1. Ensure `crm.clo0.net` resolves to the server IP.
2. Start the containers with `docker compose -f compose.prod.yml up -d --pull always`.
3. Merge `deploy/crm.clo0.net.Caddyfile` into `/etc/caddy/Caddyfile`.
4. Reload Caddy with `sudo systemctl reload caddy`.
5. Check the last lines of `sudo journalctl -u caddy -n 50 --no-pager` and confirm `crm.clo0.net` certificate issuance succeeds.

If the host uses the Cloudflare DNS challenge through `/etc/caddy/caddy.env`, a manual `caddy validate` run from a shell may fail unless that environment file is loaded into the command environment first.

## Local Development

- API entrypoint: `app/main.py`
- Alembic config: `alembic.ini`
- Tests: `pytest`
- Lint: `python -m ruff check .`

### Unified Local Run

Backend on the default local port:

```bash
/Users/ahmadalmubarak/Documents/CrmHotel/.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Frontend against the local API:

```bash
cd ../frontend
../.tooling/flutter/bin/flutter run -d web-server --web-hostname 127.0.0.1 --web-port 3000 --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Notes:

- `API_BASE_URL` can point to any local API origin. The frontend normalizes the trailing slash automatically.
- The backend now accepts `localhost` and `127.0.0.1` loopback origins on any port for local browser validation, so preview ports like `3001` or `3002` do not require editing `ALLOWED_ORIGINS`.
