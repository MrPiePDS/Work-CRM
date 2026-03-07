# Client Manager CRM

> A Flutter desktop CRM application for managing client records, services, and documents. Built for Windows, with SQLite local storage, secure encryption, and a polished dark-mode UI.

![Version](https://img.shields.io/badge/version-1.2.2-blue)
![Platform](https://img.shields.io/badge/platform-Windows-lightblue)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![License](https://img.shields.io/badge/license-Private-red)
[![Release](https://github.com/MrPiePDS/Work-CRM/actions/workflows/release.yml/badge.svg)](https://github.com/MrPiePDS/Work-CRM/releases)

---

## Features

| Category | Details |
|---|---|
| **Client Management** | Create, search, edit, and track client records with full audit history |
| **Service Selection** | Fixed-price services (ΑΜΚΑ/ΑΜΑ, Κλειδάριθμος, Μεταβολή, ΑΦΜ, Εργασία) with automatic total calculation |
| **Conditional Fields** | Form fields automatically hidden or disabled based on selected services |
| **Document Checklist** | Required-document list auto-generated per selected service |
| **Payment Tracking** | Total / Paid / Balance with payment method (Μετρητά / Κάρτα / Iris) |
| **Taxisnet Credentials** | Stored AES-256 encrypted; displayed only when the client has them |
| **Audit Logs Dashboard** | Full-width admin-only logs tab with real-time search, cross-tab filters, and virtualized rendering for large datasets |
| **File Management** | Per-client document folder with file import and direct Explorer access |
| **Multi-user Auth** | SHA-256 hashed passwords; admin sees audit trail and user management; regular users do not |
| **Theme Support** | System, Light, and Dark mode — preference saved between sessions |
| **Responsive Window** | 440 × 460 for login, 1200 × 750 for dashboard, with enforced minimum size |
| **PDF & Excel Export** | Export client table to PDF or Excel from the Πίνακας tab |
| **CI/CD Release** | GitHub Actions automatically builds and publishes a new installer on every `v*` tag push |

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) ≥ 3.0.0
- Visual Studio 2022 (Windows) with **"Desktop development with C++"** workload

### Run (Development)

```bash
flutter pub get
flutter run -d windows
```

### Build Release Installer

```bash
# 1. Build the Flutter Windows release binary
flutter build windows --release

# 2. Compile the Inno Setup installer
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss

# Output: dist\ClientManager_Setup.exe
```

### Automated Release (CI/CD)

```bash
# Tag a version and push — GitHub Actions handles the rest
git tag v1.2.2
git push origin v1.2.2
```

### Test

```bash
flutter test
```

### Default Login

| Username | Password |
|----------|----------|
| `admin`  | `1234`   |

> ⚠️ Change the admin password on first login via **Ρυθμίσεις → Αλλαγή Κωδικού**.

---

## Project Structure

```
crm_flutter/
  .github/
    workflows/
      release.yml             # CI/CD: build + installer + GitHub Release
  lib/
    main.dart                 # Entry point, window setup, theme init
    models/
      client.dart             # Client data class (toMap / fromMap)
    services/
      database_service.dart   # SQLite CRUD + audit logging + user management
      file_service.dart       # Local folder + file import
      security_service.dart   # AES-256 encryption for Taxisnet passwords
      pdf_service.dart        # PDF generation (client summaries)
    ui/
      screens/
        login_screen.dart     # Login UI
        dashboard_screen.dart # Tabbed dashboard (5 tabs for admin)
      widgets/
        client_form.dart      # Full client data-entry form
    data/
      mock_data.dart          # Seed data for first-run empty database
    utils/
      theme.dart              # App light/dark theme definitions
  installer.iss               # Inno Setup script for Windows installer
```

See [`Architecture.md`](./Architecture.md) for a deeper technical overview.

---

## Database

- **Engine:** SQLite via `sqflite_common_ffi` (desktop FFI bridge)
- **Location:** `<Documents>/ClientManagerV2/crm_data.db`
- **Current Schema Version:** 2

| Table | Purpose |
|---|---|
| `clients` | One row per client (35+ columns) |
| `users` | Login credentials (SHA-256 hashed passwords + roles) |
| `audit_logs` | Every create/update action with timestamp, user, and details |

---

## Tabs Overview

| Tab | Access | Description |
|---|---|---|
| Νέος πελάτης | All users | Add a new client |
| Αναζήτηση | All users | Real-time search with filters |
| Πίνακας | All users | Full table with sort, filters, PDF/Excel export |
| Ρυθμίσεις | All users | Theme, password change; admin also sees user management |
| Αρχείο (Logs) | Admin only | Full audit log dashboard with search and cross-filters |

---

## License

Private / proprietary — all rights reserved.
