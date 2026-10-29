#!/usr/bin/env python3
"""Read-only HD contact sheets from the game's selected display registry.

Only output artifacts are written. Source art is never rewritten or extracted
into replacement assets; rotation and fitting happen inside each contact cell.
"""
from __future__ import annotations

import argparse
from functools import lru_cache
import hashlib
import html
import json
import math
from pathlib import Path
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONT = ROOT / "assets/fonts/body.ttf"
GROUPS = [
    ("broadblade", "长刃"), ("sword", "迅刀"), ("pistol", "佩枪"),
    ("gauntlet", "臂铠"), ("rectifier", "音感仪"), ("echo", "声骸"),
    ("material", "材料"), ("consumable", "消耗品"), ("relic", "遗物"),
    ("keepsake", "信物"), ("bag", "背包"), ("other", "其他"),
]
ELEMENTS = [("aero", "气动"), ("electro", "导电"), ("spectro", "衍射"),
            ("fusion", "热熔"), ("glacio", "冷凝"), ("havoc", "湮灭")]
PALETTES = {
    "original": {"bg": "#1c2733", "card": "#293746", "text": "#f0f1ed", "muted": "#bac6d0", "line": "#617080", "accent": "#dfcfa7"},
    "chibi": {"bg": "#f6e7c7", "card": "#fff8e9", "text": "#493858", "muted": "#72627b", "line": "#d9cbbf", "accent": "#7472bc"},
}
QUALITY = ["#51dc8e", "#43b6ff", "#b278ff", "#ffca48", "#ff586c"]
COLS, CELL_W, CELL_H, GAP, MARGIN = 6, 600, 390, 16, 48
SHEET_W = COLS * CELL_W + (COLS - 1) * GAP + 2 * MARGIN
PAIR_W, PAIR_H, PAIR_COLS = 690, 650, 6


@lru_cache(maxsize=32)
def font(size: int, bold: bool = False):
    face = ImageFont.truetype(str(FONT), size)
    if hasattr(face, "set_variation_by_name"):
        face.set_variation_by_name(b"SemiBold" if bold else b"Medium")
    return face


def group_items(rows: list[dict]) -> list[tuple[str, str, list[dict]]]:
    grouped = {key: [] for key, _ in GROUPS}
    for row in rows:
        tags = row.get("tags", [])
        if "weapon" in tags:
            key = row.get("weapon_type", "other")
        else:
            key = next((tag for tag in ["bag", "echo", "material", "consumable", "keepsake", "relic"] if tag in tags), "other")
        grouped[key if key in grouped else "other"].append(row)
    return [(key, label, grouped[key]) for key, label in GROUPS if grouped[key]]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def source_record(entry: dict) -> dict:
    path = Path(entry["path"]) if entry.get("path") else None
    render_path = Path(entry.get("render_path") or entry.get("path", ""))
    available = (entry.get("runtime", False) or (path is not None and path.is_file())) and render_path.is_file()
    return {**entry, "available": bool(available), "sha256": sha256(path) if path and path.is_file() else None,
            "display_path": str(render_path), "display_sha256": sha256(render_path) if render_path.is_file() else None}


def art_preview(path: Path, angle: float, size: tuple[int, int]) -> Image.Image | None:
    if not path.is_file():
        return None
    with Image.open(path) as source:
        image = source.convert("RGBA")
    if angle:
        # Godot's positive screen-space angle is clockwise; Pillow is opposite.
        image = image.rotate(-math.degrees(angle), resample=Image.Resampling.BICUBIC, expand=True)
    bounds = image.getchannel("A").getbbox()
    if bounds:
        image = image.crop(bounds)  # Transparent padding only, inside this layout.
    ratio = min(size[0] / image.width, size[1] / image.height)
    return image.resize((max(1, round(image.width * ratio)), max(1, round(image.height * ratio))), Image.Resampling.LANCZOS)


def wrap(draw: ImageDraw.ImageDraw, value: str, face, width: int) -> list[str]:
    lines, line = [], ""
    for character in value:
        if line and draw.textlength(line + character, font=face) > width:
            lines.append(line)
            line = ""
        line += character
    return lines + [line]


def text(draw, at, value, size, fill, bold=False):
    draw.text(at, str(value), font=font(size, bold), fill=fill, anchor="lt")


