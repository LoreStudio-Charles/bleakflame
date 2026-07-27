class_name Nameplate
extends Node2D
## The floating plate over a ground character: who it is, how hurt it is, and
## whether it is the thing you are currently pointed at.
##
## WHY IT EXISTS (user, 2026-07-27): "We have the effigies on the ships, but
## nothing indicates player or target status well on the ground." In flight the
## target wears a bracket and the roster names it; on the ground there was NOTHING
## — no target marker of any kind, and in a town where every colonist is a similar
## silhouette you could not reliably tell which one was you.
##
## THE COLOUR LANGUAGE IS THE SHIP'S, DELIBERATELY. Hostile orange and friendly
## teal are lifted verbatim from flight_hud/ship (0.95,0.45,0.3 and 0.45,0.9,0.75)
## so a player who has learned to read the space HUD already reads this one. Two
## modes with two vocabularies would be two things to learn for one meaning.
##
## RELATIONSHIP IS COLOUR, TARGET IS SHAPE. Being targeted brightens the plate and
## adds a bracket and a foot ring; it never RECOLOURS anything. That keeps "what is
## it" and "am I pointed at it" on separate channels, which is the same split the
## ship HUD uses and the reason you can read both at a glance.
##
## DRAWN IN WORLD SPACE as a child of the character rather than as one screen-space
## overlay: the town lives in its own SubViewport, so a HUD-space pass would have to
## project every actor through it, and a plate that lags the sprite by a frame reads
## as worse than no plate.

## Lifted from flight_hud/ship — see the class comment.
const HOSTILE := Color(0.95, 0.45, 0.3)
const FRIENDLY := Color(0.45, 0.9, 0.75)
const NEUTRAL := Color(0.72, 0.76, 0.86)
const SELF := Color(0.55, 0.82, 1.0)

const PLATE_BG := Color(0.05, 0.06, 0.09, 0.72)
const BAR_BG := Color(0.02, 0.03, 0.05, 0.85)
const BAR_H := 3.0
const PAD := Vector2(4.0, 2.0)

## How close before a bystander's name is worth the ink. The current target and
## anything hostile ignore this — you always want to read the thing that matters.
const NAME_RANGE := 340.0
## Hostiles announce themselves further out than colonists do.
const HOSTILE_RANGE := 620.0
## Radii of the ellipse under the feet. Squashed, because the town is drawn at a
## slight tilt and a true circle reads as a ball rather than a footprint.
const RING_R := Vector2(17.0, 7.0)

var who: GroundCharacter          # the character this plate belongs to
var viewer: GroundCharacter       # whose point of view decides friend/foe (the player)

var _font: Font
var _head := -74.0                # plate sits this far above the feet-anchored origin


func _init(p_who: GroundCharacter, p_viewer: GroundCharacter) -> void:
	who = p_who
	viewer = p_viewer
	# ABOVE EVERYTHING. The town y-sorts, so without this a plate is occluded by any
	# actor standing one pixel further south — including the one it belongs to.
	z_index = 40
	top_level = false


func _ready() -> void:
	_font = ThemeDB.fallback_font
	var art := who.get_node_or_null("AnimatedSprite2D")
	if art is AnimatedSprite2D and art.sprite_frames != null:
		var tex := art.sprite_frames.get_frame_texture(art.animation, 0)
		if tex != null:
			_head = -float(tex.get_height()) - 8.0


func _process(_delta: float) -> void:
	queue_redraw()


## Friend, foe or bystander, from the VIEWER's side of the fight. Teams are strings
## on the character ("player_team" / "hostile"); "" means non-combatant, which is
## most of a farming colony.
func _relation() -> Color:
	if who == viewer:
		return SELF
	if who.team == "":
		return NEUTRAL
	if viewer != null and who.team == viewer.team:
		return FRIENDLY
	return HOSTILE


## Is this plate worth drawing right now? The rule is "tell me what matters and
## nothing else" — a town of forty colonists each wearing a permanent label is
## noise, and noise is what makes a player stop reading labels at all.
func _should_draw() -> bool:
	if who == null or not is_instance_valid(who) or who.dead:
		return false
	if viewer == null or not is_instance_valid(viewer):
		return false
	if who == viewer:
		return true                                   # your own marker is always on
	if viewer.combat_target == who:
		return true                                   # the thing you are pointed at
	var d := who.global_position.distance_to(viewer.global_position)
	var hostile := who.team != "" and who.team != viewer.team
	if hostile:
		return d <= HOSTILE_RANGE
	if who.health < who.max_health:
		return d <= NAME_RANGE                        # someone hurt is worth noticing
	return who.display_name != "" and d <= NAME_RANGE


