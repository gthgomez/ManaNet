extends Node

# Mirror of TOWER_TYPES / BASE_LEVEL_COSTS / PATH_UPGRADE_COSTS from core.py

const TOWER_TYPES: Dictionary = {
	"archer": {
		"cost": 80, "range": 130, "damage": 18, "cooldown": 450,
		"color": Color(0, 0.902, 0.463), "name": "Cyber-Ranger"
	},
	"mage": {
		"cost": 140, "range": 110, "damage": 58, "cooldown": 1050,
		"color": Color(0.784, 0.267, 1.0), "name": "Netrunner"
	},
	"cannon": {
		"cost": 180, "range": 95, "damage": 68, "cooldown": 1350,
		"color": Color(1.0, 0.549, 0.0), "name": "Plasma Artillery"
	},
	"sniper": {
		"cost": 150, "range": 230, "damage": 52, "cooldown": 1250,
		"color": Color(0.533, 0.8, 1.0), "name": "Sniper Proxy"
	},
	"frost": {
		"cost": 110, "range": 108, "damage": 18, "cooldown": 720,
		"color": Color(0.0, 0.898, 1.0), "name": "Thermal Siphon"
	},
	"lightning": {
		"cost": 160, "range": 105, "damage": 34, "cooldown": 470,
		"color": Color(0.784, 1.0, 0.0), "name": "Server Node"
	},
}

const BASE_LEVEL_COSTS: Array = [45, 60, 80, 105]   # level 1->2 .. 4->5
const PATH_UPGRADE_COSTS: Array = [80, 120, 175, 235, 320]

const TOWER_TYPES_LIST: Array = ["archer", "mage", "cannon", "sniper", "frost", "lightning"]
