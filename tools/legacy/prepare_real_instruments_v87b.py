#!/usr/bin/env python3
"""V87b: rebuild key event sounds from real recorded instruments.

Sources (staged in art_sources/audio/sfx/ui/real/):
- Kalimba two-note (CC0, opengameart.org/content/kalimba-two-notes) -> purchase
- Glockenspiel one-shots, VSCO 2 CE public-domain library via sgossner/Freesound (CC0) -> star
- Marimba one-shots by sgossner/Freesound (CC BY 4.0, credited) -> click/turn/win/lose

No pitch shifting, no synthesis: each event is a real recorded note or a
sequence of real notes with humanised timing (fixed seed) and level taper.
Natural decay tails are kept; only 3 ms edge fades and gentle gain matching.
"""
from pathlib import Path
import array
import hashlib
import json
import random
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "art_sources/audio/sfx/ui/real"
OUT = ROOT / "assets/audio-v53"
FFMPEG = "/opt/homebrew/bin/ffmpeg"
RATE = 48000
random.seed(87)


def load(name: str) -> array.array:
    raw = subprocess.check_output([
        FFMPEG, "-v", "error", "-i", str(SRC / name),
        "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-",
    ])
    samples = array.array("f", raw)
    if sys.byteorder != "little":
        samples.byteswap()
    return samples


def trim(samples: array.array, floor: float = 0.012) -> array.array:
    peak = max(abs(s) for s in samples)
    audible = [i for i, s in enumerate(samples) if abs(s) > peak * floor]
    begin = max(0, audible[0] - int(RATE * 0.004))
    end = min(len(samples), audible[-1] + int(RATE * 0.015))
    return samples[begin:end]


def cut(samples: array.array, seconds: float, tail_fade: float = 0.08) -> array.array:
    size = min(len(samples), int(RATE * seconds))
    out = samples[:size]
    fade_n = min(int(RATE * tail_fade), len(out) // 3)
    for i in range(fade_n):
        out[-i - 1] *= i / fade_n
    return out


def gain_to(samples: array.array, rms_target_db: float, peak_ceiling_db: float) -> array.array:
    rms = (sum(s * s for s in samples) / max(1, len(samples))) ** 0.5
    gain = (10 ** (rms_target_db / 20.0)) / max(rms, 1e-9)
    peak = max(abs(s) for s in samples) * gain
    ceiling = 10 ** (peak_ceiling_db / 20.0)
    if peak > ceiling:
        gain *= ceiling / peak
    return array.array("f", [s * gain for s in samples])


def edge_fade(samples: array.array) -> array.array:
    edge = min(int(RATE * 0.003), len(samples) // 4)
    for i in range(edge):
        samples[i] *= i / edge
        samples[-i - 1] *= i / edge
    return samples


def sequence(notes, length):
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
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    import math
    peak = max(abs(s) for s in samples)
    rms = (sum(s * s for s in samples) / max(1, len(samples))) ** 0.5
    return {
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "duration_seconds": round(len(samples) / RATE, 4),
        "peak_dbfs": round(20 * math.log10(max(peak, 1e-9)), 2),
        "rms_dbfs": round(20 * math.log10(max(rms, 1e-9)), 2),
    }


glock_fs6 = trim(load("glock_Fs6.mp3"))
glock_c6 = trim(load("glock_C6.mp3"))
mar_c5 = trim(load("marimba_C5.mp3"))
mar_e5 = trim(load("marimba_E5.mp3"))
mar_b5 = trim(load("marimba_B5.mp3"))
mar_e3 = trim(load("marimba_E3.mp3"))
mar_c3 = trim(load("marimba_C3.mp3"))
mar_d6 = trim(load("marimba_D6.mp3"))
kalimba = edge_fade(gain_to(trim(load("kalimba.wav")), -20, -8))

# star: one real high bell, ringing tail kept to 0.6 s.
star = cut(gain_to(glock_fs6, -20, -10), 0.35, 0.05)

# click: soft wooden tap, short.
click = cut(gain_to(mar_c5, -22, -12), 0.28, 0.06)

# purchase: the kalimba two-note confirm as recorded.
purchase = kalimba

# turn: brighter wooden tick.
turn = cut(gain_to(mar_d6, -24, -14), 0.35, 0.08)

# win: rising marimba arpeggio C5-E5-B5 with humanised onsets and taper,
# plus a soft glockenspiel C6 doubling the final note.
win = edge_fade(gain_to(sequence([
    (mar_c5, 0.000 + random.uniform(-0.008, 0.008), 1.00),
    (mar_e5, 0.150 + random.uniform(-0.012, 0.012), 0.92),
    (mar_b5, 0.310 + random.uniform(-0.012, 0.012), 1.00),
    (cut(glock_c6, 1.2), 0.310 + random.uniform(-0.010, 0.010), 0.30),
], 1.7), -20, -8))

# lose: two falling low marimba notes, slower and softer.
lose = edge_fade(gain_to(sequence([
    (mar_e3, 0.000 + random.uniform(-0.010, 0.010), 0.95),
    (mar_c3, 0.260 + random.uniform(-0.015, 0.015), 0.75),
], 2.1), -22, -9))

outputs = {}
for key, samples in [("star", star), ("click", click), ("purchase", purchase), ("turn", turn), ("win", win), ("lose", lose)]:
    outputs[key] = write(key, samples)

provenance_path = OUT / "provenance.json"
provenance = json.loads(provenance_path.read_text())
by_event = {entry["event"]: entry for entry in provenance["events"]}
revision = {
    "star": ("星位触发", "real/glock_Fs6.mp3", "Sam Gossner / VSCO 2 CE (public domain)",
             "https://freesound.org/people/sgossner/packs/21027/", "real glockenspiel F#6 hit, natural tail cut at 0.6 s"),
    "click": ("轻点", "real/marimba_C5.mp3", "sgossner (CC BY 4.0)",
              "https://freesound.org/people/sgossner/packs/15684/", "real marimba C5 tap, 0.28 s"),
    "purchase": ("购买", "real/kalimba.wav", "CC0",
                 "https://opengameart.org/content/kalimba-two-notes", "recorded kalimba two-note confirm, unedited timing"),
    "turn": ("旋转", "real/marimba_D6.mp3", "sgossner (CC BY 4.0)",
             "https://freesound.org/people/sgossner/packs/15684/", "real marimba D6 tap, 0.35 s"),
    "win": ("胜利", "real/marimba_C5+E5+B5 + glock_C6", "sgossner (CC BY 4.0) + VSCO 2 CE",
            "https://freesound.org/people/sgossner/packs/15684/", "real notes sequenced with humanised onsets/levels (seed 87); no pitch shifting"),
    "lose": ("败北", "real/marimba_E3+C3", "sgossner (CC BY 4.0)",
             "https://freesound.org/people/sgossner/packs/15684/", "two real low marimba notes, humanised onsets (seed 87)"),
}
for key, (label, source, author, page, note) in revision.items():
    entry = {
        "event": key,
        "label": label,
        "source": "sources/" + source,
        "source_page": page,
        "author": author,
        "output": f"{key}.wav",
        **outputs[key],
        "revision": "v87b real instruments",
        "processing_note": note,
    }
    if key in by_event:
        provenance["events"][provenance["events"].index(by_event[key])] = entry
    else:
        provenance["events"].append(entry)
provenance_path.write_text(json.dumps(provenance, ensure_ascii=False, indent=1) + "\n")
print("written:", ", ".join(f"{k} {v['duration_seconds']}s" for k, v in outputs.items()))
