extends Node
## DOCK UI HARNESS — asserts on the built screen, not on the model.
##
## WHY THIS EXISTS. Every other test in tools/ checks state: does the quest
## advance, does the contract pay, does the ability fire. All of them passed
## while Imari stood on the landing pad with no button to talk to her, because
## the talk WAS queued correctly — refresh() just drew her tab before draining
## the queue. A model test cannot see that. Only building the screen can.
##
## So this one constructs a real DockScreen, calls refresh(), and then WALKS THE
## CONTROL TREE looking for the button a player would have to click. If the
## button isn't there, the campaign is unfinishable, and this fails.
##
## RUN IT AS A SCENE, NOT A SCRIPT:
##   <godot> --headless --path . res://tools/test_dock_ui.tscn
## `--script` mode has no autoloads and dock_screen.gd needs Sfx.
##
## SAFETY: this must NEVER write the player's save. It does not call ship.dock()
## (that checkpoints) and does not call SaveGame.reset_all_progress() (that
## DELETES the save file). It drives Quests.on_dock + refresh() directly, which
## is also exactly the seam the bugs live in.

## Floor on coverage. If a case dies early (a parse error in a dependency aborts
## the rest of _ready), the suite would otherwise report a cheerful ALL PASS over
## zero assertions. Raise this as cases are added; it only has to be a floor.
const MIN_CHECKS := 90

var _fails: Array[String] = []
var _checks := 0


