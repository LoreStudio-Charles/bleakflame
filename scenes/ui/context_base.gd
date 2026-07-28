class_name ContextBase
extends VBoxContainer
## ONE CONTEXT: something here, the selected thing, its action (docs/person_as_context.md).
##
##   header = YOU        who you are and what you have, on the right
##   left   = WHAT'S HERE  filled by the subclass — a list, or a grid
##   right  = the selected thing, with its action ON it
##
## A CONTEXT COMES IN TWO PRESENTATIONS (user, 2026-07-27): a LIST for things that are
## sentences (contracts, campaign beats, research projects — you read them) and a GRID
## for things that are objects (equipment, hulls, commodities — you look at them and
## compare them at a glance). "Every shop is a grid. Anything you read is a list."
##
## THIS IS WHAT THE TWO SHARE, and it was extracted only once both existed — the same
## rule that produced ContextScreen in the first place. `ContextScreen` is the list;
## `ContextGrid` is the grid; neither owns anything the other needs.
##
## THE ACTION HELPER IS THE POINT. `action(text, blocked, on_press)` takes the reason it
## cannot be taken as an ARGUMENT, so greying a button and saying why are the same call —
## a screen cannot do one without the other. Two screens shipped that bug within a day of
## each other, and both times the assertion that should have caught it was satisfied by a
## nearby stat line instead. Making it one call is worth more than remembering twice.
##
## Subclasses override `header_text`, `fill_list` and `render_detail`, and fill `left`
## with their own presentation. The base owns the shape; the screen owns the words.

const ROW_CHARS := 46      # short titles left, full text right

var header_left: HBoxContainer     ## hosts mount the venue's NPC desk here
var left: VBoxContainer            ## the subclass's presentation goes here
var _detail: VBoxContainer
var _you: RichTextLabel
var _sel := ""                     ## stable id of the selection, kept across refreshes
var _mode := ""
var _mode_btns := {}
var _modes_row: HBoxContainer


func _init() -> void:
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

	left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	_modes_row = HBoxContainer.new()
	_modes_row.add_theme_constant_override("separation", 6)
	_modes_row.visible = false     # only screens that call set_modes() get a switcher
	left.add_child(_modes_row)

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


## ---- what a subclass fills in ----

## BBCode for the header's right-hand side: what YOU have, here.
func header_text() -> String:
	return ""


## Fill whatever this context lists — rows, or tiles. The current `_mode` (if the screen
## declared any) says which one to build.
func fill_list() -> void:
	pass


## Draw `md` — the selected thing's metadata — into the detail panel with the widgets
## below, ending in an action() when there is something to do to it.
func render_detail(_md: Dictionary) -> void:
	pass


## ---- what a PRESENTATION fills in (ContextScreen / ContextGrid) ----

func _clear_items() -> void:
	pass


## Keep the player on what they were looking at; failing that, open on the first real
## thing, so the detail panel is never blank while there IS something to read.
func _restore_selection() -> void:
	pass


func selected_meta() -> Dictionary:
	return {}


## ---- the one call a host makes ----

func refresh() -> void:
	for m in _mode_btns:
		(_mode_btns[m] as Button).button_pressed = m == _mode
	_you.text = header_text()
	_clear_items()
	fill_list()
	_restore_selection()
	_rebuild_detail()


## Optional mode switcher: [[id, LABEL], ...]. A second LIST beside the first is
## forbidden, so a screen with more than one thing to show switches between them.
func set_modes(pairs: Array) -> void:
	_modes_row.visible = true
	var group := ButtonGroup.new()
	for pair in pairs:
		var b := Button.new()
		b.text = str((pair as Array)[1])
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(110, 0)
		var id := str((pair as Array)[0])
		b.pressed.connect(_set_mode.bind(id))
		_modes_row.add_child(b)
		_mode_btns[id] = b
		if _mode == "":
			_mode = id


func _set_mode(mode: String) -> void:
	if _mode == mode:
		return
	_mode = mode
	_sel = ""
	Sfx.play("click", -16.0)
	refresh()


## Anything a screen wants ON the mode bar beside the switcher — the Armory's slot-type
## filters and level range. Same row on purpose: what you are looking at and how it is
## narrowed are one decision, and a second bar under the first is a third zone.
func mode_bar() -> HBoxContainer:
	_modes_row.visible = true
	return _modes_row


func _rebuild_detail() -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	var md := selected_meta()
	if md.is_empty():
		var lbl := Label.new()
		lbl.text = "Select something on the left."
		lbl.add_theme_color_override("font_color", UiTheme.DIM)
		_detail.add_child(lbl)
		return
	render_detail(md)


## ---- detail widgets ----

