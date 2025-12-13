Τέλειο, ξεκάθαρο 👍
---

# 📄 README.md

*(ένα αρχείο, μεγάλο, πρωτότυπο, επαγγελματικό)*

Κάνε **copy–paste ΟΛΟ** το παρακάτω ως `README.md`.

```md
# Client Manager v1  
### Local Office CRM – Design, Logic & Usage Documentation

---

## SECTION 1 — USER GUIDE  
### (For everyday users – no technical knowledge required)

---

### 1. What is Client Manager?

Client Manager is a **local desktop application** designed to help offices manage customers, services, and documents **without using the internet**.

This application replaces chaotic Excel usage with:
- clear forms
- automatic calculations
- organized customer folders
- clear responsibility (who did what, and when)

It is designed so that **anyone can use it**, even without computer experience.

---

### 2. Logging in

When the application starts, you will see a login screen.

- Each user logs in with their credentials
- Every action is logged automatically
- You always know:
  - who created a customer
  - who edited them
  - who confirmed files

This protects both the office and the employee.

---

### 3. Creating a new customer

Go to **New Customer** tab.

Fill in:
- Service type (KEP / Nomika)
- Name & Surname
- Phone number
- Notes (optional)

The date is filled automatically.

Before saving:
- You MUST confirm:
  - customer data
  - selected services & pricing

This prevents accidental mistakes.

---

### 4. Services & payments

Select at least one service.

The application will:
- calculate total cost
- calculate balance after payment
- show remaining amount clearly

No manual calculations.
No Excel formulas.
No errors.

---

### 5. Customer files (Documents)

After saving a customer:
- A **folder is created automatically**
- Folder name includes ID & customer name

You can:
- drag & drop files
- move scanned files from a scanner folder
- open files
- print files
- confirm files

Everything stays **organized per customer**.

---

### 6. Search & customer history

In the **Search** tab you can find customers by:
- ID
- Name
- Phone number

You can:
- open customer details
- see notes
- see files
- see full action history

---

### 7. Dashboard (Overview)

The Dashboard shows:
- all customers
- balances
- serving time
- file status

You can:
- filter by ID / Name / Phone
- sort by ID (ascending / descending)
- export the dashboard to **PDF**
- print clean, readable reports

---

### 8. Important notes

- This app works **offline**
- All data is stored **locally**
- No cloud
- No external servers
- No subscriptions

---

---

## SECTION 2 — TECHNICAL GUIDE  
### (For developers, IT staff, and maintainers)

---

### 1. Architecture philosophy

This project is intentionally:
- **local-first**
- **single-file**
- **easy to audit**
- **easy to maintain**

There is no server.
There is no database engine.
Excel is used as a lightweight datastore.

---

### 2. Technologies used

- **Python 3**
- **PySide6 (Qt)** for GUI
- **openpyxl** for Excel read/write
- Built-in libraries:
  - pathlib
  - json
  - csv
  - hashlib
  - datetime

---

### 3. File structure at runtime

On first run, the app creates:

```

%APPDATA%/ClientManagerV1/
│
├─ clients.xlsx        ← main datastore
├─ users.json          ← credentials & settings
├─ audit_log.csv       ← full history
└─ clients/
├─ 1 - John Doe/
├─ 2 - Maria Papas/
└─ ...

````

This structure is **self-healing** and auto-created.

---

### 4. Excel as datastore

- One row = one customer
- ID is reused using the **smallest available ID**
- No gaps unless rows are intentionally removed
- Headers auto-migrate on version changes

This avoids:
- SQL complexity
- external dependencies
- corruption risk from concurrent editing

---

### 5. Security model

- Passwords are hashed (SHA-256)
- No plaintext passwords
- Audit log records:
  - logins
  - edits
  - file operations
  - confirmations

This is NOT enterprise security.
It is **office-level accountability**.

---

### 6. Building the executable

To build a Windows `.exe`:

```bash
python -m PyInstaller --noconsole --onefile main.py
````

Result:

```
dist/main.exe
```

This exe:

* contains Python
* contains all dependencies
* runs standalone

---

### 7. About decompilation

This project is **not obfuscated**.

Reasons:

* transparency
* auditability
* maintainability

Anyone with Python knowledge can:

* inspect logic
* modify UI
* extend features

This is intentional.

---

### 8. Extending the system

Easy extension points:

* Replace Excel with SQLite
* Add user roles
* Add cloud sync
* Add automatic backups
* Add multi-office support

The architecture supports this.

---

---

## SECTION 3 — LICENSE

This project is released under a **custom license**.

You are allowed to:

* use it
* modify it
* deploy it internally

You are NOT allowed to:

* resell it as-is
* remove author attribution

See the `LICENSE` file for full terms.

---

© Author: [YOUR NAME / BRAND]
All rights reserved.

````

---

# 📜 LICENSE file  
*(ξεχωριστό αρχείο: `LICENSE`)*

Δημιούργησε αρχείο `LICENSE` και βάλε **ΑΥΤΟ ΑΚΡΙΒΩΣ**:

```text
Custom Software License

Copyright (c) 2025 [YOUR NAME]

Permission is hereby granted to use, copy, and modify this software
for personal or internal business use.

The following conditions apply:

1. This software may NOT be sold, sublicensed, or redistributed
   as a commercial product, either in original or modified form.

2. The author attribution must remain visible in the source code
   and documentation.

3. This software is provided "AS IS", without warranty of any kind,
   express or implied, including but not limited to the warranties
   of merchantability or fitness for a particular purpose.

4. The author shall not be liable for any damages arising from
   the use of this software.

This license applies to all files in this repository.

All rights reserved.
````

---