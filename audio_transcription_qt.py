from __future__ import annotations

import os
import sys
import webbrowser
from pathlib import Path

from PySide6.QtCore import QObject, QThread, Qt, Signal, Slot
from PySide6.QtGui import QDesktopServices
from PySide6.QtCore import QUrl
from PySide6.QtWidgets import (
    QApplication,
    QCheckBox,
    QComboBox,
    QFileDialog,
    QFormLayout,
    QGridLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QPlainTextEdit,
    QProgressBar,
    QSizePolicy,
    QVBoxLayout,
    QWidget,
)

from audio_pipeline.pipeline import AudioPipeline

APP_TITLE = "Audio Transcription Qt"


class PipelineWorker(QObject):
    progress = Signal(str)
    percent = Signal(int)
    status = Signal(str)
    finished = Signal(dict)
    failed = Signal(str)

    def __init__(self, input_dir: str, output_dir: str, model: str, device: str, compute_type: str, diarization: bool):
        super().__init__()
        self.input_dir = input_dir
        self.output_dir = output_dir
        self.model = model
        self.device = device
        self.compute_type = compute_type or None
        self.diarization = diarization
        self._cancelled = False

    def cancel(self) -> None:
        self._cancelled = True

    def _is_cancelled(self) -> bool:
        return self._cancelled

    @Slot()
    def run(self) -> None:
        try:
            pipeline = AudioPipeline(
                model_size=self.model,
                device=self.device,
                compute_type=self.compute_type,
                diarization_enabled=self.diarization,
            )

            def on_item(current: int, total: int, name: str) -> None:
                pct = 0 if total <= 0 else int(((current - 1) / total) * 100)
                self.percent.emit(max(0, min(100, pct)))
                self.status.emit(f"Processing {current}/{total}: {name}")

            summary = pipeline.run(
                Path(self.input_dir),
                Path(self.output_dir),
                progress_callback=self.progress.emit,
                item_callback=on_item,
                cancel_check=self._is_cancelled,
            )
            self.percent.emit(100)
            self.finished.emit(summary)
        except Exception as exc:
            self.failed.emit(str(exc))


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle(APP_TITLE)
        self.resize(980, 700)
        self.worker_thread: QThread | None = None
        self.worker: PipelineWorker | None = None
        self.last_dashboard: str | None = None
        self._build_ui()
        self._apply_style()

    def _build_ui(self) -> None:
        central = QWidget()
        self.setCentralWidget(central)
        root = QVBoxLayout(central)
        root.setContentsMargins(18, 18, 18, 18)
        root.setSpacing(14)

        title = QLabel("Audio Transcription and Speaker Analysis")
        title.setObjectName("titleLabel")
        subtitle = QLabel("Scan a folder, detect English or Afrikaans audio, transcribe it, estimate speakers, and generate an HTML dashboard.")
        subtitle.setWordWrap(True)
        subtitle.setObjectName("subtitleLabel")
        root.addWidget(title)
        root.addWidget(subtitle)

        input_group = QGroupBox("Input and Output")
        form = QGridLayout(input_group)
        form.setHorizontalSpacing(10)
        form.setVerticalSpacing(10)

        self.input_edit = QLineEdit()
        self.output_edit = QLineEdit()
        browse_in = QPushButton("Browse…")
        browse_out = QPushButton("Browse…")
        browse_in.clicked.connect(self.pick_input)
        browse_out.clicked.connect(self.pick_output)

        form.addWidget(QLabel("Input folder"), 0, 0)
        form.addWidget(self.input_edit, 0, 1)
        form.addWidget(browse_in, 0, 2)
        form.addWidget(QLabel("Output folder"), 1, 0)
        form.addWidget(self.output_edit, 1, 1)
        form.addWidget(browse_out, 1, 2)
        root.addWidget(input_group)

        options_group = QGroupBox("Processing Options")
        options = QGridLayout(options_group)
        options.setHorizontalSpacing(10)
        options.setVerticalSpacing(10)

        self.model_combo = QComboBox()
        self.model_combo.addItems(["tiny", "base", "small", "medium", "large-v3"])
        self.model_combo.setCurrentText("base")

        self.device_combo = QComboBox()
        self.device_combo.addItems(["auto", "cpu", "cuda"])

        self.compute_edit = QLineEdit()
        self.compute_edit.setPlaceholderText("Optional, e.g. int8, float16")

        self.diarization_check = QCheckBox("Enable speaker diarization")
        self.diarization_check.setChecked(True)

        options.addWidget(QLabel("Whisper model"), 0, 0)
        options.addWidget(self.model_combo, 0, 1)
        options.addWidget(QLabel("Device"), 0, 2)
        options.addWidget(self.device_combo, 0, 3)
        options.addWidget(QLabel("Compute type"), 1, 0)
        options.addWidget(self.compute_edit, 1, 1, 1, 3)
        options.addWidget(self.diarization_check, 2, 0, 1, 4)
        root.addWidget(options_group)

        progress_group = QGroupBox("Progress")
        progress_layout = QVBoxLayout(progress_group)
        self.status_label = QLabel("Ready.")
        self.progress_bar = QProgressBar()
        self.progress_bar.setRange(0, 100)
        self.progress_bar.setValue(0)
        self.log_box = QPlainTextEdit()
        self.log_box.setReadOnly(True)
        progress_layout.addWidget(self.status_label)
        progress_layout.addWidget(self.progress_bar)
        progress_layout.addWidget(self.log_box)
        root.addWidget(progress_group, 1)

        button_row = QHBoxLayout()
        self.start_btn = QPushButton("Begin Analysis")
        self.cancel_btn = QPushButton("Cancel")
        self.open_btn = QPushButton("Open Dashboard")
        self.open_folder_btn = QPushButton("Open Output Folder")
        self.cancel_btn.setEnabled(False)
        self.open_btn.setEnabled(False)
        self.open_folder_btn.setEnabled(False)

        self.start_btn.clicked.connect(self.start_processing)
        self.cancel_btn.clicked.connect(self.cancel_processing)
        self.open_btn.clicked.connect(self.open_dashboard)
        self.open_folder_btn.clicked.connect(self.open_output_folder)

        button_row.addWidget(self.start_btn)
        button_row.addWidget(self.cancel_btn)
        button_row.addStretch(1)
        button_row.addWidget(self.open_folder_btn)
        button_row.addWidget(self.open_btn)
        root.addLayout(button_row)

    def _apply_style(self) -> None:
        self.setStyleSheet(
            """
            QWidget { background: #141414; color: #f1f1f1; font-family: Segoe UI, Arial, sans-serif; font-size: 13px; }
            QGroupBox { border: 1px solid #333; border-radius: 10px; margin-top: 10px; padding-top: 14px; font-weight: 600; }
            QGroupBox::title { subcontrol-origin: margin; left: 10px; padding: 0 4px; }
            QLineEdit, QComboBox, QPlainTextEdit { background: #1f1f1f; border: 1px solid #3a3a3a; border-radius: 8px; padding: 8px; }
            QPushButton { background: #2d2d2d; border: 1px solid #454545; border-radius: 8px; padding: 9px 14px; }
            QPushButton:hover { background: #3a3a3a; }
            QPushButton:disabled { color: #888; background: #222; }
            QProgressBar { background: #1f1f1f; border: 1px solid #3a3a3a; border-radius: 8px; text-align: center; }
            QProgressBar::chunk { background: #6c63ff; border-radius: 7px; }
            #titleLabel { font-size: 24px; font-weight: 700; }
            #subtitleLabel { color: #bbbbbb; }
            """
        )

    def append_log(self, message: str) -> None:
        self.log_box.appendPlainText(message)

    def pick_input(self) -> None:
        path = QFileDialog.getExistingDirectory(self, "Select input folder")
        if path:
            self.input_edit.setText(path)
            if not self.output_edit.text().strip():
                self.output_edit.setText(str(Path(path) / "audio_output"))

    def pick_output(self) -> None:
        path = QFileDialog.getExistingDirectory(self, "Select output folder")
        if path:
            self.output_edit.setText(path)

    def validate(self) -> bool:
        input_dir = Path(self.input_edit.text().strip())
        output_dir = self.output_edit.text().strip()
        if not input_dir.exists() or not input_dir.is_dir():
            QMessageBox.warning(self, APP_TITLE, "Please select a valid input folder.")
            return False
        if not output_dir:
            QMessageBox.warning(self, APP_TITLE, "Please select an output folder.")
            return False
        return True

    def start_processing(self) -> None:
        if not self.validate():
            return

        self.log_box.clear()
        self.progress_bar.setValue(0)
        self.status_label.setText("Starting…")
        self.last_dashboard = None
        self.open_btn.setEnabled(False)
        self.open_folder_btn.setEnabled(False)

        self.worker_thread = QThread(self)
        self.worker = PipelineWorker(
            self.input_edit.text().strip(),
            self.output_edit.text().strip(),
            self.model_combo.currentText(),
            self.device_combo.currentText(),
            self.compute_edit.text().strip(),
            self.diarization_check.isChecked(),
        )
        self.worker.moveToThread(self.worker_thread)
        self.worker_thread.started.connect(self.worker.run)
        self.worker.progress.connect(self.append_log)
        self.worker.percent.connect(self.progress_bar.setValue)
        self.worker.status.connect(self.status_label.setText)
        self.worker.finished.connect(self.on_finished)
        self.worker.failed.connect(self.on_failed)
        self.worker.finished.connect(self.worker_thread.quit)
        self.worker.failed.connect(self.worker_thread.quit)
        self.worker_thread.finished.connect(self.cleanup_worker)

        self.start_btn.setEnabled(False)
        self.cancel_btn.setEnabled(True)
        self.worker_thread.start()

    def cancel_processing(self) -> None:
        if self.worker:
            self.worker.cancel()
            self.append_log("Cancellation requested. Waiting for current file to finish…")
            self.status_label.setText("Cancelling…")
            self.cancel_btn.setEnabled(False)

    @Slot(dict)
    def on_finished(self, summary: dict) -> None:
        self.start_btn.setEnabled(True)
        self.cancel_btn.setEnabled(False)
        self.last_dashboard = summary.get("dashboard_index")
        self.status_label.setText("Finished." if not summary.get("cancelled") else "Cancelled.")
        self.open_btn.setEnabled(bool(self.last_dashboard))
        self.open_folder_btn.setEnabled(True)
        self.append_log(f"Transcribed: {summary.get('transcribed', 0)}")
        self.append_log(f"Skipped language: {summary.get('skipped_language', 0)}")
        self.append_log(f"Failed: {summary.get('failed', 0)}")
        QMessageBox.information(self, APP_TITLE, f"Processing complete. Dashboard saved to:\n{self.last_dashboard}")

    @Slot(str)
    def on_failed(self, error: str) -> None:
        self.start_btn.setEnabled(True)
        self.cancel_btn.setEnabled(False)
        self.status_label.setText("Failed.")
        self.append_log(f"ERROR: {error}")
        QMessageBox.critical(self, APP_TITLE, error)

    def cleanup_worker(self) -> None:
        if self.worker:
            self.worker.deleteLater()
            self.worker = None
        if self.worker_thread:
            self.worker_thread.deleteLater()
            self.worker_thread = None

    def open_dashboard(self) -> None:
        if self.last_dashboard and Path(self.last_dashboard).exists():
            QDesktopServices.openUrl(QUrl.fromLocalFile(self.last_dashboard))

    def open_output_folder(self) -> None:
        out = self.output_edit.text().strip()
        if out and Path(out).exists():
            QDesktopServices.openUrl(QUrl.fromLocalFile(out))


def main() -> None:
    app = QApplication(sys.argv)
    app.setApplicationName(APP_TITLE)
    win = MainWindow()
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
