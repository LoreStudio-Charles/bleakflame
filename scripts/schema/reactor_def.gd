class_name ReactorDef
extends ComponentDef

## THE THREE HARD STATS (2026-07-22, user). A reactor now publishes its energy
## behaviour DIRECTLY instead of the game deriving it from leftover LOAD:
##   power_output   — LOAD: the fit budget modules draw against (unchanged).
##   energy_capacity — CAPACITY: the size of the energy pool.
##   energy_recharge — RECHARGE: energy per second, flat.
## Regen used to fall out of unused LOAD (a lean fit recharged fast, a full one
## crawled). Realistic, but it meant every fitting choice silently moved regen
## and made the pool impossible to tune — so it is gone. These are knobs we set,
## not emergent side effects. (Zero on an OLD reactor falls back to the legacy
## formula in build_ship, so pre-change saves still load.)
@export var power_output := 50.0
@export var energy_capacity := 0.0
@export var energy_recharge := 0.0
## Reactors color every vapor trail on the ship — grade made visible.
@export var trail_color := Color(0.55, 0.75, 1.0)


func stat_summary() -> String:
	return "+%.0f Load · %.0f Capacity · %.1f/s Recharge" % [
		power_output, energy_capacity, energy_recharge]


func slot_type() -> HardpointDef.SlotType:
	return HardpointDef.SlotType.REACTOR
