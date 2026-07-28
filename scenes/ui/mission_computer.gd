class_name MissionComputer
extends VBoxContainer
## THE MISSION COMPUTER — the first screen built to docs/person_as_context.md.
##
## It used to be THREE COLUMNS: contracts on offer | contracts in hand | quest log.
## A tester asked "where do I turn this in?" and the honest answer was: in the middle
## column, floating free of the contract it acts on, in a column that was otherwise
## 90% empty AND redundant — the same contract was listed again in the quest log
## beside it. The third column existed because it duplicated the second, and the
## action got buried on the redundant copy.
##
## Now: THREE ZONES, TWO COLUMNS.
##   header = YOU              credits, hold, and how many jobs close RIGHT HERE
##   left   = what is here     ONE list: your work, then what is on offer
##   right  = what is selected, with the action sitting ON the thing it acts on
##
## The quest log is not a third column: every live objective — campaign beat, side
## contract, expedition lead — is one row of the same list in MissionTracker order,
## so the thing you read and the thing you act on are the same object, and the
## tracker's curation (★ show on HUD, ▲▼ order) sits in the detail panel with it.
## HISTORY (finished work + the ship's log) is the same two columns in a different
## MODE — never a second list on screen beside the first.
##
## UI ONLY. Accepting and closing out are the HOST'S business (they move the wallet,
## faction standing and the campaign hand-off): this emits and re-reads. That is why
## a refused turn-in still reports through the host's one shared path.

signal accept_offer(index: int)          ## global MissionLog.offers index
signal turn_in_requested(index: int)     ## MissionLog.active index

const ROW_CHARS := 46      # short titles left, full text right (rule 4)

var ship: TestShip
var is_station: bool

## The host mounts the venue's NPC desk here — the person is the header of their
## own screen, not another box competing with the work.
var header_left: HBoxContainer
## Public so the host can register it as the "offers" tutor anchor: a lesson can
## name one ROW of it by text, so this has to be the real list.
var list: ItemList

var _you: RichTextLabel
var _detail: VBoxContainer
var _mode := "work"        # "work" | "log"
var _mode_btns := {}
var _sel := ""             # stable id of the selected row, kept across refreshes


func _init(p_ship: TestShip, p_is_station: bool) -> void:
	ship = p_ship
	is_station = p_is_station
	add_theme_constant_override("separation", 12)

	# ---- ZONE 1: YOU ------------------------------------------------------
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	add_child(head)
	header_left = HBoxContainer.new()
	header_left.add_theme_constant_override("separation", 12)
	head.add_child(header_left)
	_you = RichTextLabel.new()
	_you.bbcode_enabled = true
	_you.fit_content = true
	_you.scroll_active = false
	_you.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_you.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_you)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	add_child(body)

	# ---- ZONE 2: WHAT IS HERE ---------------------------------------------
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	body.add_child(left)

	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 6)
	left.add_child(modes)
	var group := ButtonGroup.new()
	for pair in [["work", "WORK"], ["log", "HISTORY"]]:
		var b := Button.new()
		b.text = str(pair[1])
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(110, 0)
		b.pressed.connect(_set_mode.bind(str(pair[0])))
		modes.add_child(b)
		_mode_btns[str(pair[0])] = b

	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(280, 160)
	list.fixed_icon_size = Vector2i(30, 30)
	list.icon_mode = ItemList.ICON_MODE_LEFT
	list.item_selected.connect(_on_row)
	left.add_child(list)

	# ---- ZONE 3: WHAT IS SELECTED -----------------------------------------
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 1.25
	frame.add_theme_stylebox_override("panel",
		UiTheme._box(UiTheme.PANEL, Color(0.2, 0.24, 0.32)))
	body.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	scroll.add_child(_detail)


func refresh() -> void:
	for m in _mode_btns:
		(_mode_btns[m] as Button).button_pressed = m == _mode
	_refresh_you()
	_rebuild_list()
	_rebuild_detail()


func _set_mode(mode: String) -> void:
	if _mode == mode:
		return
	_mode = mode
	_sel = ""
	Sfx.play("click", -16.0)
	refresh()


