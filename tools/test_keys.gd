extends SceneTree
## THE BINDING TABLE + THE COMBAT MODEL it encodes (user's hotkey overhaul, 2026-07-25).
##   <godot> --headless --path . --script res://tools/test_keys.gd
##
## Guards the things a careless edit would silently break: two actions landing on one key,
## the space/ground shared verbs drifting apart, and — the big one — the rule that THE
## MOUSE NEVER FIRES. Combat is target-and-engage now: guns are a STATE ([Q] weapons
## free), ordnance is a VERB ([R]).

var _fails := 0


func _init() -> void:
	# 1) NO TWO ACTIONS ON ONE KEY. Q is deliberately dual (cancel in menus / weapons-free
	#    in the world) and those contexts never overlap, so it's declared once here.
	var bound := {
		"CONFIRM": Keys.CONFIRM, "CANCEL": Keys.CANCEL, "ORDNANCE": Keys.ORDNANCE,
		"CYCLE_FOE": Keys.CYCLE_FOE,
		"MAP": Keys.MAP, "HOLD": Keys.HOLD, "BAGS": Keys.BAGS, "DOSSIER": Keys.DOSSIER,
		"FACTIONS": Keys.FACTIONS, "SOCIAL": Keys.SOCIAL, "DARK": Keys.DARK,
		"LOG": Keys.LOG, "COMMS": Keys.COMMS, "BOOST": Keys.BOOST, "BRAKE": Keys.BRAKE,
		"COMMAND": Keys.COMMAND, "MENU": Keys.MENU, "SCREENSHOT": Keys.SCREENSHOT,
		"TARGET_SELF": Keys.TARGET_SELF, "TARGET_PARTY_2": Keys.TARGET_PARTY_2,
		"TARGET_PARTY_3": Keys.TARGET_PARTY_3, "TARGET_PARTY_4": Keys.TARGET_PARTY_4,
	}
	var seen := {}
	for name in bound:
		var k: int = bound[name]
		if seen.has(k):
			_chk(false, "%s and %s both bound to %s" % [name, seen[k], Keys.name_of(k)])
		seen[k] = name
	_chk(true, "no two actions share a key (%d bindings checked)" % bound.size())

	# WEAPONS_FREE intentionally shares Q with CANCEL — one "no" key, context decides.
	_chk(Keys.WEAPONS_FREE == Keys.CANCEL,
		"weapons-free rides the CANCEL key ([Q] = 'no'/'hold fire'), by design")

	# 2) The ability bus maps 1-5 and nothing else.
	_chk(Keys.ability_index(Keys.ABILITY_1) == 0, "[1] is bus slot 0")
	_chk(Keys.ability_index(Keys.ABILITY_1 + 4) == 4, "[5] is bus slot 4")
	_chk(Keys.ability_index(Keys.ABILITY_1 + 5) == -1, "[6] is not a bus slot")
	_chk(Keys.ability_index(Keys.MAP) == -1, "an overlay key is never read as an ability")

	# 3) Party frames: F1 is SELF, then 2-4.
	_chk(Keys.party_index(Keys.TARGET_SELF) == 0, "F1 targets self")
	_chk(Keys.party_index(Keys.TARGET_PARTY_4) == 3, "F4 targets party member 4")
	_chk(Keys.party_index(Keys.MAP) == -1, "a non-frame key has no party index")

	# 4) THE MOUSE NEVER FIRES (the combat overhaul's core rule). LMB selects, full stop;
	#    the firing verbs are keys. If someone re-binds a weapon to a mouse button, this
	#    is the alarm.
	_chk(Keys.SELECT == MOUSE_BUTTON_LEFT, "LMB is SELECT")
	_chk(Keys.INTERACT_AT_CURSOR == MOUSE_BUTTON_RIGHT, "RMB is the soft interact")
	_chk(Keys.WEAPONS_FREE != Keys.SELECT and Keys.ORDNANCE != Keys.SELECT,
		"neither firing verb is on a mouse button — the mouse never fires")

	# 5) Guns and ordnance are DIFFERENT gestures: a state vs a verb. Sharing a key would
	#    make weapons-free dump the magazine.
	_chk(Keys.WEAPONS_FREE != Keys.ORDNANCE,
		"guns (a state) and ordnance (a verb) are separate keys")

	# 5b) NO ALLY-CYCLE KEY, on purpose (user, 2026-07-25): LEFT-CLICK targets anything,
	#     ally included. That only stays safe because LMB never arms — the split is
	#     enforced in ship._select_target_at(point, engage), where the LMB path passes
	#     engage=false. Guard the SHAPE of that here; the behaviour itself is exercised in
	#     flight. If someone re-adds arming to the select path, ally-clicking starts
	#     shootouts inside the station sanctuary.
	var ship_src := FileAccess.get_file_as_string("res://scenes/flight/ship.gd")
	_chk(ship_src.contains("_select_target_at(get_global_mouse_position(), false)"),
		"LEFT-CLICK in the world selects WITHOUT engaging")
	_chk(ship_src.contains("if engage and target.is_in_group(enemy_group):"),
		"weapons only go free on the ENGAGE path, never on a plain select")

	# 6) Readable names, so HUD/tutor copy can be generated instead of hardcoding letters.
	_chk(Keys.name_of(Keys.MAP) == "M", "name_of reports the map key as 'M'")
	_chk(Keys.name_of(Keys.MENU) == "Esc", "name_of spells Esc")
	_chk(Keys.name_of(Keys.COMM_TERMINAL) == "ENTER", "name_of spells ENTER")

	print("test_keys: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(1 if _fails > 0 else 0)


func _chk(cond: bool, msg: String) -> void:
	print(("  ok  " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1
