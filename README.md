# Work-CRM
---

```md
# Client Manager – Local Desktop App (v1)

A local Windows desktop application for managing customer cases using Excel as the backend.  
Designed to replace direct Excel usage with a simple, controlled GUI.

---

## 🎯 Goal (v1)
- Run **locally** (no server, no internet required)
- Use **Excel** as the main data store
- Track **who did what and when**
- Allow fast customer registration, search, and basic file management

---

## ✅ Features (v1)
- Basic **login system** (local credentials)
- New customer registration
- Automatic ID assignment from Excel
- Service selection & price calculation
- Payment & balance calculation
- Customer folder creation
- Drag & drop file upload to customer folder
- Customer search (ID / Name / Phone)
- Customer edit & notes
- Simple **audit log** (CSV)

---

## 🛠 Tech Stack
- Python 3
- PySide6 (Qt GUI)
- openpyxl (Excel read/write)
- Local filesystem (folders per customer)

---

## 📂 Project Structure
```

client_manager/
│
├─ app.py
├─ login_window.py
├─ main_window.py
├─ excel_manager.py
├─ file_manager.py
├─ auth_manager.py
├─ audit_logger.py
├─ config.py
├─ users.json
├─ audit_log.csv
└─ requirements.txt

````

---

## ▶️ Run Locally
```bash
pip install -r requirements.txt
python app.py
````

---

## 🚧 Scope Notes

This is **v1**, focused on being:

* stable
* fast to use
* easy to extend

Advanced features (timers, scanner integration, detailed audit UI) are planned for future versions.

---

## 🔒 Notes

* No sensitive credentials (e.g. Taxisnet passwords) are stored.
* All actions are logged locally for accountability.
```
