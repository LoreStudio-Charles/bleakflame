extends Node
## GROUND TECHNIQUES (docs/ground_combat.md): the character's own bus, the effects, the
## cell, and Meditate. Run as a SCENE (needs autoloads — Pilot/Sfx):
##   <godot> --headless --path . res://tools/test_techniques.tscn

var _fails := 0


func _ready() -> void:
	Pilot.reset()

	# ---- 1) THE BOOK: universal floor known to everyone; profession kit gated ----
	var floor_set := Techniques.known()
	_chk(floor_set.has("field_patch") and floor_set.has("sand_kick"),
		"an uncommissioned character knows the universal floor")
	_chk(not floor_set.has("brace"), "a profession technique is NOT known without the commission")
	Pilot.profession = "guardian"
	_chk(Techniques.known().has("brace"), "joining the commission teaches its technique")
	Pilot.profession = ""
	_chk(not Techniques.known().has("brace"), "leaving it takes the technique back")

	# ---- 2) THE BUS is the character's own, NOT the ship's gems ----
	Pilot.set_technique(0, "field_patch")
	_chk(Pilot.technique_at(0) == "field_patch", "a technique prepares onto a bus slot")
	_chk(Pilot.gem_at(0) == "", "preparing a technique NEVER touches the ship's gem bar")
	# One technique, one slot: preparing it elsewhere vacates the old key.
	Pilot.set_technique(3, "field_patch")
	_chk(Pilot.technique_at(0) == "" and Pilot.technique_at(3) == "field_patch",
		"a technique lives on exactly ONE key")

	# ---- 3) autoprepare mirrors autowire: drop unknown, fill open, keep placed ----
	Pilot.techniques = ["brace", "", "", "sand_kick", ""]   # brace is NOT known (no commission)
	Pilot.autoprepare()
	_chk(not Pilot.techniques.has("brace"), "autoprepare drops a technique you don't know")
	_chk(Pilot.technique_at(3) == "sand_kick", "autoprepare leaves a deliberately placed key alone")
	_chk(Pilot.techniques.has("field_patch"), "autoprepare fills open slots with what you know")

	# ---- 4) PERSISTENCE: the bus survives a save round-trip ----
	var snap := Pilot.to_dict()
	Pilot.reset()
	_chk(Pilot.technique_at(3) == "", "reset clears the bus")
	Pilot.from_dict(snap)
	_chk(Pilot.technique_at(3) == "sand_kick", "the bus survives a save round-trip")

	# ---- 5) THE CELL: spend refuses when short, and spends NOTHING when it refuses ----
	var w := GroundCharacter.new()
	w.setup("res://assets/characters/PilotM")
	add_child(w)
	w.max_energy = 30.0
	w.energy = 20.0
	_chk(not w.spend_energy(25.0), "a short cell refuses the spend")
	_chk(is_equal_approx(w.energy, 20.0), "a REFUSED spend costs no energy (the ship invariant)")
	_chk(w.spend_energy(20.0) and is_equal_approx(w.energy, 0.0), "an affordable spend goes through")

	# ---- 6) EFFECTS live on the character, so anyone can apply them ----
	w.max_health = 100.0
	w.health = 50.0
	var healed := w.mend(34.0)
	_chk(is_equal_approx(healed, 34.0) and is_equal_approx(w.health, 84.0), "mend heals")
	_chk(is_equal_approx(w.mend(999.0), 16.0), "mend never overfills")

	w.mitigation = 0.1
	w.apply_brace(6.0, 0.3)
	w.health = 100.0
	w.take_damage(100.0)
	# 100 x (1 - (0.1 + 0.3)) = 60
	_chk(is_equal_approx(w.health, 40.0), "brace mitigation stacks onto worn plating (health %.1f)" % w.health)

	# ---- 7) A REELING character can't act — gated in the ONE motion path ----
	var victim := GroundCharacter.new()
	victim.setup("res://assets/characters/Colonist")
	add_child(victim)
	victim.team = "hostile"
	victim.max_health = 500.0
	victim.health = 500.0
	victim.global_position = Vector2(1000, 1000)
	var attacker := GroundCharacter.new()
	attacker.setup("res://assets/characters/PilotM")
	add_child(attacker)
	attacker.team = "player_team"
	attacker.max_health = 200.0
	attacker.health = 200.0
	attacker.global_position = Vector2(1000, 1030)
	attacker.set_melee(9.0, 60.0, 0.2)
	attacker.engage(victim)
	attacker.apply_stun(3.0)
	_chk(attacker.is_stunned(), "a kicked character is reeling")
	_chk(not attacker.auto_attack, "the reel drops auto-attack")
	var before := victim.health
	attacker.auto_attack = true          # even forced back on...
	attacker.combat_target = victim
	for _i in 20:
		await get_tree().physics_frame
	_chk(is_equal_approx(victim.health, before), "...a reeling character still lands nothing")
	# It wears off and the fight resumes.
	attacker._stun_t = 0.0
	for _i in 20:
		await get_tree().physics_frame
	_chk(victim.health < before, "the reel wears off and the attacks land again")

	# ---- 8) MEDITATE: defenseless, and the cell floods back ----
	var m := GroundCharacter.new()
	m.setup("res://assets/characters/PilotM")
	add_child(m)
	m.max_energy = 100.0
	m.energy = 10.0
	m.energy_recharge = 1.0
	m.combat_target = victim
	m.auto_attack = true
	m.set_meditating(true)
	_chk(not m.auto_attack, "meditating stands you down")
	var e0 := m.energy
	for _i in 30:
		await get_tree().physics_frame
	var med_gain := m.energy - e0
	m.set_meditating(false)
	var e1 := m.energy
	for _i in 30:
		await get_tree().physics_frame
	var idle_gain := m.energy - e1
	_chk(med_gain > idle_gain * 2.0,
		"the cell fills far faster while meditating (%.2f vs %.2f)" % [med_gain, idle_gain])
	_chk(not m.meditating and m.pose == "", "standing up ends the pose")

	# ---- 9) Every technique is REACHABLE and DESCRIBED (authoring guard) ----
	for t in Techniques.LIST:
		var id := str(t.id)
		_chk(str(t.get("name", "")) != "" and str(t.get("desc", "")) != "",
			"technique %s has a name and a description" % id)
		var src := str(t.source)
		_chk(src == "universal" or not Professions.def(src).is_empty(),
			"technique %s names a real source (%s)" % [id, src])
		_chk(Techniques.tooltip_body(id) != "", "technique %s builds a tooltip" % id)

	Pilot.reset()
	print("test_techniques: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _chk(cond: bool, msg: String) -> void:
	print(("  ok  " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1
