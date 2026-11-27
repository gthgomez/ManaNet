#!/usr/bin/env python3
"""Rough RMS diff between 1672x941 captures and authoritative Nov 2026 references."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
REF = REPO / "art" / "references" / "authoritative" / "nov-2026"
CAP = REPO / "docs" / "qa" / "captures" / "1672x941"

PAIRS = [
	("reference_a_main_menu.png", CAP / "menu" / "menu.png", "main menu"),
	("reference_b_map_select.png", CAP / "maps" / "maps.png", "map select"),
	("reference_c_gameplay.png", CAP / "game_nov2026" / "game_combat.png", "gameplay"),
]


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.parse_args()
	try:
		from PIL import Image, ImageChops
	except ImportError:
		print("compare_nov2026: install Pillow to run pixel diffs", file=sys.stderr)
		return 2

	worst = 0.0
	for ref_name, cap_path, label in PAIRS:
		ref_path = REF / ref_name
		if not ref_path.is_file() or not cap_path.is_file():
			print("SKIP %s (missing %s or %s)" % (label, ref_path, cap_path))
			continue
		ref = Image.open(ref_path).convert("RGB")
		cap = Image.open(cap_path).convert("RGB")
		if ref.size != cap.size:
			cap = cap.resize(ref.size, Image.Resampling.LANCZOS)
		diff = ImageChops.difference(ref, cap)
		pixels = list(diff.getdata())
		n = max(1, len(pixels) * 3)
		sq = 0.0
		for pixel in pixels:
			for ch in pixel:
				sq += float(ch) * float(ch)
		rms = (sq / float(n)) ** 0.5
		pct = 100.0 * rms / 255.0
		worst = max(worst, pct)
		print("%s: RMS diff %.1f%% (%dx%d)" % (label, pct, ref.size[0], ref.size[1]))
	print("compare_nov2026: worst surface RMS %.1f%% (lower is closer; procedural art won't match paint)" % worst)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
