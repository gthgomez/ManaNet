extends Node

# Between-wave upgrade card pool for in-run player choices.
# Standard pool drawn every wave; milestone pool drawn at boss waves 5 / 10 / 15.

const CARDS: Array = [
	{
		"id":    "windfall",
		"label": "Windfall",
		"desc":  "Gold scaled to wave: +30g (waves 1–5), +50g (6–10), +70g (11–15).",
		"tag":   "economy",
		"icon":  "💰",
	},
	{
		"id":    "life_recover",
		"label": "+1 Life",
		"desc":  "Recover one lost life.",
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
		"desc":  "Next wave enemies spawn 20% slower.",
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
		"desc":  "+8 gold per kill this wave.",
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
		"desc":  "Spawn interval +40% slower this wave (more time to build).",
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
		"desc":  "+80 gold immediately.",
		"tag":   "economy",
		"icon":  "💰",
	},
	{
		"id":    "emergency_protocol",
		"label": "Emergency Protocol",
		"desc":  "Recover 2 lives immediately.",
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
		"desc":  "+2 gold per kill permanently. Stacks each milestone.",
		"tag":   "permanent",
		"icon":  "⛏",
	},
]

# Filter out cards that conflict with the active modifier.
static func filtered_pool(active_modifier: String) -> Array:
	var pool: Array = CARDS.duplicate()
	match active_modifier:
		"mod_blitz":
			pool = pool.filter(func(c): return c["id"] != "frost_vanguard" and c["id"] != "slow_wave")
		"mod_sudden_death":
			pool = pool.filter(func(c): return c["id"] != "life_recover")
	return pool

# Draw `count` cards. At milestone waves (5/10/15) always uses the milestone pool.
static func draw_cards(pool: Array, count: int, wave: int = 0) -> Array:
	if wave in [5, 10, 15]:
		var ms: Array = MILESTONE_CARDS.duplicate()
		ms.shuffle()
		return ms.slice(0, mini(count, ms.size()))
	var shuffled: Array = pool.duplicate()
	shuffled.shuffle()
	return shuffled.slice(0, mini(count, shuffled.size()))
