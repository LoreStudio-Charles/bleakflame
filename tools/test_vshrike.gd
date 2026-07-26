extends Node
## THE V-SHRIKE LIVERY — black hull, one red hourglass (user, 2026-07-25).
##   godot --headless --path . res://tools/test_vshrike.tscn
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

	print("test_vshrike: %s" % ("ALL PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _fail(msg: String) -> void:
	print("FAIL: " + msg)
	_fails += 1


func _raider(build: ShipBuild) -> VShrikeShip:
	var s := VShrikeShip.new()
	add_child(s)
	s.setup_vshrike(build)
	return s


## Every polygon under the mark, whatever it is parented to.
func _mark_polys(s: VShrikeShip) -> Array:
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
	var s := _raider(SampleBuilds.vshrike_goshawk())
	if s._hull_sprite != null:
		print("NOTE: Goshawk now has art — the silhouette path is covered by the Harrier case")
	var polys := _mark_polys(s)
	if polys.size() != 2:
		_fail("silhouette hull got %d hourglass polygons, want 2" % polys.size())
	for p in polys:
		if p.color != VShrikeShip.WIDOW_RED:
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
	elif _mark_polys(s).size() != 2:
		_fail("art hull got %d hourglass polygons, want 2" % _mark_polys(s).size())
	s.queue_free()


## The hull must be the faction's black, NOT a random rust-and-orange pirate skin.
func _case_no_random_pirate_skin() -> void:
	var s := _raider(SampleBuilds.vshrike_harrier())
	if s.use_variant_skin:
		_fail("V-Shrike opted into the shared pirate skin pool — the livery cannot be uniform")
	var tint: Color = s._hull_sprite.modulate if s._hull_sprite != null else s._hull_visual.color
	if tint != VShrikeShip.HULL_BLACK:
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
	var s := _raider(SampleBuilds.vshrike_goshawk())
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
## tint — so ~13% of V-Shrike used to spawn green, blue or amber. This surfaced by
## luck of the dice on one run, which is exactly why it is pinned here instead:
## the roll is DRIVEN until it fires rather than waited on.
func _case_a_specialist_is_still_black() -> void:
	var s := _raider(SampleBuilds.vshrike_goshawk())
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
		var tint: Color = s._hull_sprite.modulate if s._hull_sprite != null else s._hull_visual.color
		if tint != VShrikeShip.HULL_BLACK:
			_fail("a %s V-Shrike is %s, not black — the specialist repaint escaped the livery" % [
				s.specialty_name(), tint])
	s.queue_free()


## ROLE IS A CAPABILITY YOU BUY (user, 2026-07-25). Reading a contact's role takes
## a sensor that publishes role_id_range — ADVANCED grade, level 10+ — and it is a
## RANGE, so a distant contact stays an unknown quantity. Asserted through a real
## TestShip because the gate has to hold where it is actually consulted.
func _case_role_is_sensor_data_not_paint() -> void:
	var mark := _raider(SampleBuilds.vshrike_goshawk())
	mark.specialty = AIShip.Specialty.MENDER
	mark.global_position = Vector2(400.0, 0.0)

	var pilot := TestShip.new()
	add_child(pilot)
	pilot.apply_build(SampleBuilds.get_build(3))   # Rooster: stock Wayfarer sensors
	pilot.global_position = Vector2.ZERO
	if pilot.classify(mark) != "":
		_fail("a stock sensor identified a role — the capability must be bought, not free")

	# Fit the Augur array: same contact, now legible.
	var augur := SampleBuilds.get_build(3)
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
	var plain := _raider(SampleBuilds.vshrike_harrier())
	plain.specialty = AIShip.Specialty.NONE
	plain.global_position = Vector2(300.0, 0.0)
	if pilot.classify(plain) != "":
		_fail("a non-specialist reported a role")

	mark.queue_free()
	plain.queue_free()
	pilot.queue_free()
