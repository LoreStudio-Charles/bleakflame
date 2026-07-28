class_name ResearchLabView
extends VBoxContainer
## THE RESEARCH LAB — Dex's room, second screen built to docs/person_as_context.md.
##
## It was the Mission Computer's bug with different nouns: two ItemLists side by side
## (collection + leads | tech trees) and TWO detached buttons under them, "Research
## selected" and "Trade in all Scan Data" — an action floating under a column instead
## of sitting on the thing it acts on. Selecting a lead opened a whole MODAL to show
## one paragraph, because there was nowhere on the screen for a paragraph to live.
##
## Now: header = your Insight and what is earning it; left = ONE list (your
## collection, your leads, then each tech tree); right = the selected thing with its
## action on it.
##
## THE SCAN DATA ARCHIVE IS A ROW, not a button. Filing readings is an action on the
## readings, so they are a thing you can select and read about — which is also the
## only place the cargo-to-Insight loop was ever explained.
##
## WHY A PROJECT IS OUT OF REACH IS STATED BEFORE THE CLICK: `Research.blocker()` is
## the query behind `Research.unlock()`, so the sentence under a greyed button is the
## one a refused click would have produced.
##
## UI ONLY. Spending Insight and archiving cargo are the HOST'S business.

signal research_requested(id: String)
signal archive_requested()

const ROW_CHARS := 46

var ship: TestShip
var header_left: HBoxContainer
var list: ItemList

var _you: RichTextLabel
var _detail: VBoxContainer
var _sel := ""


func _init(p_ship: TestShip) -> void:
	ship = p_ship
	add_theme_constant_override("separation", 12)

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

	list = ItemList.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(280, 160)
	list.item_selected.connect(_on_row)
	body.add_child(list)

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
	_refresh_you()
	_rebuild_list()
	_rebuild_detail()


func _refresh_you() -> void:
	var income := Research.income_per_day()
	var earning := "[color=#%s]nothing is earning yet[/color]" % UiTheme.DIM.to_html(false)
	if income > 0.0:
		earning = "[color=#%s]collection earns[/color] +%.2f / day" % [
			UiTheme.DIM.to_html(false), income]
	_you.text = "[right][b][color=#%s]INSIGHT %d[/color][/b]     %s     [color=#%s]%s — %s[/color][/right]" % [
		UiTheme.AMBER.to_html(false), int(Research.insight), earning,
		UiTheme.DIM.to_html(false), GameClock.label(), GameClock.cadence_text()]


# ---- the one list ---------------------------------------------------------

func _rebuild_list() -> void:
	list.clear()

	_section("YOUR COLLECTION")
	if Research.recovered.is_empty():
		_empty("— nothing recovered yet — artifacts are found, never bought —")
	for id in Research.recovered:
		var art: Dictionary = Research.ARTIFACTS[id]
		var i := list.add_item("   ✦ %s" % _short(str(art.name)))
		list.set_item_custom_fg_color(i, UiTheme.AMBER)
		list.set_item_metadata(i, {"id": "a:" + str(id), "kind": "artifact", "art": art})

	# The archive: a THING, so its action has something to sit on.
	var aboard := int(ship.commodities.get("scan_data", 0))
	var arch := list.add_item("   ▤ Scan Data archive   %d aboard" % aboard)
	list.set_item_custom_fg_color(arch, UiTheme.ACCENT if aboard > 0 else UiTheme.DIM)
	list.set_item_metadata(arch, {"id": "archive", "kind": "archive"})

	_section("EXPEDITION LEADS")
	var leads: Array = Research.log_entries(ship)
	if leads.is_empty():
		_empty("— no leads — rumours travel on dockhands' lips —")
	for e in leads:
		var i := list.add_item("   ◈ %s" % _short(str(e.title)))
		list.set_item_custom_fg_color(i, UiTheme.ACCENT)
		list.set_item_metadata(i, {"id": "r:" + str(e.id), "kind": "lead", "entry": e,
			"key": MissionTracker.lead_key(str(e.id))})

	for tree in Research.TREES:
		_section(str(tree.name).to_upper())
		for node in tree.nodes:
			var researched := Research.is_unlocked(str(node.id))
			var txt := "   ✓ %s" % _short(str(node.name)) if researched \
				else "   %s   %d Insight" % [_short(str(node.name)), int(node.cost)]
			var i := list.add_item(txt)
			if researched:
				list.set_item_custom_fg_color(i, Color(0.45, 0.75, 0.5))
			elif Research.blocker(str(node.id)) != "":
				list.set_item_custom_fg_color(i, UiTheme.DIM)
			else:
				list.set_item_custom_fg_color(i, UiTheme.AMBER)   # affordable RIGHT NOW
			list.set_item_metadata(i, {"id": "t:" + str(node.id), "kind": "node",
				"node": node, "tree": str(tree.name)})
	_restore_selection()


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


