class_name DefenseDef
extends ComponentDef
## Shields and armor share the Defense slot so bubble-vs-plate is a build
## choice. COMPOSITE components provide both at a premium grade.

enum Kind { SHIELD, ARMOR, COMPOSITE }

@export var kind := Kind.ARMOR
@export var shield_hp := 0.0
@export var shield_regen := 0.0          # hp/s
@export var armor_hp := 0.0


func stat_summary() -> String:
	var parts: Array[String] = []
	if shield_hp > 0.0:
		parts.append("+%.0f shield, regenerating %.1f/s" % [shield_hp, shield_regen])
	if armor_hp > 0.0:
		parts.append("+%.0f armor" % armor_hp)
	return "   ".join(parts)


func slot_type() -> HardpointDef.SlotType:
	return HardpointDef.SlotType.DEFENSE
