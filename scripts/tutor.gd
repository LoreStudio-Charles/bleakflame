class_name Tutor
## ATTENTION PINGS — the game teaching by POINTING, not by doing it for you.
##
## When a pilot first has an ability they've never memorized, the answer is not
## to quietly memorize it (that teaches nothing and hides a whole system) and not
## to open a wall of text. It's to make the right button glow until they press
## it. They perform the action themselves, so they know how next time.
##
## A LESSON is an ordered list of STEPS. Each step names a UI ANCHOR — a string
## a screen registers for a control it owns — plus one line of copy. A step
## clears when the player does the thing (`note()`), never on a timer, so the
## ping is always pointing at the next real action.
##
## Lessons fire ONCE EVER (persisted in SaveGame.tutor_seen). Ping, learn, gone.
##
## Adding a lesson = one LESSONS entry + `Tutor.arm("id")` where it becomes
## relevant + `Tutor.note("anchor")` where the player completes each step.
## Screens only have to call `register()` for the controls they own.

const LESSONS := {
	# WHERE YOUR VITALS LIVE — the first thing a new pilot needs to be able to
	# read: the effigy carries HULL/SHIELD/ARMOR and the reactor ENERGY pill, all
	# in one place. Pinned at the effigy with a dwell so it points, teaches, and
	# retires on its own (no action to complete, can't jam the queue).
	"vitals": [
		{"anchor": "effigy", "where": "flight", "dwell": 13.0,
			"text": "YOUR SHIP AT A GLANCE (top-left): the ship sprite is your HULL — it tints green→amber→red as you take hits. The ring is your SHIELD (regenerates), the outline your ARMOR. The glowing pill is ENERGY — abilities spend it, and it recharges over time. When hull hits red, dock or run."},
	],
	# THE BIG ONE, armed when the lab asks for a scan and the ship has no
	# scanner. It walks the entire gear loop in the order a pilot will repeat
	# forever after — buy in the Armory, fit on the paperdoll — and lands them
	# holding an ability, which arms "memorize" straight after. One continuous
	# lesson from "I need a thing" to "the thing is on my number keys".
	"buy_scanner": [
		{"venue": "station", "anchor": "tab_armory", "where": "dock", "tab": "Armory", "text": "The lab wants a survey scan — and you don't have that ability yet. Open the Armory."},
		{"venue": "station", "anchor": "armory_shop", "where": "dock", "text": "Buy the SURVEY ROUTINE chip. RIGHT-CLICK a tile to buy. Abilities are chips — every one of them."},
		{"venue": "station", "anchor": "tab_engineering", "where": "dock", "tab": "Engineering Bay", "text": "A chip in your hold does nothing. Open Engineering."},
		{"venue": "station", "anchor": "coupling", "where": "dock", "text": "Drop it into your UNIVERSAL COUPLING — the rack that holds everything your ship KNOWS. (Right-click a chip to load it.)"},
	],
	# The first ability a pilot ever owns. Fitting is done — this is the step
	# everyone misses: a known ability still has to be MEMORIZED to a gem.
	"memorize": [
		{"anchor": "tab_pilot", "where": "dock", "tab": "Pilot", "text": "New ability aboard — open PILOT to bring it online."},
		{"anchor": "loadout", "where": "dock", "text": "Pick a bus slot, then choose the ability. It fires on that number key."},
		{"anchor": "gem_bar", "where": "flight", "text": "SYSTEM LIVE — press its key in flight to run it."},
	],
	# Taught the moment they undock for the planet: a first-timer has no idea
	# where the colony IS, and hunting for it is the confusing part — not the
	# flying. Anchored to the RADAR, because that is where navigation lives.
	"chart": [
		{"anchor": "radar", "where": "flight", "text": "Press [G] for the system chart — your destination is marked on it."},
	],
	# Fired by the FIRST transmission a pilot ever receives. Comms scroll away,
	# and nothing tells you they were kept — so the one thing worth teaching is
	# that nothing is ever lost.
	# RUNNING DARK. Taught once the pilot has actually SPENT reserves on an ability
	# (energy below the pool), so both of its benefits are live and legible. In
	# the fiction: cutting every system means (1) the circuits are cold, so you
	# can re-flash your Processor Bus — change which abilities are loaded —
	# without frying yourself, and (2) the reactor is no longer feeding systems,
	# so it dumps everything into refilling Capacity, far faster than in flight.
	# Unpinned + dwell: [K] is a key, not a widget, and this can never starve.
	"running_dark": [
		{"anchor": "gem_bar", "where": "flight", "pin": false, "dwell": 13.0,
			"text": "Reserves down? Press [K] to run DARK — every system offline. The reactor stops feeding them and floods your energy Capacity back instead. Cold circuits are also safe to re-flash: swap which abilities are loaded, right there in the black. Reboot when you're ready."},
	],

	"comms": [
		{"anchor": "comms_badge", "where": "flight", "text": "Every transmission is archived — press [C] to re-read anything you missed."},
	],
	# THE TRADE LOOP, taught across two venues in one lesson: buy where a good
	# is MADE, sell where it is WANTED. Armed when the pilot is about to fly to
	# the planet anyway, so the cargo run costs them nothing but hold space and
	# the profit lands as a discovery rather than a lecture.
	"trade": [
		{"venue": "station", "anchor": "tab_missions", "where": "dock", "tab": "Mission", "text": "You're heading planetside — get PAID for the trip. Open the Mission Computer."},
		{"venue": "station", "anchor": "offers", "where": "dock", "item": "Circuits", "text": "This one — 4 Circuits down to the colony. Select it, then Accept."},
		{"venue": "station", "anchor": "tab_market", "where": "dock", "tab": "Market", "text": "The contract doesn't supply the cargo — you do. Open the MARKET."},
		{"venue": "station", "anchor": "market_goods", "where": "dock", "good": "circuits", "need": 4,
			"text": "Circuits are MADE here, so they're cheap. Buy the 4 you owe — and a few spare to sell down there."},
		# (Launch is NOT taught here — see the "launch" lesson, which fires at the
		# very first countdown. By the time a pilot is running freight they have
		# launched a dozen times, and explaining it then reads as the game not
		# paying attention.)
		# Landed. Without this step the turn-in ping lives INSIDE the missions
		# tab, so a pilot who never opens it sees nothing and flies home still
		# carrying the freight.
		{"venue": "planet", "anchor": "tab_missions_planet", "where": "dock", "tab": "Mission", "text": "Down safe, still carrying their freight. Open the Mission Uplink."},
		{"venue": "planet", "anchor": "contracts_held", "where": "dock", "text": "Turn the contract in here for the reward."},
	],

	# THE RETURN LEG. The trade route is RECIPROCAL — the station manufactures,
	# the colony grows — so a pilot who only learns the outbound run flies home
	# empty half the time. Taught at the colony, paid at the station, which
	# closes the loop and makes the route feel like a circuit rather than an
	# errand.
	# HANDING IN. Nothing in the UI announced that a contract was ready to close:
	# a pilot could land, chat, and fly home still carrying the crate. This is
	# armed at whichever venue can actually take the delivery.
	# ONE UNPINNED STEP ON A TIMER, deliberately. This lesson can arm at EITHER
	# venue, and the mission tab's anchor differs between them — a pinned step
	# naming one venue's anchor would sit forever at the other, blocking every
	# lesson behind it. Unpinned + dwell cannot starve the queue, and the tab
	# already wears a PIP whenever something is closeable, which is the durable
	# signal; this is just the one-time explanation of it.
	"turn_in": [
		{"anchor": "tab_missions_planet", "where": "dock", "pin": false, "dwell": 9.0,
			"text": "That delivery can be closed out right here — the Mission board is wearing a mark. Open it and hand the cargo in for payment."},
	],

	"trade_return": [
		{"venue": "planet", "anchor": "tab_market_planet", "where": "dock", "tab": "Market", "text": "Never fly home empty. Open the colony MARKET."},
		{"venue": "planet", "anchor": "market_goods_planet", "where": "dock", "good": "food", "need": 4,
			"text": "The colony GROWS food — down here it's cheap. Fill your hold."},
		{"venue": "station", "anchor": "market_goods", "where": "dock", "text": "The station grows nothing and pays a premium for it. Sell here — that's the whole route, both ways."},
	],

	# THE VERY FIRST COUNTDOWN. The old tutorial already says "press E to
	# launch"; what it never mentions is that the window can be SCRUBBED. This
	# fires the first time a countdown is ever on screen — the only honest
	# moment to teach it — and any launch at all satisfies the whole thing, so a
	# pilot who just flies is never nagged about a branch they skipped.
	"launch": [
		{"anchor": "launch_window", "text": "Launch window open. [E] goes NOW, [Q] scrubs it — try scrubbing, you can always stand down."},
		{"anchor": "launch_hint", "where": "dock", "pin": false, "text": "Stood down, no harm done. Press [E] again when you're ready to fly."},
	],

	# --- Flight keybinds. Each is armed at the moment it first MATTERS, never
	# on a timer, so the game only ever explains a thing you are already doing.
	"log": [
		{"anchor": "missions_hud", "where": "flight", "text": "Press [L] for the captain's log — every lead, order and discovery is kept there."},
	],
	"salvage": [
		{"anchor": "cargo_gauge", "where": "flight", "text": "Hold's full. Press [B] to manage cargo — grab what's nearby, jettison what isn't worth the mass."},
	],
	"ordnance": [
		{"anchor": "ord_gauge", "where": "flight", "text": "You're carrying ORDNANCE. Rounds are finite and cost credits at dock — press [Z] to hold them and fire guns only."},
	],
	"targeting": [
		{"anchor": "radar", "where": "flight", "text": "RIGHT-CLICK a contact to target it — [T] cycles hostiles, [Y] friendlies. Most systems need a target."},
	],

	# THE PIP ITSELF. Taught the first time one ever appears, because the whole
	# conversation system now depends on the player reading a dot: nobody
	# ambushes you at the ramp any more, so a pilot who does not know what the
	# dot means simply never hears the campaign.
	#
	# UNPINNED on purpose — the pip is already the thing being pointed at, and
	# framing a tab that is itself wearing a marker just adds a second marker.
	"pips": [
		{"anchor": "tab_pilot", "where": "dock", "pin": false, "dwell": 9.0,
			"text": "See the pulsing dot on a tab? Someone in there wants a word. Open it and talk to them — nobody will interrupt you at the ramp."},
	],

	# THE OFFICE DOOR. Armed the moment a door is first DRAWN — not when the
	# invitation is earned — because which tab it appears on depends on which
	# leader invited you (Ruel's is the Landing Bay, Dex's the Research Lab,
	# Doug's is a different SCREEN entirely at the Verge). A static `tab` step
	# could never name the right room, so instead the lesson is armed with the
	# door and the ping simply waits for the pilot to open that tab: an anchor
	# with no visible claimant draws nothing until there is one.
	"office": [
		{"anchor": "office_door", "where": "dock", "dwell": 10.0,
			"text": "A door has opened. Commissions are signed in person, in their office — and reading the terms costs you nothing. Step inside and see what it grants before you decide."},
	],

	# --- INTRODUCTIONS. The campaign personally presents Ruel, Voss, Dex, Imari,
	# the Counter and Krayt; it never presents SELLA or DOUG at all, so a pilot
	# could finish the whole starter arc without learning that the Explorer's
	# Union and the Prospector Guild have faces — quietly hiding two professions.
	#
	# These use the TUTOR CALLOUT, deliberately NOT the tab pip. The pip means
	# "someone here has business with you"; overloading it with "here is a person
	# who exists" would teach players that a pip is story and then disappoint
	# them. Two meanings, two visual languages.
	"meet_sella": [
		{"venue": "planet", "anchor": "tab_explorers", "where": "dock", "tab": "Explorer's Union", "dwell": 10.0,
			"text": "You haven't met the colony's cartographer. Sella pays credits for scan data — and posts survey work the lab can't match."},
	],
	"meet_dex": [
		{"venue": "station", "anchor": "tab_pilot", "where": "dock", "pin": false, "dwell": 10.0,
			"text": "You haven't met Dex in the RESEARCH LAB. He trades Insight for scan data, and the lab is where artifacts get read — the long game starts there."},
	],
	"meet_doug": [
		{"anchor": "radar", "where": "flight", "dwell": 12.0,
			"text": "You're carrying ore. Doug Diggs buys it at THE DIG, out in the Verge — better than station rate. It's on your chart [G]."},
	],

	# --- FIRST VISIT to each dock tab. Self-paced by design: these arm when the
	# pilot opens the tab, so curiosity sets the tempo and nothing fires until
	# they are already looking at the thing being explained.
	"tab_intro_bay": [
		{"anchor": "panel_bay", "dwell": 8.0, "text": "The Landing Bay: repairs and restock happen automatically, billed on arrival. Your ship and pilot summary live here."},
	],
	"tab_intro_armory": [
		{"venue": "station", "anchor": "panel_armory", "dwell": 8.0, "text": "The Armory sells CLEAN factory gear. RIGHT-CLICK to buy or sell; left-click to inspect. Salvage is where the treasure is."},
	],
	"tab_intro_engineering": [
		{"venue": "station", "anchor": "panel_engineering", "dwell": 8.0, "text": "Engineering: drag parts onto the hull to fit them. RIGHT-CLICK a part to auto-fit, or a fitted slot to remove it."},
	],
	"tab_intro_market": [
		{"anchor": "panel_market", "dwell": 8.0, "text": "The Market. GREEN is a good deal here, RED is a bad one — buy cheap where it's made, sell dear where it's wanted."},
	],
	"tab_intro_missions": [
		{"anchor": "panel_missions", "dwell": 8.0, "text": "The contract board. Work offered HERE may be turned in elsewhere — check where each one ends."},
	],
	"tab_intro_shipyard": [
		{"venue": "station", "anchor": "panel_shipyard", "dwell": 8.0, "text": "The Shipyard sells whole ships, flight-ready. Anything you buy stays yours — board any owned hull in Engineering."},
	],
	"tab_intro_research": [
		{"venue": "station", "anchor": "panel_research", "dwell": 8.0, "text": "The Research Lab turns Scan Data into INSIGHT, and Insight into permanent upgrades. Artifacts pay out forever."},
	],
	"tab_intro_bar": [
		{"venue": "station", "anchor": "panel_bar", "dwell": 8.0, "text": "Ember Row. Rumours come from CONVERSATION — ask for the word, and you'll hear what the Reach is whispering."},
	],

	# Standing has crossed a leader's threshold. A commission is the gate to a
	# profession's skills AND its quartermaster, and nothing else in the UI
	# announces that it's now available.
	"commission": [
		{"venue": "station", "anchor": "tab_pilot", "where": "dock", "tab": "Pilot", "text": "Someone's been watching your work. Open PILOT."},
		{"anchor": "commissions", "where": "dock", "text": "Green means an invitation. You sign on with the LEADER, not here — go and see them where they work, and their office door will be beside them."},
	],
}

