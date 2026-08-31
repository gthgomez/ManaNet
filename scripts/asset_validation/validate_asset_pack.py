"""Validate the production SVG pack and optionally consume causal runtime proof.

Static validation can establish present/valid/bound. It cannot establish that a
texture was loaded or rendered. Those fields remain null until the Godot runtime
certification harness supplies evidence from live render pools and UI controls.
"""
from __future__ import annotations

import argparse
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


def _runtime_evidence(path: Path | None) -> tuple[dict[str, dict], list[str]]:
    if path is None:
        return {}, []
    if not path.exists():
        return {}, [f"runtime-evidence-missing:{path}"]
    try:
        parsed = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return {}, [f"runtime-evidence-decode:{path}:{exc}"]
    if not isinstance(parsed, dict) or not isinstance(parsed.get("assets"), list):
        return {}, ["runtime-evidence-shape:expected object with assets array"]
    evidence: dict[str, dict] = {}
    errors: list[str] = []
    for item in parsed["assets"]:
        if not isinstance(item, dict) or not item.get("id"):
            errors.append("runtime-evidence-entry:missing-id")
            continue
        asset_id = str(item["id"])
        if asset_id in evidence:
            errors.append(f"runtime-evidence-duplicate:{asset_id}")
        evidence[asset_id] = item
    return evidence, errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime-evidence", type=Path, help="JSON emitted by runtime_asset_certification.gd")
    args = parser.parse_args()

    errors: list[str] = []
    entries: list[dict] = []
    seen_hashes: dict[str, str] = {}
    runtime, runtime_errors = _runtime_evidence(args.runtime_evidence)
    errors.extend(runtime_errors)
    binding_text = {family: BINDING_SOURCES[family].read_text(encoding="utf-8") for family in EXPECTED}

    for family, stems in EXPECTED.items():
        for stem in stems:
            path = SVG_ROOT / family / f"{stem}.svg"
            resource_path = f"res://assets/sprites/production/{family}/{stem}.svg"
            asset_id = f"{family}.{stem}"
            present = path.exists()
            valid = False
            digest = None
            if not present:
                errors.append(f"missing:{path.relative_to(ROOT)}")
            else:
                source = path.read_text(encoding="utf-8")
                root = None
                try:
                    root = ElementTree.fromstring(source)
                    valid = root.tag.rsplit("}", 1)[-1] == "svg"
                except Exception as exc:
                    errors.append(f"decode:{path.name}:{exc}")
                if not valid:
                    errors.append(f"root:{path.name}")
                expected_width = {"towers": "96", "enemies": "96", "environment": "900", "vfx": "32", "ui": "64"}[family]
                if root is not None and root.attrib.get("width") != expected_width:
                    valid = False
                    errors.append(f"dimensions:{path.name}:expected {expected_width}")
                if re.search(r"<rect[^>]+(?:fill|style)=['\"]#(?:05070d|000000)['\"]", source, re.I):
                    valid = False
                    errors.append(f"opaque-background:{path.name}")
                digest = sha256(path)
                if digest in seen_hashes:
                    valid = False
                    errors.append(f"duplicate:{path.name}:{seen_hashes[digest]}")
                seen_hashes[digest] = str(path.relative_to(ROOT)).replace("\\", "/")

            bound_static = resource_path in binding_text[family]
            runtime_item = runtime.get(asset_id)
            runtime_path_ok = runtime_item is not None and runtime_item.get("path") == resource_path
            if runtime_item is not None and not runtime_path_ok:
                errors.append(f"runtime-evidence-path-mismatch:{asset_id}")
            loaded = bool(runtime_item["loaded"]) if runtime_path_ok and isinstance(runtime_item.get("loaded"), bool) else None
            exercised = bool(runtime_item["exercised"]) if runtime_path_ok and isinstance(runtime_item.get("exercised"), bool) else None
            visually_reviewed = bool(runtime_item["visually_reviewed"]) if runtime_path_ok and isinstance(runtime_item.get("visually_reviewed"), bool) else None
            bound = bound_static and (bool(runtime_item.get("bound")) if runtime_path_ok else True)
            if not present:
                status = "missing"
            elif not valid:
                status = "invalid"
            elif not bound:
                status = "unbound"
            elif loaded is None or exercised is None:
                status = "runtime-pending"
            elif not loaded:
                status = "load-failed"
            elif not exercised:
                status = "not-exercised"
            elif visually_reviewed is not True:
                status = "runtime-exercised-review-pending"
            else:
                status = "runtime-certified"
            entries.append({
                "id": asset_id,
                "path": resource_path,
                "present": present,
                "valid": valid,
                "bound": bound,
                "loaded": loaded,
                "exercised": exercised,
                "visually_reviewed": visually_reviewed,
                "status": status,
                "scenario": runtime_item.get("scenario") if runtime_path_ok else None,
                "frame_count_seen": runtime_item.get("frame_count_seen", 0) if runtime_path_ok else 0,
                "sha256": digest,
            })

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    manifest["verification"] = {
        "static_validator": "pass" if not errors else "fail",
        "runtime_evidence": str(args.runtime_evidence).replace("\\", "/") if args.runtime_evidence else None,
        "runtime_certified": bool(entries) and all(entry["status"] == "runtime-certified" for entry in entries),
    }
    manifest["assets"] = entries
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    if errors:
        print("ASSET_PACK_FAIL")
        print("\n".join(errors))
        return 1
    counts = {key: sum(1 for entry in entries if entry[key] is True) for key in ("present", "valid", "bound", "loaded", "exercised", "visually_reviewed")}
    unknown = {key: sum(1 for entry in entries if entry[key] is None) for key in ("loaded", "exercised", "visually_reviewed")}
    print(f"ASSET_PACK_PASS assets={len(entries)} unique_hashes={len(seen_hashes)}")
    print("PRESENT=", counts["present"], "VALID=", counts["valid"], "BOUND=", counts["bound"])
    print("LOADED=", counts["loaded"], "EXERCISED=", counts["exercised"], "VISUALLY_REVIEWED=", counts["visually_reviewed"], "UNKNOWN=", unknown)
    if args.runtime_evidence is None:
        print("RUNTIME_EVIDENCE=not-provided; runtime fields remain null")
    return 0


if __name__ == "__main__":
    sys.exit(main())
