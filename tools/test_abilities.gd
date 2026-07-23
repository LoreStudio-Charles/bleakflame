extends SceneTree
## Ability + profession-module WIRING integrity.
## Run: <godot> --headless --path . --script res://tools/test_abilities.gd
##
## Adding an ability touches five places (Abilities.LIST, a .tres tag, a
## dispatch arm in ship._activate_gem, a gem_state arm, and the leader's wares).
## Miss one and the ability silently does nothing — the gem lights up and the
## key is dead. Nothing else in the suite catches that, so this does.
##
## NOTE: --script mode has NO autoloads, so ship.gd (which calls Sfx) cannot be
## loaded as a class here. The dispatch checks READ ITS SOURCE AS TEXT instead —
## coarse, but it catches the whole "forgot to wire it" family, and it is the
## only way to see inside ship.gd from a headless test.

## Abilities live in CHIPS now (docs/ability_coupling.md); systems are scanned
## too so a legacy module that still grants one is still checked.
const SYS_DIR := "res://data/components/systems"
const CHIP_DIR := "res://data/components/chips"
const SHIP_SRC := "res://scenes/flight/ship.gd"

var fails := 0


func _init() -> void:
	var src := _read(SHIP_SRC)
	var modules := _load_modules()

	_check_list_sane()
	_check_every_ability_has_a_module(modules)
	_check_dispatch_and_state(src)
	_check_preloads_resolve(src)
	_check_wares_match_locks(modules)
	_check_cooldowns(modules)
	_check_energy_costs(modules, src)
	_check_energy_math()

	print("test_abilities: ", "ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails)
	quit(1 if fails > 0 else 0)


func _fail(msg: String) -> void:
	fails += 1
	print("FAIL: ", msg)


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_fail("cannot read %s" % path)
		return ""
	return f.get_as_text()


## Every SystemDef on disk, keyed by resource path.
func _load_modules() -> Dictionary:
	var out := {}
	for base in [CHIP_DIR, SYS_DIR]:
		var dir := DirAccess.open(base)
		if dir == null:
			_fail("cannot open %s" % base)
			continue
		for file in dir.get_files():
			if not file.ends_with(".tres"):
				continue
			var path := "%s/%s" % [base, file]
			var res := ResourceLoader.load(path)
			if res == null:
				_fail("cannot load %s" % path)
				continue
			out[path] = res
	return out


func _check_list_sane() -> void:
	var seen := {}
	for a in Abilities.LIST:
		var id: String = a.id
		if seen.has(id):
			_fail("duplicate ability id '%s'" % id)
		seen[id] = true
		if str(a.get("name", "")).is_empty():
			_fail("ability '%s' has no display name" % id)
		if str(a.get("desc", "")).is_empty():
			_fail("ability '%s' has no description (the book shows it)" % id)
		if a.get("source", "") == "module" and str(a.get("tag", "")).is_empty():
			_fail("module ability '%s' has no tag — nothing can ever grant it" % id)


## A module ability the player can never obtain is a dead entry in the book.
func _check_every_ability_has_a_module(modules: Dictionary) -> void:
	for a in Abilities.LIST:
		if a.get("source", "") != "module":
			continue
		var tag: String = a.get("tag", "")
		var found := false
		for res in modules.values():
			if res.has_tag(tag):
				found = true
				break
		if not found:
			_fail("ability '%s' wants tag '%s' but no chip or module carries it" % [a.id, tag])


## The two places ship.gd must name every ability: the [1]-[5] dispatch, and the
## HUD's cooldown hook. A gem with no dispatch arm is a dead key; one with no
## gem_state arm draws a bar that never sweeps.
func _check_dispatch_and_state(src: String) -> void:
	if src.is_empty():
		return
	var dispatch := _slice(src, "func _activate_gem", "\nfunc ")
	var state := _slice(src, "func gem_state", "\nfunc ")
	if dispatch.is_empty():
		_fail("could not find _activate_gem in ship.gd")
	if state.is_empty():
		_fail("could not find gem_state in ship.gd")
	for a in Abilities.LIST:
		var quoted := '"%s"' % a.id
		if not dispatch.contains(quoted):
			_fail("ability '%s' has NO dispatch arm in _activate_gem — the key does nothing" % a.id)
		if not state.contains(quoted):
			_fail("ability '%s' has no gem_state arm — the HUD cannot draw its cooldown" % a.id)


## Every preload() in ship.gd must point at a file that exists — a typo here is
## a hard crash the moment the ability fires, which no boot check would reveal.
func _check_preloads_resolve(src: String) -> void:
	var re := RegEx.new()
	re.compile('preload\\("([^"]+)"\\)')
	for m in re.search_all(src):
		var path := m.get_string(1)
		if not ResourceLoader.exists(path):
			_fail("ship.gd preloads '%s' which does not exist" % path)


## A profession-locked module must be sold by THAT profession's quartermaster,
## and every ware path must exist. This is the check that would have caught the
## Decoy Flare role swap leaving it in the wrong leader's stock.
func _check_wares_match_locks(modules: Dictionary) -> void:
	var sold := {}
	for p in Professions.LIST:
		for path in Professions.wares(p.id):
			if not ResourceLoader.exists(path):
				_fail("%s sells '%s' which does not exist" % [p.id, path])
				continue
			var res := ResourceLoader.load(path)
			var lock: String = res.profession_lock
			if lock != "" and lock != p.id:
				_fail("%s sells '%s' but it is locked to '%s'" % [
					p.id, res.display_name, lock])
			sold[path] = true

	for path in modules:
		var res = modules[path]
		# Deliberately withheld for the demo (Professions.WITHHELD_WARES) — not
		# an accident, and it comes back when that list is emptied.
		if Professions.ware_withheld(str(path)):
			continue
		if res.profession_lock != "" and not sold.has(path):
			_fail("'%s' is locked to '%s' but NO quartermaster stocks it — unobtainable" % [
				res.display_name, res.profession_lock])


## Every activatable module needs a cooldown in its `extra`, or it fires every
## frame you hold the key. Survey Scan is the deliberate exception (it channels).
func _check_cooldowns(modules: Dictionary) -> void:
	var exempt := ["scan"]
	for a in Abilities.LIST:
		if a.get("source", "") != "module":
			continue
		var tag: String = a.get("tag", "")
		if tag in exempt:
			continue
		for res in modules.values():
			if not res.has_tag(tag):
				continue
			var key := "%s_cooldown" % tag
			if not res.extra.has(key):
				_fail("'%s' has no '%s' in extra — the ability has no cooldown" % [
					res.display_name, key])
			elif float(res.extra[key]) <= 0.0:
				_fail("'%s' has %s = %s" % [res.display_name, key, res.extra[key]])


## Every ability must have an ENERGY cost in its module, be routed through the
## `_spend` gate, and be priced in `energy_cost()` for the HUD. An ability that
## skips the gate is free forever and quietly better than its peers.
func _check_energy_costs(modules: Dictionary, src: String) -> void:
	var free := ["scan"]           # Survey Scan is deliberately free
	var costs := _slice(src, "func energy_cost", "\nfunc ")
	for a in Abilities.LIST:
		if a.get("source", "") != "module":
			continue
		var tag: String = a.get("tag", "")
		if not costs.contains('"%s"' % a.id):
			_fail("ability '%s' is missing from energy_cost() — the HUD cannot price it" % a.id)
		if tag in free:
			continue
		var key := "%s_energy" % tag
		for res in modules.values():
			if not res.has_tag(tag):
				continue
			if not res.extra.has(key):
				_fail("'%s' has no '%s' — the ability would be FREE" % [res.display_name, key])
			elif float(res.extra[key]) <= 0.0:
				_fail("'%s' has %s = %s" % [res.display_name, key, res.extra[key]])

	# One _spend call per costed ability (scan is free and has no gate).
	var gates := src.count("if not _spend(")
	var want := 0
	for a in Abilities.LIST:
		if a.get("source", "") == "module" and a.get("tag", "") not in free:
			want += 1
	if gates != want:
		_fail("ship.gd has %d _spend gates but %d costed abilities — one is free" % [
			gates, want])


## The pool must be reachable: the WEAKEST reactor in the game has to afford the
## DEAREST ability, or that ability is unusable on the ship it ships with.
##
## Constants are read out of build_ship.gd as text, not referenced: touching
## BuildShip here would pull in Sfx, which does not exist in --script mode.
func _check_energy_math() -> void:
	# CAPACITY and RECHARGE are now HARD REACTOR STATS (2026-07-22), decoupled
	# from the fit's leftover LOAD. So this checks the REACTORS directly rather
	# than a margin formula. Loading a .tres works in --script mode; instantiating
	# BuildShip would not (it pulls in Sfx).
	var dearest := 25.0        # Repair Field, the priciest ability
	var burst := 3.0           # a pool must bank a burst of several dear casts

	var reactors := ["res://data/components/reactors/scrap_cell_pile.tres",
		"res://data/components/reactors/hearth_fusion.tres",
		"res://data/components/reactors/overdrive_bottle.tres"]
	var weakest_cap := 1e9
	for path in reactors:
		if not ResourceLoader.exists(path):
			_fail("reactor missing: %s" % path)
			continue
		var r = ResourceLoader.load(path)
		# The three hard stats must all be real numbers a designer set.
		if r.energy_capacity <= 0.0:
			_fail("%s has no energy_capacity — the pool is a hard reactor stat now" % r.display_name)
		if r.energy_recharge <= 0.0:
			_fail("%s has no energy_recharge — recovery is a hard reactor stat now" % r.display_name)
		if r.power_output <= 0.0:
			_fail("%s has no power_output (Load budget)" % r.display_name)
		weakest_cap = minf(weakest_cap, r.energy_capacity)

	# DEPTH: even the weakest reactor's pool holds a burst, so energy meters HOW
	# OFTEN you cast, never blocks a single cast on a fresh pool.
	if weakest_cap < dearest * burst:
		_fail("weakest reactor pools %.0f but should bank a %d-cast burst (%.0f)" % [
			weakest_cap, int(burst), dearest * burst])

	# RECHARGE IS FIT-INDEPENDENT now: the same reactor gives the same recharge
	# whether the fit is lean or crammed. (Proven by construction — recharge is a
	# reactor field ShipStats just sums — so this asserts the seam still exists
	# rather than re-deriving it.)
	var bs := _read("res://scenes/flight/build_ship.gd")
	if bs.find("stats.get(\"energy_recharge\"") < 0:
		_fail("build_ship no longer reads energy_recharge from the reactor stats")

	# The support tier must still regen faster than the combat tier.
	if Professions.energy_regen("science") <= Professions.energy_regen("guardian"):
		_fail("science regen (%s) should exceed guardian (%s)" % [
			Professions.energy_regen("science"), Professions.energy_regen("guardian")])
	if Professions.energy_regen("trader") <= Professions.energy_regen("privateer"):
		_fail("trader regen should exceed privateer")


## Value of a `const NAME := <float>` line, read from source text.
func _const_of(src: String, name: String) -> float:
	var re := RegEx.new()
	re.compile("const\\s+%s\\s*:=\\s*([0-9.]+)" % name)
	var m := re.search(src)
	if m == null:
		_fail("could not find const %s" % name)
		return 0.0
	return float(m.get_string(1))


## Text between `start` and the next `stop`, for reading one function out of a
## source file without a parser.
func _slice(src: String, start: String, stop: String) -> String:
	var a := src.find(start)
	if a < 0:
		return ""
	var b := src.find(stop, a + start.length())
	return src.substr(a, (b - a) if b > a else -1)
