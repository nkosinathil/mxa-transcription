from __future__ import annotations

import csv
import json
from pathlib import Path
from typing import Any, Callable

from .diarization import SpeakerDiarizer, assign_speakers_to_transcript
from .file_utils import discover_audio_files
from .reporting import write_dashboard
from .transcription import ALLOWED_LANGUAGES, TranscriptionEngine
from .utils import ensure_dir, safe_slug, sha256_file


class AudioPipeline:
    def __init__(
        self,
        model_size: str = "base",
        device: str = "auto",
        compute_type: str | None = None,
        diarization_enabled: bool = True,
    ):
        self.transcriber = TranscriptionEngine(model_size=model_size, device=device, compute_type=compute_type)
        self.diarizer = SpeakerDiarizer(enabled=diarization_enabled)

    def run(
        self,
        input_dir: Path,
        output_dir: Path,
        progress_callback: Callable[[str], None] | None = None,
        item_callback: Callable[[int, int, str], None] | None = None,
        cancel_check: Callable[[], bool] | None = None,
    ) -> dict[str, Any]:
        def emit(msg: str) -> None:
            if progress_callback:
                progress_callback(msg)

        def is_cancelled() -> bool:
            return bool(cancel_check and cancel_check())

        input_dir = input_dir.resolve()
        output_dir = output_dir.resolve()
        ensure_dir(output_dir)
        transcripts_dir = ensure_dir(output_dir / "transcripts")

        emit(f"Scanning for audio files in: {input_dir}")
        audio_files = discover_audio_files(input_dir)
        results: list[dict[str, Any]] = []
        total = len(audio_files)
        emit(f"Found {total} audio file(s).")

        for index, audio_file in enumerate(audio_files, start=1):
            if is_cancelled():
                emit("Processing cancelled by user.")
                break
            if item_callback:
                item_callback(index, total, audio_file.name)

            item = {
                "file": str(audio_file),
                "filename": audio_file.name,
                "stem": safe_slug(audio_file.stem),
                "size_bytes": audio_file.stat().st_size,
                "sha256": sha256_file(audio_file),
                "status": "pending",
                "speaker_count": None,
                "transcript_page": None,
            }
            try:
                emit(f"[{index}/{total}] Transcribing: {audio_file.name}")
                tx = self.transcriber.transcribe(audio_file)
                item.update(
                    {
                        "language": tx.get("language"),
                        "language_probability": tx.get("language_probability"),
                        "duration": tx.get("duration"),
                    }
                )

                if tx.get("language") not in ALLOWED_LANGUAGES:
                    item["status"] = "skipped_language"
                    item["segments"] = []
                    item["speaker_count"] = 0
                    item["note"] = f"Detected language {tx.get('language')} is not supported. Supported: en, af."
                    emit(f"[{index}/{total}] Skipped {audio_file.name}: unsupported language '{tx.get('language')}'.")
                    results.append(item)
                    continue

                emit(f"[{index}/{total}] Running diarization: {audio_file.name}")
                diarization = self.diarizer.diarize(str(audio_file))
                segments = assign_speakers_to_transcript(tx.get("segments", []), diarization.get("speaker_segments", []))
                speaker_labels = sorted({seg.get("speaker", "Speaker 1") for seg in segments})
                item["speaker_count"] = len(speaker_labels) if speaker_labels else diarization.get("speaker_count", 1)
                item["diarization_note"] = diarization.get("note")
                item["segments"] = segments
                item["status"] = "success"

                txt_path = transcripts_dir / f"{item['stem']}.txt"
                json_path = transcripts_dir / f"{item['stem']}.json"

                txt_path.write_text(
                    "\n".join(
                        f"[{seg['speaker']}] {seg['text']}" for seg in item["segments"]
                    ),
                    encoding="utf-8",
                )
                json_path.write_text(json.dumps(item, indent=2, ensure_ascii=False), encoding="utf-8")
                item["txt_path"] = str(txt_path)
                item["json_path"] = str(json_path)
                emit(f"[{index}/{total}] Completed: {audio_file.name}")
            except Exception as exc:
                item["status"] = "failed"
                item["error"] = str(exc)
                emit(f"[{index}/{total}] Failed: {audio_file.name} | {exc}")
            results.append(item)

        summary = {
            "total_files": len(results),
            "transcribed": sum(1 for r in results if r.get("status") == "success"),
            "skipped_language": sum(1 for r in results if r.get("status") == "skipped_language"),
            "failed": sum(1 for r in results if r.get("status") == "failed"),
            "results": results,
            "diarization_available": self.diarizer.available,
            "diarization_note": self.diarizer.error_message,
            "cancelled": is_cancelled(),
        }

        emit("Building dashboard...")
        dashboard_index = write_dashboard(summary, output_dir)
        summary["dashboard_index"] = str(dashboard_index)

        (output_dir / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
        with (output_dir / "summary.csv").open("w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["filename", "size_bytes", "language", "duration", "speaker_count", "status", "sha256"])
            for item in results:
                writer.writerow([
                    item.get("filename"),
                    item.get("size_bytes"),
                    item.get("language"),
                    item.get("duration"),
                    item.get("speaker_count"),
                    item.get("status"),
                    item.get("sha256"),
                ])

        emit(f"Done. Dashboard: {dashboard_index}")
        return summary
