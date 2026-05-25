extends Node

# Mirror of UPGRADE_PATHS from core.py
# Descriptions include actual mechanical stats derived from Tower.gd / GameState.gd.

const UPGRADE_PATHS: Dictionary = {
	"archer": [
		{
			"path": "Top", "name": "Grid-Toxin", "tiers": [1.1, 1.14, 1.18, 1.22, 1.3],
			"special": "root",
			"desc": "Plasma bolts carry grid-toxins that lock down enemy movements on hit.\nRoot chance: 8% (L1) → 11% (L2) → 14% (L3) → 17% (L4) → 20% (L5).\nDamage multiplier: ×1.10 (L1) → ×1.30 (L5).",
		},
		{
			"path": "Middle", "name": "Hyper-Threader", "tiers": [1.08, 1.1, 1.12, 1.15, 1.18],
			"special": "multi",
			"desc": "Fires multiple plasma bolts and processes attacks faster.\nBolts per shot: 1 → 2 (L1) → 3 (L2+). Discharge delay reduction: −8% (L1) → −16% (L2) → up to −38% at L5.\nDamage multiplier: ×1.08 (L1) → ×1.18 (L5).",
		},
		{
			"path": "Bottom", "name": "Laser Focus", "tiers": [1.2, 1.25, 1.3, 1.35, 1.45],
			"special": "focus",
			"desc": "Optronic targeting for devastating single-target hits.\nBonus damage per level: +12% (L1) → +24% (L2) → up to +60% (L5). Detects stealth at L2. +25% Power when Laser Focus is dominant path.\nDamage multiplier: ×1.20 (L1) → ×1.45 (L5).",
		},
	],
	"mage": [
		{
			"path": "Top", "name": "Firewall Overflow", "tiers": [1.18, 1.22, 1.28, 1.35, 1.5],
			"special": "burn",
			"desc": "Injects thermal virus causing area-of-effect explosions.\nVirus DoT: 55% of hit DPS for 2.4 s (L1) → 115% DPS for 4.0 s (L5). AoE splash radius: 54 (L1) → 66 → 78 → 90 → 102 px (L5), dealing 55% splash damage.\n+15% Power when Firewall Overflow is dominant path.",
		},
		{
			"path": "Middle", "name": "Data Siphon", "tiers": [1.05, 1.1, 1.15, 1.2, 1.25],
			"special": "transmute",
			"desc": "Siphons bonus credits from destroyed software entities.\nCredits per kill: +2c (L1) → +3c (L2) → +4c (L3) → +5c (L4) → +6c (L5).\nDamage multiplier: ×1.05 (L1) → ×1.25 (L5).",
		},
		{
			"path": "Bottom", "name": "Vulnerability Exploit", "tiers": [1.12, 1.18, 1.25, 1.32, 1.45],
			"special": "mana_leak",
			"desc": "Applies Vulnerability Exploit: the target receives increased damage from ALL defensive nodes.\nExtra damage taken: +6% (L1) → +12% (L2) → +18% (L3) → +24% (L4) → +30% (L5).\nDamage multiplier: ×1.12 (L1) → ×1.45 (L5).",
		},
	],
	"cannon": [
		{
			"path": "Top", "name": "Thermonuclear Splash", "tiers": [1.2, 1.25, 1.3, 1.35, 1.45],
			"special": "aoe",
			"desc": "Heavy plasma shells explode on impact, dealing massive AoE damage.\nBlast radius: 70 (L1) → 88 → 106 → 124 → 142 px (L5). Splash deals 65% of hit damage to all enemies in radius. Triggers screen shake.\nDamage multiplier: ×1.20 (L1) → ×1.45 (L5).",
		},
		{
			"path": "Middle", "name": "Cyclic Overdrive", "tiers": [1.08, 1.1, 1.13, 1.16, 1.2],
			"special": "rapid",
			"desc": "Cyclic overclocking systems drastically increase discharge rate.\nDischarge delay reduction: −9% (L1) → −18% (L2) → −27% (L3) → −36% (L4) → −45% (L5).\nDamage multiplier: ×1.08 (L1) → ×1.20 (L5).",
		},
		{
			"path": "Bottom", "name": "Stasis Bombard", "tiers": [1.1, 1.14, 1.18, 1.22, 1.28],
			"special": "shock",
			"desc": "High-arc stasis shells stun primary target and slow down nearby entities.\nStun duration: 550 ms (L1) → 700 ms (L2) → 850 ms (L3) → 1000 ms (L4) → 1150 ms (L5). Nearby slow: 400–800 ms.\nDamage multiplier: ×1.10 (L1) → ×1.28 (L5).",
		},
	],
	"sniper": [
		{
			"path": "Top", "name": "Decompile Protocol", "tiers": [1.22, 1.28, 1.35, 1.42, 1.55],
			"special": "crit",
			"desc": "Surgical decimation of critical points triggers devastating critical hits.\nCrit chance: 16% (L1) → 20% (L2) → 24% (L3) → 28% (L4) → 32% (L5). Critical hits deal 2.5× damage.\n+20% Power when Decompile Protocol is dominant path.",
		},
		{
			"path": "Middle", "name": "Target Scanner", "tiers": [1.08, 1.12, 1.16, 1.2, 1.25],
			"special": "reveal",
			"desc": "Tactical sensor grid extends range and flairs stealth units.\nRange bonus: +4% per level (+20% at L5). L2+: hit enemies are flared — stealth revealed for 3.5 s (L2) → 4.0 s (L3) → 4.5 s (L4) → 5.0 s (L5).\nDamage multiplier: ×1.08 (L1) → ×1.25 (L5).",
		},
		{
			"path": "Bottom", "name": "Kernel Pierce", "tiers": [1.15, 1.2, 1.25, 1.3, 1.4],
			"special": "armor",
			"desc": "Calibrated kernel-piercing algorithms ignore enemy firewall protection.\nFirewall ignored: 12% (L1) → 24% (L2) → 36% (L3) → 40% (L4–L5, capped).\nDamage multiplier: ×1.15 (L1) → ×1.40 (L5).",
		},
	],
	"frost": [
		{
			"path": "Top", "name": "Cryo-Leak", "tiers": [1.1, 1.15, 1.2, 1.25, 1.35],
			"special": "fragile",
			"desc": "Cryo-leak coating makes entities Fragile: all defensive nodes deal +15% more damage to them.\nActive from L1. Extends slow: 1.0 s (L1) → 1.1 s → 1.3 s → 1.4 s → 1.5 s (L5).\nDamage multiplier: ×1.10 (L1) → ×1.35 (L5).",
		},
		{
			"path": "Middle", "name": "Kernel Freeze", "tiers": [1.1, 1.15, 1.2, 1.25, 1.35],
			"special": "shatter",
			"desc": "Freezes entities solid. L2+: targets are frozen for 0.53 s (L2) → 0.62 s (L3) → 0.71 s (L4) → 0.80 s (L5). Frozen targets take 2× damage from Physical & Earth (Shatter).\nDamage multiplier: ×1.10 (L1) → ×1.35 (L5).",
		},
		{
			"path": "Bottom", "name": "Grid Recall", "tiers": [1.15, 1.2, 1.25, 1.32, 1.45],
			"special": "rewind",
			"desc": "Quantum stasis fields recall enemy data-packets backward along the path.\nRecall chance: 9% (L1) → 13% (L2) → 17% (L3) → 21% (L4) → 25% (L5), sending target 18% back. L2+: every hit also guarantees a 35% (L2) → 40% (L3) → 45% (L4) → 50% (L5) path rewind.\nDamage multiplier: ×1.15 (L1) → ×1.45 (L5).",
		},
	],
	"lightning": [
		{
			"path": "Top", "name": "Static Charge", "tiers": [1.1, 1.15, 1.2, 1.25, 1.35],
			"special": "voltage",
			"desc": "Static charge builds up on sustained discharge against the same entity.\n+5% damage for each consecutive discharge on the same target (unlimited stacking). Range bonus: +2% per level (+10% at L5).\nDamage multiplier: ×1.10 (L1) → ×1.35 (L5).",
		},
		{
			"path": "Middle", "name": "Coil Supercharge", "tiers": [1.18, 1.24, 1.3, 1.38, 1.5],
			"special": "flare",
			"desc": "Overclocks server coils for burst discharge and stealth-revealing scans.\nScans reveal stealth for 2.8 s (L1) → 3.4 s (L2) → 4.0 s (L3) → 4.6 s (L4) → 5.2 s (L5). Cooldown reduction: −7% per level (max −42% at L5).\nDamage multiplier: ×1.18 (L1) → ×1.50 (L5).",
		},
		{
			"path": "Bottom", "name": "EMP Surge", "tiers": [1.1, 1.15, 1.2, 1.25, 1.35],
			"special": "disrupt",
			"desc": "EMP surge disrupts enemy abilities and strips shield matrices.\nDisrupt duration: 1.2 s (L1) → 1.6 s (L2) → 2.0 s (L3) → 2.4 s (L4) → 2.8 s (L5). Shield damage: 10 pts per level per hit (L1: 10 → L5: 50).\nDamage multiplier: ×1.10 (L1) → ×1.35 (L5).",
		},
	],
}

static func get_path_data(ttype: String, path: String) -> Dictionary:
	if not UPGRADE_PATHS.has(ttype): return {}
	for item in UPGRADE_PATHS[ttype]:
		if item["path"] == path:
			return item
	return {}
