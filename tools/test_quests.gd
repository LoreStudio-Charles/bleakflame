extends SceneTree
## Headless smoke test for the story-quest framework:
##   godot --headless --path . --script res://tools/test_quests.gd
## Covers the post-tutorial funnel: auto-start gating, contract counting,
## goto/report stages, rewards, log entries, and the save round-trip.


class DummyShip:
	var commodities := {}

	func remove_commodity(key: String, qty: int) -> void:
		commodities[key] = commodities.get(key, 0) - qty
		if commodities[key] <= 0:
			commodities.erase(key)


func _init() -> void:
	var failures := 0
	Quests.reset()
	Research.reset()
	Wallet.credits = 0
	Wallet.xp = 0
	var ship := DummyShip.new()

	# Gating: nothing starts before the tutorial is done.
	Quests.on_dock(true, ship, false)
	if not Quests.active.is_empty():
		print("FAIL: quest started before tutorial completion")
		failures += 1
	# LANDING TUTORIAL first: the dirtside milk run is the opening post-tutorial
	# job (it forces a planetary landing), and prove_wings gates behind it.
	Quests.on_dock(true, ship, true)
	if not Quests.active.has("dirtside_run"):
		print("FAIL: dirtside_run (landing tutorial) should auto-start after tutorial")
		failures += 1
	if Quests.active.has("prove_wings"):
		print("FAIL: prove_wings started before the landing tutorial")
		failures += 1
	Quests.take_talks(true)   # drain Ruel's dirtside briefing
	# It resolves as a TALK with Imari at the PLANET — you have to land to finish.
	Quests.on_dock(false, ship, true)
	var dirt_talk := Quests.take_talks(false)
	if dirt_talk.is_empty() or dirt_talk[0].giver != "imari":
		print("FAIL: dirtside talk not queued at the planet: ", dirt_talk)
		failures += 1
	Quests.advance_talk("dirtside_run")
	if not Quests.completed.has("dirtside_run"):
		print("FAIL: dirtside_run did not complete on the colony talk")
		failures += 1
	# Ruel's DEBRIEF does not fire here: he is at the station and the quest
	# completed at the colony, so it waits for the trip home (venue rule).
	if not Quests.take_talks(false).is_empty():
		print("FAIL: Ruel debriefed from the colony, where he isn't")
		failures += 1
	# Zero the purse so the reward assertions below stay about THEIR quest.
	Wallet.credits = 0
	Wallet.xp = 0

	Quests.on_dock(true, ship, true)
	if not Quests.active.has("prove_wings"):
		print("FAIL: prove_wings should start once the landing tutorial is done")
		failures += 1
	if Quests.active.has("overdue"):
		print("FAIL: overdue started before its prerequisite")
		failures += 1
	# Starting a quest queues its giver's briefing for the dock UI to present.
	# Back at the station: the held debrief AND the new briefing, both Ruel's.
	var briefings := Quests.take_talks(true)
	if briefings.size() != 2 or briefings[0].giver != "ruel" 			or briefings[1].giver != "ruel":
		print("FAIL: station talks not queued on return: ", briefings)
		failures += 1

	# Contracts stage counts turn-ins; completion pays out and debriefs.
	Quests.note_contract()
	if Quests.log_entries(ship)[0].current.find("1/2") < 0:
		print("FAIL: contracts progress not reflected: ", Quests.log_entries(ship)[0].current)
		failures += 1
	Quests.note_contract()
	if not Quests.completed.has("prove_wings") or Wallet.credits != 150 or Wallet.xp != 20:
		print("FAIL: prove_wings completion/rewards: %dc %dxp" % [Wallet.credits, Wallet.xp])
		failures += 1
	var debriefs := Quests.take_talks(true)
	if debriefs.size() != 1 or debriefs[0].giver != "ruel":
		print("FAIL: debrief talk not queued on completion: ", debriefs)
		failures += 1

	# Next dock hands out the follow-up; entering its goto stage charts the
	# POI and snaps an idle waypoint to it.
	PoiMap.register("meridian_fix", "Last Fix", Vector2(6950, 3400), "signal")
	PoiMap.waypoint_id = ""
	Quests.on_dock(true, ship, true)
	if not Quests.active.has("overdue"):
		print("FAIL: overdue should start once prove_wings completes")
		failures += 1
	if not PoiMap.is_discovered("meridian_fix") or PoiMap.waypoint_id != "meridian_fix":
		print("FAIL: goto stage should chart + waypoint its POI")
		failures += 1

	# Far away: nothing. On site: the sweep completes with a HUD flash.
	if not Quests.tick_goto(Vector2.ZERO).is_empty():
		print("FAIL: goto fired from across the system")
		failures += 1
	var flashes := Quests.tick_goto(Vector2(7000, 3300))
	if flashes.size() != 1 or Quests.stage_def("overdue").get("kind", "") != "report":
		print("FAIL: goto arrival should advance to the report stage")
		failures += 1

	# Reporting at the station completes the quest and pays.
	var credits_before := Wallet.credits
	Quests.on_dock(true, ship, true)
	if not Quests.completed.has("overdue") or Wallet.credits != credits_before + 220:
		print("FAIL: overdue completion/rewards")
		failures += 1
	# dirtside_run (landing tutorial) + prove_wings + overdue.
	if Quests.completed_entries().size() != 3:
		print("FAIL: completed entries: ", Quests.completed_entries().size())
		failures += 1
	# The journal recorded the arc.
	if Research.journal.size() < 5:
		print("FAIL: journal too thin: ", Research.journal.size())
		failures += 1

	# TALK stage: completing overdue starts ember_word; its briefing queues,
	# then docking queues the talk-stage conversation (venue = station).
	Quests.take_talks(true)   # clear voss briefing for ember_word
	if not Quests.active.has("ember_word"):
		print("FAIL: ember_word should start after overdue")
		failures += 1
	if Quests.stage_def("ember_word").get("kind", "") != "talk":
		print("FAIL: ember_word stage should be a talk")
		failures += 1
	# A planet dock must NOT resolve a station-venue talk.
	Quests.on_dock(false, ship, true)
	if not Quests.take_talks(false).is_empty():
		print("FAIL: station talk fired at the planet")
		failures += 1
	# Station dock queues the conversation, but does NOT auto-advance it.
	Quests.on_dock(true, ship, true)
	var talks := Quests.take_talks(true)
	if talks.size() != 1 or talks[0].giver != "odessa" or not talks[0].has("advance"):
		print("FAIL: talk-stage conversation not queued: ", talks)
		failures += 1
	if Quests.completed.has("ember_word"):
		print("FAIL: talk stage auto-advanced without the conversation")
		failures += 1
	# Finishing the conversation (UI close -> advance_talk) completes it.
	var cred := Wallet.credits
	Quests.advance_talk("ember_word")
	if not Quests.completed.has("ember_word") or Wallet.credits != cred + 120:
		print("FAIL: advance_talk did not complete ember_word")
		failures += 1

	# SCAN_TARGET stage: docking starts cold_patch (requires ember_word);
	# the flight scene asks where to place the anomaly, and surveying it
	# advances the stage.
	Quests.on_dock(true, ship, true)
	Quests.take_talks(true)   # clear lab briefing
	if Quests.stage_def("cold_patch").get("kind", "") != "scan_target":
		print("FAIL: cold_patch stage should be scan_target")
		failures += 1
	var site := Quests.scan_site()
	if site.get("quest", "") != "cold_patch" or not (site.get("pos") is Vector2):
		print("FAIL: scan_site did not report the anomaly to place: ", site)
		failures += 1
	var cred2 := Wallet.credits
	Quests.note_scan_target("cold_patch")
	if not Quests.completed.has("cold_patch") or Wallet.credits != cred2 + 260:
		print("FAIL: note_scan_target did not complete cold_patch")
		failures += 1
	if not Quests.scan_site().is_empty():
		print("FAIL: scan_site should be empty once the stage is done")
		failures += 1

	# SURVIVE_EVENT stage: docking starts caught_looking; the flight scene
	# asks where the ambush triggers, and reaching safety advances it.
	Quests.on_dock(true, ship, true)
	Quests.take_talks(true)   # clear lab briefing
	if Quests.stage_def("caught_looking").get("kind", "") != "survive_event":
		print("FAIL: caught_looking stage should be survive_event")
		failures += 1
	var asite := Quests.survive_site()
	if asite.get("quest", "") != "caught_looking" or not (asite.get("pos") is Vector2):
		print("FAIL: survive_site did not report the ambush trigger: ", asite)
		failures += 1
	var cred3 := Wallet.credits
	Quests.note_survived("caught_looking")
	if not Quests.completed.has("caught_looking") or Wallet.credits != cred3 + 320:
		print("FAIL: note_survived did not complete caught_looking")
		failures += 1
	if not Quests.survive_site().is_empty():
		print("FAIL: survive_site should be empty once survived")
		failures += 1

	# BEAT 4: first_contact starts; it's a scan_target (tendril) with an
	# escort flag, completed by scanning the fragment.
	Quests.on_dock(true, ship, true)
	Quests.take_talks(true)
	var ts := Quests.scan_site()
	if ts.get("quest", "") != "first_contact" or ts.get("anomaly", "") != "tendril":
		print("FAIL: scan_site did not report the tendril: ", ts)
		failures += 1
	if not Quests.escort_active():
		print("FAIL: first_contact should request a guardian escort")
		failures += 1
	Quests.note_scan_target("first_contact")
	if not Quests.completed.has("first_contact") or Quests.escort_active():
		print("FAIL: scanning the tendril did not complete first_contact")
		failures += 1

	# BEAT 5 HERMIT: DEX hands you the lead (giver "lab"), so the_hermit ACTIVATES
	# at the STATION and charts a breadcrumb to the planet — a quest whose giver
	# stood at the destination could never send you there (the dead-end the user
	# hit: Dex referenced the Counter but no quest pointed the way). The TALK still
	# happens with the hermit, at the planet.
	Quests.on_dock(true, ship, true)
	Quests.take_talks(true)
	if not Quests.active.has("the_hermit"):
		print("FAIL: the_hermit should activate at the station (Dex hands the lead)")
		failures += 1
	# The campaign step points at the planet (the breadcrumb).
	var step := Quests.current_step()
	if step.get("quest") == "the_hermit" and step.get("target_poi") != "planetoid":
		print("FAIL: hermit breadcrumb should point at the planet, got ", step.get("target_poi"))
		failures += 1
	# The hermit TALK presents at the planet, and completes the beat.
	Quests.on_dock(false, ship, true)
	var htalk := Quests.take_talks(false)
	if htalk.size() != 1 or htalk[0].giver != "hermit":
		print("FAIL: hermit talk not queued at the planet: ", htalk)
		failures += 1
	Quests.advance_talk("the_hermit")
	if not Quests.completed.has("the_hermit"):
		print("FAIL: hermit talk did not complete")
		failures += 1

	# BEAT 6 GOTO+DIALOGUE: rust_shoal starts; tick_goto must NOT auto-finish
	# it (it carries a dialogue), advance_goto_dialogue does.
	Quests.on_dock(true, ship, true)
	Quests.take_talks(true)
	var gd := Quests.goto_dialogue_site()
	if gd.get("quest", "") != "rust_shoal" or gd.get("npc", "") != "krayt":
		print("FAIL: goto_dialogue_site did not report rust_shoal: ", gd)
		failures += 1
	Quests.tick_goto(Vector2(gd.pos))   # arriving must not complete a dialogue-goto
	if Quests.completed.has("rust_shoal"):
		print("FAIL: dialogue-goto auto-completed on arrival")
		failures += 1
	Quests.advance_goto_dialogue("rust_shoal")
	if not Quests.completed.has("rust_shoal"):
		print("FAIL: advance_goto_dialogue did not complete rust_shoal")
		failures += 1

	# BEAT 7 REACH_GATE: the finale is manual_start — the flight scene's
	# Shoal's-fall set-piece begins it (Krayt's final transmission), NOT a dock.
	Quests.on_dock(true, ship, true)
	Quests.take_talks(true)
	if Quests.active.has("nothing_left_behind"):
		print("FAIL: the finale auto-started at a dock (should be manual_start)")
		failures += 1
	Quests.begin_manual("nothing_left_behind")   # the set-piece delivers the transmission
	if not Quests.active.has("nothing_left_behind"):
		print("FAIL: begin_manual did not start the finale")
		failures += 1
	if Quests.gate_site().get("quest", "") != "nothing_left_behind":
		print("FAIL: gate_site did not report the finale")
		failures += 1
	Quests.note_gate_reached("nothing_left_behind")
	if not Quests.completed.has("nothing_left_behind"):
		print("FAIL: reaching the gate did not complete the finale")
		failures += 1

	# Save round-trip mid-quest. Clear the landing tutorial first — it's the
	# opening job now, so prove_wings only starts behind it.
	Quests.reset()

	Quests.on_dock(true, ship, true)     # dirtside_run
	Quests.on_dock(false, ship, true)    # queues the colony talk
	Quests.take_talks(false)
	Quests.advance_talk("dirtside_run")
	Quests.on_dock(true, ship, true)     # now prove_wings
	Quests.note_contract()
	var snap := Quests.to_dict()
	Quests.reset()
	Quests.from_dict(snap)
	if not Quests.active.has("prove_wings") or Quests.active["prove_wings"].count != 1:
		print("FAIL: save round-trip lost quest state")
		failures += 1
	Quests.from_dict({"active": {"bogus": {"stage": 3}}, "completed": ["fake"]})
	if not Quests.active.is_empty() or not Quests.completed.is_empty():
		print("FAIL: corrupt save entries accepted")
		failures += 1

	# EPHEMERAL QUEST POIs (user rule, 2026-07-23): a quest-only marker must NEVER be
	# revealed by flying past, must appear only while its stage is live, and vanish
	# the instant it isn't — no orphaned map clutter, no spoiler.
	Quests.reset()
	PoiMap.reset()
	PoiMap.register("cold_patch_site", "Anomalous Return", Vector2(4200, -1600), "signal", false, true)
	# 1. Proximity must NOT chart it (this is the whole bug).
	PoiMap.tick_discovery(Vector2(4200, -1600), 5000.0)
	if PoiMap.is_discovered("cold_patch_site"):
		print("FAIL: ephemeral POI was proximity-charted by flying near it")
		failures += 1
	# 2. It reveals only while its stage is the live objective.
	Quests.active["cold_patch"] = {"stage": 0, "count": 0}
	Quests.refresh_pois()
	if not PoiMap.is_discovered("cold_patch_site"):
		print("FAIL: ephemeral POI not revealed while its stage is active")
		failures += 1
	# 3. And it disappears the moment that stage is no longer active.
	Quests.active.erase("cold_patch")
	Quests.refresh_pois()
	if PoiMap.is_discovered("cold_patch_site"):
		print("FAIL: ephemeral POI lingered after its quest ended")
		failures += 1

	# ENTERING A STAGE RE-POINTS THE AUTO-WAYPOINT (the "Ask the Only One Who Ran"
	# bug, 2026-07-23): a lingering diamond from the previous beat must NOT block the
	# new objective's mark — but a MANUAL chart tag is still respected.
	Quests.reset()
	PoiMap.reset()
	PoiMap.register("planetoid", "Epharon", Vector2(500, 0), "planet", true)
	PoiMap.register("rust_shoal", "The Rust Shoal", Vector2(2600, -7600), "den")
	PoiMap.set_waypoint("planetoid", false)          # a lingering AUTO mark
	Quests.active["rust_shoal"] = {"stage": 0, "count": 0}
	Quests._enter_stage("rust_shoal")
	if PoiMap.waypoint_id != "rust_shoal":
		print("FAIL: entering a stage did not re-point the auto-waypoint (got %s)" % PoiMap.waypoint_id)
		failures += 1
	# A hand-tagged waypoint wins over the auto re-point.
	Quests.reset()
	PoiMap.reset()
	PoiMap.register("planetoid", "Epharon", Vector2(500, 0), "planet", true)
	PoiMap.register("rust_shoal", "The Rust Shoal", Vector2(2600, -7600), "den")
	PoiMap.set_waypoint("planetoid", true)           # player hand-tagged
	Quests.active["rust_shoal"] = {"stage": 0, "count": 0}
	Quests._enter_stage("rust_shoal")
	if PoiMap.waypoint_id != "planetoid":
		print("FAIL: a manual waypoint was clobbered by a stage entry")
		failures += 1

	# ---- requires_days: a follow-up that must WAIT (user, 2026-07-26) ----
	# legend_empty_cave opens with "Nobody's seen him. Three days." — which only
	# reads as a worry if three days have actually passed. Days advance per DOCKING,
	# so the wait is paced by play rather than by a real-world clock.
	Quests.reset()
	Research.reset()
	Quests.completed.append("legend_check_in")
	Quests.completed_day["legend_check_in"] = 10
	Research.day = 10
	Quests.check_new_work(true, true)
	if Quests.active.has("legend_empty_cave"):
		print("FAIL: the follow-up arrived the same day the favour was finished")
		failures += 1
	Research.day = 12                                  # two days on — still early
	Quests.check_new_work(true, true)
	if Quests.active.has("legend_empty_cave"):
		print("FAIL: the follow-up arrived on day 2 of a 3-day wait")
		failures += 1
	Research.day = 13
	for _i in 12:
		Quests.check_new_work(true, true)
	if not Quests.active.has("legend_empty_cave"):
		print("FAIL: the follow-up never arrived after its 3 days — a wait that "
			+ "never ends is a dead campaign, not pacing")
		failures += 1

	# AN OLD SAVE HAS NO RECORDED DAY. It must not be gated forever on information
	# it cannot have — a returning player would simply never see the beat again.
	Quests.reset()
	Research.reset()
	Quests.completed.append("legend_check_in")         # ...and NO completed_day entry
	Research.day = 0
	for _i in 12:
		Quests.check_new_work(true, true)
	if not Quests.active.has("legend_empty_cave"):
		print("FAIL: a pre-existing save with no completion day was locked out")
		failures += 1

	# THE SAGA KEEPS ITS HERMIT. legend_check_in must wait for `the_hermit`, or the
	# Campaign can empty the Counter's cave before the Saga sends you to talk to him.
	Quests.reset()
	Research.reset()
	Quests.completed.append("ember_word")
	# PUMP, do not call once. `check_new_work` starts one quest per call, so a single
	# call can be consumed by whatever else ember_word unblocks — and this assertion
	# would then pass because nothing started, not because the gate held. (Verified:
	# with the gate sabotaged back to `ember_word`, the one-call version still went
	# green. A test that cannot fail is not a test.)
	for _i in 12:
		Quests.check_new_work(true, true)
	if Quests.active.has("legend_check_in"):
		print("FAIL: the Legend line started before the Saga's hermit beat — the "
			+ "Counter can go missing before you are sent to speak with him")
		failures += 1
	Quests.completed.append("the_hermit")
	# `check_new_work` deliberately starts ONE fresh quest per call (dock pacing), and
	# clearing `the_hermit` also unblocks other beats — so pump it until it settles
	# rather than assuming this one is first in the list.
	for _i in 12:
		Quests.check_new_work(true, true)
	if not Quests.active.has("legend_check_in"):
		print("FAIL: the Legend line never started after the hermit beat")
		failures += 1

	# ---- requires_level: the Campaign's COLD STRETCHES (user, 2026-07-26) ----
	# The Legend spans the whole game by going quiet while the pilot grows. A beat
	# held back must stay held back, arrive when earned, and -- the part that matters
	# most -- SAY it is waiting, because a cold trail and a broken quest look
	# identical from the cockpit. A real save once sat frozen at ember_word for ~46
	# game days, which is where the idiot-proof-through-line rule came from.
	Quests.reset()
	Research.reset()
	Wallet.xp = 0
	var lvl_gate := {"requires": "legend_check_in", "requires_level": 12}
	Quests.completed.append("legend_check_in")
	if Quests._prereq_met(lvl_gate, "legend_check_in", true):
		print("FAIL: a level-12 beat opened for a level-1 pilot")
		failures += 1
	Wallet.xp = Pilot.xp_for_level(12)
	if Pilot.level() < 12:
		print("FAIL: test could not reach level 12 (got %d)" % Pilot.level())
		failures += 1
	elif not Quests._prereq_met(lvl_gate, "legend_check_in", true):
		print("FAIL: the beat never arrived after the level was earned — a gate that "
			+ "never opens is a dead campaign, not pacing")
		failures += 1

	# "You are not ready" must outrank "not yet": a beat gated on BOTH must report the
	# level, or a pilot waits out the days and still finds nothing.
	Wallet.xp = 0
	Quests.completed_day["legend_check_in"] = 0
	Research.day = 99
	var both := {"requires": "legend_check_in", "requires_level": 12, "requires_days": 3}
	if Quests._prereq_met(both, "legend_check_in", true):
		print("FAIL: days elapsed let a level gate through")
		failures += 1

	Wallet.xp = 0
	Quests.active.clear()
	if not ("level" in Quests.pending_reason("legend_empty_cave")
			or "day" in Quests.pending_reason("legend_empty_cave")
			or Quests.pending_reason("legend_empty_cave") == ""):
		print("FAIL: pending_reason returned something unreadable")
		failures += 1
	Research.day = 0
	Quests.completed_day["legend_check_in"] = 0
	var why := Quests.pending_reason("legend_empty_cave")
	if why == "":
		print("FAIL: a beat held by its 3-day wait explained nothing — silence and a "
			+ "bug are indistinguishable to the player")
		failures += 1
	Wallet.xp = 0

	# ---- SPINE NAMES: every throughline is "The <Something>" (user) ----
	# The Saga is "The Rise" -- the awkward rise of the Galeans onto the grand stage.
	# The spine's TITLE is stable; the current MOVEMENT rides as position, because a
	# log entry that renames itself underneath the player is disorienting.
	Quests.reset()
	if Quests.spine_name("saga") != "The Rise":
		print("FAIL: the Saga should read 'The Rise', got '%s'" % Quests.spine_name("saga"))
		failures += 1
	if Quests.spine_name("campaign") != "The Legend":
		print("FAIL: the Campaign should read 'The Legend', got '%s'"
			% Quests.spine_name("campaign"))
		failures += 1
	if Quests.movement_name("saga") != "The Gate":
		print("FAIL: Movement I should read 'The Gate', got '%s'"
			% Quests.movement_name("saga"))
		failures += 1

	# THE REVEAL MUST NEVER REACH THE LOG. This guards the PROPERTY, not the string:
	# "The Convergence" and "The Idiot" were both live candidates, and either would
	# hand the player the shape of the ending in their first hour. Whoever names
	# Movement II will be tempted the same way.
	for forbidden in ["Convergence", "Idiot", "Warden", "Prison"]:
		if forbidden in Quests.spine_name("saga") or forbidden in Quests.movement_name("saga"):
			print("FAIL: the Saga's log text says '%s' — that is the late reveal, "
				% forbidden + "printed from the first hour")
			failures += 1

	# Finishing a movement must not blank the entry: the spine outlives its parts.
	Quests.completed.append("nothing_left_behind")
	if Quests.spine_name("saga") == "":
		print("FAIL: with Movement I done the Saga has no title at all")
		failures += 1
	Quests.reset()

	Quests.reset()
	PoiMap.reset()
	Research.reset()
	Wallet.credits = 0
	Wallet.xp = 0
	
	if failures == 0:
		print("test_quests: ALL PASS")
	else:
		print("test_quests: %d FAILURES" % failures)
	quit(failures)
