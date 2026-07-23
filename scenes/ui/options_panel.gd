class_name OptionsPanel
extends CanvasLayer
## Reusable OPTIONS overlay — audio volumes + fullscreen, bound to the Settings
## autoload. Used by BOTH the main menu and the pause menu. Frees itself on Back;
## joins "esc_capture" so the pause menu's Esc defers to it while it's open.

func _init() -> void:
	layer = 40


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("esc_capture")

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = -200
	panel.offset_bottom = 200
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.BG, 0.99)
	style.border_color = Color(0.4, 0.62, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(26.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	panel.add_child(col)

	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiTheme.AMBER)
	title.add_theme_font_size_override("font_size", 22)
	col.add_child(title)

	_add_slider(col, "Master Volume", "master")
	_add_slider(col, "Music", "music")
	_add_slider(col, "Sound Effects", "sfx")

	var fs_row := HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 10)
	col.add_child(fs_row)
	var fs_lbl := Label.new()
	fs_lbl.text = "Fullscreen"
	fs_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_row.add_child(fs_lbl)
	var fs := CheckButton.new()
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(func(on: bool) -> void:
		Settings.set_fullscreen(on)
		Sfx.play("click", -14.0))
	fs_row.add_child(fs)

	var back := Button.new()
	back.text = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiTheme.button_flavor(back, "tertiary", 220.0)
	back.pressed.connect(_close)
	col.add_child(back)


func _add_slider(col: VBoxContainer, label: String, which: String) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	col.add_child(row)
	var head := HBoxContainer.new()
	row.add_child(head)
	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(lbl)
	var val := Label.new()
	val.add_theme_color_override("font_color", UiTheme.DIM)
	val.text = "%d%%" % roundi(Settings.volume(which) * 100.0)
	head.add_child(val)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = Settings.volume(which)
	s.custom_minimum_size = Vector2(420, 0)
	s.value_changed.connect(func(v: float) -> void:
		Settings.set_volume(which, v)
		val.text = "%d%%" % roundi(v * 100.0))
	row.add_child(s)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	Sfx.play("click", -14.0)
	remove_from_group("esc_capture")
	queue_free()
