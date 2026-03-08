# 🚀 Client Manager v1.3.0 — Release Notes
**Date:** 08 March 2026

---

## 📦 Download

| File | Description |
|------|-------------|
| `ClientManager_Setup_v1.3.0.exe` | Windows installer (self-contained, ~15 MB) |
| `app-release.apk` | Android APK (for manual install or auto-update) |

> Run the installer on any **Windows 10/11** PC — no additional software required.

---

## ✨ What's New in v1.3.0

### 🔄 Unified Self-Hosted Update System
- **Kotatsu-style auto-updates**: The application now checks directly with GitHub Releases to see if a newer version is available.
- **Cross-Platform Support**: Seamless updates for both **Windows** (via installer execution) and **Android** (via OTA APK installation).
- **Auto-check on Startup**: A new setting allows the app to silently check for updates every time you open it.
- **Manual Control**: Don't want auto-checks? Use the new "Έλεγχος Τώρα" button in the Settings tab.
- **Download Progress**: See real-time download percentage directly in a popup dialog before the update installs.

### 🛠 Deployment & CI/CD
- **Enhanced Build Pipeline**: A new GitHub Actions workflow now builds both Windows and Android versions automatically on every push to main.
- **Automated Tag Releases**: Pushing a version tag now creates a draft GitHub Release with all platform assets attached.

### 🐛 Improvements
- Optimized the Settings tab layout to accommodate new update controls.
- Improved Android permission handling for side-loading APK updates reliably.

---

## 📥 Installation

### Windows
1. Download `ClientManager_Setup_v1.3.0.exe`
2. Run it and follow the wizard.
3. Launch **Client Manager** from the Start Menu.

### Android
1. Download `app-release.apk`
2. Open the file on your device and allow "Install from Unknown Sources" if prompted.

> **Upgrading?** Simply run the new installer or use the in-app "Check for Updates" button to let the app handle it for you!

---

## ⚙️ System Requirements

- **Windows**: 10 or 11 (64-bit)
- **Android**: 5.0+ (API 21)
- ~60 MB free disk space
- Internet connection required ONLY for checking and downloading updates.

---

*Built with Flutter 3 · SQLite · Inno Setup 6 · GitHub Actions*
