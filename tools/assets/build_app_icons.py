#!/usr/bin/env python3
"""Convert the approved PNG into desktop icons on macOS (sips + iconutil).

This performs size/format conversion only; the illustration is authored separately.
Generated files are committed so other build hosts need not run this tool.
"""
import struct
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'assets/ui/branding'


def clean_png(path):
    """Keep pixel and color data, omit source-machine/provenance text metadata."""
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    chunks, offset = [data[:8]], 8
    while offset < len(data):
        length = struct.unpack_from('>I', data, offset)[0]
        kind = data[offset + 4:offset + 8]
        if kind in (b'IHDR', b'PLTE', b'tRNS', b'IDAT', b'IEND', b'sRGB', b'gAMA', b'cHRM'):
            chunks.append(data[offset:offset + length + 12])
        offset += length + 12
    path.write_bytes(b''.join(chunks))


def resize(source, target, size):
    subprocess.run(['sips', '-z', str(size), str(size), str(source), '--out', str(target)],
                   check=True, stdout=subprocess.DEVNULL)
    clean_png(target)


def main():
    source = ART / 'app-icon.png'
    clean_png(source)
    with tempfile.TemporaryDirectory() as temp:
        temp = Path(temp)
        sizes = (16, 20, 24, 32, 40, 48, 64, 128, 256)
        images = []
        for size in sizes:
            path = temp / f'{size}.png'
            resize(source, path, size)
            images.append(path.read_bytes())
        offset = 6 + 16 * len(sizes)
        ico = bytearray(struct.pack('<HHH', 0, 1, len(sizes)))
        for size, data in zip(sizes, images):
            ico += struct.pack('<BBBBHHII', size % 256, size % 256, 0, 0, 1, 32, len(data), offset)
            offset += len(data)
        (ART / 'app-icon.ico').write_bytes(ico + b''.join(images))
        iconset = temp / 'AppIcon.iconset'
        iconset.mkdir()
        for size in (16, 32, 128, 256, 512):
            for scale in (1, 2):
                suffix = '@2x' if scale == 2 else ''
                resize(source, iconset / f'icon_{size}x{size}{suffix}.png', size * scale)
        subprocess.run(['iconutil', '-c', 'icns', str(iconset), '-o', str(ART / 'app-icon.icns')], check=True)
    print('App icon: PNG + Windows ICO + macOS ICNS ready')


if __name__ == '__main__':
    main()
