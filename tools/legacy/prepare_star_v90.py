#!/usr/bin/env python3
"""Use the first pop of the user's approved Mixkit audition (candidate 03)."""
from pathlib import Path
import array
import hashlib
import json
import math
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/audio-v53'
SOURCE = OUT / 'sources/mixkit/cartoon-bubble-pop-731.wav'
GAIN_DB = -8.513  # Same fixed gain as audition 03, not a new normalization.


def main():
    path = OUT / 'star.wav'
    subprocess.run([
        '/opt/homebrew/bin/ffmpeg', '-y', '-v', 'error', '-i', str(SOURCE),
        '-map', '0:a:0', '-ar', '48000', '-ac', '2', '-af',
        f'atrim=start=0:end=0.25,asetpts=PTS-STARTPTS,volume={GAIN_DB}dB,'
        'afade=t=out:st=0.245:d=0.005',
        '-c:a', 'pcm_s16le', '-map_metadata', '-1', str(path),
    ], check=True)
    with wave.open(str(path), 'rb') as sound:
        duration = sound.getnframes() / sound.getframerate()
        samples = array.array('h', sound.readframes(sound.getnframes()))
    peak = max(abs(value) for value in samples) / 32768
    rms = math.sqrt(sum((value / 32768)**2 for value in samples) / len(samples))
    entry = {
        'event': 'star', 'label': '星位触发',
        'source': str(SOURCE.relative_to(OUT)),
        'source_title': 'Cartoon bubble pop', 'source_id': 'Mixkit 731',
        'source_page': 'https://mixkit.co/free-sound-effects/bubble/',
        'source_download': 'https://assets.mixkit.co/active_storage/sfx/731/731.wav',
        'author': 'Mixkit stock sound effect; individual creator not listed',
        'license': 'Mixkit Sound Effects Free License',
        'license_url': 'https://mixkit.co/license/modal/sfxFree/',
        'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'output': 'star.wav', 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'duration_seconds': duration, 'gain_db': GAIN_DB,
        'peak_dbfs': round(20 * math.log10(peak), 3),
        'rms_dbfs': round(20 * math.log10(rms), 3),
        'revision': 'v90 user-selected cartoon bubble first pop',
        'processing_note': 'First pop only, source 0.000–0.250 s; second pop at ~0.270 s excluded. Same gain as audition 03, 5 ms tail fade. 48 kHz stereo PCM16. Original pitch/speed; no EQ, synthesis, or layered instruments. Existing playback -13 dB and 260 ms wall-time rate limit retained.',
    }
    provenance = OUT / 'provenance.json'
    table = json.loads(provenance.read_text())
    table['events'] = [entry if row['event'] == 'star' else row for row in table['events']]
    provenance.write_text(json.dumps(table, ensure_ascii=False, indent=1) + '\n')
    print(json.dumps(entry, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
