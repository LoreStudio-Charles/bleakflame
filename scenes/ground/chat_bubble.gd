class_name ChatBubble
extends Node2D
## A LINE OF SPEECH OVER SOMEONE'S HEAD (user, 2026-07-26).
##
## Replaces the centre-screen flash that NPC hails used. A flash is the wrong
## channel for dialogue twice over: it takes the middle of the screen for something
## the player did not ask for, and it does not say WHO is talking — in a town with
## six people that is a real question. It also had to be read fast or not at all;
## "the words she says pop up and go away a tiny bit too fast" was the report that
## started this.
##
## A bubble answers all three: it is beside the speaker, it points AT them, and it
## sits still while you read.
##
## ART IS DROP-IN, and comes in two pieces ON PURPOSE:
##   assets/ui/chat_bubble.png       — the body, a NINE-PATCH
##   assets/ui/chat_bubble_tail.png  — the little arrow, a plain sprite
##
## THE TAIL CANNOT BE PART OF THE NINE-PATCH. A nine-patch stretches its bottom
## EDGE horizontally, so an arrow drawn into that edge smears wider every time the
## bubble grows to fit a longer line. Keeping it a separate sprite centred beneath
## the body means it stays exactly the shape it was drawn, at any bubble width.
##
## Absent either file it draws itself, so this works before any art exists —
## and the procedural version stands down piece by piece as each PNG lands.

const BODY_ART := "res://assets/ui/chat_bubble.png"
const TAIL_ART := "res://assets/ui/chat_bubble_tail.png"

## Text metrics. WRAP_WIDTH is a ceiling, not a size: a short line makes a short
## bubble, which is the whole point of a nine-patch here.
const WRAP_WIDTH := 320.0
const PAD := Vector2(14.0, 9.0)
const FONT_SIZE := 15
## How far the tail's point sits above the speaker's origin. Their sprite is drawn
## from the feet, so this clears a head without needing to know the art's height.
const LIFT := 96.0
const TAIL_H := 10.0

const FADE := 0.35

var _life := 0.0
var _target: Node2D = null
var _body: Control = null
var _tail: Node2D = null
var _label: Label = null
var _size := Vector2.ZERO


## `speaker` is followed every frame — an NPC who wanders off takes their words
## with them, which is far less confusing than a line hanging in empty air.
static func say(parent: Node, speaker: Node2D, text: String, life := 4.5) -> ChatBubble:
	var b := ChatBubble.new()
	b._target = speaker
	b._life = life
	parent.add_child(b)
	b._build(text)
	return b


func _build(text: String) -> void:
	z_index = 90                      # over props, under any real overlay

	_label = Label.new()
	_label.text = text
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color(0.08, 0.09, 0.12))

	# Measure at the wrap ceiling, then shrink to what the text actually used, so a
	# three-word line does not get a three-hundred-pixel bubble.
	var font := _label.get_theme_font("font")
	var wrapped := font.get_multiline_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, WRAP_WIDTH, FONT_SIZE)
	_size = wrapped + PAD * 2.0

	if ResourceLoader.exists(BODY_ART):
		var np := NinePatchRect.new()
		np.texture = load(BODY_ART)
		# Corners drawn 1:1; only the flat middle stretches. Same reasoning as
		# UiTheme.add_frame -- stretched detail smears, repeated detail clutters.
		var m := int(min(12, min(np.texture.get_width(), np.texture.get_height()) / 3))
		np.patch_margin_left = m
		np.patch_margin_top = m
		np.patch_margin_right = m
		np.patch_margin_bottom = m
		_body = np
	else:
		_body = Control.new()      # procedural: _draw() handles it
	_body.size = _size
	_body.position = -Vector2(_size.x * 0.5, _size.y + TAIL_H + LIFT)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)

	_label.position = PAD
	_label.size = Vector2(_size.x - PAD.x * 2.0, _size.y - PAD.y * 2.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_label)

	if ResourceLoader.exists(TAIL_ART):
		var t := Sprite2D.new()
		t.texture = load(TAIL_ART)
		t.centered = false
		var tw: float = float(t.texture.get_width())
		t.position = Vector2(-tw * 0.5, -LIFT - TAIL_H)
		_tail = t
		add_child(t)


func _process(delta: float) -> void:
	if _target != null and is_instance_valid(_target):
		global_position = _target.global_position
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	# Fade the last moment rather than blinking out.
	modulate.a = clampf(_life / FADE, 0.0, 1.0)
	if _body != null and not (_body is NinePatchRect):
		queue_redraw()


## PROCEDURAL FALLBACK — only what the art has not replaced.
##
## Drawn here on the Node2D rather than on the body Control so the tail and the
## panel share one coordinate space, and so a missing TAIL still gets drawn even
## when the BODY art exists. Either piece can land on its own.
func _draw() -> void:
	if _size == Vector2.ZERO:
		return
	var fill := Color(0.93, 0.94, 0.97, 0.96)
	var edge := Color(0.10, 0.12, 0.16, 0.9)
	var top := -(_size.y + TAIL_H + LIFT)
	if not (_body is NinePatchRect):
		var r := Rect2(Vector2(-_size.x * 0.5, top), _size)
		draw_rect(r, fill)
		draw_rect(r, edge, false, 2.0)
	if _tail == null:
		# A small down-pointing arrow, centred, its tip toward the speaker.
		var y := -LIFT - TAIL_H
		draw_colored_polygon(PackedVector2Array([
			Vector2(-9.0, y), Vector2(9.0, y), Vector2(0.0, y + TAIL_H)]), fill)
		draw_line(Vector2(-9.0, y), Vector2(0.0, y + TAIL_H), edge, 2.0)
		draw_line(Vector2(9.0, y), Vector2(0.0, y + TAIL_H), edge, 2.0)
