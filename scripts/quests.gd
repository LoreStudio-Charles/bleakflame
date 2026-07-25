class_name Quests
## Authored story quests — the campaign's spine (docs/campaign_starter_system.md).
## Data-driven stages like Research.CHAINS, but with NPC givers, quest text,
## and rewards. Statics persist via SaveGame ("quests").
##
## Stage kinds:
##   contracts — complete `n` procedural contracts (MissionLog turn-ins)
##   goto      — reach world position `pos` within `radius`; entering the
##               stage charts `poi` (and waypoints it if none is set)
##   report    — dock at the station
##   talk      — have a conversation with `npc` at `venue` (station|planet):
##               the stage's `dialogue` nodes auto-present on docking there,
##               and finishing the conversation advances the stage. This is
##               the campaign's workhorse (the hermit, Krayt's comms).
##   scan_target — survey a quest-placed Anomaly at `pos` (charts `poi`, the
##               flight scene spawns the Anomaly). Scanning it advances.
##   survive_event — fly to `pos` (charts `poi`); arriving triggers a
##               SCRIPTED ambush (flight scene spawns a lesser Cinderweb and
##               suspends the ambient one). Reaching the station's light
##               advances the stage — you survive, you don't win.
##   (scan_target extras: optional `anomaly` ("residue"|"tendril") sets the
##               look; optional `escort: true` gives a protective Guardian
##               wing that clears pirates off your approach.)
##   goto (+ optional `dialogue`) — a goto stage that carries a `dialogue`
##               node dict opens an in-flight DialoguePanel with `npc` on
##               arrival instead of auto-completing; finishing it advances.
##   reach_gate — fly into the charted waygate at `pos`: the demo's exit.
##               Triggers the thank-you screen.
##
## Givers TALK: `briefing` plays as a dialogue when the quest starts,
## `debrief` when it completes. quests.gd only QUEUES these (pending_talks);
## the dock screen presents them via DialoguePanel (keeps this SaveGame- and
## UI-free so it stays loadable in --script test mode).
##
## Quests AUTO-START on a station dock once `requires` is met ("" = tutorial
## complete). One new quest per dock — the board hands out work, it doesn't
## bury you. Every stage completion writes the shared Captain's Log
## (Research.journal) and flashes visibly.

