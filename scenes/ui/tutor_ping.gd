class_name TutorPing
extends Control
## The ping itself: corner brackets that breathe around a target control, plus
## one line of copy beside it. Deliberately RESTRAINED — this sits on top of a
## working screen the player is already reading, so it points without shouting.
##
## Never eats input (MOUSE_FILTER_IGNORE): the whole idea is that the player
## presses the real button, so the hint must never be the thing they click.
##
## Follows its target every frame rather than being positioned once, so it stays
## correct through tab switches, list rebuilds and window resizes.

## Gap below which the caption and its target read as one thing and the leader
## line is dropped entirely.
const MIN_LEADER := 34.0

const GLOW := Color(0.95, 0.78, 0.35)     # amber: the HUD's "look here" colour
const PERIOD := 1.5

var anchor := ""

var _t := 0.0
var _read := 0.0   # seconds this informational step has been legible


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 90


func _process(delta: float) -> void:
	_t += delta
	# INFORMATIONAL steps ("dwell") retire themselves after being on screen long
	# enough to read. A tab intro has nothing to DO — there is no click that
	# means "understood" — so without this it never completes, never counts as
	# seen, and re-arms every single time the tab is opened.
	var step := Tutor.current()
	var dwell := float(step.get("dwell", 0.0))
	if dwell > 0.0 and Tutor.safe and Tutor.is_pointing(anchor):
		# UNPINNED steps draw as a centered caption and never touch their anchor
		# node, so demanding a visible one froze them: the timer never advanced,
		# the lesson never retired, and every lesson queued behind it starved.
		# (That is how "pips" — an unpinned step added 2026-07-22 — silently ate
		# the whole trade lesson.) Tick whenever the step is actually ON SCREEN.
		var pinned := bool(step.get("pin", true))
		var node := Tutor.anchor_node(anchor)
		var on_screen: bool = not pinned or (node != null and node.is_visible_in_tree())
		if on_screen:
			_read += delta
			if _read >= dwell:
				_read = 0.0
				Tutor.note(anchor)
	queue_redraw()


## Where the brackets actually go. For a TabContainer the whole control is the
## entire panel — framing that is useless ("look at the screen you're on"), so a
## step naming a `tab` gets JUST THAT TAB'S HEADER in the strip. That's the thing
## the player has to click.
func _target_rect(node: Control) -> Rect2:
	var step := Tutor.current()
	var want := str(step.get("tab", ""))
	if want != "" and node is TabContainer:
		var bar: TabBar = (node as TabContainer).get_tab_bar()
		if bar != null:
			for i in bar.tab_count:
				# Substring match: the same tab is titled differently per venue
				# ("Mission Computer" vs "Mission Uplink"), and a step shouldn't
				# have to know which dock it will be read at.
				if bar.get_tab_title(i).findn(want) >= 0:
					var tab_rect := bar.get_tab_rect(i)
					return Rect2(bar.global_position - global_position + tab_rect.position, tab_rect.size)

	# A step can name ONE ROW of a list ("item"), matched on its text. Framing a
	# whole contract board when exactly one contract is meant makes the player
	# hunt for it — which is the confusion the ping exists to remove.
	var item := str(step.get("item", ""))
	if item != "" and node is ItemList:
		var list: ItemList = node
		for i in list.item_count:
			if list.get_item_text(i).findn(item) >= 0:
				var ir := list.get_item_rect(i)
				return Rect2(list.global_position - global_position + ir.position, ir.size)

	return Rect2(node.global_position - global_position, node.size)


## Step copy, with live PROGRESS appended when the step wants a quantity —
## "buy 4" is a guess until you can see you're at 2.
func _caption() -> String:
	var step := Tutor.current()
	# Lesson copy writes {TOKEN}s, never letters — expanded here against the LIVE
	# bindings so a rebind re-words every lesson instead of making it lie.
	var text := Keys.expand(str(step.get("text", "")))
	var need := int(step.get("need", 0))
	var good := str(step.get("good", ""))
	if need <= 0 or good.is_empty() or text.is_empty():
		return text
	var ship := get_tree().get_first_node_in_group("player_ship")
	if ship == null:
		return text
	return "%s   (%d/%d)" % [text, int(ship.commodities.get(good, 0)), need]


## Where the leader line starts and ends — or EMPTY for no line at all.
##
## It must touch the target's NEAR edge. The old form picked `r.end.y` when the
## target sat below the caption, i.e. the target's FAR side, so the line was
## drawn straight down through the middle of whatever it was pointing at — most
## visibly right through the launch countdown panel.
##
## And when the caption is already beside the thing, there is nothing to lead:
## a stub of line between two touching boxes is noise. Static + pure so the
## geometry can be tested without rendering anything.
static func leader_points(box: Rect2, target: Rect2) -> Array:
	var bc := box.get_center()
	var tc := target.get_center()
	# Close enough to read as one unit (or overlapping) — no line needed.
	if box.grow(MIN_LEADER).intersects(target):
		return []
	var below := tc.y > bc.y
	var from := Vector2(bc.x, box.end.y if below else box.position.y)
	var to := Vector2(
		clampf(from.x, target.position.x, target.end.x),
		target.position.y if below else target.end.y)
	return [from, to]


