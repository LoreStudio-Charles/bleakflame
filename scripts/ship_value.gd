class_name ShipValue
## WHAT A SHIP IS WORTH — hull AND everything bolted to it, from ONE place.
##
## Written before the Shipyard grew a sell verb, because the user named the two ways it
## goes wrong and both are the same missing rule (2026-07-28):
##
##   1. "buy a hull, strip it, and sell it for a profit"
##   2. "buy a hull, fill it out with sweet loot, sell it for the base hull price, and
##      feel cheated"
##
## One is an exploit and one is a robbery, and a single number prevents both: a ship's
## price is its ASSEMBLY, never its hull.
##
## THE UNITS ARE THE TRAP, and it is why this is a function rather than a habit.
## `HullDef.price` is already a BUY-SIDE number — DockScreen charges it directly, with no
## markup — while `ComponentDef.value()` is INTRINSIC, doubled by ItemVisuals.BUY_MULT on
## the way to a shelf. Add them naively and the hull is priced at half its own worth
## relative to its parts. Anyone can write that bug; nobody can write it twice if there
## is only one place to write it.
##
## THE STANDARD LOADOUT IS CURRENTLY FREE. A shipyard hull is sold "flight-ready with
## standard loadout" for `hull.price` alone, so the fitted parts are thrown in — deliberate
## pricing, not an oversight, and NOT changed here. It does mean the sell side must credit
## those parts at their own rate rather than assume they were paid for.

## What a sold hull recovers, before its parts. The same 2x spread every other item
## trades at (ItemVisuals.BUY_MULT), applied to the hull's own buy price so a ship is not
## quietly the one thing in the game you can round-trip at par.
const HULL_RECOVERY := 1.0 / 2.0


## WHAT A YARD WOULD PAY for this ship as it stands. Hull at the standard spread, plus
## every fitted component and chip at exactly what the Armory would give you for it
## loose — so stripping a ship before selling it is worth nothing either way, and
## selling a loaded one never silently discards the loot in it.
static func sell(build: ShipBuild) -> int:
	if build == null or build.hull == null:
		return 0
	var total := int(round(float(build.hull.price) * HULL_RECOVERY * Pilot.sell_mult()))
	for part in fitted(build):
		total += ItemVisuals.sell_price(part)
	return total


## What it would cost to put this exact ship on the pad today: the yard's price for the
## hull (loadout included, see above) plus the shelf price of anything fitted BEYOND it.
## Used to show a pilot what their ship represents, never to charge them.
static func replacement(build: ShipBuild) -> int:
	if build == null or build.hull == null:
		return 0
	var total := int(build.hull.price)
	for part in fitted(build):
		total += ItemVisuals.buy_price(part)
	return total


## Everything bolted on: hardpoints AND the coupling's chips. Chips are the half that
## gets forgotten — they are not in `slots`, they cost real money, and a valuation that
## skips them is the "sold my loot for nothing" complaint in miniature.
static func fitted(build: ShipBuild) -> Array:
	var out: Array = []
	if build == null:
		return out
	for key in build.slots:
		var comp: ComponentDef = build.slots[key]
		if comp != null:
			out.append(comp)
	for chip in build.chips:
		if chip != null:
			out.append(chip)
	return out
