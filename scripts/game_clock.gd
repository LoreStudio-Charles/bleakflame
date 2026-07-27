class_name GameClock
## WHAT TIME IT IS — the only thing in the game that knows.
##
## WHY (user, 2026-07-27): "That system is going to change, and possibly be tracked to
## realtime, but no system should have a hard coupling with it so that whether it changes
## to any other system, we just get date from it and it advances as needed."
##
## It was `Research.day`, an int incremented on docking, read directly in twenty places —
## and, worse, done ARITHMETIC ON: `Research.day >= completed_day[req] + wait`. That is the
## coupling that actually hurts. A stored day number is easy to redirect; two dozen
## expressions that assume "+1 means tomorrow" all break silently the moment a unit changes,
## and they break by producing plausible wrong answers rather than errors.
##
## THE CONTRACT, and the whole point of the class:
##
##   · ASK for the time      — now()
##   · STORE a moment        — now(), kept as an opaque stamp; never inspected
##   · COMPARE two moments   — since(stamp) / elapsed(stamp, span)
##   · AUTHOR a duration     — days(3), never the literal 3
##   · SHOW a time           — label(stamp)
##
## NOBODY ADDS, SUBTRACTS OR COMPARES A STAMP THEMSELVES. Obey that and this class can be
## gutted for a realtime clock, an orbital calendar, or a server-authoritative tick with no
## change anywhere else: `DAY` becomes 86400, `now()` reads a wall clock, `advance()`
## becomes a no-op because time flows on its own, and every `elapsed(stamp, days(3))` in
## the codebase keeps meaning exactly what it meant.
##
## WORLD STATE, NOT PLAYER STATE (docs/multiplayer_readiness.md): two pilots in one session
## can never legitimately disagree about what day it is. It is deliberately NOT in
## PlayerState and belongs to the WorldState container when that lands.

## Clock units in one game day. THE ONE PLACE the unit is defined — every authored duration
## goes through days(), so changing this re-scales the whole game consistently.
##
## DELIBERATELY NOT 1. At 1 the unit is invisible: `days(n)` and `n` are the same number, so
## every consumer that does raw arithmetic still works by accident and NO TEST CAN TELL THE
## DIFFERENCE — sabotaging days() to ignore DAY entirely went undetected. Making a day 24
## units (call them hours) means the conversion is load-bearing from today, which is the
## only way the seam is real rather than aspirational. It also gives sub-day resolution for
## free, which anything realtime is going to want.
const DAY := 24

## An impossible stamp, for "this has never happened". Distinct from 0, which is a real
## moment (the first day) — the two were the same value before and a never-mediated faction
## read as mediated-on-day-zero.
const NEVER := -1

static var _now := 0
## Called after every advance. Systems that ACCRUE over time subscribe rather than being
## called from inside the tick, so the clock knows nothing about artifacts or research.
static var _listeners: Array[Callable] = []


## The current moment, as an opaque stamp. Store it; do not read meaning into it.
static func now() -> int:
	return _now


## Move time forward. Called by whatever currently drives the calendar — today a docking,
## tomorrow perhaps nothing at all because the clock reads real time.
static func advance(units := DAY) -> void:
	if units <= 0:
		return
	_now += units
	for c in _listeners:
		if c.is_valid():
			c.call(units)


## A duration written by a designer, in days, converted to clock units. `requires_days: 3`
## becomes `days(3)`. This is the seam that keeps authored content meaningful across a
## change of unit — the .tres and the quest tables never have to be rewritten.
static func days(n) -> int:
	return int(n) * DAY


## How much time has passed since a stamp. NEVER answers a very large number, so
## "has enough time passed" is true for something that never happened — which is almost
## always the intent (nothing has been mediated, so mediation is allowed).
static func since(stamp: int) -> int:
	if stamp == NEVER:
		return 0x3FFFFFFF
	return _now - stamp


## Has at least `span` passed since `stamp`? The comparison every gate wants, in the one
## place it can be got wrong.
static func elapsed(stamp: int, span: int) -> bool:
	return since(stamp) >= span


## How much of `span` is still to run — for a UI that wants to say "2 days". Never negative.
static func remaining(stamp: int, span: int) -> int:
	return maxi(0, span - since(stamp))


## PLAYER-FACING. The one place the fiction of the calendar is worded, so a change of
## system changes the words here and nowhere else. `stamp` defaults to now.
static func label(stamp := NEVER) -> String:
	return "Day %d" % day_number(stamp)


## HOW TIME PASSES, in the player's words — printed on the Captain's Log and the lab
## readout. It was hard-coded as "a day passes with each docking" in two places, which is a
## sentence about the CURRENT rule sitting in files that should not know the rule. When the
## clock becomes realtime this line changes here and both screens follow.
static func cadence_text() -> String:
	return "a day passes with each docking"


## The day a stamp falls on — FOR DISPLAY AND AUTHORING ONLY. Anything using this to
## compare or to do arithmetic is exactly what this class exists to prevent; use
## since()/elapsed() instead.
static func day_number(stamp := NEVER) -> int:
	var at := _now if stamp == NEVER else stamp
	return int(at / DAY)


## Subscribe to the passage of time. The callable receives the units advanced.
static func on_tick(c: Callable) -> void:
	if not _listeners.has(c):
		_listeners.append(c)


static func to_dict() -> Dictionary:
	return {"now": _now}


## `day` is the LEGACY KEY: saves written before the clock existed stored a bare day count
## under Research. Read it as a day-count so an existing pilot keeps their calendar, exactly
## the way old path-only affix saves still load.
static func from_dict(data: Dictionary) -> void:
	if data.has("now"):
		_now = int(data["now"])
	elif data.has("day"):
		_now = days(int(data["day"]))
	else:
		_now = 0


static func reset() -> void:
	_now = 0
