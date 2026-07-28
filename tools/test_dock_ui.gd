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
## zero assertions.
##
## IT HAS TO BE RAISED WITH THE SUITE, AND IT WAS NOT. It sat at 90 while the
## suite grew to ~670, so any run that died four-fifths of the way through still
## passed — observed live on 2026-07-27, printing "ALL PASS (139 checks)" off a
## dependency that had failed to compile. A floor set to a seventh of the real
## count is decoration. Bump this whenever you add a case; the number below is
## deliberately close to the real total so that forgetting is LOUD rather than
## silent.
const MIN_CHECKS := 650

var _fails: Array[String] = []
var _checks := 0


func _ready() -> void:
	# AS CALLABLES, so each case can be checked for having actually produced
	# assertions. A case that dies on its first line used to vanish without trace:
	# the suite simply reported a smaller number and called it a pass.
	var cases: Array[Callable] = [
		_case_station_talk_appears_on_arrival,
		_case_trade_lesson_waits_for_ruel,
		_case_planet_talk_appears_on_arrival,
		_case_every_home_tab_can_host_its_person,
		_case_office_door_is_earned,
		_case_the_addressee_ranks_quest_business_first,
		_case_the_desk_and_the_greeting_agree,
		_case_a_shut_board_still_closes_work_you_took,
		_case_an_authored_conversation_survives_the_addressee,
		_case_office_shows_tree_and_terms,
		_case_commission_never_joins_on_one_click,
		_case_every_leader_has_a_room,
		_case_secret_commissions_never_leak,
		_case_the_privateer_is_earned_at_the_shoal,
		_case_no_trust_no_shelf,
		_case_a_stocked_row_states_its_price_of_entry,
		_case_the_meter_measures_the_rung_being_climbed,
		_case_a_venue_can_speak,
		_case_a_bespoke_venue_drains_every_held_talk,
		_case_the_shoal_lesson_arms_off_pirate_standing,
		_case_withheld_abilities_are_not_on_sale,
		_case_withholding_is_all_or_nothing,
		_case_ability_tooltips_carry_numbers,
		_case_office_door_is_taught,
		_case_informational_lessons_do_not_starve_the_queue,
		_case_turn_in_is_signalled,
		_case_filler_never_preempts_an_objective,
		_case_leader_line_never_crosses_its_target,
		_case_same_npc_keeps_talking,
		_case_all_held_talks_play_in_one_sitting,
		_case_talk_to_odessa_does_quest_first,
		_case_every_npc_desk_is_uniform,
		_case_quest_log_is_the_tracker,
		_case_the_action_sits_on_the_contract,
		_case_the_lab_puts_the_spend_on_the_project,
		_case_the_shipyard_is_a_shop_shelf,
		_case_a_ship_is_worth_what_is_bolted_to_it,
		_case_no_counter_pays_back_what_it_charges,
		_case_demand_moves_prices_without_breaking_anything,
		_case_armory_filters,
		_case_the_armory_sells_from_your_own_shelf,
		_case_level_gates_equipping,
		_case_the_campaign_banner_never_goes_silent,
		_case_started_spines_stay_in_the_log,
		_case_contracts_credit_their_giver_guild,
		_case_gem_bar_never_starts_crossed_out,
		_case_odessa_has_no_dead_ask,
		_case_every_equipment_surface_describes_parts,
		_case_hulls_are_graded_gear,
		_case_lessons_stay_at_their_own_venue,
		_case_every_lesson_is_completable,
		_case_a_refused_turn_in_says_so,
	]
	for c in cases:
		var before := _checks
		c.call()
		if _checks == before:
			_fails.append("case %s asserted NOTHING — it died before its first check "
				% c.get_method() + "(look for a SCRIPT ERROR above)")

	if _checks < MIN_CHECKS:
		# NAME THE DEAD CASE FIRST. Quitting on the count alone tells you the suite
		# broke but not where, and the per-case "asserted NOTHING" line is usually
		# pointing straight at it.
		for f in _fails:
			printerr("  FAIL: %s" % f)
		# The two literals are joined BEFORE formatting. Written as `"a " + "b" % args`
		# the `%` binds tighter than the `+`, so it formatted the second literal —
		# which has no placeholders — and the numbers never reached the message. Same
		# shape as the %d/%d that printed raw on every dock screen for months.
		printerr(("test_dock_ui: RAN ONLY %d CHECKS (expect >= %d) — a case aborted, "
			+ "probably a parse/runtime error above. NOT a pass.") % [_checks, MIN_CHECKS])
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

## EVERY REJECTION IS VISIBLE (project convention) — including the ones the UI
## thinks it has already prevented.
##
## MissionLog.complete() returns a REASON on refusal ("...isn't finished yet.",
## "...turns in elsewhere.", "No such contract."), and all three boards gate the
## button on the same conditions — so the refusal path only runs when the world
## moved between the last refresh and the click. That is precisely when a dead
## button is most confusing, and two of the three boards had `_flash(r.msg)`
## INSIDE `if r.ok`, so the press did nothing at all: no sound, no message.
## scenes/ground/board_view.gd was the copy that got it right, with a comment
## naming the convention.
##
## Asserted BOTH ways: the real screen actually says something, and no board is
## structurally able to swallow the reason again.
func _case_a_refused_turn_in_says_so() -> void:
	var screen := _fresh_dock(true)          # the STATION
	screen.refresh()
	var kept := MissionLog.active.duplicate(true)
	MissionLog.active.clear()

	# Complete (n = 0 delivered of 0) but turns in AT THE COLONY. The button would
	# be disabled here; a stale index or a mid-refresh change reaches this anyway.
	MissionLog.active.append({"type": "delivery", "good": "circuits", "n": 0,
		"reward": 100, "turn_in": "planet", "venue": "station", "desc": "test run"})
	screen._on_turn_in(0)
	_ok(screen._flash_msg != "",
		"a refused turn-in tells the player something instead of doing nothing")
	_ok(screen._flash_msg.contains("elsewhere"),
		"...and says WHY — that it turns in elsewhere (got: %s)" % screen._flash_msg)
	_ok(MissionLog.active.size() == 1, "the refused contract is still in the log")

	# A stale index — the other way this path is reached in practice.
	screen._on_turn_in(99)
	_ok(screen._flash_msg != "", "a stale turn-in index is reported, not ignored")

	MissionLog.active.clear()
	for m in kept:
		MissionLog.active.append(m)
	screen.queue_free()

	# STRUCTURAL, so the NEXT board cannot repeat it. Every file that calls
	# MissionLog.complete must report the result at the SAME indent as `if r.ok:` —
	# i.e. unconditionally — rather than nested inside the success branch.
	#
	# FOLLOW THE CODE WHERE IT MOVED (2026-07-27). The bespoke boards adopted
	# VenueLayout, so prospect_deck no longer calls complete() at all — the shell does,
	# once, for every venue on it. Scanning the old file would have kept "passing" while
	# checking a function that no longer exists, so the list names the shell instead. A
	# structural test has to be re-aimed when the structure changes, or it quietly stops
	# guarding anything.
	for path in ["res://scenes/ui/dock_screen.gd", "res://scenes/ui/venue_layout.gd",
			"res://scenes/ground/board_view.gd"]:
		var src := FileAccess.get_file_as_string(path)
		_ok(src.contains("MissionLog.complete("),
			"%s still turns contracts in through the shared path" % path.get_file())
		var lines := src.split("\n")
		# ANCHOR ON complete(), NOT on the first `if r.ok:`. Every one of these files
		# has an earlier r.ok — the ACCEPT handler — and anchoring there measured the
		# wrong function in all three (board_view passed only by luck, because its
		# accept path happens to report unconditionally too).
		var guard := -1
		var indent := ""
		var reported := false
		var seen_complete := false
		for i in lines.size():
			var line: String = lines[i]
			if line.contains("MissionLog.complete("):
				seen_complete = true
			if guard < 0:
				if seen_complete and line.strip_edges() == "if r.ok:":
					guard = i
					indent = line.substr(0,
						line.length() - line.strip_edges(true, false).length())
				continue
			# Blank lines and COMMENTS are not the report — and stopping on a comment
			# at the guard indent is how the first draft of this check failed the very
			# fix it was written for.
			var bare := line.strip_edges()
			if bare == "" or bare.begins_with("#"):
				continue
			var here := line.substr(0, line.length() - line.strip_edges(true, false).length())
			if here.length() > indent.length():
				continue                      # still inside the ok branch
			if here.length() < indent.length():
				break                         # left the function without reporting
			# `flash(` not `_flash(` — the venue shell's is PUBLIC (its hosts call it),
			# and matching only the private spelling would have read a correct report as
			# a missing one. The shorter needle still matches both.
			if line.contains("flash(") or line.contains("_report("):
				reported = true
			break
		_ok(reported,
			"%s reports the outcome OUTSIDE `if r.ok:` — a refusal must not be silent"
				% path.get_file())

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


## THE FRONT DOOR (docs/person_as_context.md, step 3). Everything a person will do with
## you is ONE ranked list, and campaign business sits at the top of it.
##
## THE CLAIM IS NOT "the talk is offered" — it is "the talk is offered FIRST". Being
## present but further down is exactly how ember_word got lost for ~46 game-days: the
## talk was queued correctly the whole time, behind a button that answered first.
## So the fixture stacks the deck against it — Ruel holds a campaign talk AND a
## commission invitation, which is also gold and also wants the top line.
func _case_the_addressee_ranks_quest_business_first() -> void:
	# The RULE, with the host listing its offers in the wrong order on purpose.
	var jumbled := [
		Addressee.offer("office", "About the commission.", Addressee.Kind.DOOR),
		Addressee.offer("board", "Anything on the board?", Addressee.Kind.SERVICE),
		Addressee.offer("quest", "About the Meridian.", Addressee.Kind.QUEST),
	]
	var order := Addressee.ranked(jumbled)
	_ok(order.size() == 3 and str(order[0].id) == "quest",
		"quest business sorts first however the host happened to list it")
	_ok(str(order[1].id) == "board" and str(order[2].id) == "office",
		"...and everything behind it keeps the host's own order")
	_ok(Addressee.style_of(order[0]) == "primary",
		"story business is gold — the campaign always reads as a moment that matters")
	_ok(Addressee.style_of(order[1]) == "secondary",
		"an ordinary service is not gold, or gold would stop meaning anything")

	# And THROUGH THE REAL DESK, because a correct rule nobody calls is a failure this
	# project has already paid for.
	var screen := _fresh_dock(true)
	Standing.reset()
	Pilot.profession = ""
	Standing.add("guardian", Standing.INVITE_AT)   # a gold invitation, competing
	screen.refresh()
	screen._held_talks["ruel"] = [{"quest": "Standing With the Board", "giver": "ruel",
		"text": "Two jobs, cleanly done."}]

	var panel := _addressee(screen, "ruel")
	_ok(panel != null, "the desk opens Ruel's addressee")
	var said := _choice_texts(panel, [])
	_ok(said.size() >= 3,
		"he offers the talk, the commission and a way out — %s" % str(said))
	_ok(said.size() > 0 and "Standing With the Board" in str(said[0]),
		"the queued campaign talk is the FIRST thing he says, above the invitation")
	# The greeting must not contradict the list under it. "Board's quiet for you" over
	# a gold quest line tells the player two opposite things at once.
	_ok(not _find_text(panel, "Board's quiet"),
		"and he doesn't open with 'nothing pressing' while holding a job for you")
	_dispose(screen, panel)
	screen.queue_free()


