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

## How far the tail rides UP INTO the bubble.
##
## THE TAIL DRAWS ON TOP (user, 2026-07-26). It is added after the body so it wins
## the z-order, and that is required rather than incidental: the bubble's bottom
## border is a 1px black line, and behind the body that line would run straight
## across the tail's mouth, like a balloon with its neck tied off. Drawn over it,
## the tail's own white fill covers the border exactly where the two meet and the
## outline appears to open into the stem. The shipped tail is open-topped (every row
## is black edge plus white fill), which is what makes that work -- no art change
## needed.
##
## 1px is the MEASURED thickness of that border. It also makes the join immune to
## rounding, since this lives in world space and an exact edge-to-edge join can
## split across a pixel boundary at a fractional camera zoom.
##
## APPLIED TO THE TAIL ONLY. Shifting body and tail by the same amount just moves
## the whole assembly and leaves the join exact -- which is exactly what the first
## version of this constant did, and the test agreed with it because it encoded the
## same arithmetic. The test now demands a real overlap.
const TAIL_OVERLAP := 1.0

## How far in from the bubble's edge the tail attaches, as a fraction of width.
## Not 0: a tail flush with the corner reads as a mistake rather than a stem.
const TAIL_INSET := 0.22

const FADE := 0.35

var _life := 0.0
var _target: Node2D = null
var _body: Control = null
var _tail: Node2D = null
var _label: Label = null
var _size := Vector2.ZERO
## Which way the body extends from the speaker; see the layout in _build.
var _open_right := true


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

	# MEASURE THE TAIL FIRST. The body's bottom edge has to sit exactly on the
	# arrow's top, and only the art knows how tall the arrow is: the shipped one is
	# 8px of ink inside a 32px canvas, so the fixed 10 this used to assume left a
	# 2px seam between bubble and tail.
	var tip := Vector2.ZERO
	var tail_h := TAIL_H
	var has_tail := ResourceLoader.exists(TAIL_ART)
	if has_tail:
		var ttex: Texture2D = load(TAIL_ART)
		var metrics := _tail_metrics(ttex)
		tip = Vector2(metrics.x, metrics.y)
		tail_h = maxf(1.0, metrics.z)

	if ResourceLoader.exists(BODY_ART):
		var np := NinePatchRect.new()
		np.texture = load(BODY_ART)
		# Corners drawn 1:1; only the flat middle stretches. Same reasoning as
		# UiTheme.add_frame -- stretched detail smears, repeated detail clutters.
		# 20% of the shorter side. Measured against the shipped 32x32 art, whose
		# rounded corners are 6px deep, this gives 6 — corners drawn 1:1, the flat
		# middle free to stretch. It scales with the art, so a 64px redraw with
		# 12px corners still works without touching code.
		var m := int(min(np.texture.get_width(), np.texture.get_height()) * 0.2)
		np.patch_margin_left = m
		np.patch_margin_top = m
		np.patch_margin_right = m
		np.patch_margin_bottom = m
		_body = np
	else:
		_body = Control.new()      # procedural: _draw() handles it
	# WHICH SIDE THE BUBBLE OPENS TOWARD (user, 2026-07-26). The tail stays over the
	# speaker; the BODY slides so a long line does not run off the edge. Speaker on
	# the left of the view -> bubble opens right (tail near its left end), and the
	# mirror on the other side. Falls back to centred when there is no camera to ask.
	var open_right := true
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam != null and _target != null and is_instance_valid(_target):
		open_right = _target.global_position.x <= cam.get_screen_center_position().x
	_open_right = open_right

	_body.size = _size
	# Attach point sits TAIL_INSET in from the near edge, so the body offset puts
	# x=0 (the speaker) at that spot rather than at the body's middle.
	var shift: float = _size.x * TAIL_INSET if open_right else _size.x * (1.0 - TAIL_INSET)
	_body.position = Vector2(-shift, -(_size.y + tail_h + LIFT))
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)

	_label.position = PAD
	_label.size = Vector2(_size.x - PAD.x * 2.0, _size.y - PAD.y * 2.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_label)

	if has_tail:
		var t := Sprite2D.new()
		t.texture = load(TAIL_ART)
		t.centered = false
		# ANCHOR THE DRAWN TIP, NOT THE CANVAS. The shipped tail is a 9x8 arrow
		# floating in a 32x32 canvas — its ink centre sits 5.5px left of the texture
		# centre, and the arrow is SWEPT, so its point is the bottom-RIGHT rather
		# than the bottom-middle. Positioning by texture width would hang it off to
		# one side and aim it at nothing. Found by measuring the PNG, because a
		# transparent canvas hides all of this.
		# FLIPPED WHEN THE BUBBLE OPENS THE OTHER WAY. The arrow is swept, so a
		# mirrored copy is exactly the stem the other side needs — and flip_h mirrors
		# WITHIN the sprite's rect, so the tip moves to (width - tip.x) and the
		# placement has to follow it or the point drifts off the speaker.
		t.flip_h = not open_right
		var tip_x: float = tip.x if open_right else float(t.texture.get_width()) - tip.x
		# MINUS: up into the bubble, so the mouth is covered by what it overlaps.
		t.position = Vector2(-tip_x, -LIFT - tip.y - TAIL_OVERLAP)
		_tail = t
		add_child(t)


