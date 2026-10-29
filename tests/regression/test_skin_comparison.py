"""Contact sheets preserve source bytes, proportions, ordering, and missing rows."""
import importlib.util
import math
from pathlib import Path
import tempfile
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "build_skin_comparison.py"


class ComparisonTests(unittest.TestCase):
    def tool(self):
        self.assertTrue(TOOL.exists(), "repeatable contact-sheet builder exists")
        spec = importlib.util.spec_from_file_location("skin_comparison", TOOL)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_groups_cover_each_id_once_in_stable_order(self):
        tool = self.tool()
        rows = [
            {"id": "weapon_b", "tags": ["weapon"], "weapon_type": "sword"},
            {"id": "bag", "tags": ["bag"]},
            {"id": "echo", "tags": ["echo"]},
            {"id": "weapon_a", "tags": ["weapon"], "weapon_type": "sword"},
        ]
        groups = tool.group_items(rows)
        flattened = [row["id"] for _, _, group in groups for row in group]
        self.assertCountEqual(flattened, [row["id"] for row in rows])
        self.assertEqual(flattened, ["weapon_b", "weapon_a", "echo", "bag"])
        self.assertEqual(tool.group_items(rows), groups)

    def test_display_rotation_and_uniform_fit_keep_source_bytes(self):
        tool = self.tool()
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "blade.png"
            art = Image.new("RGBA", (160, 40), (255, 0, 0, 255))
            art.paste((0, 0, 255, 255), (80, 0, 160, 40))
            art.save(source)
            before = source.read_bytes()
            preview = tool.art_preview(source, math.pi / 2, (200, 300))
            self.assertAlmostEqual(preview.height / preview.width, 4, delta=.05)
            self.assertLessEqual(preview.height, 300)
            self.assertEqual(preview.getpixel((preview.width // 2, preview.height // 4)), (255, 0, 0, 255))
            self.assertEqual(preview.getpixel((preview.width // 2, preview.height * 3 // 4)), (0, 0, 255, 255))
            self.assertEqual(source.read_bytes(), before)

    def test_missing_is_explicit_and_never_uses_original(self):
        tool = self.tool()
        with tempfile.TemporaryDirectory() as directory:
            entry = {"path": str(Path(directory) / "not-yet-generated.png"), "angle": 0}
            self.assertFalse(tool.source_record(entry)["available"])
            self.assertIsNone(tool.art_preview(Path(entry["path"]), 0, (100, 100)))


if __name__ == "__main__":
    unittest.main()
