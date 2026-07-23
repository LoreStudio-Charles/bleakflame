class_name CouplingDef
extends ComponentDef
## THE UNIVERSAL COUPLING — the rack that holds ability CHIPS (docs/
## ability_coupling.md). Every hull has exactly one Coupling hardpoint, so this
## never competes with cargo or sensors for space; that competition is precisely
## what kept the profession layer off most ships.
##
## Capacity is GRADE and nothing else, doubling per tier, so each upgrade is a
## felt jump instead of an increment. Deliberately generous: the book was never
## meant to be the constraint — the five gem slots are, and Going Dark is the
## only way to re-flash them away from a dock.
##
## Draws NO power itself (user): charging for the shelf would tax simply having
## a book. A CHIP may declare its own `power_draw` if its capability warrants.
##
## Higher grades are intended to double as STAT STICKS later (user) — hence the
## bonus fields below, which aggregate like any other component.

const CAPACITY := {
	Grades.Grade.FLOTSAM: 1,
	Grades.Grade.SALVAGE: 2,
	Grades.Grade.STANDARD: 4,
	Grades.Grade.ADVANCED: 8,
	Grades.Grade.EXPERIMENTAL: 16,
	Grades.Grade.BESPOKE: 64,
	Grades.Grade.EXOTIC: 64,
}

## Stat-stick seam: a fine Coupling should be worth fitting for more than room.
## Zero on everything shipped today; aggregated by ShipStats when set.
@export var bonus_shield_hp := 0.0
@export var bonus_armor_hp := 0.0
@export var bonus_cargo := 0.0


func capacity() -> int:
	return int(CAPACITY.get(grade, 1))


func stat_summary() -> String:
	var parts: Array[String] = ["holds %d ability chips" % capacity()]
	if bonus_shield_hp > 0.0:
		parts.append("+%.0f shield" % bonus_shield_hp)
	if bonus_armor_hp > 0.0:
		parts.append("+%.0f armor" % bonus_armor_hp)
	if bonus_cargo > 0.0:
		parts.append("+%.0f cargo hold" % bonus_cargo)
	return "   ".join(parts)


func slot_type() -> HardpointDef.SlotType:
	return HardpointDef.SlotType.COUPLING
