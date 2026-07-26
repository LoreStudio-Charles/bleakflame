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

## A NAMED hunter's callsign ("Recluse"), or "" for the rank and file.
##
## THE NAME IS THE WHOLE VENGEANCE LOOP. A pilot killed by an anonymous black
## fighter has been beaten by the game; a pilot killed by RECLUSE has been beaten
## by somebody, and can go back for them. So the callsign is what the HUD shows on
## the mark and what Nemesis keys the grudge to.
##
## A PAIR SHARES ONE CALLSIGN on purpose — Recluse hunts as two hulls and one
## animal. Either one that kills you writes the same grudge, and killing either
## settles it.
var callsign := ""


## Where the Navy's reach begins, published by flight_test (the AIShip.station_pos
## pattern). Vector2.INF = nobody has said, so the navy term is simply skipped.
static var navy_pos := Vector2.INF

# --- THE RAIDER'S DOCTRINE (user, 2026-07-25) ---
# Recluse is a COMMERCE RAIDER, not a duellist. It is on this road for cargo, and
# it would rather take a fat hauler than win a fight. That single preference does
# a lot of characterisation for free: the V-Shrike are here to TAKE, and combat is
# just the toll.
#
# It also makes the Mule frightening to fly. A pilot who is the only cargo in the
# lane IS the convoy, and gets hunted accordingly.
const CARGO_WEIGHT := 1.5      # hold size is the whole appeal; bigger is better
const ALONE_BONUS := 250.0     # anyone alone out here is worth taking, cargo or not
const ESCORT_FEAR := 60.0      # per ally near the mark — a screen is a deterrent,
                               # never a veto: a fat enough hauler is still worth it
const NAVY_DREAD := 12000.0    # inside this of the Navy's reach, prey looks poisoned
const NAVY_WEIGHT := 0.05
const DISTANCE_COST := 0.02    # mild: it will cross the lane for a good enough mark
## Allies this close to a mark count as its screen.
const SCREEN_R := 1400.0


## HOW A RAIDER RANKS A MARK. Pure and static so the doctrine can be tested
## without a world: cargo is the draw, isolation is the opportunity, the Navy is
## the deterrent, and distance is a tiebreak.
##
## Deliberately a SCORE and not a filter. "Only attack freighters" would make
## Recluse ignore a lone fighter, and "anyone alone in the lane is in danger" is
## the rule that keeps the whole road tense rather than just the cargo runs.
static func rank_prey(cargo: float, allies_near: int, navy_dist: float,
		my_dist: float) -> float:
	var score := maxf(0.0, cargo) * CARGO_WEIGHT
	if allies_near <= 0:
		score += ALONE_BONUS
	else:
		score -= float(allies_near) * ESCORT_FEAR
	if navy_dist < NAVY_DREAD:
		score -= (NAVY_DREAD - navy_dist) * NAVY_WEIGHT
	return score - maxf(0.0, my_dist) * DISTANCE_COST


## Named hunters pick by doctrine; the rank and file keep the ordinary
## nearest-target behaviour. A whole faction of fussy raiders would read as
## broken AI rather than as character.
func _pick_prey() -> BuildShip:
	if callsign == "":
		return super()
	var reach := acquire_range()
	if reach <= 0.0:
		return null          # no eyes, no hunt — doctrine cannot pick what it cannot see
	var best: BuildShip = null
	var best_score := -INF
	for node in get_tree().get_nodes_in_group("player_team"):
		var bs := node as BuildShip
		if bs == null or not _prey_valid(bs, reach):
			continue
		var navy_d := INF
		if navy_pos.is_finite():
			navy_d = bs.global_position.distance_to(navy_pos)
		var score := rank_prey(_hold_size(bs), _screen_around(bs), navy_d,
			global_position.distance_to(bs.global_position))
		if score > best_score:
			best_score = score
			best = bs
	return best


## How much this mark can be carrying — the reason to bother.
func _hold_size(bs: BuildShip) -> float:
	return float(bs.stats.get("cargo", 0.0)) if bs.stats != null else 0.0


## Friendly hulls close enough to a mark to answer for it. The mark itself does
## not count as its own escort.
func _screen_around(bs: BuildShip) -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("player_team"):
		var other := node as BuildShip
		if other == null or other == bs or other.dead:
			continue
		if other.global_position.distance_to(bs.global_position) <= SCREEN_R:
			n += 1
	return n


var _widow_mark: Node2D = null


## Stands up a V-Shrike raider: the pirate brain, the widow's colours, and the
## refusal to talk. Pass a `name` to make it a named hunter.
func setup_vshrike(new_build: ShipBuild, p_tactic: Tactic = Tactic.ORBIT,
		name_tag: String = "") -> void:
	callsign = name_tag
	faction_livery = true      # keep off the shared rust-and-orange skin pool
	setup(new_build, p_tactic, HULL_BLACK)
	apply_widow_mark()


## NOTE ON SPECIALISTS. Rare AI specialists used to advertise themselves by
## repainting the hull (mender green / warden blue / binder amber), which fired on
## ~13% of eligible hulls and spawned roughly one V-Shrike in eight out of its own
## livery. This class briefly carried a `_roll_specialty` override to paint the
## black back on.
##
## THAT OVERRIDE IS GONE because the cause is: role is SENSOR DATA now (user,
## 2026-07-25 — Ship.classify + SystemDef.role_id_range), so nothing repaints a
## hull to announce a role and hull colour means FACTION, exclusively. The guard
## survives as a test rather than as code, since there is no longer anything to
## guard against — only something to notice if it ever comes back.


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
