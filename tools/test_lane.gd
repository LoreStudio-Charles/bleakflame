extends Node
## THE LONG LANE's geography (docs/the_long_lane.md).
##   godot --headless --path . res://tools/test_lane.tscn
##
## THE INVARIANT: the middle half of the road belongs to NOBODY. Guardians leash
## at the first quarter, the Navy leashes at the last, and the Gap between them is
## why freight hires escorts and why the V-Shrike are worth being afraid of.
##
## It is a quiet thing to break. Widening a patrol band by a few percent looks
## like tuning, changes nothing visible on any screen, and silently removes the
## reason the lane exists — the danger stops being a PLACE. So the bands are
## constants and this asserts they never touch.
##
## Runs as a SCENE: it preloads flight_test.gd, which reaches autoloads.

const FT := preload("res://scenes/flight/flight_test.gd")

var _fails := 0


func _ready() -> void:
	_case_the_gap_is_unpatrolled()
	_case_bands_are_ordered_and_sane()
	_case_the_rim_end_clears_the_sanctuary()

	print("test_lane: %s" % ("ALL PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _fail(msg: String) -> void:
	print("FAIL: " + msg)
	_fails += 1


## Neither authority may reach into the Gap, from either end.
func _case_the_gap_is_unpatrolled() -> void:
	var gap: Vector2 = FT.LANE_GAP_LEG
	var guard: Vector2 = FT.LANE_GUARD_LEG
	var navy: Vector2 = FT.LANE_NAVY_LEG

	if guard.y >= gap.x:
		_fail("the Guardian band reaches t=%.2f, into a Gap that starts at t=%.2f — freight no longer needs an escort out of the rim" % [guard.y, gap.x])
	if navy.x <= gap.y:
		_fail("the Navy band starts at t=%.2f, inside a Gap that ends at t=%.2f — the capital end is covered when it must not be" % [navy.x, gap.y])
	# And the unpatrolled middle has to be SUBSTANTIAL. A token sliver of danger
	# between two patrols is not a Gap, it is a speed bump.
	var unpatrolled: float = navy.x - guard.y
	if unpatrolled < 0.35:
		_fail("only %.0f%% of the road is unpatrolled — the Gap should be about half of it" % (unpatrolled * 100.0))


func _case_bands_are_ordered_and_sane() -> void:
	for pair in [["guard", FT.LANE_GUARD_LEG], ["gap", FT.LANE_GAP_LEG], ["navy", FT.LANE_NAVY_LEG]]:
		var leg: Vector2 = pair[1]
		if leg.x >= leg.y:
			_fail("the %s band is empty or inverted (%.2f -> %.2f)" % [pair[0], leg.x, leg.y])
		if leg.x < 0.0 or leg.y > 1.0:
			_fail("the %s band runs off the road (%.2f -> %.2f)" % [pair[0], leg.x, leg.y])


## The rim anchor must sit OUTSIDE the station's sanctuary, or the lane's first
## leg starts inside the bubble where ambient hostiles are already forbidden —
## which would quietly extend safety up the road.
func _case_the_rim_end_clears_the_sanctuary() -> void:
	var d: float = FT.LANE_RIM.distance_to(Vector2.ZERO)
	if d <= AIShip.SANCTUARY_R:
		_fail("the lane's rim anchor is %.0fu from the station, inside the %.0fu sanctuary" % [
			d, AIShip.SANCTUARY_R])
