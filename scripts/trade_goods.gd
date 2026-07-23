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
}

## What each venue SELLS to the player and BUYS from the player (per unit).
## Each market makes one thing cheap (its own product) and RESELLS the
## other's at an import PREMIUM — so you can buy anything anywhere if you
## really want to, you just pay through the nose for what isn't local. The
## premium is always ABOVE that market's own buy-back price, so there's no
## same-dock arbitrage; the profitable route is still buy-where-made,
## sell-where-wanted.
const STATION_MARKET := {
	"name": "Station",
	"sells": {"circuits": 22, "food": 24, "water": 16},   # food/water imported, premium
	"buys": {"food": 18, "water": 12, "ferrite_ore": 8, "cobalt_ore": 22,
		"aurite_ore": 60},
}
const PLANET_MARKET := {
	"name": "Planet Colony",
	"sells": {"food": 10, "water": 6, "circuits": 40},    # circuits imported, premium
	"buys": {"circuits": 34},
}


static func display_name(key: String) -> String:
	return GOODS[key]["name"]


static func unit_mass(key: String) -> float:
	return GOODS[key]["mass"]