func _ready() -> void:
	_case_station_talk_appears_on_arrival()
	_case_trade_lesson_waits_for_ruel()
	_case_planet_talk_appears_on_arrival()
	_case_every_home_tab_can_host_its_person()
	_case_office_door_is_earned()
	_case_office_shows_tree_and_terms()
	_case_commission_never_joins_on_one_click()
	_case_every_leader_has_a_room()
	_case_secret_commissions_never_leak()
	_case_withheld_abilities_are_not_on_sale()
	_case_withholding_is_all_or_nothing()
	_case_ability_tooltips_carry_numbers()
	_case_office_door_is_taught()
	_case_informational_lessons_do_not_starve_the_queue()
	_case_turn_in_is_signalled()
	_case_filler_never_preempts_an_objective()
	_case_leader_line_never_crosses_its_target()
	_case_same_npc_keeps_talking()
	_case_all_held_talks_play_in_one_sitting()
	_case_talk_to_odessa_does_quest_first()
	_case_every_npc_desk_is_uniform()
	_case_quest_log_is_the_tracker()
	_case_armory_filters()
	_case_level_gates_equipping()
	_case_the_campaign_banner_never_goes_silent()
	_case_started_spines_stay_in_the_log()
	_case_contracts_credit_their_giver_guild()
	_case_gem_bar_never_starts_crossed_out()
	_case_odessa_has_no_dead_ask()
	_case_every_equipment_surface_describes_parts()
	_case_hulls_are_graded_gear()
	_case_lessons_stay_at_their_own_venue()
	_case_every_lesson_is_completable()

	if _checks < MIN_CHECKS:
		printerr("test_dock_ui: RAN ONLY %d CHECKS (expect >= %d) — a case aborted, "
			+ "probably a parse/runtime error above. NOT a pass." % [_checks, MIN_CHECKS])
		get_tree().quit(1)
		return
	if _fails.is_empty():
		print("test_dock_ui: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_dock_ui: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


# ---- cases ----

## THE IMARI REGRESSION, station side. Ruel's briefing is queued by the same
## docking that builds the screen; his button must exist on that first draw.
func _case_station_talk_appears_on_arrival() -> void:
	var screen := _fresh_dock(true)
	Quests.on_dock(true, screen.ship, true)
	screen.refresh()
	_ok(_find_button(screen, "Talk to " + Npcs.display_name("ruel")) != null,
		"Ruel has a Talk button on the docking that queues his briefing")
	_ok(screen._tab_has_waiting(Npcs.home("ruel")),
		"the Landing Bay tab reports a waiting person (drives the pip)")
	screen.queue_free()


## The lesson must follow the conversation. Before Ruel speaks it stays silent;
## after he speaks it arms.
func _case_trade_lesson_waits_for_ruel() -> void:
	var screen := _fresh_dock(true)
	Quests.on_dock(true, screen.ship, true)
	screen.refresh()
	_ok(not _tutor_knows("trade"),
		"the trade lesson does NOT arm while Ruel's briefing is unheard")

	# Hear him out, the way clicking the button does.
	Quests.take_talk("ruel")
	screen._held_talks["ruel"] = []
	screen.refresh()
	_ok(_tutor_knows("trade"),
		"the trade lesson arms once Ruel has actually briefed the run")
	screen.queue_free()


## THE REPORTED BUG. Land at the colony carrying the crate: Imari must be
## talkable on arrival, not one refresh later.
func _case_planet_talk_appears_on_arrival() -> void:
	var screen := _fresh_dock(false)
	Quests.active["dirtside_run"] = {"stage": 0, "count": 0}
	Quests.on_dock(false, screen.ship, true)
	screen.refresh()
	_ok(_find_button(screen, "Talk to " + Npcs.display_name("imari")) != null,
		"Imari has a Talk button the moment you land with the crate")
	_ok(screen._tab_has_waiting(Npcs.home("imari")),
		"the Landing Pad tab reports a waiting person (drives the pip)")
	screen.queue_free()


## Every NPC's `home` must name a tab that actually EXISTS at their venue —
## otherwise their talks queue into a room with no door and the pip has nothing
## to sit on. Catches a typo'd or renamed home before a player finds it.
func _case_every_home_tab_can_host_its_person() -> void:
	for venue_is_station in [true, false]:
		var screen := _fresh_dock(venue_is_station)
		var titles := []
		for i in screen._tabs.get_tab_count():
			titles.append(screen._tabs.get_tab_title(i))
		for id in Npcs.CAST:
			if not Npcs.is_dockside(str(id)):
				continue   # Krayt and Doug keep their own bespoke screens
			if Npcs.is_ground(str(id)):
				continue   # Tam/Bram live in walkable-town buildings, not behind a dock tab
			if Npcs.at_venue(str(id), venue_is_station) \
					and Npcs.home(str(id)) != "":
				_ok(titles.has(Npcs.home(str(id))),
					"%s's home tab \"%s\" exists at %s" % [id, Npcs.home(str(id)),
						"the station" if venue_is_station else "the colony"])
		screen.queue_free()


## THE DOOR IS EARNED. No invitation, no office — the leader is just a person at
## a counter. Standing crosses the line and the door appears where they work.
func _case_office_door_is_earned() -> void:
	_ok(not Professions.dev_unlock_offices,
		"the dev door-unlock is OFF by default — a playtest sees the real gating")
	var screen := _fresh_dock(true)
	Standing.reset()
	Pilot.profession = ""
	screen.refresh()
	_ok(_find_button(screen, Professions.office_name("guardian")) == null,
		"no office door before an invitation is earned")

	Standing.add("guardian", Standing.INVITE_AT)
	screen.refresh()
	_ok(_find_button(screen, Professions.office_name("guardian")) != null,
		"Ruel's office door appears once standing earns the invitation")
	screen.queue_free()


## The prospectus is the reason the room exists: the tree and the terms must be
## readable BEFORE signing, or the commitment is blind.
func _case_office_shows_tree_and_terms() -> void:
	var screen := _fresh_dock(true)
	Standing.reset()
	Pilot.profession = ""
	Standing.add("guardian", Standing.INVITE_AT)
	screen.refresh()
	screen._open_office("ruel", "guardian")

	var office := _find_office(screen)
	_ok(office != null, "the office opens from the door")
	if office == null:
		screen.queue_free()
		return
	_ok(_find_text(office, "Bulwark Brace"), "a visitor can read the tree before joining")
	_ok(_find_text(office, "Killshot") == false, "the office shows THIS commission's tree only")
	_ok(_find_button(office, "Accept the commission") != null,
		"an invited visitor is offered the commission")
	# DEMO POLISH: nothing on screen may advertise its own incompleteness.
	if not Professions.SHOW_UNBUILT:
		_ok(not _find_text(office, "not yet built"),
			"the office never shows a work-in-progress node")
		_ok(not _find_text(office, "ABILITY TREE"),
			"a two-ability list is not billed as a TREE while nodes are withheld")
		for b in Professions.branches("guardian"):
			for n in b.get("nodes", []):
				_ok(bool(n.get("built", false)),
					"every tree node shown is one that actually works")
	_ok(_find_tile(office) == null,
		"the quartermaster's counter stays shut for a non-member")
	screen.queue_free()


## Two presses, always. A commission is meant to be a decision you live with, so
## the warning must sit between the offer and the signature.
func _case_commission_never_joins_on_one_click() -> void:
	var screen := _fresh_dock(true)
	Standing.reset()
	Pilot.profession = ""
	Standing.add("guardian", Standing.INVITE_AT)
	screen.refresh()
	screen._open_office("ruel", "guardian")
	var office := _find_office(screen)
	if office == null:
		_ok(false, "office opened for the commitment check")
		screen.queue_free()
		return

	_press(_find_button(office, "Accept the commission"))
	_ok(Pilot.profession == "", "pressing Accept does NOT join — it warns first")
	_ok(_find_text(office, "This is permanent."), "the warning says plainly that it is permanent")

	_press(_find_button(office, "Sign on"))
	_ok(Pilot.profession == "guardian", "confirming signs you on")

	# Permanence is DERIVED FROM THE BUILD: tests run in a debug build, where the
	# choice stays swappable so playtests can iterate. A release export flips
	# can_switch to false with no flag to remember.
	_ok(Professions.can_switch() == OS.is_debug_build(),
		"commission permanence follows the build (swappable in debug, locked shipped)")
	_ok(_find_tile(office) != null,
		"the quartermaster's counter opens to a member, in ARMORY TILES")
	screen.queue_free()


## Every commission's leader must have a room to be met in, or that profession is
## unreachable. Doug and Vyper live on bespoke screens, so this checks the DATA
## (a named office + a tree) rather than any one screen's tabs.
func _case_every_leader_has_a_room() -> void:
	for p in Professions.LIST:
		var pid := str(p.id)
		_ok(Professions.office_name(pid) != "" \
				and Professions.OFFICES.has(pid),
			"%s's commission has a named office" % pid)
		_ok(not Professions.branches(pid).is_empty(),
			"%s's commission has an ability tree" % pid)
		# NO PLACEHOLDERS ON SCREEN. A parenthetical name is how an undesigned
		# node looks in the design record; it must never survive into the office.
		# Withhold it (`hidden: true`) or name it properly.
		for b in Professions.branches(pid):
			for n in b.get("nodes", []):
				var nm := str(n.get("name", ""))
				_ok(not nm.begins_with("("),
					"%s's tree shows no placeholder node (%s)" % [pid, nm])
				_ok(nm.strip_edges() != "", "%s's tree has no unnamed node" % pid)
		_ok(Professions.led_by(str(p.leader)) == pid,
			"%s resolves back to the %s commission" % [p.leader, pid])


## THE LINK ITSELF. A withheld ability must be gone from BOTH the office tree
## and every quartermaster shelf — and a live one must be present in both. This
## is what makes Professions.WITHHELD a single switch rather than two flags that
## can drift apart, so building an ability in the open cannot half-expose it.
func _case_withholding_is_all_or_nothing() -> void:
	for aid in Abilities.ids():
		var id := str(aid)
		var in_tree := false
		var on_shelf := false
		for p in Professions.LIST:
			var pid := str(p.id)
			for b in Professions.branches(pid):
				for n in b.get("nodes", []):
					if str(n.get("id", "")) == id:
						in_tree = true
			for wpath in Professions.wares(pid):
				if Professions.abilities_of(str(wpath)).has(id):
					on_shelf = true
		if Professions.withheld(id):
			_ok(not in_tree, "withheld %s appears in NO office tree" % id)
			_ok(not on_shelf, "withheld %s is on NO quartermaster shelf" % id)
		elif in_tree or on_shelf:
			# Not withheld: it must be whole. Half-present is the failure mode
			# this whole mechanism exists to make impossible.
			_ok(in_tree and on_shelf,
				"%s is offered whole — tree AND shelf, never one without the other" % id)


## WITHHOLDING MUST BE CONSISTENT AT BOTH ENDS. An ability hidden from the tree
## must not still be purchasable from that commission's quartermaster, and a chip
## on the shelf must correspond to something the office lists. Either mismatch is
## the exact "wait, what's that?" the demo lock exists to prevent.
func _case_withheld_abilities_are_not_on_sale() -> void:
	for p in Professions.LIST:
		var pid := str(p.id)
		var shown := {}
		for b in Professions.branches(pid):
			for n in b.get("nodes", []):
				shown[str(n.get("name", "")).to_lower()] = true
		for wpath in Professions.wares(pid):
			var sp := str(wpath)
			if not ResourceLoader.exists(sp):
				continue
			var comp: ComponentDef = load(sp)
			var tags = comp.get("tags")
			if tags == null:
				continue
			for tag in tags:
				var aid := Abilities.id_for_tag(str(tag))
				if aid == "":
					continue
				_ok(shown.has(Abilities.display_name(aid).to_lower()),
					"%s sells %s and its office lists it" % [pid, Abilities.display_name(aid)])


## SECRETS STAY SECRET. The Privateer commission is built and playable but must
## not be advertised anywhere in the demo: no meter, no door, no invitation
## tutor. This is the assertion that catches a well-meaning refactor swapping
## Professions.visible() back to Professions.LIST and spoiling the surprise.
func _case_secret_commissions_never_leak() -> void:
	for p in Professions.LIST:
		var pid := str(p.id)
		if not Professions.hidden(pid):
			continue
		_ok(not Professions.visible().has(p),
			"%s is absent from the advertised list" % pid)
		Standing.reset()
		Pilot.profession = ""
		Standing.add(pid, Standing.INVITE_AT * 3)   # over-qualified on purpose
		_ok(not Professions.office_open(pid),
			"%s's door stays shut even to an over-qualified pilot" % pid)
		for venue_is_station in [true, false]:
			var screen := _fresh_dock(venue_is_station)
			Standing.add(pid, Standing.INVITE_AT * 3)
			screen.refresh()
			_ok(not _find_text(screen, str(p.name)),
				"\"%s\" is never printed on the %s dock" % [p.name,
					"station" if venue_is_station else "colony"])
			_ok(_find_button(screen, Professions.office_name(pid)) == null,
				"%s's office door is never drawn at %s" % [pid,
					"the station" if venue_is_station else "the colony"])
			screen.queue_free()


## A tooltip that only says what an ability DOES cannot settle "which of these
## two goes in my last gem slot". Every ability must state its cost, and the
## timed ones their cadence — read LIVE off the fitted module, so a better chip
## shows better numbers.
func _case_ability_tooltips_carry_numbers() -> void:
	var screen := _fresh_dock(true)
	var timed := ["bulwark", "cloak", "lance", "killshot", "blight", "jinx",
		"overload", "crystal", "tangle_shot", "warp_jump", "blackout",
		"decoy_flare", "repair_field"]
	for aid in Abilities.ids():
		var body: String = Abilities.tooltip_body(str(aid), screen.ship, [str(aid)])
		# Free abilities (scan, by design) say so explicitly rather than omitting
		# the line — silence would read as "unknown", not "nothing".
		_ok("Energy" in body or "No energy cost" in body,
			"%s's tooltip states its energy cost" % aid)
		_ok(Abilities.describe(str(aid)) in body, "%s's tooltip still explains what it does" % aid)
		if timed.has(str(aid)):
			_ok("Cooldown" in body, "%s's tooltip states its cooldown" % aid)
	_ok("Channel" in Abilities.tooltip_body("scan", screen.ship, ["scan"]),
		"a channelled ability states its channel time")
	_ok("not fitted" in Abilities.tooltip_body("cloak", screen.ship, ["scan"]).to_lower(),
		"a gem whose module is missing says so instead of pretending it will fire")

	# THE VERB IS "WIRED", never "memorized" — the EverQuest metaphor stays in the
	# design docs, but nothing the player reads should sound like a spellbook.
	Pilot.set_gem(0, "scan")
	var wired: String = Abilities.tooltip_body("scan", screen.ship, ["scan"])
	_ok("Wired to key [1]" in wired, "a slotted ability reads as WIRED to its key")
	_ok(not ("emoriz" in wired), "no player-facing text says memorized")

	# The EQ nouns went the same way as the verb: gems -> BUS SLOTS (the
	# Processor Bus was already canon in Going Dark), book -> LIBRARY.
	screen._refresh_pilot()
	_ok(_find_text(screen, "PROCESSOR BUS"), "the gem bar is the Processor Bus")
	_ok(_find_text(screen, "ABILITY LIBRARY"), "the spellbook is the ability library")
	_ok(not _find_text(screen, "ABILITY GEMS"), "no screen still says GEMS")
	_ok(not _find_text(screen, "ABILITY BOOK"), "no screen still says BOOK")
	screen.queue_free()


## The office is a brand-new surface, so it gets a lesson like every other one.
## Two failure modes worth pinning: the lesson never arming, and the lesson
## arming with NO PING OVERLAY claiming its anchor — which looks identical to a
## working tutor right up until nothing is ever drawn.
func _case_office_door_is_taught() -> void:
	var screen := _fresh_dock(true)
	Standing.reset()
	Pilot.profession = ""
	screen.refresh()
	_ok(not Tutor.pending.has("office") and Tutor.active != "office",
		"the office lesson stays silent while no door exists")

	Standing.add("guardian", Standing.INVITE_AT)
	screen.refresh()
	_ok(_tutor_knows("office"), "the office lesson arms when a door first appears")

	# A DEV-UNLOCKED door is not an invitation and must not be announced.
	Tutor.reset()
	Standing.reset()
	Professions.dev_unlock_offices = true
	screen.refresh()
	_ok(_find_button(screen, Professions.office_name("guardian")) != null,
		"the dev unlock still opens doors for inspection")
	_ok(not _tutor_knows("office"),
		"...but a dev-unlocked door is never announced as an invitation")
	Professions.dev_unlock_offices = false
	_ok(Tutor.anchor_node("office_door") != null,
		"the door registers itself as the lesson's anchor")

	var claimed := false
	for c in screen.get_children():
		if c is TutorPing and (c as TutorPing).anchor == "office_door":
			claimed = true
	_ok(claimed, "a ping overlay exists to draw on the office_door anchor")

	# Opening the door completes the lesson rather than leaving it pulsing.
	Tutor.arm("office")
	screen._open_office("ruel", "guardian")
	_ok(not _tutor_knows("office") or Tutor.seen.has("office"),
		"entering the office retires the lesson wherever it sat in the queue")
	_ok(not Tutor.pending.has("office"), "and it is not left queued behind another lesson")
	screen.queue_free()


## HEAD-OF-LINE BLOCKING. An informational lesson (one with `dwell` and nothing
## to click) retires on a timer. If that timer cannot advance, the lesson stays
## ACTIVE forever and every lesson queued behind it never runs — which is how the
## unpinned "pips" step silently swallowed the whole trade lesson, and with it
## the buy-circuits teaching, on the first dock of a new game.
func _case_informational_lessons_do_not_starve_the_queue() -> void:
	var screen := _fresh_dock(true)
	Standing.reset()
	Pilot.profession = ""
	# THE ACTUAL REPRODUCTION: `Tutor.safe` is written by the FLIGHT tick, so it
	# still holds whatever it was when you docked. Dock while something is
	# hunting you and it is false — dwell timers stop, the informational lesson
	# never retires, and everything behind it starves. Docking must assert its
	# own safety rather than inherit flight's.
	Tutor.safe = false
	Quests.on_dock(true, screen.ship, true)
	screen.refresh()
	screen.refresh()
	_ok(Tutor.safe, "docking asserts that the dock is a safe context")
	_ok(Tutor.active != "" or not Tutor.pending.is_empty(), "a lesson is running at the dock")

	# Hear Ruel out (the trade lesson now waits for the conversation, not just for
	# the briefing to land on his desk) so trade legitimately arms and queues
	# BEHIND the active pip lesson — the starvation scenario this case exists for.
	Quests.take_talk("ruel")
	screen._held_talks["ruel"] = []
	screen.refresh()

	# Run the clock the way the ping node does, rather than waiting real seconds.
	for i in 40:
		for c in screen.get_children():
			if c is TutorPing:
				(c as TutorPing)._process(1.0)
		screen.refresh()
		if _tutor_knows("trade") and Tutor.active == "trade":
			break
	_ok(Tutor.seen.has("pips"), "the unpinned pip lesson retires on its dwell timer")
	_ok(Tutor.active == "trade" or Tutor.seen.has("trade"),
		"the trade lesson actually RUNS instead of starving behind it")
	screen.queue_free()


## LANDING WITH A CLOSEABLE CONTRACT MUST SAY SO. A pilot could land, talk to
## Imari, and fly home still carrying the crate: nothing pipped, nothing taught.
## And the colony's half of the trade route must not depend on the station's
## lesson having COMPLETED — chaining lessons is how one stall erases another.
func _case_turn_in_is_signalled() -> void:
	var screen := _fresh_dock(false)
	Tutor.safe = true
	screen.refresh()
	var quiet := screen._tab_has_waiting("Mission Uplink")

	# Give the pilot a completed delivery in hand.
	MissionLog.active.append({"type": "delivery", "good": "circuits", "n": 0,
		"reward": 100, "turn_in": "planet", "venue": "station", "desc": "test run"})
	screen.refresh()
	_ok(not quiet, "the Mission tab is quiet with nothing to hand in")
	_ok(screen._has_turn_in_here(), "the dock knows a contract can be closed here")
	_ok(screen._tab_has_waiting("Mission Uplink"),
		"the Mission tab wears a pip when something can be handed in")
	_ok(_tutor_knows("turn_in"), "and the hand-in is taught the first time")
	MissionLog.active.clear()

	# The return leg (SELL at the station — the buying moved to the ground lesson) must
	# arm on its own merits: station venue + food aboard, with `trade` never completed.
	Tutor.reset()
	Tutor.safe = true
	_ok(not Tutor.seen.has("trade"), "precondition: the outbound lesson never finished")
	screen.queue_free()
	var st := _fresh_dock(true)
	st.ship.add_commodity("food", 4)
	st.refresh()
	_ok(_tutor_knows("trade_return"),
		"carrying food at the STATION teaches the sell — not chained to another lesson")
	st.ship.remove_commodity("food", 4)
	st.queue_free()


## SCENERY MUST NOT INTERRUPT WORK. Tab-intro blurbs retire on a timer; an
## objective waits for the player to DO something. When a blurb takes the slot,
## the objective's ping disappears and the blurb self-destructs seconds later —
## which reads as "the tutor vanished on its own and I did nothing".
func _case_filler_never_preempts_an_objective() -> void:
	# The objective here is the STATION outbound lesson (the colony's steps are a GROUND
	# lesson now and never touch a dock tab).
	var screen := _fresh_dock(true)
	Tutor.safe = true
	Quests.active["dirtside_run"] = {"stage": 0, "count": 0}
	Quests.take_talk("ruel")
	screen._held_talks["ruel"] = []
	screen.refresh()
	screen.refresh()
	_ok(Tutor.active == "trade", "the station's objective lesson is running")

	# Open the Armory the way a click does — mid-objective.
	for i in screen._tabs.get_tab_count():
		if screen._tabs.get_tab_title(i) == "Armory":
			screen._tabs.current_tab = i
			break
	_ok(Tutor.active == "trade",
		"opening a tab mid-objective does NOT hand the slot to a tab blurb")
	_ok(not Tutor.pending.has("tab_intro_armory"),
		"and the blurb is not even queued while real work is outstanding")

	# With nothing outstanding, scenery is welcome again.
	Tutor.reset()
	Tutor.safe = true
	Tutor.arm("tab_intro_market")
	Tutor.pump()
	_ok(Tutor.active == "tab_intro_market", "with nothing else to say, the blurb runs")

	# And when both are queued, the objective wins the slot.
	Tutor.reset()
	Tutor.safe = true
	Tutor.arm("tab_intro_market")
	Tutor.arm("trade")
	Tutor.pump()
	_ok(Tutor.active == "trade", "queued together, the objective takes the slot first")

	# ALREADY ON THE TAB. A step that completes on a tab-CHANGE must not deadlock
	# when the lesson activates while the player is already standing there —
	# otherwise the NEXT step (accept the contract) never arrives.
	Tutor.reset()
	Tutor.safe = true
	for i in screen._tabs.get_tab_count():
		if screen._tabs.get_tab_title(i).begins_with("Mission"):
			screen._tabs.current_tab = i
			break
	Tutor.arm("trade")
	screen.refresh()
	_ok(Tutor.active == "trade" and Tutor.step >= 1,
		"a lesson that starts on the tab it points at advances to the real task")
	_ok(str(Tutor.current().get("item", "")) == "Circuits",
		"...which is the ACCEPT-CIRCUITS step, actually on screen")
	screen.queue_free()


## THE LEADER LINE MUST NOT DRAW THROUGH THE THING IT POINTS AT. It used to aim
## at the target's FAR edge, so pointing at the launch countdown ran the line
## straight down through the panel body. Pure geometry, so it tests without
## rendering: the segment may touch the target's boundary but never enter it.
func _case_leader_line_never_crosses_its_target() -> void:
	var target := Rect2(400, 150, 300, 240)      # e.g. the launch window
	var cases := {
		"caption below": Rect2(430, 520, 240, 26),
		"caption above": Rect2(430, 40, 240, 26),
		"caption left": Rect2(60, 250, 240, 26),
		"caption right": Rect2(900, 250, 240, 26),
	}
	for label in cases:
		var pts: Array = TutorPing.leader_points(cases[label], target)
		if pts.is_empty():
			continue
		var a: Vector2 = pts[0]
		var b: Vector2 = pts[1]
		# Sample along the segment; nothing strictly inside the target.
		var inside := 0
		for i in range(1, 40):
			var pt: Vector2 = a.lerp(b, float(i) / 40.0)
			if target.grow(-1.0).has_point(pt):
				inside += 1
		_ok(inside == 0, "leader line stops at the target's near edge (%s)" % label)
		_ok(target.grow(2.0).has_point(b), "...and actually reaches it (%s)" % label)

	# Touching or near-touching: no line at all, it would just be noise.
	_ok(TutorPing.leader_points(Rect2(410, 395, 200, 26), target).is_empty(),
		"no leader line when the caption already sits against its target")


## HAND A JOB IN AND HEAR THE NEXT ONE. Closing a debrief used to end the
## conversation even when the SAME person had the next contract ready — you shut
## the door and reopened it to hear "one more thing". Their follow-on continues
## the talk; anyone else still waits behind a pip.
##
## Staged DIRECTLY on Quests.pending_talks rather than by completing real quest
## data: this is a test of the ROUTING (same giver vs other giver), and tying it
## to whichever quest happens to follow dirtside_run would make it pass for
## reasons unrelated to the rule. The first version did exactly that and could
## not tell the fix from the bug.
func _case_same_npc_keeps_talking() -> void:
	var screen := _fresh_dock(true)
	Quests.reset()
	screen._talk_queue.clear()
	screen._held_talks.clear()
	screen._active_talk = null

	# Ruel has one more thing to say the moment this debrief closes.
	Quests.pending_talks.append({"giver": "ruel", "quest": "Next Job", "text": "One more thing."})
	screen._on_talk_closed({"giver": "ruel", "quest": "Dirtside Run", "text": "Well flown."})
	var continued: bool = not screen._talk_queue.is_empty() 		or (screen._active_talk != null and is_instance_valid(screen._active_talk))
	_ok(continued, "the same NPC's next job continues the conversation, no second visit")
	_ok(not screen._held_talks.has("ruel"),
		"...and is NOT parked behind his own pip while you stand in front of him")

	# Someone ELSE's business must still wait behind their pip.
	screen._talk_queue.clear()
	screen._active_talk = null
	Quests.pending_talks.append({"giver": "voss", "quest": "Overdue", "text": "A word."})
	screen._on_talk_closed({"giver": "ruel", "quest": "x", "text": "y"})
	_ok(screen._held_talks.get("voss", []).size() == 1,
		"another NPC's business is HELD for their pip, never forced on you")
	_ok(screen._talk_queue.is_empty(), "...and does not gatecrash the conversation")
	screen.queue_free()


## A NEW PILOT MUST NOT SEE A CROSSED-OUT GEM. `Pilot.reset()` wired "scan" into
## slot [1] on every new game, but the starter Rooster grants NO abilities — so
## the HUD drew a red ✕ over slot 1 from the first frame and kept it there until
## the pilot happened to buy a scanner. Empty is the honest state.
func _case_gem_bar_never_starts_crossed_out() -> void:
	Pilot.reset()
	for i in Pilot.GEM_SLOTS:
		_ok(Pilot.gem_at(i) == "", "a new pilot's bus slot %d starts EMPTY" % (i + 1))

	# The starter ship grants nothing, so boarding must not invent a gem.
	var screen := _fresh_dock(true)
	var known: Array = Abilities.known_for_build(screen.ship.build)
	if known.is_empty():
		_ok(Pilot.gem_at(0) == "",
			"boarding a ship with no abilities leaves the bar empty, not crossed out")

	# ...but the moment a fit DOES grant something, it wires into the first open slot.
	Pilot.gems = ["", "", "", "", ""]
	Pilot.autowire(["scan"])
	_ok(Pilot.gem_at(0) == "scan", "a granted ability wires into the first open slot")

	# EQUIP adds to the next OPEN slot without disturbing a still-fitted gem
	# (user, 2026-07-23: equip a chip -> wire it into the last open ability slot).
	Pilot.autowire(["scan", "cloak"])
	_ok(Pilot.gem_at(0) == "scan" and Pilot.gem_at(1) == "cloak",
		"equipping a second ability fills the next open slot, leaving the first")

	# UNEQUIP removes that ability from the bus (chip no longer fitted).
	Pilot.autowire(["scan"])
	_ok(Pilot.gem_at(0) == "scan" and Pilot.gem_at(1) == "",
		"unequipping a chip drops its ability off the bus")

	# A still-fitted ability is left EXACTLY where the pilot placed it — reconcile
	# only removes the unfitted and fills the empty, never reshuffles the kept.
	Pilot.gems = ["", "", "", "", ""]
	Pilot.set_gem(2, "scan")
	Pilot.autowire(["scan"])
	_ok(Pilot.gem_at(2) == "scan" and Pilot.gem_at(0) == "",
		"a still-fitted gem stays where the pilot put it")
	screen.queue_free()


## NO DEAD GOLD BUTTONS. "What's the word?" used to sit there in gold whether or
## not she had anything, answer "quiet week", and STILL be gold when you came
## back to the start — a promise the conversation could not keep.
func _case_odessa_has_no_dead_ask() -> void:
	var with_rumor: Dictionary = Dialogues.ODESSA_BAR.duplicate(true)
	DockScreen._dress_odessa(with_rumor, true)
	var found := false
	for key in with_rumor:
		for c in with_rumor[key].get("choices", []):
			if str(c.get("action", "")) == "rumor":
				found = true
				_ok(str(c.get("style", "")) == "primary",
					"with a rumor waiting, the ask is GOLD — something happens")
	_ok(found, "with a rumor waiting, the ask is offered at all")

	var quiet: Dictionary = Dialogues.ODESSA_BAR.duplicate(true)
	DockScreen._dress_odessa(quiet, false)
	for key in quiet:
		for c in quiet[key].get("choices", []):
			_ok(str(c.get("action", "")) != "rumor",
				"with nothing to tell, the ask is HIDDEN rather than a dead end")
	# The panel must still be usable — hiding one choice cannot empty the room.
	_ok(not quiet.get("start", {}).get("choices", []).is_empty(),
		"...and she still has something to say")


## ONE DESCRIPTION OF A PART, EVERYWHERE. The paperdoll showed a bare two-line
## string ("Main Drive (Engine Mk1) / Efficient Vectorjet Thruster Mk1 Standard")
## while the Armory, the hold and the Coupling all gave the full grade panel —
## so the one screen where you decide what to FIT told you the least about it.
func _case_every_equipment_surface_describes_parts() -> void:
	var screen := _fresh_dock(true)
	# The doll lays itself out on `resized`, which never fires headless — give it
	# a size and build it directly.
	screen._doll.size = Vector2(420, 420)
	screen._refresh_paperdoll()

	var slot := _find_slot_with_part(screen)
	_ok(slot != null, "the paperdoll has a fitted slot to inspect")
	if slot == null:
		screen.queue_free()
		return
	var tip: Object = slot._make_custom_tooltip("")
	_ok(tip != null, "a fitted slot builds a rich tooltip, not a bare string")
	if tip == null:
		screen.queue_free()
		return
	var text: String = (tip as RichTextLabel).get_parsed_text()
	_ok(slot.comp.display_name in text, "it names the part")
	_ok(Grades.display_name(slot.comp.grade) in text, "it states the GRADE, like every other surface")
	_ok("mass" in text, "it states mass, like every other surface")
	_ok("unfit" in text, "it says how to get the part back out")
	screen.queue_free()


func _find_slot_with_part(root: Node) -> Node:
	for child in root.get_children():
		if child is DockScreen.SlotSquare and (child as DockScreen.SlotSquare).comp != null:
			return child
		var hit := _find_slot_with_part(child)
		if hit != null:
			return hit
	return null


## A HULL IS GEAR TOO. It gets the same rich hover as a component — quality,
## level, and above all its SLOT SET, which is what a buyer actually compares and
## which previously could only be seen by boarding the ship.
func _case_hulls_are_graded_gear() -> void:
	for i in SampleBuilds.count():
		var build := SampleBuilds.get_build(i)
		var tip: Object = DockScreen.hull_tooltip(build)
		_ok(tip != null, "hull %s has a rich tooltip" % build.hull.display_name)
		var text: String = (tip as RichTextLabel).get_parsed_text()
		_ok(build.hull.display_name in text, "it names the hull (%s)" % build.hull.display_name)
		_ok(Grades.display_name(build.hull.grade) in text,
			"it states the hull's QUALITY (%s)" % build.hull.display_name)
		_ok("Level" in text, "it states the hull's LEVEL (%s)" % build.hull.display_name)
		_ok("HARDPOINTS" in text, "it lists the slot set (%s)" % build.hull.display_name)

	# The two old girls are junk-tier on purpose; everything else is Standard
	# until a better hull is authored above it.
	for i in SampleBuilds.count():
		var hull := SampleBuilds.get_build(i).hull
		var junk := hull.display_name in ["Rooster", "Dowager"]
		# Everything authored so far is second-hand: the two old girls are
		# Flotsam, every other hull is Salvage. Nothing is Standard yet.
		var want: int = Grades.Grade.FLOTSAM if junk else Grades.Grade.SALVAGE
		_ok(hull.grade == want,
			"%s is %s" % [hull.display_name, Grades.display_name(want)])
		_ok(hull.level >= 1, "%s has a level" % hull.display_name)

	# JUNK HULLS CARRY A JUNK BUS. The coupling's grade sets how many ability
	# chips fit, so this is the first upgrade that changes what a pilot can DO —
	# it must match the hull's own tier rather than quietly shipping a good one.
	for i in SampleBuilds.count():
		var build := SampleBuilds.get_build(i)
		var cup: CouplingDef = build.coupling()
		_ok(cup != null, "%s has a Coupling fitted" % build.hull.display_name)
		if cup == null:
			continue
		# Checked by ITEM path, not display name: the file is still
		# standard_coupling.tres (keeps its icon) but reads "Salvaged Coupling"
		# in-game — Salvage grade, 2 chips.
		var junk2: bool = build.hull.display_name in ["Rooster", "Dowager"]
		var want_item := "scrap_coupling" if junk2 else "standard_coupling"
		_ok(want_item in str(cup.resource_path),
			"%s carries the %s coupling" % [build.hull.display_name, want_item])


## A LESSON MUST STILL BE RIGHT WHERE IT FINALLY RUNS. `where: "dock"` is true at
## the station AND the colony AND the Verge, so a station-only lesson that got
## QUEUED behind another one pumped at the next dock of any kind — a pilot on the
## colony's landing pad was told to go and meet Dex at the station's lab. Arming
## at the right venue is not enough when lessons can wait.
func _case_lessons_stay_at_their_own_venue() -> void:
	# (meet_sella retired 2026-07-25 — meeting her is a GROUND step now; trade_return
	# moved to the STATION, its planet half became the ground lesson.)
	var venues := {"meet_dex": "station",
		"trade": "station", "trade_return": "station", "commission": "station"}
	for lid in venues:
		var want := str(venues[lid])
		var other := "planet" if want == "station" else "station"

		# Queued at its own venue: eligible.
		Tutor.reset()
		Tutor.safe = true
		Tutor.context = "dock"
		Tutor.venue = want
		Tutor.pending.append(lid)
		Tutor.pump()
		_ok(Tutor.active == lid, "%s runs at the %s" % [lid, want])

		# Same lesson, wrong dock: must keep waiting, not fire.
		Tutor.reset()
		Tutor.safe = true
		Tutor.context = "dock"
		Tutor.venue = other
		Tutor.pending.append(lid)
		Tutor.pump()
		_ok(Tutor.active != lid, "%s does NOT fire at the %s" % [lid, other])
		_ok(Tutor.pending.has(lid), "...it waits until you are back at the %s" % want)


## THE TUTOR MUST BE HARD TO BREAK (user, 2026-07-22). Every tutor bug this
## session was an authoring mistake that LOOKED fine: an anchor no screen
## registers, an anchor no ping overlay draws, a `tab` naming a room that does
## not exist at that venue. Each one silently jammed the queue.
##
## So every step is checked against the real screens before it can ship. Adding a
## lesson with a typo now fails here instead of in someone's playthrough.
func _case_every_lesson_is_completable() -> void:
	# What the built screens actually offer, at both venues.
	# Registration/pings are collected PER VENUE, because a station-only anchor is
	# correctly absent from the colony and vice versa.
	var reg := {"station": {}, "planet": {}}
	var ping := {"station": {}, "planet": {}}
	var tabs := {"station": {}, "planet": {}}
	for is_station in [true, false]:
		var vkey := "station" if is_station else "planet"
		Tutor._anchors.clear()
		var screen := _fresh_dock(is_station)
		for i in screen._tabs.get_tab_count():
			tabs[vkey][screen._tabs.get_tab_title(i)] = true
		for a in Tutor._anchors:
			reg[vkey][str(a)] = true
		var pd := {}
		_collect_pings(screen, pd)
		ping[vkey] = pd
		screen.queue_free()

	# Anchors that register the moment their widget is DRAWN rather than when the
	# screen is built — the office door only exists once you have an invitation.
	# Anchors owned by TRANSIENT UI a bare build can't stand up: the office door registers
	# only once you have an invitation; the launch-countdown modal creates its own ping.
	var lazy := {"office_door": true, "launch_window": true}
	# FLIGHT-lesson captions draw from the flight HUD's pings, not the dock's — the dock-only
	# check below never saw them, which is the exact hole the effigy tutorial fell through.
	var flight_pings: Array = load("res://scenes/flight/flight_hud.gd").TUTOR_PING_ANCHORS

	for lid in Tutor.LESSONS:
		var steps: Array = Tutor.LESSONS[lid]
		_ok(not steps.is_empty(), "lesson '%s' has at least one step" % lid)
		for i in steps.size():
			var st: Dictionary = steps[i]
			var anchor := str(st.get("anchor", ""))
			var where := str(st.get("where", ""))
			var label := "%s[%d]" % [lid, i]

			if where == "ground":
				# GROUND lessons are drawn by the TOWN (epharon_town: a caption + a spatial chevron
				# to the target NPC/building), NOT a TutorPing — they carry a `target`, no `anchor`.
				_ok(str(st.get("text", "")) != "", "%s has copy to show" % label)
				continue

			_ok(anchor != "", "%s names an anchor" % label)
			_ok(str(st.get("text", "")) != "", "%s has copy to show" % label)
			var venue := str(st.get("venue", ""))
			_ok(venue in ["", "station", "planet", "verge"],
				"%s has a legal venue ('%s')" % [label, venue])

			if lazy.has(anchor):
				continue          # transient UI owns its ping (office door / launch modal)
			# FLIGHT captions need a ping on the flight HUD (single source of truth in
			# FlightHud). This is what would have caught the effigy tutorial rendering nothing.
			if where == "flight":
				_ok(flight_pings.has(anchor),
					"%s (flight) anchor '%s' has a flight-HUD ping" % [label, anchor])
				continue
			if where != "dock":
				# any-context ("") — must draw SOMEWHERE: a flight ping or a dock ping.
				_ok(flight_pings.has(anchor)
						or (ping["station"] as Dictionary).has(anchor)
						or (ping["planet"] as Dictionary).has(anchor),
					"%s (any-context) anchor '%s' draws in flight or at a dock" % [label, anchor])
				continue
			if lazy.has(anchor):
				continue          # registers on draw; can't see it from a bare build
			if not bool(st.get("pin", true)):
				continue          # unpinned = caption only, needs no anchor widget
			# Which venues can this step actually run at? A venue-tagged step:
			# only that one. Untagged: any dock, so it must hold up at BOTH.
			var venues: Array = [venue] if venue != "" else ["station", "planet"]
			for v in venues:
				if v == "verge":
					continue          # bespoke screen, checked by hand
				_ok(reg[v].has(anchor),
					"%s anchor '%s' is registered at the %s" % [label, anchor, v])
				_ok((ping[v] as Dictionary).has(anchor),
					"%s anchor '%s' has a ping overlay at the %s" % [label, anchor, v])
				var want_tab := str(st.get("tab", ""))
				if want_tab == "":
					continue
				var found := false
				for title in tabs[v]:
					if str(title).begins_with(want_tab):
						found = true
				_ok(found, "%s tab '%s' exists at the %s" % [label, want_tab, v])


func _collect_pings(root: Node, out: Dictionary) -> void:
	for child in root.get_children():
		if child is TutorPing:
			out[(child as TutorPing).anchor] = true
		_collect_pings(child, out)


## HEAR EVERYTHING THEY ARE HOLDING, IN ONE VISIT. Ruel commonly has a finished
## quest's DEBRIEF and the next quest's BRIEFING waiting at the same dock; the
## old _talk_to popped just one, so "Standing With the Board" sat un-started
## behind a second click on the same button. Clicking Talk must drain them all.
func _case_all_held_talks_play_in_one_sitting() -> void:
	var screen := _fresh_dock(true)
	screen._held_talks.clear()
	screen._talk_queue.clear()
	screen._active_talk = null
	screen._held_talks["ruel"] = [
		{"giver": "ruel", "quest": "Dirtside Run — COMPLETE", "text": "Well flown."},
		{"giver": "ruel", "quest": "Standing With the Board", "text": "Board's got work."},
	]
	screen._talk_to("ruel")
	# One shows now; the rest must be QUEUED, not left held for another click.
	var queued_or_active := screen._talk_queue.size() 		+ (1 if screen._active_talk != null and is_instance_valid(screen._active_talk) else 0)
	_ok(queued_or_active == 2, "both of Ruel's held talks are in play at once")
	_ok(not screen._held_talks.has("ruel"),
		"nothing is left holding behind a second click")
	screen.queue_free()


## DOING A GUILD'S WORK BUILDS THAT GUILD. Turn-in standing follows the GIVER,
## not the work TYPE — Sella's Scan Data runs are `delivery` contracts, and a
## type-only map credited them to the Traders, leaving Scout standing stuck once
## the map's secrets were all charted (the exact thing the user hit).
func _case_contracts_credit_their_giver_guild() -> void:
	var cases := {
		"sella": "scout", "imari": "trader", "ruel": "guardian",
		"doug": "miner", "lab": "science", "voss": "guardian",
		"vyper": "privateer"}   # privateer is hidden, but its work still counts
	for giver in cases:
		# A delivery from each giver — same TYPE, different guilds.
		var fac := MissionLog.faction_for({"giver": giver, "type": "delivery"})
		_ok(fac == cases[giver],
			"a contract from %s credits %s (got '%s')" % [giver, cases[giver], fac])
	# The specific regression: Sella's scan-data delivery is SCOUT, not trader.
	_ok(MissionLog.faction_for({"giver": "sella", "type": "delivery", "good": "scan_data"}) == "scout",
		"Sella's Scan Data run builds Scout standing")
	# Giver-less procedural contracts keep the old work-type flavour.
	_ok(MissionLog.faction_for({"type": "bounty"}) == "guardian",
		"a giver-less bounty still falls back to Guardian")

	# Every giver that actually POSTS work resolves to a real faction — no
	# contract can pay out to nobody.
	for m in MissionLog._templates:
		var f := MissionLog.faction_for(m)
		_ok(f != "", "template from '%s' credits a guild" % str(m.get("giver", "?")))


## THE EMBER_WORD FREEZE. Odessa's bespoke "Talk to Odessa" button used to always
## open the bar rumour chat, ignoring a pending CAMPAIGN talk — so ember_word's
## "meet Odessa" beat sat un-advanced behind a second, redundant button and the
## campaign froze (~46 game-days in a real save). "Talk to Odessa" must present
## her QUEST business first, and only fall through to the bar when she has none.
func _case_talk_to_odessa_does_quest_first() -> void:
	var screen := _fresh_dock(true)
	screen._held_talks.clear()
	screen._talk_queue.clear()
	screen._active_talk = null
	screen._bar_panel = null

	# Odessa has a pending campaign talk (as ember_word queues on docking).
	screen._held_talks["odessa"] = [{"giver": "odessa", "quest": "The Word at Ember Row",
		"nodes": {"start": {"text": "hi", "choices": [{"text": "ok", "next": "end"}]}},
		"advance": "ember_word"}]
	screen._on_talk_odessa()
	var quest_shown: bool = not screen._talk_queue.is_empty() 		or (screen._active_talk != null and is_instance_valid(screen._active_talk))
	_ok(quest_shown, "Talk to Odessa presents her pending QUEST talk, not the bar chat")
	_ok((screen._held_talks.get("odessa", []) as Array).is_empty(),
		"the held Odessa quest talk is drained (ember_word can advance)")
	_ok(screen._bar_panel == null, "it did NOT open the bar rumour chat while quest business waits")

	# With nothing held, the button falls through to the bar chat as before.
	screen._held_talks.clear()
	screen._talk_queue.clear()
	screen._active_talk = null
	screen._bar_panel = null
	screen._on_talk_odessa()
	_ok(screen._bar_panel != null, "with no quest business, Talk to Odessa opens the bar chat")

	# And there is EXACTLY ONE "Talk to Odessa" button in the whole tree — the
	# unified NPC desk. The freeze was a SECOND, redundant button; the anti-
	# regression is that a second one can never exist again.
	_ok(screen._npc_desks.has("odessa"), "Odessa is a unified NPC desk like everyone else")
	_ok(_count_buttons(screen, "Talk to " + Npcs.display_name("odessa")) == 1,
		"exactly one Talk to Odessa button — no duplicate to hide a quest talk behind")
	screen.queue_free()


## THE UNIFIED NPC DESK. Every dockside face is placed by the same NpcDesk object,
## with an always-visible talk button that is never a dead click, lit only on news.
func _case_every_npc_desk_is_uniform() -> void:
	for station in [true, false]:
		var screen := _fresh_dock(station)
		screen._held_talks.clear()
		screen.refresh()
		for npc in screen._npc_desks:
			var desk: NpcDesk = screen._npc_desks[npc]
			_ok(desk is NpcDesk, "%s stands at an NpcDesk (%s dock)" % [npc, "station" if station else "planet"])
			# Always-visible button, even with nothing held.
			_ok(_count_buttons(desk, "Talk to " + Npcs.display_name(npc)) == 1,
				"%s desk shows its talk button with nothing queued" % npc)
			# A no-news desk carries no amber dot; a held talk lights it.
			desk.set_news(false)
			_ok(not desk._dot.visible, "%s desk dot is dark with no news" % npc)
			desk.set_news(true)
			_ok(desk._dot.visible, "%s desk dot lights on news" % npc)
		screen.queue_free()


## CURATION LIVES ON THE ACTIVE LOG ENTRIES (user, 2026-07-23): the QuestLogView
## active tab IS the tracker — every objective (campaign + contract) is an entry
## with a ★ show/hide and ▲▼ reorder on its title, and starring one off drops it
## from the HUD list. No separate TrackerPanel any more.
func _case_quest_log_is_the_tracker() -> void:
	Quests.reset()
	MissionTracker.reset()
	MissionLog.active.clear()
	MissionLog.offers.clear()
	MissionLog.ensure_offers()
	Quests.active["overdue"] = {"stage": 0, "count": 0}
	_ok(MissionLog.accept(0), "seed a contract for the tracker")
	var ship := TestShip.new()
	add_child(ship)
	ship.apply_build(SampleBuilds.get_build(SampleBuilds.current))
	var view := QuestLogView.new(ship, "active")
	add_child(view)
	view.rebuild()

	_ok(_count_buttons(view, "★") + _count_buttons(view, "☆") >= 2,
		"every active objective carries a show/hide star on its title row")
	_ok(_count_buttons(view, "▲") >= 2 and _count_buttons(view, "▼") >= 2,
		"...and ▲▼ reorder arrows")

	var before := MissionTracker.visible_tracked(ship).size()
	_ok(before >= 2, "campaign + contract both track")
	MissionTracker.toggle("q:overdue")
	_ok(MissionTracker.visible_tracked(ship).size() == before - 1,
		"starring an objective off drops it from the HUD list")
	MissionTracker.toggle("q:overdue")

	view.queue_free()
	ship.queue_free()


# ---- rig ----

## A dock screen with clean campaign statics behind it. Never touches the save.
func _fresh_dock(is_station: bool) -> DockScreen:
	# NOT forced any more. Forcing it here is exactly why the shipped default
	# (OS.is_debug_build() -> every door open in every playtest) went unnoticed:
	# the suite asserted the rule it wanted while the game ran the other one.
	Quests.reset()
	Tutor.reset()
	MissionLog.ensure_offers()
	var ship := TestShip.new()
	add_child(ship)
	ship.apply_build(SampleBuilds.get_build(SampleBuilds.current))
	var screen := DockScreen.new(ship, is_station)
	add_child(screen)
	screen.visible = true   # refresh() early-returns on a hidden screen
	return screen


## Has the tutor been told about this lesson — queued, running, or already shown?
func _tutor_knows(id: String) -> bool:
	return Tutor.pending.has(id) or Tutor.active == id or Tutor.seen.has(id)


## Depth-first walk for a VISIBLE button whose text contains `needle`. Visibility
## matters: a button parked on an unbuilt tab is not a button the player can press.
func _find_button(root: Node, needle: String) -> Button:
	for child in root.get_children():
		if child is Button and needle in (child as Button).text:
			return child
		var hit := _find_button(child, needle)
		if hit != null:
			return hit
	return null


## Count EVERY button whose text contains `needle`, visible or not — a duplicate
## parked on an unbuilt tab still counts, which is the regression we guard against.
func _count_buttons(root: Node, needle: String) -> int:
	var n := 0
	for child in root.get_children():
		if child is Button and needle in (child as Button).text:
			n += 1
		n += _count_buttons(child, needle)
	return n


func _find_office(root: Node) -> GuildOffice:
	for child in root.get_children():
		if child is GuildOffice:
			return child
	return null


## Does any label anywhere under `root` contain this text? Buttons are how you
## act; labels are how you READ, and the prospectus is a reading surface.
func _find_text(root: Node, needle: String) -> bool:
	for child in root.get_children():
		if child is RichTextLabel and needle in (child as RichTextLabel).get_parsed_text():
			return true
		if child is Label and needle in (child as Label).text:
			return true
		if _find_text(child, needle):
			return true
	return false


## The counter must render as ItemTiles — same grade border, mark badge, pips
## and price as everywhere else equipment is shown.
func _find_tile(root: Node) -> Node:
	for child in root.get_children():
		if child is ItemTile:
			return child
		var hit := _find_tile(child)
		if hit != null:
			return hit
	return null


func _press(b: Button) -> void:
	if b != null:
		b.pressed.emit()


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)