static var seen: Array[String] = []
static var active := ""
static var step := 0

## anchor id -> Control, registered by whichever screen owns it. Weak by
## convention: screens re-register on build, and stale entries are validated
## before use rather than tracked.
static var _anchors := {}


## MANY nodes can share an anchor name — the station dock screen and the planet
## dock screen both build a "market", and the Shoal will too. Keep every
## claimant and resolve to whichever is actually ON SCREEN, or the last screen
## constructed would silently steal the anchor from the one you're looking at.
static func register(anchor: String, node: Control) -> void:
	if not _anchors.has(anchor):
		_anchors[anchor] = []
	var list: Array = _anchors[anchor]
	# Drop dead claimants as we go — screens are rebuilt often, and a freed
	# entry is a landmine for anything that inspects the list later.
	for i in range(list.size() - 1, -1, -1):
		if not is_instance_valid(list[i]):
			list.remove_at(i)
	if not list.has(node):
		list.append(node)


## ONLY ever returns something the player can actually SEE. It used to fall back
## to a registered-but-hidden control, which drew a leader line off to a node on
## a screen that wasn't up — a line to nowhere. No visible claimant means no
## pointer, and the caller decides what to do about it.
##
## NOTE the guard order: `is_instance_valid` MUST come before `is`, because
## evaluating `is` against a freed instance throws.
static func anchor_node(anchor: String) -> Control:
	var list: Array = _anchors.get(anchor, [])
	for n in list:
		if not is_instance_valid(n) or not (n is Control):
			continue
		if n.is_visible_in_tree():
			return n
	return null


