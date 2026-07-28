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
## THE ASKING PRICE ALREADY CONTAINS THE LOADOUT (user, 2026-07-28):
##
##     orig_creds = hull_base + Σ(included_components)
##
## A shipyard hull is sold "flight-ready with standard loadout" for `hull.price`, and
## that price was set knowing what came bolted to it. So the hull's OWN worth is the
## asking price MINUS what the yard threw in — `hull_base()` below — and a sale credits
## the bare hull once and whatever is currently fitted once. My first version recovered
## against the whole asking price and then added the parts on top, which paid for the
## standard loadout TWICE and made stripping a ship strictly worse than selling it whole.
##
## THE INVARIANT THAT FALLS OUT is the one worth remembering, and it is what the test
## pins: selling a stock ship whole, and stripping it to sell the pieces separately, come
## to EXACTLY THE SAME NUMBER — half the asking price. Neither exploit has anywhere to
## live, and the player never has to know which order to do things in.
##
## THE UNITS ARE THE TRAP. `HullDef.price` is a BUY-SIDE number — DockScreen charges it
## directly, with no markup — while `ComponentDef.value()` is INTRINSIC, doubled by
## ItemVisuals.BUY_MULT on the way to a shelf. So `included` is summed at BUY price, to
## match the number it is being subtracted from.

## What a sold hull recovers of its own bare worth: the same 2x spread every other item
## trades at (ItemVisuals.BUY_MULT), so a ship is not quietly the one thing in the game
## you can round-trip at par.
const HULL_RECOVERY := 1.0 / 2.0

## hull resource_path -> the parts the yard includes in its asking price. Built once;
## the factory loadouts are constant.
static var _included := {}


## THE BARE HULL'S WORTH — the asking price with the standard loadout taken back out.
## Never below zero: a hull whose loadout is somehow worth more than its sticker is a
## data error, and clamping keeps it from turning into a NEGATIVE sale that pays the
## yard to take the ship.
static func hull_base(hull: HullDef) -> int:
	if hull == null:
		return 0
	var included := 0
	for part in included_parts(hull):
		included += ItemVisuals.buy_price(part)
	return maxi(0, int(hull.price) - included)


## WHAT A YARD WOULD PAY for this ship as it stands: the bare hull at the standard
## spread, plus every fitted component and chip at exactly what the Armory would give you
## for it loose — so stripping before selling is worth nothing either way, and selling a
## loaded ship never silently discards the loot in it.
static func sell(build: ShipBuild) -> int:
	if build == null or build.hull == null:
		return 0
	var total := int(round(float(hull_base(build.hull)) * HULL_RECOVERY * Pilot.sell_mult()))
	for part in fitted(build):
		total += ItemVisuals.sell_price(part)
	return total


## What it would cost to put this exact ship on the pad today. For a stock ship this is
## the asking price, by construction; for a refitted one it is the bare hull plus what is
## actually on it. Used to show a pilot what their ship represents, never to charge them.
static func replacement(build: ShipBuild) -> int:
	if build == null or build.hull == null:
		return 0
	var total := hull_base(build.hull)
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


## What the yard included in this hull's price, from the FACTORY build rather than the
## player's. A hull nobody sells (enemy-only hulls) includes nothing, so its base is its
## price — harmless, since none of them ever reaches a counter.
static func included_parts(hull: HullDef) -> Array:
	if _included.is_empty():
		for i in SampleBuilds.count():
			var stock := SampleBuilds.stock(i)
			if stock != null and stock.hull != null:
				_included[stock.hull.resource_path] = fitted(stock)
	return _included.get(hull.resource_path, [])
