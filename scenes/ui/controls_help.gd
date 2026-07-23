class_name ControlsHelp
extends CanvasLayer
## The CONTROLS / HELP overlay — the keybind reference that used to live as a
## near-invisible line on the dash. Opened from the Esc menu. Frees itself on
## Back; joins "esc_capture" so the pause menu's Esc defers to it while open.

## NOTE: literal square brackets in BBCode must be [lb]/[rb] — a backslash is
## NOT an escape in Godot's parser (it renders the backslash verbatim).
const CONTROLS := "[color=#f2b859]FLIGHT[/color]
  [b]W / S[/b]   thrust forward / reverse        [b]A / D[/b]   rotate
  [b]Space[/b]   brake                           [b]Shift[/b]   boost
  [color=#8890a0]near top speed + brake + hard turn = Hyperslide[/color]

[color=#f2b859]COMBAT[/color]
  [b]guns[/b] fire automatically, in-arc         [b][lb]1[rb]–[lb]5[rb][/b]   ability gems
  [b][lb]Z[rb][/b]   hold ordnance (missiles hold; guns stay hot)
  [b][lb]K[rb][/b]   go dark — systems offline

[color=#f2b859]TARGETING[/color]
  [b]RMB[/b]   select target / grab salvage       [b][lb]T[rb] / [lb]Y[rb][/b]   cycle foe / friendly

[color=#f2b859]DOCKING & INFO[/color]
  [b][lb]E[rb][/b]   dock / launch                    [b]F1[/b]   assembly viewer
  [b][lb]B[rb][/b] cargo   [b][lb]G[rb][/b] chart   [b][lb]C[rb][/b] comms   [b][lb]L[rb][/b] log   [b][lb]U[rb][/b] factions"


func _init() -> void:
	layer = 40


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("esc_capture")

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -320
	panel.offset_right = 320
	panel.offset_top = -220
	panel.offset_bottom = 220
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.BG, 0.99)
	style.border_color = Color(0.4, 0.62, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(26.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)

	var title := Label.new()
	title.text = "CONTROLS"
	title.add_theme_color_override("font_color", UiTheme.AMBER)
	title.add_theme_font_size_override("font_size", 22)
	col.add_child(title)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(580, 0)
	body.text = CONTROLS
	col.add_child(body)

	var back := Button.new()
	back.text = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiTheme.button_flavor(back, "tertiary", 200.0)
	back.pressed.connect(_close)
	col.add_child(back)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		_close()


func _close() -> void:
	Sfx.play("click", -14.0)
	queue_free()