## Begin a lesson, unless it has already been taught or one is already running.
## QUEUED, not dropped (2026-07-22). Only one lesson pings at a time — two sets
## of brackets on one screen is noise, not guidance — but a lesson armed while
## another is running must WAIT rather than be lost. The opening hour now has
## several (market, chart, docking, scanner, memorize, comms, commission) and
## they will overlap; silently discarding one means a system is never taught.
static var pending: Array[String] = []

## SAFE TO TEACH (user, 2026-07-22). A callout across the middle of the screen
## is dangerous during a fight — it covers the very space a pilot is reading to
## stay alive, and a lesson learned while being shot at is not learned at all.
## The flight scene sets this false near live hostiles and true when docked, in
## the station sanctuary, under a truce, or simply alone in open space.
##
## Unsafe does NOT discard a lesson: arming queues it, and the pings stop
## drawing until it's safe again. The teaching waits for a quiet moment rather
## than competing with a threat.
static var safe := true

## WHERE THE PLAYER IS: "dock" or "flight". A step may declare a `where`, and a
## lesson whose current step doesn't belong here YIELDS its slot to one that
## does — the comms lesson ([C] is flight-only) was holding the queue while
## docked and blocking the trade lesson the player was standing in.
##
## Yielding is not cancelling: progress is remembered per lesson and restored
## when the pilot is back somewhere the step makes sense.
static var context := "dock"
## Which dock you are actually standing in: "station" / "planet" / "verge", and
## "" in flight. Set by whichever screen is up; read by _fits.
static var venue := ""
static var _progress := {}


