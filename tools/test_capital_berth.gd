extends Node
## CAPITAL BERTH — the Supercruiser (first SUPER_HEAVY hull) and the Orivel
## drydocks that finally have something to hold. Validates the size gate's ACCEPT
## path: before this hull existed, nothing was above HEAVY, so only the REFUSAL
## side of DockingPad.size_permitted was ever reachable. Uses the REAL outpost
## pads and the REAL hull, so the config and the data are checked together.
##
## RUN AS A SCENE (autoloads):
##   <godot> --headless --path . res://tools/test_capital_berth.tscn
## Read-only: never writes the save (only pad size logic + hull/build data).

var _fails: Array[String] = []
var _checks := 0

const SB := HullDef.SizeBand


func _ready() -> void:
	var outpost := OrivelOutpost.new()
	add_child(outpost)   # _ready builds the 8 pads

	_case_supercruiser_is_the_first_capital()
	_case_fleet_build_fits()
	_case_drydock_accepts_the_capital(outpost)
	_case_bay_refuses_the_capital(outpost)
	_case_every_band_has_a_home(outpost)

	if _fails.is_empty():
		print("test_capital_berth: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: ", f)
		printerr("test_capital_berth: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)


func _hull() -> HullDef:
	return load("res://data/hulls/supercruiser.tres")


func _case_supercruiser_is_the_first_capital() -> void:
	var h := _hull()
	_ok(h != null, "supercruiser.tres loads")
	if h == null:
		return
	_ok(h.size_band == SB.SUPER_HEAVY, "Supercruiser is SUPER_HEAVY (got band %d)" % h.size_band)
	_ok(h.hull_hp >= 1000.0, "capital-scale hull (%d hp)" % int(h.hull_hp))
	_ok(h.silhouette.size() > 0 and h.fits_art_budget(), "silhouette + hardpoints fit the 256u SUPER_HEAVY canvas")
	# A Mk4 cruiser: combat slots cap at Mk4 (the coupling is always Mk5, exempt),
	# with the mixed battery present — a Mk1 turret that CAN track fighters (traverse
	# 360/mark = 360 deg/s) alongside Mk4 mains.
	var has_mk1_weapon := false
	var has_mk4_weapon := false
	for hp in h.hardpoints:
		if hp.slot_type != HardpointDef.SlotType.COUPLING:
			_ok(hp.mark <= 4, "%s is Mk<=4 (got %d)" % [hp.display_name, hp.mark])
		if hp.slot_type == HardpointDef.SlotType.WEAPON:
			has_mk1_weapon = has_mk1_weapon or hp.mark == 1
			has_mk4_weapon = has_mk4_weapon or hp.mark == 4
	_ok(has_mk1_weapon, "has a Mk1 turret — point-defense that swats fighters")
	_ok(has_mk4_weapon, "has a Mk4 main battery")


func _case_fleet_build_fits() -> void:
	var b := SampleBuilds.galean_supercruiser()
	_ok(b != null and b.hull != null, "fleet build (galean_supercruiser) constructs")
	if b == null or b.hull == null:
		return
	_ok(b.hull.size_band == SB.SUPER_HEAVY, "fleet build flies the Supercruiser hull")
	# Every hardpoint got something (13 slots, 0..12).
	_ok(b.slots.size() >= b.hull.hardpoints.size(), "all %d hardpoints are fitted (got %d)" % [b.hull.hardpoints.size(), b.slots.size()])
	# NO OVER-MARK: every fitted component's mark must be <= its slot's mark. This is
	# the exact bug the navy weapons fix — a Mk4 gun in a Mk3 mount slipped past
	# _make (which doesn't validate) and armed the ship with an illegal fit.
	for i in b.slots:
		if i >= b.hull.hardpoints.size():
			continue
		var comp = b.slots[i]
		if comp == null:
			continue
		var slot_mark: int = b.hull.hardpoints[i].mark
		var comp_mark: int = int(comp.get("mark")) if comp.get("mark") != null else 1
		_ok(comp_mark <= slot_mark, "%s (Mk%d) fits its Mk%d slot [%d]" % [str(comp.get("display_name")), comp_mark, slot_mark, i])


func _drydock(outpost: OrivelOutpost) -> DockingPad:
	for p in outpost.pads:
		if p.min_size_band == SB.SUPER_HEAVY:
			return p
	return null


func _bay(outpost: OrivelOutpost) -> DockingPad:
	for p in outpost.pads:
		if p.max_size_band == SB.HEAVY:
			return p
	return null


func _case_drydock_accepts_the_capital(outpost: OrivelOutpost) -> void:
	_ok(not outpost.pads.is_empty(), "outpost built its pads (%d)" % outpost.pads.size())
	var d := _drydock(outpost)
	_ok(d != null, "outpost has a drydock (min SUPER_HEAVY)")
	if d == null:
		return
	# THE POINT: the accept path, previously unreachable.
	_ok(d.size_permitted(SB.SUPER_HEAVY), "a drydock ACCEPTS a Supercruiser")
	_ok(d.size_permitted(SB.SUPER_HEAVY_PLUS), "a drydock also accepts SUPER_HEAVY_PLUS (the future carrier)")
	_ok(not d.size_permitted(SB.HEAVY), "a drydock refuses a HEAVY — too small for the cradles")
	_ok(not d.size_permitted(SB.LIGHT), "a drydock refuses a fighter — too small")


func _case_bay_refuses_the_capital(outpost: OrivelOutpost) -> void:
	var bay := _bay(outpost)
	_ok(bay != null, "outpost has a landing bay (max HEAVY)")
	if bay == null:
		return
	_ok(not bay.size_permitted(SB.SUPER_HEAVY), "a bay refuses the Supercruiser — too large")
	_ok(bay.size_permitted(SB.HEAVY), "a bay takes HEAVY")
	_ok(bay.size_permitted(SB.MEDIUM), "a bay takes MEDIUM")
	_ok(bay.size_permitted(SB.LIGHT), "a bay takes LIGHT")


func _case_every_band_has_a_home(outpost: OrivelOutpost) -> void:
	# Bays cover LIGHT..HEAVY, drydocks SUPER_HEAVY..PLUS — the ranges are contiguous
	# and abut, so every band lands somewhere and nothing falls through the gap.
	for band in [SB.LIGHT, SB.MEDIUM, SB.HEAVY, SB.SUPER_HEAVY, SB.SUPER_HEAVY_PLUS]:
		var homed := false
		for p in outpost.pads:
			if p.size_permitted(band):
				homed = true
				break
		_ok(homed, "size band %d has a berth on the outpost" % band)
