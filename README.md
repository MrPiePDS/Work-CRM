# Client Manager CRM

> A Flutter desktop CRM application for managing client records, services, and documents. Built for Windows, with SQLite local storage and a clean, dark-mode-ready UI.

---

## Features

- **Client Management** — Create, search, edit, and track client records with full history
- **Service Selection** — Checkboxes for fixed-price services (ΑΜΚΑ/ΑΜΑ, Κλειδάριθμος, Μεταβολή, ΑΦΜ, Εργασία) with automatic total calculation
- **Conditional Fields** — Form fields are automatically hidden or disabled based on selected services
- **Document Checklist** — Required-document list generated automatically per selected service
- **Payment Tracking** — Total / Paid / Balance with payment method (Μετρητά / Κάρτα / Iris)
- **Taxisnet Credentials** — Stored AES-encrypted; visible only when the client has them
- **Audit Logs** — Every create/update action is recorded with timestamp and user (visible to admin)
- **File Management** — Per-client document folder with file import (rename dialog) and direct Explorer access
- **Multi-user** — Admin user sees full audit trail and the Logs tab; regular users do not
- **Responsive Window** — 440 × 460 for login, 1200 × 750 for the dashboard

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) ≥ 3.0.0
- Visual Studio 2022 (Windows) with "Desktop development with C++" workload

### Run

```bash
cd crm_flutter
flutter pub get
flutter run -d windows
```

### Test

```bash
flutter test
```

### Default Login

| Username | Password |
|----------|----------|
| admin    | 1234     |

> ⚠️ Change the admin password on first login.

---

## Project Structure

```
crm_flutter/
  lib/
    main.dart               # Entry point, window setup
    models/
      client.dart           # Client data class (toMap / fromMap)
    services/
      database_service.dart # SQLite CRUD + audit logging
      file_service.dart     # Local folder + file import
      security_service.dart # AES encryption for Taxisnet passwords
      audit_service.dart    # Standalone audit helper (legacy)
      pdf_service.dart      # PDF generation
      migration_service.dart# Data migration helpers
    ui/
      screens/
        login_screen.dart   # Login UI
        dashboard_screen.dart # Main tabbed dashboard
      widgets/
        client_form.dart    # Full client data-entry form
    data/
      mock_data.dart        # Seed data for first-run
    utils/
      theme.dart            # App light/dark theme definitions
```

See [`ARCHITECTURE.md`](./ARCHITECTURE.md) for a deeper technical overview.

---

## Database

- **Engine:** SQLite via `sqflite_common_ffi` (desktop FFI bridge)
- **Location:** `<Documents>/ClientManagerV2/crm_data.db`
- **Current Schema Version:** 2

| Table       | Purpose                                  |
|-------------|------------------------------------------|
| `clients`   | One row per client (35+ columns)         |
| `users`     | Login credentials (SHA-256 hashed)       |
| `audit_logs`| Every create/update with user + detail   |

---

## License

Private / proprietary — all rights reserved.
