#!/usr/bin/env python3
"""Preserve a built-in generated asset and record its provenance; never redraw it."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument("section", choices=["items", "characters", "ui", "bags"])
parser.add_argument("key")
parser.add_argument("source", type=Path)
args = parser.parse_args()
manifest_path = ROOT / "assets/manifest.json"
manifest = json.loads(manifest_path.read_text())
entry = manifest[args.section][args.key]
target = ROOT / entry["path"]
image = Image.open(args.source)
alpha = image.getchannel("A") if "A" in image.getbands() else None
if args.section in ("items", "characters") and (alpha is None or alpha.getextrema()[0] != 0):
    raise SystemExit("Generated cutout is missing real transparency: " + args.key)
target.parent.mkdir(parents=True, exist_ok=True)
shutil.copy2(args.source, target)
entry.update({
    "status": "generated_pending_native_review",
    "generator": "built_in_image_gen",
    "raw_path": str(args.source),
    "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
    "dimensions": list(image.size),
    "has_alpha": alpha is not None,
    "alpha_bounds": list(alpha.getbbox()) if alpha and alpha.getbbox() else None,
    "prompt": f"art_sources/prompts/{args.section}-{args.key}.txt",
})
temporary = manifest_path.with_suffix(".tmp")
temporary.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
temporary.replace(manifest_path)
print(f"Saved {args.section}/{args.key}: {image.size}, alpha={alpha is not None}")
