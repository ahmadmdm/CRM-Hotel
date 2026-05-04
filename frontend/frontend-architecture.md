# Frontend Architecture Blueprint

## 1. Project Architecture (Feature-First + Clean Architecture)

The Flutter app should be a single codebase serving three experiences from the same domain model:

- Responsive web admin panel for admin, finance, and operations users
- Mobile-first simplified flows for housekeeping and maintenance teams
- Shared service layer for auth, API, caching, localization, and notifications

### 1.1 Folder Structure

```text
frontend/
  lib/
    main.dart
    app/
      bootstrap/
        bootstrap.dart
        app_initializer.dart
      routing/
        app_router.dart
        app_redirector.dart
        route_names.dart
        route_guards.dart
      theme/
        app_theme.dart
        app_colors.dart
        app_typography.dart
        app_spacing.dart
        app_radius.dart
      localization/
        locale_controller.dart
        l10n_extensions.dart
      shell/
        app_shell.dart
        worker_shell.dart
    core/
      auth/
        auth_session.dart
        token_store.dart
        claims_parser.dart
      network/
        dio_client.dart
        interceptors/
          auth_interceptor.dart
          refresh_interceptor.dart
          logging_interceptor.dart
      storage/
        isar_service.dart
        secure_storage_service.dart
        cache_policies.dart
      sync/
        sync_queue.dart
        sync_engine.dart
        sync_action.dart
        sync_conflict.dart
        connectivity_service.dart
      errors/
        app_exception.dart
        failure_mapper.dart
      widgets/
        app_scaffold.dart
        app_loading.dart
        app_error_view.dart
        offline_banner.dart
      utils/
        date_utils.dart
        currency_utils.dart
        responsive_utils.dart
    design_system/
      tokens/
        color_tokens.dart
        typography_tokens.dart
        spacing_tokens.dart
      components/
        buttons/
        inputs/
        chips/
        cards/
        dialogs/
        tables/
        charts/
        navigation/
    features/
      auth/
        data/
          datasources/
          models/
          repositories/
        domain/
          entities/
          repositories/
          usecases/
        presentation/
          controllers/
          pages/
          widgets/
      dashboard/
      units/
      bookings/
      crm/
      finance/
      operations/
        housekeeping/
        maintenance/
      notifications/
      settings/
    l10n/
      app_ar.arb
      app_en.arb
```

### 1.2 Layering Rules

- `features/*/presentation`: Riverpod controllers, screens, and feature-scoped widgets only.
- `features/*/domain`: entities, repository contracts, and use cases. No Flutter imports.
- `features/*/data`: remote data sources, local data sources, DTOs, and repository implementations.
- `core`: cross-cutting infrastructure reused by multiple features.
- `design_system`: reusable UI primitives and composed widgets, independent from any feature.
- `app`: bootstrap, routing, theme, and top-level app shells.

### 1.3 Feature Example

```text
features/
  operations/
    housekeeping/
      data/
        datasources/
          housekeeping_remote_ds.dart
          housekeeping_local_ds.dart
        models/
          housekeeping_task_model.dart
        repositories/
          housekeeping_repository_impl.dart
      domain/
        entities/
          housekeeping_task.dart
        repositories/
          housekeeping_repository.dart
        usecases/
          get_today_tasks.dart
          complete_task_offline.dart
          sync_pending_tasks.dart
      presentation/
        controllers/
          housekeeping_tasks_controller.dart
        pages/
          housekeeping_home_page.dart
        widgets/
          housekeeping_task_card.dart
```

## 2. State Management Strategy (Riverpod + Offline Sync)

### 2.1 Auth State

Use one source of truth for the current session:

- `SessionController extends AsyncNotifier<AuthSession?>`
- Access token kept in memory
- Refresh token kept in secure storage
- Claims parsed once and exposed as typed role and permission providers
- On app startup:
  1. Load refresh token from secure storage
  2. Call `/auth/refresh` if access token is missing or expired
  3. Fetch `/auth/me`
  4. Build `AuthSession(user, roles, permissions, locale)`
  5. Router reacts to the hydrated session

