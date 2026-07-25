extends Node
## GROUND COMBAT v1 (docs/ground_combat.md): the damage order, cover, the goblin's
## scavenger AI (flee, pack courage, TOWN SANCTUARY), target-locked attacks, and the
## death seam. Run as a SCENE:
##   <godot> --headless --path . res://tools/test_ground_combat.tscn

var _fails := 0


func _ready() -> void:
	# ---- 1) THE DAMAGE ORDER: raw -> barrier soaks -> remainder x (1-mit) -> health ----
	var w := GroundCharacter.new()
	w.setup("res://assets/characters/PilotM")
	add_child(w)
	w.max_health = 100.0
	w.health = 100.0
	w.max_barrier = 20.0
	w.barrier = 20.0
	w.mitigation = 0.5
	var taken := w.take_damage(30.0)
	# 30 raw: 20 soaked by barrier, 10 through, x0.5 mitigation = 5 to health.
	_chk(is_equal_approx(w.barrier, 0.0), "barrier soaks FIRST (fully spent)")
	_chk(is_equal_approx(taken, 5.0), "mitigation halves what got through (took %.1f)" % taken)
	_chk(is_equal_approx(w.health, 95.0), "health carries the remainder")

	# Mitigation never zeroes a hit (min 1 damage).
	w.mitigation = 0.85
	w.take_damage(1.0)
	_chk(w.health < 95.0, "a hit always costs at least 1")

	# ---- 2) KNEELING adds cover mitigation ----
	w.mitigation = 0.2
	w.health = 100.0
	w.set_pose("kneeling")
	w.take_damage(10.0)
	# 10 x (1 - (0.2+0.25)) = 5.5
	_chk(is_equal_approx(w.health, 94.5), "kneeling stacks COVER_MITIGATION (health %.1f)" % w.health)
	w.set_pose("")

	# ---- 3) TARGET-LOCKED attack: in range + off cooldown = the hit lands ----
	var g := DustGoblin.new()
	add_child(g)
	g.setup_goblin(Vector2(3000, 1500))
	w.add_to_group("player_walker")           # the goblin's brain hunts this group
	w.team = "player_team"
	w.global_position = Vector2(3000, 1520)   # inside claw reach
	w.max_health = 100.0
	w.health = 100.0
	w.mitigation = 0.0
	g.engage(w)
	for _i in 12:
		await get_tree().physics_frame
	_chk(w.health < 100.0, "the goblin's swipe landed (target-locked resolution)")

	# ---- 3b) THE KILL STANDS YOU DOWN: auto-attack clears when the target dies ----
	var victim := GroundCharacter.new()
	victim.setup("res://assets/characters/Colonist")
	add_child(victim)
	victim.max_health = 10.0
	victim.health = 10.0
	w.set_melee(50.0, 60.0, 0.2)
	w.global_position = Vector2(5000, 5000)
	victim.global_position = Vector2(5000, 5040)
	w.engage(victim)
	for _i in 20:
		await get_tree().physics_frame
		if victim.dead:
			break
	_chk(victim.dead, "the engage killed the practice victim")
	for _i in 4:
		await get_tree().physics_frame
	_chk(not w.auto_attack and w.combat_target == null,
		"auto-attack STOOD DOWN when the target died (next select must not fire)")
	# ...AND THE CORPSE IS RELEASED. Separate assertion because these two have separate
	# causes now: the death EVENT clears auto_attack, the per-frame housekeeping drops the
	# reference. When the refactor moved the stand-down into the event, the housekeeping
	# was left below the `not auto_attack` early-return — so it stopped running the moment
	# the event fired, and the dead target stayed selected. Order matters; this pins it.
	for _i in 6:
		await get_tree().physics_frame
	_chk(w.combat_target == null, "the dead target is RELEASED even with auto-attack off")
	w.attack_spec = {}

	# ---- 4) SCAVENGER AI: break-and-run at low health ----
	g.global_position = g.home + Vector2(320, 0)   # wounded OUT in the field
	g.health = g.max_health * 0.2
	for _i in 6:
		await get_tree().physics_frame
	_chk(not g.auto_attack, "a wounded goblin stops fighting")
	_chk(g.is_moving(), "...and bolts for home")

	# ---- 5) THE TOWN IS SANCTUARY ----
	var g2 := DustGoblin.new()
	add_child(g2)
	g2.setup_goblin(Vector2(1600, 300))
	w.global_position = Vector2(400, 200)     # deep inside the colony's light
	w.health = 100.0
	for _i in 6:
		await get_tree().physics_frame
	_chk(not g2.auto_attack, "a goblin never attacks prey inside the town's light")

	# ---- 6) DEATH routes through THE seam ----
	var hold := preload("res://tools/fake_hold.gd").new()
	add_child(hold)
	hold.add_commodity("food", 3)
	var result := GroundDeath.apply(hold)
	_chk(int(hold.commodities.get("food", 0)) == 0, "the bag drops on death (v1 policy)")
	_chk((result.get("dropped", []) as Array).size() == 1, "the seam reports what fell")
	_chk(str(result.get("wake", "")) == "starport", "you wake at the Starport")

	# ---- 7) Goblin death: XP is the ONE spine ----
	var xp0 := Wallet.xp
	var g3 := DustGoblin.new()
	add_child(g3)
	g3.setup_goblin(Vector2(3200, 1800))
	g3.take_damage(500.0)
	_chk(g3.dead, "enough damage kills a goblin")
	# (The town pays the XP via its died hook; here we just assert the signal fired
	# by checking dead-state cleanup.)
	_chk(not g3.auto_attack and g3.combat_target == null, "death clears its fight state")
	# The corpse must not float: the projected shadow (a flipped STANDING copy) fades out
	# with the fall — a lying body casts nothing.
	await get_tree().create_timer(1.2).timeout
	var shadow: AnimatedSprite2D = g3.get("_shadow")
	_chk(shadow != null and shadow.modulate.a < 0.05,
		"a corpse casts no standing shadow (alpha %.2f)" % (shadow.modulate.a if shadow else 1.0))
	_chk(Wallet.xp == xp0, "XP is paid by the TOWN hook, not the actor (no double-pay)")

	# ---- 8) RETALIATION TARGETING: a hit acquires the attacker — only into an empty slot ----
	var pv := GroundCharacter.new()
	pv.setup("res://assets/characters/PilotM")
	add_child(pv)
	pv.team = "player_team"
	pv.global_position = Vector2(7000, 7000)
	var gob := DustGoblin.new()
	add_child(gob)
	gob.setup_goblin(Vector2(7000, 7040))
	pv.take_damage(3.0, gob)
	_chk(pv.combat_target == gob, "an unprovoked hit acquires the attacker as target")
	_chk(not pv.auto_attack, "...but never pulls the trigger for you (target, not engage)")
	var gob2 := DustGoblin.new()
	add_child(gob2)
	gob2.setup_goblin(Vector2(7040, 7000))
	pv.take_damage(3.0, gob2)
	_chk(pv.combat_target == gob, "a flank hit NEVER re-aims a fight in progress")

	# ---- 9) GOBLIN GEAR DROPS: every pool path is real, and the pool matches the
	# mirror test_ground_gear.gd asserts in --script mode (which can't name this class).
	for path in DustGoblin.DROP_POOL:
		_chk(ResourceLoader.exists(path), "drop pool resource exists: " + path)
	_chk(DustGoblin.DROP_POOL == ["res://data/ground/scrap_shiv.tres",
		"res://data/ground/rag_hood.tres", "res://data/ground/work_gloves.tres"],
		"DROP_POOL matches the mirrored list in test_ground_gear.gd")
	# The clutched find is a real, affix-capable item.
	var corpse := DustGoblin.new()
	add_child(corpse)
	corpse.setup_goblin(Vector2(9000, 9000))
	corpse.die()
	var found_gear := false
	for _i in 60:   # 22% a roll — 60 corpses miss all three ~3-in-a-million
		corpse.looted = false
		var haul := corpse.loot()
		if haul.get("gear") != null:
			found_gear = true
			_chk(haul.gear is GroundGearDef, "the clutched find is ground gear")
			break
	_chk(found_gear, "some corpses clutch gear (60 rolls, none hit)")

	# ---- 10) THE DUNE AMBUSH: hidden, inert, and unfindable until it springs ----
	# The whole point is that you get no tell, so "dormant" has to mean ALL of it: not
	# drawn, not thinking, and NOT IN THE HOSTILE GROUP — otherwise TAB-cycle or a radar
	# sweep names three goblins standing in empty sand before they've moved.
	var lurker := DustGoblin.new()
	add_child(lurker)
	lurker.setup_goblin(Vector2(20000, 20000))
	lurker.lie_in_wait()
	_chk(not lurker.visible, "a waiting ambusher is invisible")
	_chk(not lurker.is_in_group("ground_hostiles"), "...and cannot be targeted or cycled")
	var walker := GroundCharacter.new()
	walker.setup("res://assets/characters/PilotM")
	add_child(walker)
	walker.team = "player_team"
	walker.add_to_group("player_walker")
	walker.global_position = Vector2(20000, 20060)   # right on top of it
	var lurk_pos := lurker.global_position
	for _i in 20:
		await get_tree().physics_frame
	_chk(lurker.global_position == lurk_pos, "it does not stir, even with prey beside it")
	_chk(not lurker.auto_attack, "...and does not attack while it waits")
	lurker.spring(walker)
	_chk(lurker.visible and lurker.is_in_group("ground_hostiles"), "springing reveals it")
	_chk(lurker.combat_target == walker and lurker.auto_attack, "springing sends it at you")
	_chk(lurker.home == lurk_pos, "it leashes to the cover it broke from, not a far warren")

	print("test_ground_combat: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _chk(cond: bool, msg: String) -> void:
	print(("  ok  " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1
