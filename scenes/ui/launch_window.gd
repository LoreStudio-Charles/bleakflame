class_name LaunchWindow
extends CanvasLayer
## The launch-clearance beat: pressing [E] to leave the station opens THIS
## instead of undocking instantly — a countdown plus your HOLD laid out, so
## leaving the sanctuary is a deliberate act and you get a last look at what
## you're carrying into the dark (and a chance to back out and stash it).
## [E] launches now, [Q]/[Esc] aborts, and letting the count reach zero launches
## you. Reinforces "flies with you, dies with you": the hold is exactly what you
## put at risk the instant you leave. COUNTDOWN is tunable.

signal launched
signal aborted

const COUNTDOWN := 4.0

var ship: TestShip
var _t := COUNTDOWN
var _count: Label
var _done := false


func _init(p_ship: TestShip) -> void:
	ship = p_ship
	layer = 45


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("esc_capture")   # pause menu defers to us while we're open

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.BG, 0.99)
	style.border_color = UiTheme.AMBER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(28.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var title := Label.new()
	title.text = "PREPARING TO LAUNCH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiTheme.AMBER)
	title.add_theme_font_size_override("font_size", 20)
	col.add_child(title)

	Tutor.register("launch_window", col)
	var ping := TutorPing.new()
	add_child(ping)
	ping.anchor = "launch_window"

	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_color_override("font_color", UiTheme.TEXT)
	_count.add_theme_font_size_override("font_size", 56)
	col.add_child(_count)

	col.add_child(_build_hold())

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var go := Button.new()
	go.text = "Launch Now  [E]"
	UiTheme.button_flavor(go, "primary", 200.0)
	go.pressed.connect(_launch)
	row.add_child(go)
	var stop := Button.new()
	stop.text = "Abort  [Q]"
	UiTheme.button_flavor(stop, "tertiary", 200.0)
	stop.pressed.connect(_abort)
	row.add_child(stop)

	_update_count()


## The manifest that flies (and dies) with you — the whole point of the pause.
func _build_hold() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var items: Array[String] = []
	for comp in ship.cargo:
		items.append(str(comp.display_name))
	for key in ship.commodities:
		var n: int = int(ship.commodities[key])
		if n > 0:
			items.append("%s ×%d" % [TradeGoods.display_name(str(key)), n])
	var head := Label.new()
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if items.is_empty():
		head.text = "Hold empty — nothing to lose out there."
		head.add_theme_color_override("font_color", Color(0.5, 0.82, 0.56))
		box.add_child(head)
	else:
		head.text = "⚠  %d in your hold — lost if you die:" % items.size()
		head.add_theme_color_override("font_color", UiTheme.DANGER)
		box.add_child(head)
		for it in items:
			var l := Label.new()
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.text = it
			l.add_theme_color_override("font_color", Color(0.86, 0.6, 0.5))
			l.add_theme_font_size_override("font_size", 12)
			box.add_child(l)
	return box


func _process(delta: float) -> void:
	if _done:
		return
	_t -= delta
	_update_count()
	if _t <= 0.0:
		_launch()


func _update_count() -> void:
	if _count != null:
		_count.text = str(maxi(0, ceili(_t)))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_E:
		get_viewport().set_input_as_handled()
		_launch()
	elif event.keycode == KEY_Q or event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_abort()


func _launch() -> void:
	if _done:
		return
	_done = true
	remove_from_group("esc_capture")
	# LAUNCHING SATISFIES THE WHOLE LAUNCH LESSON, whichever way you got here —
	# confirmed with [E], or just let the count run out. A pilot who simply
	# flies has demonstrated the thing; nagging them about the scrub they chose
	# not to try would be the tutorial talking for its own sake.
	Tutor.skip(["launch_hint", "launch_window"])
	Sfx.play("jingle", -6.0, 0.7)
	launched.emit()
	queue_free()


func _abort() -> void:
	if _done:
		return
	_done = true
	remove_from_group("esc_capture")
	Tutor.note("launch_window")   # they tried the scrub — now show them the way out
	Sfx.play("click", -10.0, 0.8)
	aborted.emit()
	queue_free()
