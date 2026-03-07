# 🚀 Client Manager v1.2.2 — Release Notes
**Date:** 07 March 2026

---

## 📦 Download

| File | Description |
|------|-------------|
| `ClientManager_Setup_v1.2.2.exe` | Windows installer (self-contained, ~14 MB) |

> Run the installer on any **Windows 10/11** PC — no additional software required.

---

## ✨ What's New in v1.2.2

### 📊 Admin Logs Dashboard (Major Redesign)
- The "Αρχείο (Logs)" tab is now a full **admin-only dashboard** with a full-width, virtualized table that handles thousands of log entries without any lag.
- **Search bar**: Filter logs in real-time by username, action type, customer ID, or any text in the details.
- **Cross-tab filters**: The Status, Service, and Payment filters now apply to logs as well, letting you focus on specific client categories instantly.

### ⚡ Performance Overhaul
- **Near-zero lag on filters**: Filtering and search now happen entirely in memory. No more database calls on every keystroke.
- **O(1) log lookups**: Log-to-client cross-referencing uses a hash map instead of a full list scan, making the Logs Dashboard instant even with large datasets.
- **Memoized lists**: Filtered results are cached and only recomputed when something actually changes.

### 🐛 Bug Fixes
- **Dropdown dark mode**: Fixed an issue where filter dropdown menu options showed black text on a dark background, making them invisible.

### 🤖 CI/CD Automation
- Push a `v*` tag to GitHub and a GitHub Actions workflow automatically builds the release, packages the Inno Setup installer, and publishes a new GitHub Release — no manual steps required.

---

## 📥 Installation

1. Download `ClientManager_Setup_v1.2.2.exe`
2. Run it and follow the wizard (Next → Install → Finish)
3. Launch **Client Manager** from the Start Menu or Desktop shortcut

> **Upgrading from v1.2.1?** Simply run the new installer — it will upgrade in place and preserve your database.

---

## ⚙️ System Requirements

- Windows 10 or Windows 11 (64-bit)
- ~55 MB free disk space
- No internet connection required — fully offline

---

*Built with Flutter 3 · SQLite · Inno Setup 6 · GitHub Actions*
