class_name PlayerState
extends RefCounted
## EVERYTHING THAT BELONGS TO ONE PILOT, in one object instead of scattered across
## a dozen modules as `static var`.
##
## WHY (user, 2026-07-27): "Let's get it coop friendly now. That would remove subtle
## bugs, make forward progress easier and more reliable, and pave the way for any
## form of multiplayer." The whole game's player state lived in ~97 statics, which
## says exactly one thing: there is one pilot, forever. Every road out of that —
## 1-4 coop or the MMO server — needs the same first step, so this is safe to build
## before that fork is settled (see the coop north star notes).
##
## HOW IT LANDS WITHOUT A THOUSAND-LINE DIFF. The existing modules (Wallet, Stash,
## …) keep their exact public API and become FORWARDING FACADES onto
## `PlayerState.local`. `Wallet.credits += 100` still compiles and still works —
## there are 67 sites reading that one field alone, and rewriting them would have
## been a huge diff whose only real content was "same thing, new spelling."
## GDScript 4.7 supports custom get/set on `static var`, which is what makes this
## possible; verified in an isolated project before committing to the approach,
## including that reassigning `local` changes what every existing reader sees.
##
## SO THE MIGRATION IS: move the DATA here, leave the NAMES alone. A call site only
## needs touching when it must name WHICH pilot — and that is exactly the set of
## places multiplayer has to visit anyway.
##
## NOT IN HERE: world state (the POI list, the calendar, the contract board's
## postings) and engine/config tables (Tutor's predicate registry, MissionLog's
## templates). Those are shared by everyone in a session and belong to a WorldState
## when it lands. The rule for sorting a field: if two pilots in one session could
## legitimately disagree about its value, it is player state.

## The pilot this client is playing. Coop/MMO adds a lookup by peer id alongside
## this; `local` stays as "me", which is what UI and input always want.
##
## Lazily built rather than `static var local := PlayerState.new()`, because a
## static initialiser that constructs its own class is asking about ordering, and
## a null local would fail far away from the cause.
static var _local: PlayerState

static var local: PlayerState:
	get:
		if _local == null:
			_local = PlayerState.new()
		return _local
	set(value):
		_local = value


# --- Wallet ------------------------------------------------------------------
var credits := 0
var xp := 0

# --- Stash (safe storage at the station; death never touches it) --------------
var stash_items: Array[ComponentDef] = []
var stash_commodities: Dictionary = {}

# --- Pilot identity, commission and loadout ----------------------
var created: bool = false
var callsign: String = ""  # a handle from CALLSIGNS
var family_name: String = ""  # free text
var portrait_path: String = ""
var background: String = ""
var bio: String = ""
var profession: String = ""  # "" = no commission yet
var skills: Dictionary = {}  # skill id -> ranks bought
var shoal_invited: bool = false
var shoal_truce_kills: int = 0
var met: Array[String] = []
var gems: Array = ["", "", "", "", ""]
var ground_gear: Dictionary = {}
var ground_cache: Dictionary = {}  # slot -> rebuilt GroundGearDef (not saved)
var techniques: Array = ["", "", "", "", ""]
var ground_kit_granted: bool = false

# --- Owned ships (SampleBuilds) ----------------------------------
var ship_current: int = 3  # starter: Rooster (index 3)
var ship_owned: Array[int] = [3]
var ship_builds: Dictionary = {}

# --- Faction standing ------------------------------------------
var standing_points: Dictionary = {}  # faction id -> signed standing
var standing_peace: Dictionary = {}  # faction id -> bool (absent = at peace)
var standing_mend_day: Dictionary = {}  # faction id -> last game-day mediated
var standing__seeded: bool = false

# --- Comms inbox -----------------------------------------------
var comms_messages: Array[Dictionary] = []

# --- Contracts this pilot holds --------------------------------
var mission_active: Array = []  # contracts THIS pilot took
var mission_total_kills: int = 0  # bounty progress baseline
var mission_next_uid: int = 1

