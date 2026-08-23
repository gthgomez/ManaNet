class_name BrandCopy
extends RefCounted

## Player-facing copy for ManaNet identity (network defense / patches).
## Code may keep gold/lives/rp; UI must use these helpers.

const FANTASY_SUBTITLE := "Hold the grid for 15 waves. Patch smart. Deploy wisely."

const CURRENCY_RUN := "Credits"
const CURRENCY_META := "Shards"
const CORE_RESOURCE := "Integrity"
const CORE_SHORT := "INT"
const META_SCREEN := "Cyber-Deck"
const WAVE_SHOP_TITLE := "CHOOSE A PATCH"
const WAVE_SHOP_TITLE_BOSS := "BOSS CLEARED — CHOOSE A PATCH"
const WAVE_SHOP_HELP := "Pick one network bonus, or skip to continue."
const START_WAVE := "Start Wave"
const INSTRUCTION_PICK_TOWER := "Pick a defender to secure the grid"
const INSTRUCTION_CHOOSE_TOWER := "CHOOSE A DEFENDER TO BEGIN"
const INSTRUCTION_START_WAVE := "START WAVE WHEN READY"

static func credits(amount: int) -> String:
	return "%s: %d" % [CURRENCY_RUN, amount]

static func integrity(amount: int) -> String:
	return "%s: %d" % [CORE_RESOURCE, amount]

static func integrity_short(amount: int) -> String:
	return "%s %d" % [CORE_SHORT, amount]

static func shards(amount: int) -> String:
	return "%s: %d" % [CURRENCY_META, amount]

static func shards_cost(cost: int) -> String:
	return "%d %s" % [cost, CURRENCY_META]

static func credits_amount_suffix(amount: int) -> String:
	## Compact shop costs: "45c" reads as credits, not gold.
	return "%dc" % amount

static func skip_bonus_start_wave(wave: int) -> String:
	return "Skip Patch — %s %d" % [START_WAVE, wave]

static func wave_shop_header(wave: int, is_milestone: bool) -> String:
	if is_milestone:
		return WAVE_SHOP_TITLE_BOSS
	return "%s BEFORE WAVE %d" % [WAVE_SHOP_TITLE, wave]

static func pause_status(wave: int, lives: int, gold: int) -> String:
	return "Paused  |  Wave %d  %s %d  %s %d" % [
		wave, CORE_RESOURCE, lives, CURRENCY_RUN, gold
	]

static func life_lost_toast(lost: int) -> String:
	if lost == 1:
		return "Integrity -1"
	return "Integrity -%d" % lost

static func shards_mult(mult: float, stacked: bool = false) -> String:
	if stacked:
		return "  %s ×%.1f  (stacked)" % [CURRENCY_META, mult]
	return "  %s ×%.1f" % [CURRENCY_META, mult]

static func end_stat_shards(earned: int, total: int) -> String:
	return "+%d  (total: %d)" % [earned, total]
