#!/usr/bin/env python3
"""Cut one short fusion bubble from a retained CC0 recording. Never plays audio."""
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
OUT = ROOT / "assets/audio-v102"
SOURCE = ROOT / "art_sources/audio/sfx/ui/bubbles-single2.wav"
RATE = 48000
DURATION = 0.26
FADE_IN = 0.004
FADE_OUT = 0.035


def main():
    ffmpeg = shutil.which("ffmpeg") or "/opt/homebrew/bin/ffmpeg"
    raw = subprocess.check_output([
        ffmpeg, "-v", "error", "-i", str(SOURCE), "-af",
        "atrim=start=0:end=0.26,highpass=f=35,lowpass=f=3600:p=2",
        "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-",
    ])
    samples = array.array("f", raw)
    if sys.byteorder != "little":
        samples.byteswap()
    if len(samples) != round(DURATION * RATE):
        raise ValueError("Recording must cover the declared excerpt without silence padding")
    for i in range(len(samples)):
        samples[i] *= min(1.0, i / (FADE_IN * RATE), (len(samples) - 1 - i) / (FADE_OUT * RATE))
    peak = max(map(abs, samples))
    rms = math.sqrt(sum(v * v for v in samples) / len(samples))
    gain = min(10 ** (-9.0 / 20) / peak, 10 ** (-22.0 / 20) / rms)
    pcm = array.array("h", (round(v * gain * 32767) for v in samples))
    if max(map(abs, pcm)) >= 32767:
        raise ValueError("Clipping detected")
    if sys.byteorder != "little":
        pcm.byteswap()
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / "fusion_land.wav"
    with wave.open(str(target), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    provenance = {
        "revision": "v102",
        "kind": "single excerpt of an existing licensed recording",
        "procedural_synthesis": False,
        "pitch_shift_semitones": 0,
        "playback_rate": 1.0,
        "event": "fusion_land",
        "land_animation_seconds": 0.94,
        "runtime_gain_db": -7.0,
        "source": {
            "path": str(SOURCE.relative_to(ROOT)),
            "sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
            "title": "Bubble Sound Effects / bubbles-single2",
            "author": "BMacZero / Brian MacIntosh",
            "source_url": "https://opengameart.org/content/bubble-sound-effects",
            "license": "CC0-1.0",
            "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
            "license_evidence": "assets/audio/sfx/ui/CREDITS.md",
        },
        "processing": {
            "excerpt_seconds": [0.0, DURATION],
            "highpass_hz": 35,
            "lowpass_hz": 3600,
            "fade_in_seconds": FADE_IN,
            "fade_out_seconds": FADE_OUT,
            "fixed_gain_db": round(20 * math.log10(gain), 6),
            "layer_count": 1,
        },
        "output": {
            "file": target.name,
            "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
            "duration_seconds": DURATION,
            "channels": 1,
            "sample_rate": RATE,
            "peak_dbfs": round(20 * math.log10(peak * gain), 3),
            "rms_dbfs": round(20 * math.log10(rms * gain), 3),
        },
        "audition": "Not automatically played or subjectively approved.",
    }
    (OUT / "provenance.json").write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(provenance["output"], indent=2))


if __name__ == "__main__":
    main()
