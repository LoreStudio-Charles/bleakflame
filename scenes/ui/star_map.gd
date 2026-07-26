class_name StarMap
extends CanvasLayer
## THE MAP — [M]. One view that zooms through every scale the game has:
##
##     SURFACE  →  SYSTEM  →  GALAXY  →  UNIVERSE
##
## (user's spec, 2026-07-25). RIGHT-CLICK zooms OUT one level; clicking an element that
## has a deeper level zooms IN to it. It replaced the flat single-level system chart.
##
## THE CLICK MODEL, reconciled with the game's input scheme (LMB always selects):
##   1st LMB on an element  — SELECT it, and tag it as the WAYPOINT if it's somewhere you
##                            can actually fly (that navigation is the tutorial's core
##                            loop, so it must not be lost to the new zooming).
##   2nd LMB on the SAME    — ZOOM IN, if it has a deeper level. Select-then-enter, the
##     element                same pattern as every file browser.
##   RMB anywhere           — ZOOM OUT one level.
## Clicking the current waypoint again clears it (back to auto-tracking by the tracker).
##
## HONEST ABOUT WHAT ISN'T KNOWN. The galaxy and universe levels have no content yet, and
## this does NOT invent any: they show the one system we have, the gate leading out of it,
## and everything beyond marked UNCHARTED. That happens to be exactly right for the Saga —
## humanity flies gate to gate in ignorance — so the empty map is the story, not a stub.

enum Level {SURFACE, SYSTEM, GALAXY, UNIVERSE}

