class_name QuestLogView
extends ScrollContainer
## The expandable quest log, shared by the dock Missions tab and the [L]
## flight overlay. One entry per quest/expedition: click the title to expand
## into quest text, a fold of completed steps (what you've done, for when
## you're lost), the highlighted current step, and the rewards. `mode`
## picks active vs completed-history content; entries come from
## Quests.log_entries/Research.log_entries in a unified shape.

var ship: TestShip
var mode := "active"   # "active" | "completed"
var _expanded := {}    # entry id -> bool
var _steps_open := {}  # entry id -> bool
var _box: VBoxContainer


func _init(p_ship: TestShip, p_mode: String) -> void:
	ship = p_ship
	mode = p_mode
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 4)
	add_child(_box)


func rebuild() -> void:
	for child in _box.get_children():
		child.queue_free()
	var entries: Array = []
	if mode == "active":
		entries = Quests.log_entries(ship) + Research.log_entries(ship)
	else:
		entries = Quests.completed_entries() + Research.completed_entries()
	if entries.is_empty():
		var lbl := Label.new()
		lbl.text = "— nothing here yet —" if mode == "completed" \
			else "— no active quests — work finds pilots at the station —"
		lbl.add_theme_color_override("font_color", Color(0.38, 0.41, 0.5))
		_box.add_child(lbl)
	for e in entries:
		_add_entry(e)


func _add_entry(e: Dictionary) -> void:
	var open: bool = _expanded.get(e.id, false)
	var title := Button.new()
	title.text = "%s  %s  —  %s" % ["▾" if open else "▸", e.title, e.giver]
	title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.pressed.connect(func() -> void:
		_expanded[e.id] = not open
		rebuild())
	if e.done_quest:
		title.modulate = Color(1, 1, 1, 0.75)
	_box.add_child(title)
	if not open:
		return

	# Expanded card: portrait (when the art exists) beside the quest text.
	var body_row := HBoxContainer.new()
	body_row.add_theme_constant_override("separation", 10)
	_box.add_child(body_row)
	var portrait := Npcs.portrait(str(e.get("giver_id", "")))
	if portrait != null:
		var face := TextureRect.new()
		face.texture = portrait
		face.custom_minimum_size = Vector2(96, 96)
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		body_row.add_child(face)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.text = "[i][color=#a8b0c2]%s[/color][/i]" % e.body
	body_row.add_child(body)

	var done: Array = e.done
	if not done.is_empty():
		var fold_open: bool = _steps_open.get(e.id, false)
		var fold := Button.new()
		fold.text = "%s  completed steps (%d)" % ["▾" if fold_open else "▸", done.size()]
		fold.alignment = HORIZONTAL_ALIGNMENT_LEFT
		fold.modulate = Color(1, 1, 1, 0.65)
		fold.pressed.connect(func() -> void:
			_steps_open[e.id] = not fold_open
			rebuild())
		_box.add_child(fold)
		if fold_open:
			for s in done:
				var step := RichTextLabel.new()
				step.bbcode_enabled = true
				step.fit_content = true
				step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				step.text = "[color=#8890a0]   ✓ %s[/color]" % s
				_box.add_child(step)

	if not e.done_quest and str(e.current) != "":
		var current := RichTextLabel.new()
		current.bbcode_enabled = true
		current.fit_content = true
		current.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		current.text = "[color=#73bff2]▶ %s[/color]" % e.current
		_box.add_child(current)

	if str(e.rewards) != "":
		var reward := Label.new()
		reward.text = "Reward: %s" % e.rewards
		reward.add_theme_color_override("font_color", UiTheme.AMBER)
		_box.add_child(reward)
