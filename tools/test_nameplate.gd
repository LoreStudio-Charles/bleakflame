extends Node
## NAMEPLATES AND UNIT FRAMES — the rules that decide what a player is told about the
## people around them on foot.
##
## These are worth pinning because the ground mode is about to be built THREE MORE TIMES
## (user, 2026-07-27: two more planets in this system), and every rule here is one a new
## scene inherits for free or silently loses.
##
## RUN AS A SCENE (autoloads + real character art):
##   <godot> --headless --path . res://tools/test_nameplate.tscn --quit-after 900

var _fails: Array[String] = []
var _checks := 0

const ART := "res://assets/characters/Colonist"


func _ready() -> void:
	_case_every_character_gets_a_plate()
	_case_plates_show_only_what_matters()
	_case_a_pack_does_not_pile_up()
	_case_tint_does_not_bleed_into_the_plate()
	_case_health_is_not_identity()

	if _fails.is_empty():
		print("test_nameplate: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_nameplate: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


## THE SINGLE-SOURCE RULE. The plate is attached by GroundCharacter.setup(), not by the
## spawner, so that the next spawn site somebody adds cannot be the one that quietly has
## no plate. If this breaks, plates go missing per-spawner and nothing else notices.
func _case_every_character_gets_a_plate() -> void:
	var c := _actor("Someone")
	_ok(_plate_of(c) != null, "setup() gives every ground character a nameplate")
	_ok(_plate_of(c).is_in_group("nameplates"),
		"...and it joins the nameplates group, so plates can see each other")
	c.queue_free()


func _case_plates_show_only_what_matters() -> void:
	var me := _actor("Me", "player_team")
	me.add_to_group("player_walker")
	var foe := _actor("Foe", "hostile")
	var civ := _actor("Civ")

	var pm := _plate_of(me)
	var pf := _plate_of(foe)
	var pc := _plate_of(civ)
	_ok(pf.viewer() == me, "a plate finds the viewer from the scene, not from a constructor")

	foe.global_position = Vector2(300, 0)
	_ok(pf._should_draw(), "a hostile inside HOSTILE_RANGE is drawn")
	foe.global_position = Vector2(Nameplate.HOSTILE_RANGE + 200.0, 0)
	_ok(not pf._should_draw(), "...and is dropped once it is far enough away")

	# The thing you are pointed at is ALWAYS drawn, however far off. Losing your own
	# target's plate at range would be the single most annoying way for this to fail.
	me.combat_target = foe
	_ok(pf._should_draw(), "your current target is drawn at ANY range")
	me.combat_target = null

	_ok(pm._should_draw(), "your own marker is always on")

	civ.global_position = Vector2(200, 0)
	_ok(pc._should_draw(), "a named bystander close by is drawn")
	civ.global_position = Vector2(Nameplate.NAME_RANGE + 100.0, 0)
	_ok(not pc._should_draw(), "...and a distant one is not — a town is not a label soup")

	# A HURT bystander is worth noticing even though an unhurt one at the same spot is not.
	civ.global_position = Vector2(200, 0)
	civ.health = civ.max_health * 0.5
	_ok(pc._should_draw(), "someone wounded nearby is drawn")

	foe.global_position = Vector2(100, 0)
	foe.dead = true
	_ok(not pf._should_draw(), "the dead wear no plate")

	for n in [me, foe, civ]:
		n.queue_free()


## THE PILE. Four scrit standing together drew four plates in the same few pixels and the
## names overprinted into an unreadable smear — this is what the screenshot showed and
## what _stack_index exists to fix.
func _case_a_pack_does_not_pile_up() -> void:
	var me := _actor("Me", "player_team")
	me.add_to_group("player_walker")
	me.global_position = Vector2(0, 500)
	var pack: Array[GroundCharacter] = []
	for i in 4:
		var g := _actor("Scrit", "hostile")
		g.global_position = Vector2(10.0 * i, 300.0 + 4.0 * i)   # a tight, overlapping clump
		pack.append(g)

	var slots := {}
	for g in pack:
		slots[_plate_of(g)._stack_index()] = true
	_ok(slots.size() == pack.size(),
		"four plates in a clump take four DIFFERENT slots (got %d)" % slots.size())

	# Depth order: the one standing furthest back is pushed highest, so the plates read
	# top-to-bottom in the same order the bodies read back-to-front.
	var back := _plate_of(pack[0])._stack_index()     # smallest y = furthest back
	var front := _plate_of(pack[3])._stack_index()    # largest y = nearest the camera
	_ok(back > front,
		"the character furthest back takes the highest slot (back %d > front %d)"
			% [back, front])

	# Far apart is NOT a pile, and must not be stacked — a plate floating a screen above
	# its owner because something unrelated stood near it is worse than an overlap.
	pack[3].global_position = Vector2(2000, 2000)
	_ok(_plate_of(pack[3])._stack_index() == 0,
		"a character standing alone takes the bottom slot, hard against its own head")

	me.queue_free()
	for g in pack:
		g.queue_free()


## THE CASCADE. `modulate` applies to children, and a character's children now include its
## nameplate — so tinting the NODE would tint the plate. This is the hull-decal bug in a
## second place (set_hull_tint writes self_modulate for exactly this reason), and it hid
## there for months because the tints in play were mild. The two tints in play here are
## mild too, so it would have hidden here as well.
func _case_tint_does_not_bleed_into_the_plate() -> void:
	var c := _actor("Tinted")
	c.set_tint(Color(0.2, 0.1, 0.4))
	_ok(c.modulate.is_equal_approx(Color.WHITE),
		"set_tint leaves the NODE's modulate alone, so the plate is not tinted with it")
	var plate := _plate_of(c)
	_ok(plate.modulate.is_equal_approx(Color.WHITE), "...and the plate is drawn untinted")
	c.queue_free()


## THE TWO BLUES. The first frame drew the player's health in the SELF colour, directly
## above a cell gauge that is also blue and also full width — they read as one confusing
## double bar. Identity belongs on the name and the border; the bar carries health.
func _case_health_is_not_identity() -> void:
	var me := _actor("Me", "player_team")
	me.add_to_group("player_walker")
	var foe := _actor("Foe", "hostile")
	var hud := GroundHud.new()
	hud.walker = me
	add_child(hud)

	_ok(not hud._health_color(me).is_equal_approx(Nameplate.SELF),
		"your health bar is NOT the same colour as your cell gauge")
	_ok(hud._health_color(me).is_equal_approx(Nameplate.FRIENDLY),
		"...it is the friendly colour, which is what the town used before frames existed")
	_ok(hud._relation(me).is_equal_approx(Nameplate.SELF),
		"identity still reads SELF on the name and border")
	_ok(hud._health_color(foe).is_equal_approx(Nameplate.HOSTILE),
		"a hostile's health bar reads hostile")

	hud.queue_free()
	me.queue_free()
	foe.queue_free()


func _actor(nm: String, team := "") -> GroundCharacter:
	var c := GroundCharacter.new()
	# ADDED TO THE TREE FIRST: setup() attaches the plate, and a plate needs a tree to
	# find its viewer in.
	add_child(c)
	c.setup(ART)
	c.display_name = nm
	c.team = team
	return c


func _plate_of(c: GroundCharacter) -> Nameplate:
	for child in c.get_children():
		if child is Nameplate:
			return child
	return null


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)
