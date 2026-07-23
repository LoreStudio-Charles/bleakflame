class_name NpcDesk
extends PanelContainer
## THE ONE PLACE AN NPC STANDS on a dock tab (user, 2026-07-23: "a single NPC tab
## object that controls the layout — every tab was almost identical").
##
## Portrait thumb + name/role, an ALWAYS-VISIBLE "Talk to X" button, and a NEWS
## HIGHLIGHT (amber dot + a gold button + a lit border) that lights only when they
## are holding something for you. Every tab that hosts a face mounts one of these,
## so the talk affordance reads identically everywhere: the room does its own work
## above, the person always waits in the same spot below. When they have nothing
## queued the button still works — it opens a short idle exchange — so it is never
## a dead control.
##
## The host owns the MEANING (what "news" is, what the talk does, the office door);
## this owns the LOOK. Host wiring: connect `talk_pressed`, call `set_news()` each
## refresh, and drop the office door / hints into `extras`.

signal talk_pressed(npc: String)

const THUMB := 52

var npc: String
var _dot: Label
var _btn: Button
var _idle_note: Label
var extras: VBoxContainer          # office door + standing hints — host fills these

var _calm := UiTheme._box(UiTheme.PANEL, Color(0.2, 0.24, 0.32))
var _lit := UiTheme._box(UiTheme.PANEL.lightened(0.04), UiTheme.AMBER)


func _init(npc_id: String) -> void:
	npc = npc_id
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_theme_stylebox_override("panel", _calm)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)

	# --- Header: thumb · name/role · news dot -------------------------------
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)

	var face := Npcs.portrait(npc)
	if face != null:
		var thumb := TextureRect.new()
		thumb.texture = face
		thumb.custom_minimum_size = Vector2(THUMB, THUMB)
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(thumb)

	var who := RichTextLabel.new()
	who.bbcode_enabled = true
	who.fit_content = true
	who.scroll_active = false
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.custom_minimum_size = Vector2(150, 0)
	who.text = "[b][color=#f2b859]%s[/color][/b]\n[color=#8890a0]%s[/color]" % [
		Npcs.display_name(npc), Npcs.role(npc)]
	head.add_child(who)

	_dot = Label.new()
	_dot.text = "●"
	_dot.add_theme_color_override("font_color", UiTheme.AMBER)
	_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dot.visible = false
	head.add_child(_dot)

	# --- The talk button (always here) --------------------------------------
	_btn = Button.new()
	_btn.text = "Talk to %s" % Npcs.display_name(npc)
	_btn.pressed.connect(func() -> void: talk_pressed.emit(npc))
	col.add_child(_btn)

	_idle_note = Label.new()
	_idle_note.add_theme_font_size_override("font_size", 11)
	_idle_note.add_theme_color_override("font_color", UiTheme.DIM)
	_idle_note.visible = false
	col.add_child(_idle_note)

	extras = VBoxContainer.new()
	extras.add_theme_constant_override("separation", 4)
	col.add_child(extras)

	set_news(false)


## The one call the host makes each refresh. `has_news` lights the dot, the gold
## button and the lit border; otherwise the button is a quiet tertiary invite and
## a small caption says there's nothing pressing (but you can still say hello).
func set_news(has_news: bool, subtitle := "") -> void:
	_dot.visible = has_news
	add_theme_stylebox_override("panel", _lit if has_news else _calm)
	UiTheme.button_flavor(_btn, "primary" if has_news else "tertiary")
	if has_news:
		_idle_note.visible = false
	else:
		_idle_note.text = subtitle if subtitle != "" else "Nothing pressing right now."
		_idle_note.visible = true


## Clear the office door / hints before the host re-adds them.
func clear_extras() -> void:
	for c in extras.get_children():
		c.queue_free()
