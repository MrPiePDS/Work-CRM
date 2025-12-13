import sys
from PySide6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QLineEdit, QPushButton, QComboBox, QFrame
)
from PySide6.QtCore import Qt


MATERIAL_STYLE = """
* {
    font-family: 'Segoe UI';
    font-size: 14px;
}

/* Window */
QWidget {
    background-color: #121212;
    color: #E6E1E5;
}

/* Cards */
QFrame {
    background-color: #1E1E1E;
    border-radius: 16px;
}

/* Labels */
QLabel#title {
    font-size: 20px;
    font-weight: 600;
}

/* Inputs */
QLineEdit, QComboBox {
    background-color: #2A2A2A;
    border-radius: 12px;
    padding: 10px;
    border: 1px solid #3A3A3A;
}

QLineEdit:focus, QComboBox:focus {
    border: 2px solid #6750A4;
}

/* Buttons */
QPushButton {
    background-color: #6750A4;
    border-radius: 14px;
    padding: 10px;
    font-weight: 600;
}

QPushButton:hover {
    background-color: #7F67BE;
}

QPushButton#secondary {
    background-color: #2A2A2A;
}

QPushButton#secondary:hover {
    background-color: #333333;
}

/* Drop area */
QLabel#drop {
    border: 2px dashed #6750A4;
    border-radius: 16px;
    padding: 30px;
    color: #B69DF8;
}
"""


class DemoWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Client Manager – Demo (Material 3)")
        self.resize(640, 560)
        self.setStyleSheet(MATERIAL_STYLE)

        root = QVBoxLayout(self)
        root.setSpacing(16)
        root.setContentsMargins(20, 20, 20, 20)

        # ---- Header
        header = QHBoxLayout()
        title = QLabel("Client Manager")
        title.setObjectName("title")

        stats = QLabel("Next ID: 12   |   Άτομα: 8   |   Σύνολο €: 1.240")
        stats.setStyleSheet("color:#A1A1A1")

        header.addWidget(title)
        header.addStretch()
        header.addWidget(stats)
        root.addLayout(header)

        # ---- Card: Form
        card = QFrame()
        card_layout = QVBoxLayout(card)
        card_layout.setSpacing(12)
        card_layout.setContentsMargins(20, 20, 20, 20)

        card_layout.addWidget(QLabel("Νέα καταχώρηση"))

        self.name = QLineEdit()
        self.name.setPlaceholderText("Όνομα πελάτη")

        self.phone = QLineEdit()
        self.phone.setPlaceholderText("Τηλέφωνο")

        self.revenue = QLineEdit()
        self.revenue.setPlaceholderText("Έσοδα (€)")

        self.status = QComboBox()
        self.status.addItems(["Ναι", "Όχι"])

        card_layout.addWidget(self.name)
        card_layout.addWidget(self.phone)
        card_layout.addWidget(self.revenue)
        card_layout.addWidget(self.status)

        root.addWidget(card)

        # ---- Drop zone
        drop = QLabel("📂 Ρίξε εδώ αρχεία (Drag & Drop)")
        drop.setObjectName("drop")
        drop.setAlignment(Qt.AlignCenter)
        root.addWidget(drop)

        # ---- Buttons
        btns = QHBoxLayout()

        save = QPushButton("Καταχώρηση")
        open_folder = QPushButton("Άνοιγμα φακέλου")
        open_folder.setObjectName("secondary")

        btns.addWidget(save)
        btns.addWidget(open_folder)

        root.addLayout(btns)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    w = DemoWindow()
    w.show()
    sys.exit(app.exec())
