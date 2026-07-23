extends SceneTree
## One-off: write ONLY the Umbral Cloak Field .tres (the full generator would
## overwrite hand-edited data/). Mirrors the generator's cloak block. Safe to
## delete after running. Run: <godot> --headless --path . --script res://tools/make_cloak.gd

const SystemDefS := preload("res://scripts/schema/system_def.gd")
const GradesS := preload("res://scripts/schema/grades.gd")

func _init() -> void:
	var G := GradesS.Grade
	var s := SystemDefS.new()
	s.display_name = "Umbral Cloak Field"
	s.grade = G.ADVANCED
	s.mark = 1; s.mass = 4.0; s.power_draw = 8.0
	s.tags = PackedStringArray(["cloak"])
	s.profession_lock = "privateer"
	s.extra = {"cloak_duration": 6.0, "cloak_cooldown": 14.0}
	s.description = "Privateer tech. Bend light around the hull: hostiles lose their lock for a few seconds. Firing a weapon collapses the field."
	var path := "res://data/components/systems/umbral_cloak_field.tres"
	var err := ResourceSaver.save(s, path)
	print("cloak save: ", "OK " + path if err == OK else "ERR %d" % err)

	var b := SystemDefS.new()
	b.display_name = "Bulwark Projector"
	b.grade = G.ADVANCED
	b.mark = 1; b.mass = 5.0; b.power_draw = 9.0
	b.tags = PackedStringArray(["bulwark"])
	b.profession_lock = "guardian"
	b.extra = {"bulwark_duration": 5.0, "bulwark_cooldown": 18.0,
		"bulwark_radius": 420.0, "bulwark_reduction": 0.5}
	b.description = "Guardian tech. Throw a blue damage-reduction dome over yourself and every ally in range for 5s — the brace for a boss's alpha strike."
	var bpath := "res://data/components/systems/bulwark_projector.tres"
	var berr := ResourceSaver.save(b, bpath)
	print("bulwark save: ", "OK " + bpath if berr == OK else "ERR %d" % berr)
	quit()
