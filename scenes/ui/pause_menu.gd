class_name PauseMenu
extends CanvasLayer
## The Escape menu: Resume / Controls / Options / Quit to Main Menu / Exit. Esc
## opens it — but only
## when nothing else owns Esc (a dialogue or an open overlay in the
## "esc_capture" group closes first). Added LAST in the flight scene so it
## processes Esc before those overlays and can defer to them.

## Whether opening the menu freezes the world. TRUE in solo (players expect a
## real pause). COOP SEAM: a coop session sets this FALSE — the menu opens
## live, the shared sim keeps running, and the station sanctuary / docking is
## your safe space. We never pause-for-all: freezing a shared authoritative
## sim is netcode-hostile and a griefing vector. Each player's menu is local.
var pauses_world := true

var _open := false
var _panel: PanelContainer
var _title: Label
var _options_note: Label


func _init() -> void:
	layer = 30


func _ready() -> void:
	# Keep running (and catching Esc) while the rest of the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.theme = UiTheme.get_theme()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -180
	_panel.offset_right = 180
	_panel.offset_top = -170
	_panel.offset_bottom = 170
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.BG, 0.99)
	style.border_color = Color(0.4, 0.62, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(22.0)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.visible = false
	add_child(_panel)

	# A dim backdrop while paused.
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.5)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.visible = false
	var shade_layer := CanvasLayer.new()
	shade_layer.layer = 29
	shade_layer.add_child(_shade)
	add_child(shade_layer)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", UiTheme.AMBER)
	_title.add_theme_font_size_override("font_size", 20)
	col.add_child(_title)
	_add_button(col, "Resume", "primary", _resume)
	_add_button(col, "Controls", "secondary", _on_controls)
	_add_button(col, "Options", "secondary", _on_options)
	_add_button(col, "Quit to Main Menu", "tertiary", _on_main_menu)
	_add_button(col, "Exit to Desktop", "tertiary", _on_exit)
	_options_note = Label.new()
	_options_note.text = ""
	_options_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_options_note.add_theme_font_size_override("font_size", 12)
	_options_note.add_theme_color_override("font_color", Color(0.5, 0.55, 0.66))
	col.add_child(_options_note)


var _shade: ColorRect


func _add_button(parent: Node, text: String, flavor: String, handler: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiTheme.button_flavor(b, flavor, 200.0)
	b.pressed.connect(func() -> void: Sfx.play("click", -14.0))
	b.pressed.connect(handler)
	parent.add_child(b)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ESCAPE:
		return
	if _open:
		_resume()
	elif get_tree().get_nodes_in_group("esc_capture").is_empty():
		_show()


func _show() -> void:
	_open = true
	_panel.visible = true
	_shade.visible = true
	_options_note.text = "" if pauses_world else "The Reach keeps flying — mind your ship."
	# Live in coop (world runs on); a true freeze only in solo.
	_title.text = "PAUSED" if pauses_world else "MENU"
	if pauses_world:
		get_tree().paused = true
	Sfx.play("click", -12.0, 1.2)


func _resume() -> void:
	_open = false
	_panel.visible = false
	_shade.visible = false
	if pauses_world:
		get_tree().paused = false


func _on_controls() -> void:
	# The keybind reference — moved here off the near-invisible dash line.
	add_child(ControlsHelp.new())


func _on_options() -> void:
	# Shared overlay with the main menu; it captures Esc while open (esc_capture).
	add_child(OptionsPanel.new())


## Back to the title. Progress since the last DOCK (the checkpoint) is left
## behind — docking is the save, and quitting must never bank an un-docked run.
func _on_main_menu() -> void:
	if pauses_world:
		get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_exit() -> void:
	if pauses_world:
		get_tree().paused = false
	get_tree().quit()