const QUESTS := [
	# LANDING TUTORIAL. The station tutorial teaches flight + docking; setting a
	# hull on a PLANET is a different skill (gravity, no lane) and players read it
	# as confusing rather than hard. So the first post-tutorial job is a milk run
	# dirtside: the trip forces a landing, the first-landing cinematic teaches by
	# consequence, and Imari names the technique in plain words afterward.
	{"id": "dirtside_run", "title": "Dirtside Run", "giver": "ruel",
		"requires": "",
		"body": "The colony is waiting on a crate off the last freighter, and Ruel has nobody dirtside. Fly it down, hand it to Imari — and put the hull on the ground without leaving a crater.",
		"briefing": "Ruel finally looks up. \"Before I put you on anything that matters — milk run. Colony's short a crate off the last freighter and I've no one dirtside.\" He raps the crate with a knuckle. \"And pilot — setting down is NOT docking. There's no lane to line up on. A planet has gravity; it pulls you in whether you're ready or not. Your only job is slowing it. Come in slow, and drop TOWARD the pad, not across it.\" He jerks his chin at your console. \"And use your chart — [M] pulls up the nav map. Set the colony as your waypoint and fly the diamond. The Reach is bigger than it looks. Imari signs for the crate.\"",
		"debrief": "\"Down and back with the paint still on her. Good.\" Ruel almost nods. \"Now let's see what you do with work that bites back.\"",
		"stages": [
			{"kind": "talk", "npc": "imari", "venue": "planet",
				"step": "Fly to the planet, LAND at the colony, and hand the crate to Imari.",
				"flash": "Crate delivered. Landing is docking with gravity doing half the work — and all of the arguing.",
				"dialogue": {
					"start": {
						"text": "Imari has the crate off your hands before the ramp is fully down. \"From Ruel? Good — half this rock's been waiting on seals for that pump.\" She glances past you at your hull, and one corner of her mouth moves. \"And you set her down in one piece. You would be surprised, pilot.\"",
						"choices": [
							{"text": "Any advice for next time?", "next": "advice"},
							{"text": "Glad to help.", "next": "end"},
						]},
					"advice": {
						"text": "\"Same thing every pilot learns the expensive way: a planet is not a dock. Gravity is already pulling you down — all you're doing is slowing it. Come in slow and drop STRAIGHT toward the pad. Skim across it and she'll bounce, and bouncing is how a hull becomes a bill.\" She thumps the crate. \"Fly safe.\"",
						"choices": [{"text": "Noted. Thank you.", "next": "end"}]},
				}},
		],
		"rewards": {"credits": 120, "xp": 20}},
	{"id": "prove_wings", "title": "Standing With the Board", "giver": "ruel",
		"requires": "dirtside_run",
		"body": "Ruel doesn't hand the interesting work to unknowns. Run contracts off the board — bounties, recoveries, deliveries — and make your callsign mean something on this dock.",
		"briefing": "Ruel doesn't look up from the ledger. \"New transponder on my dock. Means nothing to me yet.\" He finally meets your eye. \"Board's got work — bounties, hauling, salvage recovery. Run a couple, come back in one piece, and maybe your callsign starts meaning something. Off you go.\"",
		"debrief": "\"Twice now you've come back whole. That's twice more than some.\" Ruel actually sets the stylus down. \"Voss — the underwriter — has been asking after someone exactly this lucky. Go see her before I change my mind about you.\"",
		"stages": [
			{"kind": "contracts", "n": 2,
				"step": "Complete station contracts (%d/%d) — any kind counts.",
				"flash": "RUEL: 'Twice now you've come back whole. Good. Voss has been asking for someone exactly that lucky.'"},
		],
		"rewards": {"credits": 150, "xp": 20}},
	{"id": "overdue", "title": "Overdue: The Long Meridian", "giver": "voss",
		"requires": "prove_wings",
		"body": "The hauler Long Meridian is nine days overdue on the planet run. No distress call. No debris report. No beacon. Voss needs an on-site verification for the claim file: fly the route, sweep her last transmitted fix, and report what you find.",
		"briefing": "Voss doesn't waste the pleasantries. \"The Long Meridian. Freight hauler, nine days overdue on the planet run. No distress call, no beacon, no claim from anyone who hit her.\" She slides a fix across. \"I need eyes on her last transmitted position for the file. Fly it, sweep it, tell me what's there. Precisely what's there.\"",
		"debrief": "You tell her: nothing. Not a hull plate, not a fuel sheen. Voss is quiet a long moment. \"No debris.\" She says it flat. \"Pirates leave debris. Storms leave debris. Everything leaves debris.\" The stamp comes down — LOST, CAUSE UNKNOWN — but her hand doesn't lift off it. \"...Thank you. Take the payment. And keep your comm on.\"",
		"stages": [
			{"kind": "goto", "pos": [6950, 3400], "radius": 420.0, "poi": "meridian_fix",
				"step": "Sweep the Meridian's last transmitted fix (charted on [M]; follow the waypoint diamond).",
				"flash": "SWEEP COMPLETE: no debris, no beacon, no fuel sheen. Not wreckage — NOTHING."},
			{"kind": "report",
				"step": "Report the empty sweep to Voss at the station.",
				"flash": "VOSS: 'No debris? Pirates leave debris.' The stamp says LOST, CAUSE UNKNOWN. Her eyes say something worse."},
		],
		"rewards": {"credits": 220, "xp": 30}},
	{"id": "ember_word", "title": "The Word at Ember Row", "giver": "voss",
		"requires": "overdue",
		"body": "That empty sweep won't leave Voss alone. She's sent you to Odessa at Ember Row — the dock rats hear things no claim file ever records. Pull the thread.",
		"briefing": "Voss catches you before you've stowed your helmet. \"The Meridian's going to cost me sleep, and I'd rather it cost yours.\" A thin almost-smile. \"Ember Row. Odessa. She owes me a listen, and she hears everything on this deck before I do. Go find out what people are too sober to say to an underwriter.\"",
		"stages": [
			{"kind": "talk", "npc": "odessa", "venue": "station",
				"step": "Meet Odessa at Ember Row (the station bar).",
				"flash": "Odessa's story doesn't add up to pirates. Nothing about any of this does.",
				"dialogue": {
					"start": {
						"text": "Odessa pours before you ask. \"You've got the look — the one that's stood over an empty patch of space where a ship ought to be.\" She sets the glass down. \"The Meridian wasn't the first. Won't be the last. And not one of them left so much as a scorch on the dark.\"",
						"choices": [
							{"text": "Pirates, surely.", "next": "pirates", "style": "primary"},
							{"text": "What do people say it is?", "next": "stories", "style": "primary"},
						]},
					"pirates": {
						"text": "\"Pirates take the cargo and leave the crew as a message, or take the crew and sell the cargo. They LEAVE things — that's the whole point of a message.\" She shakes her head slowly. \"Whatever this is, it doesn't leave. It just... closes over them.\"",
						"choices": [
							{"text": "So what do people say it is?", "next": "stories", "style": "primary"},
							{"text": "That's enough for tonight.", "next": "end"},
						]},
					"stories": {
						"text": "\"Old dock rats call it the thing in the dark. Say it breathes. Say it's got the patience of an orbit — comes round when it comes round, and God help what's exposed when it does.\" A dry laugh with nothing behind it. \"I'd call it nerves. If the manifests weren't a body count.\"",
						"choices": [
							{"text": "Thank you, Odessa.", "next": "end", "style": "tertiary"},
						]},
				}},
		],
		"rewards": {"credits": 120, "xp": 20}},
	{"id": "cold_patch", "title": "The Cold Patch", "giver": "lab",
		"requires": "ember_word",
		"body": "The lab wants an instrument reading, not a bar story. There's a residue lingering off the lane where a hauler was lost — cold, violet, wrong. Take a survey scanner out and read it directly.",
		"briefing": "The lab tech doesn't look up from the bench. \"Rumors don't calibrate. I need numbers.\" A marker blinks onto your chart. \"There's a residue off the lane — right where the Kestrel-class Pale Wager stopped transmitting. Survey scanner, select it, channel a full scan. Bring me what the instruments say, not what the dock rats feel.\"",
		"debrief": "The tech reads your scan twice, then a third time, and the second time the color goes out of their face. \"This isn't a residue. It's an absence. Matter that reads as removed — not burned, not scattered. Taken out of the equation.\" They set the slate down very carefully. \"I'm escalating this. Keep your scanner fitted.\"",
		"stages": [
			{"kind": "scan_target", "pos": [4200, -1600], "poi": "cold_patch_site",
				"step": "Fit a survey scanner, fly to the charted anomaly, select it and press [1] to scan.",
				"flash": "SCAN RETURN: the reading is a hole. Matter that should be here, isn't. Nothing did this that leaves debris."},
		],
		"rewards": {"credits": 260, "xp": 40}},
	{"id": "caught_looking", "title": "Caught in the Open", "giver": "lab",
		"requires": "cold_patch",
		"body": "The absence had a heading. The lab ran it back through the colony almanac and went quiet. Something passes through a set of coordinates soon — and they need a live sensor return the instant it does. You're the rig they're sending.",
		"briefing": "The tech won't quite meet your eye. \"The absence had a vector. I ran it against the old colony almanac and I need you to not ask me what I found.\" A marker burns onto your chart, far out past the lane. \"Something comes through there. Soon. Hold position and record everything. Then come straight home — I mean straight — the moment your instruments so much as flinch.\"",
		"debrief": "You're still shaking when you reach the bench. The tech takes one look at the return and stops breathing for a moment. \"...No one brings me this. No one brings me anything. That's the whole horror of it — they don't come back to bring it.\" They stand, unsteady. \"You did. You're the first. I'm taking this to Ruel and Voss both, tonight. Stay near the light, pilot. Stay near the light.\"",
		"stages": [
			{"kind": "survive_event", "pos": [2800, -2800], "poi": "ambush_site",
				"step": "Hold position at the plotted coordinates — then run for the station the instant anything arrives.",
				"flash": "YOU MADE THE LIGHT. Whatever that was, you are the first to run from it and live."},
		],
		"rewards": {"credits": 320, "xp": 60}},
	{"id": "first_contact", "title": "First Contact", "giver": "lab",
		"requires": "caught_looking",
		"body": "After the last pass, something LINGERED — a piece of the web itself, sheared off and drifting where the ambush happened. It has never left a piece of itself before. The lab needs it scanned before it dissipates. A Guardian wing flies escort this time; the Board is done losing pilots to the approach.",
		"briefing": "The tech can barely sit still. \"It left something. It has NEVER left something. A fragment — a tendril, sheared off and just... hanging there in the dark.\" A breath. \"Scan it before it's gone. And Ruel's sending a Guardian wing with you — real hardware, not volunteers this time. Let them handle whatever's on the lane. You get the reading.\"",
		"debrief": "The scan resolves and the whole bench goes quiet. It isn't residue this time — it's TISSUE. Living shadow, structured, purposeful. \"It's not a phenomenon,\" the tech says slowly. \"It's an animal. Old, and patient, and it came from SOMEWHERE.\" They look up. \"Every story says the same word — a gate. Go to the colony. Find the one they call the Counter. He's been listening longer than any of us.\"",
		"stages": [
			{"kind": "scan_target", "pos": [3400, -3300], "poi": "tendril_site",
				"anomaly": "tendril", "escort": true,
				"step": "Fly to the sheared tendril (Guardian wing escorting) and scan it with [1] before it dissipates.",
				"flash": "SCAN LOCKED — you have a piece of the thing itself. Get it to the lab."},
		],
		"rewards": {"credits": 400, "xp": 80}},
	{"id": "the_hermit", "title": "The Lantern-Drinker", "giver": "lab",
		"requires": "first_contact",
		"body": "The colony calls him the Counter — an old spacer who has tallied the thing's breathing for thirty years. Land on the planetoid and hear what he knows.",
		"stages": [
			{"kind": "talk", "npc": "hermit", "venue": "planet",
				"step": "Land on the planetoid and find the Counter at the colony's edge.",
				"flash": "The Counter's tally matches the almanac to the day. The thing keeps a schedule — and it came through the rim.",
				"dialogue": {
					"start": {
						"text": "The old man doesn't turn from his wall of tally marks. \"Thirty years I've counted its breathing. Eight minutes, some seconds that drift.\" A gnarled finger traces a column. \"The colony calls it a story. The almanac calls it a story. But stories don't keep a schedule, and this thing keeps one.\"",
						"choices": [
							{"text": "What IS it?", "next": "what"},
							{"text": "The lab said something about a gate.", "next": "gate"},
						]},
					"what": {
						"text": "\"The old tale calls it the lantern-drinker — the sky-web that swallows lights and won't come near a hearth that burns bright enough. That's why your station's still standing. Its light burns bright.\" He finally looks at you. \"For now. The tally says the orbit's tightening.\"",
						"choices": [
							{"text": "And the gate?", "next": "gate"},
						]},
					"gate": {
						"text": "\"It came from somewhere, and it'll go back if we let it — or drag us with it. There's an old ring out at the system's rim. Dead since before the colony. The stories say THAT'S the door it came through.\" He turns back to his wall. \"You want to know how to open a dead gate, go ask the only man who's flown the rim and lived. There's a pirate hiding in the Rust Shoal. Krayt. Tell him the Counter sent you, and that the light won't hold.\"",
						"choices": [
							{"text": "Thank you, old man.", "next": "end"},
						]},
				}},
		],
		"rewards": {"credits": 200, "xp": 40}},
	{"id": "rust_shoal", "title": "Ask the Only One Who Ran", "giver": "krayt",
		"requires": "the_hermit",
		"grants_shoal": true,   # the hermit hands you Krayt's invitation — the Shoal opens to you
		"body": "Krayt — a pirate quartermaster gone to ground in the Rust Shoal — is the only soul who has flown the system's rim and come home. Fly to the Shoal and get him to talk.",
		"stages": [
			{"kind": "goto", "pos": [2600, -7600], "radius": 520.0, "poi": "rust_shoal", "npc": "krayt",
				"truce": true,       # Krayt grants safe passage — pirates hold fire on the player
				"in_person": true,   # you DOCK the Shoal and meet Krayt at his table (not a comm-hail)
				"step": "Fly to the Rust Shoal (charted) and DOCK — Krayt will see you in person.",
				"flash": "Krayt has the gate's key, and a price: fly cover to the rim and get him clear of the Shoal, and it's yours.",
				"dialogue": {
					"start": {
						"text": "Krayt doesn't rise. A big man gone soft at the edges, a drink he isn't drinking sweating on the table in front of him. \"So you're the one the old man sent. Board's paint, and you still flew all the way out to my hole in the dark.\" A tired laugh, not unkind. \"Sit. You want the rim. Everyone who finds me wants the rim.\"",
						"choices": [
							{"text": "You've flown it. I need the gate.", "next": "gate"},
							{"text": "The Counter says the dark is eating ships.", "next": "evidence"},
						]},
					"evidence": {
						"text": "\"It is. Not the way WE eat 'em — we leave a mess, a ransom, a name somebody curses. This leaves a bill of lading and a hole where a ship used to be.\" The humor drains out of him. \"Six crews. No wreckage, no bodies, no quiet dignity of a grave. Just... gone. I'm the one who ran. I'm also the one still breathing. Do the arithmetic.\"",
						"choices": [
							{"text": "Then help me end it. The gate.", "next": "gate"},
						]},
					"gate": {
						"text": "\"The ring at the rim. Dead metal older than the colony, and it HUMS when the dark passes near it. I've been close enough to feel my teeth ring. I know how to wake it — sequence, coordinates, all of it, up here.\" He taps his temple. \"But it's my ticket out too. So here's the deal, hero: you fly cover, I follow you to the rim, and once I'm clear the key is yours. Fair?\"",
						"choices": [
							{"text": "Fair. Get your ship ready.", "next": "deal", "style": "primary"},
						]},
					"deal": {
						"text": "\"Ha. A handshake with a lawman. Never in my life.\" He heaves himself up, almost cheerful now. \"Give me a few to load what's worth loading. Launch, hold off my dock, and I'll form up on you. We run for the rim together — first good idea I've had in a year.\"",
						"choices": [
							{"text": "I'll be waiting outside.", "next": "end"},
						]},
				}},
		],
		"rewards": {"credits": 300, "xp": 80}},
	{"id": "nothing_left_behind", "title": "Nothing Left Behind", "giver": "krayt",
		"requires": "rust_shoal",
		"manual_start": true,   # NOT auto-handed at a dock — the flight set-piece (the Shoal's fall,
		                        # Krayt's final transmission) starts it via Quests.begin_manual().
		"body": "The dark took the Rust Shoal with Krayt still aboard — drawn off into the black so the rest could run. His final transmission carried the gate's waking sequence, bought with his life. The ring at the rim is charted. Fly to it, and leave this system before it becomes another empty patch of space.",
		"briefing": "His voice comes stripped of every joke, breathing hard over a sound like the sky closing its mouth: \"...it's got the Shoal, it's got all of it — listen. LISTEN. The gate. Coordinates are in the packet. The sequence is three long, two short, hold on the third — the ring remembers. Wake it and GO. Don't let this be for—\" Then nothing. But the packet came through. The gate is on your chart.",
		"stages": [
			{"kind": "reach_gate", "pos": [-6800, 8200], "poi": "waygate",
				"step": "Fly to the ancient gate at the system's rim and enter it. Leave the Cinder Reach.",
				"flash": ""},
		],
		"rewards": {"credits": 0, "xp": 100}},

	# ================================================================================
	# THE CINDER REACH CAMPAIGN — "The Legend" (docs/cinder_reach_campaign.md)
	# ================================================================================
	# The SYSTEM'S OWN story, not the Saga: a hunted war-legend, a noir client, and a
	# secret that restarts a war if it gets out. Saga-independent for its whole length;
	# it braids only at the gate finale.
	#
	# GATED ON `ember_word` — the Saga beat where you first walk into Ember Row and meet
	# Odessa. That is a precondition of THIS quest (she has to know your face before she
	# asks a personal favour), not a chain off the Saga: the Campaign never advances the
	# Saga and never waits on it again after this.
	#
	# BREADCRUMB RULE: giver `odessa` stands at the STATION, and so does the giver of the
	# prereq — so the lead is handed where you already are, and the DESTINATION (the
	# colony) is charted by the talk stage's venue. No orphaned "go somewhere you have
	# never been to start a quest you cannot see".
	{"id": "legend_check_in", "title": "Look In On Him", "giver": "odessa",
		"requires": "ember_word",
		"body": "Odessa wants someone to look in on an old friend at the colony's edge — a favour, she says, and she is careful to say it is nothing more than that.",
		"briefing": "She pours you something you did not order and does not charge for it. \"There's a man on Epharon. Lives out past the domes in a hole in the rock, counts things nobody asked him to count.\" A pause exactly long enough to notice. \"I'd take it kindly if somebody looked in on him. He's owed a bottle and he's owed a visit, and I can't leave this bar.\" She slides the bottle across. \"Don't make a thing of it. Just... see how he is.\"",
		"debrief": "\"He's alive, then.\" She takes the empty glass you didn't drink from and turns it over in her hands a moment too long. \"Good. That's good.\" She doesn't ask what he said, which is its own kind of answer.",
		"stages": [
			{"kind": "talk", "npc": "hermit", "venue": "planet",
				"step": "Land at Epharon and find the Counter in the cave past the domes.",
				"flash": "The old man took the bottle without a word about who sent it. He knew.",
				"dialogue": {
					"start": {
						"text": "The cave smells of cold rock and old machine oil. He's marking a wall that has no room left on it, and doesn't stop when your shadow falls across the marks.\n\n\"You're not the water run.\"",
						"choices": [
							{"text": "Odessa sent me. She sent this, too.", "next": "bottle"},
							{"text": "Just looking in.", "next": "looking"},
						]},
					"looking": {
						"text": "\"Nobody just looks in. Not out here.\" The marking stops. He still doesn't turn. \"Who sent you.\"",
						"choices": [
							{"text": "Odessa. She sent this, too.", "next": "bottle"},
						]},
					"bottle": {
						"text": "He turns then. Older than the voice, and something in the way he stands is wrong for a hermit — squared off, weight on the back foot, hands where he can see yours.\n\nHe looks at the bottle for a long moment. \"She remembers the label.\" He takes it, sets it down unopened. \"She shouldn't have sent anybody. Tell her that. Kindly.\"",
						"choices": [
							{"text": "She's worried about you.", "next": "worried", "style": "primary"},
							{"text": "What are you counting?", "next": "counting"},
						]},
					"counting": {
						"text": "\"The thing that breathes out past the rim. Eight minutes, some seconds that drift.\" He almost smiles. \"Everyone assumes it's madness. It's arithmetic. Madness would be not counting.\"",
						"choices": [
							{"text": "She's worried about you.", "next": "worried", "style": "primary"},
						]},
					"worried": {
						"text": "\"She's right to be.\" He says it plainly, the way a man reads a gauge. Then, catching himself, softer: \"Tell her I'm well. Tell her the rock is dry and the counting keeps.\"\n\nAt the mouth of the cave he says one more thing, not quite to you.\n\n\"If anybody else comes asking after an old man out here — anybody at all — you'd be doing me a kindness not to remember the way.\"",
						"choices": [
							{"text": "Understood.", "next": "end", "style": "primary"},
						]},
				}},
		],
		"rewards": {"credits": 150, "xp": 40}},
]

