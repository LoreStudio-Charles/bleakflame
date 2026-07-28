class_name Radar
extends Control
## HUD radar, bottom-right. North-up with a facing tick. First concrete piece
## of the "sensors own situational awareness" system:
##   - Landmarks (station, planetoid) ALWAYS show — you have nav charts.
##     Beyond radar range they clamp to the rim as bearing markers.
##   - Live contacts (ships, loot) only show inside the ship's sensor range —
##     with a baseline floor so sensorless builds are never fully blind.

const SENSOR_FLOOR := 600.0

## Display size — the dashboard fits a smaller scope than the old corner.
var radius := 92.0
var ship: TestShip


func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2 + 16, radius * 2 + 16)
	ship = get_tree().get_first_node_in_group("player_ship")


func _process(_delta: float) -> void:
	var _t0 := Telemetry.now_us()
	_tick_p(_delta)
	Telemetry.phase("p.radar", _t0)


func _tick_p(_delta: float) -> void:
	visible = ship != null and not ship.dead and ship.docked_at == null
	if visible:
		queue_redraw()


func _radar_range() -> float:
	return ship.sensor_reach(SENSOR_FLOOR)   # 0 = no sensor = an empty scope


func _to_radar(world_pos: Vector2, clamp_to_rim: bool) -> Variant:
	var center := size * 0.5
	# NO SENSOR MEANS NO SCOPE, not a divide by zero. sensor_reach returns 0.0 for a
	# ship with no suite (the no-free-grants rule), and this divided by it: offset
	# became INF, `.normalized()` produced NaN, and the charted landmarks and waypoint
	# -- the layer that is meant to SURVIVE blindness, since you still have nav charts
	# -- drew at garbage coordinates instead of simply not scaling.
	var reach := _radar_range()
	if reach <= 0.0:
		return null
	var offset := (world_pos - ship.global_position) * (radius / reach)
	if offset.length() > radius - 4.0:
		if not clamp_to_rim:
			return null
		offset = offset.normalized() * (radius - 4.0)
	return center + offset


func _draw() -> void:
	var _t0 := Telemetry.now_us()
	_paint()
	Telemetry.phase("radar.draw", _t0)


