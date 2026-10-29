#!/usr/bin/env python3
"""Create auditable individual generation requests. Does not call any image API."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
manifest = json.loads((ROOT / "assets/manifest.json").read_text())
common = "Image 1 is the exact identity reference. Image 2 is ONLY our approved cartoon drawing/shading style, never copy its subject or colors. "
finish = "Clean strong ink-plum outline, 2-3 crisp cel-shaded planes, simple broad highlights. Cute bright hand-drawn 2D videogame art, readable at 100px. No photo/3D/plastic rendering, muddy painterly gradients, noisy texture, dense filigree, unnecessary sparkles, text, name, frame, card, badge, pedestal, border or background. ONE isolated subject complete with 8% safe transparent margins, no cropped parts. True alpha background. Small tight near-black contact shadow for depth, not a large ground plane. "
for section in ("characters", "items"):
    for key, entry in manifest[section].items():
        out = ROOT / f"art_sources/prompts/{section}-{key}.txt"
        if out.exists():
            continue
        if section == "characters":
            prompt = ("Style-transfer: create a complete adorable dango chibi character of " + entry["name"] + ". " + common
                + "Preserve the first character's own hair color and hairstyle, eyes, key accessories and outfit colors. About 1.5 heads tall, very large round head, tiny simplified body, rounded short hands/feet, a cheerful relaxed standing pose, small expressive face. NOT a realistic body with just a bigger head. All hair/hat/ears and feet must fit. Simplify costume ornament to only a few identity accents. No extra weapon. " + finish)
        else:
            prompt = "Style-transfer: redraw the exact " + entry["name"] + " as a charming rounded cartoon inventory icon for the same game. " + common
            if "weapon" in entry["tags"]:
                prompt += "Keep its signature silhouette, recognizable blade/barrel/ring/gauntlet pieces, original color arrangement and intrinsic effects. Simplify tiny engraving, round small details, use bold readable shape design. Preserve visual identity; not a generic substitute. "
                if entry.get("weapon_type") in ("sword", "broadblade"):
                    prompt += "Pose strictly HORIZONTAL: handle on left and blade tip pointing right. Complete blade/hilt and original intrinsic effects visible. Moderately compact cartoon proportions without turning it into a stub. Wide landscape canvas; no diagonal placement. "
                elif entry.get("weapon_type") in ("pistol", "gauntlets", "gauntlet"):
                    prompt += "Keep a single main object as in reference, orient its principal long axis HORIZONTAL, compact clear silhouette. No diagonal pose. "
                else:
                    prompt += "Retain the rectifier's characteristic floating pieces and important energy/light shapes if visible in the reference. Arrange widest axis horizontally when elongated; do not remove its existing energy effects. "
                prompt += "Only keep the glow/effects present in image 1. No invented flames/aura/lightning/runes, no framing glow. "
            elif "echo" in entry["tags"]:
                prompt += "Complete adorable little monster, rounded cute body, retain the original horns, ears, wings, shell and other distinctive anatomy and colors. Friendly expressive face, no human redesign, no square crop. Preserve original elemental effects only. "
            else:
                prompt += "Preserve the depicted food/plant/material/relic's distinctive shape, ingredients, main colors and key details. Simplify into broad charming cartoon shapes. No added face, no added magic effects or halo if absent in the source. "
            prompt += finish
        out.write_text(prompt + "\n")
print("Individual prompts ready")