## ARMORY FILTERS — the chip shelf and the level band (user, 2026-07-26).
##
## Asserted through the REAL screen and the REAL shop stock, because the whole
## point of these two filters is which of the actual shipped items they surface.
##
## The subtle one is CHIPS vs SYSTEM. A chip is a SystemDef, so `slot_type()`
## answers SYSTEM for a cargo pod and an ability chip alike — a slot filter simply
## cannot tell them apart, which is why the chip shelf keys off what the item
## GRANTS instead. If that ever regresses to a slot test, "Chips" quietly becomes a
## second System tab and the System tab fills up with chips.
func _case_armory_filters() -> void:
	var screen := _fresh_dock(true)
	screen.refresh()

	# --- CHIPS shows only things that grant an ability ---
	screen._armory_filter = DockScreen.FILTER_CHIPS
	screen._refresh_armory()
	var chips := _shop_tiles(screen)
	_ok(not chips.is_empty(), "the Chips filter shows something (the shop stocks chips)")
	for c in chips:
		_ok(DockScreen._is_chip(c), "'%s' is on the chip shelf and grants an ability" % c.display_name)

	# --- ...and the System shelf is free of them ---
	screen._armory_filter = HardpointDef.SlotType.SYSTEM
	screen._refresh_armory()
	for c in _shop_tiles(screen):
		_ok(not DockScreen._is_chip(c),
			"'%s' is a chip and must not sit on the System shelf" % c.display_name)

	# --- LEVEL BAND ---
	screen._armory_filter = -1
	screen._armory_lvl_min = 1
	screen._armory_lvl_max = Pilot.MAX_LEVEL
	screen._refresh_armory()
	var all_count := _shop_tiles(screen).size()
	_ok(all_count > 0, "the unfiltered shelf has stock (%d)" % all_count)

	screen._armory_lvl_min = 1
	screen._armory_lvl_max = 5
	screen._refresh_armory()
	for c in _shop_tiles(screen):
		_ok(int(c.level) >= 1 and int(c.level) <= 5,
			"'%s' (L%d) is inside the 1-5 band" % [c.display_name, int(c.level)])

	# A band nothing occupies must EXPLAIN itself, not just look like a broken shop.
	screen._armory_lvl_min = Pilot.MAX_LEVEL
	screen._armory_lvl_max = Pilot.MAX_LEVEL
	screen._refresh_armory()
	_ok(_shop_tiles(screen).is_empty(), "an empty band shows no stock")
	_ok(_finds_text(screen._shop_grid, "level %d" % Pilot.MAX_LEVEL),
		"an empty shelf names the level band that emptied it")

	# --- THE ENDS CANNOT CROSS --- dragging min past max shoves max, and vice
	# versa. Without this the shop can be left permanently empty with no visible
	# cause, which reads as a bug rather than a filter.
	screen._armory_lvl_min = 1
	screen._armory_lvl_max = 60
	screen._lvl_min_spin.value = 1
	screen._lvl_max_spin.value = 60
	screen._lvl_min_spin.value = 40          # emits -> should shove max up
	_ok(screen._armory_lvl_max >= 40,
		"raising min above max pushed max up (min %d, max %d)"
		% [screen._armory_lvl_min, screen._armory_lvl_max])
	screen._lvl_max_spin.value = 3           # emits -> should shove min down
	_ok(screen._armory_lvl_min <= 3,
		"lowering max below min pulled min down (min %d, max %d)"
		% [screen._armory_lvl_min, screen._armory_lvl_max])

	screen.queue_free()


