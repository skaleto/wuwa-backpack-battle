#!/usr/bin/env python3
"""Prepare two animation cues from retained licensed samples, never play audio.

Run: python3 tools/legacy/prepare_fusion_v101.py
Requires ffmpeg; all inputs are already retained inside the project.
Only sample excerpts, filtering, envelopes, original-speed overlap and stereo
panning are used. No oscillators, pitch shifting, stretching or new melodies.
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
OUT = ROOT / "assets/audio-v101"
RATE = 48000
LAND_AT = 0.94
FFMPEG = shutil.which("ffmpeg") or "/opt/homebrew/bin/ffmpeg"
SOURCES = {
    "air": {
        "path": "art_sources/audio/sfx/weapons/mixkit-2161.wav",
        "title": "Air in a hit / 2161",
        "author": "Mixkit",
        "source_url": "https://mixkit.co/free-sound-effects/swish/",
        "license": "Mixkit Sound Effects Free License",
        "license_url": "https://mixkit.co/license/modal/sfxFree/",
        "license_evidence": "art_sources/audio/sfx/weapons/mixkit-license.html",
        "lowpass_hz": 4000,
    },
    "bubble_small": {
        "path": "art_sources/audio/sfx/ui/bubbles-single1.wav",
        "title": "Bubble Sound Effects / bubbles-single1",
        "author": "BMacZero / Brian MacIntosh",
        "source_url": "https://opengameart.org/content/bubble-sound-effects",
        "license": "CC0-1.0",
        "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
        "license_evidence": "assets/audio/sfx/ui/CREDITS.md",
        "lowpass_hz": 4200,
    },
    "bubble_body": {
        "path": "art_sources/audio/sfx/ui/bubbles-single2.wav",
        "title": "Bubble Sound Effects / bubbles-single2",
        "author": "BMacZero / Brian MacIntosh",
        "source_url": "https://opengameart.org/content/bubble-sound-effects",
        "license": "CC0-1.0",
        "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
        "license_evidence": "assets/audio/sfx/ui/CREDITS.md",
        "lowpass_hz": 3200,
    },
    "pop": {
        "path": "art_sources/audio/sfx/ui/mixkit/cartoon-bubble-pop-731.wav",
        "title": "Cartoon bubble pop / 731, first pop only",
        "author": "Mixkit",
        "source_url": "https://mixkit.co/free-sound-effects/bubble/",
        "license": "Mixkit Sound Effects Free License",
        "license_url": "https://mixkit.co/license/modal/sfxFree/",
        "license_evidence": "art_sources/audio/sfx/ui/mixkit/license.html",
        "lowpass_hz": 4800,
    },
}

# Pan -1 = left, 0 = centre, +1 = right. Each material approaches the same
# centre over the sample's own duration, without changing its playback speed.
GATHER_LAYERS = [
    {"source": "bubble_small", "excerpt": [0.0, 0.31], "at": 0.035, "gain_db": -2.0, "pan": [-0.7, -0.15], "fade_in": 0.006, "fade_out": 0.025},
    {"source": "bubble_small", "excerpt": [0.0, 0.31], "at": 0.255, "gain_db": -3.0, "pan": [0.7, 0.15], "fade_in": 0.006, "fade_out": 0.025},
    {"source": "bubble_small", "excerpt": [0.0, 0.31], "at": 0.490, "gain_db": -4.0, "pan": [-0.3, 0.0], "fade_in": 0.006, "fade_out": 0.025},
    {"source": "air", "excerpt": [0.01, 0.35], "at": 0.200, "gain_db": -9.0, "pan": [-0.6, -0.06], "fade_in": 0.070, "fade_out": 0.045},
    {"source": "air", "excerpt": [0.01, 0.35], "at": 0.430, "gain_db": -7.5, "pan": [0.6, 0.06], "fade_in": 0.070, "fade_out": 0.045},
    {"source": "air", "excerpt": [0.01, 0.35], "at": 0.640, "gain_db": -6.0, "pan": [-0.2, 0.0], "fade_in": 0.070, "fade_out": 0.045},
]
LAND_LAYERS = [
    {"source": "pop", "excerpt": [0.0, 0.25], "at": 0.0, "gain_db": -6.0, "pan": [0.0, 0.0], "fade_in": 0.002, "fade_out": 0.015},
    {"source": "bubble_body", "excerpt": [0.0, 0.435646], "at": 0.015, "gain_db": -6.5, "pan": [0.0, 0.0], "fade_in": 0.008, "fade_out": 0.020},
]


def read_source(key):
    source = SOURCES[key]
    path = ROOT / source["path"]
    source["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    raw = subprocess.check_output([
        FFMPEG, "-v", "error", "-i", str(path), "-af",
        f"highpass=f=35,lowpass=f={source['lowpass_hz']}:p=2",
        "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-",
    ])
    samples = array.array("f", raw)
    if sys.byteorder != "little":
        samples.byteswap()
    return samples


def mix(layers, sources, duration, rms_db, peak_db):
    mixed = [0.0] * (round(duration * RATE) * 2)
    for layer in layers:
        start, end = (round(v * RATE) for v in layer["excerpt"])
        samples = sources[layer["source"]][start:end]
        gain = 10 ** (layer["gain_db"] / 20)
        offset = round(layer["at"] * RATE)
        fade_in = max(1, round(layer["fade_in"] * RATE))
        fade_out = max(1, round(layer["fade_out"] * RATE))
        for i, value in enumerate(samples):
            frame = offset + i
            if frame * 2 + 1 >= len(mixed):
                raise ValueError("Layer exceeds its explicitly declared cue duration")
            envelope = min(1.0, i / fade_in, (len(samples) - 1 - i) / fade_out)
            pan = layer["pan"][0] + (layer["pan"][1] - layer["pan"][0]) * i / max(1, len(samples) - 1)
            angle = (pan + 1) * math.pi / 4
            value *= gain * envelope
            # Constant-power pan coefficients only; no generated audio signal.
            mixed[frame * 2] += value * math.cos(angle)
            mixed[frame * 2 + 1] += value * math.sin(angle)
    peak = max(map(abs, mixed))
    rms = math.sqrt(sum(v * v for v in mixed) / len(mixed))
    gain = min(10 ** (rms_db / 20) / rms, 10 ** (peak_db / 20) / peak)
    return [v * gain for v in mixed], round(20 * math.log10(gain), 6)


def write_wav(name, samples):
    pcm = array.array("h", (round(v * 32767) for v in samples))
    if max(map(abs, pcm)) >= 32767:
        raise ValueError("Clipping detected")
    if sys.byteorder != "little":
        pcm.byteswap()
    path = OUT / name
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    peak = max(map(abs, samples))
    rms = math.sqrt(sum(v * v for v in samples) / len(samples))
    return {
        "file": name,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "duration_seconds": len(samples) / (2 * RATE),
        "peak_dbfs": round(20 * math.log10(peak), 3),
        "rms_dbfs": round(20 * math.log10(rms), 3),
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sources = {key: read_source(key) for key in SOURCES}
    gather, gather_gain = mix(GATHER_LAYERS, sources, 1.0, -24.0, -9.0)
    land, land_gain = mix(LAND_LAYERS, sources, 0.48, -21.0, -7.0)
    gather_record = write_wav("fusion_gather.wav", gather)
    land_record = write_wav("fusion_land.wav", land)
    # Preview uses the exact two files' PCM at the animation's landing time.
    # No independent preview gain or extra audio layer is introduced.
    preview = [0.0] * round((LAND_AT + 0.48) * RATE * 2)
    for offset, samples in [(0, gather), (round(LAND_AT * RATE) * 2, land)]:
        for i, value in enumerate(samples):
            preview[offset + i] += round(value * 32767) / 32767
    preview_record = write_wav("fusion_preview.wav", preview)
    records = {
        "revision": "v101",
        "kind": "layered excerpts of existing licensed samples",
        "procedural_synthesis": False,
        "pitch_shift_semitones": 0,
        "playback_rate": 1.0,
        "runtime_gain_db": -7.0,
        "land_animation_seconds": LAND_AT,
        "visual_end_seconds": 1.25,
        "processing": "35 Hz high-pass, source-specific gentle low-pass, original-speed excerpts, edge fades, constant-power inward stereo pan, fixed layer gain, final RMS/peak ceiling. No music, new melody, oscillators, pitch shifting, time stretching or reverb.",
        "sources": SOURCES,
        "cues": [
            dict(gather_record, event="fusion", layers=GATHER_LAYERS, final_gain_db=gather_gain),
            dict(land_record, event="fusion_land", layers=LAND_LAYERS, final_gain_db=land_gain),
        ],
        "preview": dict(preview_record, assembly="fusion_gather at 0.0 s + fusion_land at 0.94 s; exact PCM sum"),
        "audition": "Not played automatically or subjectively approved. Timing, PCM and hashes are checked separately.",
    }
    (OUT / "provenance.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"cues": [gather_record, land_record], "preview": preview_record}, indent=2))


if __name__ == "__main__":
    main()