static var active := {}                 # id -> {"stage": int, "count": int}
static var completed: Array[String] = []
static var pending_notes: Array[String] = []
## Conversations the dock screen should present: {"giver": id, "text": line,
## "quest": title, "rewards": text}. Drained by the UI via take_talks().
static var pending_talks: Array[Dictionary] = []


static func quest_def(id: String) -> Dictionary:
	for q in QUESTS:
		if q.id == id:
			return q
	return {}


static func stage_def(id: String) -> Dictionary:
	var q := quest_def(id)
	if q.is_empty() or not active.has(id):
		return {}
	var s: int = active[id].stage
	return q.stages[s] if s < (q.stages as Array).size() else {}


## Station docks hand out new quests and settle report stages.
## `tutorial_done` is passed in (not read off SaveGame) so this script stays
## loadable in --script test mode, where autoload-dependent scripts aren't.
static func on_dock(is_station: bool, _ship, tutorial_done: bool) -> void:
	# Talk stages resolve at their venue — station OR planet (the hermit is
	# dirtside), so this runs before the station-only gate below. The
	# conversation is queued; finishing it (advance_talk) advances the stage.
	for id in active.keys():
		var tst := stage_def(id)
		if tst.get("kind", "") == "talk":
			var at_station: bool = str(tst.get("venue", "station")) == "station"
			if at_station == is_station:
				pending_talks.append({"giver": str(tst.npc), "nodes": tst.dialogue,
					"advance": id})
	# `report` stages are station business (you file findings with the board).
	if is_station:
		for id in active.keys():
			if stage_def(id).get("kind", "") == "report":
				_advance(id)
	# New work is offered at BOTH docks now — filtered by whether the giver is
	# actually standing here. It used to be station-only, which meant a
	# planetside giver (the Counter) had to be handed over by Ruel at the
	# station: the same "NPC speaking from the wrong dock" problem, mirrored.
	check_new_work(is_station, tutorial_done)


