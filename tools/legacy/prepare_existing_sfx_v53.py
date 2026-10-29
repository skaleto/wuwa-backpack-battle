#!/usr/bin/env python3
"""Prepare licensed existing samples; no oscillator synthesis or new sounds.

Usage: python3 tools/legacy/prepare_existing_sfx_v53.py <audio-sources-v53 directory>
Only resampling, gentle band limiting, tiny edge fades and gain matching.
"""
from pathlib import Path
import array
import hashlib
import json
import math
import shutil
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(sys.argv[1]).resolve()
OUT = ROOT / "assets/audio-v53"
FFMPEG = shutil.which("ffmpeg") or "/opt/homebrew/bin/ffmpeg"
RATE = 48000
MAPPING = {
    "click": ("kenney-interface/Audio/pluck_001.ogg", "轻点", -20),
    "pick": ("bmaczero-bubbles/bubbles-single1.wav", "抓取", -19),
    "turn": ("kenney-interface/Audio/bong_001.ogg", "旋转", -20),
    "drop": ("bmaczero-bubbles/bubbles-single2.wav", "落下", -18),
    "purchase": ("kenney-interface/Audio/confirmation_001.ogg", "购买", -18),
    "start": ("kenney-interface/Audio/confirmation_002.ogg", "开战", -18),
    "attack": ("kenney-interface/Audio/pluck_002.ogg", "攻击", -18),
    "hit": ("bmaczero-bubbles/bubbles-single3.wav", "受击", -18),
    "heal": ("kenney-interface/Audio/maximize_001.ogg", "治疗", -19),
    "fusion": ("kenney-interface/Audio/confirmation_004.ogg", "合成", -18),
    "reject": ("kenney-interface/Audio/minimize_001.ogg", "回落", -20),
}
OUT.mkdir(parents=True, exist_ok=True)
(OUT / "sources").mkdir(exist_ok=True)
records = []
preview = []
cursor = 0.0
for key, (relative, label, rms_target_db) in MAPPING.items():
    src = SOURCE / relative
    kept = OUT / "sources" / src.name
    shutil.copy2(src, kept)
    raw = subprocess.check_output([
        FFMPEG, "-v", "error", "-i", str(src), "-af",
        "highpass=f=40,lowpass=f=6500", "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-",
    ])
    samples = array.array("f", raw)
    if sys.byteorder != "little":
        samples.byteswap()
    # Remove source silence, retaining 4 ms before and 15 ms after the audible body.
    peak = max(abs(s) for s in samples)
    audible = [i for i, s in enumerate(samples) if abs(s) > peak * 0.012]
    begin = max(0, audible[0] - int(RATE * 0.004))
    end = min(len(samples), audible[-1] + int(RATE * 0.015))
    samples = samples[begin:end]
    fade = min(int(RATE * 0.003), len(samples) // 4)
    for i in range(fade):
        samples[i] *= i / fade
        samples[-i - 1] *= i / fade
    rms = math.sqrt(sum(s * s for s in samples) / len(samples))
    gain = min(10 ** (rms_target_db / 20) / rms, 10 ** (-6 / 20) / max(abs(s) for s in samples))
    pcm = array.array("h", (round(s * gain * 32767) for s in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    target = OUT / (key + ".wav")
    with wave.open(str(target), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    duration = len(samples) / RATE
    source_page = "https://opengameart.org/content/bubble-sound-effects" if "bmaczero" in relative else "https://kenney.nl/assets/interface-sounds"
    author = "BMacZero / Brian MacIntosh" if "bmaczero" in relative else "Kenney"
    records.append({
        "event": key, "label": label, "source": "sources/" + src.name,
        "source_page": source_page, "author": author, "license": "CC0-1.0",
        "source_sha256": hashlib.sha256(src.read_bytes()).hexdigest(),
        "output": target.name, "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "duration_seconds": round(duration, 4), "gain_db": round(20 * math.log10(gain), 2),
        "peak_dbfs": round(20 * math.log10(max(abs(s * gain) for s in samples)), 2),
        "rms_dbfs": round(20 * math.log10(rms * gain), 2),
        "preview_start_seconds": round(cursor, 3),
    })
    preview.extend(pcm)
    preview.extend([0] * int(RATE * 0.5))
    cursor += duration + 0.5
(OUT / "provenance.json").write_text(json.dumps({
    "kind": "existing licensed sample adaptation", "procedural_synthesis": False,
    "processing": "mono 48 kHz PCM16; 40 Hz high-pass / 6.5 kHz low-pass; silence trim; 3 ms edge fades; RMS gain matching with -6 dBFS peak ceiling. No pitch/time changes or layered oscillator generation.",
    "events": records,
}, ensure_ascii=False, indent=2) + "\n")
with wave.open(str(ROOT / "build/qa/ui-v53/sound-preview.wav"), "wb") as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(RATE)
    output.writeframes(array.array("h", preview).tobytes())
print(json.dumps(records, ensure_ascii=False, indent=2))
