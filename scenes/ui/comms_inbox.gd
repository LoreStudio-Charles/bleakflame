class_name CommsInbox
extends CanvasLayer
## The mailbox: a persistent badge shows the unread comm count, and [C] opens
## the inbox to re-read any message an NPC ever sent. Dismissing a comm never
## loses it — it lands here. Modeled on the [M] map / [L] log overlays.

var ship: TestShip
var _badge: Label
var _panel: PanelContainer
var _list: ItemList
var _reader: RichTextLabel
var _face: TextureRect
var _open := false


func _init(p_ship: TestShip) -> void:
	ship = p_ship
	layer = 11


func _ready() -> void:
	# Always-visible mailbox badge, upper-right.
	_badge = Label.new()
	_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_badge.offset_left = -220
	_badge.offset_right = -16
	_badge.offset_top = 12
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_badge.add_theme_font_size_override("font_size", 14)
	add_child(_badge)
	# The BADGE is what the lesson points at — it's the unread counter AND it
	# carries the [C] hint, so the ping lands on the thing being explained.
	Tutor.register("comms_badge", _badge)
	var ping := TutorPing.new()
	ping.anchor = "comms_badge"
	add_child(ping)

	_panel = PanelContainer.new()
	_panel.theme = UiTheme.get_theme()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -460
	_panel.offset_right = 460
	_panel.offset_top = -280
	_panel.offset_bottom = 280
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
	var header := Label.new()
	header.text = "COMMS — MESSAGE ARCHIVE        [C] close"
	header.add_theme_color_override("font_color", UiTheme.AMBER)
	header.add_theme_font_size_override("font_size", 15)
	col.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(300, 0)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_selected)
	row.add_child(_list)
	var read_col := VBoxContainer.new()
	read_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	read_col.add_theme_constant_override("separation", 8)
	row.add_child(read_col)
	_face = TextureRect.new()
	_face.custom_minimum_size = Vector2(128, 128)
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	read_col.add_child(_face)
	_reader = RichTextLabel.new()
	_reader.bbcode_enabled = true
	_reader.size_flags_vertical = Control.SIZE_EXPAND_FILL
	read_col.add_child(_reader)


func _process(_delta: float) -> void:
	var _t0 := Telemetry.now_us()
	_tick_p(_delta)
	Telemetry.phase("p.comms_inbox", _t0)


func _tick_p(_delta: float) -> void:
	var n := Comms.unread()
	if n > 0:
		_badge.text = "✉ %d NEW   [C]" % n
		_badge.add_theme_color_override("font_color", UiTheme.AMBER)
	elif not Comms.messages.is_empty():
		_badge.text = "✉ %d   [C]" % Comms.messages.size()
		_badge.add_theme_color_override("font_color", Color(0.45, 0.5, 0.62))
	else:
		_badge.text = ""


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == Keys.COMMS and not ship.dead and ship.docked_at == null:
		Tutor.did("comms_opened")   # they opened the archive themselves
		_toggle()
	elif event.keycode == Keys.MENU and _open:
		_toggle()


func _toggle() -> void:
	_open = not _open
	_panel.visible = _open
	if _open:
		add_to_group("esc_capture")   # own Esc so the pause menu waits
	else:
		remove_from_group("esc_capture")
	Sfx.play("click", -10.0, 1.2 if _open else 0.9)
	if _open:
		_rebuild()


func _rebuild() -> void:
	_list.clear()
	# Newest first.
	for i in range(Comms.messages.size() - 1, -1, -1):
		var m: Dictionary = Comms.messages[i]
		var mark := "● " if not m.read else "   "
		var idx := _list.add_item("%s%s — %s" % [mark, m.name, m.title])
		_list.set_item_metadata(idx, i)
		if not m.read:
			_list.set_item_custom_fg_color(idx, UiTheme.AMBER)
	if Comms.messages.is_empty():
		_reader.text = "[color=#8890a0]No transmissions yet.[/color]"
		_face.texture = null
	else:
		_list.select(0)
		_on_selected(0)


func _on_selected(list_index: int) -> void:
	var i: int = _list.get_item_metadata(list_index)
	var m: Dictionary = Comms.messages[i]
	Comms.mark_read(i)
	_face.texture = Npcs.portrait(str(m.from))
	_reader.text = "[b][color=#f2b859]%s[/color][/b]  [color=#8890a0]— %s[/color]\n%s\n\n%s" % [
		m.name, Npcs.role(str(m.from)), m.title, m.body]
	# Refresh the unread dot on this row without losing the selection.
	_list.set_item_text(list_index, "   %s — %s" % [m.name, m.title])
	_list.set_item_custom_fg_color(list_index, UiTheme.TEXT)
