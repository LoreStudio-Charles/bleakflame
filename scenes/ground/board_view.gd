class_name BoardView
extends CanvasLayer
## The colony CONTRACT BOARD — the ground's job board, opened by walking up to it (or to
## the person who posts the work) instead of a dock tab.
##
## Second slice of moving planetside services onto ground-native views (the first was
## ShopView; see the shop for the why). Same contract as that one:
##
## DELIBERATELY THIN. Every rule — what's posted here, whether you may take it, whether
## it's finished, the payment, the giver's guild standing, the campaign hand-off — lives
## in MissionLog.take/complete, the SAME calls the station's tabbed board makes. This
## file draws and dispatches; it owns no rules, so the two boards cannot drift apart.
##
## Self-contained: builds its own UI, owns Esc while open (group "esc_capture"), frees
## itself on close. The host instances it and connects `closed`.

signal closed

## Venue NAME, not a bool — outposts (The Dig, and whatever the capital grows) take
## turn-ins too, and MissionLog speaks venue names.
var venue := "planet"
var npc_id: String                  # whose board this is (portrait + name), "" for a kiosk
var ship

var _offers: VBoxContainer
var _held: VBoxContainer
var _note: Label
var _note_t := 0.0
var _picked := -1                   # global offers index of the selected posting


func _init(p_npc: String, p_venue: String, p_ship) -> void:
	npc_id = p_npc
	venue = p_venue
	ship = p_ship
	layer = 26


func _ready() -> void:
	add_to_group("esc_capture")
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -470
	panel.offset_right = 470
	panel.offset_top = -290
	panel.offset_bottom = 290
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.BG, 0.99)
	style.border_color = UiTheme.AMBER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	root.add_child(head)
	if npc_id != "":
		var portrait := Npcs.portrait(npc_id)
		if portrait != null:
			var face := TextureRect.new()
			face.texture = portrait
			face.custom_minimum_size = Vector2(64, 64)
			face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			head.add_child(face)
	var titles := VBoxContainer.new()
	head.add_child(titles)
	var who := Label.new()
	who.text = "COLONY CONTRACT BOARD" if npc_id == "" \
		else "%s — posting work" % Npcs.display_name(npc_id)
	who.add_theme_font_size_override("font_size", 17)
	who.add_theme_color_override("font_color", UiTheme.AMBER)
	titles.add_child(who)
	var sub := Label.new()
	sub.text = "Work posted here may turn in elsewhere — each posting says where it ends."
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", UiTheme.ACCENT)
	titles.add_child(sub)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	_offers = _column(cols, "ON OFFER")
	_held = _column(cols, "IN HAND")

	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 12)
	_note.visible = false
	root.add_child(_note)

	var leave := Button.new()
	leave.text = "Step away from the board   [Esc]"
	UiTheme.button_flavor(leave, "tertiary")
	leave.pressed.connect(close)
	root.add_child(leave)

	refresh()


func _column(parent: Node, title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(col)
	var head := Label.new()
	head.text = title
	head.add_theme_color_override("font_color", UiTheme.AMBER)
	col.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box


func refresh() -> void:
	# remove_child BEFORE queue_free (deferred), so a same-frame refresh can't stack rows.
	for c in _offers.get_children():
		_offers.remove_child(c)
		c.queue_free()
	for c in _held.get_children():
		_held.remove_child(c)
		c.queue_free()

	# ON OFFER — what's posted at THIS venue (optionally this person's own board).
	var posted := MissionLog.offers_at(venue, str(BOARDS.get(npc_id, "")))
	if posted.is_empty():
		_empty(_offers, "— nothing posted right now —")
	for entry in posted:
		_offer_row(entry)

	# IN HAND — every active contract, with a Turn in button that lights only where it
	# can actually be closed (MissionLog decides; the button just reflects it).
	if MissionLog.active.is_empty():
		_empty(_held, "— no contracts in hand —")
	for i in MissionLog.active.size():
		_held_row(i, MissionLog.active[i])


## A person's own board id, when they keep one (mirrors the dock's PERSON_BOARDS).
const BOARDS := {"sella": "sella"}


func _empty(parent: Node, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.5, 0.55, 0.62))
	parent.add_child(l)


func _offer_row(entry: Dictionary) -> void:
	var m: Dictionary = entry["m"]          # offers_at returns {"m": mission, "index": global}
	var idx: int = int(entry["index"])
	var row := VBoxContainer.new()
	_offers.add_child(row)
	var b := Button.new()
	b.text = "%s  —  %dc" % [MissionLog.label(m), int(m.reward)]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.button_flavor(b, "primary" if idx == _picked else "secondary")
	b.pressed.connect(_on_pick.bind(idx))
	row.add_child(b)
	# The selected posting expands into its terms + the commitment.
	if idx == _picked:
		var terms := Label.new()
		terms.text = "  %s\n  Turns in: %s" % [_terms(m),
			str(m.get("turn_in", "planet" if m.type == "delivery" else "station"))]
		terms.add_theme_font_size_override("font_size", 11)
		terms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(terms)
		var take := Button.new()
		take.text = "Take this contract"
		UiTheme.button_flavor(take, "primary")
		take.pressed.connect(_on_take.bind(idx))
		row.add_child(take)


func _terms(m: Dictionary) -> String:
	match str(m.type):
		"bounty":
			return "Clear %d hostiles." % int(m.n)
		"recovery":
			return "Recover %d crates of stolen goods." % int(m.n)
		"delivery":
			return "Deliver %d × %s." % [int(m.n), TradeGoods.display_name(str(m.good))]
	return ""


func _held_row(index: int, m: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_held.add_child(row)
	var lbl := Label.new()
	lbl.text = "%s  [%d/%d]" % [MissionLog.label(m), MissionLog.progress(m, ship), int(m.n)]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)
	var b := Button.new()
	b.text = "Turn in"
	b.disabled = not (MissionLog.is_complete(m, ship) and MissionLog.venue_ok_at(m, venue))
	UiTheme.button_flavor(b, "primary")
	b.pressed.connect(_on_turn_in.bind(index))
	row.add_child(b)


func _on_pick(index: int) -> void:
	Sfx.play("click", -16.0)
	_picked = -1 if index == _picked else index
	refresh()


func _on_take(index: int) -> void:
	var r := MissionLog.take(index)
	if r.ok:
		Tutor.did("accepted_contract")   # they took the work themselves
		_picked = -1
	_report(r)


func _on_turn_in(index: int) -> void:
	# The SAME completion path the station board uses: payment, the giver's guild
	# standing, and the campaign hand-off — nothing re-implemented here.
	var r := MissionLog.complete(index, ship, venue, SaveGame.tutorial_done)
	if r.ok:
		Tutor.did("turned_in")
		Tutor.retire("turn_in")
		Sfx.play("jingle", -8.0)
	_report(r)


## Every rejection is VISIBLE (project convention) — the shared call already says why.
func _report(r: Dictionary) -> void:
	_note.text = str(r.get("msg", ""))
	_note.add_theme_color_override("font_color",
		Color(0.42, 0.86, 0.46) if bool(r.get("ok", false)) else UiTheme.DANGER)
	_note.visible = true
	_note_t = 2.6
	refresh()


func _process(delta: float) -> void:
	if _note_t > 0.0:
		_note_t -= delta
		if _note_t <= 0.0:
			_note.visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		close()


func close() -> void:
	closed.emit()
	queue_free()