def place_art(canvas: Image.Image, entry: dict, rect: tuple[int, int, int, int], palette: dict):
    x, y, width, height = rect
    art = art_preview(Path(entry["display_path"]), float(entry.get("angle", 0)), (width, height)) if entry["available"] else None
    if art is not None:
        canvas.paste(art, (x + (width - art.width) // 2, y + (height - art.height) // 2), art)
    else:
        draw = ImageDraw.Draw(canvas)
        draw.text((x + width // 2, y + height // 2 - 12), "?", font=font(94, True), fill="#c46b65", anchor="mm")
        draw.text((x + width // 2, y + height // 2 + 61), "缺少该皮肤资源", font=font(23), fill=palette["muted"], anchor="mm")


def item_group(key: str, title: str, rows: list[dict], skin: str) -> Image.Image:
    p = PALETTES[skin]
    row_count = math.ceil(len(rows) / COLS)
    canvas = Image.new("RGB", (SHEET_W, 88 + row_count * (CELL_H + GAP)), p["bg"])
    draw = ImageDraw.Draw(canvas)
    text(draw, (MARGIN, 20), title, 40, p["text"], True)
    text(draw, (MARGIN + 230, 29), f"{len(rows):02d} 件", 25, p["muted"])
    for n, row in enumerate(rows):
        x, y = MARGIN + n % COLS * (CELL_W + GAP), 88 + n // COLS * (CELL_H + GAP)
        draw.rounded_rectangle((x, y, x + CELL_W, y + CELL_H), radius=14, fill=p["card"])
        text(draw, (x + 19, y + 15), f"{row['number']:03d}", 21, p["muted"])
        tier = max(1, min(5, row.get("tier", 1)))
        draw.ellipse((x + CELL_W - 32, y + 19, x + CELL_W - 18, y + 33), fill=QUALITY[tier - 1])
        place_art(canvas, row[skin], (x + 26, y + 46, CELL_W - 52, 235), p)
        lines = wrap(draw, row["name"], font(29, True), CELL_W - 40)
        for line_index, line in enumerate(lines):
            text(draw, (x + 20, y + 292 + line_index * 33), line, 29, p["text"], True)
        text(draw, (x + 20, y + CELL_H - 31), row["id"], 19, p["muted"])
        caption = f"T{tier} · {len(row.get('shape', []))} 格"
        draw.text((x + CELL_W - 19, y + CELL_H - 31), caption, font=font(19), fill=p["muted"], anchor="rt")
    return canvas


def character_group(title: str, rows: list[dict], leader: bool = False) -> Image.Image:
    width = 2 * MARGIN + PAIR_COLS * PAIR_W + (PAIR_COLS - 1) * GAP
    canvas = Image.new("RGB", (width, 88 + math.ceil(len(rows) / PAIR_COLS) * (PAIR_H + GAP)), PALETTES["chibi"]["bg"])
    draw = ImageDraw.Draw(canvas)
    text(draw, (MARGIN, 20), title, 40, "#493858", True)
    text(draw, (MARGIN + 260, 29), f"{len(rows):02d} 位 · 左原画 / 右 Q 版", 25, "#72627b")
    for n, row in enumerate(rows):
        x, y = MARGIN + n % PAIR_COLS * (PAIR_W + GAP), 88 + n // PAIR_COLS * (PAIR_H + GAP)
        for index, skin in enumerate(["original", "chibi"]):
            p = PALETTES[skin]
            at = x + index * (PAIR_W // 2)
            draw.rectangle((at, y, at + PAIR_W // 2, y + 557), fill=p["card"])
            text(draw, (at + 16, y + 16), "原画" if skin == "original" else "Q 版", 22, p["muted"])
            place_art(canvas, row[skin], (at + 17, y + 57, PAIR_W // 2 - 34, 480), p)
        text(draw, (x + 12, y + 575), f"{row['number']:02d}  {row['name']}", 31, "#493858", True)
        text(draw, (x + 12, y + 617), row["id"] + (" · " + row.get("role_id", "") if leader else ""), 20, "#72627b")
    return canvas


def sheet_header(title: str, subtitle: str, width: int, skin: str) -> Image.Image:
    p = PALETTES[skin]
    header = Image.new("RGB", (width, 190), p["bg"])
    draw = ImageDraw.Draw(header)
    text(draw, (MARGIN, 37), title, 57, p["text"], True)
    text(draw, (MARGIN, 117), subtitle, 28, p["muted"])
    return header


def save_sheet(image: Image.Image, path: Path, artifacts: list[dict], title: str):
    image.save(path, optimize=False, compress_level=6, dpi=(150, 150))
    preview = image.copy()
    preview.thumbnail((1200, 1800), Image.Resampling.LANCZOS)
    preview_path = path.with_name(path.stem + "-preview.jpg")
    preview.save(preview_path, quality=88, optimize=True)
    artifacts.append({"path": path.name, "preview": preview_path.name, "title": title,
                      "width": image.width, "height": image.height, "bytes": path.stat().st_size})


def build_item_sheets(data: dict, output: Path, artifacts: list[dict]):
    groups = group_items(data["items"])
    number = 1
    for _, _, rows in groups:
        for row in rows:
            row["number"] = number
            number += 1
    group_heights = [88 + math.ceil(len(rows) / COLS) * (CELL_H + GAP) for _, _, rows in groups]
    for skin, label in [("original", "原画"), ("chibi", "Q 版")]:
        missing = sum(not row[skin]["available"] for row in data["items"])
        header = sheet_header(f"物品与背包完整总览 · {label}", f"178 件物品 + 5 个背包  /  两版编号、分组、顺序一致  /  缺图 {missing}", SHEET_W, skin)
        sheet = Image.new("RGB", (SHEET_W, header.height + sum(group_heights) + 48), PALETTES[skin]["bg"])
        sheet.paste(header, (0, 0)); y = header.height
        for key, title, rows in groups:
            group = item_group(key, title, rows, skin)
            sheet.paste(group, (0, y)); y += group.height
            save_sheet(group, output / f"items-{skin}-{key}.png", artifacts, f"{label} · {title}")
        save_sheet(sheet, output / f"items-{skin}-all.png", artifacts, f"{label} · 178 物品 + 5 背包")


def build_character_sheets(data: dict, output: Path, artifacts: list[dict]):
    groups = [(key, title, [row for row in data["characters"] if row["element"] == key]) for key, title in ELEMENTS]
    number = 1
    for _, _, rows in groups:
        for row in rows:
            row["number"] = number; number += 1
    if number != len(data["characters"]) + 1:
        raise ValueError("A character element is missing from the comparison grouping")
    width = 2 * MARGIN + PAIR_COLS * PAIR_W + (PAIR_COLS - 1) * GAP
    height = 190 + sum(88 + math.ceil(len(rows) / PAIR_COLS) * (PAIR_H + GAP) for _, _, rows in groups) + 48
    sheet = Image.new("RGB", (width, height), PALETTES["chibi"]["bg"])
    missing = sum(not row[skin]["available"] for row in data["characters"] for skin in ["original", "chibi"])
    sheet.paste(sheet_header("60 位角色 · 原画 / Q 版对照", f"招募立绘逐位配对  /  完整形象等比展示  /  缺图 {missing}", width, "chibi"), (0, 0))
    y = 190
    for key, title, rows in groups:
        group = character_group(title, rows)
        sheet.paste(group, (0, y)); y += group.height
        save_sheet(group, output / f"characters-paired-{key}.png", artifacts, f"角色对照 · {title}")
    save_sheet(sheet, output / "characters-paired-all.png", artifacts, "60 位角色 · 对照总览")
    for number, row in enumerate(data["leaders"], 1):
        row["number"] = number
    leaders = character_group("6 位领队", data["leaders"], leader=True)
    save_sheet(leaders, output / "leaders-paired.png", artifacts, "6 位领队 · 全身立绘对照")


def build_overview(output: Path):
    canvas = Image.new("RGB", (1920, 1600), "#f6e7c7")
    draw = ImageDraw.Draw(canvas)
    text(draw, (48, 32), "双皮肤 · 完整资源对照", 51, "#493858", True)
    text(draw, (48, 108), "178 件物品 + 5 个背包 · 60 位角色  /  高清图可放大逐项查看", 27, "#72627b")
    for n, (name, label) in enumerate([("items-original-all", "原画 · 物品与背包"), ("items-chibi-all", "Q 版 · 物品与背包"), ("characters-paired-all", "60 位角色 · 原画 / Q 版")]):
        x = 48 + n * 624
        text(draw, (x, 179), label, 30, "#493858", True)
        with Image.open(output / f"{name}-preview.jpg") as source:
            art = source.convert("RGB")
        art.thumbnail((588, 1295), Image.Resampling.LANCZOS)
        canvas.paste(art, (x + (588 - art.width) // 2, 244))
    canvas.save(output / "comparison-preview.jpg", quality=92, optimize=True)


def build_index(output: Path, artifacts: list[dict], missing: list[dict]):
    cards = []
    primary = {"items-original-all.png", "items-chibi-all.png", "characters-paired-all.png", "leaders-paired.png"}
    for artifact in sorted(artifacts, key=lambda item: (item["path"] not in primary, item["path"])):
        cards.append(f'<a class="card" href="{html.escape(artifact["path"])}"><img loading="lazy" src="{html.escape(artifact["preview"])}"><b>{html.escape(artifact["title"])}</b><small>{artifact["width"]} × {artifact["height"]} · PNG</small></a>')
    missing_rows = "".join(f'<tr><td>{html.escape(row["skin"])}</td><td>{html.escape(row["name"])}</td><td>{html.escape(row["id"])}</td></tr>' for row in missing)
    page = '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>双皮肤高清对照</title><style>body{margin:0;background:#f6e7c7;color:#493858;font:16px system-ui,sans-serif}main{max-width:1280px;margin:48px auto;padding:0 24px}h1{font-size:36px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:20px}.card{color:inherit;text-decoration:none;background:#fff8e9;border-radius:14px;padding:16px;display:flex;flex-direction:column;gap:10px}.card img{width:100%;height:310px;object-fit:contain}.card small{opacity:.7}table{border-collapse:collapse;width:100%}td,th{padding:9px;text-align:left;border-bottom:1px solid #cdbdaa}</style><main><h1>双皮肤 · 高清对照</h1>'
    page += f'<p>178 件物品 + 5 个背包，60 位角色，6 位领队。两版编号与顺序一致；点击打开高清原图。当前缺图 {len(missing)} 项（含领队重复引用）。</p><p>图像均等比展示，方向来自游戏当前 display registry；背包由当前原生渲染入口生成。源资源未修改。</p><div class="grid">' + "".join(cards) + '</div><h2>缺图清单</h2>'
    page += '<table><thead><tr><th>皮肤</th><th>名称</th><th>ID</th></tr></thead><tbody>' + missing_rows + '</tbody></table><p><a href="index.json">资源路径、SHA-256 与逐项清单</a> · <a href="comparison-preview.jpg">对话展示缩略总览</a></p></main></html>'
    (output / "index.html").write_text(page, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "build/qa/demo-v50/comparison")
    parser.add_argument("--godot", default="/Applications/Godot.app/Contents/MacOS/Godot")
    parser.add_argument("--strict", action="store_true", help="Write sheets, then fail if any selected source is missing")
    args = parser.parse_args()
    output = args.output_dir.resolve()
    if output == ROOT or output == ROOT / "assets" or ROOT / "assets" in output.parents:
        parser.error("output-dir must not be the project root or inside source assets")
    output.mkdir(parents=True, exist_ok=True)
    command = [args.godot, "--path", str(ROOT), "--script", str(ROOT / "tools/legacy/render_skin_comparison.gd"), "--", f"--output-dir={output}"]
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    (output / "native-export.log").write_text(result.stdout + result.stderr, encoding="utf-8")
    if result.returncode or "SCRIPT ERROR" in result.stderr or "ERROR:" in result.stderr:
        print(result.stdout + result.stderr, file=sys.stderr)
        return result.returncode or 2
    data = json.loads((output / "source-index.json").read_text())
    if len(data["items"]) != 183 or len(data["characters"]) != 60 or len({row["id"] for row in data["items"]}) != 183:
        raise ValueError("Expected exactly 178 items + 5 bags and 60 characters")
    missing = []
    for group in ["items", "characters", "leaders"]:
        for row in data[group]:
            for skin in ["original", "chibi"]:
                row[skin] = source_record(row[skin])
                if not row[skin]["available"]:
                    missing.append({"group": group, "id": row["id"], "name": row["name"], "skin": skin, "path": row[skin]["path"]})
    artifacts = []
    build_item_sheets(data, output, artifacts)
    build_character_sheets(data, output, artifacts)
    build_overview(output)
    # Source hashes are captured before layout and verified afterwards.
    checked = set()
    for group in ["items", "characters", "leaders"]:
        for row in data[group]:
            for skin in ["original", "chibi"]:
                record = row[skin]
                if record["sha256"] and record["path"] not in checked:
                    if sha256(Path(record["path"])) != record["sha256"]:
                        raise RuntimeError(f"Source changed during contact-sheet build: {record['path']}")
                    checked.add(record["path"])
    result = {"counts": {key: len(data[key]) for key in ["items", "characters", "leaders"]},
              "source_files_verified_unchanged": len(checked), "missing": missing, "artifacts": artifacts, "data": data}
    (output / "index.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    build_index(output, artifacts, missing)
    print(f"COMPARISON: {len(artifacts)} HD sheets; 183 item IDs; 60 characters; {len(missing)} missing; {len(checked)} source hashes unchanged")
    print(output / "index.html")
    return 1 if args.strict and missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