## YOU CAN ALWAYS FINISH WHAT YOU AGREED TO. The old board carried this rule explicitly —
## it returned early when shut, so work you had ALREADY TAKEN became unturnable-in the
## moment your standing slipped below the posting line, and the job sat in your log with
## nowhere on the map to close it.
##
## MOVING THE BOARD BEHIND THE PERSON PUT THAT RULE BACK AT RISK IN A NEW WAY: if the
## offer to talk about work appears only while the board is OPEN, the whole screen that
## closes a contract becomes unreachable — the same bug, one level up, and invisible
## because the board itself is still perfectly correct.
func _case_a_shut_board_still_closes_work_you_took() -> void:
	var ship := TestShip.new()
	add_child(ship)
	ship.apply_build(SampleBuilds.get_build(SampleBuilds.current))
	var bar := SpeakEasy.new(ship)
	add_child(bar)
	bar.visible = true
	Standing.reset()
	Pilot.profession = ""
	MissionLog.active.clear()
	MissionLog.ensure_offers()

	# Banner up, take one of her jobs.
	Standing.add("privateer", SpeakEasy.WORK_AT - Standing.get_points("privateer"))
	bar.refresh()
	var posted := MissionLog.offers_at("shoal", "The Speak's Easy")
	_ok(not posted.is_empty(), "she has work posted to take")
	if posted.is_empty():
		bar.queue_free()
		ship.queue_free()
		return
	MissionLog.take(int(posted[0].index))
	_ok(MissionLog.active.size() == 1, "the contract is in hand")

	# Now fall back under her banner — a truce guest again, holding her job.
	Standing.add("privateer", -50 - Standing.get_points("privateer"))
	bar.refresh()
	var talk := _venue_talk(bar)
	_ok(_find_button(talk, "Anything on the board") == null,
		"her board is shut again — she posts nothing to a guest")
	var closing := _find_button(talk, "close out")
	_ok(closing != null,
		"...but the work you already took can still be reached, in different words")
	var work := _take_offer(bar, talk, "close out")
	_ok(work != null and _find_text(work, str(MissionLog.active[0].desc)),
		"...and the contract is on the screen that closes it")
	if work != null:
		work.free()
	MissionLog.active.clear()
	bar.queue_free()
	ship.queue_free()


## AN AUTHORED CONVERSATION IS NOT A SERVICE, and the addressee must not eat one. Doug is
## the game's mining teacher and Dialogues.DOUG_DECK is a real branching tree — folding it
## into a one-line reply would have deleted the only place the game explains that a gun
## chips a rock and a cutter opens it. It becomes ONE OFFER in his list instead, which is
## the same merge Odessa's bar chat is still waiting for.
func _case_an_authored_conversation_survives_the_addressee() -> void:
	var ship := TestShip.new()
	add_child(ship)
	ship.apply_build(SampleBuilds.get_build(SampleBuilds.current))
	var deck := ProspectDeck.new(ship)
	add_child(deck)
	deck.visible = true
	deck.refresh()

	var talk := _venue_talk(deck)
	_ok(talk != null, "Doug is always talkable — he is the game's mining teacher")
	var ask := _find_button(talk, "about the rock")
	_ok(ask != null, "his mining lesson is one of the things he'll do with you")
	_dispose(deck, talk)
	if ask != null:
		ask.pressed.emit()
		var lesson := _live_panel(deck)
		# THE WHOLE TREE, not a flattened line: DOUG_DECK's opening node, and more than
		# one way on from it. A one-choice panel would be the flattening this guards.
		_ok(lesson != null and _find_text(lesson,
			str((Dialogues.DOUG_DECK["start"] as Dictionary).text).substr(0, 24)),
			"...and taking it opens his authored tree, not a canned reply")
		_ok(lesson != null and _choice_texts(lesson, []).size() > 1,
			"...with its branches intact")
		_dispose(deck, lesson)
	deck.queue_free()
	ship.queue_free()


## A SCREEN MUST NOT CONTRADICT ITSELF. The desk outside says whether someone is holding
## something for you; the greeting inside says the same thing in their own voice. Found
## in a screenshot, not a test: the desk read "They have an offer for you" while Ruel
## opened with "Board's quiet for you right now" — because only the desk counted a
## waiting invitation as news. Both halves were individually correct, which is exactly
## why nothing caught it. So the claim is about AGREEMENT, and the fixture is the case
## where they disagreed: an invitation and NO queued talk.
func _case_the_desk_and_the_greeting_agree() -> void:
	var screen := _fresh_dock(true)
	Standing.reset()
	Pilot.profession = ""
	Standing.add("guardian", Standing.INVITE_AT)
	screen.refresh()
	_ok((screen._held_talks.get("ruel", []) as Array).is_empty(),
		"the fixture is an INVITATION alone — no queued talk propping it up")
	_ok(screen._has_news("ruel"),
		"an earned invitation counts as news, so the desk lights for it")

	var panel := _addressee(screen, "ruel")
	_ok(not _find_text(panel, "Board's quiet"),
		"...and he does not greet you with 'nothing pressing' while holding one")
	_dispose(screen, panel)

	# The other direction: nothing waiting, and the quiet greeting is correct again.
	Standing.reset()
	screen.refresh()
	_ok(not screen._has_news("ruel"), "with nothing waiting the desk goes quiet")
	var idle := _addressee(screen, "ruel")
	_ok(_find_text(idle, "Board's quiet"),
		"...and he says so, rather than promising news he doesn't have")
	_dispose(screen, idle)
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
	# The door is a LINE HE SAYS now, not a button beside him — so the question is
	# what Ruel offers when you walk up, and the absence has to be read off a panel
	# that definitely opened, or "no door" and "no conversation" look identical.
	var before := _addressee(screen, "ruel")
	_ok(before != null, "Ruel always talks to you — the desk is never a dead click")
	_ok(not _find_button(before, "About the commission"),
		"no commission offered before an invitation is earned")
	_dispose(screen, before)

	Standing.add("guardian", Standing.INVITE_AT)
	screen.refresh()
	var after := _addressee(screen, "ruel")
	var door := _find_button(after, "About the commission")
	_ok(door != null,
		"Ruel offers the commission once standing earns the invitation")
	if door != null:
		# Taking him up on it must actually go somewhere — and must not leave the
		# conversation parked underneath the room it just opened.
		door.pressed.emit()
		_ok(_find_office(screen) != null, "...and taking him up on it opens the office")
		_ok(after.is_queued_for_deletion(),
			"...and the conversation steps aside instead of waiting behind it")
	_dispose(screen, after)
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
##
## TESTED WITHOUT A SECRET IN THE GAME (2026-07-27). This used to walk LIST for anything
## `hidden`, and the Privateer was the only one — reopening it emptied the loop, so the
## case would have reported ALL PASS while asserting nothing. A fixture cannot be pushed
## into LIST either: it is `const`, and Godot makes const collections read-only.
##
## So the rule is asked of an INJECTED roster (Professions.visible_in), and the live list
## is asserted to be consistent with it. The machinery stays verified between secrets,
## which is exactly when a refactor is most likely to quietly undo it.
func _case_secret_commissions_never_leak() -> void:
	var ghost := {"id": "zzz_test_secret", "hidden": true, "name": "Sable Cabal"}
	var open_one := {"id": "zzz_test_open", "name": "Open Guild"}
	var shown := Professions.visible_in([ghost, open_one])
	_ok(not shown.has(ghost), "a hidden commission is filtered out of the advertised list")
	_ok(shown.has(open_one), "...and an ordinary one is not — the filter is not just empty")
	_ok(Professions.visible_in([]).is_empty(), "an empty roster advertises nothing")

	# THE LIVE LIST AGREES WITH THE RULE. This is what catches a refactor that starts
	# hand-rolling the filter somewhere instead of asking for it.
	_ok(Professions.visible().size() == Professions.visible_in(Professions.LIST).size(),
		"visible() is the same filter applied to the real roster")
	for p in Professions.LIST:
		var pid := str(p.id)
		_ok(Professions.hidden(pid) != Professions.visible().has(p),
			"%s is advertised iff it is not hidden" % pid)
		# A HIDDEN COMMISSION'S DOOR STAYS SHUT to an over-qualified pilot, and an open
		# one's does not. Both directions, so "the door never opens" would fail too.
		Standing.reset()
		Pilot.profession = ""
		# TO a level, not BY an amount. `add(INVITE_AT * 3)` assumed every ledger opens at
		# zero; the Shoal's opens at -100 (Standing.OPENING), so +30 left the pilot at -70
		# and this asserted a door was shut for the wrong reason entirely.
		Standing.add(pid, Standing.INVITE_AT * 3 - Standing.get_points(pid))
		_ok(Standing.eligible(pid), "...%s test pilot is genuinely over-qualified" % pid)
		_ok(Professions.office_open(pid) != Professions.hidden(pid),
			"%s's door opens to an over-qualified pilot iff it is not a secret" % pid)


