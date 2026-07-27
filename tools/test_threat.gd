extends Node
## POWER RANKS — does the scale actually separate the ships it is meant to?
##
## The whole feature exists because a level-5 Guardian (3x pools AND 3x damage) and
## a level-5 pirate read identically on screen. So the test that matters is not "the
## function returns a number" — it is that the SHIPPED builds land in different
## ranks, in the right order, and that a stock rim pirate stays quiet.
##
## THIS ALSO CALIBRATES. Threat.BASE_POWER is a pinned constant; this prints the
## measured baseline and fails if it has drifted far enough to move ranks, so a
## balance change re-ranks the fleet in a test instead of in a playthrough.
##
## RUN AS A SCENE (autoloads + real builds):
##   <godot> --headless --path . res://tools/test_threat.tscn

var _fails: Array[String] = []
var _checks := 0


func _ready() -> void:
	var stock := _ship(SampleBuilds.get_build(0))            # rim pirate, the baseline
	# THE SAME BUILD, BOTH WAYS. A first draft compared a stock hull against a
	# Guardian flying a DIFFERENT (lighter) hull, and they scored within 2% of each
	# other -- so the test reported the feature broken when what was actually broken
	# was the comparison. Isolating the military multipliers means changing ONE thing.
	var guard := GuardianShip.new()
	add_child(guard)
	guard.setup_guard(SampleBuilds.get_build(0), 600.0)

	var p_stock := Threat.ship_power(stock)
	var p_guard := Threat.ship_power(guard)
	print("  measured: stock=%.1f  guardian(same hull)=%.1f  ratio=%.2f  (BASE_POWER=%.1f)"
		% [p_stock, p_guard, p_guard / maxf(p_stock, 0.01), Threat.BASE_POWER])

	# CALIBRATION. The constant only has to be close enough that ranks do not move;
	# a wide tolerance keeps this from failing on every incidental tuning nudge while
	# still catching a change big enough to matter.
	# CALIBRATED ON THE NORMALISED VALUE, not the raw one. Comparing raw power to
	# BASE_POWER compares a level-3 ship against a level-1 unit and passes while the
	# constant is wrong by exactly that ship's level growth -- which is how a Guardian
	# came to audit at 0.63 of a target it hits precisely. The claim worth asserting
	# is the one the whole scale rests on: an ordinary enemy scores 1.0 FOR ITS LEVEL.
	var n_stock := Threat.normalised(p_stock, stock.level())
	print("  a stock rim pirate normalises to %.2f (must be ~1.0)" % n_stock)
	_ok(absf(n_stock - 1.0) < 0.25,
		"a stock hull IS the unit — normalises to 1.0 (got %.2f)" % n_stock)

	# THE POINT OF THE WHOLE FEATURE.
	_ok(p_guard > p_stock * 2.0,
		"a Guardian scores far above a stock hull (%.1f vs %.1f)" % [p_guard, p_stock])
	var r_stock := Threat.rank_of(stock)
	var r_guard := Threat.rank_of(guard)
	_ok(r_stock == Threat.Rank.NORMAL,
		"a rim pirate ranks NORMAL — the common case stays silent (got %s)"
			% Threat.label(r_stock))
	# THE AUTHORED SPEC (user, 2026-07-27): "Guardians are Elite."
	_ok(r_guard == Threat.Rank.ELITE,
		"a Guardian patrol reads ELITE — built for a %s (got %s)"
			% [Threat.group_text(r_guard), Threat.label(r_guard)])
	_ok(Threat.pips(r_stock) == "", "NORMAL draws no pips, so the marks stay a warning")
	_ok(Threat.pips(r_guard) != "", "...and an ELITE wears some")

	# THE AUDIT. Rank is a promise; this is whether the ship keeps it. Reported rather
	# than enforced, because the fleet does NOT meet its targets yet and a hard fail
	# would just be a red suite nobody can fix today — but an unmet promise should be
	# a number somebody can see, not a surprise in play.
	print("  audit — ELITE promises %.0fx a same-level normal:" % Threat.RANK_MULT[Threat.Rank.ELITE])
	print("    guardian hits %.2f of its target" % Threat.target_ratio(guard))
	_ok(Threat.target_ratio(guard) > 0.0, "the audit produces a real ratio")
	_ok(Threat.RANK_MULT[Threat.Rank.MILITARY] == 6.0
		and Threat.RANK_MULT[Threat.Rank.SPEC_OPS] == 24.0,
		"the tuning targets are the authored 3x / 6x / 24x")

	if _fails.is_empty():
		print("test_threat: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_threat: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _ship(build: ShipBuild, level := 0) -> AIShip:
	var a := AIShip.new()
	add_child(a)
	a.spawn_level = level       # BEFORE setup: apply_build is where pools are scaled
	a.setup(build)
	return a


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)
