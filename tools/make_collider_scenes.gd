extends SceneTree
## AUTHORING TOOL — make hand-editable collider scenes for the ground props/buildings.
##
## WHY (user, 2026-07-25): prop colliders are measured from the art at runtime, which is a
## good default but can't be nudged. This writes one small scene per art key containing
##   · the ART itself, as a reference Sprite2D you can see, and
##   · a CollisionPolygon2D seeded with the auto-measured footprint
## so you can open it in Godot, grab the polygon tool, and drag the points until the solid
## matches the rock exactly. The town loads the polygon if the scene exists and falls back
## to the automatic rectangle if it doesn't — so generating a scene is opt-in per prop and
## deleting one restores the default.
##
##   <godot> --headless --path . --script res://tools/make_collider_scenes.gd
##   then open scenes/ground/colliders/<key>.tscn and drag the points.
##
## COORDINATE SPACE (important): the scene's origin is the art's BASE ANCHOR — the middle
## of the sprite's lowest wide row, i.e. where it meets the ground. The sprite is placed so
## that is true on screen, so what you see is what the game uses. Points are SOURCE PIXELS,
## scaled per instance at spawn, which is why one polygon serves every size of that prop.
##
## Re-running SKIPS keys that already have a scene — your edits are never overwritten.

const OUT_DIR := "res://scenes/ground/colliders"

## art path -> key. Props and buildings both, since both build colliders the same way.
const SOURCES := {
	"res://assets/ground/props/boulders.png": "boulders",
	"res://assets/ground/props/mesa.png": "mesa",
	"res://assets/ground/buildings/starport.png": "starport",
	"res://assets/ground/buildings/guild.png": "guild",
	"res://assets/ground/buildings/aquaponics.png": "aquaponics",
	"res://assets/ground/buildings/market.png": "market",
	"res://assets/ground/buildings/hab.png": "hab",
	"res://assets/ground/buildings/cave.png": "cave",
}

## Mirrors epharon_town's automatic footprint, so the seeded polygon starts exactly where
## the game would have put the rectangle.
const FOOTPRINT_DEPTH := 0.55
const FOOTPRINT_INSET := 0.94


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var made := 0
	var skipped := 0
	for path in SOURCES:
		var key: String = SOURCES[path]
		var out := "%s/%s.tscn" % [OUT_DIR, key]
		if ResourceLoader.exists(out):
			print("  skip (already authored): ", out)
			skipped += 1
			continue
		if not FileAccess.file_exists(path):
			print("  skip (no art): ", path)
			continue
		var img := Image.new()
		if img.load(path) != OK:
			print("  skip (unreadable): ", path)
			continue
		var br := ArtAnchor.base_row(img)
		if br.is_empty():
			print("  skip (blank art): ", path)
			continue
		if _write_scene(out, path, img, br):
			made += 1
	print("collider scenes: %d written, %d already authored -> %s" % [made, skipped, OUT_DIR])
	quit(0)


func _write_scene(out: String, art: String, _img: Image, br: Dictionary) -> bool:
	# Offsets that put the art's BASE ANCHOR at the scene origin — the same maths
	# _spawn_prop uses, so the editor view matches the game exactly.
	var off := ArtAnchor.base_offset(br)
	var w: float = float(br.right) - float(br.left)
	var depth: float = w * FOOTPRINT_DEPTH
	var half_w: float = w * FOOTPRINT_INSET * 0.5
	# Seed polygon = the automatic rectangle: front edge on the base line (y = 0),
	# footprint standing behind it (negative y is "back"/north).
	var pts := PackedVector2Array([
		Vector2(-half_w, 0.0), Vector2(half_w, 0.0),
		Vector2(half_w, -depth), Vector2(-half_w, -depth)])

	var root := Node2D.new()
	root.name = "PropCollider"
	var spr := Sprite2D.new()
	spr.name = "ArtReference"
	spr.texture = load(art)
	spr.centered = false
	spr.offset = off
	root.add_child(spr)
	spr.owner = root
	var poly := CollisionPolygon2D.new()
	poly.name = "Footprint"
	poly.polygon = pts
	root.add_child(poly)
	poly.owner = root

	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		print("  FAILED to pack: ", out)
		return false
	if ResourceSaver.save(packed, out) != OK:
		print("  FAILED to save: ", out)
		return false
	print("  wrote ", out, "   (base width %.0fpx, seeded depth %.0fpx)" % [w, depth])
	return true
