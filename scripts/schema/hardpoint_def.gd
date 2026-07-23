class_name HardpointDef
extends Resource
## One socket on a hull. Slot type constrains what fits; mark is the maximum
## component size (downfitting smaller components is always allowed).

## COUPLING is appended LAST on purpose: these values are serialized in hull
## .tres files, so inserting anywhere else would silently re-type every existing
## hardpoint on disk.
enum SlotType { WEAPON, ENGINE, REACTOR, DEFENSE, SYSTEM, COUPLING }

@export var display_name := ""
@export var offset := Vector2.ZERO       # position relative to hull center
@export var facing_deg := 0.0            # arc center, degrees; 0 = ship's nose
@export var slot_type := SlotType.WEAPON
@export_range(1, 5) var mark := 1        # Mark I-V, max component size
## Firing arc in degrees, WEAPON slots only. 30 = fixed, 360 = full turret.
## In Connected flight the player aims wide-arc mounts; in Disconnected
## flight they are AI-run.
@export var arc_deg := 30.0
