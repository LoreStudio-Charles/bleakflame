class_name DialoguePanel
extends CanvasLayer
## The conversation UI: portrait, name and role, the NPC's line, choice
## buttons. Deliberately generic — feed it a node dict (Dialogues.*) and an
## action handler; it owns no story state. This same panel is the future
## engine for campaign talks (hermit, Krayt's comms) and the Cinderheart
## text mini-adventure; quests will get a "talk" stage kind that opens it.

signal closed

var npc_id: String
var nodes: Dictionary
var handler: Callable   # func(action: String) -> String (the NPC's reply)

var _text: RichTextLabel
var _choices: VBoxContainer
var vo_prefix := ""   # host sets this; nodes with no explicit `vo` play audio/vo/<prefix>_<nodekey>


func _init(p_npc: String, p_nodes: Dictionary, p_handler: Callable) -> void:
	npc_id = p_npc
	nodes = p_nodes
	handler = p_handler
	layer = 25


func _ready() -> void:
	# Owns Esc while open, so the pause menu defers to it.
	add_to_group("esc_capture")
	# Dim the world behind the conversation so mission-critical talk lands
	# front-and-center and can't be missed. Modal in attention, not in
	# control — the player dismisses freely and it's kept in the Comms inbox.
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	# Centered, not bottom-anchored: important comms belong in the middle of
	# the glass, not tucked at the edge.
	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -440
	panel.offset_right = 440
	panel.offset_top = -180
	panel.offset_bottom = 180
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.BG, 0.99)
	style.border_color = Color(0.4, 0.62, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var face_col := VBoxContainer.new()
	row.add_child(face_col)
	var portrait := Npcs.portrait(npc_id)
	if portrait != null:
		var face := TextureRect.new()
		face.texture = portrait
		face.custom_minimum_size = Vector2(192, 192)
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face_col.add_child(face)
	var who := Label.new()
	who.text = Npcs.display_name(npc_id)
	who.add_theme_color_override("font_color", UiTheme.AMBER)
	face_col.add_child(who)
	var role := Label.new()
	role.text = Npcs.role(npc_id)
	role.add_theme_font_size_override("font_size", 10)
	role.add_theme_color_override("font_color", Color(0.5, 0.55, 0.66))
	face_col.add_child(role)

	var talk_col := VBoxContainer.new()
	talk_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(talk_col)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	talk_col.add_child(_text)
	_choices = VBoxContainer.new()
	talk_col.add_child(_choices)

	show_node("start")


func show_node(id: String) -> void:
	if id == "end" or not nodes.has(id):
		close()
		return
	var node: Dictionary = nodes[id]
	_text.text = str(node.text)
	# Each node cuts the previous line and speaks its own `vo` (if any) — so
	# advancing a step never overlaps voices. Empty/absent `vo` = silence.
	var vo := str(node.get("vo", ""))
	if vo == "" and vo_prefix != "":
		vo = "%s_%s" % [vo_prefix, id]
	# `vo_once` nodes (e.g. an NPC's greeting) speak only the first time they're
	# shown per docking session, so re-reading the main message stays quiet.
	Sfx.play_voice(vo, -4.0, bool(node.get("vo_once", false)))
	_set_choices(node.choices)


func _set_choices(choices: Array) -> void:
	for child in _choices.get_children():
		child.queue_free()
	for c in choices:
		var b := Button.new()
		b.text = c.text
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # uniform width
		UiTheme.button_flavor(b, _choice_flavor(c))
		b.pressed.connect(_on_choice.bind(c))
		_choices.add_child(b)


## GOLD is never guessed from structure — it's a deliberate authorial hint that
## reads "this moment is important: a decision or an update is happening here."
## The engine only defaults the two neutral weights:
##   advancing / an authored `action` = SECONDARY (green — investigate, ask);
##   a closer ("Leave.", "Thank you, old man.") = TERTIARY (cyan — good manners,
##     backing out; NOTHING changes, so never gold).
## Anything that actually matters opts into gold with `"style": "primary"` right
## at that choice — briefings/debriefs (new work, completion), a real fork
## ("Accept the truce"), a reveal. That keeps gold meaning the same thing
## everywhere: pay attention, something is about to change.
func _choice_flavor(c: Dictionary) -> String:
	if c.has("style"):
		return str(c.style)
	if str(c.get("next", "")) == "end":
		return "tertiary"
	return "secondary"


func _on_choice(c: Dictionary) -> void:
	Sfx.play("click", -16.0)
	if c.has("action"):
		# The host answers; the reply becomes an ad-hoc node. Cut any line
		# still playing — the host may start its own (e.g. an overheard VO).
		Sfx.stop_voice()
		var reply: String = handler.call(str(c.action))
		_text.text = reply
		_set_choices([{"text": "Anything else?", "next": "start"},
			{"text": "Leave.", "next": "end"}])
	else:
		show_node(str(c.get("next", "end")))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		close()


func close() -> void:
	Sfx.stop_voice()   # never let a line bleed past the conversation
	closed.emit()
	queue_free()
