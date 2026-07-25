class_name WeaponAnchors
## WHERE A WEAPON SITS on a walking character — per (direction, frame): hand position,
## weapon rotation, and whether it draws behind the body.
##
## HAND-AUTHORED IN THE EDITOR (user, 2026-07-25: "if I can edit those per frame and
## ensure each character gets it set correctly we can make it work"). The data lives in
## a SCENE at `scenes/ground/anchors/<CharacterFolder>/<Group>.tscn` — generate the
## starter with tools/make_anchor_scenes.gd, then open it in Godot: each animation frame
## is laid out as a locked reference sprite with two Marker2D children,
##   `one` — the ONE-HAND grip (drag it onto the palm; ROTATE the gizmo = weapon angle)
##   `two` — the TWO-HAND carry anchor (same controls)
## Marker meta `behind` (bool, in the Inspector) = draw the weapon behind the body.
## Per-character on purpose: the goblin's chibi arms are nowhere near the mannequin's.
##
## The code table below is only the SEED + fallback (estimated off PilotM's cuffs, the
## PoC values) — an authored scene always wins. Missing scene + missing direction =
## the fallback, scaled by canvas size, so an unauthored character still carries.

const DIRS := ["south", "east", "north", "west"]

## Fallback tables, authored against the 68px mannequin canvas (the PoC).
## {pos, rot (degrees), behind} — west entries are authored, not auto-mirrored, because
## our west sheets are real generated art, not flips.
const FALLBACK_ONE := {
	"south": [[26, 42, 90, false], [27, 41, 90, false], [26, 40, 90, false], [27, 41, 90, false]],
	"east":  [[37, 42, 0, false], [40, 41, 0, false], [37, 40, 0, false], [42, 41, 0, false]],
	"north": [[42, 42, -90, true], [41, 41, -90, true], [42, 40, -90, true], [41, 41, -90, true]],
	"west":  [[31, 42, 0, false], [28, 41, 0, false], [31, 40, 0, false], [26, 41, 0, false]],
}
const FALLBACK_TWO := {
	"south": [[34, 41, 0, false], [34, 40, 0, false], [34, 39, 0, false], [34, 40, 0, false]],
	"east":  [[40, 41, 0, false], [40, 40, 0, false], [40, 41, 0, false], [40, 40, 0, false]],
	"north": [[34, 33, -45, true], [34, 32, -45, true], [34, 33, -45, true], [34, 32, -45, true]],
	"west":  [[28, 41, 0, false], [28, 40, 0, false], [28, 41, 0, false], [28, 40, 0, false]],
}

const SCENE_PATH := "res://scenes/ground/anchors/%s/%s.tscn"

static var _cache := {}


## The full anchor set for a character's animation group:
##   {dir: [{one: {pos, rot, behind}, two: {...}} x frames]}
## `char_folder` = the assets/characters folder name ("PilotM", "DustGoblin"...).
static func load_set(char_folder: String, group: String, canvas := 68) -> Dictionary:
	var key := "%s/%s" % [char_folder, group]
	if _cache.has(key):
		return _cache[key]
	var out := _fallback_set(canvas)
	var path := SCENE_PATH % [char_folder, group]
	if ResourceLoader.exists(path):
		var packed: PackedScene = load(path)
		var root := packed.instantiate()
		for dir_node in root.get_children():
			var d := str(dir_node.name)
			if not DIRS.has(d):
				continue
			var frames: Array = []
			for frame_node in dir_node.get_children():
				if frame_node is not Sprite2D:
					continue
				var entry := {}
				for m in frame_node.get_children():
					if m is Marker2D and str(m.name) in ["one", "two"]:
						entry[str(m.name)] = {
							"pos": (m as Marker2D).position,
							"rot": (m as Marker2D).rotation,
							"behind": bool(m.get_meta("behind", false)),
						}
				frames.append(entry)
			if not frames.is_empty():
				out[d] = frames
		root.queue_free()
	_cache[key] = out
	return out


## The code fallback, scaled from the 68px mannequin canvas to this character's.
static func _fallback_set(canvas: int) -> Dictionary:
	var s := float(canvas) / 68.0
	var out := {}
	for d in DIRS:
		var frames: Array = []
		for i in 4:
			frames.append({
				"one": _entry(FALLBACK_ONE[d][i], s),
				"two": _entry(FALLBACK_TWO[d][i], s),
			})
		out[d] = frames
	return out


static func _entry(row: Array, s: float) -> Dictionary:
	return {"pos": Vector2(row[0] * s, row[1] * s),
		"rot": deg_to_rad(float(row[2])), "behind": bool(row[3])}


## Tests / regeneration hook.
static func clear_cache() -> void:
	_cache.clear()
