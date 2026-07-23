class_name AbilityChipDef
extends ComponentDef
## An ABILITY CHIP — the thing that actually grants an ability now. Chips live
## INSIDE the Universal Coupling (docs/ability_coupling.md), not in a hardpoint,
## so an ability never costs you a cargo pod or a sensor suite again.
##
## `tags` works exactly as it did on the old SystemDef modules: the tag names
## the ability (Abilities.LIST matches on it), and `extra` carries that
## ability's tuning. The migration was therefore a change of container, not of
## machinery — every `_engage_*` in ship.gd reads the same `extra` keys.
##
## A chip is an ordinary component otherwise: bought from a quartermaster,
## carried in the hold, stashed, sold. Mass is near zero — these are cards.

@export var tags: PackedStringArray = []
## Locks the chip to a commission, same rule as the modules it replaced: you
## cannot slot Bulwark without the Guardian's blessing.
@export var profession_lock := ""
## Ability tuning, read by ship.gd (cooldowns, damage, radii, energy cost).
@export var extra := {}
## A chip MAY carry hardware stats — the Killshot coilgun ships its own optics,
## because targeting reach is max(600, sensor_range) and its 700 minimum range
## would otherwise be unusable. Aggregated by ShipStats like any component.
@export var sensor_range := 0.0


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func stat_summary() -> String:
	var parts: Array[String] = []
	for t in tags:
		for a in Abilities.LIST:
			if a.get("tag", "") == t:
				parts.append("grants %s" % a.name)
				break
	if profession_lock != "":
		parts.append("[%s only]" % profession_lock.capitalize())
	return "   ".join(parts)


## Chips are not hardpoint gear. They report SYSTEM so any legacy path that asks
## still gets a sane answer, but the fit rules route them to the Coupling.
func slot_type() -> HardpointDef.SlotType:
	return HardpointDef.SlotType.SYSTEM
