class_name EngineDef
extends ComponentDef

@export var thrust := 500.0
## Trail SHAPE belongs to the thruster (the reactor supplies the COLOR).
@export var trail_scale := 1.0
@export var trail_spread_deg := 11.0


func stat_summary() -> String:
	return "+%.0f thrust (speed and acceleration)" % thrust


func slot_type() -> HardpointDef.SlotType:
	return HardpointDef.SlotType.ENGINE