## THE PRIVATEER IS REOPENED (2026-07-27, user: "I closed the Privateer profession before
## building a demo to keep it secret. I would like to reopen it now and restore access to
## unlock it via missions from the Shoal.")
##
## Reopening a commission by DELETING A FLAG is only correct if something else was already
## holding the door. This asserts that something is the standing ledger — every rung of the
## Shoal ladder, and the board that pays the last one.
func _case_the_privateer_is_earned_at_the_shoal() -> void:
	_ok(not Professions.hidden("privateer"), "the Privateer commission is no longer secret")
	var ids := []
	for p in Professions.visible():
		ids.append(str(p.id))
	_ok(ids.has("privateer"), "...and it is advertised like any other commission")

	# THE LADDER IS THE GATE. A pilot who has never been to the Shoal opens at -100 from
	# Standing.OPENING, so no amount of lawful play can ever reach the door.
	Standing.reset()
	Pilot.profession = ""
	_ok(Standing.get_points("privateer") == -100,
		"a pilot who has never met the Shoal opens at war with them")
	_ok(not Professions.office_open("privateer"),
		"The Back Room is shut to a pilot who has never met the Shoal")
	Standing.add("privateer", 50)                      # Krayt's truce
	_ok(not Professions.office_open("privateer"),
		"...still shut under Krayt's truce — a truce is not a commission")
	Standing.add("privateer", 50)                      # Vyper's banner
	_ok(Standing.get_points("privateer") >= SpeakEasy.WORK_AT,
		"Vyper's banner opens her contract board")
	_ok(not Professions.office_open("privateer"),
		"...but the commission is still ahead of you at 0")
	Standing.add("privateer", Standing.INVITE_AT)      # her work
	_ok(Professions.office_open("privateer"),
		"running Vyper's work to INVITE_AT opens The Back Room")

	# AND THERE IS WORK TO RUN. A ladder whose top rung needs standing that no board pays
	# is a locked door with the key drawn on it — that was the actual gap: the fence opens
	# at Friendly (100) and the quartermaster at commissioned, so a pilot at 0 could see
	# both and reach neither.
	MissionLog.ensure_offers()   # top-up only; safe to call after any earlier case
	var posted := MissionLog.offers_at("shoal", "The Speak's Easy")
	_ok(posted.size() >= 3, "Vyper posts work at the Speak's Easy (%d)" % posted.size())
	for entry in posted:
		_ok(MissionLog.faction_for(entry.m) == "privateer",
			"...crediting Privateer standing, not the Board's")
		_ok(MissionLog.venue_ok_at(entry.m, "shoal"),
			"...handed in at the Shoal")
		_ok(not MissionLog.venue_ok_at(entry.m, "station"),
			"...and never filed with the Board at the station")

	# AND IT IS ON SCREEN. The model above can be perfectly correct while the bar draws
	# nothing — that is the Imari-on-the-pad bug, and it is why this project tests real
	# screens. Build the actual Speak's Easy and walk it for the control a player clicks.
	var ship := TestShip.new()
	add_child(ship)
	ship.apply_build(SampleBuilds.get_build(SampleBuilds.current))
	var bar := SpeakEasy.new(ship)
	add_child(bar)
	bar.visible = true          # refresh() early-returns on a hidden screen

	# THE LADDER IS NOW READ OFF WHAT SHE OFFERS. The board, the shelf and the back room
	# stopped being columns on this screen in the person-as-context pass — they are lines
	# in Vyper's own list — so the question "can the player reach it" is asked by walking
	# up to her, which is also the only way a player can ask it.
	Standing.reset()
	Pilot.profession = ""
	Standing.add("privateer", -50 - Standing.get_points("privateer"))   # Krayt's truce
	bar.refresh()
	var guest := _venue_talk(bar)
	_ok(guest != null, "Vyper always talks — a guest can still stand at the bar")
	_ok(_find_button(guest, "Anything on the board") == null,
		"under Krayt's truce she offers no work — you are a guest, not crew")
	_ok(_find_button(guest, "About the commission") == null,
		"...and The Back Room is not mentioned")
	_dispose(bar, guest)

	Standing.add("privateer", 50)                                      # Vyper's banner
	bar.refresh()
	var crew := _venue_talk(bar)
	_ok(_find_button(crew, "Anything on the board") != null,
		"Vyper's banner puts a job on the board")
	_ok(_find_button(crew, "About the commission") == null,
		"...but The Back Room is still shut at 0 — the work comes first")
	# AND THE BOARD IS REALLY BEHIND IT: her postings, in the shared Mission Computer.
	var work := _take_offer(bar, crew, "Anything on the board")
	_ok(work != null, "...and asking opens her board")
	if work != null:
		_ok(_find_text(work, str(MissionLog.offers_at("shoal", "The Speak's Easy")[0].m.desc)),
			"...with her own postings on it, not the station's")
		_ok(_find_button(work, "Back to Vyper") != null,
			"...and the way out returns to her, not to the room")
		work.free()

	Standing.add("privateer", Standing.INVITE_AT)                       # her work, run
	bar.refresh()
	var trusted := _venue_talk(bar)
	_ok(_find_button(trusted, "About the commission") != null,
		"at INVITE_AT the door to The Back Room is drawn at the bar")
	_dispose(bar, trusted)
	bar.queue_free()
	ship.queue_free()


## THE TRUST RULE (user, 2026-07-27): "hide the entire tab to someone the quartermaster
## doesn't trust enough to see the shop."
##
## HIDDEN MEANS ABSENT, and that is the whole assertion. A greyed shelf, or a heading
## over a "take the colors first" caption, is still a shop the player cannot use — which
## is the DEMO POLISH RULE inverted, and it advertises a faction's inventory as a reward
## before they have any reason to want it. The bar USED to do exactly that.
##
## VISIBILITY, NOT EXISTENCE. The heading is hidden rather than freed, so `_find_text`
## alone passes for the wrong reason and would keep passing if the hiding broke — the
## same trap that made a "Take the job" assertion vacuous last session.
func _case_no_trust_no_shelf() -> void:
	var ship := TestShip.new()
	add_child(ship)
	ship.apply_build(SampleBuilds.get_build(SampleBuilds.current))
	var bar := SpeakEasy.new(ship)
	add_child(bar)
	bar.visible = true
	Standing.reset()
	Pilot.profession = ""

	# Every rung BELOW trust, including the two where the player is already welcome.
	# ABSENT NOW MEANS SHE DOES NOT OFFER IT: the shelf moved behind Vyper, so "not on
	# screen" is the wrong question — a screen it was never on would pass that forever.
	# The question is whether she will show it to you when you ask her for gear.
	for below in [-50, SpeakEasy.WORK_AT, Standing.INVITE_AT - 1]:
		Standing.add("privateer", below - Standing.get_points("privateer"))
		bar.refresh()
		var talk := _venue_talk(bar)
		_ok(talk != null, "she is talkable at standing %d" % below)
		_ok(_find_button(talk, "on the shelf") == null,
			"at standing %d she does not offer the shelf at all" % below)
		_ok(not _find_visible_text(bar, "QUARTERMASTER"),
			"...and it is nowhere on the room behind her either")
		for ware in Professions.wares("privateer"):
			if not ResourceLoader.exists(str(ware)):
				continue
			var comp: ComponentDef = load(str(ware))
			_ok(not _find_visible_text(bar, comp.display_name),
				"...nor is %s, which they cannot buy" % comp.display_name)
			break        # one ware proves the shelf; loading all three per rung is waste
		_dispose(bar, talk)

	# THE VENUE PUBLISHES ITS OWN TUTOR CONTEXT. `Tutor.safe` is written by the FLIGHT
	# tick, so a dock screen that does not assert it inherits whatever was true at the
	# moment of docking — dock while something is hunting you and it stays FALSE, dwell
	# timers stop, and every lesson behind the active one starves. DockScreen and the
	# Verge deck each learned this the hard way; the Speak's Easy never asserted it at
	# all, so the newest venue shipped with the oldest bug. It is the shell's job now,
	# which is why no venue can forget it again.
	Tutor.safe = false
	Tutor.venue = "station"
	bar.refresh()
	_ok(Tutor.safe, "the venue asserts a safe tutor context instead of inheriting flight's")
	_ok(Tutor.venue == "shoal", "...and names itself, so station-only lessons stay home")

	# AND IT OPENS. A gate that is always shut is indistinguishable from a missing
	# feature, so the same walk must find the shelf the moment trust lands.
	Standing.add("privateer", Standing.INVITE_AT - Standing.get_points("privateer"))
	bar.refresh()
	var open_talk := _venue_talk(bar)
	_ok(_find_button(open_talk, "on the shelf") != null,
		"at INVITE_AT she offers the shelf — trust and the back room arrive together")
	var shelf := _take_offer(bar, open_talk, "on the shelf")
	_ok(shelf != null and _find_text(shelf, "QUARTERMASTER"),
		"...and asking for gear actually opens her counter")
	if shelf != null:
		shelf.free()
	bar.queue_free()
	ship.queue_free()


## "show the faction required to purchase the item and the currency required" (user).
## Nothing on a counter may be a silent refusal: a row the pilot cannot buy says WHY in
## words, and every row names what it costs.
func _case_a_stocked_row_states_its_price_of_entry() -> void:
	var ship := TestShip.new()
	add_child(ship)
	ship.apply_build(SampleBuilds.get_build(SampleBuilds.current))
	var bar := SpeakEasy.new(ship)
	add_child(bar)
	bar.visible = true
	Standing.reset()
	Pilot.profession = ""
	Standing.add("privateer", Standing.INVITE_AT - Standing.get_points("privateer"))
	bar.refresh()

	# An INVITED but UNCOMMISSIONED pilot: she will show the shelf, and every ware on it
	# is locked behind the commission she offers in the same breath. That is the pull the
	# adjacency exists to create, and it only works if the row says so out loud.
	var counter := _take_offer(bar, _venue_talk(bar), "on the shelf")
	_ok(counter != null, "she shows an invited pilot the counter")
	_ok(counter != null and _find_text(counter, "requires"),
		"a ware they cannot buy states its requirement in words, not a dead button")
	# THE ACTUAL PRICE, not merely "a lowercase c somewhere on the screen" — which the
	# word "credits" in the header satisfied, and which no sabotage of the price could
	# ever have failed.
	var priced := ""
	for ware in Professions.wares("privateer"):
		if ResourceLoader.exists(str(ware)):
			priced = VenueLayout.price_text(
				int(ItemVisuals.buy_price(load(str(ware))) * SpeakEasy.QUART_MARKUP))
			break
	_ok(priced != "" and counter != null and _find_text(counter, priced),
		"...and every row names its price, at her markup (%s)" % priced)
	if counter != null:
		counter.free()

	# THE CURRENCY IS NAMED BY ONE FUNCTION. Faction scrip does not exist yet and must
	# not be invented by a layout pass — but the day it does, this is the only place
	# that has to learn about it.
	_ok(VenueLayout.price_text(180) == "180c", "credits print as credits")
	_ok(VenueLayout.price_text(4, "insight") == "4 Insight",
		"...and a second currency is NAMED, never assumed to be credits")

	# The rule itself, without a screen. NAME THE REASON, not merely "refused": these
	# wares are level 5 and the harness pilot is level 1, so BOTH gates are unmet at
	# once and an assertion that only checks `met == false` passes with the commission
	# check deleted outright — verified by sabotage, which is how this was caught.
	# WHICH reason is shown also matters to the player: the commission is the binding
	# one and its door is standing right beside the shelf.
	for ware in Professions.wares("privateer"):
		if not ResourceLoader.exists(str(ware)):
			continue
		var comp: ComponentDef = load(str(ware))
		var locked := VenueLayout.requirement(comp, "privateer", "privateer")
		_ok(not bool(locked.met), "%s refuses an uncommissioned pilot" % comp.display_name)
		_ok("commission" in str(locked.text),
			"...naming THE COMMISSION, the gate they can act on (%s)" % str(locked.text))

		# And with the commission held, the level gate speaks for itself rather than
		# the row going quiet or claiming to be buyable.
		var held := Pilot.profession
		Pilot.profession = "privateer"
		var levelled := VenueLayout.requirement(comp, "privateer", "privateer")
		Pilot.profession = held
		_ok(not bool(levelled.met), "...and a level-%d chip still refuses a level-%d pilot" % [
			int(comp.level), Pilot.level()])
		_ok("level" in str(levelled.text),
			"...naming the LEVEL once the commission is no longer the obstacle (%s)" % str(levelled.text))
	bar.queue_free()
	ship.queue_free()


