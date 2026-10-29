#!/usr/bin/env python3
"""Prepare V87 star ping and result stingers from the approved CC0 sources.

Usage: python3 tools/legacy/prepare_star_stingers_v87.py
Reads assets/audio/sfx/ui/sources (already licensed copies), writes star.wav /
win.wav / lose.wav next to the existing event sounds, and appends provenance.
No oscillator synthesis: only decode, gentle band limiting, sample-rate pitch
shifts of the kept sources, overlap-add note sequencing, fades and gain
matching. Band ceiling widens from V53's 6.5 kHz to 12 kHz per the audio
review (V53 processing muffled the bright end and read as stiff).
"""
from pathlib import Path
import array
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/audio/sfx/ui/sources"
OUT = ROOT / "assets/audio-v53"
FFMPEG = "/opt/homebrew/bin/ffmpeg"
RATE = 48000


def decode(name: str) -> array.array:
    raw = subprocess.check_output([
        FFMPEG, "-v", "error", "-i", str(SRC / name), "-af",
        "highpass=f=40,lowpass=f=12000", "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-",
    ])
    samples = array.array("f", raw)
    if __import__("sys").byteorder != "little":
        samples.byteswap()
    return samples


def trim(samples: array.array) -> array.array:
    peak = max(abs(s) for s in samples)
    audible = [i for i, s in enumerate(samples) if abs(s) > peak * 0.012]
    begin = max(0, audible[0] - int(RATE * 0.004))
    end = min(len(samples), audible[-1] + int(RATE * 0.015))
    return samples[begin:end]


def pitch(samples: array.array, semitones: float) -> array.array:
    ratio = 2.0 ** (semitones / 12.0)
    size = max(2, int(len(samples) / ratio))
    out = array.array("f", bytes(size * 4))
    for i in range(size):
        pos = i * ratio
        base = int(pos)
        frac = pos - base
        if base + 1 < len(samples):
            out[i] = samples[base] * (1 - frac) + samples[base + 1] * frac
        else:
            out[i] = samples[min(base, len(samples) - 1)]
    return out


def gain_to(samples: array.array, rms_target_db: float, peak_ceiling_db: float) -> array.array:
    rms = (sum(s * s for s in samples) / max(1, len(samples))) ** 0.5
    gain = (10 ** (rms_target_db / 20.0)) / max(rms, 1e-9)
    peak = max(abs(s) for s in samples) * gain
    ceiling = 10 ** (peak_ceiling_db / 20.0)
    if peak > ceiling:
        gain *= ceiling / peak
    return array.array("f", [s * gain for s in samples])


def fade(samples: array.array) -> array.array:
    edge = min(int(RATE * 0.003), len(samples) // 4)
    for i in range(edge):
        samples[i] *= i / edge
        samples[-i - 1] *= i / edge
    return samples


def sequence(notes: list, length: float) -> array.array:
    total = int(RATE * length)
    out = array.array("f", bytes(total * 4))
    for samples, onset, level in notes:
        start = int(onset * RATE)
        for i, s in enumerate(samples):
            if start + i < total:
                out[start + i] += s * level
    return out


def write(key: str, samples: array.array) -> dict:
    pcm = array.array("h", [max(-32768, min(32767, int(s * 32767))) for s in samples])
    path = OUT / f"{key}.wav"
    import wave
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    peak = max(abs(s) for s in samples)
    rms = (sum(s * s for s in samples) / max(1, len(samples))) ** 0.5
    import math
    return {
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "duration_seconds": round(len(samples) / RATE, 4),
        "peak_dbfs": round(20 * math.log10(max(peak, 1e-9)), 2),
        "rms_dbfs": round(20 * math.log10(max(rms, 1e-9)), 2),
    }


bubble = trim(decode("bubbles-single1.wav"))
bubble3 = trim(decode("bubbles-single3.wav"))
bong = trim(decode("bong_001.ogg"))

# Star ping: the soft bubble family pitched up into a small rounded blip.
star = fade(gain_to(pitch(bubble, 14), -24, -10))[: int(RATE * 0.16)]

# Win: quick rising three-tap arpeggio with a bubble pop on the last note.
win = fade(gain_to(sequence([
    (pitch(bong, 0), 0.00, 1.0),
    (pitch(bong, 4), 0.11, 0.92),
    (pitch(bong, 7), 0.22, 1.0),
    (pitch(bubble3, 7), 0.22, 0.45),
], 0.7), -20, -8))

# Lose: two slow falling taps, quieter and lower.
lose = fade(gain_to(sequence([
    (pitch(bong, 0), 0.00, 0.9),
    (pitch(bong, -2), 0.17, 0.7),
], 0.8), -22, -9))

outputs = {}
outputs["star"] = write("star", star)
outputs["win"] = write("win", win)
outputs["lose"] = write("lose", lose)

provenance_path = OUT / "provenance.json"
provenance = json.loads(provenance_path.read_text())
entries = {
    "star": ("星位触发", "bubbles-single1.wav", "bmaczero-bubbles", "https://opengameart.org/content/bubble-sound-effects",
             "pitch +14 semitones (sample-rate shift, no time correction), 160 ms cap"),
    "win": ("胜利", "bong_001.ogg + bubbles-single3.wav", "Kenney + BMacZero", "https://kenney.nl/assets/interface-sounds",
            "three bong taps at 0/+4/+7 semitones (onsets 0/0.11/0.22 s) plus a +7 semitone bubble pop on the last tap"),
    "lose": ("败北", "bong_001.ogg", "Kenney", "https://kenney.nl/assets/interface-sounds",
             "two bong taps at 0/-2 semitones (onsets 0/0.17 s), softer"),
}
for key, (label, source, author, page, note) in entries.items():
    provenance["events"].append({
        "event": key,
        "label": label,
        "source": "sources/" + source.split(" + ")[0],
        "source_page": page,
        "author": author,
        "license": "CC0-1.0",
        "output": f"{key}.wav",
        **outputs[key],
        "processing_note": note + "; band 40 Hz–12 kHz (wider than V53's 6.5 kHz per audio review)",
    })
provenance_path.write_text(json.dumps(provenance, ensure_ascii=False, indent=1) + "\n")
print("written:", ", ".join(f"{k} {v['duration_seconds']}s peak {v['peak_dbfs']}dB" for k, v in outputs.items()))
