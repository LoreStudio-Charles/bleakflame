class_name EngineDef
extends ComponentDef

@export var thrust := 500.0
## Trail SHAPE belongs to the thruster (the reactor supplies the COLOR).
@export var trail_scale := 1.0
@export var trail_spread_deg := 11.0
## The exhaust PARTICLE SPRITE — pixel art, ATTACHED TO THE THRUSTER so an exotic /
## alien drive ships its own plume look with no engine changes. Null = the default
## procedural diamond spark. Rendered nearest (blocky) and tinted per-particle by
## the reactor's trail_color + lifetime ramp, same as the default. Ignored when
## `trail_scene` is set (that owns the whole look).
@export var trail_texture: Texture2D
## FULLY AUTHORED exhaust — a .tscn built in the Godot particle editor (root a
## GPU/CPUParticles2D). When set, the ship instantiates IT at the thruster instead
## of the code-built plume: the code only toggles emitting + faces it on thrust, the
## entire LOOK is yours (no code tuning). This is how you author unique / alien
## drives visually. Null = the code-built default (tuned in build_ship).
@export var trail_scene: PackedScene


func stat_summary() -> String:
	return "+%.0f thrust (speed and acceleration)" % thrust


func slot_type() -> HardpointDef.SlotType:
	return HardpointDef.SlotType.ENGINE
