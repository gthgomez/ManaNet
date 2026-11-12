extends Node

# Mirror of MAPS from core.py
# path entries are Vector2 — Godot-native equivalent of (x, y) tuples.

const MAPS: Array = [
	{
		"id": 0,
		"name": "S-Curve",
		"subtitle": "COMPROMISED SECTOR",
		"desc": "A corrupted district under AI instability. Expect unpredictable routes and heightened enemy activity.",
		"difficulty": 3,
		"path": [
			Vector2(-40, 300), Vector2(250, 300), Vector2(250, 100), Vector2(450, 100),
			Vector2(450, 450), Vector2(650, 450), Vector2(650, 200), Vector2(940, 200),
		],
	},
	{
		"id": 1,
		"name": "Gauntlet",
		"subtitle": "INDUSTRIAL FIREWALL",
		"desc": "A high-pressure industrial zone that channels enemy forces through tight, strategic chokepoints.",
		"difficulty": 2,
		"path": [
			Vector2(-40, 480), Vector2(380, 480), Vector2(380, 340), Vector2(200, 340),
			Vector2(200, 160), Vector2(550, 160), Vector2(550, 340), Vector2(720, 340),
			Vector2(720, 480), Vector2(940, 480),
		],
	},
	{
		"id": 2,
		"name": "Spiral",
		"subtitle": "CORPORATE PERIMETER",
		"desc": "A controlled perimeter around Arcana's core facilities. Learn the basics and establish your defense.",
		"difficulty": 1,
		"path": [
			Vector2(-40, 300), Vector2(200, 300), Vector2(200, 100), Vector2(750, 100),
			Vector2(750, 500), Vector2(300, 500), Vector2(300, 180), Vector2(600, 180),
			Vector2(600, 390), Vector2(450, 390), Vector2(450, 310), Vector2(940, 310),
		],
	},
]

const WIDTH: int = 900
const HEIGHT: int = 600
const PATH_RADIUS: int = 28
const TOWER_RADIUS: int = 22
const MAX_WAVE: int = 15
const FPS: int = 60
const PATH_KEYS: Array = ["Top", "Middle", "Bottom"]
const TARGET_MODES: Array = ["first", "last", "strong", "weak", "close"]
