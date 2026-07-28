extends Node
## ONE SHOOTER FOR EVERY UI SCREEN — point it at a screen, hand it a pilot state, get a PNG.
##
## WHY THIS AND NOT A FULLY GENERAL shoot(scene, coords) (user asked, 2026-07-27):
## the existing rigs (shoot_town, shoot_wrecks, shoot_ambush...) split cleanly in two.
## The PLUMBING is identical everywhere — read_only, wait for layout, capture, quit — and
## is worth having once. The DRIVING is not: "undock, drag five hostiles into view, kill
## them" and "walk to the warren, wound everyone, target a scrit" are programs, and
## expressing them as parameters would mean inventing a config language harder to write
## than the ten lines it replaced. Those rigs stay hand-written.
##
## UI SCREENS ARE THE PART THAT DOES GENERALISE. Every one of them is built the same way
## (a TestShip plus an argument or two) and what actually varies between shots is PILOT
## STATE — standing, credits, profession, which venue you are standing in. That fits on a
## command line, and it is the family with the most members: nine dock tabs, the bar, the
## deck, six offices.
##
## MUST RUN WINDOWED. --headless has no renderer, so get_viewport().get_texture() comes
## back empty and every shot is a blank file. This is why the other rigs say so too.
##
##   <godot> --path . res://tools/shoot.tscn -- --screen=speakeasy --standing=privateer:10
##   <godot> --path . res://tools/shoot.tscn -- --screen=office --prof=privateer --out=back_room.png
##   <godot> --path . res://tools/shoot.tscn -- --list
##
## ARGS (after a bare `--`, which is how Godot passes user args):
##   --screen=<id>      which screen (see SCREENS below); required
##   --out=<name.png>   filename; defaults to "<id>_shot.png"
##   --standing=k:v,... set standing EXACTLY, e.g. privateer:10,guardian:50
##   --credits=<n>      wallet
##   --prof=<id>        join a commission before building the screen
##   --tab=<name>       select a tab by title, for the tabbed dock screens
##   --frames=<n>       frames to settle before capturing (default 30)
##   --dir=<path>       output directory

const DEFAULT_DIR := "C:/Users/charl/AppData/Local/Temp/claude/E--Seared-Games-repos-Bleakflame-bleakflame/3a9df3e2-fa85-477f-96c4-c9436e26c8ad/scratchpad"

## Every screen this can photograph: id -> how to build it. A builder takes the ship and
## returns the node to add; adding one is a single line here, which is the whole point.
## Builders are Callables rather than a data table because construction genuinely differs
## (GuildOffice takes two callbacks) — the state setup above them is what is shared.
var _builders := {}

var _args := {}
var _ship: TestShip


func _ready() -> void:
	# NEVER WRITE THE PLAYER'S PILOT. These screens run the real autoloads, and docking
	# paths checkpoint. Same rule as every other tool in here.
	SaveGame.read_only = true
	_register()
	_args = _parse(OS.get_cmdline_user_args())

	if _args.has("list") or not _args.has("screen"):
		print("shoot: screens available — %s" % ", ".join(_builders.keys()))
		if not _args.has("list"):
			printerr("shoot: --screen=<id> is required")
		get_tree().quit(0 if _args.has("list") else 1)
		return

	var id := str(_args.get("screen", ""))
	if not _builders.has(id):
		printerr("shoot: unknown screen \"%s\" — try one of: %s" % [id, ", ".join(_builders.keys())])
		get_tree().quit(1)
		return

	_apply_state()
	_ship = TestShip.new()
	add_child(_ship)
	_ship.apply_build(SampleBuilds.get_build(SampleBuilds.current))

	var screen: Node = (_builders[id] as Callable).call(_ship)
	add_child(screen)
	if screen.get("visible") != null:
		screen.visible = true      # most of these early-return from refresh() while hidden
	if screen.has_method("refresh"):
		screen.refresh()
	_select_tab(screen)

	var frames := int(_args.get("frames", "30"))
	for _i in frames:
		await get_tree().process_frame

	var out := str(_args.get("out", "%s_shot.png" % id))
	var dir := str(_args.get("dir", DEFAULT_DIR))
	var img := get_viewport().get_texture().get_image()
	# A BLANK SHOT IS THE FAILURE THIS TOOL IS MOST LIKELY TO HAVE, and it looks like
	# success — the file exists, the run exits 0, and only a human opening it finds out.
	# Almost always --headless (no renderer). Say so instead of writing the blank.
	if img == null or img.is_empty():
		printerr("shoot: the viewport gave back nothing — are you running --headless? Run WINDOWED.")
		get_tree().quit(1)
		return
	img.save_png("%s/%s" % [dir, out])
	print("shoot: saved %s  (screen=%s, %s)" % [out, id, _state_summary()])
	get_tree().quit()


