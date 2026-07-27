extends Node
## THE RELATIONSHIP MATRIX — before any of it is wired to a trigger.
##
## Stage 1 of replacing player_team/hostile_team. Nothing shoots differently yet; this
## proves the matrix says what the world's fiction says, so that when targeting is switched
## over there is one thing to blame instead of two.
##
##   <godot> --headless --path . res://tools/test_factions.tscn --quit-after 300

var _fails: Array[String] = []
var _checks := 0


func _ready() -> void:
	_case_vshrike_hate_everyone()
	_case_civilians_hate_nobody()
	_case_hatred_is_not_automatically_mutual()
	_case_the_lane_reads_correctly()
	_case_a_pilot_is_a_faction()
	_case_no_row_names_a_faction_that_does_not_exist()

	if _fails.is_empty():
		print("test_factions: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_factions: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


## THE LINE THAT MOTIVATED THE WHOLE CHANGE (user): "V-Shrike faction should just hate
## everyone." Under two teams this was unrepresentable — raiders and pirates shared
## hostile_team, so the Long Lane's own fiction could not be built.
func _case_vshrike_hate_everyone() -> void:
	for other in Factions.LIST:
		if str(other) == "vshrike":
			continue
		_ok(Factions.hostile("vshrike", str(other)),
			"V-Shrike are hostile to %s" % other)
	# Including the thing two teams specifically could not express.
	_ok(Factions.hostile("vshrike", "shoal"),
		"...INCLUDING Shoal pirates — the case two teams could not hold")
	_ok(not Factions.hostile("vshrike", "vshrike"), "...but not each other")


func _case_civilians_hate_nobody() -> void:
	for other in Factions.LIST:
		_ok(not Factions.hostile("civilian", str(other)),
			"civilians are hostile to nobody (%s)" % other)
	# They are still PREY, which is the asymmetry the lane rests on.
	_ok(Factions.hostile("shoal", "civilian"), "...but pirates hunt them")
	_ok(Factions.hostile("vshrike", "civilian"), "...and so do the V-Shrike")


## Asymmetry is the feature. A predator's appetite is not a mutual feud, and forcing
## symmetry would have made every hunter into a war.
func _case_hatred_is_not_automatically_mutual() -> void:
	_ok(Factions.hostile("vshrike", "civilian") and not Factions.hostile("civilian", "vshrike"),
		"a hauler does not declare war on the thing hunting it")
	_ok(Factions.hostile("guardian", "shoal") and Factions.hostile("shoal", "guardian"),
		"...while a real feud IS mutual, when it is authored that way")


func _case_the_lane_reads_correctly() -> void:
	_ok(Factions.allied("guardian", "navy"), "Guardians and the Navy are on the same side")
	_ok(Factions.allied("escort", "civilian"), "hired escorts protect the freight they ride with")
	_ok(Factions.hostile("escort", "shoal"), "...and fight what comes for it")
	_ok(not Factions.hostile("guardian", "civilian"), "the law does not shoot the freight")
	_ok(Factions.hostile("leviathan", "civilian") and Factions.hostile("leviathan", "guardian"),
		"a leviathan is everyone's problem")


## "Every player should be their own faction that begins with a starting relationship to
## every faction" (user). The pilot is not a special case in the lookup — they have a row
## like anyone else, and STANDING is that row.
func _case_a_pilot_is_a_faction() -> void:
	var me := Factions.player_id()
	_ok(Factions.is_player(me), "a pilot has a faction id of their own")
	_ok(me != Factions.player_id("second"), "...and two pilots are two factions")
	_ok(Factions.allied(me, me), "a pilot is not hostile to themselves")

	# The opening relationship: hostile to what hates everyone, at peace with the rest.
	_ok(Factions.hostile(me, "vshrike"), "a new pilot may shoot V-Shrike on sight")
	_ok(Factions.hostile("vshrike", me), "...and they will certainly shoot back")
	_ok(Factions.hostile(me, "leviathan"), "a leviathan is fair game without paperwork")
	_ok(not Factions.hostile(me, "civilian"), "a new pilot is NOT at war with haulers")
	_ok(not Factions.hostile(me, "guardian"), "...nor with the law")
	_ok(not Factions.hostile("guardian", me), "...and the law has no quarrel with them yet")

	# And it MOVES — the starting relationship is a start, not a fixture.
	var before := Factions.hostile("guardian", Factions.player_id())
	Standing.add("guardian", -999)
	_ok(not before and Factions.hostile("guardian", Factions.player_id()),
		"...until the pilot earns their enmity, and then it turns")
	Standing.add("guardian", 999)


## An authored table can name a faction that does not exist and nothing complains — the
## relationship simply never fires. That is the quietest possible failure, so it is checked.
func _case_no_row_names_a_faction_that_does_not_exist() -> void:
	var unknown: Array[String] = []
	for from in Factions.BASE:
		if not Factions.LIST.has(from):
			unknown.append(str(from))
		for to in Factions.BASE[from]:
			if str(to) != "*" and not Factions.LIST.has(to):
				unknown.append("%s -> %s" % [from, to])
	_ok(unknown.is_empty(), "every row and column names a real faction — unknown: %s"
		% str(unknown))


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)