## The tail's real geometry, in texture pixels: (tip_x, tip_y, ink_height).
##
## Scanned from the image, never hardcoded, because a transparent canvas hides all
## of it. The shipped arrow is 9x8 of ink adrift in a 32x32 canvas — its centre sits
## 5.5px left of the texture centre and it is SWEPT, so its point is the
## bottom-RIGHT rather than the bottom-middle. Anything derived from texture size
## would hang it off to one side, aim it at nothing, and leave a seam.
##
## A re-drawn tail — longer, hooked the other way, properly centred — lands right
## with no code change. That is the whole promise of a drop-in seam.
func _tail_metrics(tex: Texture2D) -> Vector3:
	var img := tex.get_image()
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	if img == null:
		return Vector3(w * 0.5, h, TAIL_H)
	var low := -1
	var high := -1
	var lo_x := tex.get_width()
	var hi_x := -1
	for y in img.get_height():
		var any := false
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.15:
				any = true
				if low < 0 or y > low:
					low = y
				if high < 0:
					high = y
		if any and low == y:
			# Only the LOWEST row defines the point.
			lo_x = tex.get_width()
			hi_x = -1
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.15:
					lo_x = mini(lo_x, x)
					hi_x = maxi(hi_x, x)
	if low < 0:
		return Vector3(w * 0.5, h, TAIL_H)
	return Vector3((float(lo_x) + float(hi_x) + 1.0) * 0.5,
		float(low) + 1.0, float(low + 1 - high))


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
	var top := -(_size.y + TAIL_H + LIFT)   # fallback path: no art, so the constant is the truth
	if not (_body is NinePatchRect):
		var shift: float = _size.x * TAIL_INSET if _open_right else _size.x * (1.0 - TAIL_INSET)
		var r := Rect2(Vector2(-shift, top), _size)
		draw_rect(r, fill)
		draw_rect(r, edge, false, 2.0)
	if _tail == null:
		# A small down-pointing arrow, centred, its tip toward the speaker.
		var y := -LIFT - TAIL_H
		draw_colored_polygon(PackedVector2Array([
			Vector2(-9.0, y), Vector2(9.0, y), Vector2(0.0, y + TAIL_H)]), fill)
		draw_line(Vector2(-9.0, y), Vector2(0.0, y + TAIL_H), edge, 2.0)
		draw_line(Vector2(9.0, y), Vector2(0.0, y + TAIL_H), edge, 2.0)
