#!/usr/bin/env python3
"""Soften the existing recorded star placeholder; no new instrument or synthesis.

Rebuilds only star.wav from its licensed source, without transposition or
post-EQ normalization that would undo the attenuation. Other sounds are untouched.
"""
from pathlib import Path
import array
import hashlib
import json
import math
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/audio-v53'
SOURCE = OUT / 'sources/real/glock_Fs6.mp3'
FFMPEG = '/opt/homebrew/bin/ffmpeg'
RATE = 48000


def floats(raw):
    samples = array.array('f', raw)
    if sys.byteorder != 'little':
        samples.byteswap()
    return samples


def pcm(samples):
    data = array.array('f', samples)
    if sys.byteorder != 'little':
        data.byteswap()
    return data.tobytes()


def filter_audio(samples, filters):
    return floats(subprocess.check_output([
        FFMPEG, '-v', 'error', '-f', 'f32le', '-ar', str(RATE), '-ac', '1',
        '-i', '-', '-af', filters, '-f', 'f32le', '-'], input=pcm(samples)))


def db(value):
    return 20 * math.log10(max(value, 1e-9))


def metrics(samples):
    return {'duration_seconds': round(len(samples) / RATE, 4),
            'peak_dbfs': round(db(max(abs(x) for x in samples)), 2),
            'rms_dbfs': round(db(math.sqrt(sum(x*x for x in samples) / len(samples))), 2)}


def main():
    source = floats(subprocess.check_output([
        FFMPEG, '-v', 'error', '-i', str(SOURCE), '-f', 'f32le', '-ac', '1', '-ar', str(RATE), '-']))
    peak = max(abs(x) for x in source)
    audible = [i for i, x in enumerate(source) if abs(x) > peak * .012]
    source = source[max(0, audible[0] - int(RATE * .004)):min(len(source), audible[-1] + int(RATE * .015))]
    rms = math.sqrt(sum(x*x for x in source) / len(source))
    gain = min(10**(-20/20) / rms, 10**(-10/20) / max(abs(x) for x in source))
    source = array.array('f', (x * gain for x in source))
    # Retain a quick cue; soften its high partials and leading edge, not its pitch.
    samples = filter_audio(source[:int(RATE*.30)],
        'highshelf=f=3000:g=-6:t=q:w=0.707,lowpass=f=6000:p=2,'
        'afade=t=in:st=0:d=0.006,afade=t=out:st=0.245:d=0.055')
    data = array.array('h', (max(-32768, min(32767, round(x*32767))) for x in samples))
    if sys.byteorder != 'little':
        data.byteswap()
    path = OUT / 'star.wav'
    with wave.open(str(path), 'wb') as w:
        w.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        w.writeframes(data.tobytes())
    meta = metrics(samples)
    meta['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    provenance = OUT / 'provenance.json'
    table = json.loads(provenance.read_text())
    for entry in table['events']:
        if entry['event'] == 'star':
            entry.update(meta)
            entry.update({'revision': 'v89 softened existing placeholder', 'license': 'CC0-1.0',
                'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                'processing_note': 'Existing F#6 recording, unchanged pitch; -6 dB high shelf at 3 kHz; 6 kHz low-pass; 6 ms attack and 55 ms release; 0.30 s; no post-filter normalization. Playback -13 dB, 260 ms rate limit.'})
    provenance.write_text(json.dumps(table, ensure_ascii=False, indent=1)+'\n')
    print(json.dumps(meta, ensure_ascii=False))


if __name__ == '__main__':
    main()