# ---- zone 1 ---------------------------------------------------------------

## The header answers the tester's question before they have clicked anything:
## how many jobs can be closed AT THIS DESK. Everything else here is what a
## contract costs you to carry — credits and hold.
func _refresh_you() -> void:
	var closeable := 0
	for m in MissionLog.active:
		if MissionLog.is_complete(m, ship) and MissionLog.venue_ok(m, is_station):
			closeable += 1
	var ready := "[color=#%s]nothing to hand in here[/color]" % UiTheme.DIM.to_html(false)
	if closeable > 0:
		ready = "[b][color=#%s]%d %s to close here[/color][/b]" % [
			UiTheme.AMBER.to_html(false), closeable,
			"job" if closeable == 1 else "jobs"]
	_you.text = "[right]%s     [color=#%s]credits[/color] %dc     [color=#%s]hold[/color] %.0f/%.0f[/right]" % [
		ready, UiTheme.DIM.to_html(false), Wallet.credits, UiTheme.DIM.to_html(false),
		ship.cargo_used(), float(ship.stats.get("cargo", 0.0))]


# ---- zone 2: the one list -------------------------------------------------

func _rebuild_list() -> void:
	list.clear()
	if _mode == "work":
		_fill_work()
	else:
		_fill_history()
	_restore_selection()


func _fill_work() -> void:
	var rich := _rich_entries()
	var tracked: Array = MissionTracker.trackables(ship)
	var spines: Array = Quests.dormant_spines()
	_section("YOUR WORK")
	if tracked.is_empty() and spines.is_empty():
		_empty("— nothing in hand — take something from the board —")
	var current_key := ""
	for t in tracked:
		if not t.hidden:
			current_key = str(t.key)
			break
	for t in tracked:
		_track_row(t, rich, str(t.key) == current_key)
	for s in spines:
		var i := list.add_item("   %s %s" % [
			QuestLogView.GLYPH.get("saga", "◆"), _short(str(s.title))])
		list.set_item_custom_fg_color(i, UiTheme.DIM)
		list.set_item_metadata(i, {"id": str(s.id), "kind": "entry", "entry": s})

	_section("ON OFFER HERE")
	var offers := MissionLog.offers_for(is_station)
	if offers.is_empty():
		_empty("— the board is bare — check back after a run —")
	for e in offers:
		var m: Dictionary = e.m
		var i := list.add_item("   %s   %dc" % [_short(str(m.get("desc", "Contract"))),
			int(m.get("reward", 0))])
		_face(i, str(m.get("giver", "")))
		list.set_item_metadata(i, {"id": "o:%s" % str(m.get("desc", "")),
			"kind": "offer", "index": int(e.index), "m": m})


## One objective row. A contract that can be CLOSED HERE wears a ✓ and goes amber
## — the same signal the header counts, at the row you have to click.
func _track_row(t: Dictionary, rich: Dictionary, is_current: bool) -> void:
	var key := str(t.key)
	var kind := str(t.kind)
	var txt := "%s %s" % [str(QuestLogView.GLYPH.get(kind, "•")), _short(str(t.label))]
	if t.has("count"):
		var c: Vector2i = t.count
		txt += "   %d/%d" % [c.x, c.y]
	var tint: Color = QuestLogView.TINT.get(kind, UiTheme.TEXT)
	var closeable := false
	var ci := _contract_index(key)
	if ci >= 0:
		var m: Dictionary = MissionLog.active[ci]
		closeable = MissionLog.is_complete(m, ship) and MissionLog.venue_ok(m, is_station)
	if closeable:
		txt = "✓ " + txt
		tint = UiTheme.AMBER
	else:
		txt = ("▶ " if is_current else "   ") + txt
	var i := list.add_item(txt)
	list.set_item_custom_fg_color(i, tint if not t.hidden else tint.darkened(0.35))
	var giver_id := ""
	if ci >= 0:
		giver_id = str(MissionLog.active[ci].get("giver", ""))
	elif rich.has(key):
		giver_id = str((rich[key] as Dictionary).get("giver_id", ""))
	_face(i, giver_id)
	var md := {"id": key, "kind": "contract" if ci >= 0 else "entry", "key": key,
		"track": t}
	if rich.has(key):
		md["entry"] = rich[key]
	list.set_item_metadata(i, md)