## ---- Research (scripts/research.gd) ----
## WHAT THIS PILOT HAS LEARNED. `Research.day` stays WORLD and is deliberately absent:
## the calendar advances for the system, not for a person, and two pilots in one session
## can never disagree about what day it is. Everything below they can.
var research_insight: float = 0.0
var research_recovered: Array[String] = []  # artifact ids installed at the lab
var research_chain_stage: Dictionary = {}  # artifact id -> current stage index
var research_survey_progress: int = 0  # counter for the active survey_rocks stage
## SCAN DATA IS KNOWLEDGE (2026-07-27): a subject is catalogued ONCE, by hull class. Two
## pilots absolutely disagree here — that is the whole feature.
var research_catalogued: Dictionary = {}  # subject key -> true
var research_unlocked: Dictionary = {}  # tech node id -> true
var research_pending_notes: Array[String] = []
var research_journal: Array[Dictionary] = []  # {day, text} — the captain's log
var research_last_rumor_vo: String = ""
var research_last_rumor_chain: String = ""

## ---- Quests (scripts/quests.gd) ----
## THE CAMPAIGN, PER PILOT. This is the migration the flag rule was waiting on: presence
## + order (docs/multiplayer_readiness.md) only means anything once each pilot has their
## own chain to check against. Helping a friend with a later beat must not grant it out
## of sequence, and it cannot even be asked while there is one global `active`.
var quest_active: Dictionary = {}  # id -> {"stage": int, "count": int}
var quest_completed: Array[String] = []
var quest_completed_day: Dictionary = {}  # id -> game day it closed
var quest_pending_notes: Array[String] = []
var quest_pending_talks: Array[Dictionary] = []

## ---- Tutor (scripts/tutor.gd) ----
## THE MODULE STRADDLES THE LINE, which is why it went last. What a pilot HAS BEEN TAUGHT,
## what they are being shown right now, and how far through it they are, are all theirs —
## in coop, two pilots at different points in the game must not share a lesson queue, and
## the second player joining must not have the first's onboarding skipped for them.
##
## WHAT STAYS GLOBAL, deliberately, over in Tutor itself:
##   · `_anchors`      — which Control owns which anchor id. A property of the SCREEN that
##                       is built, not of who is looking at it.
##   · `_arm_pred` / `_done_pred` / `_preds_built` — the predicate registry. Authored
##                       engine tables; identical for everyone, forever.
##   · `stalls`        — the watchdog's bug list. NOT player state and pointedly not reset
##                       with a pilot: it is the game writing its own to-do list across
##                       every playtester, and scoping it per-pilot would throw that away.
var tutor_seen: Array[String] = []  # lesson ids retired for good
var tutor_active: String = ""
var tutor_step: int = 0
var tutor_pending: Array[String] = []  # queued behind the active one
var tutor_progress: Dictionary = {}  # lesson id -> per-step progress
var tutor_did: Dictionary = {}  # one-shot event flags, session-only
var tutor_ctx: Dictionary = {}  # last context snapshot the predicates read
## Is this pilot somewhere a lesson may interrupt? Written by the flight tick and asserted
## by the dock screens — the field whose cross-context staleness starved the whole queue
## once already, and which two pilots obviously disagree about.
var tutor_safe: bool = true
var tutor_context: String = "dock"
var tutor_venue: String = ""
var tutor_stall: float = 0.0  # watchdog: eligible-but-idle time on the active lesson
var tutor_stall_key: String = ""

## ---- PoiMap (scripts/poi_map.gd) ----
## The POI LIST itself is world — the Rust Shoal is where it is for everyone. What is
## PERSONAL is whether you have found it, and where your own chart marker points.
var poi_discovered: Dictionary = {}  # id -> true; fog of discovery
var poi_waypoint_id: String = ""
## A MANUAL tag outranks the objective tracker's automatic one, so it has to travel with
## the pilot who made it (MissionTracker.sync_waypoint respects this).
var poi_waypoint_manual: bool = false


## Hand this pilot a clean slate. Used by New Game; also the honest way to build a
## second pilot in a test without disturbing the one already loaded.
##
## RESET FROM A FRESH INSTANCE rather than by listing the fields. A hand-written
## wipe() is a second copy of the defaults that drifts the moment someone adds a
## field and forgets it here -- and a field that quietly survives a New Game is
## exactly the bug that let Nemesis grudges and Pilot.met leak into new pilots
## (fixed 2026-07-26). This cannot drift: the defaults have one home, the
## declarations above.
func wipe() -> void:
	var fresh := PlayerState.new()
	for prop in fresh.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			set(prop.name, fresh.get(prop.name))
