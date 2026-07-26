class_name QuestLogView
extends ScrollContainer
## The expandable quest log, shared by the dock Missions tab and the [L] flight
## overlay. In ACTIVE mode it IS the objective tracker (user, 2026-07-23): every
## live objective — campaign quest, side contract, expedition lead — is one entry,
## in the player's tracker order, and the title row carries the curation controls
## right where you read it: ★ (show on HUD) / ☆ (hidden), ▲▼ to reorder (top = the
## CURRENT objective, ▶, that drives the waypoint), and a kind tint. Click the title
## to expand into quest text, completed steps, the current step and rewards. The
## COMPLETED tab stays a plain read-only history.

## In lockstep with FlightHud.KIND_COLOR — the same layer reads the same colour in the
## corner and in the log, or the vocabulary teaches nothing.
const TINT := {
	"saga": UiTheme.AMBER, "campaign": Color("b98ce0"), "arc": Color("7aa7f0"),
	"mission": Color("76d18c"), "contract": UiTheme.TEXT, "lead": UiTheme.ACCENT,
}
const GLYPH := {"saga": "◆", "campaign": "◈", "arc": "▲", "mission": "★",
	"lead": "◇", "contract": "•"}

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
	var entries: Array = _active_entries() if mode == "active" \
		else Quests.completed_entries() + Research.completed_entries()
	if entries.is_empty():
		var lbl := Label.new()
		lbl.text = "— nothing here yet —" if mode == "completed" \
			else "— no active objectives — work finds pilots at the station —"
		lbl.add_theme_color_override("font_color", Color(0.38, 0.41, 0.5))
		_box.add_child(lbl)
		if mode == "active":
			var tip := Label.new()
			tip.text = "★ show on HUD   ·   ▲▼ order (top is current)"
			tip.add_theme_font_size_override("font_size", 11)
			tip.add_theme_color_override("font_color", Color(0.4, 0.44, 0.54))
			_box.add_child(tip)
	for e in entries:
		_add_entry(e)


## Every live objective, resolved to a rich entry, in the tracker's order — with
## its tracker `key`/`kind`/`hidden` and which one is the current (top-shown) one.
func _active_entries() -> Array:
	var rich := {}
	for e in Quests.log_entries(ship):
		rich["q:" + str(e.id)] = e
	for e in Research.log_entries(ship):
		rich["r:" + str(e.id)] = e
	var tracked: Array = MissionTracker.trackables(ship)
	var current_key := ""
	for t in tracked:
		if not t.hidden:
			current_key = str(t.key)
			break
	var out: Array = []
	for t in tracked:
		var key := str(t.key)
		var e: Dictionary = (rich[key] as Dictionary).duplicate() if rich.has(key) \
			else _contract_entry(key, t)
		e["key"] = key
		e["kind"] = str(t.kind)
		e["hidden"] = bool(t.hidden)
		e["is_current"] = key == current_key
		out.append(e)
	return out


## A compact log entry for a side contract (which has no authored quest text).
func _contract_entry(key: String, t: Dictionary) -> Dictionary:
	var uid := int(key.substr(2))
	for m in MissionLog.active:
		if MissionLog.uid_of(m) == uid:
			var giver := str(m.get("giver", ""))
			return {"id": key, "title": str(m.get("desc", "Contract")),
				"giver": Npcs.display_name(giver) if giver != "" else "Contract Board",
				"giver_id": giver,
				"body": "%s contract — turn in at %s." % [
					str(m.get("type", "")).capitalize(), str(m.get("turn_in", "station"))],
				"done": [], "current": str(t.get("detail", "")),
				"rewards": "%dc" % int(m.get("reward", 0)), "done_quest": false}
	return {"id": key, "title": str(t.get("label", "Contract")), "giver": "", "giver_id": "",
		"body": "", "done": [], "current": str(t.get("detail", "")), "rewards": "", "done_quest": false}


func _add_entry(e: Dictionary) -> void:
	var open: bool = _expanded.get(e.id, false)
	var kind := str(e.get("kind", ""))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 3)
	_box.add_child(header)

	# Curation controls live on the title row (active tracker entries only).
	if mode == "active" and e.has("key"):
		var key := str(e.key)
		var star := Button.new()
		star.text = "★" if not e.hidden else "☆"
		star.tooltip_text = "Hide from the HUD" if not e.hidden else "Show on the HUD"
		star.custom_minimum_size = Vector2(30, 0)
		star.pressed.connect(func() -> void:
			MissionTracker.toggle(key)
			rebuild())
		header.add_child(star)
		var up := Button.new()
		up.text = "▲"
		up.custom_minimum_size = Vector2(28, 0)
		up.pressed.connect(func() -> void:
			MissionTracker.move(key, -1)
			rebuild())
		header.add_child(up)
		var down := Button.new()
		down.text = "▼"
		down.custom_minimum_size = Vector2(28, 0)
		down.pressed.connect(func() -> void:
			MissionTracker.move(key, 1)
			rebuild())
		header.add_child(down)

	var title := Button.new()
	var mark := "▶ " if e.get("is_current", false) else ""
	var glyph := (str(GLYPH.get(kind, "")) + " ") if kind != "" else ""
	title.text = "%s  %s%s%s  —  %s" % ["▾" if open else "▸", mark, glyph, e.title, e.giver]
	title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if kind != "":
		title.add_theme_color_override("font_color", TINT.get(kind, UiTheme.TEXT))
	title.pressed.connect(func() -> void:
		_expanded[e.id] = not open
		rebuild())
	if e.done_quest:
		title.modulate = Color(1, 1, 1, 0.75)
	elif e.get("hidden", false):
		title.modulate = Color(1, 1, 1, 0.55)   # dimmed while off the HUD
	header.add_child(title)
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
