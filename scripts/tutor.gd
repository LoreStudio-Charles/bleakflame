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
	# FLIGHT TRAINING — the old pre-Tutor "flight control" tutorial, folded in as
	# the FIRST lesson (user, 2026-07-24) so it runs first, pays the 150c/50xp that
	# funds everything after, and wears the Tutor's centred captions instead of a
	# top bar. Unpinned (centred) captions; a slim controller (Tutorial) drives the
	# mechanics — input tracking, the 3 practice drones, the payout — and calls
	# Tutor.did() to complete each step. Steps carry `id`s the controller reads.
	"flight_training": [
		{"id": "tut_launch", "anchor": "launch_hint", "pin": false, "text": "Welcome, Pilot — let's earn that license. Press [E] to launch."},
		{"id": "tut_thrust", "anchor": "effigy", "pin": false, "where": "flight", "text": "Fore and aft thrust: burn forward with [W], feel the weak reverse with [S]. Engines point back, so reverse is soft on every hull."},
		{"id": "tut_rotate", "anchor": "effigy", "pin": false, "where": "flight", "text": "Vector the nose with [A] and [D]. Your velocity holds its heading until you burn against it."},
		{"id": "tut_boostbrake", "anchor": "effigy", "pin": false, "where": "flight", "text": "Hold [SHIFT] to boost. Hold [SPACE] to brake to a full stop."},
		{"id": "tut_drones", "anchor": "effigy", "pin": false, "where": "flight", "text": "Practice drones inbound. RIGHT-CLICK a drone: that targets it AND switches your guns ON. When your target dies the guns switch OFF — right-click the next one. [Q] toggles your guns by hand. Clear all three."},
		{"id": "tut_dock", "anchor": "effigy", "pin": false, "text": "Well flown. Now bring her home and dock: line up ALONG the lane, ease the throttle, green is clean. Crawl her in when you're unsure."},
	],
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
	# The first ability a pilot ever owns. The bus AUTO-WIRES a fitted ability into
	# an open slot now (Pilot.autowire), so the lesson is no longer "go memorize it"
	# — it teaches FIRING. One flight step; completes the first time they run one,
	# and cannot restart (once fired, seen). This is the 2026-07-23 fix for the
	# "ability tutorial restarts every time the survey scan is equipped" bug.
	"memorize": [
		{"anchor": "gem_bar", "where": "flight", "text": "SYSTEM WIRED — your new ability sits on the [1]-[5] bus. Press its number key in flight to run it. (Rewire the bus any time from the Pilot tab at dock.)"},
	],
	# Taught the moment they undock for the planet: a first-timer has no idea
	# where the colony IS, and hunting for it is the confusing part — not the
	# flying. Anchored to the RADAR, because that is where navigation lives.
	"chart": [
		{"anchor": "radar", "where": "flight", "text": "Press [M] for the map — your destination is marked on it."},
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
		# (Launch is NOT taught here — see the "launch" lesson. The PLANETSIDE half of
		# the run — turning in, buying the return load — is the GROUND lesson
		# "ground_intro" now: the colony is a place, not a tab deck.)
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
	# STATION-ONLY as of 2026-07-25. It used to be venue-agnostic and anchored to
	# "tab_missions_planet" — a tab on the planet DOCK SCREEN, which no longer opens:
	# planetside is ground-native, and the colony's hand-in is a BUILDING you walk to
	# (taught by ground_intro's CONTRACT BOARD step). Left as-is it told a pilot standing
	# in the sand to open a tab that does not exist. Unpinned + dwell still, because the
	# tab already wears a pip and this is only the one-time explanation of it.
	"turn_in": [
		{"venue": "station", "anchor": "tab_missions", "where": "dock", "pin": false, "dwell": 9.0,
			"text": "That job can be closed out right here — the Mission Computer is wearing a mark. Open it and hand the cargo in for payment."},
	],

	# Only the STATION half lives here now — buying the food is the ground lesson's job.
	"trade_return": [
		{"venue": "station", "anchor": "market_goods", "where": "dock", "text": "That food in your hold: the station grows nothing and pays a premium for it. Sell here — that's the whole route, both ways."},
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
		{"anchor": "cargo_gauge", "where": "flight", "text": "Hold's full. Press [H] to manage cargo — grab what's nearby, jettison what isn't worth the mass."},
	],
	"ordnance": [
		{"anchor": "ord_gauge", "where": "flight", "text": "You're carrying ORDNANCE. Guns fire themselves once weapons are free, but rounds are finite and cost credits at dock — press [R] to launch them when it counts."},
	],
	"targeting": [
		{"anchor": "radar", "where": "flight", "text": "LEFT-CLICK targets without shooting — a rock to scan, an ally to help. RIGHT-CLICK a hostile to target it AND switch your guns on. [TAB] cycles hostiles. Most systems need a target."},
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
	"meet_ruel": [
		{"venue": "station", "anchor": "panel_bay", "where": "dock", "pin": false,
			"text": "Harbormaster Ruel has your first job — talk to him here at the Landing Bay."},
	],
	"meet_dex": [
		{"venue": "station", "anchor": "tab_pilot", "where": "dock", "pin": false, "dwell": 10.0,
			"text": "You haven't met Dex in the RESEARCH LAB. He trades Insight for scan data, and the lab is where artifacts get read — the long game starts there."},
	],
	"meet_doug": [
		{"anchor": "radar", "where": "flight", "dwell": 12.0,
			"text": "You're carrying ore. Doug Diggs buys it at THE DIG, out in the Verge — better than station rate. It's on your chart [M]."},
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

	# GROUND-MODE onboarding (2026-07-25) — the town replaces tab-poking with WALKING.
	# `where: "ground"` means the caption + a soft direction nudge live in the TOWN (not a
	# TutorPing on a Control), and `target` names the NPC or building to point at. Completion
	# is an IN-WORLD action folded in as a did() event: reaching the NPC (they notice +
	# approach) or [E]-ing the place. Watchdog treats "ground" steps as player-paced.
	# THE COLONY VISIT — the user's canonical order (2026-07-25): land -> Imari ->
	# contract board -> Sella -> market prices -> buy food -> spaceport -> launch.
	# (The station sell that closes the route is trade_return, at the station.)
	"ground_intro": [
		{"where": "ground", "target": "Imari", "anchor": "", "text": "Welcome to Epharon. Elder Imari keeps this place running — find her out by the Starport and see what she needs. [WASD] or hold the mouse to walk."},
		{"where": "ground", "target": "CONTRACTS", "anchor": "", "text": "Work gets settled at the colony's CONTRACT BOARD — walk over and turn in what you're carrying."},
		{"where": "ground", "target": "EXPLORERS GUILD", "anchor": "", "text": "Cartographer Sella maps the Reach from the Explorer's Union. Step inside and introduce yourself — she pays for the far dark."},
		{"where": "ground", "target": "MARKET", "anchor": "", "text": "Check the prices at Bram's MARKET — GREEN means a local bargain."},
		{"where": "ground", "target": "MARKET", "anchor": "", "text": "Food is GROWN here, so it's cheap — RIGHT-CLICK the shelf and buy 4 to sell back at the station."},
		{"where": "ground", "target": "STARPORT", "anchor": "", "text": "That's the colony. Lift off from your ship on the pad — or the Starport services desk."},
	],

	# --- ON-FOOT COMBAT. The plan deliberately held these back until the verbs existed
	# (docs/tutorial_revision_plan.md: "DO NOT teach yet"); ground combat landed
	# 2026-07-25, so they arm now. Each waits for the moment it MATTERS — a scrit in
	# view, a spent cell — never on landing, because a caption about killing things is
	# noise to someone who came down to sell food.
	"ground_fight": [
		{"where": "ground", "anchor": "", "text": "Something's out there. RIGHT-CLICK it to target AND open fire — [TAB] cycles what's near. Left-click only ever LOOKS."},
		{"where": "ground", "anchor": "", "text": "[Q] switches your weapon on and off by hand, and it switches off by itself when your target drops. [SPACE] kneels for cover — you take far less while you're down."},
	],

	# The character's own bus. Taught apart from the fight lesson on purpose: knowing
	# WHERE abilities come from (training, prepared at the dossier) is a different idea
	# from knowing how to shoot, and cramming both into one caption taught neither.
	"techniques": [
		{"where": "ground", "anchor": "", "text": "You know a few TECHNIQUES on foot — [1] to [5] along the bottom. Try one."},
		{"where": "ground", "anchor": "", "text": "Techniques are training, not hardware: press [P] and open TECHNIQUES to choose which five you carry. Your ship's abilities are a separate set."},
	],

	# Armed by a SPENT CELL, which is the only moment the answer is interesting.
	"meditate": [
		{"where": "ground", "anchor": "", "text": "Cell's low. Press [K] to MEDITATE — it floods back fast, but you're defenceless while you're down. Never in the open with something hunting."},
	],

	# The dossier is where levels, skills, standing, cargo and now equipment live, and
	# nothing ever mentioned it. Armed the first time the player has a REASON: a level
	# with a skill point waiting to be spent.
	# IN FLIGHT, unpinned. Skill points come from XP and XP comes from kills, so the
	# cockpit is where you are standing when you earn one — and an unpinned caption needs
	# no anchor, which is why it can't live in the "any context" bucket the validator
	# (rightly) insists must point at something real.
	"dossier": [
		{"where": "flight", "anchor": "effigy", "pin": false,
			"text": "You've earned a skill point. Press [P] for your dossier — level, skills, standing, what you're carrying, and the gear you wear on foot."},
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
## Lessons the watchdog NEVER retires — player-paced onboarding that must not "move it
## or lose it" (user, 2026-07-24): the caption WAITS as long as it takes. Safe because
## every step still completes on the ACTION (launch / thrust / dock), so it can't jam
## forever; and a stuck step here is the player reading, not a bug the watchdog must clear.
const PATIENT := ["flight_training", "meet_ruel"]

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
	if PATIENT.has(active) or str(_step_of(active, step).get("where", "")) == "ground":
		_stall = 0.0            # player-paced: waits as long as it takes (exploring a town / meeting people)
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


## The current (unfinished) step of ANY lesson — active, queued, or paused. Lets a
## spatial host (the town) peek at a dock lesson still waiting in the queue and map its
## objective to a place, so "open the Market tab" can be redirected to "walk to the
## MARKET building" while the tabbed lesson itself never has to know about the town.
static func step_for(id: String) -> Dictionary:
	if not LESSONS.has(id):
		return {}
	var at := step if id == active else int(_progress.get(id, 0))
	var steps: Array = LESSONS[id]
	return steps[at] if at < steps.size() else {}


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


## Force a lesson DONE by id — mark it seen and drop it from the active/pending queues.
## Used to end the flight tutorial the instant the pilot docks, from whatever step they
## were on (it's PATIENT now, so without this an early dock would hang it forever).
static func complete(id: String) -> void:
	if not seen.has(id):
		seen.append(id)
	if active == id:
		active = ""
		step = 0
	pending.erase(id)
	_progress.erase(id)


static func finish() -> void:
	if active != "" and not seen.has(active):
		seen.append(active)
	active = ""
	step = 0
	# Promote whatever was waiting, so a lesson armed mid-lesson still lands.
	# (pump() also does this every frame in flight, for the unsafe case.)
	pump()


# ============================================================================
# DECLARATIVE ENGINE (2026-07-23) — the fix for tutor fragility.
#
# Every tutor bug had one shape: a SIGNAL that didn't fire, or fired from the
# wrong place. The old model pushes state around imperatively — Tutor.arm() from
# a dozen call sites, Tutor.note() sprinkled wherever the player "does the thing".
# Here a lesson instead DECLARES its trigger (`_arm_pred[id]`) and each step its
# completion (`_done_pred[id][step]`) as predicates over a CONTEXT snapshot, and
# `observe()` evaluates them every frame. "Did someone remember to call note()?"
# becomes "is this true right now?" — which can't be forgotten or double-fired,
# and (because completion is a poll) a resumed lesson AUTO-SKIPS steps already
# satisfied, so an evicted lesson picks up exactly where it should.
#
# SAFE + INCREMENTAL: predicates are registered per lesson in _build_preds(). A
# lesson with no predicate still runs on the old arm/note path, so migration is
# one lesson at a time and nothing breaks in between. `note()` only touches the
# ACTIVE lesson's current pointing-anchor, so a leftover note() no-ops the moment
# a predicate has advanced past it — no double-advance.
# ============================================================================

## The game-state snapshot the predicates read, refreshed by observe().
static var ctx := {}
## One-shot EVENT flags for the few completions that aren't a level poll — firing
## an ability, opening the chart/comms/salvage, launching. An action site calls
## Tutor.did("x") ONCE, unconditionally (no anchor to match, nothing to miss — the
## failure mode note() had), and observe() folds these into the ctx so a step's
## predicate can read c.get("x"). Session-only; cleared on reset().
static var _did := {}


## Record that a one-shot tutorial-relevant action happened (replaces note() for
## genuine events). Unconditional: it cannot "miss" the way a mis-anchored note did.
static func did(event: String) -> void:
	_did[event] = true
## id -> Callable(ctx) -> bool. Lesson arms when true (and not seen/active/pending).
static var _arm_pred := {}
## id -> Array[Callable|null], one per step. Step completes when its predicate is
## true; a null entry falls back to note()/dwell for that step.
static var _done_pred := {}
static var _preds_built := false


## Drive the declarative engine from a fresh context snapshot. Called every frame
## in flight and on every dock refresh. Idempotent with the old arm/note path.
static func observe(snapshot: Dictionary) -> void:
	_build_preds()
	ctx = snapshot.duplicate()
	for k in _did:
		ctx[k] = true
	# Advance the active lesson past EVERY currently-satisfied step at once (instant
	# resume: an evicted lesson whose early steps are already done lands on the
	# right one). Bounded by step count; finish() clears `active` and ends the loop.
	var guard := 0
	while active != "" and guard < 16:
		guard += 1
		var dp: Array = _done_pred.get(active, [])
		if step >= dp.size() or not (dp[step] is Callable):
			break
		if not _fits(active, step) or not (dp[step] as Callable).call(ctx):
			break
		_complete_step()
	# Arm any declarative lesson whose trigger is now true.
	for id in _arm_pred:
		if seen.has(id) or pending.has(id) or id == active:
			continue
		# Scenery (tab-intro filler) only arms in a clear moment — never queued
		# behind real work, matching the old "arm only when idle" gate.
		if is_filler(id) and (active != "" or not pending.is_empty()):
			continue
		if (_arm_pred[id] as Callable).call(ctx):
			arm(id)
	pump()


## Advance the active step (declarative completion). Mirrors note()'s advance without
## the anchor gate — the predicate already decided the step is done.
static func _complete_step() -> void:
	if active == "":
		return
	step += 1
	_confirm()
	if step >= (LESSONS[active] as Array).size():
		finish()
	else:
		_chime()


## Register the arm/step predicates. Predicates are pure functions of the context
## dict, so they read game state through simple keys the callers populate. Built
## once; a lesson absent here still runs on the old imperative path.
static func _build_preds() -> void:
	if _preds_built:
		return
	_preds_built = true

	# FLIGHT TRAINING: armed explicitly by the Tutorial controller (no arm_pred — it
	# runs once on a fresh save). The controller sets each did() flag as the pilot
	# finishes that step's action; the flags are sticky so completion never misses.
	_done_pred["flight_training"] = [
		func(c): return c.get("tut_launched", false),
		func(c): return c.get("tut_thrust", false),
		func(c): return c.get("tut_rotate", false),
		func(c): return c.get("tut_boostbrake", false),
		func(c): return c.get("tut_drones", false),
		func(c): return c.get("tut_docked", false),
	]

	# --- Flight lessons (context "flight"): arm on a live condition, complete on a
	# poll or a dwell. The flight scene feeds the snapshot each frame (flight_test).
	# WHERE HULL/SHIELD/ARMOR/ENERGY live — foundational, shown on the first flight.
	# EVERY predicate reads keys with `c.get(key, false)` (or "", 0) — a DEFAULT, so a
	# missing ctx key is falsy, never a bool(null) crash that would silently break a
	# lesson. That defensiveness is part of "can't jam": a caller can forget a key.
	_arm_pred["vitals"] = func(c): return c.get("flying", false)
	# Doug exists the moment ore does — a place to fly to, not a screen to open.
	_arm_pred["meet_doug"] = func(c): return c.get("has_ore", false) and not c.get("met_doug", false)
	# The captain's log, once there is anything in it worth reading; completes [L].
	_arm_pred["log"] = func(c): return c.get("journal", false)
	_done_pred["log"] = [func(c): return c.get("log_opened", false)]
	# Running Dark: the pilot has SPENT reserves on an ability and still has a live
	# one gemmed, so both of its benefits (fast recharge + safe re-flash) are live.
	_arm_pred["running_dark"] = func(c): return c.get("energy_spent", false)
	# Targeting: something is on sensors but still far enough out that reading a
	# callout costs nothing — and completes the instant they lock ANY target.
	_arm_pred["targeting"] = func(c): return c.get("contact_far", false) and not c.get("has_target", false)
	_done_pred["targeting"] = [func(c): return c.get("has_target", false)]
	# Chart: there IS somewhere to go (a waypoint is set) and they haven't opened it.
	_arm_pred["chart"] = func(c): return c.get("flying", false) and c.get("waypoint_set", false) and not c.get("chart_opened", false)
	_done_pred["chart"] = [func(c): return c.get("chart_opened", false)]
	# Comms: a transmission has arrived; completes when they open the archive [C].
	_arm_pred["comms"] = func(c): return c.get("flying", false) and c.get("comms_any", false) and not c.get("comms_opened", false)
	_done_pred["comms"] = [func(c): return c.get("comms_opened", false)]
	# Salvage: the hold is full; completes when they open the cargo manager [H].
	_arm_pred["salvage"] = func(c): return c.get("flying", false) and c.get("hold_full", false) and not c.get("salvage_opened", false)
	_done_pred["salvage"] = [func(c): return c.get("salvage_opened", false)]
	# Ordnance: a magazine weapon is aboard; completes the first time they LAUNCH one [R].
	_arm_pred["ordnance"] = func(c): return c.get("flying", false) and c.get("carrying_ordnance", false) and not c.get("fired_ordnance", false)
	_done_pred["ordnance"] = [func(c): return c.get("fired_ordnance", false)]

	# --- The gear loop + firing (dock -> flight) ---
	# memorize: a fitted ability is WIRED to the bus (auto-wired now); completes the
	# first time they FIRE one. One step, can't restart — the #2 survey-scan fix.
	_arm_pred["memorize"] = func(c): return c.get("has_wired_ability", false) and not c.get("fired_ability", false)
	_done_pred["memorize"] = [func(c): return c.get("fired_ability", false)]
	# buy_scanner: a live scan need but no scan ability — walk buy (Armory) -> fit
	# (Engineering). Each step is a level poll of tab/inventory; auto-skips if the
	# pilot is already ahead.
	_arm_pred["buy_scanner"] = func(c): return c.get("needs_scan", false) and c.get("can_afford_scanner", false)
	_done_pred["buy_scanner"] = [
		func(c): return str(c.get("tab", "")) == "Armory",
		func(c): return c.get("armory_bought", false) or c.get("knows_scan", false),
		func(c): return str(c.get("tab", "")) == "Engineering Bay",
		func(c): return c.get("knows_scan", false),
	]

	# --- Dock: the trade loop ---
	# trade: armed at the station while the planet run is live AND Ruel has said it.
	_arm_pred["trade"] = func(c): return str(c.get("venue", "")) == "station" and c.get("dirtside_active", false) and not c.get("ruel_pending", false)
	_done_pred["trade"] = [
		func(c): return str(c.get("tab", "")) == "Mission",
		func(c): return c.get("accepted_contract", false),
		func(c): return str(c.get("tab", "")) == "Market",
		func(c): return int(c.get("cargo_circuits", 0)) >= 4,
	]
	# trade_return: the colony half of the reciprocal route.
	# Buy-food waits until the crate is DELIVERED — otherwise it jumped ahead of turning the
	# contract in to Imari, the actual reason you flew down (user, 2026-07-24).
	_arm_pred["trade_return"] = func(c): return str(c.get("venue", "")) == "station" and int(c.get("cargo_food", 0)) > 0
	_done_pred["trade_return"] = [
		func(c): return str(c.get("tab", "")) == "Market" and str(c.get("venue", "")) == "station",
	]

	# --- Dock: dwell / pip lessons (arm-only; a dwell timer retires them) ---
	# turn_in: a contract can be closed at this venue.
	_arm_pred["turn_in"] = func(c): return c.get("turn_in_here", false)
	# (meet_sella retired 2026-07-25: meeting her is a step of the GROUND sequence now.)
	_arm_pred["meet_dex"] = func(c): return c.get("dirtside_done", false) and str(c.get("venue", "")) == "station" and not c.get("met_dex", false)
	# meet_ruel: landed post-tutorial with Ruel holding the first job; done when you talk to him.
	_arm_pred["meet_ruel"] = func(c): return str(c.get("venue", "")) == "station" and c.get("dirtside_active", false) and c.get("ruel_pending", false)
	_done_pred["meet_ruel"] = [func(c): return not c.get("ruel_pending", true)]
	# The pip itself, the first time anyone is waiting.
	_arm_pred["pips"] = func(c): return c.get("pip_showing", false)
	# A commission door has been drawn (earned).
	_arm_pred["office"] = func(c): return c.get("office_open", false)
	# A commission is available and the pilot has never taken one.
	_arm_pred["commission"] = func(c): return str(c.get("venue", "")) == "station" and c.get("no_profession", false) and c.get("commission_eligible", false)
	_done_pred["commission"] = [
		func(c): return str(c.get("tab", "")) == "Pilot",
		func(c): return c.get("joined_commission", false),
	]

	# --- Dock: first-visit tab intros (FILLER; arm when that tab is open, dwell) ---
	_arm_pred["tab_intro_bay"] = func(c): return str(c.get("tab", "")) == "Landing Bay"
	_arm_pred["tab_intro_armory"] = func(c): return str(c.get("tab", "")) == "Armory"
	_arm_pred["tab_intro_engineering"] = func(c): return str(c.get("tab", "")) == "Engineering Bay"
	_arm_pred["tab_intro_market"] = func(c): return str(c.get("tab", "")) == "Market"
	_arm_pred["tab_intro_missions"] = func(c): return str(c.get("tab", "")) == "Mission"
	_arm_pred["tab_intro_shipyard"] = func(c): return str(c.get("tab", "")) == "Shipyard"
	_arm_pred["tab_intro_research"] = func(c): return str(c.get("tab", "")) == "Research Lab"
	_arm_pred["tab_intro_bar"] = func(c): return str(c.get("tab", "")) == "Ember Row"

	# --- GROUND (context "ground"): the town publishes the snapshot + draws the caption/
	# nudge; each step completes on an in-world action folded in as a did() event.
	_arm_pred["ground_intro"] = func(c): return c.get("on_ground", false) and c.get("tutorial_done", false)
	_done_pred["ground_intro"] = [
		func(c): return c.get("met_imari", false),
		func(c): return c.get("turned_in", false) or c.get("used_mission_uplink", false),
		func(c): return c.get("met_sella", false),
		func(c): return c.get("used_market", false),
		func(c): return int(c.get("cargo_food", 0)) >= 4,
		func(c): return c.get("launched", false),
	]

	# ON-FOOT COMBAT. Armed by the SITUATION, never by landing: a hostile you can
	# actually see. `hostile_near` is published by the town each frame.
	# NOTE every ground-combat lesson also requires `tutorial_done`. That is its OWN
	# precondition (you are a licensed pilot), NOT chaining off another lesson finishing —
	# the forbidden pattern. Without it they armed during FLIGHT TRAINING and took the
	# slot the colony onboarding needed, which is exactly the starvation shape the
	# declarative engine exists to prevent.
	_arm_pred["ground_fight"] = func(c): return c.get("on_ground", false) \
		and c.get("tutorial_done", false) and c.get("hostile_near", false)
	_done_pred["ground_fight"] = [
		func(c): return c.get("ground_engaged", false),
		func(c): return c.get("ground_weapons_toggled", false) or c.get("ground_kneeled", false),
	]
	# Techniques: you must actually KNOW one, or the lesson points at an empty bar.
	_arm_pred["techniques"] = func(c): return c.get("on_ground", false) \
		and c.get("tutorial_done", false) and c.get("has_technique", false)
	_done_pred["techniques"] = [
		func(c): return c.get("used_technique", false),
		func(c): return c.get("dossier_opened", false),
	]
	# Meditate answers a question the player is ALREADY asking — "why won't this fire?"
	# — so it waits for a cell spent below half with a technique prepared.
	_arm_pred["meditate"] = func(c): return c.get("on_ground", false) \
		and c.get("tutorial_done", false) and c.get("has_technique", false) \
		and float(c.get("energy_frac", 1.0)) < 0.5
	_done_pred["meditate"] = [func(c): return c.get("meditated", false)]
	# The dossier, the first time there is something to DO in it. Not venue-gated: [P]
	# opens anywhere, and the moment you earn a point is the moment to say so.
	_arm_pred["dossier"] = func(c): return int(c.get("skill_points", 0)) > 0
	_done_pred["dossier"] = [func(c): return c.get("dossier_opened", false)]


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
	_did.clear()
	ctx = {}
	_progress.clear()
