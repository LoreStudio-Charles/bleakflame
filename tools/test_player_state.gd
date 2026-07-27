extends Node
## PLAYER STATE — the container that makes a second pilot representable.
##
## The whole game's player state used to live in ~97 `static var`s, which encode
## exactly one claim: there is one pilot, forever. This suite asserts the claim is
## gone — that two PlayerStates hold genuinely separate money and storage, and that
## the old module names still reach whichever one is `local`.
##
## THE FACADE IS THE POINT. Wallet/Stash keep their API so ~137 existing call sites
## did not have to change; if the forwarding silently broke, every one of them would
## quietly read a stale copy instead of the live pilot. So this drives the FACADES,
## not the container — testing PlayerState directly would prove nothing about the
## 137 readers.
##
## RUN AS A SCENE (autoloads):
##   <godot> --headless --path . res://tools/test_player_state.tscn
## Never writes the save.

var _fails: Array[String] = []
var _checks := 0


func _ready() -> void:
	var was := PlayerState.local

	_case_the_facade_reaches_the_container()
	_case_two_pilots_do_not_share_a_wallet()
	_case_two_pilots_do_not_share_a_stash()
	_case_collections_are_live_not_copies()
	_case_two_pilots_are_different_people()
	_case_two_pilots_own_different_ships()
	_case_two_pilots_stand_apart()
	_case_a_wipe_clears_only_that_pilot()
	_case_two_pilots_run_their_own_campaign()
	_case_two_pilots_keep_their_own_catalogue()
	_case_two_pilots_are_taught_separately()
	_case_the_engine_tables_are_still_shared()
	_case_two_pilots_explore_separately()
	_case_wipe_cannot_drift()

	PlayerState.local = was
	if _fails.is_empty():
		print("test_player_state: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_player_state: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


## The old names must still work, or 137 call sites are lying.
func _case_the_facade_reaches_the_container() -> void:
	PlayerState.local = PlayerState.new()
	Wallet.credits = 500
	_ok(PlayerState.local.credits == 500, "Wallet.credits writes THROUGH to the pilot")
	PlayerState.local.credits = 900
	_ok(Wallet.credits == 900, "...and reads back from it")
	Wallet.credits += 100            # the compound-assign idiom used all over
	_ok(Wallet.credits == 1000, "read-modify-write through the facade still works")


## THE ONE THAT MATTERS. Before the container this was not expressible: there was
## one `static var credits` and two pilots would have spent the same money.
func _case_two_pilots_do_not_share_a_wallet() -> void:
	var alice := PlayerState.new()
	var bob := PlayerState.new()

	PlayerState.local = alice
	Wallet.credits = 250
	Wallet.xp = 40

	PlayerState.local = bob
	Wallet.credits = 999
	Wallet.xp = 7

	_ok(alice.credits == 250 and alice.xp == 40, "the first pilot kept their own money and XP")
	_ok(bob.credits == 999 and bob.xp == 7, "the second pilot has their own")

	PlayerState.local = alice
	_ok(Wallet.credits == 250, "switching back reads the first pilot again (got %d)" % Wallet.credits)


func _case_two_pilots_do_not_share_a_stash() -> void:
	var alice := PlayerState.new()
	var bob := PlayerState.new()
	var part: ComponentDef = load("res://data/components/weapons/vk2_autocannon.tres")

	PlayerState.local = alice
	Stash.items.append(part)
	Stash.store_commodity("aurite_ore", 12)

	PlayerState.local = bob
	_ok(Stash.items.is_empty(), "a second pilot's stash starts EMPTY, not shared")
	_ok(int(Stash.commodities.get("aurite_ore", 0)) == 0, "...and holds none of their ore")
	Stash.store_commodity("aurite_ore", 3)

	_ok(int(alice.stash_commodities.get("aurite_ore", 0)) == 12,
		"the first pilot's ore is untouched by the second's")
	_ok(int(bob.stash_commodities.get("aurite_ore", 0)) == 3, "each keeps their own count")
	_ok(alice.stash_items.size() == 1 and bob.stash_items.is_empty(),
		"and their component storage is separate")


## The getters hand back the pilot's OWN array, not a copy — every existing call
## site mutates in place (`Stash.items.append`, `.assign`, `.clear`), so a getter
## that copied would swallow all of it silently.
func _case_collections_are_live_not_copies() -> void:
	var pilot := PlayerState.new()
	PlayerState.local = pilot
	Stash.items.clear()
	Stash.items.append(load("res://data/components/weapons/vk2_autocannon.tres"))
	_ok(pilot.stash_items.size() == 1, "append through the facade reaches the pilot's array")
	Stash.commodities["ferrite_ore"] = 5
	_ok(int(pilot.stash_commodities.get("ferrite_ore", 0)) == 5,
		"dictionary writes land on the pilot, not on a throwaway copy")
	# take_commodity is a facade STATIC operating on that same dictionary.
	_ok(Stash.take_commodity("ferrite_ore", 2) == 2, "the helper statics still work")
	_ok(int(pilot.stash_commodities.get("ferrite_ore", 0)) == 3, "...and write to the right pilot")


func _case_a_wipe_clears_only_that_pilot() -> void:
	var keep := PlayerState.new()
	var scrub := PlayerState.new()
	keep.credits = 777
	keep.stash_commodities["aurite_ore"] = 4
	scrub.credits = 100
	scrub.stash_commodities["aurite_ore"] = 9

	scrub.wipe()
	_ok(scrub.credits == 0 and scrub.stash_commodities.is_empty(), "wipe() empties its own pilot")
	_ok(keep.credits == 777 and int(keep.stash_commodities.get("aurite_ore", 0)) == 4,
		"...and leaves every other pilot alone")


## IDENTITY, COMMISSION AND LOADOUT. In coop these are the things that make two
## pilots two people rather than one pilot rendered twice.
func _case_two_pilots_are_different_people() -> void:
	var alice := PlayerState.new()
	var bob := PlayerState.new()

	PlayerState.local = alice
	Pilot.callsign = "Wingfeather"
	Pilot.profession = "guardian"
	Pilot.skills["evasion"] = 2
	Pilot.gems[0] = "scan"
	Pilot.met.append("ruel")

	PlayerState.local = bob
	_ok(Pilot.callsign == "", "a second pilot has their own name, not the first's")
	_ok(Pilot.profession == "", "...their own commission")
	_ok(Pilot.skills.is_empty(), "...their own skills")
	_ok(Pilot.gems[0] == "", "...their own wired abilities")
	_ok(Pilot.met.is_empty(), "...and has met nobody yet")

	Pilot.callsign = "Tallow"
	Pilot.profession = "miner"
	PlayerState.local = alice
	_ok(Pilot.callsign == "Wingfeather" and Pilot.profession == "guardian",
		"the first pilot is unchanged by the second's choices")


## SHIP OWNERSHIP. `owned` and the cached refits were global, so in coop every
## pilot would have flown the same hull and shared one loadout.
func _case_two_pilots_own_different_ships() -> void:
	var alice := PlayerState.new()
	var bob := PlayerState.new()

	PlayerState.local = alice
	SampleBuilds.owned.append(5)      # she bought the Dowager
	SampleBuilds.current = 5

	PlayerState.local = bob
	_ok(not SampleBuilds.owned.has(5), "a second pilot does not own the first's ship")
	_ok(SampleBuilds.current == 3, "...and is still aboard the starter (got %d)"
		% SampleBuilds.current)

	PlayerState.local = alice
	_ok(SampleBuilds.current == 5 and SampleBuilds.owned.has(5),
		"the first pilot still owns and flies hers")


## STANDING, INBOX AND CONTRACTS. Reputation is earned by a PERSON — shared
## standing would mean one pilot's massacre burns their whole party's docking
## rights, and one pilot's contract would tick down on someone else's kills.
func _case_two_pilots_stand_apart() -> void:
	var alice := PlayerState.new()
	var bob := PlayerState.new()

	PlayerState.local = alice
	Standing.add("guardian", 30)
	Comms.post("ruel", "Docking Control", "Mind the arm.")
	MissionLog.active.append({"type": "bounty", "n": 3, "desc": "test", "reward": 50})
	MissionLog.total_kills = 12

	PlayerState.local = bob
	_ok(Standing.get_points("guardian") == 0,
		"a second pilot has their OWN standing (got %d)" % Standing.get_points("guardian"))
	_ok(Comms.messages.is_empty(), "...their own comms inbox")
	_ok(MissionLog.active.is_empty(), "...and holds none of the first's contracts")
	_ok(MissionLog.total_kills == 0, "...with their own bounty baseline")

	Standing.add("guardian", -5)
	PlayerState.local = alice
	_ok(Standing.get_points("guardian") == 30,
		"the first pilot's reputation is untouched by the second's (got %d)"
			% Standing.get_points("guardian"))
	_ok(Comms.messages.size() == 1, "...and still has their own mail")
	_ok(MissionLog.active.size() == 1 and MissionLog.total_kills == 12,
		"...and their own contract and kill count")


## THE CAMPAIGN IS PER PILOT — the data foundation the flag rule was waiting on.
##
## "Presence, then order" (docs/multiplayer_readiness.md) cannot even be ASKED while there
## is one global `Quests.active`: helping a friend with a later beat must not grant it to
## you out of sequence, and that comparison needs your own chain to compare against. This
## does not implement the rule — presence needs the net layer — it proves the state it will
## be written against exists.
func _case_two_pilots_run_their_own_campaign() -> void:
	var ahead := PlayerState.new()
	var behind := PlayerState.new()

	PlayerState.local = ahead
	Quests.active["legend_who_is_asking"] = {"stage": 1, "count": 0}
	Quests.completed.append("prove_wings")
	Quests.completed_day["prove_wings"] = 4

	PlayerState.local = behind
	_ok(Quests.active.is_empty(),
		"a second pilot has not started the first's beat (%d active)" % Quests.active.size())
	_ok(Quests.completed.is_empty(), "...and has completed none of their quests")
	_ok(Quests.completed_day.is_empty(), "...and shares none of their timestamps")

	# The one ahead is untouched by the one behind — the direction that would silently
	# ERASE somebody's campaign if these were still shared.
	Quests.completed.append("overdue")
	PlayerState.local = ahead
	_ok(Quests.completed.size() == 1 and Quests.completed[0] == "prove_wings",
		"...and the first pilot's campaign is not rewritten by the second's")
	_ok(Quests.active.has("legend_who_is_asking"), "...still standing mid-beat where they were")


## SCAN DATA IS KNOWLEDGE (user, 2026-07-27), and knowledge is personal. A subject is
## catalogued once PER PILOT: your friend having filed a Goshawk must not spend your
## first-scan payout, and it must not deny you the discovery either.
func _case_two_pilots_keep_their_own_catalogue() -> void:
	var scholar := PlayerState.new()
	var rookie := PlayerState.new()

	PlayerState.local = scholar
	Research.catalogued["hull:res://data/hulls/goshawk.tres"] = true
	Research.insight = 40.0
	Research.journal.append({"day": 3, "text": "Filed a Goshawk."})

	PlayerState.local = rookie
	_ok(Research.catalogued.is_empty(), "a second pilot's catalogue starts empty")
	_ok(is_equal_approx(Research.insight, 0.0), "...with none of the first's Insight")
	_ok(Research.journal.is_empty(), "...and a blank captain's log")

	Research.insight += 15.0
	PlayerState.local = scholar
	_ok(is_equal_approx(Research.insight, 40.0),
		"...and earning it does not touch the first pilot's (got %.1f)" % Research.insight)
	_ok(Research.journal.size() == 1, "...nor write into their log")


## ONBOARDING IS PERSONAL. The coop case that makes this matter: a friend joining a
## veteran's session must still be taught to fly, and the veteran must not have the
## beginner's lessons re-armed at them. One shared queue cannot express either.
func _case_two_pilots_are_taught_separately() -> void:
	var veteran := PlayerState.new()
	var newcomer := PlayerState.new()

	PlayerState.local = veteran
	Tutor.seen.append("flight_training")
	Tutor.seen.append("memorize")
	Tutor.active = "running_dark"
	Tutor.step = 2
	Tutor.safe = false
	Tutor.context = "flight"

	PlayerState.local = newcomer
	_ok(Tutor.seen.is_empty(), "a newcomer has been taught nothing yet")
	_ok(Tutor.active == "", "...and is not mid-lesson in somebody else's tutorial")
	_ok(Tutor.step == 0, "...at step zero")
	# `safe` is the field whose cross-context staleness once starved the entire queue.
	# Two pilots plainly disagree about whether they are being shot at.
	_ok(Tutor.safe, "...and is safe until their OWN situation says otherwise")
	_ok(Tutor.context == "dock", "...with their own context")

	Tutor.seen.append("docking")
	PlayerState.local = veteran
	_ok(Tutor.seen.size() == 2 and not Tutor.seen.has("docking"),
		"...and what the newcomer learns is not written into the veteran's record")
	_ok(Tutor.active == "running_dark" and Tutor.step == 2,
		"...who is still exactly where they were")
	_ok(not Tutor.safe, "...and still in trouble")


## THE OTHER DIRECTION, which is the one that gets forgotten: over-migrating is a bug too.
## The predicate registry and the anchor map are ENGINE tables — authored once, identical
## for everyone. Per-pilot copies would mean a lesson that arms for one player and not the
## other, and the stall log is the game's own bug list across every playtester, so scoping
## it to a pilot would quietly throw it away on New Game.
func _case_the_engine_tables_are_still_shared() -> void:
	var a := PlayerState.new()
	var b := PlayerState.new()

	PlayerState.local = a
	Tutor._build_preds()
	var arm_count := Tutor._arm_pred.size()
	Tutor.record_stall("some_lesson", 0, "test")
	var stall_count := Tutor.stalls.size()
	_ok(arm_count > 0, "the predicate registry is populated (%d)" % arm_count)

	PlayerState.local = b
	_ok(Tutor._arm_pred.size() == arm_count,
		"the predicate registry is SHARED, not copied per pilot (%d vs %d)"
			% [Tutor._arm_pred.size(), arm_count])
	_ok(Tutor.stalls.size() == stall_count,
		"the stall log is shared — it is the game's bug list, not a pilot's")


## THE FOG IS PERSONAL. "You have not found the Rust Shoal yet, your friend has" is the
## whole point of discovery; the POI list itself stays world state.
func _case_two_pilots_explore_separately() -> void:
	var scout := PlayerState.new()
	var greenhorn := PlayerState.new()

	PlayerState.local = scout
	PoiMap.discover("shoal")
	PoiMap.set_waypoint("shoal", true)
	_ok(PoiMap.is_discovered("shoal"), "the scout has found the Shoal")

	PlayerState.local = greenhorn
	_ok(not PoiMap.is_discovered("shoal"), "...and the greenhorn has not")
	_ok(PoiMap.waypoint_id == "", "...and has no marker on their chart")
	_ok(not PoiMap.waypoint_manual, "...nor inherits a manual tag they never made")

	PlayerState.local = scout
	_ok(PoiMap.waypoint_id == "shoal", "the scout's own marker is untouched")
	_ok(PoiMap.waypoint_manual, "...and is still theirs to override the tracker with")


## THE DRIFT GUARD. wipe() resets from a fresh instance rather than a hand-written
## field list, so adding a field cannot leave a stale value alive across New Game —
## the shape of the Nemesis/Pilot.met leak fixed on 2026-07-26. This asserts the
## property actually holds for EVERY declared field, not just the ones I remembered.
func _case_wipe_cannot_drift() -> void:
	var fresh := PlayerState.new()
	var dirty := PlayerState.new()
	var touched := 0
	var total := 0
	var skipped: Array[String] = []
	for prop in fresh.get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		total += 1
		var clean = fresh.get(prop.name)
		# Dirty every field with something that is definitely not its default.
		match typeof(clean):
			TYPE_INT: dirty.set(prop.name, 4242)
			TYPE_FLOAT: dirty.set(prop.name, 42.5)
			TYPE_BOOL: dirty.set(prop.name, not bool(clean))
			TYPE_STRING: dirty.set(prop.name, "dirty")
			TYPE_DICTIONARY: dirty.set(prop.name, {"dirty": 1})
			TYPE_ARRAY:
				var soiled := _dirty_array(clean)
				if soiled.size() == (clean as Array).size():
					skipped.append("%s (Array of an unhandled type)" % str(prop.name))
					continue
				dirty.set(prop.name, soiled)
			_:
				skipped.append("%s (%s)" % [str(prop.name), type_string(typeof(clean))])
				continue
		touched += 1
	# EVERY FIELD, OR NAME THE ONES YOU COULD NOT REACH. This used to be `touched > 10`
	# with typed arrays falling through a bare `continue` — so a dozen Array[String] and
	# Array[Dictionary] fields were never dirtied at all, and the "wipe clears everything"
	# assertion below passed VACUOUSLY for every one of them. A guard that silently skips a
	# whole category of field is the shape it was written to prevent.
	_ok(skipped.is_empty(), "every field type can be dirtied — unreachable: %s" % str(skipped))
	_ok(touched == total, "the guard dirtied all %d declared fields (reached %d)"
		% [total, touched])

	dirty.wipe()
	var stale: Array[String] = []
	for prop in fresh.get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if str(dirty.get(prop.name)) != str(fresh.get(prop.name)):
			stale.append(str(prop.name))
	_ok(stale.is_empty(), "wipe() clears EVERY declared field — stale: %s" % str(stale))


## A non-empty array that a TYPED array field will actually accept. `Array[String]` refuses
## a Dictionary and vice versa, so the element is chosen from the destination's own element
## type — which is why this cannot just append a string and hope.
## A non-empty array that a TYPED array field will actually accept. `Array[String]` refuses
## a Dictionary and vice versa, so the element comes from the destination's own element
## type — this cannot just append a string and hope.
##
## RETURNS THE ARRAY UNCHANGED when it cannot synthesise an element, and the caller detects
## that and NAMES the field. The first version appended "dirty" to anything it did not
## recognise; Godot rejected the push_back, printed an engine error, left the array equal to
## fresh — and the suite still said ALL PASS, because "wipe cleared it" is trivially true
## for a field that was never dirtied. Exactly the vacuum this whole case exists to prevent.
func _dirty_array(clean) -> Array:
	var src := clean as Array
	var out: Array = src.duplicate()
	match src.get_typed_builtin():
		TYPE_NIL: out.append("dirty")        # untyped Array takes anything
		TYPE_STRING: out.append("dirty")
		TYPE_DICTIONARY: out.append({"dirty": 1})
		TYPE_INT: out.append(4242)
		TYPE_FLOAT: out.append(42.5)
		TYPE_OBJECT: out.append(null)   # Array[ComponentDef] and friends accept a null slot
	return out


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)
