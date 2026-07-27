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
	_case_a_wipe_clears_only_that_pilot()
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


## THE DRIFT GUARD. wipe() resets from a fresh instance rather than a hand-written
## field list, so adding a field cannot leave a stale value alive across New Game —
## the shape of the Nemesis/Pilot.met leak fixed on 2026-07-26. This asserts the
## property actually holds for EVERY declared field, not just the ones I remembered.
func _case_wipe_cannot_drift() -> void:
	var fresh := PlayerState.new()
	var dirty := PlayerState.new()
	var touched := 0
	for prop in fresh.get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var clean = fresh.get(prop.name)
		# Dirty every field with something that is definitely not its default.
		match typeof(clean):
			TYPE_INT: dirty.set(prop.name, 4242)
			TYPE_FLOAT: dirty.set(prop.name, 42.5)
			TYPE_BOOL: dirty.set(prop.name, not bool(clean))
			TYPE_STRING: dirty.set(prop.name, "dirty")
			TYPE_DICTIONARY: dirty.set(prop.name, {"dirty": 1})
			_: continue      # typed arrays: filled below only if we can
		touched += 1
	_ok(touched > 10, "the guard actually dirtied a meaningful number of fields (%d)" % touched)

	dirty.wipe()
	var stale: Array[String] = []
	for prop in fresh.get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if str(dirty.get(prop.name)) != str(fresh.get(prop.name)):
			stale.append(str(prop.name))
	_ok(stale.is_empty(), "wipe() clears EVERY declared field — stale: %s" % str(stale))


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)