func _paint() -> void:
	if ship == null or ship.build == null:
		return
	var center := size * 0.5

	# Instrument housing: same bezel as every other dashboard widget.
	var housing := UiTheme.bezel()
	if housing != null:
		draw_style_box(housing, Rect2(Vector2.ZERO, size))
	draw_circle(center, radius, Color(0.03, 0.05, 0.08, 0.82))
	draw_arc(center, radius, 0, TAU, 48, Color(0.35, 0.42, 0.55, 0.8), 1.5)
	draw_arc(center, radius * 0.5, 0, TAU, 32, Color(0.35, 0.42, 0.55, 0.25), 1.0)

	# Player: center dot + facing tick.
	draw_circle(center, 3.0, Color(0.8, 0.9, 1.0))
	draw_line(center, center + Vector2.RIGHT.rotated(ship.rotation) * 10.0,
		Color(0.8, 0.9, 1.0), 1.5)

	# Landmarks: CHARTED infrastructure (station, planet, belt) always shows,
	# rim-clamped when far. SECRET places never do — chart-only once found,
	# radar-visible only while tagged as the waypoint (user rule).
	for poi in PoiMap.pois:
		if not poi.get("charted", false):
			continue
		var lp = _to_radar(poi.pos, true)
		match poi.kind:
			"station":
				draw_rect(Rect2(lp - Vector2(3.5, 3.5), Vector2(7, 7)), Color(0.55, 0.75, 1.0), false, 1.5)
			"planet":
				draw_arc(lp, 5.0, 0, TAU, 12, Color(0.72, 0.55, 0.85), 1.5)
			"belt":
				draw_colored_polygon(PackedVector2Array([
					lp + Vector2(0, -4), lp + Vector2(4, 0), lp + Vector2(0, 4), lp + Vector2(-4, 0)]),
					Color(0.6, 0.55, 0.48))
			"beacon":
				# A lane marker: a small ringed pip. Rim-clamped like every charted
				# landmark, which is the whole point -- it gives a pilot a BEARING to
				# fly at across tens of thousands of units of empty road.
				draw_arc(lp, 4.0, 0, TAU, 12, Color(0.95, 0.82, 0.45), 1.4)
				draw_circle(lp, 1.6, Color(0.95, 0.82, 0.45))
			_:
				draw_circle(lp, 3.0, Color(0.6, 0.65, 0.75))
	# The waypoint: an amber bearing diamond, whatever it points at.
	var wp = PoiMap.waypoint_pos()
	if wp != null:
		var p = _to_radar(wp, true)
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]),
			UiTheme.AMBER)
		draw_arc(p, 7.5, 0, TAU, 16, Color(UiTheme.AMBER, 0.45), 1.2)

	# The named beast: while it hunts you, fear tells you its bearing even
	# beyond sensor range — a pulsing violet-red mark clamped to the rim.
	for beast in get_tree().get_nodes_in_group("leviathan"):
		if beast.get("hunting") == true:
			var p = _to_radar(beast.global_position, true)
			var pulse := 4.5 + sin(Time.get_ticks_msec() * 0.012) * 2.0
			draw_circle(p, pulse, Color(0.85, 0.25, 0.55))
			draw_arc(p, pulse + 3.0, 0, TAU, 16, Color(0.85, 0.25, 0.55, 0.5), 1.5)

	# Contacts: sensor-gated, never rim-clamped (out of range = unknown).
	var sensor_sq := _radar_range() * _radar_range()
	# Pirate dens are contacts, not landmarks: charts don't mark them.
	for den in get_tree().get_nodes_in_group("pirate_dens"):
		if ship.global_position.distance_squared_to(den.global_position) > sensor_sq:
			continue
		var dp = _to_radar(den.global_position, false)
		if dp != null:
			draw_rect(Rect2(dp - Vector2(4, 4), Vector2(8, 8)), Color(0.85, 0.5, 0.3), false, 1.5)
	for hostile in get_tree().get_nodes_in_group("hostile_team"):
		if hostile.get("dead") == true:
			continue
		if ship.global_position.distance_squared_to(hostile.global_position) > sensor_sq:
			continue
		var p = _to_radar(hostile.global_position, false)
		if p != null:
			var big: bool = hostile is BuildShip and hostile.stats.mass > 100.0
			draw_circle(p, 3.5 if big else 2.0, Color(0.95, 0.35, 0.3))
	for pickup in get_tree().get_nodes_in_group("loot"):
		if ship.global_position.distance_squared_to(pickup.global_position) > sensor_sq:
			continue
		var p = _to_radar(pickup.global_position, false)
		if p != null:
			var color: Color = Grades.color(pickup.def.grade) if pickup.def != null \
				else Color(0.92, 0.82, 0.5)
			draw_circle(p, 1.5, color)

	# MINEABLE ROCK — a MINER'S perk (ore_sense is 0 for everyone else, so the scope
	# stays clean). A small ore-brown chip within ore-sense range says "something to
	# cut here"; once SURVEYED it reads its verdict — brighter if it holds ore, dim
	# grey if it proved barren — so a prospector can skip the empties at a glance.
	var ore_sense: float = ship.stats.get("ore_sense", 0.0)
	if ore_sense > 0.0:
		var ore_sq: float = ore_sense * ore_sense
		for rock in get_tree().get_nodes_in_group("asteroids"):
			if ship.global_position.distance_squared_to(rock.global_position) > ore_sq:
				continue
			var rp = _to_radar(rock.global_position, false)
			if rp == null:
				continue
			var col := Color(0.62, 0.5, 0.32)                 # unsurveyed: unknown ore-brown
			if rock.get("surveyed") == true:
				# Object.get() takes ONE arg (unlike Dictionary.get) — the rock is a
				# MineableAsteroid, so these properties always resolve.
				if str(rock.get("ore_type")) != "" and int(rock.get("ore_units")) > 0:
					col = Color(0.85, 0.72, 0.4)              # surveyed & rich: brighter
				else:
					col = Color(0.4, 0.42, 0.46)              # surveyed & barren: dim
			draw_colored_polygon(PackedVector2Array([
				rp + Vector2(0, -2.5), rp + Vector2(2.5, 0),
				rp + Vector2(0, 2.5), rp + Vector2(-2.5, 0)]), col)