## The ComponentDefs currently drawn on the shop shelf.
##
## SKIPS NODES ALREADY QUEUED FOR DELETION. `_refresh_armory` clears the grid with
## queue_free(), which is DEFERRED to the end of the frame — so inside one frame the
## grid holds the previous fill AND the new one. Reading it raw made every filter
## look like it did nothing at all (the first run of this case "found" every weapon
## in the game on the chip shelf). In play a frame always elapses between refreshes,
## so this is a harness concern, not a product bug.
func _shop_tiles(screen: DockScreen) -> Array:
	var out: Array = []
	for t in screen._shop_grid.get_children():
		if t.is_queued_for_deletion():
			continue
		var c = t.get("comp")
		if c != null:
			out.append(c)
	return out


## CHECKS THE NODE ITSELF, then its children. It only walked children at first,
## which meant handing it the very Label you cared about reported "not found" —
## a false failure that looks exactly like a real one.
func _finds_text(root: Node, needle: String) -> bool:
	var own = root.get("text")
	if own != null and needle in str(own):
		return true
	for child in root.get_children():
		if child.is_queued_for_deletion():
			continue
		var txt = child.get("text")
		if txt != null and needle in str(txt):
			return true
		if _finds_text(child, needle):
			return true
	return false


## LEVEL IS THE MINIMUM PILOT LEVEL TO EQUIP (user, 2026-07-26).
##
## It started life as a shop-filter label. Making it a REQUIREMENT is the part with
## teeth, so this asserts the refusal itself rather than the number being drawn:
## a label nobody enforces and a gate nobody can see are different failures, and
## the first one is what this used to be.
func _case_level_gates_equipping() -> void:
	var screen := _fresh_dock(true)
	screen.refresh()

	# A blue mk1 part: level 5 by the grade+mark rule.
	var blue: ComponentDef = load("res://data/components/weapons/halberd_repeater.tres")
	var white: ComponentDef = load("res://data/components/weapons/junker_slugthrower.tres")
	_ok(int(blue.level) == 5, "Halberd Repeater is level 5 (got %d)" % int(blue.level))
	_ok(int(white.level) == 1, "Junker Slugthrower is level 1 (got %d)" % int(white.level))

	# Find a weapon hardpoint big enough that MARK can never be the reason it is
	# refused — otherwise this case could pass on the wrong error entirely.
	var slot := -1
	for i in screen.ship.build.hull.hardpoints.size():
		var hp: HardpointDef = screen.ship.build.hull.hardpoints[i]
		if hp.slot_type == HardpointDef.SlotType.WEAPON and hp.mark >= blue.mark:
			slot = i
			break
	_ok(slot >= 0, "the starter has a weapon hardpoint that fits a Mk%d" % blue.mark)
	if slot < 0:
		screen.queue_free()
		return

	var was := Wallet.xp
	Wallet.xp = 0                                   # level 1
	_ok(Pilot.level() == 1, "pilot is level 1 for the test (got %d)" % Pilot.level())
	var err := screen._fit_error(blue, slot)
	_ok(err != "", "a level-5 part is REFUSED to a level-1 pilot")
	_ok("level" in err.to_lower(), "...and the refusal says why: '%s'" % err)
	_ok(screen._fit_error(white, slot) == "", "a level-1 part still fits a level-1 pilot")

	# Earn the level and the same part becomes legal — the gate must OPEN, or it is
	# just a permanent ban wearing a level's clothes.
	Wallet.xp = Pilot.xp_for_level(5)
	_ok(Pilot.level() >= 5, "pilot reached level 5 (got %d)" % Pilot.level())
	_ok(screen._fit_error(blue, slot) == "",
		"the same part fits once the level is earned — got '%s'" % screen._fit_error(blue, slot))

	# THE STARTER MUST BE LEGAL AT LEVEL 1. It flies white and grey precisely so a
	# new pilot is never wearing gear they could not re-fit after a refit.
	Wallet.xp = 0
	for i in screen.ship.build.slots:
		var c: ComponentDef = screen.ship.build.slots[i]
		if c == null:
			continue
		_ok(int(c.level) <= 1,
			"starter part '%s' is level %d — a level-1 pilot could not re-fit it"
			% [c.display_name, int(c.level)])

	Wallet.xp = was
	screen.queue_free()


