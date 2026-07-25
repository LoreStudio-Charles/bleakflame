extends Node
## The WEAPON DISPLAY chain (docs/ground_combat.md, hand-anchor standard): authored
## anchor scenes load per character, equip attaches a weapon sprite to the walking
## animation, the per-frame `behind` flag actually flips draw order, and the grip math
## puts the weapon INSIDE the canvas at the anchored hand.
##   <godot> --headless --path . res://tools/test_weapon_anchors.tscn

var _fails := 0


func _ready() -> void:
	# 1) The loader prefers an AUTHORED scene and falls back cleanly.
	WeaponAnchors.clear_cache()
	var setp := WeaponAnchors.load_set("PilotM", "Walking", 68)
	_chk(setp.has("south") and (setp["south"] as Array).size() == 4,
		"PilotM's authored anchor scene loads (4 frames per direction)")
	var nobody := WeaponAnchors.load_set("NoSuchCharacter", "Walking", 68)
	_chk(nobody.has("south"), "an unauthored character gets the fallback table")
	var scrit := WeaponAnchors.load_set("Scrit", "Walking", 56)
	var gpos: Vector2 = scrit["south"][0]["one"]["pos"]
	_chk(gpos.x < 56 and gpos.y < 56, "scrit anchors live on ITS canvas (56px), not the mannequin's")

	# 2) Equip on a real walking character.
	var walker := GroundCharacter.new()
	walker.setup("res://assets/characters/PilotM")
	add_child(walker)
	walker.equip_weapon(load("res://assets/ground/weapons/pistol.png"), Vector2(3, 5), false)
	await get_tree().process_frame
	var wpn: Sprite2D = walker.get("_weapon")
	_chk(wpn != null and wpn.visible, "equipping shows a weapon sprite")
	_chk(wpn.get_parent() == walker.get("_anim"),
		"the weapon rides the animation sprite (inherits flip + frame space)")

	# 3) Facing south the pistol draws IN FRONT; facing north it goes BEHIND.
	walker.face("south")
	walker.call("_apply_anim", false)
	walker.call("_sync_weapon")
	_chk(not wpn.show_behind_parent, "south carry draws in front of the body")
	var south_pos: Vector2 = wpn.position
	_chk(absf(south_pos.x) < 40 and south_pos.y > -70 and south_pos.y < 5,
		"south anchor lands within the body box (%s)" % south_pos)
	walker.face("north")
	walker.call("_apply_anim", false)
	walker.call("_sync_weapon")
	_chk(wpn.show_behind_parent, "north carry tucks behind the body")

	# 4) Two-handed style reads the CARRY table, not the hand table.
	walker.equip_weapon(load("res://assets/ground/weapons/rifle.png"), Vector2(18, 5), true)
	walker.face("south")
	walker.call("_apply_anim", false)
	walker.call("_sync_weapon")
	var carry_pos: Vector2 = wpn.position
	walker.equip_weapon(load("res://assets/ground/weapons/pistol.png"), Vector2(3, 5), false)
	walker.call("_sync_weapon")
	_chk(carry_pos != wpn.position, "two-hand carry uses its own anchors (differs from one-hand)")

	# 5) Unequip hides without freeing (re-equip is cheap).
	walker.unequip_weapon()
	_chk(not wpn.visible, "unequip hides the weapon")

	print("test_weapon_anchors: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _chk(cond: bool, msg: String) -> void:
	print(("  ok  " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1
