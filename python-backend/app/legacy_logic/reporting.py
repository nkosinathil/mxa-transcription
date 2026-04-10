from __future__ import annotations

from pathlib import Path
from typing import Any

from .utils import ensure_dir, format_bytes, format_seconds, html_escape, relative_posix


def _build_transcript_html(item: dict[str, Any], audio_rel_path: str) -> str:
    speaker_count = item.get("speaker_count") or 1
    language = item.get("language") or ""
    probability = item.get("language_probability")
    probability_text = f"{probability:.2f}" if isinstance(probability, (int, float)) else ""

    segment_html = []
    for seg in item.get("segments", []):
        segment_html.append(
            f"""
            <div class=\"segment\">
                <div class=\"segment-head\">
                    <span class=\"speaker\">{html_escape(seg.get('speaker', 'Speaker 1'))}</span>
                    <span class=\"time\">{html_escape(format_seconds(seg.get('start')))} - {html_escape(format_seconds(seg.get('end')))}</span>
                </div>
                <div class=\"segment-text\">{html_escape(seg.get('text', ''))}</div>
            </div>
            """
        )

    diarization_note = item.get("diarization_note") or ""
    diarization_html = f"<div class='note'>Diarization note: {html_escape(diarization_note)}</div>" if diarization_note else ""

    return f"""<!DOCTYPE html>
<html lang=\"en\">
<head>
<meta charset=\"UTF-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
<title>{html_escape(item['filename'])}</title>
<style>
body {{ font-family: Arial, sans-serif; background:#0f172a; color:#e5e7eb; margin:0; padding:24px; }}
.container {{ max-width:1000px; margin:0 auto; }}
.card {{ background:#111827; border:1px solid #334155; border-radius:14px; padding:20px; margin-bottom:20px; }}
a {{ color:#93c5fd; }}
.meta {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(220px,1fr)); gap:12px; margin-top:16px; }}
.meta-item {{ background:#0b1220; border:1px solid #243244; border-radius:10px; padding:12px; }}
.segment {{ background:#0b1220; border:1px solid #243244; border-radius:10px; padding:14px; margin-bottom:12px; }}
.segment-head {{ display:flex; justify-content:space-between; gap:12px; margin-bottom:6px; font-size:14px; }}
.speaker {{ font-weight:700; color:#c4b5fd; }}
.time {{ color:#93c5fd; }}
.segment-text {{ white-space:pre-wrap; line-height:1.55; }}
.note {{ margin-top:12px; color:#fca5a5; }}
audio {{ width:100%; margin-top:14px; }}
</style>
</head>
<body>
<div class=\"container\">
  <div class=\"card\">
    <div><a href=\"../index.html\">← Back to dashboard</a></div>
    <h1>{html_escape(item['filename'])}</h1>
    <audio controls preload=\"metadata\">
      <source src=\"{html_escape(audio_rel_path)}\">
      Your browser does not support audio playback.
    </audio>
    <div class=\"meta\">
      <div class=\"meta-item\"><strong>File size</strong><br>{html_escape(format_bytes(item['size_bytes']))}</div>
      <div class=\"meta-item\"><strong>Language</strong><br>{html_escape(language)}</div>
      <div class=\"meta-item\"><strong>Language confidence</strong><br>{html_escape(probability_text)}</div>
      <div class=\"meta-item\"><strong>Duration</strong><br>{html_escape(format_seconds(item.get('duration')))}</div>
      <div class=\"meta-item\"><strong>Distinct speakers</strong><br>{html_escape(speaker_count)}</div>
      <div class=\"meta-item\"><strong>Status</strong><br>{html_escape(item.get('status', ''))}</div>
    </div>
    {diarization_html}
  </div>
  <div class=\"card\">
    <h2>Transcript</h2>
    {''.join(segment_html) if segment_html else '<p>No transcript available.</p>'}
  </div>
</div>
</body>
</html>"""


