class_name TradeGoods
## Commodity registry + market price tables. Commodities are stackable cargo
## mass, distinct from components. Markets are asymmetric on purpose: the
## station manufactures (cheap circuits, pays for organics), the planet grows
## (cheap food/water, pays for circuits) — profit flows both directions of the
## route, and pirates prey on exactly this traffic.

const GOODS := {
	"circuits": {"name": "Circuits", "mass": 2.0},
	"food": {"name": "Food", "mass": 3.0},
	"water": {"name": "Water", "mass": 4.0},
	"stolen_goods": {"name": "Stolen Goods", "mass": 2.0},  # mission turn-ins only
	# Mining yields (station industry buys ore; rarity ladder ferrite->aurite).
	"ferrite_ore": {"name": "Ferrite Ore", "mass": 2.0},
	"cobalt_ore": {"name": "Cobalt Ore", "mass": 2.0},
	"aurite_ore": {"name": "Aurite Ore", "mass": 3.0},
	# Survey scanner output. No market buyer: the Research Lab trades it in
	# for Insight (Research.SCAN_DATA_INSIGHT per unit).
	"scan_data": {"name": "Scan Data", "mass": 0.4},
	# Artifact-chain matter (Research Lab discovery chains — never market
	# goods): fragments mined out of aurite rock, and the one-off artifacts
	# themselves during the haul home. Artifacts are NEVER combat drops.
	"cinder_fragment": {"name": "Cinder Fragment", "mass": 0.5},
	"wayfinder_core": {"name": "Wayfinder Core (artifact)", "mass": 6.0},
	# CAMPAIGN EVIDENCE. Listed in no market's `sells` or `buys`, so every counter
	# answers "no buyer here" — it is a thing you CARRY, not a thing you trade, and the
	# hold is the only place it can be. That is the point: the fiction says you take it
	# to Odessa, so the player should be able to open their hold and see it sitting there.
	"ooshu_drone": {"name": "Smashed Scout Drone", "mass": 1.2},
}

## What each venue SELLS to the player and BUYS from the player (per unit).
## Each market makes one thing cheap (its own product) and RESELLS the
## other's at an import PREMIUM — so you can buy anything anywhere if you
## really want to, you just pay through the nose for what isn't local. The
## premium is always ABOVE that market's own buy-back price, so there's no
## same-dock arbitrage; the profitable route is still buy-where-made,
## sell-where-wanted.
## `local` = what this venue MAKES. It drives the deal colouring (buy a local export
## cheap = green, an import = red; the sell side inverts) and lives HERE rather than in
## a storefront, so the tabbed dock and the ground shop teach the same lesson.
## A COUNTER PAYS HALF WHAT IT CHARGES for the same good (user, 2026-07-28: "arbitrage
## traders should sell for 50% buy price, so you have to find a place that really wants
## your goods to make them profitable").
##
## THE POINT IS WHERE THE PROFIT COMES FROM. At 0.75-0.85 — what these tables used to
## carry — a venue's own spread was thin enough that a percentage bonus could reach
## across it, and profit could come from standing still. At 0.5 it cannot: the only way
## to make money is to carry goods somewhere that WANTS them, which is the trade game.
## It also means the Trader's bonus has a 2x gap to work inside, so it mitigates a real
## cost instead of threatening to invert a small one.
##
## IMPORT PRICES ROSE; BUY-BACKS DID NOT MOVE. Halving what a venue pays would have
## killed every route at once — the colony paid 34 for circuits and the station sells
## them at 22, so a buy-back of 20 turns the Reach's staple run into a loss. Doubling the
## import premium instead keeps every route's profit exactly what it was and puts the
## change where the fiction already said it was: a frontier colony pays dearly for what
## it cannot make. Asserted in test_dock_ui, so the next market authored cannot drift.
const BUYBACK := 0.5

const STATION_MARKET := {
	"name": "Station",
	"local": ["circuits"],
	"sells": {"circuits": 22, "food": 36, "water": 24},   # food/water imported, premium
	"buys": {"food": 18, "water": 12, "ferrite_ore": 8, "cobalt_ore": 22,
		"aurite_ore": 60},
}
const PLANET_MARKET := {
	"name": "Planet Colony",
	"local": ["food", "water"],
	"sells": {"food": 10, "water": 6, "circuits": 68},    # circuits imported, premium
	"buys": {"circuits": 34},
}


static func display_name(key: String) -> String:
	return GOODS[key]["name"]


static func unit_mass(key: String) -> float:
	return GOODS[key]["mass"]


