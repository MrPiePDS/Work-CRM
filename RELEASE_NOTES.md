# 🚀 Client Manager v1.3.0 — Release Notes
**Date:** 06 March 2026

---

## 📦 Download

| File | Size |
|------|------|
| `ClientManager_Setup.exe` | 13.5 MB |

> Run the installer on any **Windows 10/11** PC — no additional software or settings required.

---

## ✨ What's New in v1.3.0

### 🔐 Secure Authentication & User Management
- **SHA-256 password hashing:** All user credentials are now securely hashed and stored in the local SQLite database.
- **Admin Settings Tab:** A new dedicated tab for administrators to add, delete, and manage user accounts and passwords directly from the dashboard.
- **Database login:** Hardcoded login credentials have been entirely removed in favor of real database authentication.

### 🧪 Comprehensive Testing Suite
- **Unit and Integration Tests:** Added a robust suite of automated tests covering models, database services, and UI flows.
- **App Flow Verification:** Ensured stability through rigorous widget testing of the login screen and client form.

### 🧹 Codebase Cleanup and Polish
- **Refactoring:** Cleaned up UI logic in the dashboard and login screens for better maintainability.
- **Log Removal:** Cleared out debugging artifacts and legacy test files.
- **Flow Fixes:** Resolved issues with settings navigation and logout transitions.

---

## 📥 Installation

1. Download `ClientManager_Setup.exe`
2. Run it and follow the wizard (Next → Install → Finish)
3. Launch **Client Manager** from the Start Menu

---

## ⚙️ System Requirements

- Windows 10 or Windows 11 (64-bit)
- ~50 MB free disk space
- No internet connection required — fully offline

---

*Built with Flutter 3 · SQLite · Inno Setup 6*
