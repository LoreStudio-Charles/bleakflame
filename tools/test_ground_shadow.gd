extends Node
## Shadow-contact contract (user's spec): a building's shadow must TOUCH the sprite at the two
## outer corners of its base — the left and right ends of the widest base row. If a shadow
## corner lands anywhere but the sprite's corner, there's a gap and the building reads as
## FLOATING. This measures that gap in world space (sprite corner vs shadow corner) and fails
## if any exceeds TOL. The town stashes the corner columns at build time, so this only does
## transform math — no get_image (which hangs headless). Run as a SCENE:
##   <godot> --headless --path . res://tools/test_ground_shadow.tscn

const TOL := 2.0   # world px; the two corners should coincide near-exactly

func _ready() -> void:
	var town: Node = load("res://scenes/ground/epharon_town.tscn").instantiate()
	add_child(town)
	await get_tree().process_frame
	await get_tree().process_frame

	var pairs: Array = town.get("_shadow_pairs")
	var ok := true
	var checked := 0
	for p in pairs:
		var spr: Sprite2D = p["spr"]
		var shd: Sprite2D = p["shd"]
		for side in ["left", "right"]:
			var tex_pt := Vector2(float(p[side]), float(p["y"]))
			# world position of that texture pixel under each node (offset is a draw property,
			# so add it to the local point before to_global).
			var on_sprite: Vector2 = spr.to_global(spr.offset + tex_pt)
			var on_shadow: Vector2 = shd.to_global(shd.offset + tex_pt)
			var gap := on_sprite.distance_to(on_shadow)
			checked += 1
			var touches := gap <= TOL
			ok = ok and touches
			print("  %-16s %-5s corner  gap=%.2f  %s" % [
				p["name"], side, gap, "ok" if touches else "FAIL — floating"])

	print("test_ground_shadow: %d corners checked -> %s" % [checked, "PASS" if ok else "FAIL"])
	get_tree().quit(0 if (ok and checked > 0) else 1)
