extends SceneTree
## AUTHORING TOOL — weapon-anchor scenes, one per character, hand-editable in the editor.
##
##   <godot> --headless --path . --script res://tools/make_anchor_scenes.gd
##
## For every character with a Walking animation this writes
## `scenes/ground/anchors/<Folder>/Walking.tscn`: each frame laid out as a reference
## sprite with two Marker2D children —
##   `one` = the ONE-HAND grip (drag onto the palm, ROTATE the gizmo = weapon angle,
##           Inspector meta `behind` = draw weapon behind the body)
##   `two` = the TWO-HAND carry anchor (same controls)
## The GAME reads these via WeaponAnchors.load_set; a missing scene falls back to the
## built-in table, so generating is opt-in and deleting a scene restores defaults.
##
## SEEDING IS DETECTED, NOT GUESSED (the eyeballed PoC table didn't attach — user):
## hands are bare skin, and skin pixels below the face can only be hands. Each character
## teaches us its own skin palette from its face band, so Imari's dark skin and Tam's
## tan seed as well as PilotM's. Characters where detection finds nothing (the hooded
## goblin has no visible skin) seed from the scaled fallback — still fully editable.
##
## TRAILING-HAND RULE (found on the PoC's stride frames): when the detected hand sits
## on the BACK side relative to facing, the weapon would pierce the torso — those
## frames seed with `behind = true` (east/west only; south/north keep pose defaults).
##
## Re-running SKIPS characters that already have a scene — edits are never overwritten.

const CHAR_ROOT := "res://assets/characters"
const OUT_ROOT := "res://scenes/ground/anchors"
const DIRS := ["south", "east", "north", "west"]


func _init() -> void:
	var made := 0
	var skipped := 0
	var da := DirAccess.open(CHAR_ROOT)
	if da == null:
		print("no characters dir")
		quit(1)
		return
	for folder in da.get_directories():
		# EVERY animation group gets its own anchor scene — Walking, Aiming, Kneeling...
		# Pose groups are single-frame, so their scenes are one column of markers.
		var groups_dir := "%s/%s/animations" % [CHAR_ROOT, folder]
		var gda := DirAccess.open(groups_dir)
		if gda == null:
			continue
		for group in gda.get_directories():
			var gpath := "%s/%s" % [groups_dir, group]
			var out := "%s/%s/%s.tscn" % [OUT_ROOT, folder, group]
			if ResourceLoader.exists(out):
				print("  skip (already authored): ", out)
				skipped += 1
				continue
			if _write_scene(folder, gpath, out):
				made += 1
	print("anchor scenes: %d written, %d already authored -> %s" % [made, skipped, OUT_ROOT])
	quit(0)


func _write_scene(folder: String, walk: String, out: String) -> bool:
	# Canvas size + this character's own skin palette (from its south rotation's face).
	var south0 := _img("%s/south/frame_000.png" % walk)
	if south0 == null:
		return false
	var canvas := south0.get_width()
	var rot_south := _img("%s/%s/rotations/south.png" % [CHAR_ROOT, folder])
	var skin := _skin_palette(rot_south if rot_south != null else south0)
	var fallback := WeaponAnchors._fallback_set(canvas)

	var is_pose := not FileAccess.file_exists(
		ProjectSettings.globalize_path("%s/south/frame_001.png" % walk))
	var root := Node2D.new()
	root.name = "WeaponAnchors"
	for r in DIRS.size():
		var d: String = DIRS[r]
		var dir_node := Node2D.new()
		dir_node.name = d
		dir_node.position = Vector2(0, r * (canvas + 24))
		root.add_child(dir_node)
		dir_node.owner = root
		for f in 4:
			var frame_path := "%s/%s/frame_%03d.png" % [walk, d, f]
			var img := _img(frame_path)
			if img == null:
				continue   # pose groups carry a single frame; missing indexes just skip
			var spr := Sprite2D.new()
			spr.name = "frame_%d" % f
			spr.texture = load(frame_path)
			spr.centered = false
			spr.position = Vector2(f * (canvas + 24), 0)
			dir_node.add_child(spr)
			spr.owner = root

			var seed_one: Dictionary = fallback[d][f]["one"]
			var seed_two: Dictionary = fallback[d][f]["two"]
			var hand := _detect_hand(img, skin, d)
			if hand != Vector2.INF:
				seed_one = {"pos": hand, "rot": seed_one["rot"],
					"behind": _trailing(hand, d, canvas) or bool(seed_one["behind"])}
				# POSE groups (a single held frame — Aiming, Kneeling): the hands ARE the
				# carry, so the two-hand marker rides the detected hands too. WALKING keeps
				# the body-anchored carry (the PoC finding: a walked two-hander must not
				# chase one swinging arm).
				if is_pose:
					seed_two = {"pos": hand, "rot": seed_two["rot"], "behind": seed_two["behind"]}
			_marker(spr, root, "one", seed_one)
			_marker(spr, root, "two", seed_two)

	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		print("  FAILED to pack ", out)
		return false
	DirAccess.make_dir_recursive_absolute("%s/%s" % [OUT_ROOT, folder])
	if ResourceSaver.save(packed, out) != OK:
		print("  FAILED to save ", out)
		return false
	print("  wrote ", out, "  (canvas %d, skin tones %d)" % [canvas, skin.size()])
	return true


