from __future__ import annotations

import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import ffmpeg
import imageio_ffmpeg
from faster_whisper import WhisperModel
from mutagen import File as MutagenFile

ALLOWED_LANGUAGES = {"en", "af"}


@dataclass
class SegmentRecord:
    start: float
    end: float
    text: str
    speaker: str = "Speaker 1"


class TranscriptionEngine:
    def __init__(self, model_size: str = "base", device: str = "auto", compute_type: str | None = None):
        self.model_size = model_size
        self.device = self._detect_device(device)
        self.compute_type = compute_type or ("float16" if self.device == "cuda" else "int8")
        self.ffmpeg_path = self._get_ffmpeg()
        self.model: WhisperModel | None = None

    def _detect_device(self, device: str) -> str:
        if device == "auto":
            return "cuda" if shutil.which("nvidia-smi") else "cpu"
        return device

    def _get_ffmpeg(self) -> str:
        try:
            return imageio_ffmpeg.get_ffmpeg_exe()
        except Exception:
            ffmpeg_path = shutil.which("ffmpeg")
            if ffmpeg_path:
                return ffmpeg_path
            raise RuntimeError("FFmpeg not found. Install imageio-ffmpeg or ffmpeg.")

    def _load_model(self) -> WhisperModel:
        if self.model is None:
            self.model = WhisperModel(self.model_size, device=self.device, compute_type=self.compute_type)
        return self.model

    def media_duration(self, path: Path) -> float | None:
        try:
            mf = MutagenFile(str(path))
            if mf is not None and getattr(mf, "info", None) is not None:
                length = getattr(mf.info, "length", None)
                return float(length) if length is not None else None
        except Exception:
            return None
        return None

    def extract_audio_to_wav(self, src: Path, out_wav: Path, sr: int = 16000) -> Path:
        (
            ffmpeg
            .input(str(src))
            .output(str(out_wav), ac=1, ar=sr, format="wav", vn=None, loglevel="error")
            .overwrite_output()
            .run(cmd=self.ffmpeg_path)
        )
        return out_wav

    def transcribe(self, audio_path: Path) -> dict[str, Any]:
        model = self._load_model()
        duration = self.media_duration(audio_path)

        with tempfile.TemporaryDirectory(prefix="audio_pipe_") as td:
            wav_path = Path(td) / f"{audio_path.stem}_mono.wav"
            self.extract_audio_to_wav(audio_path, wav_path)

            segments_iter, info = model.transcribe(
                str(wav_path),
                task="transcribe",
                vad_filter=True,
                word_timestamps=False,
                temperature=0.0,
            )
            segments = [
                SegmentRecord(start=float(seg.start), end=float(seg.end), text=(seg.text or "").strip())
                for seg in segments_iter
                if (seg.text or "").strip()
            ]

        language = getattr(info, "language", None)
        language_probability = getattr(info, "language_probability", None)
        if duration is None:
            duration = getattr(info, "duration", None)

        return {
            "language": language,
            "language_probability": language_probability,
            "duration": duration,
            "allowed_language": language in ALLOWED_LANGUAGES,
            "segments": [segment.__dict__ for segment in segments],
        }
