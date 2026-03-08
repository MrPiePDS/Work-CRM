# 🏹 Client Manager CRM — Project Milestones

This document tracks the major achievements, feature transitions, and technical wins in the development of **Client Manager CRM**.

---

## 🏗️ Phase 1: The Foundation (v1.0.x)
**Date:** March 3rd, 2026
*   **Legacy Rewrite**: Successfully moved away from the old Excel-based management into a modern, full-desktop CRM built with **Flutter**.
*   **Offline-First Architecture**: Integrated `sqflite_common_ffi` for local SQLite storage, ensuring data stays private and accessible without internet.
*   **Security Foundation**: Implemented AES-256 for sensitive credentials and SHA-256 for user authentication.

## 🚀 Phase 2: Core Feature Complete (v1.2.x)
**Date:** March 3rd – March 7th, 2026
*   **Automated Form Logic**: Added conditional fields and a dynamic document checklist that updates based on the selected services ($AMKA/AMA, Κλειδάριθμος, etc.).
*   **File Management System**: Built a per-client directory structure for storage with direct Windows Explorer integration.
*   **Performance Overhaul (O(1))**: Optimized client searching and audit log filtering from linear O(N) to O(1) map-based lookups, making searches instant for thousands of records.
*   **Admin Dashboard**: Created a full-width virtualized data grid for audit logging/tracking restricted to admin users.

## 🤖 Phase 3: Automation & Release (v1.3.0)
**Date:** March 8th, 2026
*   **CI/CD Pipeline**: Deployed a multi-platform **GitHub Actions** workflow that builds Windows installers and Android APKs automatically.
*   **Self-Hosted Update System**: Built an in-app "Check for Updates" module (Kotatsu-style) that fetches new releases directly from GitHub without requiring an app store.
*   **Alpha Stability Phase (v1.3.2.a)**: Fine-tuned the CI/CD pipeline to eliminate "asset pollution" and provide a clean, professional release page for users.

---

## 🛣️ Future Roadmap
- [ ] **WIA Scanner Support**: Native C++ integration for direct scanner communication.
- [ ] **Cloud Backup**: Optional encrypted cloud sync (Firebase/S3).
- [ ] **Mobile Port**: Refine the UI specifically for Android tablets.