Recommended core providers:

- `sessionControllerProvider`
- `currentUserProvider`
- `roleSetProvider`
- `isAuthenticatedProvider`
- `connectivityProvider`
- `syncStatusProvider`

### 2.2 Dio and Token Refresh

- `auth_interceptor`: injects access token into every protected request
- `refresh_interceptor`: handles `401`, refreshes token once, retries the failed request, then forces logout if refresh fails
- `logging_interceptor`: debug only, disabled in production for sensitive data
- Use request serialization for concurrent refresh attempts so only one refresh call runs at a time

### 2.3 Data Strategy by Role

Not every role should be equally offline-capable:

- Admin, Finance, Operations: online-first with cached reads for dashboard, lists, and detail pages
- Housekeeping: offline-first for daily tasks and task completion
- Maintenance: offline-tolerant for ticket acceptance, status change, and note updates

This keeps finance authoritative and safe, while worker flows remain usable in weak connectivity environments.

### 2.4 Offline Sync Model

Use Isar as the local database with two categories of local records:

1. Read models: cached units, tasks, tickets, and minimal client/booking snapshots needed by the current role
2. Pending mutations: commands generated while offline and replayed when connectivity returns

Suggested local sync entity:

| Field | Purpose |
| --- | --- |
| `id` | Local unique ID |
| `entityType` | `housekeeping_task`, `maintenance_ticket`, etc. |
| `entityId` | Server-side object ID |
| `actionType` | `complete_task`, `start_ticket`, `resolve_ticket`, `add_note` |
| `payload` | Serialized command payload |
| `createdAt` | Ordering and replay |
| `retryCount` | Backoff control |
| `status` | `pending`, `syncing`, `failed`, `completed`, `conflict` |
| `lastError` | Debuggable failure message |

### 2.5 Offline Workflow for Housekeeping and Maintenance

1. Fetch daily tasks from the API when online and store them in Isar.
2. If the device goes offline, task lists continue reading from Isar.
3. When a worker taps “completed” or “resolved”, update local UI optimistically and insert a sync action.
4. `SyncEngine` observes connectivity and app lifecycle, then replays pending actions in FIFO order.
5. After a successful replay, the app refreshes the affected entity from the API and marks the sync action complete.

### 2.6 Conflict Handling

- Every mutable server entity should expose `updated_at` and optionally `version`.
- If replay receives `409 Conflict`, mark the sync action as `conflict` and keep the local action visible in a supervisor review screen.
- For worker actions, prefer server truth over device truth. The app should reload the latest task and show a clear conflict banner.
- Finance screens should not queue writes offline.

### 2.7 Riverpod Patterns

- Use `AsyncNotifier` for async screens with remote orchestration.
- Use `Notifier` for local view state such as filters, sort order, selected date range, and current tab.
- Use provider families for details pages keyed by `unitId`, `bookingId`, `taskId`, and `ticketId`.
- Keep controllers thin; business rules stay in domain use cases.

## 3. Routing and Guards (GoRouter)

### 3.1 Route Topology

```text
/splash
/login
/forbidden
/app
  /dashboard
  /units
  /units/:unitId
  /bookings
  /bookings/:bookingId
  /crm
  /crm/:clientId
  /finance
  /finance/payments
  /finance/expenses
  /operations/housekeeping
  /operations/maintenance
/worker
  /housekeeping
  /maintenance
```

### 3.2 Role-Based Landing Routes

| Role | Default Route After Login |
| --- | --- |
| `super_admin` | `/app/dashboard` |
| `sub_admin` | `/app/dashboard` |
| `financial` | `/app/finance` |
| `operations` | `/app/bookings` |
| `maintenance` | `/worker/maintenance` |
| `housekeeping` | `/worker/housekeeping` |

### 3.3 Guard Rules