## Finished work, then the ship's log. Same two columns, different mode — the log
## is never a third list sitting beside the one you are working in.
func _fill_history() -> void:
	_section("COMPLETED")
	var done: Array = Quests.completed_entries() + Research.completed_entries()
	if done.is_empty():
		_empty("— no finished business yet —")
	for e in done:
		var i := list.add_item("   %s" % _short(str(e.title)))
		list.set_item_custom_fg_color(i, Color(0.55, 0.75, 0.6))
		_face(i, str(e.get("giver_id", "")))
		list.set_item_metadata(i, {"id": "c:%s" % str(e.id), "kind": "entry", "entry": e})

	_section("SHIP'S LOG")
	if Research.journal.is_empty():
		_empty("— no entries yet — the Reach keeps its stories close —")
	for j in range(Research.journal.size() - 1, -1, -1):
		var entry: Dictionary = Research.journal[j]
		var i := list.add_item("   %s  %s" % [GameClock.label(int(entry.day)),
			_short(str(entry.text), ROW_CHARS - 10)])
		list.set_item_custom_fg_color(i, UiTheme.DIM)
		list.set_item_metadata(i, {"id": "j:%d" % j, "kind": "journal", "entry": entry})


func _section(title: String) -> void:
	var i := list.add_item("—— %s ——" % title)
	list.set_item_disabled(i, true)
	list.set_item_selectable(i, false)
	list.set_item_custom_fg_color(i, UiTheme.ACCENT)


func _empty(text: String) -> void:
	var i := list.add_item("   %s" % text)
	list.set_item_disabled(i, true)
	list.set_item_selectable(i, false)
	list.set_item_custom_fg_color(i, Color(0.38, 0.41, 0.5))


func _face(row: int, npc: String) -> void:
	if npc == "":
		return
	var art := Npcs.portrait(npc)
	if art != null:
		list.set_item_icon(row, art)


## Keep the player on the row they were reading across a refresh; failing that,
## open on the first real row so the detail panel is never blank while there IS
## something to read.
func _restore_selection() -> void:
	var want := _sel
	_sel = ""
	for i in list.item_count:
		var md = list.get_item_metadata(i)
		if md is Dictionary and str((md as Dictionary).get("id", "")) == want:
			list.select(i)
			_sel = want
			return
	for i in list.item_count:
		if not list.is_item_selectable(i):
			continue
		list.select(i)
		_sel = str((list.get_item_metadata(i) as Dictionary).get("id", ""))
		return


func _on_row(index: int) -> void:
	var md = list.get_item_metadata(index)
	_sel = str((md as Dictionary).get("id", "")) if md is Dictionary else ""
	Sfx.play("click", -18.0, 1.1)
	_rebuild_detail()


func _selected_meta() -> Dictionary:
	for i in list.item_count:
		var md = list.get_item_metadata(i)
		if md is Dictionary and str((md as Dictionary).get("id", "")) == _sel:
			return md
	return {}


# ---- zone 3: the selected thing, with its action --------------------------

func _rebuild_detail() -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	var md := _selected_meta()
	if md.is_empty():
		var lbl := Label.new()
		lbl.text = "Select something on the left."
		lbl.add_theme_color_override("font_color", UiTheme.DIM)
		_detail.add_child(lbl)
		return
	match str(md.get("kind", "")):
		"offer": _detail_offer(md)
		"contract": _detail_contract(md)
		"journal": _detail_journal(md)
		_: _detail_entry(md.get("entry", {}), str(md.get("key", "")))


