# Changelog

All notable changes to **Client Manager CRM** are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

> Changes staged but not yet tagged as a release.

---

## [1.2.2] — 2026-03-07

### Added
- **Admin Logs Dashboard (Tab 5)**: Complete redesign of the Audit Logs tab into a full-width, scalable admin-only dashboard using `ListView.builder` for smooth performance even with thousands of entries.
- **Logs Search Bar**: Real-time search across all log fields (username, action type, customer ID, and details text).
- **Cross-Filter Logs**: Status, Service, and Payment filters now work across both the Πίνακας tab and the Αρχείο (Logs) tab simultaneously, with O(1) map-based client lookups.
- **GitHub Actions CI/CD Pipeline**: Automated release workflow (`.github/workflows/release.yml`) — push a `v*` tag and GitHub Actions automatically builds the Flutter Windows app, compiles the Inno Setup installer, and creates a GitHub Release with the `.exe` uploaded as an asset.
- **Dynamic Version Injection**: The CI/CD pipeline reads the version from the Git tag and patches it into `installer.iss` automatically — no manual edits needed.

### Changed
- **Performance Overhaul**: Replaced O(N×M) log filtering with O(1) map-based lookups. Replaced redundant database search calls with instant local memoized filtering. Filter and search are now near-instant (<1ms) regardless of dataset size.
- **Memoized Filtering**: Filtering and sorting now computed once and cached in `_cachedFilteredClients` / `_cachedFilteredAuditLogs`; UI reuses the cache without recalculation on every frame.
- **Local Search**: Client search no longer hits the database on every keystroke — results are filtered in-memory from the already-loaded dataset.

### Fixed
- **Dropdown Dark Mode Bug**: Filter dropdowns in dark mode had black text on a dark background when the menu was open. Fixed by introducing `selectedItemBuilder` to separate the button label style from the popup menu item style.

---

## [1.2.1] — 2026-03-06

### Added
- **Settings Tab (Users Admin)**: Full admin control over user accounts (adding users, deleting users, changing passwords).
- **Secure Authentication**: SHA-256 hashing for all users stored in the local SQLite database. Hardcoded login strings were removed.
- **Comprehensive Test Suite**: Added Unit Tests (Models, Services) and Widget/Integration Tests (App flow, Login UI, Client form tests) under the `test/` directory.

### Changed
- `database_service.dart`: Added full user management methods (`getUser`, `createUser`, `updateUserPassword`, `deleteUser`, checking login credentials).
- `login_screen.dart`: Refactored to authenticate against the new `DatabaseService`.
- `dashboard_screen.dart`: Refactored to separate the users settings tab functionality.

### Fixed
- Fixed unlinked settings navigation and logout state transitions.
- Cleanup of debugging logs (eliminated unused files and print statements).

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
