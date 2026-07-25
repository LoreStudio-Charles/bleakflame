extends Node2D
## A minimal stand-in for the player ship's CARGO HOLD, for tests that need something in
## the "player_ship" group without standing up a whole BuildShip (which pulls in a build,
## physics, and a save). Duck-types exactly the surface the trade rules touch.

class Stats:
	var cargo := 100.0

var commodities := {}
var cargo: Array = []      # carried COMPONENTS (the real ship has this too)
var stats := Stats.new()


func cargo_used() -> float:
	var used := 0.0
	for k in commodities:
		used += commodities[k] * TradeGoods.unit_mass(k)
	return used


func can_carry_mass(mass: float) -> bool:
	return cargo_used() + mass <= stats.cargo


func add_commodity(key: String, qty: int) -> void:
	commodities[key] = int(commodities.get(key, 0)) + qty


func remove_commodity(key: String, qty: int) -> void:
	commodities[key] = int(commodities.get(key, 0)) - qty
