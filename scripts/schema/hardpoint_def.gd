class_name HardpointDef
extends Resource
## One socket on a hull. Slot type constrains what fits; mark is the maximum
## component size (downfitting smaller components is always allowed).

## NEW TYPES GO ON THE END, ALWAYS. These values are serialized as integers in
## hull .tres files, so inserting anywhere else silently re-types every existing
## hardpoint on disk — a Reactor Cradle quietly becomes a Defense Bay.
##
## SENSOR is its own slot (2026-07-25, user) rather than another SYSTEM: without
## sensors a ship is blind, so a sensor must never have to win a fight against
## cargo for a socket. The Dray's only system slots were its two Cargo Bays —
## fitting eyes cost it a hold, which is not a decision anyone should be asked to
## make.
enum SlotType { WEAPON, ENGINE, REACTOR, DEFENSE, SYSTEM, COUPLING, SENSOR }

@export var display_name := ""
@export var offset := Vector2.ZERO       # position relative to hull center
@export var facing_deg := 0.0            # arc center, degrees; 0 = ship's nose
@export var slot_type := SlotType.WEAPON
@export_range(1, 5) var mark := 1        # Mark I-V, max component size
## Firing arc in degrees, WEAPON slots only. 30 = fixed, 360 = full turret.
## In Connected flight the player aims wide-arc mounts; in Disconnected
## flight they are AI-run.
@export var arc_deg := 30.0
