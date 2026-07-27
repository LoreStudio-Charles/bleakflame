class_name CaptainsLog
extends CanvasLayer
## The quest log in flight, toggled with [L] — the same three views as the
## dock Missions tab: Active (expandable quests + expeditions), Completed
## (history you can re-read), Chronicle (the day-stamped story stream).

var ship: TestShip
var _active_view: QuestLogView
var _done_view: QuestLogView
var _chronicle: RichTextLabel


func _init(p_ship: TestShip) -> void:
	ship = p_ship
	layer = 11
	visible = false


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 200
	panel.offset_top = 80
	panel.offset_right = -200
	panel.offset_bottom = -80
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.BG, 0.96)
	style.border_color = Color(0.32, 0.5, 0.66)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var col := VBoxContainer.new()
	panel.add_child(col)
	var header := Label.new()
	header.text = "QUEST LOG        [L] close"
	header.add_theme_color_override("font_color", UiTheme.AMBER)
	header.add_theme_font_size_override("font_size", 15)
	col.add_child(header)
	# Curation lives ON the Active-tab entries now (★ / ▲▼ / tint) — no separate panel.
	var subtabs := TabContainer.new()
	subtabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(subtabs)
	_active_view = QuestLogView.new(ship, "active")
	_active_view.name = "Active"
	subtabs.add_child(_active_view)
	_done_view = QuestLogView.new(ship, "completed")
	_done_view.name = "Completed"
	subtabs.add_child(_done_view)
	_chronicle = RichTextLabel.new()
	_chronicle.name = "Chronicle"
	_chronicle.bbcode_enabled = true
	_chronicle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	subtabs.add_child(_chronicle)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	# GROUNDED COUNTS AS FLYING for the log (playtest: can't open it on a planet).
	# Walking the colony means the ship is DOCKED to the planetoid, so the old
	# `docked_at == null` test locked the quest log exactly where the quests are.
	if event.keycode == Keys.LOG and not ship.dead \
			and (ship.docked_at == null or ship.docked_at is Planetoid):
		visible = not visible
		if visible:
			Tutor.did("log_opened")   # they found the log themselves
			_refresh()
		_esc_capture(visible)
		Sfx.play("click", -10.0, 1.3 if visible else 0.9)
	elif event.keycode == Keys.MENU and visible:
		visible = false
		_esc_capture(false)
		Sfx.play("click", -10.0, 0.9)


func _esc_capture(on: bool) -> void:
	if on:
		add_to_group("esc_capture")
	else:
		remove_from_group("esc_capture")


func _refresh() -> void:
	_active_view.rebuild()
	_done_view.rebuild()
	var txt := "[color=#8890a0]%s — %s[/color]\n\n" % [GameClock.label(), GameClock.cadence_text()]
	if Research.journal.is_empty():
		txt += "[color=#8890a0]No entries yet. The Reach keeps its stories close.[/color]"
	for i in range(Research.journal.size() - 1, -1, -1):
		var entry: Dictionary = Research.journal[i]
		txt += "[color=#f2b859]%s[/color]  —  %s\n" % [GameClock.label(int(entry.day)), entry.text]
	_chronicle.text = txt
