class_name ComponentDef
extends Resource
## Base class for everything that fits a hardpoint. Subclasses per slot type
## carry the typed stats; this layer carries the axes shared by all loot:
## size (mark), quality (grade), and the two ship economies (mass, power).

@export var display_name := ""
@export_multiline var description := ""
@export_range(1, 5) var mark := 1
@export var grade := Grades.Grade.STANDARD
## The same second axis HullDef carries: GRADE is quality, LEVEL is tier. A
## high-level part can out-perform a physically larger one, so mark stops being
## the only ladder. Mostly a display/authoring seam (nothing scales off it yet —
## see docs/progression_table.md), but it is REAL where a capability is gated on
## it: role identification needs a sensor at ADVANCED grade and level 10+.
@export var level := 1
@export var mass := 1.0
@export var power_draw := 0.0            # reactors are the only producers
## Optional sprite drawn on the hull at the hardpoint (weapons, armor, engines).
## Components with no overlay and no effects still get UI presence — nothing
## the player fits should be imperceptible.
@export var overlay_sprite: Texture2D
## Reserved for Exotic-grade rule-breakers: the risk that comes with defying
## physics. Empty for all non-Exotic components. Not used in MVP.
@export var hazard := ""
## Affix identity (rolled at drop time by Affixes). base_path points at the
## clean factory .tres this item was forged from — saves store base + ids
## and rebuild the identical item deterministically.
@export var affix_ids: PackedStringArray = []
@export var base_path := ""


## Sell value: grade worth scaled by size, spiced by affixes (drawbacks cut).
func value() -> int:
	var v := float(Grades.INFO[grade]["value"] * mark)
	for id in affix_ids:
		v *= 0.7 if Affixes.is_drawback(id) else 1.35
	return int(round(v))


## Affix lines for detail panels; empty string for clean factory gear.
func affix_text() -> String:
	if affix_ids.is_empty():
		return ""
	var lines: Array[String] = []
	for id in affix_ids:
		lines.append(Affixes.text(id))
	return "\n".join(lines)


## One-line gameplay stats for shop/refit UI. Subclasses override.
func stat_summary() -> String:
	return ""


func slot_type() -> HardpointDef.SlotType:
	push_error("ComponentDef subclass must override slot_type()")
	return HardpointDef.SlotType.SYSTEM
