#!/usr/bin/env python3
"""Build authored Q5 star rules from the exact published V93 baseline."""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASELINE_SHA256 = "b93de1c216fce6e362d7cc62b88af51f9da7b53b9745cccdbf0e570892f21e4c"
LIMITS = {1: 2, 2: 3, 3: 4, 4: 4, 5: 5}


def build():
    raw = (ROOT / "data/compat/catalog-v93.json").read_bytes()
    assert hashlib.sha256(raw).hexdigest() == BASELINE_SHA256, "V93 baseline changed"
    baseline = json.loads(raw)
    design = json.loads((ROOT / "data/compat/design/v101.json").read_text())
    result = copy.deepcopy(baseline)
    for kind, change in design["stars"].items():
        item = result["items"][kind]
        assert item["rarity"] == 5 and "weapon" in item["tags"], kind
        assert not baseline["items"][kind]["stars"], kind
        item["stars"] = copy.deepcopy(change["layout"])
        item["v75"]["stars"] = copy.deepcopy(change["layout"])
        item["v75"]["star"] = item["v75"]["starText"] = change["text"]
        item["v75"]["material_effect"] = copy.deepcopy(change["effect"])
    q5 = []
    for kind, item in result["items"].items():
        points = list(map(tuple, item["stars"]))
        assert len(points) <= LIMITS.get(item["rarity"], 5), kind
        assert len(points) == len(set(points)), kind
        assert not set(points).intersection(map(tuple, item["shape"])), kind
        if "weapon" in item["tags"] and item["rarity"] == 5:
            assert points, kind
            q5.append(kind)
        # The authoring step may change only layout, star rule and star description.
        normalized = copy.deepcopy(item)
        old = baseline["items"][kind]
        normalized["stars"] = old["stars"]
        if "v75" in normalized:
            for key in ["stars", "star", "starText", "material_effect"]:
                if key in old["v75"]:
                    normalized["v75"][key] = old["v75"][key]
                else:
                    normalized["v75"].pop(key, None)
        assert normalized == old, kind
    assert len(q5) == 42 and set(q5) == set(design["audit"]), "Review all Q5 weapons"
    assert len(design["stars"]) == 17
    result["design_version"] = 101
    return result


def main():
    data = build()
    (ROOT / "data/catalog.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print("V101: reviewed 42 Q5 weapons; authored 17 star rules; retained 25 existing identities")


if __name__ == "__main__":
    main()