## ---- TRANSACTIONS ----
##
## THE ONE implementation of buying and selling, so every storefront is a SKIN over
## the same rules. It used to live inside DockScreen, which meant the walkable town
## could only reach it by opening the station's tabbed dock panel — the shoehorn that
## made planetside guidance point at tabs that weren't on screen. Now the tabbed dock
## and the ground shop both call these.
##
## UI-FREE ON PURPOSE (like the rest of this file): no Control, no flash, no refresh —
## each returns {"ok": bool, "msg": String} and the caller decides how to show it. That
## keeps the rules testable under `--script` (no autoloads) and stops the two
## storefronts from drifting apart. `ship` is duck-typed (commodities /
## can_carry_mass / add_commodity / remove_commodity).

## THE TRADE PERK NARROWS A LOCAL SPREAD; IT MAY NEVER CROSS ONE (user, 2026-07-28: the
## trade skill should "chip away at the diff from buy and sell without ever making it
## profitable to buy and sell").
##
## THIS FILE ALREADY CLAIMED THAT — "the premium is always ABOVE that market's own
## buy-back price, so there's no same-dock arbitrage" — and it was true of the LISTED
## numbers and false the moment a commission moved both ends. A level-60 Trader bought
## food at the station for 17c and sold it back at the same counter for 23c: +6c a unit,
## no travel, no risk, repeatable forever. Circuits at the colony paid +16c.
## (tools/audit_arbitrage.gd prints it.)
##
## WHERE A VENUE TRADES A GOOD BOTH WAYS, the perk now moves each price toward the
## MIDPOINT of that venue's own spread instead of pushing the two ends past each other.
## The gap closes; it cannot invert. `edge` is a fraction strictly under 1.0, so the two
## prices approach and never meet.
##
## CROSS-REGION TRADE IS UNTOUCHED — deliberately (user: "it's okay to cross on market
## items from one region to another, that's the trader gameplay"). A venue that only
## SELLS a good, or only BUYS it, has no local spread to protect, so the perk applies in
## full there. Buying circuits at the station (sell-only, 22 -> 15) and selling them at
## the colony still pays a maxed Trader 20c a unit against a fresh pilot's 12.

## The most of a local spread a perk may ever close. Under 1.0 by definition: at 1.0 the
## two prices meet, and a round trip becomes free rather than merely unprofitable.
const MAX_EDGE := 0.9


## Unit price the player PAYS here (their trade background/skill discounts it).
static func buy_price(market: Dictionary, key: String) -> int:
	var listed := float(market["sells"][key])
	if not market["buys"].has(key):
		return int(round(listed * Pilot.trade_buy_mult()))
	return int(round(_toward_mid(listed, float(market["buys"][key]),
		1.0 - Pilot.trade_buy_mult())))


## Unit price the player RECEIVES here.
static func sell_price(market: Dictionary, key: String) -> int:
	var listed := float(market["buys"][key])
	if not market["sells"].has(key):
		return int(round(listed * Pilot.trade_sell_mult()))
	return int(round(_toward_mid(listed, float(market["sells"][key]),
		Pilot.trade_sell_mult() - 1.0)))


## Move `price` a fraction of the way toward the midpoint between it and `other`. Pure and
## static so the boundary is assertable without a market, a pilot or a screen.
static func _toward_mid(price: float, other: float, edge: float) -> float:
	var mid := (price + other) * 0.5
	return price - (price - mid) * clampf(edge, 0.0, MAX_EDGE)


static func buy(ship, market: Dictionary, key: String) -> Dictionary:
	if not market["sells"].has(key):
		return {"ok": false, "msg": "%s isn't sold here." % display_name(key)}
	var price := buy_price(market, key)
	if Wallet.credits < price:
		return {"ok": false, "msg": "Not enough credits (%dc)." % price}
	if not ship.can_carry_mass(unit_mass(key)):
		return {"ok": false, "msg": "Hold full."}
	Wallet.credits -= price
	ship.add_commodity(key, 1)
	return {"ok": true, "msg": "Bought %s for %dc." % [display_name(key), price]}


static func sell(ship, market: Dictionary, key: String) -> Dictionary:
	if int(ship.commodities.get(key, 0)) <= 0:
		return {"ok": false, "msg": "No %s in hold." % display_name(key)}
	if not market["buys"].has(key):
		return {"ok": false, "msg": "No buyer for %s here." % display_name(key)}
	var price := sell_price(market, key)
	ship.remove_commodity(key, 1)
	Wallet.credits += price
	if key.ends_with("_ore"):
		Standing.add("miner", 1)   # ore off your hold = Doug's kind of work
	return {"ok": true, "msg": "Sold %s for %dc." % [display_name(key), price]}