func _marker(parent: Sprite2D, root: Node2D, mname: String, entry: Dictionary) -> void:
	var m := Marker2D.new()
	m.name = mname
	m.position = entry["pos"]
	m.rotation = float(entry["rot"])
	m.gizmo_extents = 6.0
	m.set_meta("behind", bool(entry["behind"]))
	parent.add_child(m)
	m.owner = root


func _img(path: String) -> Image:
	if not FileAccess.file_exists(path.replace("res://", ProjectSettings.globalize_path("res://"))) \
			and not ResourceLoader.exists(path):
		return null
	var img := Image.new()
	return img if img.load(ProjectSettings.globalize_path(path)) == OK else null


## Warm tones sampled from the face band (upper-middle of the sprite).
func _skin_palette(img: Image) -> Dictionary:
	var tones := {}
	var w := img.get_width()
	var h := img.get_height()
	for y in range(int(h * 0.1), int(h * 0.38)):
		for x in range(int(w * 0.3), int(w * 0.7)):
			var c := img.get_pixel(x, y)
			if c.a > 0.4 and c.r8 > 110 and c.r8 > c.b8 and absi(c.r8 - c.g8) < 95:
				tones[Color8(c.r8, c.g8, c.b8)] = tones.get(Color8(c.r8, c.g8, c.b8), 0) + 1
	var skin := {}
	for c in tones:
		if tones[c] > 2:
			skin[c] = true
	return skin


## Largest skin cluster below the face = the near hand. INF if this character hides
## its hands (gloves, a hood-shadowed goblin) — the caller keeps the fallback seed.
func _detect_hand(img: Image, skin: Dictionary, _d: String) -> Vector2:
	if skin.is_empty():
		return Vector2.INF
	var w := img.get_width()
	var h := img.get_height()
	var pts: Array[Vector2i] = []
	for y in range(int(h * 0.44), int(h * 0.85)):
		for x in range(int(w * 0.12), int(w * 0.88)):
			var c := img.get_pixel(x, y)
			if c.a > 0.4 and skin.has(Color8(c.r8, c.g8, c.b8)):
				pts.append(Vector2i(x, y))
	if pts.is_empty():
		return Vector2.INF
	# cluster by x-gap; keep the biggest cluster's centroid
	pts.sort()
	var clusters: Array = [[pts[0]]]
	for i in range(1, pts.size()):
		if pts[i].x - (clusters[-1][-1] as Vector2i).x > 5:
			clusters.append([pts[i]])
		else:
			clusters[-1].append(pts[i])
	var best: Array = clusters[0]
	for cl in clusters:
		if cl.size() > best.size():
			best = cl
	var sum := Vector2.ZERO
	for p in best:
		sum += Vector2(p)
	return (sum / best.size()).round()


## On profile frames, a hand on the BACK side means the weapon would pierce the torso —
## seed those frames as behind-the-body.
func _trailing(hand: Vector2, d: String, canvas: int) -> bool:
	var mid := canvas * 0.5
	if d == "east":
		return hand.x < mid - canvas * 0.07
	if d == "west":
		return hand.x > mid + canvas * 0.07
	return false