func _detail_offer(md: Dictionary) -> void:
	var m: Dictionary = md.m
	_title(str(m.get("desc", "Contract")), UiTheme.TEXT)
	_who(str(m.get("giver", "")), "OFFERED HERE")
	_note("%s work. Closes at %s." % [str(m.get("type", "")).capitalize(),
		venue_word(str(m.get("turn_in", "station")))])
	_stat("Pays", "%dc" % int(m.get("reward", 0)))
	var full := MissionLog.active.size() >= MissionLog.MAX_ACTIVE
	var b := Button.new()
	b.text = "Accept contract"
	b.disabled = full
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UiTheme.button_flavor(b, "primary")
	b.pressed.connect(func() -> void:
		Sfx.play("click", -16.0)
		accept_offer.emit(_offer_index(md)))
	_detail.add_child(b)
	if full:
		_reason("Your log is full — %d of %d contracts in hand. Close one first." % [
			MissionLog.active.size(), MissionLog.MAX_ACTIVE])


## The contract you are HOLDING — and the one screen in the game where the turn-in
## button belongs, sitting under the contract it closes rather than floating in a
## column of its own.
func _detail_contract(md: Dictionary) -> void:
	var i := _contract_index(str(md.key))
	if i < 0:
		_note("That contract is no longer in hand.")
		return
	var m: Dictionary = MissionLog.active[i]
	_title(str(m.get("desc", "Contract")), UiTheme.TEXT)
	_who(str(m.get("giver", "")), "IN HAND · %s" % str(m.get("type", "")).to_upper())
	var have := MissionLog.progress(m, ship)
	var need := int(m.get("n", 1))
	_stat("Progress", "%d of %d" % [have, need])
	_stat("Reward", "%dc" % int(m.get("reward", 0)))
	_stat("Closes at", venue_word(str(m.get("turn_in", "station"))))

	var done := MissionLog.is_complete(m, ship)
	var here := MissionLog.venue_ok(m, is_station)
	var b := Button.new()
	b.text = "Turn in — %dc" % int(m.get("reward", 0))
	b.disabled = not (done and here)
	# SHRINK, not fill: a gold bar spanning the whole panel reads as a banner rather
	# than a button, and the eye wants it directly under the numbers it acts on.
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UiTheme.button_flavor(b, "primary")
	b.pressed.connect(func() -> void:
		Sfx.play("click", -16.0)
		turn_in_requested.emit(_contract_index(str(md.key))))
	_detail.add_child(b)
	# A DEAD BUTTON MUST SAY WHY (project convention: every rejection is visible).
	# It used to be greyed with nothing beside it, which is how a player ends up
	# asking where the turn-in is while looking straight at it. The reason states
	# the CONSEQUENCE and lets the stat block above state the fact — saying "closes
	# at the colony" twice in one panel is the redundancy this screen exists to end.
	if not done:
		_reason("Not finished yet — %d of %d." % [have, need])
	elif not here:
		_reason("Finished — but not at this desk.")
	_curation(str(md.key))


func _detail_entry(e: Dictionary, key: String) -> void:
	if e.is_empty():
		_note("Nothing more is known about this yet.")
		if key != "":
			_curation(key)
		return
	_title(str(e.get("title", "")), UiTheme.AMBER)
	_who(str(e.get("giver_id", "")), str(e.get("giver", "")).to_upper())
	if str(e.get("body", "")) != "":
		_note(str(e.body), true)
	for s in e.get("done", []):
		var step := Label.new()
		step.text = "   ✓ %s" % str(s)
		step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		step.add_theme_color_override("font_color", Color(0.53, 0.56, 0.63))
		_detail.add_child(step)
	if not bool(e.get("done_quest", false)) and str(e.get("current", "")) != "":
		var cur := Label.new()
		cur.text = "▶ %s" % str(e.current)
		cur.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cur.add_theme_color_override("font_color", UiTheme.ACCENT)
		_detail.add_child(cur)
	if str(e.get("rewards", "")) != "":
		_stat("Reward", str(e.rewards))
	if key != "":
		_curation(key)


func _detail_journal(md: Dictionary) -> void:
	var e: Dictionary = md.entry
	_title(GameClock.label(int(e.day)), UiTheme.AMBER)
	_note(str(e.text))