1. If the app is still hydrating auth state, keep the user on `/splash`.
2. If there is no valid session, redirect any protected route to `/login`.
3. If the user is authenticated and navigates to `/login`, redirect to the role-specific landing route.
4. If the user lacks permission for a route, redirect to `/forbidden`.
5. Preserve deep link intent using a `from` query param so users return to the originally requested page after login.

### 3.4 Practical Guard Implementation

- Use a router refresh listener driven by `sessionControllerProvider`.
- Define route-level metadata for required roles or permissions.
- Centralize redirect logic in `app_redirector.dart`, not inside individual pages.
- Use `ShellRoute` for the admin web shell and a separate `ShellRoute` for worker flows so navigation chrome stays role-appropriate.

Example guard matrix:

| Route Group | Guard |
| --- | --- |
| `/app/finance/*` | Requires `financial` or `super_admin` |
| `/app/operations/*` | Requires `operations`, `sub_admin`, or `super_admin` |
| `/worker/housekeeping` | Requires `housekeeping` |
| `/worker/maintenance` | Requires `maintenance` |

## 4. UI/UX Roadmap

### 4.1 Design System First

Build the design system before feature pages. It should cover:

- Color tokens for status-driven UI: occupancy, finance, warning, maintenance, success, offline, destructive
- Arabic and English typography tokens with explicit RTL and LTR spacing behavior
- Elevation, radius, border, and spacing tokens for consistent cards, filters, tables, and dialogs
- Component states: default, hover, focused, pressed, disabled, loading, error

### 4.2 Shared Widgets That Must Exist Early

- `AppScaffold` for responsive shell handling drawer, nav rail, and mobile bottom navigation
- `SectionHeader` for page titles and actions
- `KpiCard` for dashboard metrics
- `StatusChip` for unit, booking, payment, and task states
- `FilterBar` with search, date range, status, and unit selectors
- `ResponsiveDataTable` for CRM and finance modules
- `EmptyStateView`, `ErrorStateView`, `OfflineBanner`, `SyncStatusIndicator`
- `AppDateRangeField`, `CurrencyField`, `PhoneField`, `SearchField`
- `UnitCard`, `BookingCalendarCell`, `TaskCard`, `TicketCard`

### 4.3 Recommended Build Order

| Phase | Deliverables |
| --- | --- |
| Phase 1 | App bootstrap, theme, localization, auth flow, secure token handling, route guards |
| Phase 2 | Responsive app shell, dashboard KPIs, unit listing, unit details, shared filters |
| Phase 3 | Booking list, booking creation form, booking details, calendar view |
| Phase 4 | Housekeeping offline flow, maintenance simplified flow, sync engine, offline indicators |
| Phase 5 | CRM tables, client details, blacklist flows, finance payments and expenses |
| Phase 6 | Push notifications with FCM, advanced reporting views, performance hardening, accessibility audit |

### 4.4 UX Priorities by Surface

- Web admin panel: dense information layout, fast table filtering, keyboard-friendly forms, clear analytics blocks
- Housekeeping mobile flow: single-column task list, large completion CTA, low-friction offline feedback
- Maintenance mobile flow: quick ticket acceptance, status timeline, photo attachment support, note entry
- Finance screens: strong validation, explicit currency formatting, immutable history cues, export-friendly tables

### 4.5 Internationalization and Responsiveness

- All strings come from ARB files from day one; no hardcoded UI strings.
- Layout primitives must flip cleanly between RTL and LTR.
- Desktop uses navigation rail or side menu, tablet uses adaptive rail/drawer, and mobile workers use bottom navigation or a single-flow stack.
- Charts and tables must be designed for both dense web layouts and constrained mobile widths.

## 5. Implementation Notes

1. Keep auth, sync, and routing in `core` and `app` layers only; do not duplicate them inside features.
2. Prefer feature modules that are independently testable with fake repositories and local Isar fixtures.
3. Treat worker offline support as a first-class feature, not a later patch.
4. Design every status widget to use the same status-to-color mapping as the backend enums to avoid UI drift.
5. Add Firebase Cloud Messaging only after auth, routing, and local persistence are stable.