## Start the next eligible quest (its giver's briefing is queued to speak HERE).
## Split out of on_dock so it can also fire the instant a contract turn-in
## COMPLETES a quest — the next giver greets you on the same dock, no re-docking.
## "one fresh per call" pacing stands; a completion is one call.
static func check_new_work(is_station: bool, tutorial_done: bool) -> void:
	for q in QUESTS:
		if active.has(q.id) or completed.has(q.id):
			continue
		if q.get("manual_start", false):
			continue   # started by a scripted event (e.g. the Shoal's fall), never a dock
		# A giver can only hand you work WHERE THEY ARE. Without this Ruel
		# briefed station contracts over the colony's landing pad, which reads
		# as the harbourmaster following you around the system.
		if Npcs.is_dockside(str(q.giver)) and not Npcs.at_venue(str(q.giver), is_station):
			continue
		var req: String = q.requires
		if (req == "" and tutorial_done) or completed.has(req):
			active[q.id] = {"stage": 0, "count": 0}
			if q.get("grants_shoal", false):
				Pilot.shoal_invited = true   # Krayt's invitation, handed over by the hermit
			pending_notes.append("NEW WORK — %s: \"%s\"  (Quest Log: Missions tab, or [L] in flight)" % [
				Npcs.display_name(q.giver), q.title])
			Research.journal.append({"day": Research.day,
				"text": "Took work from %s: %s." % [Npcs.display_name(q.giver), q.title]})
			if q.has("briefing"):
				pending_talks.append({"giver": q.giver, "text": q.briefing,
					"quest": q.title, "rewards": rewards_text(q),
					"vo": str(q.id) + "_briefing"})
			_enter_stage(q.id)
			# If the fresh quest OPENS on a talk at this venue, queue it now too,
			# so the player doesn't have to re-dock to trigger it.
			var st0 := stage_def(q.id)
			if st0.get("kind", "") == "talk" and (str(st0.get("venue", "station")) == "station") == is_station:
				pending_talks.append({"giver": str(st0.npc), "nodes": st0.dialogue, "advance": q.id})
			return   # one fresh quest per call