## THE SPINE IS ALWAYS ON SCREEN — including while it is deliberately waiting.
##
## THE FAILURE THIS IS FOR is the one that actually happened: a real save sat at
## `ember_word` for ~46 game days with the campaign invisible, and the Landing Bay
## banner was built in response. But the banner only spoke during a LIVE beat and
## went blank "when the campaign is idle between beats" — rare and brief at the
## time. Level-gated cold stretches make idle the campaign's NORMAL resting state,
## so the fix for the invisible-story bug would have reintroduced it by the front
## door, this time by design.
##
## So: whenever a campaign beat is merely being held back, the dock must say so.
## Silence is only allowed when there is genuinely nothing waiting.
func _case_the_campaign_banner_never_goes_silent() -> void:
	var screen := _fresh_dock(true)
	Quests.reset()
	Research.reset()
	var was := Wallet.xp

	# A beat whose prerequisite is DONE but which is gated behind a wait: nothing is
	# active, so the banner has no live step to show — and must fall back to the
	# reason rather than showing nothing at all.
	Quests.completed.append("legend_check_in")
	Quests.completed_day["legend_check_in"] = 0
	Research.day = 0                               # 3-day wait not yet served
	Quests.active.clear()

	_ok(Quests.current_step().is_empty(),
		"no beat is active — this is the state the banner used to go blank in")
	var cold := Quests.cold_beat()
	_ok(not cold.is_empty(), "the held beat is reported as cold")
	_ok(str(cold.get("step", "")) != "",
		"...and it explains itself rather than just naming a title")

	screen.refresh()
	_ok(_finds_text(screen._overview_text, "CAMPAIGN"),
		"the Landing Bay still shows the campaign line while the trail is cold — "
		+ "a blank banner is indistinguishable from a finished story")

	# ...and it must NOT invent one out of nothing. With the chain untouched there is
	# no held beat, so the banner stays quiet — otherwise it would nag from a new game.
	Quests.reset()
	Research.reset()
	_ok(Quests.cold_beat().is_empty(),
		"a fresh pilot with the chain not yet reached is NOT 'cold' — the campaign "
		+ "has not started, which is different from waiting")

	Wallet.xp = was
	Quests.reset()
	screen.queue_free()


