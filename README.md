# CrmHotel

CrmHotel is a two-part workspace:

- `backend/`: FastAPI, SQLModel, Alembic, Celery, Redis, PostgreSQL, Docker.
- `frontend/`: Flutter app scaffold with Riverpod, GoRouter, offline sync primitives, and role-based shells.

## Backend

- Main app: `backend/app/main.py`
- Compose file: `backend/compose.yml`
- Default docs URL: `http://localhost:8000/docs`

## Frontend

- Main app: `frontend/lib/main.dart`
- Routing: `frontend/lib/app/routing/app_router.dart`
- Role-based demo login: `frontend/lib/features/auth/presentation/pages/login_page.dart`
- Supported SDK: Flutter 3.41.x with Dart 3.11.x via `./.tooling/flutter/bin/flutter`
- Team version pin: `.fvmrc` for FVM users

## Automation

- CI workflow: `.github/workflows/ci.yml`
- CD workflow: `.github/workflows/cd.yml`
- Frontend SDK pin: run `fvm use` at the workspace root if your team uses FVM
- CI now runs backend `ruff + alembic + pytest`, frontend version checks plus `analyze/test/build`, and Docker image builds for `api`, `worker`, and `frontend`.
- CD publishes `crmhotel-api`, `crmhotel-worker`, and `crmhotel-frontend` images to GHCR on pushes to `main` or `master`, or on manual dispatch.

## Suggested Next Commands

1. `cd backend && docker compose -f compose.yml up --build`
2. `cd frontend && ../.tooling/flutter/bin/flutter pub get`
3. `cd frontend && ../.tooling/flutter/bin/flutter run -d chrome`
