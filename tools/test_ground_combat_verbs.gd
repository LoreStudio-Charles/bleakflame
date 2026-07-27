extends Node2D
## THE COMBAT VERBS ON FOOT — target selection and the technique refusal ladder.
##
## These moved out of epharon_town so the next two planets inherit them, and moving code
## that nothing tests is how a working thing quietly stops working. The refusal INVARIANT
## in particular ("a refused technique costs no energy and no cooldown") was written down
## in a comment and asserted nowhere.
##
## RUN AS A SCENE (autoloads + real character art):
##   <godot> --headless --path . res://tools/test_ground_combat_verbs.tscn --quit-after 900

var _fails: Array[String] = []
var _checks := 0
var _said: Array[String] = []      # everything the verbs asked the scene to show

const ART := "res://assets/characters/Colonist"


func _ready() -> void:
	_case_nearest_picks_the_closest()
	_case_cycling_walks_the_ring()
	_case_the_cursor_picks_a_body()
	_case_a_refused_technique_costs_nothing()
	_case_a_real_cast_charges_for_itself()
	_case_refusals_are_never_silent()

	if _fails.is_empty():
		print("test_ground_combat_verbs: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_ground_combat_verbs: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _case_nearest_picks_the_closest() -> void:
	var me := _actor("Me", "player_team")
	var near := _hostile(Vector2(200, 0))
	var far := _hostile(Vector2(600, 0))
	var gone := _hostile(Vector2(50, 0))
	gone.dead = true

	var got := GroundCombat.nearest_hostile(get_tree(), me.global_position)
	_ok(got == near, "the NEAREST live hostile is picked")
	_ok(got != gone, "...and a corpse is never picked, however close it lies")

	# Out of reach means out of reach: [Q] and [TAB] must not reach across the map and
	# start a fight with something the player cannot even see.
	var none := GroundCombat.nearest_hostile(get_tree(), me.global_position, null, 100.0)
	_ok(none == null, "nothing beyond the cycle range is offered")
	_ok(GroundCombat.nearest_hostile(get_tree(), me.global_position, null, 700.0) == near,
		"...and widening the range brings them back")

	for n in [me, near, far, gone]:
		n.free()


## [TAB] cycles. The wrap is the bit worth pinning — a cycle that stops at the last foe
## instead of coming round strands the player pressing a dead key.
func _case_cycling_walks_the_ring() -> void:
	var me := _actor("Me", "player_team")
	var a := _hostile(Vector2(100, 0))
	var b := _hostile(Vector2(200, 0))
	var c := _hostile(Vector2(300, 0))

	var first := GroundCombat.nearest_hostile(get_tree(), me.global_position)
	_ok(first == a, "cycling starts at the nearest")
	var second := GroundCombat.nearest_hostile(get_tree(), me.global_position, a)
	_ok(second == b, "...then the next one out")
	var third := GroundCombat.nearest_hostile(get_tree(), me.global_position, b)
	_ok(third == c, "...and the next")
	_ok(GroundCombat.nearest_hostile(get_tree(), me.global_position, c) == a,
		"...and WRAPS to the nearest again rather than dead-ending")

	for n in [me, a, b, c]:
		n.free()


func _case_the_cursor_picks_a_body() -> void:
	var foe := _hostile(Vector2(500, 500))
	# Bodies are picked at CHEST height, not at the feet-anchored origin — that is where
	# the eye says the creature is, and clicking its middle must select it.
	var chest := foe.global_position - Vector2(0, 24)
	_ok(GroundCombat.hostile_at(get_tree(), chest) == foe, "a click on the body selects it")
	_ok(GroundCombat.hostile_at(get_tree(), chest + Vector2(500, 0)) == null,
		"a click on empty sand selects nothing")
	foe.dead = true
	_ok(GroundCombat.hostile_at(get_tree(), chest) == null, "a corpse is not clickable prey")
	foe.free()


## THE INVARIANT. Every refusal path must leave the cell and the cooldown untouched, or a
## fumbled key press quietly costs a fight. Each branch is exercised separately, because
## "it works for the one I happened to try" is how the other seven get missed.
func _case_a_refused_technique_costs_nothing() -> void:
	var me := _actor("Me", "player_team")
	me.max_energy = 100.0
	me.energy = 100.0
	var combat := GroundCombat.new(me, self, Callable(self, "_record"))

	# 1. EMPTY SLOT
	Pilot.set_technique(0, "")
	_spent(combat, 0, me, "an empty slot")

	# 2. MEDITATING
	Pilot.set_technique(0, "second_wind")
	me.set_meditating(true)
	_spent(combat, 0, me, "meditating")
	me.set_meditating(false)

	# 3. REELING
	me.apply_stun(3.0)
	_spent(combat, 0, me, "reeling")
	me._stun_t = 0.0

	# 4. NO TARGET for a technique that needs one
	Pilot.set_technique(1, "sand_kick")
	me.combat_target = null
	_spent(combat, 1, me, "no target")

	# 5. OUT OF RANGE
	var foe := _hostile(Vector2(4000, 0))
	me.combat_target = foe
	_spent(combat, 1, me, "out of range")

	# 6. UNHURT, for the heal
	Pilot.set_technique(2, "field_patch")
	me.health = me.max_health
	_spent(combat, 2, me, "already at full health")

	# 7. NOT ENOUGH ENERGY
	me.health = me.max_health * 0.5      # so the heal itself is allowed
	me.energy = 1.0
	var before_cd := combat.cooldowns.size()
	var fired: bool = combat.use(2)
	_ok(not fired, "an empty cell refuses the technique")
	_ok(is_equal_approx(me.energy, 1.0), "...and does not drain what little is left")
	_ok(combat.cooldowns.size() == before_cd, "...and starts no cooldown")

	me.free()
	foe.free()


## The mirror of the invariant: when it DOES go off, it pays. A test that only proves
## refusals are free would pass just as well on a technique that never fires at all.
func _case_a_real_cast_charges_for_itself() -> void:
	var me := _actor("Me", "player_team")
	me.max_energy = 100.0
	me.energy = 100.0
	me.max_health = 100.0
	me.health = 40.0
	var combat := GroundCombat.new(me, self, Callable(self, "_record"))
	Pilot.set_technique(0, "field_patch")

	var fired: bool = combat.use(0)
	var d := Techniques.def("field_patch")
	_ok(fired, "a legal technique fires")
	_ok(me.health > 40.0, "...and actually mends (%d)" % int(me.health))
	_ok(is_equal_approx(me.energy, 100.0 - float(d.energy)),
		"...and charges the cell exactly once (%d left)" % int(me.energy))
	_ok(combat.cooldowns.has("field_patch"), "...and goes on cooldown")

	# ...and the cooldown then REFUSES the next press, for free.
	var e := me.energy
	_ok(not combat.use(0), "the cooldown refuses a second press")
	_ok(is_equal_approx(me.energy, e), "...at no cost")

	# Cooldowns run down and clear themselves.
	combat.tick(float(d.cooldown) + 1.0)
	_ok(not combat.cooldowns.has("field_patch"), "a spent cooldown clears itself")

	me.free()


## EVERY refusal is loud and specific (the ship's _ability_fail rule, mirrored). A silent
## refusal reads as a broken key — this is the bug that made the ship's killshot feel dead.
func _case_refusals_are_never_silent() -> void:
	var me := _actor("Me", "player_team")
	me.max_energy = 100.0
	me.energy = 100.0
	var combat := GroundCombat.new(me, self, Callable(self, "_record"))
	Pilot.set_technique(0, "")

	_said.clear()
	combat.use(0)
	_ok(_said.size() == 1, "a refusal says something (%d messages)" % _said.size())
	_ok(_said.size() > 0 and _said[0].begins_with("✕"),
		"...and it is marked as a refusal, not mistaken for a status line")

	# The scene owns presentation: nothing here reaches for a Label. Prove the seam works
	# by using a sink that is not a UI at all — this test's own array.
	Pilot.set_technique(0, "sand_kick")
	me.combat_target = null
	_said.clear()
	combat.use(0)
	_ok(_said.size() == 1 and _said[0].contains("NO TARGET"),
		"...and says WHICH refusal it was (got %s)" % str(_said))

	me.free()


# ---- helpers ----

## Assert that one refusal branch charged nothing. `slot` must already hold the technique.
func _spent(combat: GroundCombat, slot: int, who: GroundCharacter, why: String) -> void:
	var e := who.energy
	var cds := combat.cooldowns.size()
	var fired: bool = combat.use(slot)
	_ok(not fired, "refused: %s" % why)
	_ok(is_equal_approx(who.energy, e), "...%s costs no energy" % why)
	_ok(combat.cooldowns.size() == cds, "...%s starts no cooldown" % why)


func _record(text: String, _secs: float) -> void:
	_said.append(text)


func _actor(nm: String, team := "") -> GroundCharacter:
	var c := GroundCharacter.new()
	add_child(c)
	c.setup(ART)
	c.display_name = nm
	c.team = team
	return c


func _hostile(at: Vector2) -> GroundCharacter:
	var c := _actor("Foe", "hostile")
	c.global_position = at
	c.add_to_group("ground_hostiles")
	return c


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)
