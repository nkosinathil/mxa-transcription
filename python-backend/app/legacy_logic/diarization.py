from __future__ import annotations

import os
from typing import Any


class SpeakerDiarizer:
    def __init__(self, enabled: bool = True):
        self.enabled = enabled
        self.pipeline = None
        self.error_message = None
        self.available = False
        if not enabled:
            self.error_message = "diarization_disabled"
            return

        token = os.getenv("HUGGINGFACE_TOKEN") or os.getenv("HF_TOKEN")
        if not token:
            self.error_message = "missing_huggingface_token"
            return

        try:
            from pyannote.audio import Pipeline

            self.pipeline = Pipeline.from_pretrained(
                "pyannote/speaker-diarization-3.1",
                use_auth_token=token,
            )
            self.available = True
        except Exception as exc:
            self.error_message = str(exc)
            self.pipeline = None
            self.available = False

    def diarize(self, audio_path: str) -> dict[str, Any]:
        if not self.available or self.pipeline is None:
            return {
                "available": False,
                "speaker_count": 1,
                "speaker_segments": [],
                "note": self.error_message or "diarization_unavailable",
            }

        diarization = self.pipeline(audio_path)
        items: list[dict[str, Any]] = []
        speakers = set()
        for turn, _, speaker in diarization.itertracks(yield_label=True):
            speakers.add(speaker)
            items.append(
                {
                    "start": float(turn.start),
                    "end": float(turn.end),
                    "speaker": str(speaker),
                }
            )

        return {
            "available": True,
            "speaker_count": len(speakers) if speakers else 1,
            "speaker_segments": items,
            "note": None,
        }


def assign_speakers_to_transcript(
    transcript_segments: list[dict[str, Any]],
    diarization_segments: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    if not transcript_segments:
        return []
    if not diarization_segments:
        for seg in transcript_segments:
            seg["speaker"] = seg.get("speaker") or "Speaker 1"
        return transcript_segments

    normalized_labels: dict[str, str] = {}
    counter = 1
    for item in diarization_segments:
        raw = item["speaker"]
        if raw not in normalized_labels:
            normalized_labels[raw] = f"Speaker {counter}"
            counter += 1

    for seg in transcript_segments:
        seg_mid = (float(seg["start"]) + float(seg["end"])) / 2.0
        best_label = None
        best_overlap = -1.0
        for dseg in diarization_segments:
            overlap_start = max(float(seg["start"]), float(dseg["start"]))
            overlap_end = min(float(seg["end"]), float(dseg["end"]))
            overlap = max(0.0, overlap_end - overlap_start)
            contains_mid = float(dseg["start"]) <= seg_mid <= float(dseg["end"])
            score = overlap + (0.0001 if contains_mid else 0.0)
            if score > best_overlap:
                best_overlap = score
                best_label = dseg["speaker"]
        seg["speaker"] = normalized_labels.get(best_label, "Speaker 1")

    return transcript_segments