## Start a `manual_start` quest from a scripted event (the flight scene calls
## this at the end of the Shoal's-fall set-piece). Charts the finale's POI and
## posts the NEW WORK note; the briefing text is delivered in flight, not here,
## so it is NOT queued as a dock talk.
static func begin_manual(id: String) -> void:
	if active.has(id) or completed.has(id):
		return
	var q := quest_def(id)
	if q.is_empty():
		return
	active[id] = {"stage": 0, "count": 0}
	pending_notes.append("NEW WORK — %s: \"%s\"  (Quest Log: Missions tab, or [L] in flight)" % [
		Npcs.display_name(q.giver), q.title])
	Research.journal.append({"day": Research.day,
		"text": "Took work from %s: %s." % [Npcs.display_name(q.giver), q.title]})
	_enter_stage(id)   # charts the waygate POI + snaps an idle waypoint


## The dock UI calls this when a talk-stage conversation closes.
static func advance_talk(id: String) -> void:
	if active.has(id) and stage_def(id).get("kind", "") == "talk":
		_advance(id)


## The flight scene asks what anomaly to place: {quest, pos} for the active
## scan_target stage, or empty. One at a time (mirrors the dig-site spawn).
static func scan_site() -> Dictionary:
	for id in active:
		var st := stage_def(id)
		if st.get("kind", "") == "scan_target":
			return {"quest": id, "pos": Vector2(st.pos[0], st.pos[1]),
				"anomaly": str(st.get("anomaly", "residue"))}
	return {}


