class_name EngineDef
extends ComponentDef

@export var thrust := 500.0
## Trail SHAPE belongs to the thruster (the reactor supplies the COLOR).
@export var trail_scale := 1.0
@export var trail_spread_deg := 11.0
## The exhaust PARTICLE SPRITE — pixel art, ATTACHED TO THE THRUSTER so an exotic /
## alien drive ships its own plume look with no engine changes. Null = the default
## procedural diamond spark. Rendered nearest (blocky) and tinted per-particle by
## the reactor's trail_color + lifetime ramp, same as the default.
@export var trail_texture: Texture2D


func stat_summary() -> String:
	return "+%.0f thrust (speed and acceleration)" % thrust


func slot_type() -> HardpointDef.SlotType:
	return HardpointDef.SlotType.ENGINE
