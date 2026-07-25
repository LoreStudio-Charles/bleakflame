extends SceneTree
## Seed generator for GROUND GEAR (data/ground/*.tres) — the starter kit, the goblin
## drop pool, and the first shop tier. Same contract as generate_sample_data.gd: this is
## the SEED, it OVERWRITES hand-edits, and the ground-combat doc is the design authority.
##   <godot> --headless --path . --script res://tools/generate_ground_gear.gd

const OUT := "res://data/ground"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var made := 0
	for def in _catalog():
		var g := GroundGearDef.new()
		for k in def:
			if k != "file":
				g.set(k, def[k])
		var path := "%s/%s.tres" % [OUT, def["file"]]
		if ResourceSaver.save(g, path) == OK:
			made += 1
			print("  wrote ", path)
		else:
			print("  FAILED ", path)
	print("ground gear: %d written -> %s" % [made, OUT])
	quit(0)


func _catalog() -> Array:
	var S := GroundGearDef.Slot
	var G := Grades.Grade
	return [
		# ---- STARTER KIT (Flotsam — rags and a scrap gun; the floor) ----
		{"file": "scrap_pistol", "display_name": "Scrap Pistol", "ground_slot": S.MAIN,
			"grade": G.FLOTSAM, "mark": 1, "mass": 1.2,
			"damage": 9.0, "attack_range": 240.0, "cooldown": 0.6,
			"art_key": "pistol", "grip_x": 3, "grip_y": 5,
			"description": "Somebody's hull plating, reborn as a sidearm. It goes bang more often than not."},
		{"file": "scrapweave_vest", "display_name": "Scrapweave Vest", "ground_slot": S.CHEST,
			"grade": G.FLOTSAM, "mark": 1, "mass": 2.0, "mitigation": 0.08,
			"description": "Cable braid and freighter lagging, stitched into something jacket-shaped."},
		{"file": "canvas_pants", "display_name": "Canvas Work Pants", "ground_slot": S.PANTS,
			"grade": G.FLOTSAM, "mark": 1, "mass": 1.0, "mitigation": 0.03,
			"description": "Colony issue. The knees are somebody else's patches."},
		{"file": "dune_boots", "display_name": "Dune Boots", "ground_slot": S.FEET,
			"grade": G.FLOTSAM, "mark": 1, "mass": 1.0, "mitigation": 0.02,
			"description": "Sand-proof, mostly. Nothing on this rock is sand-proof."},
		# ---- SALVAGE tier (drops + Bram's first shelf) ----
		{"file": "dune_rifle", "display_name": "Dune Rifle", "ground_slot": S.MAIN,
			"grade": G.SALVAGE, "mark": 1, "mass": 3.4,
			"damage": 16.0, "attack_range": 380.0, "cooldown": 1.0, "two_handed": true,
			"art_key": "rifle", "grip_x": 18, "grip_y": 5,
			"description": "A long gun for open country — slower, heavier, and it reaches past the shimmer."},
		{"file": "scrap_shiv", "display_name": "Scrap Shiv", "ground_slot": S.MAIN,
			"grade": G.FLOTSAM, "mark": 1, "mass": 0.6,
			"damage": 7.0, "attack_range": 42.0, "cooldown": 0.45, "melee": true,
			"description": "A goblin's answer to every question. Now it's yours."},
		{"file": "rag_hood", "display_name": "Rag Hood", "ground_slot": S.HEAD,
			"grade": G.FLOTSAM, "mark": 1, "mass": 0.5, "mitigation": 0.02,
			"description": "Keeps the sun off and the dust out. Goblin-cut, human-sized."},
		{"file": "work_gloves", "display_name": "Work Gloves", "ground_slot": S.HANDS,
			"grade": G.SALVAGE, "mark": 1, "mass": 0.4, "mitigation": 0.02,
			"description": "Palm-worn smooth at the pump handles. Tam swears by them."},
		{"file": "surveyor_belt", "display_name": "Surveyor's Belt", "ground_slot": S.WAIST,
			"grade": G.SALVAGE, "mark": 1, "mass": 0.8, "barrier": 15.0,
			"description": "A field kit's power cell rides the small of your back — enough charge to catch a blow before it lands."},
		{"file": "scrap_buckler", "display_name": "Scrap Buckler", "ground_slot": S.OFFHAND,
			"grade": G.SALVAGE, "mark": 1, "mass": 1.6, "mitigation": 0.06,
			"description": "A hatch cover with a handle. It has already survived worse than you will."},
	]
