extends Node

# Between-wave upgrade card pool for in-run player choices.
# Standard pool drawn every wave; milestone pool drawn at boss waves 5 / 10 / 15.

const CARDS: Array = [
	{
		"id":    "windfall",
		"label": "Windfall",
		"desc":  "Credits scaled to wave: +45c (waves 1–5), +70c (6–10), +95c (11–15).",
		"tag":   "economy",
		"icon":  "💰",
	},
	{
		"id":    "life_recover",
		"label": "+1 Integrity",
		"desc":  "Recover one lost Integrity.",
		"tag":   "survival",
		"icon":  "❤",
	},
	{
		"id":    "dmg_wave",
		"label": "Power Surge",
		"desc":  "All towers deal +15% damage this wave.",
		"tag":   "combat",
		"icon":  "⚔",
	},
	{
		"id":    "slow_wave",
		"label": "Entropy Field",
		"desc":  "Next wave's enemies move 20% slower when they spawn.",
		"tag":   "control",
		"icon":  "🌀",
	},
	{
		"id":    "discount",
		"label": "Supply Drop",
		"desc":  "Tower costs -25% this wave.",
		"tag":   "economy",
		"icon":  "🏷",
	},
	{
		"id":    "frost_vanguard",
		"label": "Frost Vanguard",
		"desc":  "First 10 enemies of the next wave spawn pre-chilled for 3 seconds.",
		"tag":   "control",
		"icon":  "❄",
	},
	{
		"id":    "gold_wave",
		"label": "Prospector",
		"desc":  "+3 Credits per kill this wave.",
		"tag":   "economy",
		"icon":  "⛏",
	},
	{
		"id":    "expose",
		"label": "Expose",
		"desc":  "All enemies have armor stripped and take +10% damage this wave.",
		"tag":   "combat",
		"icon":  "🔩",
	},
	{
		"id":    "rapid_spawn",
		"label": "Prep Time",
		"desc":  "Next wave's spawn interval is 40% longer (more time before each enemy).",
		"tag":   "control",
		"icon":  "⏳",
	},
]

# Offered exclusively at boss waves 5, 10, 15.
const MILESTONE_CARDS: Array = [
	{
		"id":    "adrenaline",
		"label": "Adrenaline",
		"desc":  "All towers permanently fire 8% faster. Stacks each milestone.",
		"tag":   "permanent",
		"icon":  "⚡",
	},
	{
		"id":    "war_chest",
		"label": "War Chest",
		"desc":  "+80 Credits immediately.",
		"tag":   "economy",
		"icon":  "💰",
	},
	{
		"id":    "emergency_protocol",
		"label": "Emergency Protocol",
		"desc":  "Recover 2 Integrity immediately.",
		"tag":   "survival",
		"icon":  "❤",
	},
	{
		"id":    "targeting_matrix",
		"label": "Targeting Matrix",
		"desc":  "All towers permanently gain +5% range. Stacks each milestone.",
		"tag":   "permanent",
		"icon":  "🎯",
	},
	{
		"id":    "bounty_contract",
		"label": "Bounty Contract",
		"desc":  "+2 Credits per kill permanently. Stacks each milestone.",
		"tag":   "permanent",
		"icon":  "⛏",
	},
]

## Filter out cards that conflict with any active modifier (primary + stack).
## Sudden Death's defining rule is "only 1 Integrity"; any life recovery would
## contradict it, so healing is excluded from the standard pool here.
static func filtered_pool(active_modifiers) -> Array:
	var mods: Array = []
	if active_modifiers is String:
		if active_modifiers != "":
			mods.append(active_modifiers)
	elif active_modifiers is Array:
		mods = active_modifiers
	var pool: Array = CARDS.duplicate()
	for m in mods:
		match m:
			"mod_blitz":
				pool = pool.filter(func(c): return c["id"] != "frost_vanguard" and c["id"] != "slow_wave")
			"mod_sudden_death":
				pool = pool.filter(func(c): return c["id"] != "life_recover")
	return pool

## Milestone (boss-wave) pool, filtered the same way. Boss rewards must obey the
## same modifier rules as the standard pool, otherwise Sudden Death could still
## hand the player Emergency Protocol at wave 5/10/15.
static func milestone_pool(active_modifiers) -> Array:
	var mods: Array = []
	if active_modifiers is String:
		if active_modifiers != "":
			mods.append(active_modifiers)
	elif active_modifiers is Array:
		mods = active_modifiers
	var pool: Array = MILESTONE_CARDS.duplicate()
	for m in mods:
		if m == "mod_sudden_death":
			pool = pool.filter(func(c): return c["id"] != "emergency_protocol")
	return pool
