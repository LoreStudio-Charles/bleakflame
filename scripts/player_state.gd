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


## Hand this pilot a clean slate. Used by New Game; also the honest way to build a
## second pilot in a test without disturbing the one already loaded.
func wipe() -> void:
	credits = 0
	xp = 0
	stash_items.clear()
	stash_commodities.clear()