## The ship calls this when a survey completes on a quest anomaly.
static func note_scan_target(id: String) -> void:
	if active.has(id) and stage_def(id).get("kind", "") == "scan_target":
		_advance(id)


## True while an active stage wants a protective Guardian escort (beat 4).
static func escort_active() -> bool:
	for id in active:
		var st := stage_def(id)
		if st.get("kind", "") == "scan_target" and bool(st.get("escort", false)):
			return true
	return false


## The flight scene asks where the ambush trigger is: {quest, pos} for the
## active survive_event stage, or empty.
static func survive_site() -> Dictionary:
	for id in active:
		var st := stage_def(id)
		if st.get("kind", "") == "survive_event":
			return {"quest": id, "pos": Vector2(st.pos[0], st.pos[1])}
	return {}


## The flight scene calls this when the player reaches safety alive.
static func note_survived(id: String) -> void:
	if active.has(id) and stage_def(id).get("kind", "") == "survive_event":
		_advance(id)


## Beat 6: a goto stage carrying an in-flight conversation. The flight scene
## opens the dialogue on arrival and calls advance_goto_dialogue on close.
static func goto_dialogue_site() -> Dictionary:
	for id in active:
		var st := stage_def(id)
		if st.get("kind", "") == "goto" and st.has("dialogue"):
			return {"quest": id, "pos": Vector2(st.pos[0], st.pos[1]),
				"radius": float(st.get("radius", 500.0)),
				"npc": str(st.get("npc", "")), "nodes": st.dialogue,
				"truce": bool(st.get("truce", false)),
				"in_person": bool(st.get("in_person", false))}
	return {}


