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
# Full contract dimensions (width, height) from mananet_asset_contract.yaml.
EXPECTED_DIMENSIONS = {
    "towers": ("96", "96"),
    "enemies": ("96", "96"),
    "environment": ("900", "600"),
    "vfx": ("32", "32"),
    "ui": ("64", "64"),
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
            svg_text = path.read_text(encoding="utf-8")
            try:
                root = ElementTree.fromstring(svg_text)
            except Exception as exc:
                errors.append(f"decode:{path.name}:{exc}")
                continue
            if root.tag.rsplit("}", 1)[-1] != "svg":
                errors.append(f"root:{path.name}")
            expected_width, expected_height = EXPECTED_DIMENSIONS[family]
            if (root.attrib.get("width"), root.attrib.get("height")) != (expected_width, expected_height):
                errors.append(f"dimensions:{path.name}:expected {expected_width}x{expected_height}")
            view_box = root.attrib.get("viewBox")
            if view_box is not None:
                parts = view_box.replace(",", " ").split()
                if len(parts) != 4 or parts[2:] != [expected_width, expected_height]:
                    errors.append(
                        f"viewbox:{path.name}:expected 0 0 {expected_width} {expected_height}"
                    )
            # Sprite families must stay transparent cutouts; environment maps are
            # intentionally opaque full-viewport backdrops and are exempt.
            if family != "environment" and re.search(
                r"<rect[^>]+(?:fill|style)=['\"]#(?:05070d|000000|07111f)['\"]", svg_text, re.I
            ):
                errors.append(f"opaque-background:{path.name}")
            resource_path = f"res://assets/sprites/production/{family}/{stem}.svg"
            digest = sha256(path)
            if digest in seen_hashes:
                errors.append(f"duplicate:{path.name}:{seen_hashes[digest]}")
            seen_hashes[digest] = str(path.relative_to(ROOT)).replace("\\", "/")
            integrated = resource_path in binding_text[family]
            entries.append({"id": f"{family}.{stem}", "path": resource_path, "status": "integrated" if integrated else "accepted", "exercised": "pending-runtime-proof", "sha256": digest})
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    # The committed manifest is the source of truth. Assert that the recomputed
    # hashes match it instead of rewriting it: a rewrite can never fail, and it
    # would silently dirty the tree on every validation run.
    manifest_assets = {asset.get("id"): asset for asset in manifest.get("assets", [])}
    for entry in entries:
        declared = manifest_assets.pop(entry["id"], None)
        if declared is None:
            errors.append(f"manifest-missing:{entry['id']}")
            continue
        if declared.get("path") != entry["path"]:
            errors.append(f"manifest-path:{entry['id']}:{declared.get('path')}->{entry['path']}")
        if declared.get("sha256") != entry["sha256"]:
            errors.append(f"manifest-drift:{entry['id']}:{declared.get('sha256')}->{entry['sha256']}")
        # The declared lifecycle fields must match what the renderer/UI sources
        # actually bind; otherwise an asset can be de-integrated while the
        # committed manifest keeps claiming "integrated".
        if declared.get("status") != entry["status"]:
            errors.append(f"manifest-status:{entry['id']}:{declared.get('status')}->{entry['status']}")
        if declared.get("exercised") != entry["exercised"]:
            errors.append(f"manifest-exercised:{entry['id']}:{declared.get('exercised')}->{entry['exercised']}")
    for stale_id in manifest_assets:
        errors.append(f"manifest-extra:{stale_id}")
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