## THE METER HAS TO MOVE. Scaled to Standing.MAX (1000) the bar did not visibly change
## anywhere on the Shoal's ladder — every rung that matters sits between -100 and 100,
## so a pilot running Vyper's contracts from 0 to 100 watched an empty bar the whole
## way and learned that the work does nothing. Measured rung-to-rung it fills across
## exactly the span being climbed.
##
## Pure + static, so the ladder is assertable without building a screen.
func _case_the_meter_measures_the_rung_being_climbed() -> void:
	var ladder := SpeakEasy.RUNGS
	var seen := []
	for p in [-100, -50, 0, 5, 12, 60, 100, 300, 499]:
		var c := VenueLayout.climb_to_next(ladder, p)
		_ok(not c.is_empty(), "at standing %d there is still a rung ahead" % p)
		_ok(float(c.frac) >= 0.0 and float(c.frac) <= 1.0,
			"...and the fill stays on the bar (%.2f)" % float(c.frac))
		seen.append(float(c.frac))

	# THE ASSERTION THAT WOULD HAVE CAUGHT THE BUG. Under the old MAX-scaled bar every
	# one of these rounded to the same empty cell; under this one they must differ.
	_ok(seen.max() - seen.min() > 0.5,
		"the bar visibly travels across the Shoal ladder (%.2f..%.2f)" % [
			seen.min(), seen.max()])

	# Progress is measured from the rung you PASSED, not from zero: at 60 you are most
	# of the way from 10 to 100, not 6% of the way to anything.
	var mid := VenueLayout.climb_to_next(ladder, 60)
	_ok(int(mid.to) == Standing.FRIENDLY_AT, "at 60 the next door is the fence")
	_ok(float(mid.frac) > 0.4, "...and it reads as most of the way there, not 6%%")

	# Hostile: the climb starts at the floor a written-off faction sits on, so Krayt's
	# truce reads as real, visible progress rather than a bar still pinned at nothing.
	var truce := VenueLayout.climb_to_next(ladder, -50)
	_ok(float(truce.frac) > 0.3, "Krayt's truce shows as ground gained (%.2f)" % float(truce.frac))

	# The top of the ladder is the one place with nothing ahead.
	_ok(VenueLayout.climb_to_next(ladder, Standing.ALLIED_AT).is_empty(),
		"at the top rung there is nothing left to climb")


## EVERY REJECTION MUST BE VISIBLE (project rule), and at a dock the flight HUD is not
## listening: flight_hud hides `_center_note` whenever the ship is docked. So the
## Speak's Easy was writing every refusal — "Not enough credits", "Mission log full",
## every turn-in result, every quest note from Krayt's table — into a hidden label. The
## screen was mute and nothing said so.
##
## THE ASSERTION IS ON SCREEN, not on the call: `ship._flash_note` was being CALLED
## correctly the whole time. Only a walk of the real control tree can tell the
## difference between "said it" and "said it where nobody could hear".
func _case_a_venue_can_speak() -> void:
	var ship := TestShip.new()
	add_child(ship)
	ship.apply_build(SampleBuilds.get_build(SampleBuilds.current))
	var bar := SpeakEasy.new(ship)
	add_child(bar)
	bar.visible = true
	Standing.reset()
	bar.refresh()

	_ok(not _find_visible_text(bar, "Not enough credits"),
		"the venue says nothing it has not been asked to say")
	bar._venue.flash("Not enough credits (180c needed).")
	_ok(_find_visible_text(bar, "Not enough credits"),
		"a refusal is VISIBLE on the venue itself, not on the hidden flight note")

	# AND IT DOES NOT GO STALE. A message that survives the next redraw becomes a lie
	# the moment the state it described changes.
	bar.refresh()
	_ok(not _find_visible_text(bar, "Not enough credits"),
		"...and is said once, then cleared")
	bar.queue_free()
	ship.queue_free()


## HEAR EVERYTHING THEY ARE HOLDING, IN ONE VISIT — the station learned this in
## 2026-07-22 ("Standing With the Board" sat un-started behind a second click on the
## same button) and the bespoke venues were written afterwards WITHOUT the fix, each
## popping a single talk. Vyper holds a debrief and the next briefing at the same
## moment for exactly the same reason Ruel does.
func _case_a_bespoke_venue_drains_every_held_talk() -> void:
	var ship := TestShip.new()
	add_child(ship)
	ship.apply_build(SampleBuilds.get_build(SampleBuilds.current))
	var bar := SpeakEasy.new(ship)
	add_child(bar)
	bar.visible = true
	Standing.reset()
	bar.refresh()

	Quests.pending_talks.append({"giver": "vyper", "text": "First thing.", "quest": "a"})
	Quests.pending_talks.append({"giver": "vyper", "text": "Second thing.", "quest": "b"})
	_ok(bar._venue.talks.has_news("vyper"), "the desk knows she is holding something")
	_ok(bar._venue.talks.held_for("vyper").size() == 2, "...both of them")

	bar._venue.talks.drain("vyper")
	# Draining takes them out of the global queue, so a second click cannot re-serve
	# them — the old path popped one and left the other behind a redundant button.
	_ok(Quests.talks_for("vyper").is_empty(),
		"one visit clears her queue — no second click for the second thing")
	_ok(not bar._venue.talks.has_news("vyper"), "...and the news dot goes out")
	Quests.pending_talks.clear()
	bar.queue_free()
	ship.queue_free()


