class_name GoingDark
extends CanvasLayer
## GOING DARK — Systems Offline. Toggle [K] in flight. It cuts engines (you
## drift), shields, and sensors; the screen goes BLACK except this panel — you
## are blind. The ONE thing you can do dark is re-flash the PROCESSOR BUS
## (memorize abilities into the [1]-[5] gems); otherwise gem loadout is
## dock-only. Your sensor signature drops so distant hunters lose you (anything
## close still sees you), and hull/armor slowly mend. Reboot ([K]/Esc) brings
## you back online after a short lockout. Vulnerable on purpose — only smart
## with cover, or a real need. (User-designed 2026-07-21; docs/progression.)

var ship: TestShip
var _sel := -1                 # selected gem slot (-1 = none)
var _slot_btns: Array = []
var _book: VBoxContainer
var _hull_bar: ProgressBar
var _armor_bar: ProgressBar
var _sel_label: Label


func _init(p_ship: TestShip) -> void:
	ship = p_ship
	layer = 20   # above the HUD (blinds it), below dialogue/pause
	visible = false


func _ready() -> void:
	var black := ColorRect.new()
	black.color = Color(0.02, 0.02, 0.04, 1.0)   # near-total dark: you see nothing
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(black)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.98)
	style.border_color = Color(0.32, 0.4, 0.52)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(26.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(560, 0)
	panel.add_child(col)

	var title := Label.new()
	title.text = "◾  SYSTEMS OFFLINE — RUNNING DARK"
	title.add_theme_color_override("font_color", UiTheme.AMBER)
	title.add_theme_font_size_override("font_size", 21)
	col.add_child(title)

	var sub := Label.new()
	sub.text = "Engines drifting · shields down · sensors blind · signature low. Re-flash the Processor Bus below, then reboot."
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", UiTheme.DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)

	# Live integrity: the only feedback you get while blind — watch it drop.
	_hull_bar = _make_bar(col, "HULL", Color(0.55, 0.82, 0.56))
	_armor_bar = _make_bar(col, "ARMOR", Color(0.75, 0.7, 0.4))

	col.add_child(HSeparator.new())

	var bus_head := Label.new()
	bus_head.text = "PROCESSOR BUS — pick a slot, then an ability from the book"
	bus_head.add_theme_color_override("font_color", UiTheme.ACCENT)
	col.add_child(bus_head)

	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	col.add_child(slots)
	for i in 5:
		var b := Button.new()
		b.custom_minimum_size = Vector2(102, 44)
		b.pressed.connect(_on_slot.bind(i))
		slots.add_child(b)
		_slot_btns.append(b)

	_sel_label = Label.new()
	_sel_label.add_theme_font_size_override("font_size", 11)
	_sel_label.add_theme_color_override("font_color", UiTheme.DIM)
	col.add_child(_sel_label)

	var book_head := Label.new()
	book_head.text = "ABILITY LIBRARY — what your fitted modules know"
	book_head.add_theme_color_override("font_color", UiTheme.ACCENT)
	col.add_child(book_head)
	_book = VBoxContainer.new()
	_book.add_theme_constant_override("separation", 4)
	col.add_child(_book)

	var note := Label.new()
	note.text = "[K] or [Esc] — bring systems online (short reboot)."
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", UiTheme.DIM)
	col.add_child(note)


func _make_bar(parent: Node, label: String, fill: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(58, 0)
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(360, 16)
	bar.show_percentage = false
	bar.max_value = 1.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", sb)
	row.add_child(bar)
	return bar


func _toggle() -> void:
	if visible:
		_close()
	elif ship.can_go_dark():
		_open()
	else:
		ship._flash_note("Systems rebooting — can't go dark yet")


func _open() -> void:
	ship.enter_dark()
	visible = true
	add_to_group("esc_capture")
	_sel = -1
	Sfx.play("click", -6.0, 0.5)
	_refresh()


func _close() -> void:
	visible = false
	remove_from_group("esc_capture")
	ship.exit_dark()
	Sfx.play("click", -6.0, 1.2)


func _on_slot(i: int) -> void:
	_sel = i
	_refresh()


func _on_book_pick(id: String) -> void:
	if _sel < 0:
		ship._flash_note("Pick a Bus slot first")
		return
	Pilot.set_gem(_sel, id)
	Sfx.play("click", -8.0, 1.0)
	_refresh()


func _on_clear() -> void:
	if _sel < 0:
		return
	Pilot.clear_gem(_sel)
	Sfx.play("click", -12.0, 0.8)
	_refresh()


func _refresh() -> void:
	for i in _slot_btns.size():
		var b: Button = _slot_btns[i]
		var aid := Pilot.gem_at(i)
		b.text = "[%d]\n%s" % [i + 1, Abilities.display_name(aid) if aid != "" else "—"]
		UiTheme.button_flavor(b, "primary" if i == _sel else "tertiary")
	_sel_label.text = ("Slot [%d] selected — choose an ability, or clear it." % (_sel + 1)) \
		if _sel >= 0 else "No slot selected."

	for c in _book.get_children():
		c.queue_free()
	var known: Array = Abilities.known_for_build(ship.build)
	if known.is_empty():
		var none := Label.new()
		none.text = "No abilities known — fit a module (its ability joins the book)."
		none.add_theme_font_size_override("font_size", 11)
		none.add_theme_color_override("font_color", UiTheme.DIM)
		_book.add_child(none)
	for id in known:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_book.add_child(row)
		var pick := Button.new()
		pick.text = Abilities.display_name(str(id))
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.pressed.connect(_on_book_pick.bind(str(id)))
		row.add_child(pick)
	if _sel >= 0 and Pilot.gem_at(_sel) != "":
		var clr := Button.new()
		clr.text = "Clear slot [%d]" % (_sel + 1)
		UiTheme.button_flavor(clr, "tertiary")
		clr.pressed.connect(_on_clear)
		_book.add_child(clr)


func _process(_delta: float) -> void:
	if not visible or ship == null or ship.build == null:
		return
	var hp_max: float = maxf(1.0, float(ship.stats.hull_hp))
	var ar_max: float = maxf(1.0, float(ship.stats.armor_hp))
	_hull_bar.value = clampf(ship.hull / hp_max, 0.0, 1.0)
	_armor_bar.value = clampf(ship.armor / ar_max, 0.0, 1.0)
	# Blind-but-not-deaf: if the hull is dropping you're being shot — bail out.
	if ship.dead:
		_close()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_K and not ship.dead:
		_toggle()
	elif event.keycode == KEY_ESCAPE and visible:
		_close()
