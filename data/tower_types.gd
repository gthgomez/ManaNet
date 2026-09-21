extends Node

# Mirror of TOWER_TYPES / BASE_LEVEL_COSTS / PATH_UPGRADE_COSTS from core.py

const TOWER_TYPES: Dictionary = {
	"archer": {
		"cost": 80, "range": 130, "damage": 18, "cooldown": 450,
		"color": Color(0.0, 0.84, 1.0), "name": "Plasma Repeater"
	},
	"mage": {
		"cost": 140, "range": 110, "damage": 58, "cooldown": 1050,
		"color": Color(0.655, 0.545, 1.0), "name": "Flux Crucible"
	},
	"cannon": {
		"cost": 180, "range": 95, "damage": 68, "cooldown": 1350,
		"color": Color(1.0, 0.545, 0.29), "name": "Nova Bombard"
	},
	"sniper": {
		"cost": 150, "range": 230, "damage": 52, "cooldown": 1250,
		"color": Color(0.65, 0.91, 1.0), "name": "Rail Ballista"
	},
	"frost": {
		"cost": 110, "range": 108, "damage": 18, "cooldown": 720,
		"color": Color(0.42, 0.94, 1.0), "name": "Cryo Obelisk"
	},
	"lightning": {
		"cost": 160, "range": 105, "damage": 34, "cooldown": 470,
		"color": Color(0.72, 0.62, 1.0), "name": "Tesla Spire"
	},
}

const BASE_LEVEL_COSTS: Array = [45, 60, 80, 105]   # level 1->2 .. 4->5
const PATH_UPGRADE_COSTS: Array = [80, 120, 175, 235, 320]

const TOWER_TYPES_LIST: Array = ["archer", "mage", "cannon", "sniper", "frost", "lightning"]
