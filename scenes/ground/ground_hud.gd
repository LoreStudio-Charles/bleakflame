class_name GroundHud
extends Control
## UNIT FRAMES on foot: who YOU are and what you are pointed at, read at a glance.
##
## WHY (user, 2026-07-27): "We have the effigies on the ships, but nothing indicates
## player or target status well on the ground." The nameplates answer this out in the
## world, where your eyes are; the frames answer it in the one fixed place on screen you
## can always find, and carry the numbers a 32px plate has no room for.
##
## THE COLOUR LANGUAGE IS NAMEPLATE'S, BY REFERENCE not by copy — the constants are read
## off Nameplate rather than restated here. Two lists of the same colours is how a plate
## and a frame end up disagreeing about whether somebody is hostile after one of them is
## edited.
##
## LAYOUT: bottom-left = you, bottom-right = your target, flanking the technique bar at
## bottom-centre. THE TOP-LEFT IS DELIBERATELY EMPTY — it is reserved for coop party
## frames (the same reservation the flight HUD honours, which is why its friendlies
## roster sits top-right). Putting the player frame there would have to move the day
## multiplayer lands, and the party is the thing that belongs in the corner you scan
## first.
##
## Purely a READOUT: it reads the character and never writes to it.

const FRAME := Vector2(268.0, 58.0)
const MARGIN := 28.0
## Sit the frames' bottoms level with the technique bar's (bar y = height - SLOT - 54).
const BOTTOM_INSET := 54.0

const PANEL_BG := Color(0.05, 0.06, 0.09, 0.78)
const BAR_BG := Color(0.02, 0.03, 0.05, 0.9)
const CELL := Color(0.45, 0.78, 0.95)
const BARRIER := Color(0.55, 0.82, 1.0)

var walker: GroundCharacter          # whose frame the left slot draws, and whose target the right

var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if walker == null or not is_instance_valid(walker):
		return
	var bounds := get_viewport_rect().size
	var y := bounds.y - BOTTOM_INSET - FRAME.y
	_draw_frame(Rect2(Vector2(MARGIN, y), FRAME), walker, true)
	var t := walker.combat_target
	if t != null and is_instance_valid(t) and not t.dead:
		_draw_frame(Rect2(Vector2(bounds.x - MARGIN - FRAME.x, y), FRAME), t, false)


