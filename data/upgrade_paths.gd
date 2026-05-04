extends Node

# Mirror of UPGRADE_PATHS from core.py
# Descriptions include actual mechanical stats derived from Tower.gd / GameState.gd.

const UPGRADE_PATHS: Dictionary = {
	"archer": [
		{
			"path": "Top", "name": "Sylvan", "tiers": [1.1, 1.14, 1.18, 1.22, 1.3],
			"special": "root",
			"desc": "Arrows carry natural toxins that root enemies on hit.\nRoot chance: 8% (L1) → 11% (L2) → 14% (L3) → 17% (L4) → 20% (L5).\nDamage multiplier: ×1.10 (L1) → ×1.30 (L5).",
		},
		{
			"path": "Middle", "name": "Ranger", "tiers": [1.08, 1.1, 1.12, 1.15, 1.18],
			"special": "multi",
			"desc": "Fires multiple arrows and attacks faster.\nArrows per shot: 1 → 2 (L1) → 3 (L2+). Cooldown reduction: −8% (L1) → −16% (L2) → up to −38% at L5.\nDamage multiplier: ×1.08 (L1) → ×1.18 (L5).",
		},
		{
			"path": "Bottom", "name": "Hunter", "tiers": [1.2, 1.25, 1.3, 1.35, 1.45],
			"special": "focus",
			"desc": "Precision training for devastating single-target hits.\nBonus damage per level: +12% (L1) → +24% (L2) → up to +60% (L5). Detects stealth at L2. +25% Power when Hunter is dominant path.\nDamage multiplier: ×1.20 (L1) → ×1.45 (L5).",
		},
	],
	"mage": [
		{
			"path": "Top", "name": "Pyromancy", "tiers": [1.18, 1.22, 1.28, 1.35, 1.5],
			"special": "burn",
			"desc": "Ignites targets and unleashes area explosions.\nBurn DoT: 55% of hit DPS for 2.4 s (L1) → 115% DPS for 4.0 s (L5). AoE splash radius: 54 (L1) → 66 → 78 → 90 → 102 px (L5), dealing 55% splash damage.\n+15% Power when Pyromancy is dominant path.",
		},
		{
			"path": "Middle", "name": "Alchemy", "tiers": [1.05, 1.1, 1.15, 1.2, 1.25],
			"special": "transmute",
			"desc": "Transmutes slain enemies into bonus gold.\nGold per kill: +2g (L1) → +3g (L2) → +4g (L3) → +5g (L4) → +6g (L5).\nDamage multiplier: ×1.05 (L1) → ×1.25 (L5).",
		},
		{
			"path": "Bottom", "name": "Arcanist", "tiers": [1.12, 1.18, 1.25, 1.32, 1.45],
			"special": "mana_leak",
			"desc": "Applies Mana Leak: the target receives increased damage from ALL towers.\nExtra damage taken: +6% (L1) → +12% (L2) → +18% (L3) → +24% (L4) → +30% (L5).\nDamage multiplier: ×1.12 (L1) → ×1.45 (L5).",
		},
	],
	"cannon": [
		{
			"path": "Top", "name": "Siege", "tiers": [1.2, 1.25, 1.3, 1.35, 1.45],
			"special": "aoe",
			"desc": "Heavy shells explode on impact, dealing AoE damage.\nBlast radius: 70 (L1) → 88 → 106 → 124 → 142 px (L5). Splash deals 65% of hit damage to all enemies in radius. Triggers screen shake.\nDamage multiplier: ×1.20 (L1) → ×1.45 (L5).",
		},
		{
			"path": "Middle", "name": "Rapid", "tiers": [1.08, 1.1, 1.13, 1.16, 1.2],
			"special": "rapid",
			"desc": "Automated reloaders drastically increase fire rate.\nCooldown reduction: −9% (L1) → −18% (L2) → −27% (L3) → −36% (L4) → −45% (L5).\nDamage multiplier: ×1.08 (L1) → ×1.20 (L5).",
		},
		{
			"path": "Bottom", "name": "Mortar", "tiers": [1.1, 1.14, 1.18, 1.22, 1.28],
			"special": "shock",
			"desc": "High-arc shells stun the primary target and chill nearby enemies.\nStun duration: 550 ms (L1) → 700 ms (L2) → 850 ms (L3) → 1000 ms (L4) → 1150 ms (L5). Nearby chill: 400–800 ms.\nDamage multiplier: ×1.10 (L1) → ×1.28 (L5).",
		},
	],
	"sniper": [
		{
			"path": "Top", "name": "Assassin", "tiers": [1.22, 1.28, 1.35, 1.42, 1.55],
			"special": "crit",
			"desc": "Precision strikes against vital points trigger devastating crits.\nCrit chance: 16% (L1) → 20% (L2) → 24% (L3) → 28% (L4) → 32% (L5). Critical hits deal 2.5× damage.\n+20% Power when Assassin is dominant path.",
		},
		{
			"path": "Middle", "name": "Scout", "tiers": [1.08, 1.12, 1.16, 1.2, 1.25],
			"special": "reveal",
			"desc": "Tactical scope extends range and marks stealth targets.\nRange bonus: +4% per level (+20% at L5). L2+: hit enemies are flared — stealth revealed for 3.5 s (L2) → 4.0 s (L3) → 4.5 s (L4) → 5.0 s (L5).\nDamage multiplier: ×1.08 (L1) → ×1.25 (L5).",
		},
		{
			"path": "Bottom", "name": "Elite", "tiers": [1.15, 1.2, 1.25, 1.3, 1.4],
			"special": "armor",
			"desc": "Calibrated armor-piercing rounds ignore enemy protection.\nArmor ignored: 12% (L1) → 24% (L2) → 36% (L3) → 40% (L4–L5, capped).\nDamage multiplier: ×1.15 (L1) → ×1.40 (L5).",
		},
	],
	"frost": [
		{
			"path": "Top", "name": "Glacier", "tiers": [1.1, 1.15, 1.2, 1.25, 1.35],
			"special": "fragile",
			"desc": "Glacial coating makes enemies Fragile: all towers deal +15% more damage to them (active from L1). Extends chill: 1.0 s (L1) → 1.1 s → 1.3 s → 1.4 s → 1.5 s (L5).\nDamage multiplier: ×1.10 (L1) → ×1.35 (L5).",
		},
		{
			"path": "Middle", "name": "Absolute Zero", "tiers": [1.1, 1.15, 1.2, 1.25, 1.35],
			"special": "shatter",
			"desc": "Freezes enemies solid. L2+: targets are frozen for 0.53 s (L2) → 0.62 s (L3) → 0.71 s (L4) → 0.80 s (L5). Frozen targets take 2× damage from Physical & Earth (Shatter).\nDamage multiplier: ×1.10 (L1) → ×1.35 (L5).",
		},
		{
			"path": "Bottom", "name": "Cryo-Stasis", "tiers": [1.15, 1.2, 1.25, 1.32, 1.45],
			"special": "rewind",
			"desc": "Stasis fields teleport enemies backward along the path.\nRewind chance: 9% (L1) → 13% (L2) → 17% (L3) → 21% (L4) → 25% (L5), sending target 18% back. L2+: every hit also guarantees a 35% (L2) → 40% (L3) → 45% (L4) → 50% (L5) path rewind.\nDamage multiplier: ×1.15 (L1) → ×1.45 (L5).",
		},
	],
	"lightning": [
		{
			"path": "Top", "name": "Tesla", "tiers": [1.1, 1.15, 1.2, 1.25, 1.35],
			"special": "voltage",
			"desc": "Voltage builds up on sustained fire against the same target.\n+5% damage for each consecutive hit on the same enemy (unlimited stacking). Range bonus: +2% per level (+10% at L5).\nDamage multiplier: ×1.10 (L1) → ×1.35 (L5).",
		},
		{
			"path": "Middle", "name": "Overcharge", "tiers": [1.18, 1.24, 1.3, 1.38, 1.5],
			"special": "flare",
			"desc": "Supercharges the coil for burst damage and stealth-revealing flares.\nFlare reveals stealth for 2.8 s (L1) → 3.4 s (L2) → 4.0 s (L3) → 4.6 s (L4) → 5.2 s (L5). Cooldown reduction: −7% per level (max −42% at L5).\nDamage multiplier: ×1.18 (L1) → ×1.50 (L5).",
		},
		{
			"path": "Bottom", "name": "Pulsar", "tiers": [1.1, 1.15, 1.2, 1.25, 1.35],
			"special": "disrupt",
			"desc": "EMP pulse disrupts enemy abilities and strips shields.\nDisrupt duration: 1.2 s (L1) → 1.6 s (L2) → 2.0 s (L3) → 2.4 s (L4) → 2.8 s (L5). Shield damage: 10 pts per level per hit (L1: 10 → L5: 50).\nDamage multiplier: ×1.10 (L1) → ×1.35 (L5).",
		},
	],
}

static func get_path_data(ttype: String, path: String) -> Dictionary:
	if not UPGRADE_PATHS.has(ttype): return {}
	for item in UPGRADE_PATHS[ttype]:
		if item["path"] == path:
			return item
	return {}
