class_name VShrikeShip
extends AIShip
## THE V-SHRIKE — the Gap's owners on the Long Lane (docs/the_long_lane.md).
##
##   "They do not raise comms. They hit, take, and destroy.
##    No prisoners. No survivors. Only ash."  — user, 2026-07-25
##
## BLACK WIDOW (user, 2026-07-25): near-BLACK hulls carrying a SINGLE POINT OF
## RED — the widow's hourglass, sitting aft on the deck where the abdomen would
## be. One mark and nothing else: no chevron, no stripes, no random skin.
##
## WHY IT READS. Every other faction in this sky is coloured — the Reach's rusty
## oranges, Guardian blue, Galean ivory, the Shoal's scavenged mismatch. A black
## hull is a HOLE in that, and the red is the only thing you get to recognise
## before it opens fire. The silence does the same work in the comms channel that
## the black does on the screen: everyone else announces themselves.

## Not pure black — a hair of cool in it, so the hull still catches the rim light
## and reads as a ship rather than a sprite-shaped hole.
const HULL_BLACK := Color(0.13, 0.12, 0.15)
## Deep arterial red, NOT the orange-red of the Reach's rust. It should look like
## a warning label, because it is one.
const WIDOW_RED := Color(0.80, 0.05, 0.09)

var _widow_mark: Node2D = null


## Stands up a V-Shrike raider: the pirate brain, the widow's colours, and the
## refusal to talk.
func setup_vshrike(new_build: ShipBuild, p_tactic: Tactic = Tactic.ORBIT) -> void:
	faction_livery = true      # keep off the shared rust-and-orange skin pool
	setup(new_build, p_tactic, HULL_BLACK)
	apply_widow_mark()


## RARE AI SPECIALISTS REPAINT THE HULL to advertise themselves (AIShip tints a
## mender green, a warden blue, a binder amber) so "kill the mender first" can be
## learned before it acts rather than in hindsight. Good rule, bad fit here: it
## fires on ~13% of eligible hulls, which would have spawned roughly one V-Shrike
## in eight in GREEN — out of its own livery, on the one faction whose whole read
## is a black hull and a single red mark.
##
## THE LIVERY WINS. A specialist stays legible through its on-use `_flash_note`
## callout, which is the channel that survives; what is lost is the advance
## warning. If that trade turns out to matter in play, the fix is to recolour the
## HOURGLASS per specialty rather than the hull — same information, and the ship
## stays black.
func _roll_specialty() -> void:
	super()
	set_hull_tint(HULL_BLACK)


## THE HOURGLASS — two triangles meeting at a waist, laid along the hull's spine
## and set aft where a widow's abdomen sits.
##
## Drawn as TWO polygons rather than one: a true hourglass outline pinches to a
## single shared point at the waist, and a self-touching polygon is exactly the
## case triangulation gets wrong.
##
## WORKS ON A SILHOUETTE HULL TOO. Every other livery in the codebase gives up
## when there is no sprite (`apply_livery` returns early), which would have made
## this mark invisible on all four Long Lane hulls — none of them have art yet.
## So the scale unit comes from the sprite when there is one and from the hull's
## authored silhouette when there isn't, and the mark parents to whichever visual
## is actually on screen.
func apply_widow_mark() -> void:
	if _widow_mark != null and is_instance_valid(_widow_mark):
		_widow_mark.queue_free()
		_widow_mark = null

	var host: Node2D = null
	var h := 0.0
	if _hull_sprite != null and _hull_sprite.texture != null:
		host = _hull_sprite
		h = 0.5 * float(_hull_sprite.texture.get_width())
	elif _hull_visual != null:
		host = _hull_visual
		h = _silhouette_half_width()
	if host == null or h <= 0.0:
		return

	# Hourglass geometry, ship-local (nose = +X). Centred at the waist, aft of
	# midships, about a quarter of the half-width long — a POINT of red, not a
	# panel of it.
	var waist := Vector2(-0.18 * h, 0.0)
	var half_len := 0.12 * h
	var half_tall := 0.13 * h

	var root := Node2D.new()
	for dir: float in [1.0, -1.0]:
		var base_x: float = waist.x + dir * half_len
		var tri := Polygon2D.new()
		tri.polygon = PackedVector2Array([
			waist,
			Vector2(base_x, -half_tall),
			Vector2(base_x, half_tall)])
		tri.color = WIDOW_RED
		root.add_child(tri)
	host.add_child(root)
	_widow_mark = root


## Half-width of the hull's authored silhouette, for art-less hulls. Uses the
## LARGER of the two axes so a long, narrow hull still gets a mark in proportion
## to the ship rather than a sliver.
func _silhouette_half_width() -> float:
	if build == null or build.hull == null or build.hull.silhouette.is_empty():
		return 0.0
	var lo := build.hull.silhouette[0]
	var hi := build.hull.silhouette[0]
	for p in build.hull.silhouette:
		lo = lo.min(p)
		hi = hi.max(p)
	return 0.5 * maxf(hi.x - lo.x, hi.y - lo.y)


## ON "THEY DO NOT RAISE COMMS" — deliberately NOT code yet.
##
## Nothing here suppresses comms, because there is nothing to suppress: hailing
## runs one way (the PLAYER hails, ship.hail_friendly, from the friendlies roster)
## and a hostile never enters that roster. AI ships have no taunt or bark system
## at all, so V-Shrike silence is currently free.
##
## It stops being free the day ambient barks land — a shared "pirate jeers on
## approach" line would hand these people a voice by accident, and the silence is
## the entire character. WHOEVER BUILDS THAT: exclude this class explicitly. An
## override written now would be dead code pointing at an API that does not exist,
## which is worse than a note.
