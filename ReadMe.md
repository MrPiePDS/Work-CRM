# Client Manager v1

### Local Office CRM — Design, Architecture & Usage Documentation

---

## Overview

**Client Manager v1** is a **local-first desktop CRM application** designed for small offices that require **clarity, accountability, and reliability** without reliance on internet connectivity or cloud services.

It replaces error-prone Excel workflows with:

* structured data entry
* automatic calculations
* organized document management
* full action traceability

The system is intentionally simple, transparent, and maintainable.

---

## SECTION 1 — USER GUIDE

### (For everyday users — no technical knowledge required)

---

### 1. Purpose of the Application

Client Manager allows office staff to:

* register customers quickly
* manage services and payments
* store and retrieve documents per customer
* track actions and responsibilities

All operations are performed **offline**, on the local computer.

---

### 2. Login & Accountability

Upon launch, users are presented with a login screen.

Each user:

* logs in with personal credentials
* is automatically associated with every action they perform

The system records:

* customer creation
* edits and updates
* file confirmations

This ensures **clear responsibility and internal protection**.

---

### 3. Creating a New Customer

Navigate to the **New Customer** tab and complete the required fields:

* Service category (e.g. KEP / Legal)
* Full name
* Phone number
* Optional notes

The date and customer ID are generated automatically.

Before saving, the user must **explicitly confirm** the entered data.
This confirmation step exists to prevent accidental or incorrect entries.

---

### 4. Services & Payments

Each customer may be assigned one or more services.

The application automatically:

* calculates total cost
* applies payments
* displays remaining balance clearly

No manual calculations are required.

---

### 5. Document Management

Once a customer is saved:

* a dedicated folder is created automatically
* the folder includes the customer ID and name

Users can:

* drag & drop files
* move scanned documents
* open and print files
* confirm document completeness

All documents remain **strictly organized per customer**.

---

### 6. Search & Customer History

The **Search** tab allows retrieval by:

* customer ID
* name
* phone number

From the results, users can:

* open customer details
* view notes
* access documents
* review full action history

---

### 7. Dashboard & Reporting

The Dashboard provides an overview of:

* all customers
* balances
* service status
* document confirmation state

Available actions:

* filtering by ID / Name / Phone
* sorting results
* exporting reports to PDF
* printing clean summaries

---

### 8. Operating Principles

* Fully offline operation
* Local data storage only
* No cloud services
* No subscriptions
* No external dependencies

---

## SECTION 2 — TECHNICAL DOCUMENTATION

### (For developers, IT staff, and maintainers)

---

### 1. Design Philosophy

Client Manager is intentionally designed to be:

* local-first
* single-instance
* easy to audit
* easy to maintain

There is:

* no server
* no background services
* no external database engine

---

### 2. Technology Stack

* Python 3
* PySide6 (Qt) — graphical interface
* openpyxl — Excel read/write

Standard libraries:

* pathlib
* json
* csv
* hashlib
* datetime

---

### 3. Runtime File Structure

On first launch, the application initializes the following structure:

```
%APPDATA%/ClientManagerV1/
│
├─ clients.xlsx        # Primary datastore
├─ users.json          # User credentials & settings
├─ audit_log.csv       # Complete action history
└─ clients/
   ├─ 1 - John Doe/
   ├─ 2 - Maria Papas/
   └─ ...
```

The structure is auto-created and self-healing.

---

### 4. Excel as Datastore

Excel is intentionally used as a lightweight datastore:

* One row per customer
* IDs assigned using the smallest available number
* Controlled access through the application only
* Automatic header migration between versions

This avoids:

* SQL complexity
* additional dependencies
* concurrency corruption

---

### 5. Security Model

* Passwords stored as SHA-256 hashes
* No plaintext credentials
* Full audit logging of:

  * logins
  * edits
  * file operations
  * confirmations

This model provides **office-level accountability**, not enterprise security.

---

### 6. Building the Executable

To generate a standalone Windows executable:

```bash
python -m PyInstaller --noconsole --onefile main.py
```

Output:

```
dist/main.exe
```

The executable includes:

* Python runtime
* all dependencies
* no external requirements

---

### 7. Transparency & Decompilation

The application is **not obfuscated by design**.

Reasons:

* transparency
* long-term maintainability
* ease of extension

The source is meant to be readable and adaptable.

---

### 8. Extension Possibilities

The architecture allows future expansion:

* migration to SQLite
* role-based permissions
* cloud synchronization
* automated backups
* multi-office support

---

## SECTION 3 — LICENSE

This project is released under a **custom internal-use license**.

Permitted:

* internal use
* modification
* deployment within an organization

Not permitted:

* resale
* sublicensing
* removal of author attribution

Refer to the `LICENSE` file for full terms.

---

© 2025 — Author: [PanosPDS/CRM]
All rights reserved.

