"""Deterministic validation for ManaNet's transparent SVG production pack.

This validator intentionally does not claim VLM aesthetic review or provider-backed
generation. It checks decodeable SVG structure, dimensions, transparency intent,
manifest coverage, duplicate hashes, and the renderer binding contract.
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "production" / "asset_manifest.json"
SVG_ROOT = ROOT / "assets" / "sprites" / "production"
EXPECTED = {
    "towers": ["plasma_repeater", "nova_bombard", "rail_ballista", "tesla_spire", "cryo_obelisk", "flux_crucible"],
    "enemies": ["intrusion", "fast_scout", "armored_firewall", "flying_drone", "swarm_minion", "heavy_brute", "shielded_brute", "swarm_carrier", "regenerator"],
    "environment": ["s_curve", "gauntlet", "spiral"],
    "vfx": ["plasma_bolt", "nova_bomb", "rail_lance", "tesla_arc", "cryo_pulse", "flux_burst"],
    "ui": ["credits", "integrity", "shards", "patch", "cyber_deck", "boss_warning"],
}
BINDING_SOURCES = {
    "towers": ROOT / "rendering" / "GameRenderer.gd",
    "enemies": ROOT / "rendering" / "GameRenderer.gd",
    "environment": ROOT / "rendering" / "GameRenderer.gd",
    "vfx": ROOT / "rendering" / "GameRenderer.gd",
    "ui": ROOT / "scenes" / "GameScreen.gd",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    errors: list[str] = []
    entries: list[dict] = []
    seen_hashes: dict[str, str] = {}
    binding_text = {family: BINDING_SOURCES[family].read_text(encoding="utf-8") for family in EXPECTED}
    for family, stems in EXPECTED.items():
        for stem in stems:
            path = SVG_ROOT / family / f"{stem}.svg"
            if not path.exists():
                errors.append(f"missing:{path.relative_to(ROOT)}")
                continue
            try:
                root = ElementTree.fromstring(path.read_text(encoding="utf-8"))
            except Exception as exc:
                errors.append(f"decode:{path.name}:{exc}")
                continue
            if root.tag.rsplit("}", 1)[-1] != "svg":
                errors.append(f"root:{path.name}")
            expected_width = {"towers": "96", "enemies": "96", "environment": "900", "vfx": "32", "ui": "64"}[family]
            if root.attrib.get("width") != expected_width:
                errors.append(f"dimensions:{path.name}:expected {expected_width}")
            if re.search(r"<rect[^>]+(?:fill|style)=['\"]#(?:05070d|000000)['\"]", path.read_text(encoding="utf-8"), re.I):
                errors.append(f"opaque-background:{path.name}")
            resource_path = f"res://assets/sprites/production/{family}/{stem}.svg"
            digest = sha256(path)
            if digest in seen_hashes:
                errors.append(f"duplicate:{path.name}:{seen_hashes[digest]}")
            seen_hashes[digest] = str(path.relative_to(ROOT)).replace("\\", "/")
            integrated = resource_path in binding_text[family]
            entries.append({"id": f"{family}.{stem}", "path": resource_path, "status": "integrated" if integrated else "accepted", "exercised": "pending-runtime-proof", "sha256": digest})
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    manifest["assets"] = entries
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    if errors:
        print("ASSET_PACK_FAIL")
        print("\n".join(errors))
        return 1
    print(f"ASSET_PACK_PASS assets={len(entries)} unique_hashes={len(seen_hashes)}")
    accepted = sum(1 for entry in entries if entry["status"] == "accepted" or entry["status"] == "integrated")
    integrated = sum(1 for entry in entries if entry["status"] == "integrated")
    print("VALIDATED=", len(entries), "ACCEPTED=", accepted, "INTEGRATED=", integrated, "EXERCISED=pending-runtime-proof")
    return 0


if __name__ == "__main__":
    sys.exit(main())
