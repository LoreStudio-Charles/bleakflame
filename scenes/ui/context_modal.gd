class_name ContextModal
extends CanvasLayer
## A CONTEXT, OPENED FROM AN ADDRESSEE (docs/person_as_context.md rule 6).
##
## The doc's rule is that a context "returns to the addressee, not to the venue", so a
## visit chains — check the board, buy a chip, leave — without re-navigating. This is
## the object that makes that literal: it holds ONE single-purpose screen over the room
## it was opened from, and its only way out says whose room it is.
##
## WHY A MODAL RATHER THAN A TAB. A tab is a place you go; a context is a thing you
## asked someone for. At a bespoke venue there is no tab strip to go to at all, which is
## exactly why the Shoal's board and shelf were originally copied onto the screen beside
## the person — and that is the clutter person-as-context is undoing. It also means the
## same context works identically at a station tab, a pirate bar and a freighter's deck,
## because none of them has to own a place to put it.
##
## HOST OWNS THE CONTENT. This owns the frame: the shade, the panel, Esc, and the way
## back. Anything Control-shaped can go in it.

signal closed

const MARGIN := 40

var _content: Control
var _back_text: String


func _init(content: Control, back_to: String) -> void:
	_content = content
	# BACK TO A PERSON, NAMED. "Close" would be true and useless — the point of the
	# rule is that you land back in the conversation you left, and the button is where
	# the player finds that out.
	_back_text = "←  Back to %s" % back_to
	layer = 20


func _ready() -> void:
	# Owns Esc while open, so the pause menu defers to it (same contract as
	# DialoguePanel, the chart and the log).
	add_to_group("esc_capture")
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = MARGIN
	panel.offset_top = MARGIN
	panel.offset_right = -MARGIN
	panel.offset_bottom = -MARGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.BG, 0.99)
	style.border_color = Color(0.4, 0.62, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_content)
	if _content.has_method("refresh"):
		_content.call("refresh")

	# The way out sits at the bottom RIGHT, its own width — a Button parented straight
	# to a VBoxContainer stretches across the whole screen (the same trap that made
	# "Take the job" a 1900px bar at the venues).
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(foot)
	var back := Button.new()
	back.text = _back_text
	UiTheme.button_flavor(back, "tertiary")
	back.pressed.connect(close)
	foot.add_child(back)


## Redraw whatever is inside, for a host whose world changed under it (a contract
## accepted, a chip bought) without closing the conversation.
func refresh() -> void:
	if _content != null and is_instance_valid(_content) and _content.has_method("refresh"):
		_content.call("refresh")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		close()


func close() -> void:
	Sfx.play("click", -16.0)
	closed.emit()
	queue_free()