static func _step_of(id: String, at: int) -> Dictionary:
	var steps: Array = LESSONS.get(id, [])
	return steps[at] if at < steps.size() else {}


## Does this step belong at the player's current location? Steps with no `where`
## fit anywhere (most of them — a tab is a tab).
## WHERE a step is allowed to run: the broad context ("dock"/"flight") AND, when
## the step names one, the specific VENUE.
##
## `where: "dock"` is true at the station AND the colony AND the Verge, so a
## station-only lesson that got QUEUED behind another one would happily pump the
## next time you docked anywhere — a pilot standing on the colony's landing pad
## was told to go and meet Dex at the station's Research Lab. Arming at the right
## venue is not enough; the step has to still be right when it finally runs.
static func _fits(id: String, at: int) -> bool:
	var step := _step_of(id, at)
	var where := str(step.get("where", ""))
	if where != "" and where != context:
		return false
	var want := str(step.get("venue", ""))
	return want == "" or want == venue


## `queue = false` for lessons that only make sense RIGHT NOW — the launch
## lesson points at a countdown window that exists for four seconds. Queueing it
## would surface the copy long after the thing it describes had closed. It stays
## unseen, so the next countdown offers it again.
static func arm(id: String, queue := true) -> void:
	if seen.has(id) or not LESSONS.has(id) or pending.has(id) or id == active:
		return
	# A REAL LESSON EVICTS SCENERY. If a tab blurb holds the slot when something
	# with an objective arrives, the blurb stands down and waits its turn —
	# otherwise the objective's ping is invisible until the blurb's timer runs
	# out, which is exactly how "buy 4 food" got replaced by "GREEN is a good
	# deal" and then vanished on its own.
	if active != "" and is_filler(active) and not is_filler(id) and safe:
		_progress[active] = step
		if not pending.has(active):
			pending.append(active)
		active = ""
		step = 0
	if active != "" or not safe:
		if queue:
			pending.append(id)
		return
	active = id
	step = 0
	_chime()


