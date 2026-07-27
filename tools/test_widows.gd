extends Node
## THE WIDOWS LIVERY — black hull, one red hourglass (user, 2026-07-25).
##   godot --headless --path . res://tools/test_widows.tscn
##
## THE FAILURE THIS GUARDS: every other livery in the codebase gives up when a
## hull has no sprite (`BuildShip.apply_livery` returns early on a null texture).
## None of the four Long Lane hulls have art yet, so a mark written to that
## pattern would have been correct, committed, and INVISIBLE on exactly the ships
## it was drawn for. So the sprite path and the silhouette path are both asserted.

var _fails := 0


func _ready() -> void:
	_case_livery_on_a_silhouette_hull()
	_case_livery_on_an_art_hull()
	_case_no_random_pirate_skin()
	_case_mark_is_not_reapplied_twice()
	_case_a_specialist_is_still_black()
	_case_role_is_sensor_data_not_paint()
	_case_a_lane_predator_out_sees_its_prey()

	print("test_widows: %s" % ("ALL PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _fail(msg: String) -> void:
	print("FAIL: " + msg)
	_fails += 1


func _raider(build: ShipBuild) -> WidowShip:
	var s := WidowShip.new()
	add_child(s)
	s.setup_widow(build)
	return s


## THE HULL'S TINT, read from wherever it actually lives.
##
## `set_hull_tint` uses **self_modulate** on the sprite, deliberately — `modulate`
## cascades to children and would repaint the decals (that is the bug that made the
## Widows hourglass render black). The silhouette path has no sprite and tints
## `_hull_visual.color` instead.
##
## THIS HELPER EXISTS BECAUSE THE TEST READ `modulate` AND PASSED ANYWAY. With no
## art on the Goshawk it took the silhouette branch, so the wrong property was
## never consulted — the case was green for the wrong reason for a full day, and
## only broke the moment real art landed. Read the field that actually carries the
## tint, in one place.
func _hull_tint(s: WidowShip) -> Color:
	return s._hull_sprite.self_modulate if s._hull_sprite != null else s._hull_visual.color


## Every polygon under the mark, whatever it is parented to.
func _mark_polys(s: WidowShip) -> Array:
	var out: Array = []
	if s._widow_mark == null or not is_instance_valid(s._widow_mark):
		return out
	for c in s._widow_mark.get_children():
		if c is Polygon2D:
			out.append(c)
	return out


## THE ONE THAT MATTERS RIGHT NOW: the lane hulls are art-less, so the mark has to
## come from the silhouette.
func _case_livery_on_a_silhouette_hull() -> void:
	var s := _raider(SampleBuilds.widow_goshawk())
	if s._hull_sprite != null:
		print("NOTE: Goshawk now has art — the silhouette path is covered by the Harrier case")
	var polys := _mark_polys(s)
	if polys.size() != 2:
		_fail("silhouette hull got %d hourglass polygons, want 2" % polys.size())
	for p in polys:
		if p.color != WidowShip.WIDOW_RED:
			_fail("hourglass is %s, not the widow red" % p.color)
		if p.polygon.size() != 3:
			_fail("hourglass half is not a triangle (%d points)" % p.polygon.size())
		# A zero-size mark is invisible, which is the whole bug class here.
		var lo: Vector2 = p.polygon[0]
		var hi: Vector2 = p.polygon[0]
		for pt in p.polygon:
			lo = lo.min(pt)
			hi = hi.max(pt)
		if hi.x - lo.x <= 0.0 or hi.y - lo.y <= 0.0:
			_fail("hourglass half has no area — it would not be visible")
	s.queue_free()


func _case_livery_on_an_art_hull() -> void:
	# The Sparrowhawk ships with real art, so this exercises the sprite branch.
	var s := _raider(SampleBuilds.pirate_brawler())
	if s._hull_sprite == null:
		print("NOTE: Sparrowhawk art missing — sprite branch not exercised")
		s.queue_free()
		return
	if _mark_polys(s).size() != 2:
		_fail("art hull got %d hourglass polygons, want 2" % _mark_polys(s).size())

	# THE MARK MUST SURVIVE THE TINT. `modulate` cascades to children and every
	# decal is a child of the hull sprite, so tinting through it multiplied the
	# hourglass by the hull black and rendered the faction's one point of red as
	# effectively BLACK. Assert what actually reaches the screen: the mark's own
	# colour times whatever the sprite multiplies its children by.
	var bleed: Color = s._hull_sprite.modulate
	for p in _mark_polys(s):
		var on_screen := Color(p.color.r * bleed.r, p.color.g * bleed.g, p.color.b * bleed.b)
		if on_screen.r < 0.5 or on_screen.r < on_screen.b * 3.0:
			_fail("the hourglass renders as %s, not red — the hull tint is bleeding into its decals" % on_screen)
	s.queue_free()


## The hull must be the faction's black, NOT a random rust-and-orange pirate skin.
func _case_no_random_pirate_skin() -> void:
	var s := _raider(SampleBuilds.widow_harrier())
	if s.use_variant_skin:
		_fail("Widows opted into the shared pirate skin pool — the livery cannot be uniform")
	var tint := _hull_tint(s)
	if tint != WidowShip.HULL_BLACK:
		_fail("hull tint is %s, not the widow black" % tint)
	# "Primarily black": whatever else happens, the hull must stay far darker than
	# the mark it carries, or there is no single point of red.
	var lum := tint.r * 0.3 + tint.g * 0.6 + tint.b * 0.1
	if lum > 0.3:
		_fail("hull luminance %.2f is not 'primarily black'" % lum)
	s.queue_free()


## Re-applying (a refit re-runs apply_build) must not stack a second hourglass on
## top of the first — that would slowly brighten the mark with every call.
func _case_mark_is_not_reapplied_twice() -> void:
	var s := _raider(SampleBuilds.widow_goshawk())
	s.apply_widow_mark()
	s.apply_widow_mark()
	var live := 0
	var host: Node = s._hull_sprite if s._hull_sprite != null else s._hull_visual
	for c in host.get_children():
		if c is Node2D and not (c is Polygon2D) and not c.is_queued_for_deletion():
			live += 1
	if live != 1:
		_fail("%d widow marks on the hull after re-applying, want 1" % live)
	s.queue_free()


## A SPECIALIST MUST STILL BE BLACK. AIShip._roll_specialty repaints the hull to
## advertise a mender/warden/binder, and it runs AFTER setup applies the faction
## tint — so ~13% of Widows used to spawn green, blue or amber. This surfaced by
## luck of the dice on one run, which is exactly why it is pinned here instead:
## the roll is DRIVEN until it fires rather than waited on.
func _case_a_specialist_is_still_black() -> void:
	var s := _raider(SampleBuilds.widow_goshawk())
	var rolled := false
	for _i in 500:
		s.specialty = AIShip.Specialty.NONE
		s._roll_specialty()
		if s.specialty != AIShip.Specialty.NONE:
			rolled = true
			break
	if not rolled:
		_fail("never rolled a specialist in 500 tries — this case proved nothing")
	else:
		var tint := _hull_tint(s)
		if tint != WidowShip.HULL_BLACK:
			_fail("a %s Widows is %s, not black — the specialist repaint escaped the livery" % [
				s.specialty_name(), tint])
	s.queue_free()


## ROLE IS A CAPABILITY YOU BUY (user, 2026-07-25). Reading a contact's role takes
## a sensor that publishes role_id_range — ADVANCED grade, level 10+ — and it is a
## RANGE, so a distant contact stays an unknown quantity. Asserted through a real
## TestShip because the gate has to hold where it is actually consulted.
func _case_role_is_sensor_data_not_paint() -> void:
	var mark := _raider(SampleBuilds.widow_goshawk())
	mark.specialty = AIShip.Specialty.MENDER
	mark.global_position = Vector2(400.0, 0.0)

	var pilot := TestShip.new()
	add_child(pilot)
	pilot.apply_build(SampleBuilds.get_build(3))   # Rooster: stock Wayfarer sensors
	pilot.global_position = Vector2.ZERO
	if pilot.classify(mark) != "":
		_fail("a stock sensor identified a role — the capability must be bought, not free")

	# Fit the Augur array: same contact, now legible.
	#
	# `get_build` returns the SHARED CACHED build on purpose (a refit has to persist
	# across ship swaps and deaths), so mutating its slots here permanently upgrades
	# the starter for every case that runs after this one. That went unnoticed until
	# a later case asserted the starter's sensor reach and was told 2400. Put it back
	# when we are done.
	var augur := SampleBuilds.get_build(3)
	var was_slot5 = augur.slots.get(5)
	augur.slots[5] = load("res://data/components/systems/augur_sensor_array.tres")
	pilot.apply_build(augur)
	if float(pilot.stats.get("role_id_range", 0.0)) <= 0.0:
		_fail("the Augur array published no role_id_range — the stat never reached ShipStats")
	elif pilot.classify(mark) != "Mender":
		_fail("the Augur array could not identify a Mender at 400u, got '%s'" % pilot.classify(mark))

	# Out past its reach it goes back to unknown — silence, not "ordinary".
	mark.global_position = Vector2(9000.0, 0.0)
	if pilot.classify(mark) != "":
		_fail("role was identified far beyond role_id_range — the range gate does nothing")

	# An ordinary ship never reports a role, however good the sensors.
	var plain := _raider(SampleBuilds.widow_harrier())
	plain.specialty = AIShip.Specialty.NONE
	plain.global_position = Vector2(300.0, 0.0)
	if pilot.classify(plain) != "":
		_fail("a non-specialist reported a role")

	# RESTORE THE SHARED BUILD — see above.
	if was_slot5 == null:
		augur.slots.erase(5)
	else:
		augur.slots[5] = was_slot5

	mark.queue_free()
	plain.queue_free()
	pilot.queue_free()


## A LANE PREDATOR OUT-SEES ITS PREY (user playtest, 2026-07-26: flew the whole
## route to the Navy picket and met no raider at all).
##
## AIShip caps acquisition at AGGRO_RANGE 950 — right for the INNER SYSTEM, where it
## stops pirates dogpiling a new pilot near the station. The Long Lane is 91,000
## units. A 950u radius on a road that long makes an interception statistically
## almost impossible, and a probe confirmed four raiders sitting in the exact stretch
## the player crossed. Meanwhile the white-tier starter carries a Tin-Ear (700u), so
## neither side could see the other: two ships with sub-kilometre awareness passing
## in the dark, one of them painted black.
##
## The fix stays INSIDE the pillar — never grant what a ship has not equipped. The
## reach is not a bigger constant; it is the raider's own suite, and upgrading that
## suite is what buys it.
func _case_a_lane_predator_out_sees_its_prey() -> void:
	var raider := _raider(SampleBuilds.widow_goshawk())
	var elite := _raider(SampleBuilds.widow_goshawk_elite())

	if raider.acquire_range() <= AIShip.AGGRO_RANGE:
		_fail("a lane raider acquires at %.0f, no better than the inner-system cap %.0f — nothing changed on the lane" % [
			raider.acquire_range(), AIShip.AGGRO_RANGE])

	# It must also out-see the PLAYER's starter, or the predator is the one being
	# surprised. Being found first, by something black, IS the Gap.
	var pilot := TestShip.new()
	add_child(pilot)
	pilot.apply_build(SampleBuilds.get_build(3))
	var mine := pilot.sensor_reach(0.0)
	if raider.acquire_range() <= mine:
		_fail("the raider sees %.0f and the starter sees %.0f — the hunter must find you before you find it" % [
			raider.acquire_range(), mine])
	if elite.acquire_range() <= raider.acquire_range():
		_fail("Recluse's Augur (%.0f) should reach past the rank and file (%.0f)" % [
			elite.acquire_range(), raider.acquire_range()])

	# THE PILLAR HOLDS: strip the suite and the reach goes with it, or this is a free
	# grant wearing a sensor's clothes.
	var blind := _raider(SampleBuilds.widow_goshawk())
	blind.stats["sensor_range"] = 0.0
	if blind.acquire_range() > 0.0:
		_fail("a raider with no suite still acquires at %.0f — the reach must be EQUIPPED, not given" % blind.acquire_range())

	raider.queue_free()
	elite.queue_free()
	blind.queue_free()
	pilot.queue_free()