def _build_index_html(summary: dict[str, Any], dashboard_dir: Path) -> str:
    rows = []
    for item in summary["results"]:
        audio_link = relative_posix(Path(item["file"]), dashboard_dir)
        play_html = (
            f"<audio controls preload='metadata'><source src='{html_escape(audio_link)}'></audio>"
            if Path(item["file"]).exists() else "—"
        )
        transcript_link = (
            f"<a href='{html_escape(item['transcript_page'])}'>View transcript</a>"
            if item.get("transcript_page") else "—"
        )
        rows.append(
            f"""
            <tr>
                <td>{html_escape(item['filename'])}</td>
                <td>{html_escape(format_bytes(item['size_bytes']))}</td>
                <td>{html_escape(item.get('language') or '')}</td>
                <td>{html_escape(format_seconds(item.get('duration')))}</td>
                <td>{html_escape(item.get('speaker_count') or '')}</td>
                <td>{html_escape(item.get('status') or '')}</td>
                <td>{play_html}</td>
                <td>{transcript_link}</td>
            </tr>
            """
        )

    return f"""<!DOCTYPE html>
<html lang=\"en\">
<head>
<meta charset=\"UTF-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
<title>Audio Dashboard</title>
<style>
body {{ font-family: Arial, sans-serif; background:#020617; color:#e5e7eb; margin:0; padding:24px; }}
.container {{ max-width:1300px; margin:0 auto; }}
.kpis {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(180px,1fr)); gap:14px; margin:20px 0 24px; }}
.kpi {{ background:#111827; border:1px solid #334155; border-radius:14px; padding:18px; }}
.kpi .value {{ font-size:30px; font-weight:700; }}
.kpi .label {{ color:#94a3b8; margin-top:6px; }}
.table-wrap {{ background:#111827; border:1px solid #334155; border-radius:14px; overflow:hidden; }}
table {{ width:100%; border-collapse:collapse; }}
th, td {{ padding:14px; border-bottom:1px solid #1f2937; text-align:left; vertical-align:top; }}
th {{ background:#0f172a; color:#93c5fd; }}
tr:hover td {{ background:#0b1220; }}
a {{ color:#93c5fd; }}
audio {{ width:240px; max-width:100%; }}
</style>
</head>
<body>
<div class=\"container\">
  <h1>Audio Transcription Dashboard</h1>
  <div class=\"kpis\">
    <div class=\"kpi\"><div class=\"value\">{summary['total_files']}</div><div class=\"label\">Audio files</div></div>
    <div class=\"kpi\"><div class=\"value\">{summary['transcribed']}</div><div class=\"label\">Transcribed</div></div>
    <div class=\"kpi\"><div class=\"value\">{summary['skipped_language']}</div><div class=\"label\">Skipped language</div></div>
    <div class=\"kpi\"><div class=\"value\">{summary['failed']}</div><div class=\"label\">Failed</div></div>
  </div>
  <div class=\"table-wrap\">
    <table>
      <thead>
        <tr>
          <th>Filename</th>
          <th>Size</th>
          <th>Language</th>
          <th>Duration</th>
          <th>Speakers</th>
          <th>Status</th>
          <th>Play</th>
          <th>Transcript</th>
        </tr>
      </thead>
      <tbody>
        {''.join(rows)}
      </tbody>
    </table>
  </div>
</div>
</body>
</html>"""


def write_dashboard(summary: dict[str, Any], output_dir: Path) -> Path:
    dashboard_dir = ensure_dir(output_dir / "dashboard")
    transcripts_dir = ensure_dir(dashboard_dir / "transcripts")

    for item in summary["results"]:
        if item.get("status") != "success":
            continue
        transcript_file = transcripts_dir / f"{item['stem']}.html"
        audio_rel = relative_posix(Path(item["file"]), transcripts_dir)
        transcript_file.write_text(_build_transcript_html(item, audio_rel), encoding="utf-8")
        item["transcript_page"] = relative_posix(transcript_file, dashboard_dir)

    index_path = dashboard_dir / "index.html"
    index_path.write_text(_build_index_html(summary, dashboard_dir), encoding="utf-8")
    return index_path
