# CrmHotel Backend

FastAPI backend for reservation, unit lifecycle, operations, CRM, and finance workflows.

## Quick Start

1. Copy `.env.example` to `.env`.
2. Run `docker compose -f compose.yml up --build`.
3. Open `http://localhost:8000/docs`.

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
