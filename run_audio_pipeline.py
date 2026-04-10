from pathlib import Path
import argparse

from audio_pipeline.pipeline import AudioPipeline


def main() -> None:
    parser = argparse.ArgumentParser(description="Folder-based audio transcription and diarization pipeline")
    parser.add_argument("--input", required=True, help="Folder containing audio files")
    parser.add_argument("--output", required=True, help="Folder where reports will be written")
    parser.add_argument("--model", default="base", help="Faster-Whisper model size, e.g. tiny, base, small, medium, large-v3")
    parser.add_argument("--device", default="auto", help="auto, cpu, or cuda")
    parser.add_argument("--compute-type", default=None, help="Override faster-whisper compute type")
    parser.add_argument("--disable-diarization", action="store_true", help="Disable speaker diarization")
    args = parser.parse_args()

    pipeline = AudioPipeline(
        model_size=args.model,
        device=args.device,
        compute_type=args.compute_type,
        diarization_enabled=not args.disable_diarization,
    )
    summary = pipeline.run(Path(args.input), Path(args.output))
    print(f"Done. Dashboard: {summary['dashboard_index']}")


if __name__ == "__main__":
    main()