## Captions WRAP at a maximum width (user: the vitals lesson ran clean off the screen).
## A long sentence becomes a readable block, never a marquee.
const CAPTION_MAX_W := 540.0
const CAPTION_LINE_H := 19.0


static func wrap_lines(text: String, f: Font, size_px: int, max_w: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var probe := word if line.is_empty() else line + " " + word
		if f.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > max_w \
				and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = probe
	if not line.is_empty():
		lines.append(line)
	return lines


## The caption block: wrapped text centred on x, pulsing border. Returns its rect so the
## pinned path can hang the leader line off it.
func _draw_caption_box(center_x: float, top_y: float, text: String, pulse: float) -> Rect2:
	var f := get_theme_default_font()
	var size_px := 15
	var lines := wrap_lines(text, f, size_px, CAPTION_MAX_W)
	var w := 0.0
	for l in lines:
		w = maxf(w, f.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x)
	w += 18.0
	var box := Rect2(center_x - w * 0.5, top_y, w, lines.size() * CAPTION_LINE_H + 9.0)
	draw_rect(box, Color(0.04, 0.06, 0.10, 0.97))
	draw_rect(box, Color(GLOW, 0.55 + 0.45 * pulse), false, 2.0)
	for i in lines.size():
		draw_string(f, Vector2(box.position.x + 9.0, box.position.y + 16.0 + i * CAPTION_LINE_H),
			lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(1, 0.95, 0.82))
	return box


## Copy with no pointer — for steps that teach a KEY rather than a widget.
func _draw_caption_only() -> void:
	var text := _caption()
	if text.is_empty():
		return
	var bounds: Vector2 = get_viewport_rect().size
	var pulse: float = 0.5 + 0.5 * sin(_t * TAU / PERIOD)
	_draw_caption_box(bounds.x * 0.5, bounds.y * 0.62, text, pulse)


func _draw() -> void:
	# Hold everything while it isn't safe to teach — mid-fight the callout would
	# sit across the space the pilot needs to read. The lesson stays armed and
	# resumes the moment the sky is clear.
	if not Tutor.safe or not Tutor.is_pointing(anchor):
		return
	# A step can be UNPINNED ("pin": false) when what it teaches is a KEY, not a
	# control — [E] to launch has no widget to frame. Those show copy alone.
	if not bool(Tutor.current().get("pin", true)):
		_draw_caption_only()
		return
	# A PINNED step with no visible anchor draws NOTHING. It must not fall back
	# to caption-only: the planet's mission tab is registered but off-screen
	# while you're docked at the station, and falling back showed "Down safe,
	# still carrying their freight" to a pilot who hadn't left yet.
	var node := Tutor.anchor_node(anchor)
	if node == null or not node.is_visible_in_tree():
		return

	# Target rect in OUR space, padded so the brackets sit outside the control.
	var r := _target_rect(node).grow(5.0)
	var pulse: float = 0.5 + 0.5 * sin(_t * TAU / PERIOD)
	# Bolder than the first pass: the original brackets were hairlines at 35%
	# alpha on a busy, bright dock screen and simply read as more chrome.
	var a: float = 0.62 + 0.38 * pulse
	var arm: float = minf(22.0, minf(r.size.x, r.size.y) * 0.34)
	var col := Color(GLOW, a)
	var wide := 3.0

	# Corner brackets — an aiming reticle around the control, not a box that
	# hides its border or a fill that dims what you're meant to read.
	var pts := [
		[r.position, Vector2(arm, 0), Vector2(0, arm)],
		[Vector2(r.end.x, r.position.y), Vector2(-arm, 0), Vector2(0, arm)],
		[Vector2(r.position.x, r.end.y), Vector2(arm, 0), Vector2(0, -arm)],
		[r.end, Vector2(-arm, 0), Vector2(0, -arm)],
	]
	for p in pts:
		draw_line(p[0], p[0] + p[1], col, wide)
		draw_line(p[0], p[0] + p[2], col, wide)

	# A soft halo on the beat, so the eye catches it in peripheral vision.
	draw_rect(r, Color(GLOW, 0.05 + 0.07 * pulse), false, 1.0)

	var text := _caption()
	if text.is_empty():
		return
	# A CALLOUT near screen centre (bounded against the VIEWPORT — this Control's own
	# rect is not reliably the full screen), WRAPPED at CAPTION_MAX_W (the vitals lesson
	# ran clean off the side), on the opposite side of centre from the target so the
	# leader line has real length and the copy never covers what it points at.
	var bounds: Vector2 = get_viewport_rect().size
	var mid := bounds * 0.5
	var target_mid := r.position + r.size * 0.5
	var box_y: float = mid.y + (bounds.y * 0.12 if target_mid.y < mid.y else -bounds.y * 0.18)
	var box := _draw_caption_box(mid.x, box_y - 13.0, text, pulse)

	# Leader: caption edge -> the NEAREST edge of the target, never through it.
	var leader := leader_points(box, r)
	if not leader.is_empty():
		var lead := Color(GLOW, 0.5 + 0.5 * pulse)
		draw_line(leader[0], leader[1], lead, 2.0)
		draw_circle(leader[1], 4.0, lead)
