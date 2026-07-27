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
var _ground_cache: Dictionary = {}  # slot -> rebuilt GroundGearDef (not saved)
var techniques: Array = ["", "", "", "", ""]
var ground_kit_granted: bool = false

# --- Owned ships (SampleBuilds) ----------------------------------
var ship_current: int = 3  # starter: Rooster (index 3)
var ship_owned: Array[int] = [3]
var ship_builds: Dictionary = {}


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
