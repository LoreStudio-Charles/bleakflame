class_name GroundDeath
## THE ONE PLACE ground-death consequences live (docs/ground_combat.md — the user's
## explicit rule: the final penalty is OPEN, likely EverQuest-light, so nothing else may
## hardcode what dying costs. Change the policy HERE, once).
##
## v1 policy (buildable now): the fallen keep their EQUIPMENT; their held BAG inventory
## drops in a recoverable satchel where they fell; the player wakes at the Starport.
## OPEN seams, deliberately unimplemented: XP loss / de-level, a recoverable corpse.

## What a death costs, applied to the PLAYER. Returns what happened so the host (the
## town) can present it — this module decides consequences, never UI.
##   {"dropped": Array of {key, qty}, "wake": "starport"}
static func apply(ship_or_hold) -> Dictionary:
	var dropped: Array = []
	# v1: held commodities drop (the "bag"); fitted equipment stays. When the pilot's
	# personal BAGS [B] exist as their own store, this switches to that container.
	if ship_or_hold != null and ship_or_hold.get("commodities") != null:
		for key in ship_or_hold.commodities.keys():
			var qty := int(ship_or_hold.commodities[key])
			if qty > 0:
				dropped.append({"key": key, "qty": qty})
				ship_or_hold.remove_commodity(key, qty)
	# TODO(OPEN, user decides): XP loss (possibly de-level) — would live here, via a
	# single Wallet.xp mutation, nowhere else.
	# TODO(OPEN): register a corpse/satchel entity for recovery runs.
	return {"dropped": dropped, "wake": "starport"}
