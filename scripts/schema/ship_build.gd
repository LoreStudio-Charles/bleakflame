class_name ShipBuild
extends Resource
## A hull plus what's fitted where. This is the save format, the loot-refit
## unit, and the enemy-variant generator input, all in one small resource.

@export var hull: HullDef
## hardpoint index -> fitted component. Missing key = empty slot.
@export var slots: Dictionary[int, ComponentDef] = {}
## ABILITY CHIPS loaded into the Universal Coupling (docs/ability_coupling.md).
##
## Stored HERE, on the build, and never on the Coupling component itself:
## `load()` returns the SAME Resource instance for a given .tres, so chips kept
## on the component would be shared by every ship fitting that Coupling — one
## pilot's loadout silently appearing on another's hull.
##
## A flat list is enough because a hull has exactly one Coupling.
@export var chips: Array[AbilityChipDef] = []


func component_at(index: int) -> ComponentDef:
	return slots.get(index)


## The fitted Coupling, or null if the slot is empty.
func coupling() -> CouplingDef:
	for comp in slots.values():
		if comp is CouplingDef:
			return comp
	return null


## How many chips this ship can hold right now. No Coupling = no book.
func chip_capacity() -> int:
	var c := coupling()
	return c.capacity() if c != null else 0


## Is a chip carrying this ability tag loaded in the Coupling?
func has_chip_tag(tag: String) -> bool:
	for chip in chips:
		if chip != null and chip.has_tag(tag):
			return true
	return false


## Every chip's tuning dict, for ship.gd to read ability parameters out of —
## the same `extra` keys the old SystemDef modules carried.
func chip_extras() -> Array:
	var out := []
	for chip in chips:
		if chip != null:
			out.append(chip)
	return out


func has_system_tag(tag: String) -> bool:
	for comp in slots.values():
		if comp is SystemDef and comp.has_tag(tag):
			return true
	return false
