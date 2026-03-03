# Architecture

## Overview

Client Manager CRM is a **Flutter desktop application** targeting Windows.  
It uses an **offline-first, single-process** architecture: all data lives in a local SQLite file and no network calls are made.

```
┌─────────────────── Flutter Desktop App (Windows) ────────────────────┐
│                                                                      │
│  ┌────────────┐    ┌──────────────────┐    ┌────────────────────────┐│
│  │  UI Layer  │───▶│  Service Layer   │───▶│   Data Layer (SQLite) ││
│  │ (Screens & │◀───│  (Business Logic)│◀───│   crm_data.db         ││
│  │  Widgets)  │    └──────────────────┘    └────────────────────────┘│
│  └────────────┘             │                                        │
│                             │                                        │
│                    ┌────────▼────────┐                               │
│                    │  Filesystem     │                               │
│                    │  (Client Docs)  │                               │
│                    └─────────────────┘                               │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Layers

### 1. UI Layer — `lib/ui/`

| File | Role |
|------|------|
| `screens/login_screen.dart` | Authentication form; resizes window to 440×460 |
| `screens/dashboard_screen.dart` | 4–5 tab host: New Client / Search / Table / Settings / Logs |
| `widgets/client_form.dart` | Full create/edit form with conditional fields and document checklist |

**State management:** Plain `StatefulWidget` + `setState`. No external state library is used; the data set is small enough that explicit refreshes (calling `_refreshClients()` after every save) are sufficient without the overhead of a state library.

---

### 2. Service Layer — `lib/services/`

| Service | Responsibility |
|---------|----------------|
| `DatabaseService` | Singleton SQLite wrapper. CRUD for `clients`, `users`, `audit_logs`. Handles schema migrations. |
| `FileService` | Client document folder creation, file import (copy + rename), folder-in-Explorer launch, file listing. |
| `SecurityService` | AES-256 encryption/decryption for Taxisnet passwords stored in the DB. |
| `PdfService` | Generates printable client summary PDFs using the `pdf` + `printing` packages. |
| `AuditService` | Lightweight alternative audit writer (legacy; `DatabaseService.insertAuditLog` is preferred). |
| `MigrationService` | One-off helpers for migrating data from the legacy app format. |

---

### 3. Data Layer — SQLite

- **Package:** `sqflite_common_ffi` (required for Windows/Linux desktop; uses native SQLite via FFI)
- **File path:** `<ApplicationDocumentsDirectory>/ClientManagerV2/crm_data.db`
- **Version:** 2 (see migration history below)

#### Schema

```
clients (35 columns)
  id INTEGER PK AUTOINCREMENT
  name, phone, email, afm, amka, ama
  service_type TEXT          -- comma-separated service keys
  has_taxisnet INTEGER       -- 0|1
  taxisnet_user, taxisnet_pass (AES-encrypted)
  payment_method, total, paid, balance
  customer_status, declaration_status, id_type
  created_by, created_at, last_edited_by, last_edited_at
  folder_path, files_confirmed_by, files_confirmed_at
  goal, amount, amka_valid, aporipsi, actions_today
  kleidarithmos, amka_ama_status, request_notes, date

users
  id, username (UNIQUE), password_hash (SHA-256), role, created_at

audit_logs
  id, timestamp, username, action, customer_id (FK), details
```

#### Migration History

| Version | Changes |
|---------|---------|
| 1 | Initial schema |
| 2 | `ALTER TABLE clients ADD COLUMN email TEXT` + `id_type TEXT` |

Migrations are applied in `DatabaseService._onUpgrade()` using `PRAGMA table_info` to guard against duplicate-column errors.

---

### 4. Filesystem Layer

Local client documents are stored in:

```
<Documents>/ClientManagerV2/Clients/<ClientName>/
  Ταυτότητα_1709123456789.jpg
  Σύμβαση_1709124000000.pdf
  ...
```

All operations go through `FileService`:
- **Import** — user picks a file via `file_picker`; a rename dialog selects the doc type; file is copied with a `DocType_timestamp.ext` name.
- **List** — `listClientFiles()` reads the folder and surfaces chips in the form.
- **Open** — `openClientFolderInExplorer()` launches `explorer.exe <path>`.

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| No BLoC / Provider / Riverpod | Dataset < 1 000 rows; `setState` + explicit refresh is simpler and easier to debug |
| Offline-first SQLite | No internet dependency; all data stays on the operator's machine |
| AES for Taxisnet passwords | Passwords must be recoverable (they need to be displayed); hashing alone is not sufficient |
| Passwords in `users` table SHA-256 hashed | Login passwords do not need to be recovered, so one-way hashing is appropriate |
| `sqflite_common_ffi` | Flutter's default `sqflite` only works on mobile; FFI bridge enables desktop |
| Window resize on login/logout | Gives the app a purposeful feel: small for login, full-screen for work |
| Conditional form fields | Prevents data entry errors (e.g., you can't enter an AMKA when you're requesting one) |

---

## Window Management

```
App start  →  440 × 460  (login)
  Login    →  1200 × 750 (dashboard, min 900 × 600)
  Logout   →  440 × 460  (back to login)
```

Managed by `window_manager` package in:
- `main()` — sets initial size
- `DashboardScreen._setWindowSize()` — expands on login
- `DashboardScreen._logout()` — shrinks on logout

---

## Authentication

- Credentials stored in the `users` table (SHA-256 hashed password).
- Login check in `LoginScreen._login()` is currently a hardcoded comparison for `admin/1234`.  
  **TODO:** Query the `users` table hash for multi-user support.
- Admin detection: `widget.user == 'admin'` (simple string check).

---

## Audit Trail

Every `insertClient` and `updateClient` call writes a row to `audit_logs` via `DatabaseService.insertAuditLog()`. The Logs tab in the dashboard (admin-only) shows these rows in a `DataTable`.

---

## Future / Planned

| Feature | Notes |
|---------|-------|
| WIA Scanner integration | Requires a native C++ platform channel for Windows Image Acquisition API |
| Cloud / multi-device file storage | Needs a backend (Firebase Storage or self-hosted); out of scope for v1 |
| Full multi-user login | `users` table exists; login query needs to use it |
| PDF export improvements | `PdfService` exists but needs styling pass |
