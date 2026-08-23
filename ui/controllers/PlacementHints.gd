class_name PlacementHints
extends RefCounted

# Pure placement-hint text mapping extracted from GameScreen.gd.
# No state, no scene dependencies.

static func format_ui_reason(reason: String) -> String:
	var text: String = reason.strip_edges()
	if text == "":
		return "Cannot place here"
	if "_" in text:
		text = text.replace("_", " ").capitalize()
	return text

static func reason_hint(reason: String) -> String:
	var text: String = format_ui_reason(reason)
	match text:
		"Too close to the path":
			return "MOVE AWAY FROM PATH"
		"Too close to another tower":
			return "TOO CLOSE TO TOWER"
		"Cannot place on shop area":
			return "MOVE ABOVE SHOP"
		"Out of bounds":
			return "STAY INSIDE MAP"
		"Not enough gold":
			return "NOT ENOUGH CREDITS"
	return text.to_upper()
