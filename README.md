# Audio Transcription Qt App

This is a Qt-based desktop application that scans a folder for audio files, detects language, transcribes English and Afrikaans audio, estimates speakers, labels transcript text by speaker, and generates an HTML dashboard.

## Features

- Folder-based audio discovery
- Supports: `.wav`, `.mp3`, `.m4a`, `.aac`, `.flac`, `.ogg`, `.opus`, `.wma`
- Language detection via Faster-Whisper
- Transcription for English and Afrikaans only
- Speaker diarization with `pyannote.audio` when available
- HTML dashboard with:
  - file name
  - file size
  - audio playback
  - transcript link
  - detected language
  - duration
  - distinct speaker count
- Qt desktop GUI with:
  - browse input/output folders
  - model/device settings
  - progress bar
  - live log output
  - cancel button
  - open dashboard button

## Installation

Create and activate an environment, then install requirements:

```bash
pip install -r requirements.txt
```

## Optional diarization token

For speaker diarization, set one of these environment variables:

```bash
set HUGGINGFACE_TOKEN=your_token_here
```

or

```bash
set HF_TOKEN=your_token_here
```

Without a token, the app will still transcribe but will fall back to a single speaker label.

## Run the Qt app

```bash
python run_audio_qt.py
```

## Run the CLI version

```bash
python run_audio_pipeline.py --input "C:\input_folder" --output "C:\output_folder"
```

## Notes

- Larger Whisper models improve accuracy but are slower.
- `cuda` is faster if NVIDIA GPU support is available.
- Cancel waits for the current file to finish safely before stopping.
