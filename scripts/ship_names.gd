class_name ShipNames
## WHAT A SHIP IS CALLED — registry marks, and the pointed absence of one.
##
## USER (2026-07-27):
##   Haulers        GCT<code>
##   Luxury Liner   GVIT<code>
##   Naval Vessel   GCN<code>
##   Guardian Vessel GEU<code>
##   Pirates        random scrambled characters — or, for daring elites and up,
##                  their callsign (The Recluse, Raptor…)
##
## THE ABSENCE IS THE CHARACTER. A legitimate ship carries a REGISTRY: a prefix that says
## who licensed it and a code you could look up. A pirate carries noise — no prefix, no
## authority, nothing to file a complaint against. So the naming scheme itself tells you
## what you are looking at before the hull does, and the lane's traffic reads as a
## registered, governed thing that raiders exist at the edges of.
##
## AND A NAME IS EARNED. The rank and file are a smear of characters; the ones worth
## remembering have a CALLSIGN instead, which is exactly the Nemesis system's premise —
## "you die to something with a NAME." A scrambled string is what you forget.

## Ambiguous glyphs are omitted on purpose: a registry you cannot read back to somebody is
## not a registry. No I/1, no O/0 — the same reason real tail numbers skip them.
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LEN := 5

## Pirates get the whole alphabet AND the confusing glyphs back, because illegibility is
## the point — this is a transponder nobody maintains, or one spoofing something it isn't.
const SCRAMBLE_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

## A REGISTRY MARK IS NATION + ROLE (user, 2026-07-28), and knowing that is what makes
## the next one authorable instead of invented:
##
##   G    Galean
##   CT   Cargo Transport
##   VIT  Vitality Insured Transport — LIVE CARGO. Colloquially "Very Important Things":
##        when your family ships out, that is just what folk say. "Be careful, you're
##        carrying very important things."
##   CN   Confederate Navy
##   EU   Enforcement Unit
##
## "Other nations and races will have their own prefixes, but the structure remains
## similar." So the nation letter and the role code are the source of truth and PREFIX is
## their product — a Quarn hauler is a new NATION entry, not a new opaque string, and
## test_ship_hails asserts the table still equals the rule so the two cannot drift.
const NATION := {
	"galean": "G",
}
const ROLE_CODE := {
	"hauler": "CT",
	"liner": "VIT",      # reserved: no liner hull exists yet — the PREMIUM passenger tier
	# THE BUDGET PASSENGER CLASS IS A KNOWN GAP (user, 2026-07-28): "lower rate liners
	# should exist too, but I don't have a callsign for them." Deliberately unnamed
	# rather than invented — a made-up code would read as canon the moment it shipped.
	# Its VOICE is already reserved in ShipHails (cold coffee, homesickness, a long way
	# to go), which is the register a GVIT explicitly does not have.
	"navy": "CN",
	"guardian": "EU",
}

const PREFIX := {
	"hauler": "GCT",
	"liner": "GVIT",
	"navy": "GCN",
	"guardian": "GEU",
}


## The mark a nation stamps on a role. Adding the Quarn is one NATION entry.
static func prefix(role: String, nation := "galean") -> String:
	return str(NATION.get(nation, "")) + str(ROLE_CODE.get(role, ""))


## A registry mark for a licensed vessel. `rng` is optional so a caller that wants a stable
## fleet (a seeded lane) can hand one in; ships spawned ad hoc take the global generator.
static func registry(role: String, rng: RandomNumberGenerator = null) -> String:
	var prefix: String = PREFIX.get(role, "GCT")
	return prefix + _code(CODE_CHARS, CODE_LEN, rng)


## An unlicensed hull: characters that mean nothing, and — the part that carries the
## fiction — NO PREFIX. Length is deliberately irregular but is not the signal; a
## scramble can happen to be as long as a GCT mark. What says "unlicensed" is that no
## authority stamped it, so there is nothing to look up and nobody to complain to.
static func scrambled(rng: RandomNumberGenerator = null) -> String:
	var n := 6 + (rng.randi() % 3 if rng != null else randi() % 3)
	return _code(SCRAMBLE_CHARS, n, rng)


## The name a ship should carry. `callsign` wins outright when it is set: an elite that has
## earned a name is never a smear of characters again.
static func for_role(role: String, callsign := "", rng: RandomNumberGenerator = null) -> String:
	if callsign != "":
		return callsign
	if PREFIX.has(role):
		return registry(role, rng)
	return scrambled(rng)


## Does this name belong to something registered? Used by anything that wants to say
## "unregistered contact" rather than print noise at the player.
static func is_registered(name: String) -> bool:
	for p in PREFIX.values():
		if name.begins_with(str(p)):
			return true
	return false


static func _code(chars: String, n: int, rng: RandomNumberGenerator) -> String:
	var out := ""
	for _i in n:
		var i: int = rng.randi() % chars.length() if rng != null else randi() % chars.length()
		out += chars[i]
	return out
