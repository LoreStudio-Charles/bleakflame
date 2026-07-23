class_name SalvagePanel
extends CanvasLayer
## In-space salvage & cargo management ([B], or right-clicking a cluster of
## overlapping loot). Left: everything drifting within reach — click to pull
## it aboard. Right: your hold — click to jettison and make room. Lets the
## player compare floating loot against what they're carrying and choose.

const REACH := 650.0   # loot this near the ship is listed / grabbable

var ship: TestShip
var _open := false
var _panel: PanelContainer
var _salvage_box: VBoxContainer
var _hold_box: VBoxContainer
var _header: Label
var _refresh_t := 0.0


func _init(p_ship: TestShip) -> void:
	ship = p_ship
	layer = 11


func _ready() -> void:
	add_to_group("salvage_panel")
	_panel = PanelContainer.new()
	_panel.theme = UiTheme.get_theme()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -440
	_panel.offset_right = 440
	_panel.offset_top = -260
	_panel.offset_bottom = 260
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.BG, 0.98)
	style.border_color = Color(0.4, 0.62, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18.0)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.visible = false
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	_header = Label.new()
	_header.add_theme_color_override("font_color", UiTheme.AMBER)
	_header.add_theme_font_size_override("font_size", 15)
	col.add_child(_header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	_salvage_box = _side(row, "NEARBY SALVAGE — click to pull aboard")
	_hold_box = _side(row, "SHIP HOLD — click to jettison")


func _side(parent: Node, title: String) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 4)
	parent.add_child(c)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", UiTheme.ACCENT)
	c.add_child(lbl)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 3)
	scroll.add_child(box)
	return box


func open() -> void:
	if _open:
		return
	_open = true
	_panel.visible = true
	add_to_group("esc_capture")
	Sfx.play("click", -10.0, 1.2)
	_rebuild()


func close() -> void:
	_open = false
	_panel.visible = false
	remove_from_group("esc_capture")
	Sfx.play("click", -10.0, 0.9)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_B and not ship.dead and ship.docked_at == null:
		Tutor.note("cargo_gauge")   # they opened the salvage panel themselves
		if _open:
			close()
		else:
			open()
	elif event.keycode == KEY_ESCAPE and _open:
		close()


func _process(delta: float) -> void:
	if not _open:
		return
	# Loot drifts and the hold changes as you grab — keep the lists live.
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.35
		_rebuild()


func _rebuild() -> void:
	_header.text = "SALVAGE & CARGO        HOLD %d / %.0f        [B] close" % [
		int(ship.cargo_used()), ship.stats.cargo]
	for child in _salvage_box.get_children():
		child.queue_free()
	for child in _hold_box.get_children():
		child.queue_free()

	# Nearby salvage, nearest first.
	var loot: Array = []
	for n in get_tree().get_nodes_in_group("loot"):
		if is_instance_valid(n) and ship.global_position.distance_to(n.global_position) <= REACH:
			loot.append(n)
	loot.sort_custom(func(a, b) -> bool:
		return ship.global_position.distance_squared_to(a.global_position) \
			< ship.global_position.distance_squared_to(b.global_position))
	for l in loot:
		var fits := ship.can_carry_mass(l.payload_mass())
		var color := Grades.color(l.def.grade) if l.def != null else Color(0.9, 0.82, 0.6)
		var b := _row(_salvage_box, "%s  (mass %.0f)%s" % [
			l.payload_name(), l.payload_mass(), "" if fits else "   — HOLD FULL"],
			color if fits else Color(0.55, 0.4, 0.4))
		b.pressed.connect(_grab.bind(l))
	if _salvage_box.get_child_count() == 0:
		_note(_salvage_box, "— nothing in reach —")

	# The hold: components then commodities, each jettisonable.
	for comp in ship.cargo:
		var b := _row(_hold_box, "%s  Mk%d %s  (mass %.0f)" % [
			comp.display_name, comp.mark, Grades.display_name(comp.grade), comp.mass],
			Grades.color(comp.grade))
		b.pressed.connect(func() -> void: ship.jettison_component(comp))
	for key in ship.commodities:
		var qty: int = ship.commodities[key]
		var b := _row(_hold_box, "%s x%d  (mass %.0f ea)" % [
			TradeGoods.display_name(key), qty, TradeGoods.unit_mass(key)],
			Color(0.9, 0.82, 0.6))
		b.pressed.connect(func() -> void: ship.jettison_commodity(key))
	if _hold_box.get_child_count() == 0:
		_note(_hold_box, "— hold empty —")


func _grab(loot) -> void:
	ship.grab_loot(loot)
	_rebuild()


func _row(parent: Node, text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_color_override("font_color", color)
	parent.add_child(b)
	return b


func _note(parent: Node, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.38, 0.41, 0.5))
	parent.add_child(lbl)