static func advance_goto_dialogue(id: String) -> void:
	var st := stage_def(id)
	if active.has(id) and st.get("kind", "") == "goto" and st.has("dialogue"):
		_advance(id)


## Beat 7: the waygate — the demo's exit. Entering it ends the run.
static func gate_site() -> Dictionary:
	for id in active:
		var st := stage_def(id)
		if st.get("kind", "") == "reach_gate":
			return {"quest": id, "pos": Vector2(st.pos[0], st.pos[1])}
	return {}


static func note_gate_reached(id: String) -> void:
	if active.has(id) and stage_def(id).get("kind", "") == "reach_gate":
		_advance(id)


## A procedural contract was turned in; contracts stages count them.
static func note_contract() -> void:
	for id in active.keys():
		var st := stage_def(id)
		if st.get("kind", "") == "contracts":
			active[id].count += 1
			if active[id].count >= int(st.n):
				_advance(id)


## Called from the flight loop; returns HUD flash lines for stages that
## completed by arriving somewhere.
static func tick_goto(player_pos: Vector2) -> Array[String]:
	var flashes: Array[String] = []
	for id in active.keys():
		var st := stage_def(id)
		# Plain gotos auto-complete on arrival; gotos that carry a `dialogue`
		# are handled by the flight scene (it opens the conversation instead).
		if st.get("kind", "") != "goto" or st.has("dialogue"):
			continue
		var target := Vector2(st.pos[0], st.pos[1])
		if player_pos.distance_to(target) <= float(st.radius):
			if st.has("flash"):
				flashes.append(st.flash)
			_advance(id)
	return flashes


static func _advance(id: String) -> void:
	var st := stage_def(id)
	if st.has("flash"):
		pending_notes.append(st.flash)
		Research.journal.append({"day": Research.day, "text": st.flash})
	active[id].stage += 1
	var q := quest_def(id)
	if active[id].stage >= (q.stages as Array).size():
		active.erase(id)
		completed.append(id)
		var r: Dictionary = q.rewards
		Wallet.credits += int(r.get("credits", 0))
		Wallet.xp += int(r.get("xp", 0))
		var done_note := "QUEST COMPLETE: %s — %s" % [q.title, rewards_text(q)]
		pending_notes.append(done_note)
		Research.journal.append({"day": Research.day, "text": done_note})
		if q.has("debrief"):
			pending_talks.append({"giver": q.giver, "text": q.debrief,
				"quest": "%s — COMPLETE" % q.title, "rewards": rewards_text(q),
				"vo": str(id) + "_debrief"})
	else:
		_enter_stage(id)
	refresh_pois()   # ephemeral markers follow the live stages: old one gone, new one shown


## Reconcile ephemeral (quest-only) POIs against the LIVE stages: an ephemeral POI
## is charted ONLY while it is the target of a currently-active stage, and hidden
## the instant it isn't (user rule, 2026-07-23 — a quest marker must never outlive
## its moment or get pinned by flying past). Real landmarks are untouched; only POIs
## flagged ephemeral in PoiMap are managed here. Called on every quest-state change.
static func refresh_pois() -> void:
	var targets := {}
	for id in active.keys():
		if quest_def(id).is_empty():
			continue
		var poi := str(stage_def(id).get("poi", ""))
		if poi != "":
			targets[poi] = true
	for pid in PoiMap.ephemeral_ids():
		if targets.has(pid):
			PoiMap.discover(pid)
		else:
			PoiMap.undiscover(pid)


## Entering a stage charts its POI; an idle waypoint snaps to it so the
## radar diamond leads new pilots by the hand.
static func _enter_stage(id: String) -> void:
	var st := stage_def(id)
	# Where this beat wants you: its own POI, or (for a talk/report beat with no
	# world position) the venue's landmark, so EVERY campaign step charts a
	# diamond — talk stages used to chart nothing and vanish behind side content.
	var here := current_step()
	var poi := str(here.get("target_poi", "")) if str(here.get("quest", "")) == id else str(st.get("poi", ""))
	if poi != "" and PoiMap.exists(poi):
		PoiMap.discover(poi)
		# Re-point the AUTO waypoint at this new beat unless the player hand-tagged
		# one on the chart. It used to set the mark ONLY when the waypoint was empty,
		# so a lingering diamond from the previous beat stuck and a new objective —
		# "Ask the Only One Who Ran" at the Rust Shoal — never got its own mark until
		# something else cleared the old one. Entering a stage means "go HERE now".
		if not PoiMap.waypoint_manual:
			PoiMap.set_waypoint(poi, false)
	# Reconcile every ephemeral marker to the live stages: this reveals THIS beat's
	# quest-only POI and hides any stale one. Covers every reveal path (fresh start,
	# advance, manual start, load) since they all enter a stage.
	refresh_pois()


