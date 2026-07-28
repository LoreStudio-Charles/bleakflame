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


## CAN THIS CHIP GO IN THE COUPLING — "" if yes, else the reason, in the words the
## player should read. THE ONE COPY OF THE RULE, and it lives here because the chips do.
##
## It used to live on DockScreen as `_chip_error`, which meant the Engineering bay
## enforced capacity, the commission lock, duplicates and level, and every OTHER counter
## enforced whatever it happened to re-derive. Vyper's counter re-derived it against
## HARDPOINTS — she sells nothing but chips, and a chip's slot_type() answers SYSTEM, so
## buying a cloak from her bolted it into a System hardpoint (eating a cargo pod or a
## sensor mount) instead of loading it into the Coupling where the ability is read from.
## A rule with two spellings is a rule with one bug in it.
func chip_error(chip: AbilityChipDef, profession: String, pilot_level: int) -> String:
	var cap := chip_capacity()
	if cap <= 0:
		return "No Universal Coupling fitted — nothing to load chips into."
	if chips.size() >= cap:
		return "Coupling is full (%d/%d). Pull a chip out first." % [chips.size(), cap]
	if chip.profession_lock != "" and chip.profession_lock != profession:
		return "%s needs the %s commission." % [chip.display_name,
			Professions.display_name(chip.profession_lock)]
	for c in chips:
		if c != null and c.tags == chip.tags:
			return "That ability is already loaded."
	# LEVEL GATES CHIPS TOO (2026-07-27). _fit_error has carried this since the level
	# requirement shipped, but the Coupling had its own error path and never got it --
	# so every chip (all 14 are level 5) loaded for any pilot, while a level-5 GUN on
	# the same shelf was refused with a visible reason. The tile had already dimmed
	# itself and painted a red L5 badge, and the tooltip already read "Requires level
	# 5 — you are 2"; only the code disagreed.
	var need := int(chip.level)
	if need > pilot_level:
		return "%s needs pilot level %d — you are level %d." % [
			chip.display_name, need, pilot_level]
	return ""


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
