class_name HullDef
extends Resource
## A hull is a distinct slot set plus an identity — never a dead slot-rack.
## Category (scout, fighter, freighter...) is a role guide, not a hard limit.

enum SizeBand { LIGHT, MEDIUM, HEAVY, SUPER_HEAVY, SUPER_HEAVY_PLUS }

## Pixel-art canvas budget per size band (sprite's max extent on either axis,
## in art pixels). SUPER_HEAVY_PLUS is a ceiling ("up to"), not a target.
const ART_PX := {
	SizeBand.LIGHT: 16,
	SizeBand.MEDIUM: 32,
	SizeBand.HEAVY: 64,
	SizeBand.SUPER_HEAVY: 128,
	SizeBand.SUPER_HEAVY_PLUS: 512,
}

## World units per art pixel. Sprites render at this integer scale so pixel
## art stays crisp; silhouettes and hardpoint offsets are authored in world
## units and must fit ART_PX * ART_SCALE.
const ART_SCALE := 2


static func world_budget(band: SizeBand) -> float:
	return ART_PX[band] * ART_SCALE

@export var display_name := ""
@export var category := ""
## Explicit hull sprite path — overrides the assets/ships/<snake_name>.png default.
## This is the FACTION/COMPANY art convention: ships are organized by their maker as
## assets/ships/<faction>/<class>-<n>.png (galean-navy/cruiser-1, and later
## guardian/…, pirate/…, unaligned/…). Empty = fall back to the display-name file.
@export var art_path := ""
@export var size_band := SizeBand.LIGHT
@export var mass := 40.0                 # dry mass; components add to it
@export var hull_hp := 100.0
## QUALITY AND LEVEL, the same two axes as components — a hull is gear too.
## A high-grade or high-LEVEL hull can carry better slots and more hit points
## than a physically larger one, so size stops being the only ladder and a
## beloved small ship stays viable deep into a run.
##
## SEAM ONLY for now: these are DISPLAYED (shipyard, board strip, paperdoll
## header) and persisted, but nothing scales off them yet — the curve is a
## balance decision, not something to guess at. Give them meaning by feeding
## `level`/`grade` into hull_hp and hardpoint marks when that curve is decided.
@export var grade := Grades.Grade.STANDARD
@export var level := 1
@export var cargo_base := 0.0
## Shipyard price, flight-ready with standard loadout. 0 = not for sale.
@export var price := 0
## Every hull gets one intrinsic trait so hull choice is never a spreadsheet.
## Mechanical hookup comes later; the id is stable, the description is UI.
@export var trait_id := ""
@export_multiline var trait_description := ""
@export var hardpoints: Array[HardpointDef] = []
## Placeholder silhouette (points, ship-local, nose = +X) until real sprites.
@export var silhouette: PackedVector2Array = []


## True if the silhouette and every hardpoint fit the band's art canvas.
func fits_art_budget() -> bool:
	var budget := world_budget(size_band)
	var all_points := PackedVector2Array(silhouette)
	for hp in hardpoints:
		all_points.append(hp.offset)
	if all_points.is_empty():
		return true
	var lo := all_points[0]
	var hi := all_points[0]
	for p in all_points:
		lo = lo.min(p)
		hi = hi.max(p)
	return (hi.x - lo.x) <= budget and (hi.y - lo.y) <= budget