func _register() -> void:
	_builders["speakeasy"] = func(s: TestShip) -> Node: return SpeakEasy.new(s)
	_builders["dock"] = func(s: TestShip) -> Node: return DockScreen.new(s, true)
	_builders["colony"] = func(s: TestShip) -> Node: return DockScreen.new(s, false)
	_builders["deck"] = func(s: TestShip) -> Node: return ProspectDeck.new(s)
	# The office needs a commission to be the office OF — --prof picks it, defaulting to
	# whichever one the pilot has joined.
	_builders["office"] = func(s: TestShip) -> Node:
		var prof := str(_args.get("prof", Pilot.profession))
		if prof == "":
			prof = "guardian"
		return GuildOffice.new(Professions.leader(prof), prof, s,
			func(_p: String) -> void: pass,
			func(_i: String) -> void: pass)


## `--flag=value` and bare `--flag`. Unknown flags are kept, not rejected: this is a dev
## tool and a typo should read back in the summary line rather than abort a shot.
func _parse(argv: PackedStringArray) -> Dictionary:
	var out := {}
	for a in argv:
		var s := str(a)
		if not s.begins_with("--"):
			continue
		s = s.substr(2)
		var eq := s.find("=")
		if eq < 0:
			out[s] = "true"
		else:
			out[s.substr(0, eq)] = s.substr(eq + 1)
	return out


## Pilot state BEFORE the screen is built, because these screens read it at construction
## as well as in refresh() — setting standing afterwards photographs the wrong pilot.
func _apply_state() -> void:
	if _args.has("credits"):
		Wallet.credits = int(_args.credits)
	if _args.has("standing"):
		for pair in str(_args.standing).split(",", false):
			var kv := str(pair).split(":")
			if kv.size() != 2:
				printerr("shoot: --standing wants k:v pairs, got \"%s\"" % pair)
				continue
			# SET, not add. `Standing.add` takes a delta and the ledgers do not all open at
			# zero (the Shoal opens at -100), so "--standing=privateer:10" has to mean the
			# LEVEL or every Shoal shot is silently 100 points off.
			var key := str(kv[0])
			Standing.add(key, int(kv[1]) - Standing.get_points(key))
	if _args.has("prof"):
		Pilot.join_profession(str(_args.prof))
	if _args.has("tutorial-done"):
		SaveGame.tutorial_done = true
	MissionLog.ensure_offers()
	# CONTRACTS IN HAND — the state the mission board is actually FOR. An empty log
	# photographs the empty case and nothing else, and "take one, and pretend it is
	# finished" is two lines rather than a program, so it belongs on the command line
	# with the rest of the pilot state. `--contracts=2` takes that many from this
	# venue's board; `--finished` marks them delivered so the turn-in state is visible.
	var want := int(_args.get("contracts", "0"))
	if want > 0:
		var at_station := str(_args.get("screen", "")) != "colony"
		# RE-READ THE BOARD EACH TIME: accepting removes an offer, so every index after
		# it shifts — walking one snapshot would take the wrong second contract.
		while MissionLog.active.size() < want:
			var here := MissionLog.offers_for(at_station)
			if here.is_empty() or not MissionLog.accept(int(here[0].index)):
				break
		if _args.has("finished"):
			for m in MissionLog.active:
				m["n"] = 0                     # 0 of 0 delivered reads as complete
				m["start_kills"] = MissionLog.total_kills


## Tabbed screens only. Walks for a TabContainer and selects by title, so a shot can name
## the tab it wants rather than depending on whatever opens first.
func _select_tab(screen: Node) -> void:
	if not _args.has("tab"):
		return
	var want := str(_args.tab).to_lower()
	var tabs := _find_tabs(screen)
	if tabs == null:
		printerr("shoot: --tab given but %s has no TabContainer" % str(_args.get("screen", "")))
		return
	for i in tabs.get_tab_count():
		if want in tabs.get_tab_title(i).to_lower():
			tabs.current_tab = i
			return
	var titles := PackedStringArray()
	for i in tabs.get_tab_count():
		titles.append(tabs.get_tab_title(i))
	printerr("shoot: no tab matching \"%s\" — have: %s" % [_args.tab, ", ".join(titles)])


func _find_tabs(n: Node) -> TabContainer:
	if n is TabContainer:
		return n
	for c in n.get_children():
		var hit := _find_tabs(c)
		if hit != null:
			return hit
	return null


func _state_summary() -> String:
	var parts := PackedStringArray()
	parts.append("credits %d" % Wallet.credits)
	if Pilot.profession != "":
		parts.append("prof %s" % Pilot.profession)
	if _args.has("standing"):
		parts.append("standing %s" % _args.standing)
	return ", ".join(parts)
