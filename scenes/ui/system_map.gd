class_name SystemMap
extends CanvasLayer
## The system chart, toggled with [G] (open docked or in flight — charting
## mid-dogfight is legal and inadvisable). Fog-of-discovery: only POIs
## you've found appear. Click a POI to tag it as the WAYPOINT (click again
## to clear) — the waypoint is the only chart mark the radar ever shows.

var ship: TestShip
var _view: ChartView


func _init(p_ship: TestShip) -> void:
	ship = p_ship
	layer = 12
	visible = false


func _ready() -> void:
	_view = ChartView.new()
	_view.ship = ship
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_view)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_G and not ship.dead:
		visible = not visible
		_esc_capture(visible)
		if visible:
			Tutor.note("radar")   # they found the chart themselves
		Sfx.play("click", -10.0, 1.3 if visible else 0.9)
	elif event.keycode == KEY_ESCAPE and visible:
		visible = false
		_esc_capture(false)
		Sfx.play("click", -10.0, 0.9)


## While open, own Esc so the pause menu stays shut.
func _esc_capture(on: bool) -> void:
	if on:
		add_to_group("esc_capture")
	else:
		remove_from_group("esc_capture")


class ChartView:
	extends Control
	const PAD := 70.0
	var ship: TestShip
	var _world_rect := Rect2()

	func _process(_delta: float) -> void:
		if visible and is_visible_in_tree():
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			var best_id := ""
			var best_d := 30.0
			for p in PoiMap.pois:
				if not PoiMap.is_discovered(p.id):
					continue
				var d: float = event.position.distance_to(_to_map(p.pos))
				if d < best_d:
					best_d = d
					best_id = p.id
			if best_id != "":
				PoiMap.waypoint_id = "" if PoiMap.waypoint_id == best_id else best_id
				Sfx.play("click", -8.0, 1.4 if PoiMap.waypoint_id != "" else 0.8)
				queue_redraw()

	func _fit() -> void:
		# Frame everything known plus the player, with margin.
		var r := Rect2(ship.global_position, Vector2.ZERO)
		for p in PoiMap.pois:
			if PoiMap.is_discovered(p.id):
				r = r.expand(p.pos)
		_world_rect = r.grow(1600.0)

	func _to_map(world: Vector2) -> Vector2:
		var usable := size - Vector2(PAD * 2.0, PAD * 2.0)
		var s := minf(usable.x / _world_rect.size.x, usable.y / _world_rect.size.y)
		var origin := size * 0.5 - _world_rect.get_center() * s
		return origin + world * s

	func _draw() -> void:
		_fit()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.055, 0.96))
		var frame := UiTheme.bezel_frame()
		if frame != null:
			draw_style_box(frame, Rect2(Vector2(24, 24), size - Vector2(48, 48)))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(44, 52), "CINDER REACH — SYSTEM CHART",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UiTheme.AMBER)
		draw_string(font, Vector2(44, size.y - 36),
			"[G]/[Esc] close    click a point of interest to tag it as the waypoint",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.DIM)

		# Grid: one line per 2000 world units — distance stays readable.
		var grid_color := Color(0.16, 0.2, 0.3, 0.35)
		var gx := floorf(_world_rect.position.x / 2000.0) * 2000.0
		while gx < _world_rect.end.x:
			draw_line(Vector2(_to_map(Vector2(gx, 0)).x, PAD * 0.6),
				Vector2(_to_map(Vector2(gx, 0)).x, size.y - PAD * 0.6), grid_color, 1.0)
			gx += 2000.0
		var gy := floorf(_world_rect.position.y / 2000.0) * 2000.0
		while gy < _world_rect.end.y:
			draw_line(Vector2(PAD * 0.6, _to_map(Vector2(0, gy)).y),
				Vector2(size.x - PAD * 0.6, _to_map(Vector2(0, gy)).y), grid_color, 1.0)
			gy += 2000.0

		for p in PoiMap.pois:
			if not PoiMap.is_discovered(p.id):
				continue
			var m := _to_map(p.pos)
			var waypointed: bool = p.id == PoiMap.waypoint_id
			_draw_poi(m, p.kind)
			if waypointed:
				draw_arc(m, 14.0, 0, TAU, 24, UiTheme.AMBER, 2.0)
				draw_string(ThemeDB.fallback_font, m + Vector2(18, -10), "WAYPOINT",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiTheme.AMBER)
			draw_string(ThemeDB.fallback_font, m + Vector2(14, 5), p.name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiTheme.TEXT)

		# You: position + facing.
		var me := _to_map(ship.global_position)
		var nose := Vector2.RIGHT.rotated(ship.rotation)
		draw_circle(me, 4.0, Color(0.8, 0.95, 1.0))
		draw_line(me, me + nose * 14.0, Color(0.8, 0.95, 1.0), 1.6)

	func _draw_poi(m: Vector2, kind: String) -> void:
		match kind:
			"station":
				draw_rect(Rect2(m - Vector2(6, 6), Vector2(12, 12)), Color(0.55, 0.75, 1.0), false, 2.0)
			"planet":
				draw_arc(m, 8.0, 0, TAU, 20, Color(0.72, 0.55, 0.85), 2.0)
			"belt":
				draw_colored_polygon(PackedVector2Array([m + Vector2(0, -7),
					m + Vector2(7, 0), m + Vector2(0, 7), m + Vector2(-7, 0)]),
					Color(0.6, 0.55, 0.48))
			"den":
				draw_rect(Rect2(m - Vector2(6, 6), Vector2(12, 12)), Color(0.85, 0.5, 0.3), false, 2.0)
				draw_line(m + Vector2(-6, -6), m + Vector2(6, 6), Color(0.85, 0.5, 0.3), 1.5)
			"haunt":
				draw_arc(m, 7.0, 0, TAU, 6, Color(0.75, 0.45, 0.5), 2.0)
			_:
				draw_circle(m, 4.0, Color(0.7, 0.75, 0.85))
