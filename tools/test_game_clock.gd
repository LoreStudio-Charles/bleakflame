extends Node
## THE CLOCK — and, more importantly, that nothing is coupled to how it works.
##
## USER (2026-07-27): "That system is going to change, and possibly be tracked to realtime,
## but no system should have a hard coupling with it so that whether it changes to any other
## system, we just get date from it and it advances as needed."
##
## So the interesting assertions here are not "1 + 1 = 2". They are that DURATIONS ARE
## AUTHORED IN DAYS AND CONVERTED, that gates ask elapsed() instead of comparing numbers,
## and that no module has gone back to owning a calendar of its own.
##
##   <godot> --headless --path . res://tools/test_game_clock.tscn --quit-after 300

var _fails: Array[String] = []
var _checks := 0
var _ticks: Array[int] = []


func _ready() -> void:
	_case_time_moves_and_can_be_read()
	_case_durations_are_authored_not_hardcoded()
	_case_a_gate_asks_the_clock()
	_case_never_is_not_day_zero()
	_case_accrual_subscribes_rather_than_being_called()
	_case_it_round_trips_including_legacy_saves()
	_case_nobody_owns_a_calendar_any_more()

	GameClock.reset()
	if _fails.is_empty():
		print("test_game_clock: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_game_clock: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _case_time_moves_and_can_be_read() -> void:
	GameClock.reset()
	var t0 := GameClock.now()
	GameClock.advance()
	_ok(GameClock.now() > t0, "advancing moves the clock forward")
	_ok(GameClock.since(t0) == GameClock.DAY, "...by exactly one day's worth of units")
	GameClock.advance(0)
	_ok(GameClock.since(t0) == GameClock.DAY, "advancing by nothing does nothing")


## THE SEAM THAT SURVIVES A CHANGE OF UNIT. Authored content says `requires_days: 3`; the
## code says days(3). Widen DAY and every authored span re-scales with it, so the quest
## tables and the artifact .tres never need rewriting.
func _case_durations_are_authored_not_hardcoded() -> void:
	_ok(GameClock.days(1) == GameClock.DAY, "one authored day is one day of clock units")
	_ok(GameClock.days(3) == 3 * GameClock.DAY, "...and three is three")
	_ok(GameClock.days(0) == 0, "a zero span is zero")


func _case_a_gate_asks_the_clock() -> void:
	GameClock.reset()
	var stamp := GameClock.now()
	var span := GameClock.days(3)
	_ok(not GameClock.elapsed(stamp, span), "a fresh gate has not elapsed")
	_ok(GameClock.remaining(stamp, span) == span, "...with the whole span still to run")
	GameClock.advance(GameClock.days(2))
	_ok(not GameClock.elapsed(stamp, span), "part-way through, still closed")
	_ok(GameClock.remaining(stamp, span) == GameClock.days(1), "...one day left")
	GameClock.advance(GameClock.days(1))
	_ok(GameClock.elapsed(stamp, span), "on the day it is due, it opens")
	GameClock.advance(GameClock.days(9))
	_ok(GameClock.elapsed(stamp, span), "...and stays open")
	_ok(GameClock.remaining(stamp, span) == 0, "...with nothing remaining, never negative")


## `-1` used to mean BOTH "never happened" and a real moment one day before the start. A
## faction that had never been mediated compared as mediated-on-day-minus-one, which
## happened to work and would have stopped working the moment the clock's origin moved.
func _case_never_is_not_day_zero() -> void:
	GameClock.reset()
	_ok(GameClock.NEVER != 0, "NEVER is not the same value as the first moment")
	_ok(GameClock.elapsed(GameClock.NEVER, GameClock.days(30)),
		"something that never happened is long overdue")
	_ok(not GameClock.elapsed(GameClock.now(), GameClock.days(1)),
		"...whereas something that just happened is not")


## Systems that ACCRUE over time subscribe; the clock knows nothing about them. That is
## what lets it be replaced wholesale. It also means a clock that JUMPS pays correctly:
## a realtime clock resuming after a week must not pay a single day.
func _case_accrual_subscribes_rather_than_being_called() -> void:
	GameClock.reset()
	_ticks.clear()
	GameClock.on_tick(_record_tick)
	GameClock.advance()
	_ok(_ticks.size() == 1, "a subscriber is told when time passes")
	_ok(_ticks[0] == GameClock.DAY, "...and by how much")
	GameClock.advance(GameClock.days(7))
	_ok(_ticks.size() == 2 and _ticks[1] == GameClock.days(7),
		"a JUMP reports the whole jump, not one tick (got %s)" % str(_ticks))
	# Registering twice must not double-pay.
	GameClock.on_tick(_record_tick)
	_ticks.clear()
	GameClock.advance()
	_ok(_ticks.size() == 1, "subscribing twice does not pay twice")


func _case_it_round_trips_including_legacy_saves() -> void:
	GameClock.reset()
	GameClock.advance(GameClock.days(12))
	var saved := GameClock.to_dict()
	GameClock.reset()
	_ok(GameClock.day_number() == 0, "a reset clock is back at the start")
	GameClock.from_dict(saved)
	_ok(GameClock.day_number() == 12, "the clock survives a save round-trip (day %d)"
		% GameClock.day_number())

	# LEGACY: pilots saved before the clock existed stored a bare day count under Research.
	GameClock.reset()
	GameClock.from_dict({"day": 40})
	_ok(GameClock.day_number() == 40,
		"an old save's bare day count still loads (day %d)" % GameClock.day_number())
	GameClock.reset()
	GameClock.from_dict({})
	_ok(GameClock.day_number() == 0, "a save with no clock at all starts at the beginning")


## THE COUPLING ITSELF. Twenty sites read `Research.day` directly and several did arithmetic
## on it; that is what made the calendar hard to replace. This is a structural check rather
## than a behavioural one, because the failure it guards against is somebody REINTRODUCING a
## module-owned calendar, which no behavioural test would notice.
func _case_nobody_owns_a_calendar_any_more() -> void:
	var offenders: Array[String] = []
	for path in _gd_files("res://scripts") + _gd_files("res://scenes"):
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var n := 0
		for line in f.get_as_text().split("\n"):
			n += 1
			var code := str(line).strip_edges()
			if code.begins_with("#"):
				continue      # a comment may legitimately discuss the old field
			if code.contains("Research.day"):
				offenders.append("%s:%d" % [path.get_file(), n])
	_ok(offenders.is_empty(),
		"no module reads a calendar of its own — offenders: %s" % str(offenders))


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for sub in da.get_directories():
		out.append_array(_gd_files(dir + "/" + sub))
	for f in da.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	return out


func _record_tick(units: int) -> void:
	_ticks.append(units)


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)
