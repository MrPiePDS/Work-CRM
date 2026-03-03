# 🚀 Client Manager v1.2.0 — Release Notes
**Date:** 03 March 2026

---

## 📦 Download

| File | Size |
|------|------|
| `ClientManager_Setup.exe` | 13.3 MB |

> Run the installer on any **Windows 10/11** PC — no additional software or settings required.

---

## ✨ What's New in v1.2.0

### 🗂️ New Client Form Design
- Clean, section-based layout with icon headers
- **Client ID + registration date** shown in the top-right corner when editing
- **Email field** added to client records
- **ID Type** dropdown: Ταυτότητα / Άσυλο / Διαβατήριο / Άλλο

### 📋 Smart Document Checklist
Selecting a service now automatically shows the list of required documents the client must bring:

| Service | Documents Required |
|---|---|
| ΑΜΚΑ / ΑΜΑ | Ταυτότητα, Βεβαίωση ΑΜΚΑ, Φωτογραφία, Βεβαίωση Κατοικίας |
| Κλειδάριθμος | Ταυτότητα, Υπεύθυνη Δήλωση, Αίτηση |
| Μεταβολή | Ταυτότητα, Βεβαίωση Μεταβολής, Βεβαίωση Κατοικίας |
| ΑΦΜ | Ταυτότητα, Αποδεικτικό κατοικίας, Αίτηση ΑΦΜ |
| Εργασία | Ταυτότητα, Σύμβαση Εργασίας, Εκκαθαριστικό |

### 🔗 Smart Field Logic
The form now automatically reacts to the selected services:
- **ΑΜΚΑ / ΑΜΑ** selected → ΑΜΚΑ & ΑΜΑ input fields hidden (client doesn't have them yet)
- **ΑΦΜ** selected → ΑΦΜ input field hidden
- **Κλειδάριθμος** selected → "Διαθέτει κωδικούς Taxisnet" automatically disabled

### 📁 Client Document Folder
- **Open in Explorer** button — instantly opens the client's local document folder
- **Import Document** — pick any file, choose document type, it gets copied and renamed automatically
- Imported files appear as chips directly in the form

### 🔐 Login & Window Improvements
- App now opens as a **small login window** (440 × 460)
- After login the window automatically expands to full dashboard size
- **Logout** now correctly returns to the login screen (no more black screen)

---

## 🐛 Bug Fixes
- Fixed: client status, declaration status, and Taxisnet flag were resetting to defaults when opening the edit dialog
- Fixed: logout showing a black screen instead of the login page

---

## 📥 Installation

1. Download `ClientManager_Setup.exe`
2. Run it and follow the wizard (Next → Install → Finish)
3. Launch **Client Manager** from the Start Menu
4. Login with: **admin / 1234** *(change password after first login)*

---

## ⚙️ System Requirements

- Windows 10 or Windows 11 (64-bit)
- ~50 MB free disk space
- No internet connection required — fully offline

---

*Built with Flutter 3 · SQLite · Inno Setup 6*
