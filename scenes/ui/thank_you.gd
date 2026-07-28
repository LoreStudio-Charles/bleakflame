class_name ThankYou
extends CanvasLayer
## The demo send-off, shown when the player flies the waygate out of the Cinder
## Reach. Closes the "Nothing Left Behind" arc, teases system 2, thanks the
## friends-and-family testers — then HOLD [Space] (a deliberate, obvious hold,
## never an accidental tap) returns HOME to the main menu. Built so a real
## ending later can auto-loop home when it finishes, or offer this same hold as
## the shortcut out mid-sequence.

const MENU := "res://scenes/ui/main_menu.tscn"
const HOLD_TIME := 3.0    # long on purpose: a tester shouldn't miss the send-off
const BAR_W := 340.0

var pilot_line := ""

var _fill: ColorRect
var _hold := 0.0
var _armed := false        # only accept the hold after the screen has faded up
var _leaving := false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	# CanvasLayer isn't a CanvasItem (no modulate) — everything lives inside a
	# root Control so the whole screen can fade up from black.
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.03, 1.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	box.offset_left = -420
	box.offset_right = 420
	box.offset_top = -280
	box.offset_bottom = 280
	root.add_child(box)

	_center(box, "THE RING REMEMBERS.", UiTheme.AMBER, 30)
	_center(box, "The sequence lands — three long, two short, hold on the third —\n" +
		"and the dead gate wakes in cold blue light. Behind you the Cinder Reach\n" +
		"falls away: the station's lanterns, the quiet places, the empty patches\n" +
		"of space where ships used to be. Ahead, the dark you were made to answer.",
		UiTheme.TEXT, 15)
	_gap(box, 8)
	_center(box, "You are the first to run from Cinderweb and live —\n" +
		"and the first to chase it somewhere it can be ended.", Color(0.7, 0.8, 1.0), 16)
	_gap(box, 8)
	_center(box, "END OF THE CINDER REACH DEMO", UiTheme.AMBER, 20)
	if pilot_line != "":
		_center(box, pilot_line, Color(0.5, 0.55, 0.66), 13)
	_center(box, "Thank you for playing. The next system is coming.", Color(0.6, 0.66, 0.78), 14)
	_gap(box, 18)
	_build_hold_prompt(box)

	# Fade the whole thing up from black, THEN arm the hold — so an eager tester
	# mashing keys at the gate can't skip the send-off before it's even shown.
	root.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(root, "modulate", Color.WHITE, 1.4)
	tw.tween_callback(func() -> void: _armed = true)


func _build_hold_prompt(box: VBoxContainer) -> void:
	var prompt := Label.new()
	prompt.text = "Hold   [ SPACE ]   to return home"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", Color(0.6, 0.65, 0.78))
	prompt.add_theme_font_size_override("font_size", 15)
	box.add_child(prompt)
	var track := ColorRect.new()
	track.color = Color(0.15, 0.18, 0.25, 1.0)
	track.custom_minimum_size = Vector2(BAR_W, 10)
	track.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(track)
	_fill = ColorRect.new()
	_fill.color = UiTheme.AMBER
	_fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fill.position = Vector2.ZERO
	_fill.size = Vector2(0, 10)
	track.add_child(_fill)


func _process(delta: float) -> void:
	var _t0 := Telemetry.now_us()
	_tick_p(delta)
	Telemetry.phase("p.thank_you", _t0)


func _tick_p(delta: float) -> void:
	if _leaving:
		return
	var holding: bool = _armed and (Input.is_key_pressed(KEY_SPACE) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if holding:
		_hold = minf(HOLD_TIME, _hold + delta)
	else:
		_hold = maxf(0.0, _hold - delta * 2.5)   # release decays faster than it fills
	if _fill != null:
		_fill.size = Vector2(BAR_W * (_hold / HOLD_TIME), _fill.size.y)
	if _hold >= HOLD_TIME:
		_go_home()


func _go_home() -> void:
	if _leaving:
		return
	_leaving = true
	Sfx.play("click", -6.0)
	get_tree().change_scene_to_file(MENU)


func _center(parent: Node, text: String, color: Color, size: int) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", size)
	parent.add_child(lbl)


func _gap(parent: Node, h: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)
