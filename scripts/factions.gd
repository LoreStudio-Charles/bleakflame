class_name Factions
## WHO HATES WHOM — one relationship matrix, replacing "player_team vs hostile_team".
##
## WHY (user, 2026-07-27): "Instead of player team and enemy team can we load everything
## into faction relationships? Widows faction should just hate everyone for example. Every
## player should be their own faction that begins with a starting relationship to every
## faction."
##
## TWO TEAMS CANNOT SAY WHAT THE WORLD ALREADY IS. The Long Lane's fiction is that the
## Widows "ruthlessly raid anyone, including Shoal pirates" — and that was unbuildable,
## because raiders and pirates share `hostile_team` and a ship cannot shoot its own group.
## The Cinderweb needs a bespoke devour path for the same reason. Guardians hunting pirates
## works only because there happen to be exactly two sides. Every one of those is the same
## missing idea: a RELATIONSHIP, not a side.
##
## IT SUBSUMES STANDING RATHER THAN SITTING BESIDE IT. Standing already tracks the player's
## points per faction and already answers at_peace/at_war/is_hostile — that is the PLAYER'S
## ROW of this matrix, written before the matrix existed. A pilot is a faction here, so
## their row is looked up exactly like everyone else's.
##
## ASYMMETRIC ON PURPOSE. "Hate everyone" is a property of the hater, not a mutual pact:
## the Widows attack Shoal raiders, but a Shoal raider busy with a freighter has no
## opinion about them. A symmetric matrix would force every predator to be a feud.

enum Att {HOSTILE, NEUTRAL, ALLIED}

## Every faction that can hold or be held an opinion. `color` is the hull tint that already
## means faction (see the ROLE-IS-SENSOR-DATA rule: hull colour is faction, exclusively).
const LIST := {
	# TWO DIFFERENT INSTITUTIONS, allied but not the same (user, 2026-07-27): the Guardians
	# are PRIVATE police and investigators — licensed, hired, local to the Reach — while the
	# Navy is the Confederacy's actual armed force. They share a habit (patrolling in
	# formation) and nothing else, which is why NavyShip exists rather than the Navy being
	# GuardianShip in different paint.
	"guardian": {"name": "Cinder Reach Guardians", "color": Color(0.35, 0.55, 0.95)},
	"navy": {"name": "Galean Confederate Navy", "color": Color(0.23, 0.44, 0.85)},
	"civilian": {"name": "Reach Civilians", "color": Color(0.82, 0.84, 0.88)},
	"escort": {"name": "Contract Escorts", "color": Color(0.25, 0.70, 0.58)},
	"marines": {"name": "Galean Marine Corps", "color": Color(0.55, 0.62, 0.42)},
	"shoal": {"name": "Rust Shoal", "color": Color(0.85, 0.45, 0.30)},
	"widow": {"name": "The Widows", "color": Color(0.12, 0.11, 0.13)},
	"ooshu": {"name": "The Ooshu", "color": Color(0.62, 0.42, 0.78)},
	"ghosts": {"name": "The Ghosts", "color": Color(0.58, 0.60, 0.66)},
	"leviathan": {"name": "Leviathan", "color": Color(0.45, 0.25, 0.65)},
}

## A pilot's own faction id. Every player is their own faction (user), which is what makes
## coop allies and PvP expressible at all — and it means the player is not a special case
## in any lookup below.
const PLAYER_PREFIX := "pilot:"

## THE AUTHORED MATRIX. `from -> {to: Att}`, with "*" as the catch-all for that row.
## Missing rows and missing keys fall through to NEUTRAL: the honest default is "no
## opinion", and a faction that should fight has to say so.
##
## Read it as sentences. "widow: everything is hostile" IS the design line.
const BASE := {
	"widow": {"*": Att.HOSTILE},
	"leviathan": {"*": Att.HOSTILE},
	# THE OOSHU are a RACE read as a nation (user, 2026-07-27) — "the racial collective as a
	# national identity, because I don't know their nation's name yet." So this row is a
	# people, not an army, and it has no standing quarrel with anybody in the Reach. What
	# came knocking at Odessa's door was hired, and hired is the GHOSTS' row below.
	"ooshu": {},
	# THE GHOSTS are bounty hunters, and the organisation is called the Ghosts too — one
	# name, no house style (user, 2026-07-27). A working name of "the Web" was dropped
	# because THE WEB IS ALREADY TAKEN, and not loosely: Cinderweb IS a web, the beat-2
	# anomaly is "a severed piece of the WEB — living shadow, and it is watching back", and
	# the quest body says the same. A second Web would have had the player's most
	# frightening word pointing at a pair of contractors.
	#
	# Contractors have no enemies, only marks — a row of NEUTRAL is the correct and colder
	# answer. Who they are pointed at is a CONTRACT: a quest flag, not a line in this table.
	"ghosts": {},
	# THE GALEAN MARINE CORPS — a profession faction players may join. Galean law, so it
	# stands where the Navy and the Guardians stand.
	"marines": {"shoal": Att.HOSTILE, "widow": Att.HOSTILE, "navy": Att.ALLIED,
		"guardian": Att.ALLIED, "civilian": Att.ALLIED, "escort": Att.ALLIED},
	"shoal": {
		"civilian": Att.HOSTILE, "escort": Att.HOSTILE,
		"guardian": Att.HOSTILE, "navy": Att.HOSTILE, "marines": Att.HOSTILE,
		"widow": Att.HOSTILE,                            # they raid us; we return it
	},
	"guardian": {"shoal": Att.HOSTILE, "widow": Att.HOSTILE, "navy": Att.ALLIED,
		"marines": Att.ALLIED, "civilian": Att.ALLIED, "escort": Att.ALLIED},
	"navy": {"shoal": Att.HOSTILE, "widow": Att.HOSTILE, "guardian": Att.ALLIED,
		"marines": Att.ALLIED, "civilian": Att.ALLIED, "escort": Att.ALLIED},
	"escort": {"shoal": Att.HOSTILE, "widow": Att.HOSTILE, "civilian": Att.ALLIED,
		"guardian": Att.ALLIED, "navy": Att.ALLIED, "marines": Att.ALLIED},
	# CIVILIANS HATE NOBODY. They are prey with a licence, and the whole trade lane rests
	# on them being worth escorting rather than being a side.
	"civilian": {"guardian": Att.ALLIED, "navy": Att.ALLIED, "escort": Att.ALLIED,
		"marines": Att.ALLIED},
}

