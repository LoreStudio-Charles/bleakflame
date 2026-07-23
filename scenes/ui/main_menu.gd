extends Control
## The game's ENTRY POINT (project main scene): an animated splash — the Seared
## Games logo, then the title reveal — settling into the MAIN MENU (Continue /
## New Game / Options / Quit). Continue and New Game change_scene into flight;
## New Game wipes the save first (with a confirm if one exists). Built in code,
## like the rest of the UI; the .tscn is just a scripted root.

const FLIGHT := "res://scenes/flight/flight_test.tscn"
const LOGO := "res://assets/ui/seared_games_logo.png"
const BG_ART := "res://assets/ui/menu_bg.png"   # drop-in; falls back to embers
const STUDIO_NAME := "SEARED GAMES"   # fallback if the logo art is missing

var _menu_col: VBoxContainer
var _splash_overlay: Control
var _splash_tween: Tween
var _splashing := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()

	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Drop-in background art sits over the dark wash; embers drift over both.
	# Without art, a soft radial "forge glow" gives the dark some depth.
	if ResourceLoader.exists(BG_ART):
		var art := TextureRect.new()
		art.texture = load(BG_ART)
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)
	else:
		_add_glow()
	_add_embers()

	_build_menu()
	_menu_col.modulate.a = 0.0

	Sfx.play_music("station")   # menu ambiance; silent until a track lands
	_play_splash()


## ---- Splash: Seared Games card -> title reveal ----

func _play_splash() -> void:
	_splashing = true
	_splash_overlay = Control.new()
	_splash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_splash_overlay)
	var cover := ColorRect.new()
	cover.color = UiTheme.BG
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splash_overlay.add_child(cover)

	var card_center := CenterContainer.new()
	card_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash_overlay.add_child(card_center)

	var card: Control
	if ResourceLoader.exists(LOGO):
		var logo := TextureRect.new()
		logo.texture = load(LOGO)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(460, 140)
		card = logo
	else:
		var lbl := Label.new()
		lbl.text = STUDIO_NAME
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 30)
		lbl.add_theme_color_override("font_color", UiTheme.TEXT)
		card = lbl
	card.modulate.a = 0.0
	card_center.add_child(card)

	_splash_tween = create_tween()
	_splash_tween.tween_property(card, "modulate:a", 1.0, 0.8)
	_splash_tween.tween_interval(1.1)
	_splash_tween.tween_property(card, "modulate:a", 0.0, 0.6)
	# Reveal the menu: drop the cover while the title/buttons fade up.
	_splash_tween.tween_property(_splash_overlay, "modulate:a", 0.0, 0.7)
	_splash_tween.parallel().tween_property(_menu_col, "modulate:a", 1.0, 0.7)
	_splash_tween.tween_callback(_finish_splash)


func _finish_splash() -> void:
	_splashing = false
	if _splash_overlay != null:
		_splash_overlay.queue_free()
		_splash_overlay = null


## A key or click skips straight to the menu.
func _unhandled_input(event: InputEvent) -> void:
	if not _splashing:
		return
	var go: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed)
	if go:
		if _splash_tween != null and _splash_tween.is_running():
			_splash_tween.kill()
		_menu_col.modulate.a = 1.0
		_finish_splash()


## ---- Menu ----

func _build_menu() -> void:
	# A CenterContainer centers its child on BOTH axes at its real size — unlike
	# PRESET_CENTER, which anchors the box while it's still zero-size and lets it
	# grow down-and-right off-centre. IGNORE mouse so empty areas still pass
	# clicks through to the splash-skip; the buttons (STOP) stay clickable.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_menu_col = VBoxContainer.new()
	_menu_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_col.add_theme_constant_override("separation", 12)
	center.add_child(_menu_col)

	var title := Label.new()
	title.text = "BLEAKFLAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_color_override("font_color", UiTheme.AMBER)
	_menu_col.add_child(title)

	var sub := Label.new()
	sub.text = "C I N D E R   R E A C H"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", UiTheme.DIM)
	_menu_col.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 34)
	_menu_col.add_child(gap)

	var has_save := FileAccess.file_exists(SaveGame.PATH)
	var cont := _menu_button("Continue", "primary" if has_save else "tertiary", _on_continue)
	cont.disabled = not has_save
	_menu_button("New Game", "secondary" if has_save else "primary", _on_new_game)
	_menu_button("Options", "tertiary", _on_options)
	_menu_button("Quit", "tertiary", _on_quit)


func _menu_button(text: String, flavor: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiTheme.button_flavor(b, flavor, 280.0)
	b.pressed.connect(func() -> void: Sfx.play("click", -12.0))
	b.pressed.connect(handler)
	_menu_col.add_child(b)
	return b


func _add_glow() -> void:
	var gt := GradientTexture2D.new()
	gt.width = 512
	gt.height = 512
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(0.9, 0.45, 0.2, 0.26), Color(0.9, 0.45, 0.2, 0.0)])
	gt.gradient = g
	var glow := TextureRect.new()
	glow.texture = gt
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)


func _add_embers() -> void:
	var vp := get_viewport_rect().size
	var p := CPUParticles2D.new()
	p.amount = 70
	p.lifetime = 9.0
	p.preprocess = 6.0
	p.position = Vector2(vp.x * 0.5, vp.y + 12.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(vp.x * 0.5, 6.0)
	p.direction = Vector2(0, -1)
	p.spread = 12.0
	p.gravity = Vector2(0, -7.0)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 26.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.95, 0.6, 0.3, 0.0),
		Color(0.95, 0.6, 0.3, 0.55),
		Color(0.9, 0.4, 0.2, 0.0)])
	p.color_ramp = ramp
	add_child(p)


func _on_continue() -> void:
	get_tree().change_scene_to_file(FLIGHT)


func _on_new_game() -> void:
	if FileAccess.file_exists(SaveGame.PATH):
		_show_confirm()
	else:
		_start_new()


func _start_new() -> void:
	SaveGame.reset_all_progress()
	get_tree().change_scene_to_file(FLIGHT)


func _on_options() -> void:
	add_child(OptionsPanel.new())


func _on_quit() -> void:
	get_tree().quit()


## New Game over an existing save asks first — a wipe is unrecoverable.
func _show_confirm() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -240
	panel.offset_right = 240
	panel.offset_top = -100
	panel.offset_bottom = 100
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.BG, 0.99)
	style.border_color = Color(0.42, 0.46, 0.54)   # neutral grey — red clashed with the amber glow
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(22.0)
	panel.add_theme_stylebox_override("panel", style)
	shade.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	var msg := Label.new()
	msg.text = "Start a new game?\nThis overwrites your saved progress."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_color_override("font_color", UiTheme.TEXT)
	col.add_child(msg)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var yes := Button.new()
	yes.text = "New Game"
	UiTheme.button_flavor(yes, "primary", 160.0)
	yes.pressed.connect(func() -> void:
		Sfx.play("click", -12.0)
		_start_new())
	row.add_child(yes)
	var no := Button.new()
	no.text = "Cancel"
	UiTheme.button_flavor(no, "tertiary", 160.0)
	no.pressed.connect(func() -> void:
		Sfx.play("click", -14.0)
		shade.queue_free())
	row.add_child(no)