# ---- the selected thing ---------------------------------------------------

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
		"artifact": _detail_artifact(md.art)
		"archive": _detail_archive()
		"lead": _detail_lead(md)
		"node": _detail_node(md)


func _detail_artifact(art: Dictionary) -> void:
	_title("✦ %s" % str(art.name), UiTheme.AMBER)
	_note(str(art.desc), true)
	_stat("Yields", "1 Insight every %s, forever" % _rate_text(int(art.rate_days)))
	_note("Installed in the lab. Nothing to do — it simply pays, every day you dock.")


## Scan Data: the cargo-to-Insight loop, with the trade-in ON the readings. Empty is
## the teaching state, not an error — the row says what would happen if you had some.
func _detail_archive() -> void:
	var aboard := int(ship.commodities.get("scan_data", 0))
	_title("Scan Data archive", UiTheme.TEXT)
	_note("Readings filed with the lab. Dex pays in Insight; Cartographer Sella pays in credits for the same data — your call which you need more.", true)
	_stat("Aboard", "%d" % aboard)
	_stat("Rate", "+%d Insight each" % Research.SCAN_DATA_INSIGHT)
	var b := Button.new()
	b.text = "Archive %d — +%d Insight" % [aboard, aboard * Research.SCAN_DATA_INSIGHT]
	b.disabled = aboard <= 0
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UiTheme.button_flavor(b, "primary")
	b.pressed.connect(func() -> void:
		Sfx.play("click", -16.0)
		archive_requested.emit())
	_detail.add_child(b)
	if aboard <= 0:
		_reason("Nothing to file — survey something with a scanner fitted and [1].")


func _detail_lead(md: Dictionary) -> void:
	var e: Dictionary = md.entry
	_title("◈ %s" % str(e.title), UiTheme.ACCENT)
	_who(str(e.get("giver_id", "")), str(e.get("giver", "")).to_upper())
	if str(e.get("body", "")) != "":
		_note(str(e.body), true)
	for s in e.get("done", []):
		var step := Label.new()
		step.text = "   ✓ %s" % str(s)
		step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		step.add_theme_color_override("font_color", Color(0.53, 0.56, 0.63))
		_detail.add_child(step)
	if str(e.get("current", "")) != "":
		var cur := Label.new()
		cur.text = "▶ %s" % str(e.current)
		cur.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cur.add_theme_color_override("font_color", UiTheme.ACCENT)
		_detail.add_child(cur)
	if str(e.get("rewards", "")) != "":
		_stat("Reward", str(e.rewards))
	_note("Followed in flight — the chart marks the way, and this updates as you go.")
	_curation(str(md.get("key", "")))


func _detail_node(md: Dictionary) -> void:
	var node: Dictionary = md.node
	var id := str(node.id)
	var researched := Research.is_unlocked(id)
	_title(str(node.name), UiTheme.AMBER if not researched else Color(0.45, 0.75, 0.5))
	_note(str(node.desc), true)
	_stat("Tree", str(md.get("tree", "")))
	if researched:
		_stat("Status", "researched")
		return
	_stat("Cost", "%d Insight" % int(node.cost))
	if str(node.requires) != "":
		_stat("Requires", str(Research.find_node(str(node.requires)).get("name", node.requires)))
	var stop := Research.blocker(id)
	var b := Button.new()
	b.text = "Research — %d Insight" % int(node.cost)
	b.disabled = stop != ""
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UiTheme.button_flavor(b, "primary")
	b.pressed.connect(func() -> void:
		Sfx.play("click", -16.0)
		research_requested.emit(id))
	_detail.add_child(b)
	if stop != "":
		_reason(stop)


## Leads are tracker objectives (`r:<id>`) like any other, so they curate here too.
func _curation(key: String) -> void:
	if key == "":
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_detail.add_child(row)
	var hidden := MissionTracker.is_hidden(key)
	var star := Button.new()
	star.text = "☆ Hidden from HUD" if hidden else "★ Shown on HUD"
	star.pressed.connect(func() -> void:
		MissionTracker.toggle(key)
		Sfx.play("click", -16.0)
		refresh())
	row.add_child(star)


# ---- widgets --------------------------------------------------------------

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
	lbl.text = "[color=#%s]%s[/color]\n[color=#%s]%s[/color]" % [
		UiTheme.AMBER.to_html(false), Npcs.display_name(npc) if npc != "" else "",
		UiTheme.DIM.to_html(false), role]
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


static func _short(text: String, n := ROW_CHARS) -> String:
	if text.length() <= n:
		return text
	var cut := text.substr(0, n)
	var sp := cut.rfind(" ")
	if sp > int(n * 0.6):
		cut = cut.substr(0, sp)
	return cut + "…"


static func _rate_text(days: int) -> String:
	return "day" if days == 1 else "%d days" % days