## THE ACTION, on the thing it acts on. `blocked` is why it cannot be taken right now
## — "" means live. Greying and explaining are ONE CALL on purpose: a dead control
## with no reason beside it is the defect this whole screen shape exists to end, and
## two screens shipped one before this helper existed.
func action(text: String, blocked: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = blocked != ""
	# SHRINK, not fill: a gold bar spanning the panel reads as a banner, not a button.
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UiTheme.button_flavor(b, "primary")
	b.pressed.connect(func() -> void:
		Sfx.play("click", -16.0)
		on_press.call())
	_detail.add_child(b)
	if blocked != "":
		reason(blocked)
	return b


## A SECOND action on the same thing — sell beside buy, unfit beside fit. Same rule:
## the reason it is dead travels with it.
func alt_action(text: String, blocked: String, on_press: Callable) -> Button:
	var b := action(text, blocked, on_press)
	UiTheme.button_flavor(b, "secondary")
	return b


func title(text: String, col := UiTheme.TEXT) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", col)
	_detail.add_child(lbl)


func who(npc: String, role: String) -> void:
	var row_box := HBoxContainer.new()
	row_box.add_theme_constant_override("separation", 10)
	_detail.add_child(row_box)
	var art := Npcs.portrait(npc)
	if art != null:
		var face := TextureRect.new()
		face.texture = art
		face.custom_minimum_size = Vector2(72, 72)
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row_box.add_child(face)
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text = "[color=#%s]%s[/color]\n[color=#%s]%s[/color]" % [
		UiTheme.AMBER.to_html(false), Npcs.display_name(npc) if npc != "" else "",
		UiTheme.DIM.to_html(false), role]
	row_box.add_child(lbl)


func note(text: String, italic := false) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := "[i]%s[/i]" % text if italic else text
	lbl.text = "[color=#%s]%s[/color]" % [Color(0.66, 0.69, 0.76).to_html(false), body]
	_detail.add_child(lbl)


func stat(key: String, value: String) -> void:
	var row_box := HBoxContainer.new()
	row_box.add_theme_constant_override("separation", 10)
	_detail.add_child(row_box)
	var k := Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(90, 0)
	k.add_theme_color_override("font_color", UiTheme.DIM)
	row_box.add_child(k)
	var v := Label.new()
	v.text = value
	v.add_theme_color_override("font_color", UiTheme.TEXT)
	row_box.add_child(v)


## An obstacle, in its own words. Keep it distinct from anything the stat block says
## — a reason that only repeats a stat cannot be told apart from one, by a player OR
## by a test (both of the first screen's reason assertions passed with the line deleted,
## because they matched the stat block instead).
func reason(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.63, 0.29))
	_detail.add_child(lbl)


func step_line(text: String, done := false) -> void:
	var lbl := Label.new()
	lbl.text = "   ✓ %s" % text if done else "▶ %s" % text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color",
		Color(0.53, 0.56, 0.63) if done else UiTheme.ACCENT)
	_detail.add_child(lbl)


## Anything a screen needs in the detail panel that these widgets do not cover — the
## Armory's affix lines, a paperdoll preview. Handed the panel rather than reimplementing
## it, so the shape stays the base's.
func detail_box() -> VBoxContainer:
	return _detail


## Tracker curation, ON the objective it curates. `with_order` adds the ▲▼ that
## decide which objective drives the waypoint; a lead shown alongside contracts wants
## them, a lead read on its own page does not.
func curation(key: String, with_order := true) -> void:
	if key == "":
		return
	var row_box := HBoxContainer.new()
	row_box.add_theme_constant_override("separation", 6)
	_detail.add_child(row_box)
	var hidden := MissionTracker.is_hidden(key)
	var star := Button.new()
	star.text = "☆ Hidden from HUD" if hidden else "★ Shown on HUD"
	star.tooltip_text = "Show this objective in the flight HUD tracker" if hidden \
		else "Hide it from the flight HUD (it stays in the log)"
	star.pressed.connect(func() -> void:
		MissionTracker.toggle(key)
		Sfx.play("click", -16.0)
		refresh())
	row_box.add_child(star)
	if not with_order:
		return
	for pair in [["▲", -1], ["▼", 1]]:
		var b := Button.new()
		b.text = str(pair[0])
		b.custom_minimum_size = Vector2(34, 0)
		b.tooltip_text = "Order your objectives — the top one drives the waypoint"
		b.pressed.connect(func() -> void:
			MissionTracker.move(key, int(pair[1]))
			Sfx.play("click", -16.0)
			refresh())
		row_box.add_child(b)


## SHORT TITLES LEFT, FULL TEXT RIGHT. Shrinking the font to fit a whole description
## into a column is what made the old middle column unreadable; the detail panel has
## room for the sentence.
static func short(text: String, n := ROW_CHARS) -> String:
	if text.length() <= n:
		return text
	var cut := text.substr(0, n)
	var sp := cut.rfind(" ")
	if sp > int(n * 0.6):
		cut = cut.substr(0, sp)
	return cut + "…"