func _draw() -> void:
	if not _should_draw():
		return
	var col := _relation()
	var targeted: bool = viewer.combat_target == who
	var is_self: bool = who == viewer

	# --- the foot ring: the only marker the PLAYER themselves gets, plus the
	# target's. It sits on the ground rather than over the head so it never
	# occludes the character art, and so two stacked actors stay distinguishable.
	if is_self or targeted:
		var ring := col if is_self else Color(0.95, 0.72, 0.35)   # AMBER = selection
		draw_arc(Vector2.ZERO, RING_R.x, 0.0, TAU, 24, Color(ring, 0.85), 1.6, true)
		# Squash it by drawing into a scaled space would need a transform; instead a
		# second, flatter arc reads as a tilted ellipse at this size and costs nothing.
		draw_arc(Vector2(0, RING_R.y * 0.35), RING_R.x * 0.82, 0.0, TAU, 20,
			Color(ring, 0.35), 1.2, true)

	if is_self:
		return   # you know who you are; a plate over your own head is just clutter

	# --- the plate ---
	var label: String = who.display_name if who.display_name != "" else "?"
	# POWER, NOT JUST IDENTITY (user, 2026-07-27). Only for things you could fight —
	# pips over a farmhand would be absurd — and only when they are worth a warning.
	# TRIVIAL and EASY draw nothing, so the marks mean "look out" rather than
	# "here is a number", and a peaceful town stays free of combat furniture.
	var pips := ""
	var pip_col := Color.WHITE
	if who.team != "" and viewer.team != "" and who.team != viewer.team:
		var r := Threat.rank_of_ship(who)   # reads the AUTHORED rank; ships and walkers alike
		pips = Threat.pips(r)       # NORMAL draws nothing — the common case stays silent
		pip_col = Threat.color(r)
	var pip_w: float = 0.0 if pips == "" \
		else _font.get_string_size(pips, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 4.0
	var text_w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + pip_w
	var hurt: bool = who.health < who.max_health
	var show_bar: bool = hurt or targeted or (who.team != "" and who.team != viewer.team)
	var w: float = maxf(text_w, 46.0) + PAD.x * 2.0
	var h: float = 13.0 + PAD.y * 2.0 + (BAR_H + 2.0 if show_bar else 0.0)
	var box := Rect2(Vector2(-w * 0.5, _head - h), Vector2(w, h))

	draw_rect(box, PLATE_BG)
	if targeted:
		# THE BRACKET, not a recolour: shape says "selected", colour still says
		# "friend or foe". Corners only — a full outline at this size reads as a
		# button, and the ship HUD's target bracket is corners for the same reason.
		var amber := Color(0.95, 0.72, 0.35)
		var c := 5.0
		for corner in [[box.position, Vector2(1, 1)],
				[Vector2(box.end.x, box.position.y), Vector2(-1, 1)],
				[Vector2(box.position.x, box.end.y), Vector2(1, -1)],
				[box.end, Vector2(-1, -1)]]:
			var p: Vector2 = corner[0]
			var s: Vector2 = corner[1]
			draw_line(p, p + Vector2(c * s.x, 0), amber, 1.5)
			draw_line(p, p + Vector2(0, c * s.y), amber, 1.5)

	var tint := col if not targeted else col.lightened(0.25)
	var tx := -text_w * 0.5
	var ty := _head - h + PAD.y + 11.0
	draw_string(_font, Vector2(tx, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, tint)
	if pips != "":
		draw_string(_font, Vector2(tx + text_w - pip_w + 4.0, ty), pips,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, pip_col)

	if show_bar:
		var bx := box.position.x + PAD.x
		var bw := box.size.x - PAD.x * 2.0
		var by := box.end.y - PAD.y - BAR_H
		draw_rect(Rect2(Vector2(bx, by), Vector2(bw, BAR_H)), BAR_BG)
		var frac: float = clampf(who.health / maxf(who.max_health, 1.0), 0.0, 1.0)
		draw_rect(Rect2(Vector2(bx, by), Vector2(bw * frac, BAR_H)), tint)
		# BARRIER OVER HEALTH, drawn as a thin overlay on the same bar rather than a
		# second one: it is a shield in front of the health, and stacking two full-width
		# bars over a 32px sprite is more plate than character.
		if who.max_barrier > 0.0 and who.barrier > 0.0:
			var bf: float = clampf(who.barrier / who.max_barrier, 0.0, 1.0)
			draw_rect(Rect2(Vector2(bx, by - 1.0), Vector2(bw * bf, 1.5)),
				Color(0.55, 0.82, 1.0, 0.95))