## Keep the ACTIVE lesson relevant to where the player is, and promote a queued
## one when the slot is free. Runs every frame, docked or flying.
## FILLER = the tab-intro blurbs. They have nothing to do, retire on a timer,
## and arm whenever a tab is opened — which let them CUT IN FRONT of a lesson
## with an actual objective. A pilot opened the colony Market mid-"buy 4 food",
## got the 8-second "GREEN is a good deal" blurb instead, and watched it vanish
## on its own timer without having bought anything. Objectives outrank scenery.
static func is_filler(id: String) -> bool:
	return id.begins_with("tab_intro_")


## ---- WATCHDOG ----
##
## THE TUTOR MUST NOT BE ABLE TO JAM. Every tutor bug found in playtest had one
## shape: a lesson entered a state it could never leave, and everything queued
## behind it starved in silence — an anchor nothing claimed, a step waiting on a
## tab-change that had already happened, a venue that never came back. Rather
## than keep patching individual causes, a stuck lesson now gives up.
##
## `STALL_LIMIT` counts only time the lesson was ELIGIBLE (safe, right context,
## right venue) and still on screen doing nothing. A pilot reading slowly is not
## stalled; a lesson pointing at something that does not exist is.
const STALL_LIMIT := 50.0

static var _stall := 0.0
static var _stall_key := ""