## "The tutor should trigger off pirate faction >= 0" (user, 2026-07-27). The Shoal's
## lesson arms off the ledger of the faction that owns the room, which is the only
## honest way to say "you are welcome here now" — Tutor.safe/venue predates factions.
func _case_the_shoal_lesson_arms_off_pirate_standing() -> void:
	var arm: Callable = Tutor._arm_pred.get("shoal_standing", Callable())
	_ok(arm.is_valid(), "the Shoal lesson has an arming predicate")
	if not arm.is_valid():
		return
	_ok(not arm.call({"venue": "shoal", "standing": -50}),
		"under Krayt's truce it stays quiet — you are a guest, not crew")
	_ok(arm.call({"venue": "shoal", "standing": 0}),
		"Vyper's banner at 0 is what wakes it")
	_ok(arm.call({"venue": "shoal", "standing": 140}), "...and it holds above that")
	_ok(not arm.call({"venue": "station", "standing": 500}),
		"a Guardian's good name never triggers the Shoal's lesson")
	# A missing key must be falsy, never a crash — the "can't jam" rule for predicates.
	_ok(not arm.call({}), "an empty context is simply not the Shoal")

	# AND THE VENUE PUBLISHES WHAT IT READS. A predicate polling a key nobody writes is
	# a lesson that can never arm; this is the half that is easy to forget.
	var ship := TestShip.new()
	add_child(ship)
	ship.apply_build(SampleBuilds.get_build(SampleBuilds.current))
	var bar := SpeakEasy.new(ship)
	add_child(bar)
	bar.visible = true
	Standing.reset()
	Standing.add("privateer", 20 - Standing.get_points("privateer"))
	bar.refresh()
	var c := bar._venue.context()
	_ok(str(c.get("venue", "")) == "shoal", "the venue names itself in its snapshot")
	_ok(int(c.get("standing", -1000)) == 20,
		"...and publishes the standing the predicate reads (%s)" % str(c.get("standing")))
	_ok(arm.call(c), "so the real snapshot arms the real lesson")
	bar.queue_free()
	ship.queue_free()


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
	var peek := _addressee(screen, "ruel")
	_ok(_find_button(peek, "About the commission") != null,
		"the dev unlock still opens doors for inspection")
	_dispose(screen, peek)
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
	var reg := {"station": {}, "planet": {}, "shoal": {}}
	var ping := {"station": {}, "planet": {}, "shoal": {}}
	var tabs := {"station": {}, "planet": {}, "shoal": {}}
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

	# THE BESPOKE VENUES ARE REAL SCREENS TOO. The Verge was skipped here with a
	# "checked by hand" comment, which meant a Shoal- or Verge-tagged lesson could name
	# an anchor nothing registers and ship — the exact class of authoring mistake this
	# whole case exists to catch, exempted at the two venues least likely to be noticed.
	# Now that VenueLayout registers a standard anchor set, building one is three lines
	# and every venue on the shell is validated the same way.
	Tutor._anchors.clear()
	var bar_ship := TestShip.new()
	add_child(bar_ship)
	bar_ship.apply_build(SampleBuilds.get_build(SampleBuilds.current))
	var bar := SpeakEasy.new(bar_ship)
	add_child(bar)
	bar.visible = true
	bar.refresh()
	for a in Tutor._anchors:
		reg["shoal"][str(a)] = true
	var bar_pings := {}
	_collect_pings(bar, bar_pings)
	ping["shoal"] = bar_pings
	# The shell's standard anchor set must actually be claimed and drawable, or a lesson
	# pointing at "the board" or "the meter" jams at every venue at once.
	for a in VenueLayout.ANCHORS:
		if a == "office_door":
			continue          # lazy: registers only once you have an invitation
		_ok(reg["shoal"].has(str(a)),
			"the venue shell registers '%s' at a bespoke venue" % a)
		_ok(bar_pings.has(str(a)),
			"...and mounts a ping overlay to draw it" % [])
	bar.queue_free()
	bar_ship.queue_free()

	# A STEP MAY NAME ONE ROW OF A LIST BY TEXT (`item`), and TutorPing matches it with
	# findn on the ROW'S text — which the mission board now SHORTENS (short titles left,
	# full text right). A needle that falls past the cut points at nothing: the caption
	# draws, the highlight frames the whole list, and the player is told to pick a
	# contract the tutor can no longer find. Checked against the shipped templates, so
	# it holds whichever three the board happens to be showing.
	for lid in Tutor.LESSONS:
		for st in Tutor.LESSONS[lid]:
			var want := str((st as Dictionary).get("item", ""))
			if want == "":
				continue
			# ONLY THE BOARDS THIS STEP CAN RUN AT. Scanning every template let a
			# station lesson be satisfied by a posting on VYPER'S board — a row the
			# player will never see from that step (caught by sabotage, 2026-07-27).
			var at := str((st as Dictionary).get("venue", ""))
			var posted := 0
			var survives := 0
			for t in MissionLog._templates:
				var d := str((t as Dictionary).get("desc", ""))
				if not (want in d):
					continue
				if at != "" and str((t as Dictionary).get("venue", "station")) != at:
					continue
				posted += 1
				if want in ContextScreen.short(d):
					survives += 1
			_ok(posted > 0, "lesson '%s' names row '%s' — a contract on that board says it" % [lid, want])
			_ok(posted > 0 and survives == posted,
				"...and every one of them still says it once the row is shortened (%d of %d)" % [survives, posted])

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
			_ok(venue in ["", "station", "planet", "verge", "shoal"],
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


## THE EMBER_WORD FREEZE, and the shape of its final fix. Odessa's bespoke "Talk to
## Odessa" button used to always open the bar rumour chat, ignoring a pending CAMPAIGN
## talk — so ember_word's "meet Odessa" beat sat un-advanced behind a redundant second
## button and the campaign froze for ~46 game-days in a real save.
##
## THE FIX IS NO LONGER "the quest PRE-EMPTS the bar" (2026-07-28). That was correct and
## still a special case somebody had to remember to write. She goes through the same
## ranking as everyone else now: her bar chat opens, with her campaign business as its
## FIRST line, in gold, above what she does for a living. So the claim to hold is
## ORDERING, not exclusion — and the sharper claim underneath it is that folding her into
## the pattern did not eat her: the authored tree is merged into, never replaced.
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
	var panel := _addressee(screen, "odessa")
	_ok(panel != null, "Talk to Odessa opens her bar conversation")
	var said := _choice_texts(panel, [])
	_ok(said.size() > 0 and "The Word at Ember Row" in str(said[0]),
		"her campaign business is the FIRST thing she offers")

	# HER TREE SURVIVED. These are ODESSA_BAR's own authored choices, and if the
	# addressee had replaced her conversation instead of folding into it they would be
	# gone — a fix that deletes the writing it was protecting.
	var authored: Array = (Dialogues.ODESSA_BAR["start"] as Dictionary).choices
	for c in authored:
		if str(c.get("action", "")) == "rumor":
			continue     # hidden unless she is actually holding one — its own rule
		_ok(_find_button(panel, str(c.text)) != null,
			"...and her own line \"%s\" is still on the list" % str(c.text))
	_ok(screen._bar_panel == panel, "the bar chat is what opened — not a generated menu")

	# Taking the quest line drains it, which is what lets ember_word advance.
	var take := _find_button(panel, "The Word at Ember Row")
	if take != null:
		take.pressed.emit()
	_ok((screen._held_talks.get("odessa", []) as Array).is_empty(),
		"taking it drains the held talk (ember_word can advance)")
	_dispose(screen, panel)

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


## THE ACTION SITS ON THE THING IT ACTS ON (docs/person_as_context.md, rules 2+3).
##
## Playtest 2026-07-27, the tester: "Where do I turn this in?" The Mission Computer
## had THREE columns — offers | in hand | quest log — and `Turn in (150c)` floated in
## the middle one, detached from the contract it closed, in a column that was 90%
## empty AND redundant: the quest log beside it listed the very same contract. The
## third column existed because it duplicated the second, so the action ended up
## attached to the throwaway copy.
##
## Asserted at the SHAPE level, not by finding a button somewhere on the tab: one
## list, each contract listed once, and the button a DESCENDANT of the detail panel
## that names the contract. A button that is merely "on the tab" is exactly what the
## tester couldn't find.
func _case_the_action_sits_on_the_contract() -> void:
	var screen := _fresh_dock(true)          # the STATION
	var kept := MissionLog.active.duplicate(true)
	MissionLog.active.clear()
	var desc := "Recover the Meridian's strongbox"
	# Finished (n = 0 of 0) and closes HERE.
	MissionLog.active.append({"type": "recovery", "n": 0, "reward": 140, "giver": "voss",
		"venue": "station", "turn_in": "station", "uid": 9001, "desc": desc})
	screen.refresh()
	var mc: MissionComputer = screen._missions
	mc._sel = "m:9001"
	mc.refresh()

	_ok(_count_lists(mc) == 1, "the mission computer shows exactly ONE list")
	_ok(_count_rows(mc.list, "Meridian's strongbox") == 1,
		"a held contract is listed once — not once per column")
	_ok(_find_text(mc, "to close here"),
		"the header answers 'where do I turn this in' before anything is clicked")

	var turn := _find_button(mc, "Turn in")
	_ok(turn != null, "the turn-in button exists")
	_ok(turn != null and not turn.disabled, "...and is live on a contract that closes here")
	_ok(turn != null and _is_descendant(turn, mc._detail),
		"...and lives in the detail panel, not floating in a column of its own")
	_ok(_find_text(mc._detail, desc),
		"...on a panel that names the contract it closes")

	# A DEAD BUTTON MUST SAY WHY. Greyed with nothing beside it is how a player ends
	# up asking where the turn-in is while looking straight at it.
	MissionLog.active[0]["turn_in"] = "planet"
	mc.refresh()
	var away := _find_button(mc, "Turn in")
	_ok(away != null and away.disabled, "a contract that closes elsewhere greys its button")
	_ok(_find_text(mc._detail, "the colony"), "...the panel says WHERE it closes")
	# PIN THE REASON, not the venue: the panel already names the colony in its stat
	# block, so an assertion that only looked for "the colony" passed with the reason
	# line deleted outright (caught by sabotage, 2026-07-27).
	_ok(_find_text(mc._detail, "not at this desk"),
		"...and the dead button says why IT is dead, not just where the work ends")

	# The commoner refusal: not finished. Same rule, its own sentence.
	MissionLog.active[0]["turn_in"] = "station"
	MissionLog.active[0]["n"] = 3
	mc.refresh()
	var unfinished := _find_button(mc, "Turn in")
	_ok(unfinished != null and unfinished.disabled, "an unfinished contract greys its button")
	_ok(_find_text(mc._detail, "Not finished yet"), "...and says so, with the count")
	MissionLog.active[0]["n"] = 0

	# THE OTHER ACTION, same rule — and it must take the offer the player is READING.
	# The lists are venue-filtered, so the row's global index is re-derived on click;
	# a stale or hardcoded index takes somebody else's contract.
	var offers := MissionLog.offers_for(true)
	_ok(offers.size() >= 2, "precondition: the station board is stocked")
	if offers.size() >= 2:
		var want: Dictionary = offers[offers.size() - 1].m
		mc._sel = "o:%s" % str(want.desc)
		mc.refresh()
		var accept := _find_button(mc, "Accept")
		_ok(accept != null and _is_descendant(accept, mc._detail),
			"the accept button sits on the offer being read, not under the list")
		_press(accept)
		var took := false
		for m in MissionLog.active:
			if str(m.get("desc", "")) == str(want.desc):
				took = true
		_ok(took, "accepting takes the offer the player selected (got: %s)" % [
			MissionLog.active.map(func(m: Dictionary) -> String: return str(m.get("desc", "")))])

	MissionLog.active.clear()
	for m in kept:
		MissionLog.active.append(m)
	screen.queue_free()


## THE LAB PUTS THE SPEND ON THE PROJECT (docs/person_as_context.md, second screen).
##
## It was two ItemLists side by side with "Research selected" and "Trade in all Scan
## Data" floating underneath — the Mission Computer's bug with different nouns. And
## because there was nowhere for a paragraph to live, clicking a lead opened a MODAL
## to show one.
##
## The interesting half is the REASON. A project can be out of reach two ways (a
## prerequisite, or not enough Insight), and both are knowable BEFORE the click, so
## `Research.blocker()` is the query and `Research.unlock()` is the command that
## defers to it. The sentence under the greyed button has to be the sentence a
## refused click would have produced, or the lab can promise what unlock refuses.
func _case_the_lab_puts_the_spend_on_the_project() -> void:
	var screen := _fresh_dock(true)
	Research.unlocked.clear()
	Research.insight = 0.0
	screen.refresh()
	var lab: ResearchLabView = screen._lab

	_ok(_count_lists(lab) == 1, "the lab shows exactly ONE list")

	# A project gated by a PREREQUISITE, not by money.
	var gated := {}
	var open_node := {}
	for tree in Research.TREES:
		for node in tree.nodes:
			if str(node.requires) != "" and gated.is_empty():
				gated = node
			if str(node.requires) == "" and open_node.is_empty():
				open_node = node
	_ok(not gated.is_empty() and not open_node.is_empty(),
		"precondition: the trees have a gated project and an open one")

	# PIN THE REASON'S OWN WORDS. The detail panel ALSO carries "Requires" and "Insight"
	# in its stat block, so asserting on those passed with the reason line deleted
	# outright — the same way the Mission Computer's venue assertion did, caught by
	# sabotage the same day. "first." and "needed)" belong to the blocker sentence alone.

	# (1) CANNOT AFFORD IT — nothing in the way but the price.
	Research.insight = 0.0
	lab._sel = "t:" + str(open_node.id)
	lab.refresh()
	var poor := _find_button(lab, "Research —")
	_ok(poor != null and poor.disabled, "a project you cannot afford greys its button")
	_ok(_find_text(lab._detail, "needed)"), "...and says how much Insight it wants")

	# (2) SOMETHING COMES FIRST — with Insight to spare, so only the prerequisite bites.
	Research.insight = 9999.0
	lab._sel = "t:" + str(gated.id)
	lab.refresh()
	var b := _find_button(lab, "Research —")
	_ok(b != null and b.disabled, "a project behind a prerequisite greys its button")
	_ok(b != null and _is_descendant(b, lab._detail),
		"...and the spend sits on the project, not under the column")
	_ok(_find_text(lab._detail, "first."), "...and names the project that comes first")

	# (3) Affordable and unblocked: the button is live and actually spends.
	lab._sel = "t:" + str(open_node.id)
	lab.refresh()
	var go := _find_button(lab, "Research —")
	_ok(go != null and not go.disabled, "an affordable, unblocked project is researchable")
	_press(go)
	_ok(Research.is_unlocked(str(open_node.id)),
		"pressing it researches THAT project (%s)" % str(open_node.id))

	# ONE RULE, TWO SURFACES. If someone re-inlines the checks into unlock(), the two
	# can drift and the lab starts describing a refusal that no longer happens.
	for tree in Research.TREES:
		for node in tree.nodes:
			var stop := Research.blocker(str(node.id))
			if stop == "":
				continue          # never CALL unlock on a researchable node — it spends
			_ok(Research.unlock(str(node.id)) == stop,
				"'%s': the stated obstacle is the one unlock enforces" % str(node.name))

	# THE ARCHIVE IS A THING, so the trade-in has something to sit on — and an empty
	# hold is the teaching state, not an error.
	lab._sel = "archive"
	lab.refresh()
	var arch := _find_button(lab, "Archive")
	_ok(arch != null and arch.disabled, "with no readings aboard, filing them is refused")
	_ok(_find_text(lab._detail, "scanner"), "...and says how to get some")
	screen.ship.add_commodity("scan_data", 3)
	lab.refresh()
	var file_it := _find_button(lab, "Archive")
	_ok(file_it != null and not file_it.disabled, "readings aboard make the archive live")
	var before := Research.insight
	_press(file_it)
	_ok(Research.insight == before + 3 * Research.SCAN_DATA_INSIGHT,
		"filing them pays Insight (%.0f -> %.0f)" % [before, Research.insight])

	Research.unlocked.clear()
	Research.insight = 0.0
	screen.queue_free()


## EVERY SHOP IS A GRID (user, 2026-07-28) — the Shipyard sells objects you compare at
## a glance, so it takes the Armory's shape rather than a list with a "Purchase
## selected" button under it.
##
## The claim worth pinning is that IT NEEDED NO NEW ART: a hull's face is its own
## flight sprite. So this asserts NO SOLD HULL CAN EVER BE A BLANK SQUARE — it has a
## sprite, or a silhouette polygon to fall back on. Add a hull with neither and the
## suite says so, instead of a player finding an empty tile in the shipyard.
## A SHIP IS WORTH ITS ASSEMBLY, NOT ITS HULL. The user named the two failures this
## prevents, before the Shipyard had any way to sell (2026-07-28):
##
##   1. "buy a hull, strip it, and sell it for a profit"
##   2. "buy a hull, fill it out with sweet loot, sell it for the base hull price, and
##      feel cheated"
##
## THE ARITHMETIC IS ASSERTED OVER EVERY SHIPPED HULL, not argued about, because the trap
## is a UNIT MISMATCH rather than a logic slip: HullDef.price is already a buy-side number
## while ComponentDef.value() is intrinsic and doubled on its way to a shelf. Add them the
## obvious way and the hull is priced at half its worth relative to its parts — which is
## exploit 1, arriving quietly, on whichever hull happens to carry the richest loadout.
## A COUNTER NEVER PAYS BACK WHAT IT CHARGES. Two rules from the user (2026-07-28),
## sharing one boundary:
##
##   · the trade skill may "chip away at the diff from buy and sell without ever making
##     it profitable to buy and sell";
##   · faction "should harm the base cost as they move away from adoring you, but never
##     improve the base prices in your favour."
##
## The second is why only the first needs a guard: a modifier that can only ever move
## prices AGAINST you can only ever widen this gap. The trade skill is the one thing that
## closes it — and it had already closed it past zero on commodities, where a level-60
## Trader bought food at the station for 17c and sold it back at the same counter for
## 23c.
##
## SWEPT ACROSS THE WHOLE PERK RANGE, not checked at today's numbers. The cap is a
## balance dial someone will move; the invariant is not, and a test that only samples the
## current value tells you nothing about the one it is changed to.
## LOCAL DEMAND — docs/economy_and_contraband.md Guard 2, "farming a route is the thing
## that stops paying". A venue you flood stops wanting the thing; one you strip pays up.
##
## THE CLAIM THAT MAKES IT SAFE TO ADD UNDER EVERYTHING ELSE: because one number moves
## BOTH of a venue's prices the same way, every ratio proved earlier survives at EVERY
## saturation level, not just at the authored numbers. A model that moved one end alone
## would re-open the same-desk exploit at some stock level nobody thought to check — so
## that is exactly what is swept here, from fully glutted to fully stripped.
func _case_demand_moves_prices_without_breaking_anything() -> void:
	var kept_prof := Pilot.profession
	var kept_xp := Wallet.xp
	TradeGoods.flow_from_dict({})

	# --- THE INVARIANT, ACROSS THE WHOLE RANGE, for a maxed Trader (the worst case) ---
	Pilot.profession = "trader"
	Wallet.xp = 9_000_000
	# The untouched ratio for each good, to measure drift against.
	var baseline_ratio := {}
	for market in [TradeGoods.STATION_MARKET, TradeGoods.PLANET_MARKET,
			TradeGoods.VERGE_MARKET]:
		for key in market["sells"]:
			if market["buys"].has(key):
				# KEYED BY VENUE AND GOOD. Ferrite trades at the station AND the Verge at
				# different prices, so a good-only key let one overwrite the other and the
				# sweep compared the station's ratio against the Dig's.
				baseline_ratio["%s|%s" % [str(market["name"]), str(key)]] = 					float(TradeGoods.sell_price(market, str(key))) 					/ float(TradeGoods.buy_price(market, str(key)))
	for net in [-200.0, -60.0, -12.0, 0.0, 12.0, 60.0, 200.0]:
		for market in [TradeGoods.STATION_MARKET, TradeGoods.PLANET_MARKET,
				TradeGoods.VERGE_MARKET]:
			for key in market["sells"]:
				if not market["buys"].has(key):
					continue
				TradeGoods.flow_from_dict({})
				TradeGoods.note_flow(market, str(key), net)
				var pays := TradeGoods.buy_price(market, str(key))
				var gets := TradeGoods.sell_price(market, str(key))
				_ok(gets < pays,
					"flow %+d: %s at %s pays %dc, gets %dc"
						% [int(net), TradeGoods.display_name(str(key)),
							str(market["name"]), pays, gets])
				# AND THE RATIO HOLDS, which is the claim that "one number moves both
				# prices" actually buys. gets < pays alone survives one-sided demand —
				# the 2x buy-back gap is wide enough to absorb it — so it proves the
				# floor, not the design. Sabotage found exactly that: stripping demand
				# off one end of the convergence broke nothing this could see.
				# TOLERANCE SCALES WITH THE PRICE, because these are integers: a credit
				# of rounding on an 8c ore is 12% of the ratio and on a 120c one is under
				# 1%. A flat epsilon either fails on cheap goods or proves nothing on
				# dear ones.
				var base: float = baseline_ratio["%s|%s" % [str(market["name"]), str(key)]]
				_ok(float(gets) / float(pays) <= base + 1.5 / float(maxi(pays, 1)),
					"flow %+d: %s at %s keeps its spread ratio (%.2f vs %.2f)"
						% [int(net), TradeGoods.display_name(str(key)),
							str(market["name"]), float(gets) / float(pays), base])
	Pilot.profession = ""
	Wallet.xp = 0

	# --- FARMING A ROUTE STOPS PAYING ---
	# THROUGH TradeGoods.sell(), not by poking note_flow: sabotaging the recording call
	# inside the real transaction left this green, because the test was driving the
	# model directly and never touching the wiring. A correct helper nobody calls is a
	# failure this project has already paid for.
	TradeGoods.flow_from_dict({})
	var hauler := TestShip.new()
	add_child(hauler)
	hauler.apply_build(SampleBuilds.get_build(SampleBuilds.current))
	var fresh := TradeGoods.sell_price(TradeGoods.PLANET_MARKET, "circuits")
	for _run in 40:
		hauler.add_commodity("circuits", 1)
		var r := TradeGoods.sell(hauler, TradeGoods.PLANET_MARKET, "circuits")
		if not r.ok:
			break
	var flooded := TradeGoods.sell_price(TradeGoods.PLANET_MARKET, "circuits")
	_ok(flooded < fresh,
		"forty crates in and the colony pays less for circuits (%dc -> %dc)"
			% [fresh, flooded])
	_ok(flooded > 0, "...but never nothing — a glutted venue still trades (%dc)" % flooded)
	_ok(TradeGoods.demand_word(TradeGoods.PLANET_MARKET, "circuits") == "GLUTTED",
		"...and the screen can say WHY the number moved")

	# STRIPPING ONE WORKS THE OTHER WAY — buying out their shelf makes them want it.
	TradeGoods.flow_from_dict({})
	var listed := TradeGoods.buy_price(TradeGoods.STATION_MARKET, "circuits")
	TradeGoods.note_flow(TradeGoods.STATION_MARKET, "circuits", -40.0)
	_ok(TradeGoods.buy_price(TradeGoods.STATION_MARKET, "circuits") > listed,
		"buying out the station's circuits makes the rest dearer")
	_ok(TradeGoods.demand_word(TradeGoods.STATION_MARKET, "circuits") == "SHORT",
		"...and it says so")

	# --- AND IT RECOVERS, or a heavy trader bricks their own economy ---
	TradeGoods.flow_from_dict({})
	TradeGoods.note_flow(TradeGoods.PLANET_MARKET, "circuits", 40.0)
	var slumped := TradeGoods.sell_price(TradeGoods.PLANET_MARKET, "circuits")
	for _day in 12:
		GameClock.advance()
	var healed := TradeGoods.sell_price(TradeGoods.PLANET_MARKET, "circuits")
	_ok(healed > slumped, "a dozen days on, the colony wants circuits again (%dc -> %dc)"
		% [slumped, healed])
	for _day in 40:
		GameClock.advance()
	_ok(TradeGoods.sell_price(TradeGoods.PLANET_MARKET, "circuits") == fresh,
		"...and it returns all the way to baseline, not to a permanent dent")

	TradeGoods.flow_from_dict({})
	hauler.queue_free()
	Pilot.profession = kept_prof
	Wallet.xp = kept_xp


func _case_no_counter_pays_back_what_it_charges() -> void:
	# --- COMPONENTS: the rule, swept past anything a perk could plausibly reach ---
	for pct in [0, 25, 50, 75, 90, 100, 150]:
		var buy := 200
		var raw := int(buy * pct / 100.0)
		_ok(ItemVisuals.recovery_capped(raw, buy) < buy,
			"a %d%% sell offer on a %dc part is capped below what it costs (%dc)"
				% [pct, buy, ItemVisuals.recovery_capped(raw, buy)])
	_ok(ItemVisuals.recovery_capped(10, 200) == 10,
		"...and a normal offer is left alone — the cap is a ceiling, not a price")

	# ...and through the REAL prices, for every part the game sells.
	for path in DockScreen.SHOP_STOCK:
		var comp: ComponentDef = load(str(path))
		if comp == null:
			continue
		_ok(ItemVisuals.sell_price(comp) < ItemVisuals.buy_price(comp),
			"%s sells back for less than it costs (%dc vs %dc)"
				% [comp.display_name, ItemVisuals.sell_price(comp),
					ItemVisuals.buy_price(comp)])

	# --- THE 50% RULE, in the DATA ---
	#
	# A counter pays half what it charges for the same good, so profit can only come from
	# carrying goods somewhere that wants them. Asserted against the tables because it is
	# authored data, and the next market someone writes is exactly where it would drift.
	for market in [TradeGoods.STATION_MARKET, TradeGoods.PLANET_MARKET,
			TradeGoods.VERGE_MARKET]:
		for key in market["buys"]:
			if not market["sells"].has(key):
				continue      # one-sided — no local spread to hold
			var charges: int = market["sells"][key]
			var pays: int = market["buys"][key]
			_ok(pays <= int(round(float(charges) * TradeGoods.BUYBACK)),
				"%s pays %dc for %s and charges %dc — at or under the %d%% buy-back"
					% [str(market["name"]), pays, TradeGoods.display_name(str(key)),
						charges, int(TradeGoods.BUYBACK * 100.0)])

	# --- THE BACKSTOP, exercised directly ---
	#
	# TradeGoods.MAX_EDGE is unreachable through the game today: Pilot.TRADE_EDGE_MAX caps
	# the perk at 0.20, far under it. Sabotaging MAX_EDGE therefore changed NOTHING and
	# every test stayed green — which is what an untested guard looks like from the
	# outside, and it is only a guard at all for the day someone raises the trader cap.
	# So it is asserted against the input it exists for: an edge past 1.0, which without
	# the clamp would push the two prices straight through each other.
	for wild in [0.9, 1.0, 2.0, 5.0]:
		var high := TradeGoods._toward_mid(40.0, 34.0, wild)
		var low := TradeGoods._toward_mid(34.0, 40.0, wild)
		_ok(high > low,
			"an edge of %.1f still cannot cross a 40/34 spread (%.1f vs %.1f)"
				% [wild, high, low])
	_ok(Pilot.TRADE_EDGE_MAX < TradeGoods.MAX_EDGE,
		"the trader cap sits inside the backstop, so the backstop is the outer bound")

	# --- COMMODITIES: same desk, both directions, at every rung of the perk ---
	var kept_prof := Pilot.profession
	var kept_xp := Wallet.xp
	for xp in [0, 5_000, 100_000, 9_000_000]:
		Pilot.profession = "trader"
		Wallet.xp = xp
		for market in [TradeGoods.STATION_MARKET, TradeGoods.PLANET_MARKET,
				TradeGoods.VERGE_MARKET]:
			for key in market["sells"]:
				if not market["buys"].has(key):
					continue      # no round trip exists here; nothing to protect
				var pays := TradeGoods.buy_price(market, str(key))
				var gets := TradeGoods.sell_price(market, str(key))
				_ok(gets < pays,
					"L%d trader: %s at %s pays %dc, gets %dc back"
						% [Pilot.level(), TradeGoods.display_name(str(key)),
							str(market["name"]), pays, gets])

	# AND THE ROUTE STILL PAYS BETTER FOR A TRADER — closing the loop is worthless if it
	# flattens the gameplay it protects (user: "it's okay to cross on market items from
	# one region to another, that's the trader gameplay").
	Wallet.xp = 9_000_000
	var trader_run := TradeGoods.sell_price(TradeGoods.PLANET_MARKET, "circuits") \
		- TradeGoods.buy_price(TradeGoods.STATION_MARKET, "circuits")
	Pilot.profession = ""
	Wallet.xp = 0
	var plain_run := TradeGoods.sell_price(TradeGoods.PLANET_MARKET, "circuits") \
		- TradeGoods.buy_price(TradeGoods.STATION_MARKET, "circuits")
	_ok(trader_run > plain_run,
		"the cross-region run still rewards a Trader (%+dc vs %+dc a unit)"
			% [trader_run, plain_run])

	# --- ORE IS A COMMODITY, AND MINING IS STILL THE ONLY WAY IT PAYS ---
	#
	# Doug pays OVER the station rate, which is the Verge's whole economic argument — and
	# also the obvious thing a player will try to exploit: buy rock cheap at the station,
	# haul it to the premium buyer. Both directions must lose, or mining is pointless and
	# the Verge becomes a money printer with a commute.
	for key in ["ferrite_ore", "cobalt_ore", "aurite_ore"]:
		var out_leg := TradeGoods.sell_price(TradeGoods.VERGE_MARKET, key) 			- TradeGoods.buy_price(TradeGoods.STATION_MARKET, key)
		var back_leg := TradeGoods.sell_price(TradeGoods.STATION_MARKET, key) 			- TradeGoods.buy_price(TradeGoods.VERGE_MARKET, key)
		_ok(out_leg < 0, "hauling bought %s out to Doug loses (%+dc a unit)"
			% [TradeGoods.display_name(key), out_leg])
		_ok(back_leg < 0, "...and hauling his %s home loses too (%+dc a unit)"
			% [TradeGoods.display_name(key), back_leg])
		# AND THE VERGE IS STILL WORTH FLYING TO for rock you dug yourself.
		_ok(TradeGoods.sell_price(TradeGoods.VERGE_MARKET, key)
				> TradeGoods.sell_price(TradeGoods.STATION_MARKET, key),
			"Doug pays over the station for mined %s (%dc vs %dc)"
				% [TradeGoods.display_name(key),
					TradeGoods.sell_price(TradeGoods.VERGE_MARKET, key),
					TradeGoods.sell_price(TradeGoods.STATION_MARKET, key)])

	Pilot.profession = kept_prof
	Wallet.xp = kept_xp


func _case_a_ship_is_worth_what_is_bolted_to_it() -> void:
	for i in SampleBuilds.count():
		var stock := SampleBuilds.stock(i)          # the FACTORY ship, not the pilot's
		var name := stock.hull.display_name
		var whole := ShipValue.sell(stock)
		var bare := ShipBuild.new()
		bare.hull = stock.hull
		var loose := 0
		for part in ShipValue.fitted(stock):
			loose += ItemVisuals.sell_price(part)

		# THE INVARIANT. Sell her whole, or strip her and sell the pieces — same number,
		# and it is exactly half the asking price, because the asking price already
		# contained the loadout (user: orig_creds = hull_base + Σ included).
		#
		# This ONE equality closes both failures at once. If stripping paid more, that is
		# exploit 1; if it paid less, a pilot is punished for selling a ship they had
		# improved, which is exploit 2 wearing a different hat.
		_ok(ShipValue.sell(bare) + loose == whole,
			"%s: stripping (%dc) and selling her whole (%dc) come to the same"
				% [name, ShipValue.sell(bare) + loose, whole])
		_ok(whole == int(round(float(stock.hull.price) * ShipValue.HULL_RECOVERY)),
			"%s: a stock ship is worth half her asking price (%dc of %dc)"
				% [name, whole, int(stock.hull.price)])
		# ...and the asking price is exactly what she is made of, by construction.
		_ok(ShipValue.replacement(stock) == int(stock.hull.price),
			"%s: replacing her costs her sticker — the loadout was always in it" % name)

		# SELLING HER LOADED IS NOT ROBBERY. Anything bolted on has to move the number,
		# or a pilot's loot vanishes into the hull price.
		if not ShipValue.fitted(stock).is_empty():
			_ok(whole > ShipValue.sell(bare),
				"%s loaded is worth more than %s bare (%dc vs %dc)"
					% [name, name, whole, ShipValue.sell(bare)])
			_ok(whole - ShipValue.sell(bare) == loose,
				"...by exactly what those parts fetch loose (%dc)" % loose)

	# CHIPS COUNT. They are not in `slots`, they cost real money, and a valuation that
	# walks only the hardpoints is the "sold my loot for nothing" complaint in miniature.
	var chipped := ShipBuild.new()
	chipped.hull = SampleBuilds.get_build(0).hull
	var chip: ComponentDef = null
	for path in DockScreen.SHOP_STOCK:
		var c: ComponentDef = load(str(path))
		if c is AbilityChipDef:
			chip = c
			break
	_ok(chip != null, "precondition: the shop stocks a chip to fit")
	if chip != null:
		var before := ShipValue.sell(chipped)
		chipped.chips.append(chip)
		_ok(ShipValue.sell(chipped) == before + ItemVisuals.sell_price(chip),
			"a chip in the coupling is part of what the ship is worth")


func _case_the_shipyard_is_a_shop_shelf() -> void:
	var screen := _fresh_dock(true)
	var kept_credits := Wallet.credits
	var kept_owned: Array = SampleBuilds.owned.duplicate()
	Wallet.credits = 999999
	screen.refresh()

	_ok(_count_lists(screen._yard) == 0, "the shipyard shelf is a grid, not a list")
	# BOTH SHELVES — for sale, and yours. A hull you own leaves the stock shelf for the
	# fleet one, so walking a single grid now finds every ship except the ones you have.
	var tiles: Array = _collect_tiles(screen._yard._stock) \
		+ _collect_tiles(screen._yard._fleet)
	_ok(tiles.size() == SampleBuilds.count(),
		"every hull for sale wears a tile (%d of %d)" % [tiles.size(), SampleBuilds.count()])

	# TWO SEPARATE CLAIMS, because "sprite OR silhouette" is satisfied by the silhouette
	# on every hull in the game — it could not fail, and a sabotage that deleted the
	# sprite lookup entirely sailed straight through it.
	for t in tiles:
		var hull: HullDef = (t as HullTile).build.hull
		_ok(ItemVisuals.hull_icon(hull) != null,
			"%s ships with its own sprite — which is why the shipyard needed NO NEW ART"
				% hull.display_name)
		_ok((hull.silhouette as PackedVector2Array).size() >= 3,
			"%s also carries a silhouette, so it is never a blank tile if art moves"
				% hull.display_name)

	# BUYING ACTS ON THE TILE YOU CLICKED. The offers list already taught this lesson
	# once: an action that reads a shared "selected" instead of its own item buys
	# somebody else's ship.
	# The LAST unowned hull, never the first: an action hardcoded to index 0 buys the
	# right ship by accident if the test picks index 0, which is exactly what happened.
	var target: HullTile = null
	for t in tiles:
		if not (t as HullTile).owned:
			target = t
	_ok(target != null and target.index > 0,
		"precondition: an unowned hull that is NOT index 0")
	if target != null:
		var before := SampleBuilds.owned.size()
		# THROUGH THE REAL GESTURE. The tile's own on_interact is deliberately unset now
		# — ContextGrid owns click routing — so calling it would test a path the player
		# cannot reach, and would keep passing if the grid's wiring were cut.
		_right_click(target)
		_ok(SampleBuilds.owned.has(target.index),
			"right-clicking a tile buys THAT hull (%d)" % target.index)
		_ok(SampleBuilds.owned.size() == before + 1, "...and only that one")

	# A SHOP IS ITS INVENTORY — no details column restating the tooltip beside it, and no
	# Buy button duplicating the right-click (user, 2026-07-28). So the refusal cannot
	# live in a panel; it has to reach the player some other way, and "every rejection is
	# visible" is a project rule, not a nice-to-have.
	Wallet.credits = 0
	screen.refresh()
	_ok(_find_button(screen._yard, "Buy —") == null,
		"no Buy button on the shelf — right-click is the verb everywhere")
	# RE-COLLECT. refresh() rebuilds every tile, so the array above now holds freed
	# nodes — clicking one of those tests nothing and reports success either way.
	var poor: HullTile = null
	for t in _collect_tiles(screen._yard._stock):
		if not (t as HullTile).owned:
			poor = t
	if poor != null:
		var owned_before := SampleBuilds.owned.size()
		screen._flash_msg = ""
		_right_click(poor)
		_ok(SampleBuilds.owned.size() == owned_before,
			"a hull you cannot afford is not sold to you")
		_ok("credits" in screen._flash_msg,
			"...and the refusal says so out loud (%s)" % screen._flash_msg)

	Wallet.credits = kept_credits
	SampleBuilds.owned.clear()
	for i in kept_owned:
		SampleBuilds.owned.append(i)
	screen.queue_free()


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


## WALK UP TO SOMEONE. Presses the real desk and hands back the addressee it opened,
## so every claim below is made against the panel a player would be looking at rather
## than against the offer list that fed it.
func _addressee(screen: DockScreen, npc: String) -> DialoguePanel:
	screen._on_desk_talk(npc)
	return _live_panel(screen)


## WALK UP TO A VENUE'S FACE. Same idea as _addressee at the dock: press the real desk
## and hand back the panel, so claims are made against what a player sees.
func _venue_talk(host: Node) -> DialoguePanel:
	# The shell is a GRANDCHILD (the host wraps it in a PanelContainer), so this walks
	# rather than scanning one level — the panels it opens are direct children of the
	# host canvas, which is why those are found flat below.
	var shell := _find_venue(host)
	if shell == null:
		return null
	shell.open_addressee()
	return _live_panel(host)


## The NEWEST live conversation. SKIPPING QUEUED-FOR-DELETION IS LOAD-BEARING: an offer
## that hands off closes its panel with queue_free, which does not take effect until the
## end of the frame — so the previous conversation is still a child, still first in the
## list, and a naive walk reads the answers to the LAST question asked.
func _live_panel(host: Node) -> DialoguePanel:
	var found: DialoguePanel = null
	for c in host.get_children():
		if c is DialoguePanel and not c.is_queued_for_deletion():
			found = c
	return found


func _find_venue(root: Node) -> VenueLayout:
	for c in root.get_children():
		if c is VenueLayout:
			return c
		var hit := _find_venue(c)
		if hit != null:
			return hit
	return null


## Take one of their offers and hand back the context it opened. The offer CLOSES the
## conversation on its way (one context at a time), so the panel is disposed here.
func _take_offer(host: Node, panel: DialoguePanel, needle: String) -> ContextModal:
	var btn := _find_button(panel, needle)
	if btn == null:
		return null
	btn.pressed.emit()
	_dispose(host, panel)
	for c in host.get_children():
		if c is ContextModal:
			return c
	return null


## A REAL MOUSE GESTURE on a tile. Grid shelves route clicks through ContextGrid's
## gui_input, so poking a tile's own callback tests a path the player cannot take.
func _click(node: Control, button: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	node.gui_input.emit(ev)


func _left_click(node: Control) -> void:
	_click(node, MOUSE_BUTTON_LEFT)


func _right_click(node: Control) -> void:
	_click(node, MOUSE_BUTTON_RIGHT)


## Dispose IMMEDIATELY, not queue_free: a deferred panel is still in the tree this
## frame, and the next lookup would happily answer from the last conversation.
func _dispose(screen: Node, panel: Node) -> void:
	if panel == null or not is_instance_valid(panel) or panel.is_queued_for_deletion():
		return
	screen.remove_child(panel)
	panel.free()


## What they offer, in the order offered.
func _choice_texts(root: Node, out: Array = []) -> Array:
	for child in root.get_children():
		if child is Button:
			out.append((child as Button).text)
		_choice_texts(child, out)
	return out


func _find_office(root: Node) -> GuildOffice:
	for child in root.get_children():
		if child is GuildOffice:
			return child
	return null


## Does any label anywhere under `root` contain this text? Buttons are how you
## act; labels are how you READ, and the prospectus is a reading surface.
## CAN THE PLAYER SEE IT — the only question the trust rule cares about. Controls here
## are HIDDEN rather than freed, so an existence check answers yes for a shelf nobody
## can read and would keep answering yes if the hiding broke.
func _find_visible_text(root: Node, needle: String) -> bool:
	for child in root.get_children():
		var ctrl := child as Control
		if ctrl != null and not ctrl.is_visible_in_tree():
			continue
		if child is RichTextLabel and needle in (child as RichTextLabel).get_parsed_text():
			return true
		if child is Label and needle in (child as Label).text:
			return true
		if child is Button and needle in (child as Button).text:
			return true
		if _find_visible_text(child, needle):
			return true
	return false


## How many ItemLists are on screen. "Never two lists at once" is the rule the
## three-column board broke, and it is a SHAPE, so it is checked as one.
func _count_lists(root: Node) -> int:
	var n := 0
	for child in root.get_children():
		if child is ItemList:
			n += 1
		n += _count_lists(child)
	return n


## Rows of `list` whose text contains `needle` — a contract listed in two columns
## shows up here as 2.
func _count_rows(list: ItemList, needle: String) -> int:
	var n := 0
	for i in list.item_count:
		if needle in list.get_item_text(i):
			n += 1
	return n


func _collect_tiles(root: Node) -> Array:
	var out: Array = []
	for child in root.get_children():
		if child is HullTile:
			out.append(child)
		out += _collect_tiles(child)
	return out


func _is_descendant(node: Node, ancestor: Node) -> bool:
	var p := node
	while p != null:
		if p == ancestor:
			return true
		p = p.get_parent()
	return false


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
## THE OTHER END OF THE TRANSACTION. Two shelves share one selection and one detail
## panel, and the whole reason that is allowed is that the panel offers the verb
## belonging to WHERE THE THING CAME FROM — buy for the shop's stock, sell for yours.
## A grid that lost track of which pile a tile came from would offer Buy on gear you
## already own, and the two shelves really would be a duplicate.
func _case_the_armory_sells_from_your_own_shelf() -> void:
	var screen := _fresh_dock(true)
	var armory: ArmoryView = screen._armory
	var kept := Wallet.credits
	screen.ship.cargo.clear()
	var owned: ComponentDef = load(str(DockScreen.SHOP_STOCK[0]))
	screen.ship.add_cargo(owned)
	screen.refresh()

	var mine: Array = []
	for t in armory._yours.get_children():
		if not t.is_queued_for_deletion() and t.get("comp") != null:
			mine.append(t)
	_ok(mine.size() == 1, "the thing in your hold is on YOUR COMPONENTS (%d)" % mine.size())
	if mine.is_empty():
		screen.queue_free()
		return

	# THE VERB FOLLOWS THE PILE, asserted by what the same gesture DOES in each — which is
	# the honest form of it now that neither shelf has a button to read. If the two piles
	# ever lost track of which is which, right-click would mean one thing everywhere and
	# they really would be duplicates of each other.
	_ok(_find_button(armory, "Sell —") == null and _find_button(armory, "Buy —") == null,
		"neither shelf carries a button — right-click is the verb")

	Wallet.credits = 0
	var worth := ItemVisuals.sell_price(owned)
	_right_click(mine[0])
	_ok(Wallet.credits == worth,
		"right-clicking YOUR tile sells it for %dc (got %dc)" % [worth, Wallet.credits])
	_ok(screen.ship.cargo.is_empty(), "...and it leaves your hold")

	# ...and the same gesture on the SHOP shelf spends instead of earning.
	screen.refresh()
	var stock: Array = []
	for t in armory._shop.get_children():
		if not t.is_queued_for_deletion() and t.get("comp") != null:
			stock.append(t)
	_ok(not stock.is_empty(), "the shop has stock to buy")
	if not stock.is_empty():
		Wallet.credits = 100000
		var before_credits := Wallet.credits
		_right_click(stock[0])
		_ok(Wallet.credits < before_credits,
			"right-clicking a SHOP tile buys — the verb follows the pile it came from")
		_ok(not screen.ship.cargo.is_empty(), "...and it lands in your hold")

	Wallet.credits = kept
	screen.ship.cargo.clear()
	screen.queue_free()


func _case_armory_filters() -> void:
	var screen := _fresh_dock(true)
	screen.refresh()

	# THROUGH THE VIEW'S OWN API. The filter used to be a field on the dock; it belongs
	# to ArmoryView now, and set_filter() is the call its own buttons make.
	var armory: ArmoryView = screen._armory

	# --- CHIPS shows only things that grant an ability ---
	armory.set_filter(ArmoryView.FILTER_CHIPS)
	var chips := _shop_tiles(screen)
	_ok(not chips.is_empty(), "the Chips filter shows something (the shop stocks chips)")
	for c in chips:
		_ok(DockScreen._is_chip(c), "'%s' is on the chip shelf and grants an ability" % c.display_name)

	# --- ...and the System shelf is free of them ---
	armory.set_filter(HardpointDef.SlotType.SYSTEM)
	for c in _shop_tiles(screen):
		_ok(not DockScreen._is_chip(c),
			"'%s' is a chip and must not sit on the System shelf" % c.display_name)

	# --- LEVEL BAND ---
	armory.set_filter(-1)
	_set_band(armory, 1, Pilot.MAX_LEVEL)
	var all_count := _shop_tiles(screen).size()
	_ok(all_count > 0, "the unfiltered shelf has stock (%d)" % all_count)

	_set_band(armory, 1, 5)
	for c in _shop_tiles(screen):
		_ok(int(c.level) >= 1 and int(c.level) <= 5,
			"'%s' (L%d) is inside the 1-5 band" % [c.display_name, int(c.level)])

	# A band nothing occupies must EXPLAIN itself, not just look like a broken shop.
	_set_band(armory, Pilot.MAX_LEVEL, Pilot.MAX_LEVEL)
	_ok(_shop_tiles(screen).is_empty(), "an empty band shows no stock")
	# The note belongs to the SHELF, not to the grid — inside the grid it lands in one
	# tile-wide cell and autowraps to a character a line. So the claim is asked of the
	# whole screen, which is also what a player sees.
	_ok(_finds_text(armory, "level %d" % Pilot.MAX_LEVEL),
		"an empty shelf names the level band that emptied it")

	# --- THE ENDS CANNOT CROSS --- dragging min past max shoves max, and vice
	# versa. Without this the shop can be left permanently empty with no visible
	# cause, which reads as a bug rather than a filter.
	_set_band(armory, 1, 60)
	armory._lvl_min_spin.value = 40          # emits -> should shove max up
	_ok(armory._lvl_max >= 40,
		"raising min above max pushed max up (min %d, max %d)"
		% [armory._lvl_min, armory._lvl_max])
	armory._lvl_max_spin.value = 3           # emits -> should shove min down
	_ok(armory._lvl_min <= 3,
		"lowering max below min pulled min down (min %d, max %d)"
		% [armory._lvl_min, armory._lvl_max])

	screen.queue_free()


## The ComponentDefs currently drawn on the shop shelf.
##
## SKIPS NODES ALREADY QUEUED FOR DELETION. `_refresh_armory` clears the grid with
## queue_free(), which is DEFERRED to the end of the frame — so inside one frame the
## grid holds the previous fill AND the new one. Reading it raw made every filter
## look like it did nothing at all (the first run of this case "found" every weapon
## in the game on the chip shelf). In play a frame always elapses between refreshes,
## so this is a harness concern, not a product bug.
## THE LEVEL BAND, THROUGH THE SPINS the player actually turns — not by assigning the
## ints behind them, which would skip the shove rule that keeps the two ends from
## crossing and leave the case passing over a shop that can never refill.
func _set_band(armory: ArmoryView, lo: int, hi: int) -> void:
	armory._lvl_min_spin.value = 1           # widen first, so neither end shoves the other
	armory._lvl_max_spin.value = Pilot.MAX_LEVEL
	armory._lvl_min_spin.value = lo
	armory._lvl_max_spin.value = hi


func _shop_tiles(screen: DockScreen) -> Array:
	var out: Array = []
	for t in (screen._armory as ArmoryView)._shop.get_children():
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
	GameClock.reset()                               # 3-day wait not yet served
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
	GameClock.reset()
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