## The active campaign beat, for the always-on "NEXT" surfaces (flight HUD +
## Landing Bay) that stop a player losing the spine behind side content. Quests
## holds ONLY campaign quests (procedural work lives in MissionLog), so the first
## active one is the current story beat. Empty when the campaign is idle.
##
## `target_poi` is where the waypoint should point: the stage's own `poi` for
## goto/survive beats, else the VENUE's landmark for a talk/report beat (so even
## "meet Odessa at the station" gets a diamond, which it never had before).
static func current_step() -> Dictionary:
	for id in active.keys():
		if quest_def(id).is_empty():
			continue                 # not a campaign quest (defensive)
		var st := stage_def(id)
		if st.is_empty():
			continue
		var poi := str(st.get("poi", ""))
		if poi == "":
			var venue := str(st.get("venue", ""))
			if venue == "":
				# A report/talk beat with no venue points at its GIVER (you report TO
				# them — Voss at the station). Without this "The Long Meridian"'s report
				# stage charted nothing: the sweep marker vanished and the pilot was
				# left with no direction (user, 2026-07-24).
				venue = Npcs.venue_of(str(quest_def(id).get("giver", "")))
			poi = "planetoid" if venue == "planet" else ("station" if venue == "station" else "")
		return {
			"quest": id,
			"title": str(quest_def(id).get("title", "")),
			"step": str(st.get("step", "")),
			"target_poi": poi,
		}
	return {}


static func rewards_text(q: Dictionary) -> String:
	var r: Dictionary = q.get("rewards", {})
	var parts := PackedStringArray()
	if r.get("credits", 0) > 0:
		parts.append("%dc" % r.credits)
	if r.get("xp", 0) > 0:
		parts.append("%d xp" % r.xp)
	return " + ".join(parts)


static func take_notes() -> Array:
	var out := pending_notes.duplicate()
	pending_notes.clear()
	return out


## Drained by the dock UI: giver conversations queued this dock, in order.
## Drain only the talks whose giver is standing at THIS dock; the rest keep
## waiting. A debrief is queued the moment a quest completes — which can happen
## in flight or at the far venue — so filtering at queue time isn't enough. The
## giver waits at their own desk until you get there.
## Talks waiting for ONE person, without draining them — for venues that aren't
## the station or the planet (Doug's freighter, the Speak's Easy), where the
## is_station flag can't say where you are.
static func talks_for(npc: String) -> Array:
	var out := []
	for t in pending_talks:
		if str(t.get("giver", "")) == npc:
			out.append(t)
	return out


## Remove the first talk queued for this person, once it has been spoken.
static func take_talk(npc: String) -> void:
	for i in pending_talks.size():
		if str(pending_talks[i].get("giver", "")) == npc:
			pending_talks.remove_at(i)
			return


static func take_talks(is_station := true) -> Array:
	var out := []
	var keep: Array[Dictionary] = []   # pending_talks is typed; a bare Array won't assign
	for t in pending_talks:
		if Npcs.at_venue(str(t.get("giver", "")), is_station):
			out.append(t)
		else:
			keep.append(t)
	pending_talks = keep
	return out


## ---- Quest-log entries (unified shape with Research.log_entries) ----

static func log_entries(_ship) -> Array:
	var out := []
	for id in active:
		out.append(_entry(quest_def(id), active[id].stage, active[id].count, false))
	return out


static func completed_entries() -> Array:
	var out := []
	for id in completed:
		var q := quest_def(id)
		if not q.is_empty():
			out.append(_entry(q, (q.stages as Array).size(), 0, true))
	return out


static func _entry(q: Dictionary, upto: int, count: int, done_quest: bool) -> Dictionary:
	var done: Array[String] = []
	for j in mini(upto, (q.stages as Array).size()):
		var st: Dictionary = q.stages[j]
		if st.has("flash"):
			done.append(st.flash)
	var current := ""
	if not done_quest and upto < (q.stages as Array).size():
		var st: Dictionary = q.stages[upto]
		var step: String = st.step
		current = step % [count, int(st.n)] if step.contains("%d") else step
	return {"id": q.id, "title": q.title, "giver": Npcs.display_name(q.giver),
		"giver_id": q.giver, "body": q.body, "done": done, "current": current,
		"rewards": rewards_text(q), "done_quest": done_quest}


static func to_dict() -> Dictionary:
	return {"active": active.duplicate(true), "completed": completed.duplicate()}


static func from_dict(data: Dictionary) -> void:
	active.clear()
	for id in data.get("active", {}):
		if not quest_def(str(id)).is_empty():
			var st: Dictionary = data.active[id]
			active[str(id)] = {"stage": int(st.get("stage", 0)), "count": int(st.get("count", 0))}
	completed.clear()
	for id in data.get("completed", []):
		if not quest_def(str(id)).is_empty():
			completed.append(str(id))
	# POIs/waypoints re-chart on load for whatever stage we're standing in.
	for id in active:
		_enter_stage(id)


static func reset() -> void:
	active.clear()
	completed.clear()
	pending_notes.clear()
	pending_talks.clear()