## ---- STALL LOG (reviewable) ----
##
## Every time the watchdog gives up on a lesson it records WHY here, aggregated
## by lesson:step:anchor so a bug that recurs shows a rising `count` rather than
## flooding. Persisted in the save; reviewed with tools/dump_tutor_stalls.gd.
## The point is a to-do list of tutor bugs written by the game itself: each row
## is "this lesson could not complete for real players, here is where it stuck".
static var stalls := {}   # "lesson:step:anchor" -> {lesson, step, anchor, context, venue, count, last_day}


## Record a lesson the watchdog abandoned. `where` is a short reason string so
## the log distinguishes "no anchor on screen" from "never became eligible".
static func record_stall(id: String, at: int, why: String) -> void:
	var st := _step_of(id, at)
	var anchor := str(st.get("anchor", "?"))
	var key := "%s:%d:%s" % [id, at, anchor]
	var row: Dictionary = stalls.get(key, {
		"lesson": id, "step": at, "anchor": anchor,
		"where": str(st.get("where", "")), "venue": str(st.get("venue", "")),
		"count": 0, "last_day": 0})
	row["count"] = int(row["count"]) + 1
	row["last_day"] = Research.day
	row["reason"] = why
	stalls[key] = row
	Telemetry.warn("tutor", "'%s' step %d stalled (anchor %s)" % [id, at, anchor])


## Call once per frame from the flight scene. Retires a lesson that cannot
## possibly be completed so the queue always drains.
static func tick(delta: float) -> void:
	if active == "":
		_stall = 0.0
		_stall_key = ""
		return
	if not safe or not _fits(active, step):
		return                      # not its moment; that is waiting, not stalling
	var key := "%s:%d" % [active, step]
	if key != _stall_key:
		_stall_key = key
		_stall = 0.0
		return
	_stall += delta
	if _stall < STALL_LIMIT:
		return
	# Stuck. Give up on THIS lesson rather than block every other one forever.
	var stuck := active
	var stuck_step := step
	push_warning("Tutor: '%s' step %d stalled for %.0fs with anchor '%s' — retiring it."
		% [stuck, stuck_step, STALL_LIMIT, str(current().get("anchor", "?"))])
	record_stall(stuck, stuck_step, "stalled %ds while eligible" % int(STALL_LIMIT))
	_stall = 0.0
	_stall_key = ""
	retire(stuck)