## One frame. `is_self` adds the cell gauge (only you spend one) and drops the rank pips
## (your own encounter rank is not information you need).
func _draw_frame(box: Rect2, who: GroundCharacter, is_self: bool) -> void:
	var col := _relation(who)
	draw_rect(box, PANEL_BG)
	# The border carries the relationship, so friend/foe reads before any text is parsed.
	# The TARGET frame also gets the amber selection bracket the plate uses, for the same
	# reason it does: relationship is colour, selection is shape.
	draw_rect(box, Color(col, 0.55), false, 1.0)
	if not is_self:
		_draw_corners(box, Color(0.95, 0.72, 0.35), 9.0)

	var pad := 9.0
	var name_y := box.position.y + pad + 12.0
	var label: String = who.display_name if who.display_name != "" else "?"
	draw_string(_font, Vector2(box.position.x + pad, name_y), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)

	# RANK, right-aligned on the name row — pips plus the word, because a frame has the
	# room a nameplate does not and "MILITARY" says more than three diamonds. NORMAL
	# prints nothing at all, so the marks stay a warning rather than furniture.
	if not is_self and who.team != "" and walker.team != "" and who.team != walker.team:
		var r := Threat.rank_of(who)
		if r != Threat.Rank.NORMAL:
			var txt := "%s %s" % [Threat.pips(r), Threat.label(r)]
			var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(_font, Vector2(box.end.x - pad - w, name_y), txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Threat.color(r))

	# --- health, with the number spelled out. The plate shows a fraction as a length;
	# the frame is where you get to read it.
	var bx := box.position.x + pad
	var bw := box.size.x - pad * 2.0
	var by := box.position.y + 30.0
	var bh := 11.0
	var hcol := _health_color(who)
	draw_rect(Rect2(Vector2(bx, by), Vector2(bw, bh)), BAR_BG)
	var frac: float = clampf(who.health / maxf(who.max_health, 1.0), 0.0, 1.0)
	draw_rect(Rect2(Vector2(bx, by), Vector2(bw * frac, bh)), hcol)
	draw_rect(Rect2(Vector2(bx, by), Vector2(bw, bh)), Color(hcol, 0.4), false, 1.0)
	# OUTLINED, because the number straddles the fill edge — half of it lands on a bright
	# bar and half on the dark remainder, and a single flat colour is unreadable on one
	# side or the other whatever you pick.
	var hp := "%d / %d" % [ceili(who.health), ceili(who.max_health)]
	var hw := _font.get_string_size(hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var hp_at := Vector2(bx + bw * 0.5 - hw * 0.5, by + 9.0)
	draw_string_outline(_font, hp_at, hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4,
		Color(0.02, 0.02, 0.04, 0.95))
	draw_string(_font, hp_at, hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.98, 0.99, 1.0))

	# BARRIER sits ON the health bar as a thin overlay, the same shape the plate uses:
	# it is a shield IN FRONT OF the health, not a second pool beside it.
	if who.max_barrier > 0.0 and who.barrier > 0.0:
		var bf: float = clampf(who.barrier / who.max_barrier, 0.0, 1.0)
		draw_rect(Rect2(Vector2(bx, by - 3.0), Vector2(bw * bf, 3.0)), BARRIER)

	var line_y := by + bh + 5.0
	if is_self and who.max_energy > 0.0:
		# The CELL, mirrored from the technique bar's gauge so the two never disagree.
		var ef: float = clampf(who.energy / maxf(who.max_energy, 1.0), 0.0, 1.0)
		draw_rect(Rect2(Vector2(bx, line_y), Vector2(bw, 5.0)), BAR_BG)
		draw_rect(Rect2(Vector2(bx, line_y), Vector2(bw * ef, 5.0)),
			Color(0.62, 0.9, 1.0) if who.meditating else CELL)
	elif not is_self:
		# What the target is DOING — the states that change how you should fight it. Silent
		# when it is merely standing there, so a line appearing means something happened.
		var state := _state_text(who)
		if state != "":
			draw_string(_font, Vector2(bx, line_y + 9.0), state,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.72, 0.35))


## The states worth calling out, in the order they matter to a player deciding what to do
## next. Reeling first: it is a window, and a window closes.
func _state_text(who: GroundCharacter) -> String:
	if who.is_stunned():
		return "REELING"
	if who.is_braced():
		return "BRACED"
	if who.meditating:
		return "MEDITATING"
	if who.is_hasted():
		return "HASTED"
	if who.health < who.max_health * 0.3:
		return "WOUNDED"
	return ""


## Friend, foe or bystander, from the PLAYER's side. Delegates its palette to Nameplate so
## the world marker and the frame cannot drift apart.
func _relation(who: GroundCharacter) -> Color:
	if who == walker:
		return Nameplate.SELF
	if who.team == "":
		return Nameplate.NEUTRAL
	if who.team == walker.team:
		return Nameplate.FRIENDLY
	return Nameplate.HOSTILE


## HEALTH IS NOT IDENTITY. The first pass filled the health bar with the relation colour,
## which put the player's health in SELF blue directly above the cell gauge — also blue,
## also full width. Two bars in near-identical colours read as one confusing double bar,
## and neither said "this is your life" or "this is your energy". So identity stays on the
## NAME and the BORDER, and the bar itself carries green/orange/grey — the same green the
## town used for the player's own hp bar before frames existed.
func _health_color(who: GroundCharacter) -> Color:
	if who.team == "":
		return Nameplate.NEUTRAL
	if who == walker or who.team == walker.team:
		return Nameplate.FRIENDLY
	return Nameplate.HOSTILE


## Corner ticks rather than a full outline — a closed box at this size reads as a button,
## and the ship HUD's target bracket is corners for the same reason.
func _draw_corners(box: Rect2, col: Color, c: float) -> void:
	for corner in [[box.position, Vector2(1, 1)],
			[Vector2(box.end.x, box.position.y), Vector2(-1, 1)],
			[Vector2(box.position.x, box.end.y), Vector2(1, -1)],
			[box.end, Vector2(-1, -1)]]:
		var p: Vector2 = corner[0]
		var s: Vector2 = corner[1]
		draw_line(p, p + Vector2(c * s.x, 0), col, 2.0)
		draw_line(p, p + Vector2(0, c * s.y), col, 2.0)
