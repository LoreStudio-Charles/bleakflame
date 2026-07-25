class_name SalvagePanel
extends CanvasLayer
## In-space salvage & cargo management ([H], or right-clicking a cluster of
## overlapping loot). Left: everything drifting within reach — click to pull
## it aboard. Right: your hold — click to jettison and make room. Lets the
## player compare floating loot against what they're carrying and choose.

const REACH := 650.0   # loot this near the ship is listed / grabbable

var ship: TestShip
var _open := false
var _panel: PanelContainer
var _salvage_box: VBoxContainer
var _hold: InventoryGrid
var _header: Label
var _refresh_t := 0.0
var _hold_sig := "<never-built>"   # sentinel: never equals a real signature, so the first pass builds


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
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	col.add_child(header_row)
	_header = Label.new()
	_header.add_theme_color_override("font_color", UiTheme.AMBER)
	_header.add_theme_font_size_override("font_size", 15)
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(_header)
	var all_btn := Button.new()
	all_btn.text = "Salvage All"
	all_btn.pressed.connect(_salvage_all)
	header_row.add_child(all_btn)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	_salvage_box = _side(row, "NEARBY SALVAGE — click to pull aboard")
	# RIGHT-CLICK ONLY (user's call, 2026-07-25). Jettisoning is DESTRUCTIVE, and this
	# panel is open mid-fight — a single left-click throwing cargo into the void was one
	# stray click from losing a hold of ore. Right-click is now the one interact verb
	# everywhere, so this both unifies the idiom and makes the dangerous move deliberate.
	_hold = InventoryGrid.new(ship)
	_hold.title = "SHIP HOLD — right-click to jettison"
	_hold.columns = 4
	_hold.item_hint = func(_c) -> String: return "RIGHT-CLICK to jettison"
	_hold.material_hint = func(_k) -> String: return "RIGHT-CLICK to jettison"
	_hold.on_item = func(c, _s: String) -> void: ship.jettison_component(c)
	_hold.on_material = func(k: String, _s: String) -> void: ship.jettison_commodity(k)
	row.add_child(_hold)
	# Explainer footer (user, 2026-07-24): make the click-to-move idiom obvious.
	var footer := Label.new()
	footer.text = "Click an item on the LEFT to pull it aboard   ·   RIGHT-CLICK one on the RIGHT to jettison it and make room"
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", UiTheme.ACCENT)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(footer)


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
	if event.keycode == Keys.HOLD and not ship.dead and ship.docked_at == null:
		Tutor.did("salvage_opened")   # they opened the salvage panel themselves
		if _open:
			close()
		else:
			open()
	elif event.keycode == Keys.MENU and _open:
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
	_header.text = "SALVAGE & CARGO        HOLD %d / %.0f        [H] close" % [
		int(ship.cargo_used()), ship.stats.cargo]
	for child in _salvage_box.get_children():
		_salvage_box.remove_child(child)
		child.queue_free()   # remove first: queue_free is deferred (see inventory_grid)

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

	# The hold is the SHARED InventoryGrid (see inventory_grid.gd) with JETTISON bound to
	# the one interact verb — same tiles, same grade borders and pips as the shop counter
	# and the dossier, so your cargo reads identically everywhere.
	#
	# REBUILT ONLY WHEN IT CHANGES (playtest, 2026-07-25: "mouse doesn't highlight items in
	# the hold, it flickers, and there's no tooltip"). Nearby salvage drifts, so the LEFT
	# column has to stay live on a timer — but rebuilding on that same tick destroyed and
	# recreated every hold tile underneath the cursor. Godot needs an unbroken ~0.5s hover
	# on ONE control before a tooltip appears, so a tile replaced every 0.35s can never
	# show one, and its hover styling was thrown away just as the eye caught it.
	_hold.ship = ship
	var sig := _hold_signature()
	if sig != _hold_sig:
		_hold_sig = sig
		_hold.refresh()


## What the hold contains, as a comparable string: the parts (with their affix rolls, so
## two different rolls of the same base are distinct) plus every commodity count.
func _hold_signature() -> String:
	var parts: Array[String] = []
	var carried = ship.get("cargo")
	if carried != null:
		for c in carried:
			parts.append("%s|%s" % [c.base_path if c.base_path != "" else c.resource_path,
				",".join(PackedStringArray(c.affix_ids))])
	for key in ship.commodities:
		parts.append("%s=%d" % [key, int(ship.commodities[key])])
	return "/".join(parts)


func _grab(loot) -> void:
	ship.grab_loot(loot)
	_rebuild()


## Salvage All: pull everything in reach aboard, nearest first, until the hold is
## full (grab_loot flashes the hold-full warning if it fills). One press, whole field.
func _salvage_all() -> void:
	var loot: Array = []
	for n in get_tree().get_nodes_in_group("loot"):
		if is_instance_valid(n) and ship.global_position.distance_to(n.global_position) <= REACH:
			loot.append(n)
	loot.sort_custom(func(a, b) -> bool:
		return ship.global_position.distance_squared_to(a.global_position) \
			< ship.global_position.distance_squared_to(b.global_position))
	for l in loot:
		if not ship.grab_loot(l):
			break   # hold full — grab_loot already warned
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