static func pump() -> void:
	# The active lesson no longer belongs here — stand it down and let something
	# useful have the slot.
	if active != "" and not _fits(active, step):
		_progress[active] = step
		if not pending.has(active):
			pending.append(active)
		active = ""
		step = 0
	if active != "" or not safe or pending.is_empty():
		return
	# Take the first queued lesson that fits HERE, leaving the others waiting —
	# but REAL LESSONS FIRST. Two passes: anything with an objective, then the
	# filler. Without this a tab-intro blurb could take the slot a half-finished
	# objective was waiting for.
	for pass_filler in [false, true]:
		for i in pending.size():
			var id: String = pending[i]
			if seen.has(id):
				pending.remove_at(i)
				return
			if is_filler(id) != pass_filler:
				continue
			var at: int = int(_progress.get(id, 0))
			if _fits(id, at):
				pending.remove_at(i)
				active = id
				step = at
				_chime()
				return


## Audio cue (user, 2026-07-22). Quiet and high — an instrument noticing
## something, not an alarm. It fires when a step ARMS, so the sound and the
## first pulse of the ping land together and the ear sends the eye looking.
## "click" is a 25ms sweep — inaudible as a cue, which is why the first pings
## landed silently. "pickup" is a rising tone that actually reads as ATTENTION.
static func _chime() -> void:
	Sfx.play("pickup", -4.0, 1.25)


## Two-tone acknowledgement: the step you were pointed at is done.
static func _confirm() -> void:
	Sfx.play("dock", -8.0, 1.3)


static func current() -> Dictionary:
	if active == "" or not LESSONS.has(active):
		return {}
	var steps: Array = LESSONS[active]
	return steps[step] if step < steps.size() else {}


## Is this anchor the thing we're currently pointing at?
static func is_pointing(anchor: String) -> bool:
	var c := current()
	return not c.is_empty() and str(c.get("anchor", "")) == anchor


## The player did the thing. Advance if it was what we were waiting for, and
## retire the lesson when the last step lands.
static func note(anchor: String) -> void:
	if not is_pointing(anchor):
		return
	step += 1
	_confirm()
	if step >= (LESSONS[active] as Array).size():
		finish()
	else:
		_chime()   # the next target lights up, and says so


## RETIRE A WHOLE LESSON the player has already demonstrated, wherever it sits —
## active, queued, or not yet armed. note() only advances the ACTIVE lesson, so a
## pilot who did the thing while its lesson was still QUEUED behind another one
## would later be pinged at a door they had already walked through. Use this when
## an action proves the lesson is unnecessary, regardless of queue position.
static func retire(id: String) -> void:
	if not LESSONS.has(id):
		return
	pending.erase(id)
	if not seen.has(id):
		seen.append(id)
	if active == id:
		active = ""
		step = 0
		pump()


## Advance PAST any of these anchors — for a branch the player can simply skip.
## The launch lesson offers a scrub they don't have to try: if they just fly,
## every remaining launch step is satisfied and never shown again.
static func skip(anchors: Array) -> void:
	while active != "" and str(current().get("anchor", "")) in anchors:
		step += 1
		if step >= (LESSONS[active] as Array).size():
			finish()
			return


static func finish() -> void:
	if active != "" and not seen.has(active):
		seen.append(active)
	active = ""
	step = 0
	# Promote whatever was waiting, so a lesson armed mid-lesson still lands.
	# (pump() also does this every frame in flight, for the unsafe case.)
	pump()


## The stall log as plain data for the save. NOT cleared by reset(): a fresh
## pilot inherits the known-bug list so it keeps accumulating across playtests —
## that is the whole value of it.
static func stalls_to_list() -> Array:
	return stalls.values()


static func stalls_from_list(rows: Array) -> void:
	stalls.clear()
	for r in rows:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var key := "%s:%d:%s" % [str(r.get("lesson", "")), int(r.get("step", 0)),
			str(r.get("anchor", "?"))]
		stalls[key] = r


static func reset() -> void:
	seen.clear()
	pending.clear()
	active = ""
	step = 0
	_anchors.clear()
