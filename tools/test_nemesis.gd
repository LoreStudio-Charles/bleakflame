extends Node
## THE GRUDGE and THE RAIDER'S DOCTRINE.
##   godot --headless --path . res://tools/test_nemesis.tscn
##
## Both models are dependency-free of SaveGame and UI (Nemesis holds neither,
## rank_prey is pure and static), so nothing here needs a world standing up.
##
## RUN AS A SCENE ANYWAY: reaching rank_prey means preloading widow_ship.gd,
## which pulls in AIShip -> Sfx, and under --script there are no autoloads. The
## first attempt did exactly that and Godot printed "ALL PASS" from a stale
## cached script while the real one failed to compile -- a green that proved
## nothing, which is the worst possible failure for a test.
##
## The doctrine cases below are the USER'S RULES, one assertion each:
##   "Larger cargo is top priority"
##   "prefer cargo ships away from the navy presence"
##   "If there's no cargo ships then he takes what is there"
##   "Players in a Mule are in danger if they're the only cargo ship"
##   "Anyone is in danger if they are alone in the lane"

const VS := preload("res://scenes/flight/widow_ship.gd")

var _fails := 0


func _ready() -> void:
	_case_a_grudge_opens_and_closes()
	_case_repeat_deaths_deepen_it()
	_case_only_a_real_debt_can_be_avenged()
	_case_a_grudge_survives_a_save()
	_case_bigger_cargo_wins()
	_case_navy_presence_poisons_a_mark()
	_case_alone_is_dangerous_for_anyone()
	_case_a_lone_mule_outranks_a_lone_fighter()

	print("test_nemesis: %s" % ("ALL PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _fail(msg: String) -> void:
	print("FAIL: " + msg)
	_fails += 1


func _case_a_grudge_opens_and_closes() -> void:
	Nemesis.reset()
	if not Nemesis.active().is_empty():
		_fail("a fresh pilot already holds a grudge")
	Nemesis.record_defeat("Recluse", "Recluse", 25, 4)
	if not Nemesis.has_grudge("Recluse"):
		_fail("dying to Recluse opened no grudge")
	if Nemesis.active().size() != 1:
		_fail("expected exactly one open grudge, got %d" % Nemesis.active().size())
	if not Nemesis.avenge("Recluse", 30):
		_fail("killing Recluse did not settle the debt")
	if Nemesis.has_grudge("Recluse"):
		_fail("the grudge is still open after being avenged")
	if not Nemesis.active().is_empty():
		_fail("an avenged grudge still shows as active")


func _case_repeat_deaths_deepen_it() -> void:
	Nemesis.reset()
	Nemesis.record_defeat("Recluse", "Recluse", 25, 4)
	Nemesis.record_defeat("Recluse", "Recluse", 25, 9)
	var g: Dictionary = Nemesis.active()[0]
	if int(g.deaths) != 2:
		_fail("two deaths to one hunter counted as %d" % int(g.deaths))
	if Nemesis.defeat_line("Recluse") == Nemesis.defeat_line("Nobody"):
		_fail("a second death reads identically to a first")
	# A kill AFTER it was settled re-opens the debt: it came back.
	Nemesis.avenge("Recluse", 30)
	Nemesis.record_defeat("Recluse", "Recluse", 25, 44)
	if not Nemesis.has_grudge("Recluse"):
		_fail("a hunter that came back and killed again is still marked settled")


## Shooting a hunter that never touched you is not revenge, and the game must not
## stage a ceremony for it.
func _case_only_a_real_debt_can_be_avenged() -> void:
	Nemesis.reset()
	if Nemesis.avenge("Recluse", 12):
		_fail("avenged a hunter that had never killed anyone")
	Nemesis.record_defeat("Recluse", "Recluse", 25, 4)
	Nemesis.avenge("Recluse", 12)
	if Nemesis.avenge("Recluse", 13):
		_fail("the same grudge was avenged twice")


func _case_a_grudge_survives_a_save() -> void:
	Nemesis.reset()
	Nemesis.record_defeat("Recluse", "Recluse", 25, 4)
	Nemesis.record_defeat("Recluse", "Recluse", 25, 7)
	var saved := Nemesis.to_dict()
	Nemesis.reset()
	Nemesis.from_dict(saved)
	if not Nemesis.has_grudge("Recluse"):
		_fail("the grudge did not survive a save round-trip")
	elif int(Nemesis.active()[0].deaths) != 2:
		_fail("the death count did not survive a save round-trip")
	# Junk in the save must not crash or invent a grudge.
	Nemesis.reset()
	Nemesis.from_dict({})
	Nemesis.from_dict({"grudges": {"Ghost": {}}})
	if not Nemesis.has_grudge("Ghost"):
		_fail("a sparse saved grudge was dropped entirely")


# ---- THE DOCTRINE ----

func _case_bigger_cargo_wins() -> void:
	var bellwether := VS.rank_prey(480.0, 0, INF, 3000.0)
	var dray := VS.rank_prey(200.0, 0, INF, 3000.0)
	var mule := VS.rank_prey(80.0, 0, INF, 3000.0)
	if not (bellwether > dray and dray > mule):
		_fail("cargo is not the priority: bellwether %.0f, dray %.0f, mule %.0f" % [
			bellwether, dray, mule])
	# A SCREEN IS A DETERRENT, NEVER A VETO -- a fat enough hauler is still worth
	# it, which is what makes the convoy set-piece happen at all.
	if VS.rank_prey(480.0, 3, INF, 3000.0) <= VS.rank_prey(80.0, 0, INF, 3000.0):
		_fail("an escorted Bellwether is not worth more than a lone Mule — the convoy would never be attacked")


func _case_navy_presence_poisons_a_mark() -> void:
	var far := VS.rank_prey(200.0, 0, 40000.0, 3000.0)
	var near := VS.rank_prey(200.0, 0, 500.0, 3000.0)
	if near >= far:
		_fail("sitting next to the Navy did not make a mark less appealing (%.0f vs %.0f)" % [
			near, far])
	# And it outweighs cargo: a fat hauler under the Navy's guns is a worse bet
	# than a modest one out in the open.
	if VS.rank_prey(480.0, 0, 0.0, 3000.0) >= VS.rank_prey(120.0, 0, 40000.0, 3000.0):
		_fail("a Bellwether inside the Navy's reach still outranks a Mule in open road")


func _case_alone_is_dangerous_for_anyone() -> void:
	var lone_fighter := VS.rank_prey(6.0, 0, INF, 3000.0)
	var escorted_fighter := VS.rank_prey(6.0, 2, INF, 3000.0)
	if lone_fighter <= escorted_fighter:
		_fail("being alone did not make a ship a better mark")
	# "If there's no cargo ships then he takes what is there" -- a cargo-less mark
	# must still score above nothing, or Recluse would ignore an empty lane.
	if lone_fighter <= 0.0:
		_fail("a lone cargo-less ship scores %.0f — Recluse would never engage it" % lone_fighter)


func _case_a_lone_mule_outranks_a_lone_fighter() -> void:
	var mule := VS.rank_prey(80.0, 0, INF, 3000.0)
	var fighter := VS.rank_prey(6.0, 0, INF, 3000.0)
	if mule <= fighter:
		_fail("a lone Mule (%.0f) is not preferred over a lone fighter (%.0f)" % [mule, fighter])