## PILOTS ARE MUTUALLY NEUTRAL — no PvP (user, 2026-07-27, "yet").
##
## Every player being their own faction makes PvP expressible for FREE, which is a feature
## only if you want it. Stating the rule here rather than leaving it to fall out of the
## table means turning it on later is one line in one place, and — more importantly — that
## it cannot be turned on by ACCIDENT when somebody adds a row and forgets pilots exist.
const PILOTS_FIGHT_EACH_OTHER := false


static func is_player(id: String) -> bool:
	return id.begins_with(PLAYER_PREFIX)


## The faction id for a pilot. Takes the pilot's own key so coop can hold several at once;
## the local pilot is the default.
static func player_id(key := "local") -> String:
	return PLAYER_PREFIX + key


## HOW `from` FEELS ABOUT `to`. The only question the combat code should ever ask.
static func attitude(from: String, to: String) -> Att:
	if from == "" or to == "":
		return Att.NEUTRAL
	if from == to:
		return Att.ALLIED

	# TWO PILOTS. Neutral until PvP is a thing somebody has decided to build.
	if is_player(from) and is_player(to):
		return Att.HOSTILE if PILOTS_FIGHT_EACH_OTHER else Att.NEUTRAL

	# A PILOT'S ROW IS STANDING. It is already per-pilot, already persisted, and already
	# answers this question — reimplementing it here would be a second source of truth for
	# whether the Guardians want you dead.
	if is_player(from):
		return _player_toward(to)
	# AND THE OTHER DIRECTION IS NOT ITS MIRROR. A faction turns on a pilot for what that
	# pilot did, which Standing also records; but a faction that merely dislikes you does
	# not become something you may shoot on sight.
	if is_player(to):
		return _toward_player(from)

	var row: Dictionary = BASE.get(from, {})
	if row.has(to):
		return row[to]
	return row.get("*", Att.NEUTRAL)


## The question every weapon, every targeting reticle and every AI actually asks.
static func hostile(from: String, to: String) -> bool:
	return attitude(from, to) == Att.HOSTILE


static func allied(from: String, to: String) -> bool:
	return attitude(from, to) == Att.ALLIED


static func display_name(id: String) -> String:
	if is_player(id):
		return "Pilot"
	return str(LIST.get(id, {}).get("name", id))


static func color(id: String) -> Color:
	return LIST.get(id, {}).get("color", Color(0.72, 0.76, 0.86))


## --- the player's row, delegated to Standing ---
##
## STANDING IS THE STARTING RELATIONSHIP the user asked for: a pilot begins with points
## toward every faction, and those points ARE their opening attitude. Nothing new is
## invented here; this only phrases what Standing already knows in the matrix's language.
static func _player_toward(other: String) -> Att:
	# Anything with no opinion of anyone — and anything that hates everyone — is fair game
	# regardless of paperwork. You do not need standing with a leviathan.
	var theirs: Dictionary = BASE.get(other, {})
	if theirs.get("*", Att.NEUTRAL) == Att.HOSTILE:
		return Att.HOSTILE
	if Standing.is_hostile(other) or Standing.at_war(other):
		return Att.HOSTILE
	return Att.NEUTRAL


static func _toward_player(from: String) -> Att:
	if BASE.get(from, {}).get("*", Att.NEUTRAL) == Att.HOSTILE:
		return Att.HOSTILE      # hates everyone, and a pilot is somebody
	if Standing.is_hostile(from):
		return Att.HOSTILE      # you have earned this
	# THE SHOAL IS THE INTERESTING CASE: pirates by default, but the truce after the
	# Shoal's Fall makes them permanently neutral (Pilot.shoal_invited).
	if from == "shoal" and Pilot.shoal_invited:
		return Att.NEUTRAL
	if from == "shoal":
		return Att.HOSTILE
	return Att.NEUTRAL
