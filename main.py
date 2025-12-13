import sys
import json
import csv
import hashlib
from datetime import datetime, date
from pathlib import Path
from typing import Optional, List, Tuple
import html as html_mod

from PySide6.QtCore import Qt, QMarginsF
from PySide6.QtGui import QTextDocument
from PySide6.QtPrintSupport import QPrinter
from PySide6.QtGui import QPageLayout, QPageSize
from PySide6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit,
    QPushButton, QMessageBox, QFrame, QComboBox, QCheckBox, QTabWidget,
    QTableWidget, QTableWidgetItem, QDialog, QTextEdit, QFileDialog,
    QListWidget, QListWidgetItem, QScrollArea, QSizePolicy, QGridLayout
)

from openpyxl import Workbook, load_workbook


# ----------------------------- Material-ish Style (QSS) -----------------------------
MATERIAL_STYLE = """
* { font-family: 'Segoe UI'; font-size: 14px; }
QWidget { background-color: #121212; color: #E6E1E5; }
QFrame#card { background-color: #1E1E1E; border-radius: 16px; }
QLabel#title { font-size: 20px; font-weight: 600; }
QLabel#muted { color: #A1A1A1; }
QLineEdit, QTextEdit, QComboBox {
    background-color: #2A2A2A;
    border-radius: 12px;
    padding: 10px;
    border: 1px solid #3A3A3A;
}
QLineEdit:focus, QTextEdit:focus, QComboBox:focus { border: 2px solid #6750A4; }
QPushButton {
    background-color: #6750A4;
    border-radius: 14px;
    padding: 10px 12px;
    font-weight: 600;
}
QPushButton:hover { background-color: #7F67BE; }
QPushButton#secondary { background-color: #2A2A2A; }
QPushButton#secondary:hover { background-color: #333333; }

QLabel#drop {
    border: 2px dashed #6750A4;
    border-radius: 16px;
    padding: 18px;
    color: #B69DF8;
}
QTabWidget::pane { border: 0px; }
QTabBar::tab {
    background: #1E1E1E;
    padding: 10px 14px;
    border-top-left-radius: 12px;
    border-top-right-radius: 12px;
    margin-right: 6px;
}
QTabBar::tab:selected { background: #2A2A2A; }
QTableWidget {
    background-color: #1E1E1E;
    border-radius: 12px;
    gridline-color: #333;
}
QHeaderView::section {
    background-color: #2A2A2A;
    padding: 8px;
    border: 0px;
    color: #E6E1E5;
}
"""


# ----------------------------- Data Paths (auto-created) -----------------------------
APP_NAME = "ClientManagerV1"

def data_dir() -> Path:
    base = Path.home() / "AppData" / "Roaming" / APP_NAME
    base.mkdir(parents=True, exist_ok=True)
    return base

DATA_DIR = data_dir()
EXCEL_PATH = DATA_DIR / "clients.xlsx"
USERS_PATH = DATA_DIR / "users.json"
AUDIT_PATH = DATA_DIR / "audit_log.csv"
CLIENTS_FOLDER = DATA_DIR / "clients"
CLIENTS_FOLDER.mkdir(parents=True, exist_ok=True)


# ----------------------------- Excel Schema -----------------------------
SHEET_NAME = "Clients"
HEADERS = [
    "ID",
    "ServiceType",        # KEP / Nomika
    "Date",
    "Name",
    "Phone",
    "Taxisnet",
    "Kleidarithmos",      # Confirmed / Rejected
    "AMKA_AMA",           # Confirmed / Rejected
    "Aporipsi",           # Yes / No
    "RequestNotes",       # free text
    "ActionsToday",       # checkboxes list
    "Total",
    "Paid",
    "Balance",
    "FolderPath",
    "FilesConfirmedBy",
    "FilesConfirmedAt",
    "CreatedBy",
    "CreatedAt",
    "LastEditedBy",
    "LastEditedAt",
]


# ----------------------------- Services -----------------------------
SERVICES = [
    ("AMKA / AMA", 160),
    ("Metavoli / Change", 20),
    ("Key number", 20),
    ("AFM / Tax number", 50),
    ("Work", 75),
]


# ----------------------------- Utilities -----------------------------
def now_iso() -> str:
    return datetime.now().isoformat(timespec="seconds")

def safe_float(s: str) -> float:
    s = (s or "").strip().replace(",", ".")
    if not s:
        return 0.0
    return float(s)

def sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def audit_log(user: str, action: str, customer_id: Optional[int] = None, details: str = "") -> None:
    file_exists = AUDIT_PATH.exists()
    with AUDIT_PATH.open("a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if not file_exists:
            w.writerow(["timestamp", "user", "action", "customer_id", "details"])
        w.writerow([now_iso(), user, action, customer_id or "", details])

def read_audit_for_customer(customer_id: int) -> List[List[str]]:
    if not AUDIT_PATH.exists():
        return []
    rows = []
    with AUDIT_PATH.open("r", encoding="utf-8") as f:
        r = csv.reader(f)
        _ = next(r, None)
        for line in r:
            try:
                cid = str(line[3]).strip()
                if cid == str(customer_id):
                    rows.append(line)
            except Exception:
                pass
    return rows

def human_duration(from_iso: str) -> str:
    try:
        dt = datetime.fromisoformat(str(from_iso))
        diff = datetime.now() - dt
        mins = int(diff.total_seconds() // 60)
        hrs = mins // 60
        days = hrs // 24
        if days > 0:
            return f"{days}d {hrs%24}h"
        if hrs > 0:
            return f"{hrs}h {mins%60}m"
        return f"{mins}m"
    except Exception:
        return "-"


# ----------------------------- Storage: Users + Settings -----------------------------
def ensure_users_file() -> None:
    if not USERS_PATH.exists():
        users = {
            "_settings": {"scanner_folder": ""},
            "admin": {"password_hash": sha256("1234"), "created_at": now_iso()}
        }
        USERS_PATH.write_text(json.dumps(users, indent=2), encoding="utf-8")

def load_users() -> dict:
    ensure_users_file()
    return json.loads(USERS_PATH.read_text(encoding="utf-8"))

def save_users(users: dict) -> None:
    USERS_PATH.write_text(json.dumps(users, indent=2), encoding="utf-8")

def verify_user(username: str, password: str) -> bool:
    users = load_users()
    u = users.get(username)
    if not u:
        return False
    return u.get("password_hash") == sha256(password)

def set_user_password(username: str, new_password: str) -> None:
    users = load_users()
    if username not in users:
        users[username] = {"created_at": now_iso()}
    users[username]["password_hash"] = sha256(new_password)
    save_users(users)

def get_scanner_folder() -> str:
    users = load_users()
    return (users.get("_settings", {}) or {}).get("scanner_folder", "") or ""

def set_scanner_folder(path: str) -> None:
    users = load_users()
    users.setdefault("_settings", {})
    users["_settings"]["scanner_folder"] = path
    save_users(users)


# ----------------------------- Storage: Excel (with migration) -----------------------------
def ensure_excel() -> None:
    if not EXCEL_PATH.exists():
        wb = Workbook()
        ws = wb.active
        ws.title = SHEET_NAME
        ws.append(HEADERS)
        wb.save(EXCEL_PATH)
        return

    wb = load_workbook(EXCEL_PATH)
    ws = wb[SHEET_NAME] if SHEET_NAME in wb.sheetnames else wb.active
    existing = [str(c.value or "").strip() for c in ws[1]]
    changed = False
    for h in HEADERS:
        if h not in existing:
            existing.append(h)
            ws.cell(row=1, column=len(existing)).value = h
            changed = True
    if changed:
        wb.save(EXCEL_PATH)

def open_ws():
    ensure_excel()
    wb = load_workbook(EXCEL_PATH)
    ws = wb[SHEET_NAME] if SHEET_NAME in wb.sheetnames else wb.active
    return wb, ws

def headers_map(ws) -> dict:
    cols = {}
    for i, cell in enumerate(ws[1], start=1):
        cols[str(cell.value or "").strip()] = i
    return cols

# ✅ smallest available ID (fills gaps)
def get_next_id() -> int:
    _wb, ws = open_ws()
    cols = headers_map(ws)
    id_col = cols.get("ID", 1)

    used = set()
    for r in range(2, ws.max_row + 1):
        v = ws.cell(r, id_col).value
        try:
            i = int(str(v).strip())
            if i > 0:
                used.add(i)
        except Exception:
            pass

    nxt = 1
    while nxt in used:
        nxt += 1
    return nxt

def find_rows(query_id: str = "", query_name: str = "", query_phone: str = "") -> List[int]:
    _wb, ws = open_ws()
    cols = headers_map(ws)

    query_id = query_id.strip()
    query_name = query_name.strip().lower()
    query_phone = query_phone.strip()

    results = []
    for r in range(2, ws.max_row + 1):
        cid = str(ws.cell(r, cols["ID"]).value or "").strip()
        name = str(ws.cell(r, cols["Name"]).value or "").strip().lower()
        phone = str(ws.cell(r, cols["Phone"]).value or "").strip()

        ok = True
        if query_id:
            ok = ok and (cid == query_id)
        if query_name:
            ok = ok and (query_name in name)
        if query_phone:
            ok = ok and (query_phone in phone)

        if ok and (query_id or query_name or query_phone):
            results.append(r)
    return results

def row_to_record(ws, r: int) -> dict:
    cols = headers_map(ws)
    rec = {}
    for h, c in cols.items():
        rec[h] = ws.cell(r, c).value
    return rec

def update_row(ws, r: int, updates: dict) -> None:
    cols = headers_map(ws)
    for k, v in updates.items():
        if k in cols:
            ws.cell(r, cols[k]).value = v


# ----------------------------- Files -----------------------------
def customer_folder_name(customer_id: int, name: str) -> str:
    safe = "".join(ch for ch in name if ch.isalnum() or ch in (" ", "_", "-")).strip()
    safe = safe[:60] if safe else "Customer"
    return f"{customer_id} - {safe}"

def ensure_customer_folder(customer_id: int, name: str) -> Path:
    folder = CLIENTS_FOLDER / customer_folder_name(customer_id, name)
    folder.mkdir(parents=True, exist_ok=True)
    return folder

def open_in_explorer(path: Path) -> None:
    try:
        import os
        os.startfile(str(path))
    except Exception:
        pass

def print_file_windows(path: Path) -> bool:
    try:
        import os
        os.startfile(str(path), "print")
        return True
    except Exception:
        return False


# ----------------------------- UI Components -----------------------------
class DropZone(QLabel):
    def __init__(self, on_files_dropped):
        super().__init__("📂 Drag & Drop files here")
        self.setObjectName("drop")
        self.setAlignment(Qt.AlignCenter)
        self.setAcceptDrops(True)
        self.on_files_dropped = on_files_dropped

    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()

    def dropEvent(self, event):
        urls = event.mimeData().urls()
        paths = [u.toLocalFile() for u in urls if u.isLocalFile()]
        if paths:
            self.on_files_dropped(paths)


class LoginWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Client Manager v1 – Login")
        self.resize(440, 280)

        root = QVBoxLayout(self)
        root.setContentsMargins(20, 20, 20, 20)
        root.setSpacing(14)

        title = QLabel("Login")
        title.setObjectName("title")
        root.addWidget(title)

        hint = QLabel("Default: admin / 1234 (change it after login)")
        hint.setObjectName("muted")
        root.addWidget(hint)

        card = QFrame()
        card.setObjectName("card")
        c = QVBoxLayout(card)
        c.setContentsMargins(16, 16, 16, 16)
        c.setSpacing(10)

        self.in_user = QLineEdit()
        self.in_user.setPlaceholderText("Username")

        self.in_pass = QLineEdit()
        self.in_pass.setPlaceholderText("Password")
        self.in_pass.setEchoMode(QLineEdit.Password)

        btn_row = QHBoxLayout()
        self.btn_login = QPushButton("Login")
        self.btn_login.clicked.connect(self.do_login)

        self.btn_change = QPushButton("Change admin password")
        self.btn_change.setObjectName("secondary")
        self.btn_change.clicked.connect(self.change_admin_password)

        btn_row.addWidget(self.btn_login)
        btn_row.addWidget(self.btn_change)

        c.addWidget(self.in_user)
        c.addWidget(self.in_pass)
        c.addLayout(btn_row)

        root.addWidget(card)

    def do_login(self):
        u = self.in_user.text().strip()
        p = self.in_pass.text()
        if not u or not p:
            QMessageBox.warning(self, "Missing", "Enter username and password.")
            return
        if verify_user(u, p):
            audit_log(u, "LOGIN")
            self.main = MainWindow(current_user=u)
            self.main.show()
            self.close()
        else:
            QMessageBox.warning(self, "Login failed", "Wrong credentials.")

    def change_admin_password(self):
        dlg = QDialog(self)
        dlg.setWindowTitle("Change admin password")
        dlg.resize(420, 220)
        lay = QVBoxLayout(dlg)
        lay.setContentsMargins(16, 16, 16, 16)
        lay.setSpacing(10)

        p1 = QLineEdit(); p1.setPlaceholderText("New password"); p1.setEchoMode(QLineEdit.Password)
        p2 = QLineEdit(); p2.setPlaceholderText("Repeat new password"); p2.setEchoMode(QLineEdit.Password)

        btn = QPushButton("Save")

        def save():
            if not p1.text() or p1.text() != p2.text():
                QMessageBox.warning(dlg, "Error", "Passwords do not match.")
                return
            set_user_password("admin", p1.text())
            QMessageBox.information(dlg, "OK", "Admin password updated.")
            dlg.accept()

        btn.clicked.connect(save)

        lay.addWidget(QLabel("Set a new password for user 'admin'."))
        lay.addWidget(p1); lay.addWidget(p2); lay.addWidget(btn)
        dlg.exec()


class CustomerDialog(QDialog):
    def __init__(self, current_user: str, excel_row_index: int):
        super().__init__()
        self.current_user = current_user
        self.row_index = excel_row_index
        self.setWindowTitle("Customer details")
        self.resize(900, 620)

        wb, ws = open_ws()
        self.wb = wb
        self.ws = ws
        self.rec = row_to_record(ws, excel_row_index)
        self.customer_id = int(self.rec.get("ID") or 0)

        root = QVBoxLayout(self)
        root.setContentsMargins(16, 16, 16, 16)
        root.setSpacing(12)

        title = QLabel(f"Customer #{self.customer_id} – {self.rec.get('Name')}")
        title.setObjectName("title")
        root.addWidget(title)

        info = QLabel(
            f"Phone: {self.rec.get('Phone')}   |   Balance: {self.rec.get('Balance')}   |   Folder: {self.rec.get('FolderPath')}"
        )
        info.setObjectName("muted")
        root.addWidget(info)

        root.addWidget(QLabel("Notes / Request"))
        self.notes = QTextEdit()
        self.notes.setText(str(self.rec.get("RequestNotes") or ""))
        root.addWidget(self.notes)

        files_row = QHBoxLayout()
        self.list_files = QListWidget()
        self.list_files.setMinimumHeight(140)
        self.list_files.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        files_row.addWidget(self.list_files, 2)

        btns = QVBoxLayout()
        self.btn_open_folder = QPushButton("Open folder")
        self.btn_open_folder.setObjectName("secondary")
        self.btn_open_folder.clicked.connect(self.open_folder)

        self.btn_open_file = QPushButton("Open selected")
        self.btn_open_file.setObjectName("secondary")
        self.btn_open_file.clicked.connect(self.open_selected_file)

        self.btn_print = QPushButton("Print selected")
        self.btn_print.clicked.connect(self.print_selected_file)

        btns.addWidget(self.btn_open_folder)
        btns.addWidget(self.btn_open_file)
        btns.addWidget(self.btn_print)
        btns.addStretch(1)
        files_row.addLayout(btns, 1)

        root.addWidget(QLabel("Customer files"))
        root.addLayout(files_row)

        root.addWidget(QLabel("History (audit log)"))
        self.audit_box = QTextEdit()
        self.audit_box.setReadOnly(True)
        self.audit_box.setMinimumHeight(160)
        root.addWidget(self.audit_box)

        bottom = QHBoxLayout()
        self.btn_refresh = QPushButton("Refresh")
        self.btn_refresh.setObjectName("secondary")
        self.btn_refresh.clicked.connect(self.refresh_views)

        self.btn_save = QPushButton("Save changes")
        self.btn_save.clicked.connect(self.save_changes)

        bottom.addWidget(self.btn_save)
        bottom.addWidget(self.btn_refresh)
        bottom.addStretch(1)
        root.addLayout(bottom)

        self.refresh_views()

    def refresh_views(self):
        self.list_files.clear()
        fp = self.rec.get("FolderPath") or ""
        folder = Path(fp) if fp else None
        if folder and folder.exists():
            for p in sorted(folder.iterdir()):
                if p.is_file():
                    self.list_files.addItem(QListWidgetItem(p.name))

        lines = read_audit_for_customer(self.customer_id)
        if not lines:
            self.audit_box.setPlainText("(no history yet)")
        else:
            txt = []
            for ts, user, action, cid, details in lines[-200:]:
                txt.append(f"{ts} | {user} | {action} | {details}")
            self.audit_box.setPlainText("\n".join(txt))

    def open_folder(self):
        fp = self.rec.get("FolderPath")
        if fp:
            open_in_explorer(Path(fp))

    def selected_file_path(self) -> Optional[Path]:
        fp = self.rec.get("FolderPath") or ""
        if not fp:
            return None
        item = self.list_files.currentItem()
        if not item:
            return None
        p = Path(fp) / item.text()
        return p if p.exists() else None

    def open_selected_file(self):
        p = self.selected_file_path()
        if not p:
            return
        open_in_explorer(p)

    def print_selected_file(self):
        p = self.selected_file_path()
        if not p:
            return
        ok = print_file_windows(p)
        if not ok:
            QMessageBox.information(self, "Print", "Could not print directly. Opening file instead.")
            open_in_explorer(p)
        audit_log(self.current_user, "PRINT", self.customer_id, f"{p.name}")

    def save_changes(self):
        new_notes = self.notes.toPlainText()
        update_row(self.ws, self.row_index, {
            "RequestNotes": new_notes,
            "LastEditedBy": self.current_user,
            "LastEditedAt": now_iso(),
        })
        self.wb.save(EXCEL_PATH)
        audit_log(self.current_user, "EDIT", self.customer_id, "Updated notes")
        QMessageBox.information(self, "Saved", "Customer updated.")
        self.rec = row_to_record(self.ws, self.row_index)
        self.refresh_views()


# ----------------------------- Main Window -----------------------------
class MainWindow(QWidget):
    def __init__(self, current_user: str):
        super().__init__()
        self.user = current_user
        self.setWindowTitle("Client Manager v1")

        # Allow Windows Snap/Tiling + avoid clipping
        self.setMinimumSize(860, 560)
        self.resize(1100, 740)

        self.pending_files: List[str] = []
        self.last_saved_customer_id: Optional[int] = None
        self.last_saved_customer_folder: Optional[Path] = None

        root = QVBoxLayout(self)
        root.setContentsMargins(20, 20, 20, 20)
        root.setSpacing(14)

        header = QHBoxLayout()
        title = QLabel("Client Manager")
        title.setObjectName("title")

        self.lbl_status = QLabel(f"Logged in as: {self.user}   |   Data: {DATA_DIR}")
        self.lbl_status.setObjectName("muted")

        header.addWidget(title)
        header.addStretch(1)
        header.addWidget(self.lbl_status)
        root.addLayout(header)

        self.tabs = QTabWidget()
        root.addWidget(self.tabs)

        # Make each tab scrollable (no more hidden UI)
        self.tab_new_scroll, self.tab_new_inner = self.make_scroll_tab()
        self.tab_search_scroll, self.tab_search_inner = self.make_scroll_tab()
        self.tab_dashboard_scroll, self.tab_dashboard_inner = self.make_scroll_tab()

        self.tabs.addTab(self.tab_new_scroll, "New customer")
        self.tabs.addTab(self.tab_search_scroll, "Search")
        self.tabs.addTab(self.tab_dashboard_scroll, "Dashboard")

        self.build_tab_new(self.tab_new_inner)
        self.build_tab_search(self.tab_search_inner)
        self.build_tab_dashboard(self.tab_dashboard_inner)

        self.refresh_next_id()
        self.refresh_dashboard()

    def make_scroll_tab(self):
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        inner = QWidget()
        inner.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        scroll.setWidget(inner)
        return scroll, inner

    # ---------------- New Customer Tab ----------------
    def build_tab_new(self, parent: QWidget):
        lay = QVBoxLayout(parent)
        lay.setSpacing(14)

        card = QFrame(); card.setObjectName("card")
        c = QVBoxLayout(card); c.setContentsMargins(16, 16, 16, 16); c.setSpacing(10)

        top = QHBoxLayout()
        self.service_type = QComboBox(); self.service_type.addItems(["KEP", "Nomika"])
        self.lbl_next_id = QLabel("Next ID: -"); self.lbl_next_id.setObjectName("muted")

        top.addWidget(QLabel("Service type:"))
        top.addWidget(self.service_type)
        top.addStretch(1)
        top.addWidget(self.lbl_next_id)
        c.addLayout(top)

        self.in_date = QLineEdit(date.today().isoformat())
        self.in_name = QLineEdit(); self.in_name.setPlaceholderText("Name & Surname")
        self.in_phone = QLineEdit(); self.in_phone.setPlaceholderText("Phone number")
        self.in_taxis = QLineEdit(); self.in_taxis.setPlaceholderText("Taxisnet (note)")

        for w in (self.in_date, self.in_name, self.in_phone, self.in_taxis):
            w.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)

        row1 = QHBoxLayout(); row1.addWidget(self.in_date); row1.addWidget(self.in_name)
        row2 = QHBoxLayout(); row2.addWidget(self.in_phone); row2.addWidget(self.in_taxis)
        c.addLayout(row1); c.addLayout(row2)

        row3 = QHBoxLayout()
        self.in_kleid = QComboBox(); self.in_kleid.addItems(["Confirmed", "Rejected"])
        self.in_amka = QComboBox(); self.in_amka.addItems(["Confirmed", "Rejected"])
        self.in_aporr = QComboBox(); self.in_aporr.addItems(["No", "Yes"])

        for w in (self.in_kleid, self.in_amka, self.in_aporr):
            w.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)

        row3.addWidget(QLabel("Kleidarithmos:")); row3.addWidget(self.in_kleid)
        row3.addWidget(QLabel("AMKA/AMA:")); row3.addWidget(self.in_amka)
        row3.addWidget(QLabel("Aporipsi:")); row3.addWidget(self.in_aporr)
        c.addLayout(row3)

        c.addWidget(QLabel("Customer request / notes:"))
        self.in_request = QTextEdit(); self.in_request.setPlaceholderText("Customer request / notes")
        self.in_request.setMinimumHeight(110)
        self.in_request.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        c.addWidget(self.in_request)

        c.addWidget(QLabel("Confirm before saving:"))
        self.cb_confirm_data = QCheckBox("I confirmed the customer data")
        self.cb_confirm_services = QCheckBox("I confirmed the selected services & pricing")
        c.addWidget(self.cb_confirm_data)
        c.addWidget(self.cb_confirm_services)

        c.addWidget(QLabel("Actions today: (select at least one)"))
        self.service_checks: List[QCheckBox] = []
        for name, price in SERVICES:
            cb = QCheckBox(f"{name} ({price})")
            cb.stateChanged.connect(self.recalculate)
            self.service_checks.append(cb)
            c.addWidget(cb)

        pay = QHBoxLayout()
        self.in_paid = QLineEdit(); self.in_paid.setPlaceholderText("Paid today")
        self.in_paid.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self.in_paid.textChanged.connect(self.recalculate)

        self.lbl_total = QLabel("Total: 0"); self.lbl_total.setObjectName("muted")
        self.lbl_balance = QLabel("Balance: 0"); self.lbl_balance.setObjectName("muted")

        btn_calc = QPushButton("Recalculate"); btn_calc.setObjectName("secondary")
        btn_calc.clicked.connect(self.recalculate)

        pay.addWidget(self.in_paid, 2)
        pay.addWidget(btn_calc, 0)
        pay.addStretch(1)
        pay.addWidget(self.lbl_total)
        pay.addWidget(self.lbl_balance)
        c.addLayout(pay)

        btns = QHBoxLayout()
        self.btn_save_customer = QPushButton("Save customer to Excel")
        self.btn_save_customer.clicked.connect(self.save_customer)

        self.btn_open_folder = QPushButton("Open last customer folder")
        self.btn_open_folder.setObjectName("secondary")
        self.btn_open_folder.clicked.connect(self.open_last_folder)

        btns.addWidget(self.btn_save_customer, 2)
        btns.addWidget(self.btn_open_folder, 1)
        c.addLayout(btns)

        lay.addWidget(card)

        # Files card
        card2 = QFrame(); card2.setObjectName("card")
        c2 = QVBoxLayout(card2); c2.setContentsMargins(16, 16, 16, 16); c2.setSpacing(10)

        scanner_row = QHBoxLayout()
        self.in_scanner = QLineEdit(get_scanner_folder())
        self.in_scanner.setPlaceholderText("Scanner folder path (optional)")
        self.in_scanner.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)

        btn_set_scanner = QPushButton("Set scanner folder")
        btn_set_scanner.setObjectName("secondary")
        btn_set_scanner.clicked.connect(self.set_scanner_folder_ui)

        btn_browse_scanner = QPushButton("Browse…")
        btn_browse_scanner.setObjectName("secondary")
        btn_browse_scanner.clicked.connect(self.browse_scanner_folder)

        scanner_row.addWidget(self.in_scanner, 5)
        scanner_row.addWidget(btn_browse_scanner, 0)
        scanner_row.addWidget(btn_set_scanner, 0)
        c2.addLayout(scanner_row)

        c2.addWidget(QLabel("Files (drag & drop after saving customer):"))
        self.drop = DropZone(self.on_files_dropped)
        c2.addWidget(self.drop)

        lists_row = QHBoxLayout()

        pending_col = QVBoxLayout()
        pending_col.addWidget(QLabel("Pending files"))
        self.list_pending = QListWidget()
        self.list_pending.setMinimumHeight(120)
        self.list_pending.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        pending_col.addWidget(self.list_pending)
        lists_row.addLayout(pending_col, 2)

        folder_col = QVBoxLayout()
        folder_col.addWidget(QLabel("Customer folder files"))
        self.list_folder = QListWidget()
        self.list_folder.setMinimumHeight(120)
        self.list_folder.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        folder_col.addWidget(self.list_folder)
        lists_row.addLayout(folder_col, 2)

        scanner_col = QVBoxLayout()
        scanner_col.addWidget(QLabel("Scanner folder files"))
        self.list_scanner = QListWidget()
        self.list_scanner.setMinimumHeight(120)
        self.list_scanner.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        scanner_col.addWidget(self.list_scanner)
        lists_row.addLayout(scanner_col, 2)

        c2.addLayout(lists_row)

        btn_row = QHBoxLayout()
        btn_pick = QPushButton("Add files…")
        btn_pick.setObjectName("secondary")
        btn_pick.clicked.connect(self.pick_files)

        btn_move_pending = QPushButton("Move pending → customer folder")
        btn_move_pending.clicked.connect(self.move_pending_to_customer)

        btn_move_scanner = QPushButton("Move selected scanner → customer folder")
        btn_move_scanner.setObjectName("secondary")
        btn_move_scanner.clicked.connect(self.move_selected_scanner_to_customer)

        btn_refresh_lists = QPushButton("Refresh lists")
        btn_refresh_lists.setObjectName("secondary")
        btn_refresh_lists.clicked.connect(self.refresh_file_lists)

        btn_print = QPushButton("Print selected (customer folder)")
        btn_print.clicked.connect(self.print_selected_customer_file)

        btn_confirm_files = QPushButton("Confirm files")
        btn_confirm_files.clicked.connect(self.confirm_files)

        btn_row.addWidget(btn_pick)
        btn_row.addWidget(btn_move_pending)
        btn_row.addWidget(btn_move_scanner)
        btn_row.addWidget(btn_print)
        btn_row.addWidget(btn_confirm_files)
        btn_row.addWidget(btn_refresh_lists)
        c2.addLayout(btn_row)

        lay.addWidget(card2)
        lay.addStretch(1)

    def refresh_next_id(self):
        self.lbl_next_id.setText(f"Next ID: {get_next_id()}")

    def selected_services(self) -> List[Tuple[str, int]]:
        selected = []
        for cb, (name, price) in zip(self.service_checks, SERVICES):
            if cb.isChecked():
                selected.append((name, price))
        return selected

    def recalculate(self):
        total = sum(price for _, price in self.selected_services())
        try:
            paid = safe_float(self.in_paid.text())
        except Exception:
            paid = 0.0
        balance = total - paid
        self.lbl_total.setText(f"Total: {total:.2f}")
        self.lbl_balance.setText(f"Balance: {balance:.2f}")

    def save_customer(self):
        name = self.in_name.text().strip()
        phone = self.in_phone.text().strip()

        if not name:
            QMessageBox.warning(self, "Missing", "Name is required.")
            return

        services = self.selected_services()
        if not services:
            QMessageBox.warning(self, "Missing", "Select at least one action/service.")
            return

        if not self.cb_confirm_data.isChecked() or not self.cb_confirm_services.isChecked():
            QMessageBox.warning(self, "Confirm required", "You must confirm data and services before saving.")
            return

        total = float(sum(p for _, p in services))
        try:
            paid = safe_float(self.in_paid.text())
        except Exception:
            QMessageBox.warning(self, "Error", "Paid must be a number.")
            return
        balance = total - paid

        customer_id = get_next_id()
        folder = ensure_customer_folder(customer_id, name)

        wb, ws = open_ws()
        ws.append([
            customer_id,
            self.service_type.currentText(),
            self.in_date.text().strip() or date.today().isoformat(),
            name,
            phone,
            self.in_taxis.text().strip(),
            self.in_kleid.currentText(),
            self.in_amka.currentText(),
            self.in_aporr.currentText(),
            self.in_request.toPlainText(),
            ", ".join([f"{n}({p})" for n, p in services]),
            total,
            paid,
            balance,
            str(folder),
            "", "",
            self.user,
            now_iso(),
            self.user,
            now_iso(),
        ])
        wb.save(EXCEL_PATH)

        audit_log(self.user, "CREATE", customer_id, f"Total={total}, Paid={paid}, Balance={balance}")

        self.last_saved_customer_id = customer_id
        self.last_saved_customer_folder = folder

        self.refresh_next_id()
        self.recalculate()
        self.refresh_file_lists()
        self.refresh_dashboard()

        QMessageBox.information(self, "Saved", f"Customer saved with ID {customer_id}.")
        self.clear_form(keep_date=True)

    def clear_form(self, keep_date: bool = True):
        if not keep_date:
            self.in_date.setText(date.today().isoformat())
        self.in_name.clear()
        self.in_phone.clear()
        self.in_taxis.clear()
        self.in_request.clear()
        self.in_paid.clear()
        for cb in self.service_checks:
            cb.setChecked(False)
        self.cb_confirm_data.setChecked(False)
        self.cb_confirm_services.setChecked(False)
        self.pending_files = []
        self.list_pending.clear()
        self.recalculate()

    def open_last_folder(self):
        if not self.last_saved_customer_folder:
            QMessageBox.information(self, "Info", "No customer saved yet.")
            return
        open_in_explorer(self.last_saved_customer_folder)

    def on_files_dropped(self, paths: List[str]):
        self.pending_files.extend(paths)
        self.refresh_pending_list()

    def pick_files(self):
        files, _ = QFileDialog.getOpenFileNames(self, "Select files")
        if files:
            self.pending_files.extend(files)
            self.refresh_pending_list()

    def refresh_pending_list(self):
        self.list_pending.clear()
        for p in self.pending_files:
            self.list_pending.addItem(QListWidgetItem(p))

    def set_scanner_folder_ui(self):
        set_scanner_folder(self.in_scanner.text().strip())
        QMessageBox.information(self, "OK", "Scanner folder saved.")
        self.refresh_file_lists()

    def browse_scanner_folder(self):
        folder = QFileDialog.getExistingDirectory(self, "Select scanner folder")
        if folder:
            self.in_scanner.setText(folder)

    # ✅ IMPORTANT: This existed missing in your version sometimes -> causes crash. Keep it.
    def refresh_file_lists(self):
        # Customer folder files
        self.list_folder.clear()
        if self.last_saved_customer_folder and self.last_saved_customer_folder.exists():
            for p in sorted(self.last_saved_customer_folder.iterdir()):
                if p.is_file():
                    self.list_folder.addItem(QListWidgetItem(p.name))

        # Scanner folder files
        self.list_scanner.clear()
        sp = self.in_scanner.text().strip()
        if sp:
            sf = Path(sp)
            if sf.exists():
                for p in sorted(sf.iterdir()):
                    if p.is_file():
                        self.list_scanner.addItem(QListWidgetItem(p.name))

    def move_pending_to_customer(self):
        if not self.last_saved_customer_folder or self.last_saved_customer_id is None:
            QMessageBox.warning(self, "Missing", "Save a customer first.")
            return
        if not self.pending_files:
            QMessageBox.information(self, "Info", "No pending files selected.")
            return

        moved = 0
        for p in list(self.pending_files):
            src = Path(p)
            if not src.exists():
                continue
            dst = self.last_saved_customer_folder / src.name
            if dst.exists():
                stem, suf = dst.stem, dst.suffix
                i = 1
                while (self.last_saved_customer_folder / f"{stem}_{i}{suf}").exists():
                    i += 1
                dst = self.last_saved_customer_folder / f"{stem}_{i}{suf}"
            try:
                src.replace(dst)
                moved += 1
            except Exception:
                pass

        self.pending_files = []
        self.refresh_pending_list()
        self.refresh_file_lists()
        audit_log(self.user, "ADD_FILES", self.last_saved_customer_id, f"moved_pending={moved}")
        QMessageBox.information(self, "Done", f"Moved {moved} pending files.")

    def move_selected_scanner_to_customer(self):
        if not self.last_saved_customer_folder or self.last_saved_customer_id is None:
            QMessageBox.warning(self, "Missing", "Save a customer first.")
            return
        sp = self.in_scanner.text().strip()
        if not sp:
            QMessageBox.warning(self, "Missing", "Set scanner folder first.")
            return
        sf = Path(sp)
        if not sf.exists():
            QMessageBox.warning(self, "Error", "Scanner folder does not exist.")
            return

        item = self.list_scanner.currentItem()
        if not item:
            QMessageBox.information(self, "Info", "Select a scanner file first.")
            return

        src = sf / item.text()
        if not src.exists():
            return

        dst = self.last_saved_customer_folder / src.name
        if dst.exists():
            stem, suf = dst.stem, dst.suffix
            i = 1
            while (self.last_saved_customer_folder / f"{stem}_{i}{suf}").exists():
                i += 1
            dst = self.last_saved_customer_folder / f"{stem}_{i}{suf}"

        try:
            src.replace(dst)
            audit_log(self.user, "ADD_FILES", self.last_saved_customer_id, f"moved_scanner=1 file={dst.name}")
            self.refresh_file_lists()
            QMessageBox.information(self, "Done", "Moved selected scanner file.")
        except Exception as e:
            QMessageBox.warning(self, "Error", str(e))

    def print_selected_customer_file(self):
        if not self.last_saved_customer_folder or not self.last_saved_customer_folder.exists():
            return
        item = self.list_folder.currentItem()
        if not item:
            return
        p = self.last_saved_customer_folder / item.text()
        if not p.exists():
            return
        ok = print_file_windows(p)
        if not ok:
            open_in_explorer(p)
        if self.last_saved_customer_id is not None:
            audit_log(self.user, "PRINT", self.last_saved_customer_id, p.name)

    def confirm_files(self):
        if self.last_saved_customer_id is None:
            QMessageBox.warning(self, "Missing", "Save a customer first.")
            return

        wb, ws = open_ws()
        cols = headers_map(ws)
        for r in range(2, ws.max_row + 1):
            if str(ws.cell(r, cols["ID"]).value).strip() == str(self.last_saved_customer_id):
                update_row(ws, r, {
                    "FilesConfirmedBy": self.user,
                    "FilesConfirmedAt": now_iso(),
                    "LastEditedBy": self.user,
                    "LastEditedAt": now_iso(),
                })
                wb.save(EXCEL_PATH)
                audit_log(self.user, "CONFIRM_FILES", self.last_saved_customer_id, "Files confirmed")
                QMessageBox.information(self, "OK", "Files confirmed.")
                self.refresh_dashboard()
                return

        QMessageBox.warning(self, "Error", "Customer not found in Excel.")

    # ---------------- Search Tab ----------------
    def build_tab_search(self, parent: QWidget):
        lay = QVBoxLayout(parent)
        lay.setSpacing(14)

        card = QFrame(); card.setObjectName("card")
        c = QVBoxLayout(card); c.setContentsMargins(16, 16, 16, 16); c.setSpacing(10)

        row = QHBoxLayout()
        self.q_id = QLineEdit(); self.q_id.setPlaceholderText("ID")
        self.q_name = QLineEdit(); self.q_name.setPlaceholderText("Name contains…")
        self.q_phone = QLineEdit(); self.q_phone.setPlaceholderText("Phone contains…")

        for w in (self.q_id, self.q_name, self.q_phone):
            w.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)

        btn = QPushButton("Search"); btn.clicked.connect(self.run_search)

        row.addWidget(self.q_id, 1); row.addWidget(self.q_name, 2); row.addWidget(self.q_phone, 2); row.addWidget(btn, 0)
        c.addLayout(row)

        self.table = QTableWidget(0, 7)
        self.table.setHorizontalHeaderLabels(["Row", "ID", "Name", "Phone", "Balance", "Files?", "Created age"])
        self.table.setSelectionBehavior(QTableWidget.SelectRows)
        self.table.cellDoubleClicked.connect(self.open_selected_customer)
        self.table.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        c.addWidget(self.table)

        btns = QHBoxLayout()
        open_btn = QPushButton("Open selected"); open_btn.setObjectName("secondary")
        open_btn.clicked.connect(self.open_selected_customer)
        btns.addWidget(open_btn)
        btns.addStretch(1)
        c.addLayout(btns)

        lay.addWidget(card)
        lay.addStretch(1)

    def run_search(self):
        qid = self.q_id.text().strip()
        qn = self.q_name.text().strip()
        qp = self.q_phone.text().strip()

        if not (qid or qn or qp):
            QMessageBox.warning(self, "Missing", "Enter at least one search field.")
            return

        rows = find_rows(query_id=qid, query_name=qn, query_phone=qp)

        wb, ws = open_ws()
        self.table.setRowCount(0)

        for r in rows:
            rec = row_to_record(ws, r)
            cid = int(rec.get("ID") or 0)
            name = rec.get("Name")
            phone = rec.get("Phone")
            bal = rec.get("Balance")
            folder = Path(rec.get("FolderPath") or "")
            has_files = "Yes" if (folder.exists() and any(p.is_file() for p in folder.iterdir())) else "No"
            age = human_duration(str(rec.get("CreatedAt") or ""))

            row_i = self.table.rowCount()
            self.table.insertRow(row_i)
            self.table.setItem(row_i, 0, QTableWidgetItem(str(r)))
            self.table.setItem(row_i, 1, QTableWidgetItem(str(cid)))
            self.table.setItem(row_i, 2, QTableWidgetItem(str(name)))
            self.table.setItem(row_i, 3, QTableWidgetItem(str(phone)))
            self.table.setItem(row_i, 4, QTableWidgetItem(str(bal)))
            self.table.setItem(row_i, 5, QTableWidgetItem(has_files))
            self.table.setItem(row_i, 6, QTableWidgetItem(age))

        audit_log(self.user, "SEARCH", details=f"id={qid}, name={qn}, phone={qp}")

    def open_selected_customer(self, *_):
        row = self.table.currentRow()
        if row < 0:
            return
        excel_row = int(self.table.item(row, 0).text())
        dlg = CustomerDialog(self.user, excel_row)
        dlg.exec()
        self.refresh_dashboard()

    # ---------------- Dashboard Tab ----------------
    def build_tab_dashboard(self, parent: QWidget):
        lay = QVBoxLayout(parent)
        lay.setSpacing(14)

        card = QFrame(); card.setObjectName("card")
        c = QVBoxLayout(card); c.setContentsMargins(16, 16, 16, 16); c.setSpacing(10)

        grid = QGridLayout()
        grid.setHorizontalSpacing(10)
        grid.setVerticalSpacing(10)

        self.f_id = QLineEdit()
        self.f_id.setPlaceholderText("ID (e.g. 4 or 4-10)")
        self.f_name = QLineEdit()
        self.f_name.setPlaceholderText("Name contains")
        self.f_phone = QLineEdit()
        self.f_phone.setPlaceholderText("Phone contains")

        self.f_priority = QComboBox()
        self.f_priority.addItems(["All", "Has balance", "No balance"])

        self.f_serving = QComboBox()
        self.f_serving.addItems(["All", "Today", "Last 24h", "Last 7 days", "Older than 7 days"])

        # Sort by ID
        self.f_sort_id = QComboBox()
        self.f_sort_id.addItems(["ID ↑ (small→big)", "ID ↓ (big→small)"])

        btn_apply = QPushButton("Apply filters")
        btn_apply.clicked.connect(self.refresh_dashboard)

        btn_clear = QPushButton("Clear")
        btn_clear.setObjectName("secondary")
        btn_clear.clicked.connect(self.clear_dashboard_filters)

        btn_pdf = QPushButton("Export → PDF")
        btn_pdf.setObjectName("secondary")
        btn_pdf.clicked.connect(self.export_dashboard_pdf)  # ✅ correct name

        grid.addWidget(self.f_id,    0, 0)
        grid.addWidget(self.f_name,  0, 1)
        grid.addWidget(self.f_phone, 0, 2)

        grid.addWidget(self.f_priority, 1, 0)
        grid.addWidget(self.f_serving,  1, 1)
        grid.addWidget(self.f_sort_id,  1, 2)

        btns = QHBoxLayout()
        btns.addWidget(btn_apply)
        btns.addWidget(btn_clear)
        btns.addWidget(btn_pdf)
        btns.addStretch(1)

        btns_wrap = QWidget()
        btns_wrap.setLayout(btns)
        grid.addWidget(btns_wrap, 0, 3, 2, 1)

        grid.setColumnStretch(0, 2)
        grid.setColumnStretch(1, 2)
        grid.setColumnStretch(2, 2)
        grid.setColumnStretch(3, 1)

        c.addLayout(grid)

        self.dash = QTableWidget(0, 6)
        self.dash.setHorizontalHeaderLabels(["ID", "Name", "Phone", "Balance", "Files", "Serving time"])
        self.dash.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        c.addWidget(self.dash)

        lay.addWidget(card)
        lay.addStretch(1)

    def clear_dashboard_filters(self):
        self.f_id.clear()
        self.f_name.clear()
        self.f_phone.clear()
        self.f_priority.setCurrentIndex(0)
        self.f_serving.setCurrentIndex(0)
        self.f_sort_id.setCurrentIndex(0)
        self.refresh_dashboard()

    # ✅ FIX: This method name matches the button connection now, and uses Qt6 page layout correctly.
    def export_dashboard_pdf(self):
        try:
            path, _ = QFileDialog.getSaveFileName(
                self,
                "Export Dashboard to PDF",
                "dashboard.pdf",
                "PDF Files (*.pdf)"
            )
            if not path:
                return

            printer = QPrinter(QPrinter.HighResolution)
            printer.setOutputFormat(QPrinter.PdfFormat)
            printer.setOutputFileName(path)

            page_layout = QPageLayout(
                QPageSize(QPageSize.A4),
                QPageLayout.Landscape,
                QMarginsF(15, 15, 15, 15)
            )
            printer.setPageLayout(page_layout)

            # Build HTML table with escaping
            rows_html = []
            for row in range(self.dash.rowCount()):
                cols_html = []
                for col in range(self.dash.columnCount()):
                    item = self.dash.item(row, col)
                    txt = item.text() if item else ""
                    cols_html.append(f"<td>{html_mod.escape(txt)}</td>")
                rows_html.append("<tr>" + "".join(cols_html) + "</tr>")

            html_doc = f"""
            <html>
            <head>
            <meta charset="utf-8"/>
            <style>
                body {{ font-family: Arial; font-size: 10pt; }}
                h2 {{ margin: 0 0 10px 0; }}
                .meta {{ color: #666; font-size: 9pt; margin-bottom: 10px; }}
                table {{ border-collapse: collapse; width: 100%; }}
                th {{ background-color: #f0f0f0; padding: 6px; border: 1px solid #999; text-align: left; }}
                td {{ padding: 6px; border: 1px solid #ccc; }}
                tr:nth-child(even) {{ background-color: #fafafa; }}
            </style>
            </head>
            <body>
                <h2>Client Manager – Dashboard Export</h2>
                <div class="meta">Exported: {html_mod.escape(now_iso())} | User: {html_mod.escape(self.user)}</div>
                <table>
                    <tr>
                        <th>ID</th><th>Name</th><th>Phone</th><th>Balance</th><th>Files</th><th>Serving time</th>
                    </tr>
                    {''.join(rows_html)}
                </table>
            </body>
            </html>
            """

            doc = QTextDocument()
            doc.setHtml(html_doc)
            doc.print(printer)

            QMessageBox.information(self, "Export complete", f"PDF saved to:\n{path}")

        except Exception as e:
            QMessageBox.warning(self, "PDF export error", str(e))

    def refresh_dashboard(self):
        _wb, ws = open_ws()

        fid = self.f_id.text().strip()
        fname = self.f_name.text().strip().lower()
        fphone = self.f_phone.text().strip()
        fpriority = self.f_priority.currentText()
        fserv = self.f_serving.currentText()
        sort_mode = self.f_sort_id.currentText()

        items = []

        def id_allowed(cid_int: int) -> bool:
            if not fid:
                return True
            s = fid.replace(" ", "")
            if "-" in s:
                try:
                    a, b = s.split("-", 1)
                    a = int(a); b = int(b)
                    lo, hi = min(a, b), max(a, b)
                    return lo <= cid_int <= hi
                except Exception:
                    return False
            try:
                return cid_int == int(s)
            except Exception:
                return False

        for r in range(2, ws.max_row + 1):
            rec = row_to_record(ws, r)

            try:
                cid_int = int(rec.get("ID") or 0)
            except Exception:
                cid_int = 0

            name = str(rec.get("Name") or "")
            phone = str(rec.get("Phone") or "")
            bal = safe_float(str(rec.get("Balance") or "0"))
            created = str(rec.get("CreatedAt") or "")
            folder = Path(rec.get("FolderPath") or "")

            if not id_allowed(cid_int):
                continue
            if fname and fname not in name.lower():
                continue
            if fphone and fphone not in phone:
                continue

            if fpriority == "Has balance" and bal <= 0:
                continue
            if fpriority == "No balance" and bal > 0:
                continue

            if fserv != "All":
                try:
                    dt = datetime.fromisoformat(created)
                    diff = datetime.now() - dt
                    if fserv == "Today" and diff.days != 0:
                        continue
                    if fserv == "Last 24h" and diff.total_seconds() > 86400:
                        continue
                    if fserv == "Last 7 days" and diff.days > 7:
                        continue
                    if fserv == "Older than 7 days" and diff.days <= 7:
                        continue
                except Exception:
                    continue

            files = "Yes" if (folder.exists() and any(p.is_file() for p in folder.iterdir())) else "No"
            serving_time = human_duration(created)

            items.append((cid_int, name, phone, bal, files, serving_time))

        reverse = (sort_mode == "ID ↓ (big→small)")
        items.sort(key=lambda x: x[0], reverse=reverse)

        self.dash.setRowCount(0)
        for cid_int, name, phone, bal, files, serving_time in items:
            row_i = self.dash.rowCount()
            self.dash.insertRow(row_i)
            self.dash.setItem(row_i, 0, QTableWidgetItem(str(cid_int)))
            self.dash.setItem(row_i, 1, QTableWidgetItem(name))
            self.dash.setItem(row_i, 2, QTableWidgetItem(phone))
            self.dash.setItem(row_i, 3, QTableWidgetItem(f"{bal:.2f}"))
            self.dash.setItem(row_i, 4, QTableWidgetItem(files))
            self.dash.setItem(row_i, 5, QTableWidgetItem(serving_time))


# ----------------------------- Main -----------------------------
def main():
    ensure_excel()
    ensure_users_file()

    app = QApplication(sys.argv)
    app.setStyleSheet(MATERIAL_STYLE)

    w = LoginWindow()
    w.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