## Tracker curation, ON the objective it curates (the old separate panel is why
## these controls were ever a screen of their own).
func _curation(key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_detail.add_child(row)
	var hidden := MissionTracker.is_hidden(key)
	var star := Button.new()
	star.text = "☆ Hidden from HUD" if hidden else "★ Shown on HUD"
	star.tooltip_text = "Show this objective in the flight HUD tracker" if hidden \
		else "Hide it from the flight HUD (it stays in the log)"
	star.pressed.connect(func() -> void:
		MissionTracker.toggle(key)
		Sfx.play("click", -16.0)
		refresh())
	row.add_child(star)
	for pair in [["▲", -1], ["▼", 1]]:
		var b := Button.new()
		b.text = str(pair[0])
		b.custom_minimum_size = Vector2(34, 0)
		b.tooltip_text = "Order your objectives — the top one drives the waypoint"
		b.pressed.connect(func() -> void:
			MissionTracker.move(key, int(pair[1]))
			Sfx.play("click", -16.0)
			refresh())
		row.add_child(b)


# ---- detail widgets -------------------------------------------------------

func _title(text: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", col)
	_detail.add_child(lbl)


func _who(npc: String, role: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_detail.add_child(row)
	var art := Npcs.portrait(npc)
	if art != null:
		var face := TextureRect.new()
		face.texture = art
		face.custom_minimum_size = Vector2(72, 72)
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(face)
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_txt := Npcs.display_name(npc) if npc != "" else ""
	lbl.text = "[color=#%s]%s[/color]\n[color=#%s]%s[/color]" % [
		UiTheme.AMBER.to_html(false), name_txt, UiTheme.DIM.to_html(false), role]
	row.add_child(lbl)


func _note(text: String, italic := false) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := "[i]%s[/i]" % text if italic else text
	lbl.text = "[color=#%s]%s[/color]" % [Color(0.66, 0.69, 0.76).to_html(false), body]
	_detail.add_child(lbl)


func _stat(key: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_detail.add_child(row)
	var k := Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(90, 0)
	k.add_theme_color_override("font_color", UiTheme.DIM)
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.add_theme_color_override("font_color", UiTheme.TEXT)
	row.add_child(v)


func _reason(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.63, 0.29))
	_detail.add_child(lbl)


# ---- helpers --------------------------------------------------------------

## SHORT TITLES LEFT, FULL TEXT RIGHT. Shrinking the font to fit a whole contract
## description in a column is how the middle column got unreadable; the detail
## panel has room for the sentence.
static func _short(text: String, n := ROW_CHARS) -> String:
	if text.length() <= n:
		return text
	var cut := text.substr(0, n)
	var sp := cut.rfind(" ")
	if sp > int(n * 0.6):
		cut = cut.substr(0, sp)
	return cut + "…"


## Where a contract closes, in words a pilot uses. The raw venue keys are data.
static func venue_word(v: String) -> String:
	match v:
		"station": return "the station"
		"planet": return "the colony"
		"verge": return "The Dig"
		"shoal": return "the Rust Shoal"
		"either": return "either desk"
	return v


## Index into MissionLog.active for a tracker key, or -1 if it isn't a contract.
func _contract_index(key: String) -> int:
	if not key.begins_with("m:"):
		return -1
	var uid := int(key.substr(2))
	for i in MissionLog.active.size():
		if MissionLog.uid_of(MissionLog.active[i]) == uid:
			return i
	return -1


## The GLOBAL offers index for a row, re-derived at click time: the board restocks
## on every accept and turn-in, so a stale index would take the wrong contract.
func _offer_index(md: Dictionary) -> int:
	var m: Dictionary = md.m
	var i := int(md.get("index", -1))
	if i >= 0 and i < MissionLog.offers.size() and MissionLog.offers[i] == m:
		return i
	return MissionLog.offers.find(m)


## Campaign and expedition entries keyed by tracker key — the authored text behind
## an objective row (contracts have none; they get their own detail).
func _rich_entries() -> Dictionary:
	var rich := {}
	for e in Quests.log_entries(ship):
		rich["q:" + str(e.id)] = e
	for e in Research.log_entries(ship):
		rich["r:" + str(e.id)] = e
	return rich
