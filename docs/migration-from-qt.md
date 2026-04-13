# Migration from Qt Desktop App

This document explains what changed when moving from the desktop Qt application
to the web application, and what stayed the same.

---

## What Stayed the Same

The **core audio processing logic** is unchanged. All of these files were copied
directly into `python-backend/app/legacy_logic/`:

| Original file | New location | Changed? |
|--------------|-------------|----------|
| `audio_pipeline/transcription.py` | `legacy_logic/transcription.py` | No |
| `audio_pipeline/diarization.py` | `legacy_logic/diarization.py` | No |
| `audio_pipeline/file_utils.py` | `legacy_logic/file_utils.py` | No |
| `audio_pipeline/utils.py` | `legacy_logic/utils.py` | No |
| `audio_pipeline/reporting.py` | `legacy_logic/reporting.py` | No (adapted for web) |
| `audio_pipeline/pipeline.py` | `app/tasks/transcription_tasks.py` | Adapted |

The transcription quality, language detection, and speaker diarization
all work identically to the desktop app.

---

## What Changed

### UI Layer
| Desktop App | Web App |
|-------------|---------|
| Qt MainWindow | Browser-based PHP views |
| QProgressBar | HTML progress bar (polled via AJAX) |
| QPlainTextEdit (log box) | `job_events` table + live AJAX polling |
| QFileDialog (browse folders) | File upload input in browser |
| "Begin Analysis" button | "Start Processing" button in web UI |
| "Open Dashboard" button | Results page in browser |

### File Handling
| Desktop App | Web App |
|-------------|---------|
| Local folder scan | Upload individual files via browser |
| Local output folder | MinIO object storage |
| Local HTML dashboard | Database-backed results page |
| CSV/JSON in output folder | MinIO (downloadable via web) |

### Processing Model
| Desktop App | Web App |
|-------------|---------|
| QThread (blocking UI thread) | Celery (background worker process) |
| `_cancelled` flag | Celery task cancellation |
| Single user, local machine | Multi-user, role-based access |
| No authentication | Keycloak OIDC login |
| No audit trail | `audit_logs` table |

---

## For End Users

**Before:** Install Python, install PySide6, run `python run_audio_qt.py`
on your own computer. Browse to an input folder.

**After:** Open a web browser, go to `http://192.168.1.66`, log in with
your existing account, create a case, upload a file, click Start.

All processing now happens on the server. You can close your browser
and come back later – the job will still be running.

---

## For Administrators

**Before:** Each user installs the app on their own computer. Updates require
visiting each machine.

**After:** Deploy once to the server. All users automatically get updates.
The Keycloak admin controls who can access the system and what they can do.

---

## Known Limitations in this Version

1. **Batch upload**: The web UI currently processes one file at a time.
   To add multi-file batch processing, add a loop in `UploadController`
   and a batch endpoint to the Python API.

2. **Real-time streaming**: Progress updates use polling (every 3 seconds).
   A future version could use WebSockets or Server-Sent Events for true
   real-time updates.

3. **Dashboard HTML**: The original Qt app generated an HTML dashboard file.
   In the web app, the dashboard is replaced by the built-in results page.
   The old `reporting.py` is preserved in `legacy_logic/` in case it's needed.

4. **Local file access**: The web app cannot access files on a user's local
   network share directly – files must be uploaded through the browser.

---

## Adding a New Processing Workflow

To add a new type of analysis (e.g. sentiment analysis, keyword extraction):

1. **Python:** Add a new Celery task in `python-backend/app/tasks/`
2. **Python:** Add a new API endpoint in `python-backend/app/api/`
3. **Database:** Add a new column to `results` or a new table for the output
4. **PHP:** Add a button/form in the relevant view
5. **PHP:** Add a new method to `PythonApiClient.php` to call the new endpoint
6. **PHP:** Update the results view to display the new output
