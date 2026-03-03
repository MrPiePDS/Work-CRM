# Changelog

All notable changes to **Client Manager CRM** are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

> Changes staged but not yet tagged as a release.

---

## [1.2.0] — 2026-03-03

### Added
- **Email field** on client record (`email TEXT`, DB v2).
- **Τύπος Ταυτοποίησης** (ID type) dropdown: Ταυτότητα / Άσυλο / Διαβατήριο / Άλλο (`id_type TEXT`, DB v2).
- **Conditional form fields**:
  - ΑΜΚΑ/ΑΜΑ fields hidden when the "ΑΜΚΑ / ΑΜΑ" service is selected.
  - ΑΦΜ field hidden when the "ΑΦΜ" service is selected.
  - "Διαθέτει κωδικούς" checkbox disabled when "Κλειδάριθμος" service is selected.
- **Document checklist** — required-document list auto-generated per selected service (appears below the service checkboxes).
- **File import section** in the form:
  - "Εισαγωγή Εγγράφου" opens a file picker → rename dialog (selects doc type) → copies file into the client folder with a timestamp name.
  - "Άνοιγμα στον Explorer" launches Windows Explorer at the client's local folder.
  - Imported files shown as chips.
- **Full form visual redesign**:
  - Sections with coloured icon headers (LucideIcons).
  - `Πελάτης #ID` + creation-date chip in the top-right for existing clients.
  - Name / Phone / Email on one row.
  - Status + Declaration Status + ID Type dropdowns on one row.
- **Logout navigation fix**: logout now calls `pushReplacement(LoginScreen)` (previously `Navigator.pop` caused a black screen).
- **Window sizing**:
  - App now opens at `440 × 460` (login size).
  - Dashboard expands to `1200 × 750` (min `900 × 600`).
  - Logout shrinks window back to `440 × 460`.

### Changed
- `client.dart`: Added `email` and `idType` fields with full `toMap` / `fromMap` coverage.
- `database_service.dart`: DB version bumped `1 → 2`; `onUpgrade` uses `PRAGMA table_info` for safe `ALTER TABLE`.
- `file_service.dart`: Added `openClientFolderInExplorer()`, `importFile()`, `listClientFiles()`.
- `client_form.dart`: Complete rewrite with new layout, conditional logic, and file section.
- `dashboard_screen.dart`: `_logout()` extracted to a dedicated method; `_setWindowSize()` now also sets minimum size.

### Fixed
- State initialisation bug: `_status`, `_declarationStatus`, `_hasTaxis` were not loaded from the existing client when opening the edit dialog.

---

## [1.1.0] — 2026-03-03

### Added
- **Audit Logs tab** (admin-only): `_buildAuditLogsTab()` DataTable with timestamp, user, action chip, client ID, and details columns.
- **Payment method dropdown** (Μετρητά / Κάρτα / Iris) in the "Οικονομικά" section.
- **Service validation**: at least 1 service must be selected before saving; shows a red SnackBar if not.

### Fixed
- `dashboard_screen.dart` syntax error: stray `}` on line 184 was closing the class prematurely, orphaning `_buildAuditLogsTab()` and `build()`.
- `deprecated_member_use` warning: replaced `value:` with `initialValue:` on `DropdownButtonFormField` (Flutter ≥ 3.33 API).
- `curly_braces_in_flow_control_structures`: added braces around bare `if` statement in custom service checkbox handler.

---

## [1.0.0] — 2026-03-03

### Added
- Initial Flutter rewrite of the legacy CRM application.
- SQLite database (`sqflite_common_ffi`) with `clients`, `users`, `audit_logs` tables.
- `DatabaseService` singleton with full CRUD and `insertAuditLog` / `getAuditLogs`.
- `SecurityService` for AES-256 Taxisnet password encryption.
- `FileService` for client document folder management.
- `PdfService` for printable client summaries.
- `LoginScreen` with SHA-256 password comparison and admin password change dialog.
- `DashboardScreen` with 4 tabs (Νέος πελάτης / Αναζήτηση / Πίνακας / Ρυθμίσεις).
- `ClientForm` with service checkboxes, financial fields, Taxisnet section, and timestamp display.
- Mock data seeder for first-run empty database.
- Light / dark theme via `AppTheme` (follows OS preference).
- Window management via `window_manager` package.