const LEVEL_NAME := {
	Level.SURFACE: "SURFACE",
	Level.SYSTEM: "SYSTEM",
	Level.GALAXY: "GALAXY",
	Level.UNIVERSE: "UNIVERSE",
}

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
	if event.keycode == Keys.MAP and not ship.dead:
		visible = not visible
		_esc_capture(visible)
		if visible:
			_view.enter()
			Tutor.did("chart_opened")   # they found the map themselves
		Sfx.play("click", -10.0, 1.3 if visible else 0.9)
	elif event.keycode == Keys.MENU and visible:
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
	## Ids the galaxy/universe levels use for their single known nodes.
	const HOME_SYSTEM := "sys_cinder_reach"
	const HOME_GALAXY := "gal_local"

	var ship: TestShip
	var level: int = Level.SYSTEM
	var _selected := ""
	var _world_rect := Rect2()

	func _process(_delta: float) -> void:
		if visible and is_visible_in_tree():
			queue_redraw()

	## Opening the map should show you WHERE YOU ARE, not wherever you left it: on foot it
	## opens on the surface, in space on the system.
	func enter() -> void:
		level = Level.SURFACE if _town() != null else Level.SYSTEM
		_selected = ""

	## The town YOU ARE STANDING IN — null while flying.
	##
	## Existence is not the question. Launching from Epharon HIDES the town and
	## freezes its SubViewport; it is never freed, and it stays in group
	## "ground_town" because the character sheet needs to reach it to re-apply gear
	## whether you are down there or not. So asking the group whether a town exists
	## answered "yes" forever after your first landing, and the chart opened on the
	## surface map for the rest of the session no matter how far out you flew
	## (user, 2026-07-26).
	##
	## `can_process()` is the honest test: flight_test disables the ground viewport's
	## process mode when you launch, so this is false exactly when you are not on
	## foot — and it stays correct if the town is ever pooled or re-parented, which
	## a visibility check would not.
	func _town() -> Node:
		var t := get_tree().get_first_node_in_group("ground_town")
		return t if t != null and t.can_process() else null

	# ---------------------------------------------------------------- elements

	## Everything drawn at the current level, in one shape:
	##   {id, name, pos (world/level units), kind, deeper (bool), navigable (bool)}
	func _elements() -> Array:
		match level:
			Level.SURFACE:
				return _surface_elements()
			Level.SYSTEM:
				return _system_elements()
			Level.GALAXY:
				return _galaxy_elements()
		return _universe_elements()

	func _surface_elements() -> Array:
		var town := _town()
		if town == null:
			return []
		var out: Array = []
		for f in town.call("map_data").features:
			out.append({"id": str(f.name), "name": str(f.name), "pos": f.pos,
				"kind": str(f.kind), "deeper": false, "navigable": false})
		return out

	## The charted system: fog-of-discovery still applies, so only what you've found shows.
	func _system_elements() -> Array:
		var out: Array = []
		for p in PoiMap.pois:
			if not PoiMap.is_discovered(p.id):
				continue
			# A planet you can walk on is the only thing with a level BELOW system — and
			# only while you're standing on it (we can't chart a surface from orbit).
			var deeper: bool = str(p.kind) == "planet" and _town() != null
			out.append({"id": str(p.id), "name": str(p.name), "pos": p.pos,
				"kind": str(p.kind), "deeper": deeper, "navigable": true})
		return out

	## ONE system, and the gate out of it. Everything else is honestly unknown.
	func _galaxy_elements() -> Array:
		var out: Array = [{
			"id": HOME_SYSTEM, "name": "Cinder Reach", "pos": Vector2.ZERO,
			"kind": "system", "deeper": true, "navigable": false}]
		# The WayGate is the only road out, so the neighbour it leads to is drawn as a
		# known DIRECTION with an unknown destination.
		if PoiMap.exists("waygate") and PoiMap.is_discovered("waygate"):
			out.append({"id": "sys_beyond", "name": "Beyond the Gate — UNCHARTED",
				"pos": Vector2(2600, -1400), "kind": "unknown",
				"deeper": false, "navigable": false})
		return out

	func _universe_elements() -> Array:
		return [{"id": HOME_GALAXY, "name": "The Local Cluster", "pos": Vector2.ZERO,
			"kind": "galaxy", "deeper": true, "navigable": false}]

	# ---------------------------------------------------------------- input

	func _gui_input(event: InputEvent) -> void:
		if event is not InputEventMouseButton or not event.pressed:
			return
		# RIGHT-CLICK ZOOMS OUT (user's spec). At the top there's nowhere further to go.
		if event.button_index == Keys.INTERACT_AT_CURSOR:
			_zoom_out()
			return
		if event.button_index != Keys.SELECT:
			return
		var hit := _element_at(event.position)
		if hit.is_empty():
			return
		# SELECT-THEN-ENTER: the first click picks it (and waypoints it if it's a place you
		# can fly to); a second click on the same element descends.
		if _selected == str(hit.id) and bool(hit.deeper):
			_zoom_in(str(hit.id))
			return
		_selected = str(hit.id)
		if bool(hit.navigable):
			var clearing: bool = PoiMap.waypoint_id == str(hit.id) and PoiMap.waypoint_manual
			PoiMap.set_waypoint("" if clearing else str(hit.id), true)
		Sfx.play("click", -8.0, 1.4)

	func _element_at(at: Vector2) -> Dictionary:
		var best := {}
		var best_d := 34.0
		for e in _elements():
			var d: float = at.distance_to(_to_map(e.pos))
			if d < best_d:
				best_d = d
				best = e
		return best

	func _zoom_in(id: String) -> void:
		match level:
			Level.UNIVERSE:
				level = Level.GALAXY
			Level.GALAXY:
				level = Level.SYSTEM
			Level.SYSTEM:
				level = Level.SURFACE
			_:
				return
		_selected = ""
		Sfx.play("click", -8.0, 1.6)

	func _zoom_out() -> void:
		if level == Level.UNIVERSE:
			return
		level += 1
		_selected = ""
		Sfx.play("click", -8.0, 0.8)

	# ---------------------------------------------------------------- drawing

	func _fit(elements: Array) -> void:
		var r := Rect2()
		var started := false
		# The player only exists on the two levels they physically occupy.
		if level == Level.SYSTEM:
			r = Rect2(ship.global_position, Vector2.ZERO)
			started = true
		elif level == Level.SURFACE and _town() != null:
			r = Rect2(_town().call("map_data").player, Vector2.ZERO)
			started = true
		for e in elements:
			if started:
				r = r.expand(e.pos)
			else:
				r = Rect2(e.pos, Vector2.ZERO)
				started = true
		if not started:
			r = Rect2(Vector2.ZERO, Vector2.ZERO)
		var margin := 1600.0 if level == Level.SYSTEM else (600.0 if level == Level.SURFACE else 1800.0)
		_world_rect = r.grow(margin)

	func _to_map(world: Vector2) -> Vector2:
		var usable := size - Vector2(PAD * 2.0, PAD * 2.0)
		var s := minf(usable.x / maxf(1.0, _world_rect.size.x),
			usable.y / maxf(1.0, _world_rect.size.y))
		var origin := size * 0.5 - _world_rect.get_center() * s
		return origin + world * s

	func _draw() -> void:
		var elements := _elements()
		_fit(elements)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.055, 0.96))
		var frame := UiTheme.bezel_frame()
		if frame != null:
			draw_style_box(frame, Rect2(Vector2(24, 24), size - Vector2(48, 48)))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(44, 52), _title(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UiTheme.AMBER)
		_draw_breadcrumb(font)
		draw_string(font, Vector2(44, size.y - 36), _footer(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.DIM)

		if level == Level.SYSTEM or level == Level.SURFACE:
			_draw_grid()

		for e in elements:
			var m := _to_map(e.pos)
			_draw_element(m, str(e.kind), e)
			var label_col: Color = UiTheme.TEXT
			if str(e.kind) == "unknown":
				label_col = Color(0.55, 0.5, 0.62)
			draw_string(font, m + Vector2(14, 5), str(e.name),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, label_col)
			if str(e.id) == PoiMap.waypoint_id:
				draw_arc(m, 14.0, 0, TAU, 24, UiTheme.AMBER, 2.0)
				draw_string(font, m + Vector2(18, -10), "WAYPOINT",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiTheme.AMBER)
			if str(e.id) == _selected:
				draw_arc(m, 19.0, 0, TAU, 28, Color(0.6, 0.85, 1.0, 0.9), 1.6)
				if bool(e.deeper):
					draw_string(font, m + Vector2(-14, 34), "▼ click again to enter",
						HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.85, 1.0))

		# YOU — only where you actually are.
		if level == Level.SYSTEM:
			_draw_you(_to_map(ship.global_position), Vector2.RIGHT.rotated(ship.rotation))
		elif level == Level.SURFACE and _town() != null:
			_draw_you(_to_map(_town().call("map_data").player), Vector2.ZERO)

	func _draw_you(m: Vector2, nose: Vector2) -> void:
		draw_circle(m, 4.0, Color(0.8, 0.95, 1.0))
		if nose != Vector2.ZERO:
			draw_line(m, m + nose * 14.0, Color(0.8, 0.95, 1.0), 1.6)

	func _title() -> String:
		match level:
			Level.SURFACE:
				var t := _town()
				return str(t.call("map_data").name) if t != null else "SURFACE — NOT LANDED"
			Level.SYSTEM:
				return "CINDER REACH — SYSTEM CHART"
			Level.GALAXY:
				return "THE LOCAL CLUSTER — MOSTLY UNCHARTED"
		return "THE UNIVERSE — UNCHARTED"

	## The zoom stack, so you always know how deep you are and what right-click does.
	func _draw_breadcrumb(font: Font) -> void:
		var parts: Array = []
		for l in [Level.UNIVERSE, Level.GALAXY, Level.SYSTEM, Level.SURFACE]:
			parts.append(str(LEVEL_NAME[l]))
		var x := 44.0
		for i in parts.size():
			var lv: int = [Level.UNIVERSE, Level.GALAXY, Level.SYSTEM, Level.SURFACE][i]
			var here: bool = lv == level
			var col: Color = UiTheme.AMBER if here else Color(0.42, 0.47, 0.58)
			var s: String = str(parts[i])
			draw_string(font, Vector2(x, 76), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
			x += font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8.0
			if i < parts.size() - 1:
				draw_string(font, Vector2(x, 76), "›", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
					Color(0.3, 0.34, 0.42))
				x += 14.0

	func _footer() -> String:
		var out := "[M]/[Esc] close    RIGHT-CLICK zooms out"
		if level != Level.SURFACE:
			out += "    click an element to select it, again to enter"
		if level == Level.SYSTEM:
			out += "    (selecting tags the waypoint)"
		return out

	func _draw_grid() -> void:
		var step := 2000.0 if level == Level.SYSTEM else 500.0
		var grid_color := Color(0.16, 0.2, 0.3, 0.35)
		var gx := floorf(_world_rect.position.x / step) * step
		while gx < _world_rect.end.x:
			draw_line(Vector2(_to_map(Vector2(gx, 0)).x, PAD * 0.6),
				Vector2(_to_map(Vector2(gx, 0)).x, size.y - PAD * 0.6), grid_color, 1.0)
			gx += step
		var gy := floorf(_world_rect.position.y / step) * step
		while gy < _world_rect.end.y:
			draw_line(Vector2(PAD * 0.6, _to_map(Vector2(0, gy)).y),
				Vector2(size.x - PAD * 0.6, _to_map(Vector2(0, gy)).y), grid_color, 1.0)
			gy += step

	func _draw_element(m: Vector2, kind: String, e: Dictionary) -> void:
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
			# --- surface ---
			"building":
				var sz: Vector2 = e.get("size", Vector2(120, 100))
				var half := Vector2(maxf(4.0, sz.x * 0.02), maxf(4.0, sz.y * 0.02))
				draw_rect(Rect2(m - half, half * 2.0), Color(0.62, 0.66, 0.76), false, 1.8)
			"cave":
				draw_arc(m, 7.0, PI, TAU, 12, Color(0.78, 0.62, 0.44), 2.0)
			"person":
				draw_circle(m, 3.0, Color(0.95, 0.85, 0.6))
			# --- galaxy / universe ---
			"system":
				draw_arc(m, 11.0, 0, TAU, 28, Color(0.75, 0.85, 1.0), 2.0)
				draw_circle(m, 3.0, Color(0.85, 0.92, 1.0))
			"galaxy":
				for k in 3:
					draw_arc(m, 9.0 + k * 6.0, 0, TAU, 30, Color(0.7, 0.75, 1.0, 0.5 - k * 0.12), 1.6)
			"unknown":
				draw_arc(m, 9.0, 0, TAU, 12, Color(0.45, 0.42, 0.5), 1.4)
				draw_string(ThemeDB.fallback_font, m - Vector2(4, -5), "?",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 0.5, 0.62))
			_:
				draw_circle(m, 4.0, Color(0.7, 0.75, 0.85))