## A STORY YOU HAVE STARTED STAYS IN THE LOG, even while it is resting.
##
## The log listed LIVE objectives only, so a spine between beats vanished from it —
## and an absent story reads identically to one never begun and one already
## finished. Level-gated cold stretches make resting the Campaign's normal state,
## so this is the invisible-story failure one surface deeper than the banner.
##
## Three states, and they must look different: not started (absent), started and
## resting (present, "to be continued"), finished (absent again).
func _case_started_spines_stay_in_the_log() -> void:
	Quests.reset()
	Research.reset()

	_ok(Quests.dormant_spines().is_empty(),
		"a fresh pilot has no dormant spines — nothing has been started, which is "
		+ "different from waiting")

	# Started, and resting: one Legend beat done, the next held by its 3-day wait.
	Quests.completed.append("legend_check_in")
	Quests.completed_day["legend_check_in"] = 0
	Research.day = 0
	var dormant := Quests.dormant_spines()
	_ok(dormant.size() == 1, "the started Campaign is listed while resting (got %d)"
		% dormant.size())
	if not dormant.is_empty():
		_ok(str(dormant[0].get("title", "")) != "", "the dormant spine is named")
		_ok(str(dormant[0].get("current", "")) != "",
			"...and carries a step line rather than an empty node")
		_ok(not dormant[0].has("key"),
			"a dormant spine has NO tracker key — otherwise the log would offer to "
			+ "star and reorder a thing that is not an objective")

	# With a beat ACTIVE the spine is represented by the beat itself, not doubled.
	Quests.active["legend_empty_cave"] = {"stage": 0, "count": 0}
	_ok(Quests.dormant_spines().is_empty(),
		"an active beat replaces the placeholder — the spine must not appear twice")

	Quests.reset()
	Research.reset()
