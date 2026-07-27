class_name Wreck
extends Node2D
## WHAT IS LEFT OF A SHIP — burnt, tumbling, and still there when you come back.
##
## WHY (user, 2026-07-27): "We don't even show wrecks now and we should. Instead of just
## showing loot in space, ships ought to explode and leave spinning wreckage for a long
## time."
##
## AND IT MAKES A PIECE OF CANON VISIBLE FOR THE FIRST TIME. `BuildShip.devour()` already
## says the Cinderweb leaves its prey "gone TRACELESS — no wreck, no cargo, no rap sheet" —
## and the starter campaign turns on exactly that contrast: pirates leave evidence, the
## beast leaves none, which is what Voss's "no debris" report MEANS. Until now neither left
## anything, so the distinction existed only in dialogue. A lane strewn with the Widows's
## leavings and one clean empty patch where a hauler used to be is the whole horror, shown.
##
## PURELY VISUAL. No collider: debris you fly through is forgiving, and the avoidance pass
## (separation_dir, look-ahead) would otherwise have to learn about a new class of obstacle
## that accumulates. The loot pickup remains the thing you interact with; this is the body.

## Wrecks persist for a LONG time — the point is coming back and finding it. They fade over
## the last stretch rather than popping.
const LIFETIME := 420.0
const FADE := 45.0
## A hard ceiling across the whole scene: a long session with a busy lane would otherwise
## accumulate without limit. The OLDEST goes first, so the freshest fight is always the one
## still written on the sky.
const MAX_WRECKS := 48

## BURNT, BUT STILL READABLE. The first value (0.34) was a realistic scorch and multiplied
## into the hull sprite it vanished — space is black, so a dark wreck against it is a smudge
## you cannot identify, which defeats the point of adopting the hull's own art. Lifted until
## a Goshawk hulk is recognisably a Goshawk, and warmed slightly so it reads as burnt metal
## rather than as a grey ship somebody turned the lights off in.
const BURNT := Color(0.62, 0.53, 0.48)

var _age := 0.0
var _spin := 0.0
var _drift := Vector2.ZERO
var _sprite: Sprite2D
var _poly: Polygon2D


## Leave the remains of `ship` where it died. Duck-typed on purpose: it reads a texture and
## a velocity if they are there and degrades to a silhouette if they are not, so a hull with
## no art still leaves something.
static func spawn(ship: Node2D) -> Wreck:
	var parent := ship.get_parent()
	if parent == null:
		return null
	var w := Wreck.new()
	w.global_position = ship.global_position
	w.rotation = ship.rotation
	# TUMBLING, and carrying the momentum it died with — a wreck that stops dead where it
	# was hit reads as a prop. Slower spin for heavier hulls.
	var mass := 40.0
	var st = ship.get("stats")
	if st != null and typeof(st) == TYPE_DICTIONARY:
		mass = maxf(10.0, float(st.get("mass", 40.0)))
	w._spin = randf_range(-1.0, 1.0) * (60.0 / mass) * randf_range(0.6, 1.6)
	var vel = ship.get("velocity")
	if vel != null and typeof(vel) == TYPE_VECTOR2:
		# A fraction of what it was doing. Too much and the wreck leaves the scene of its
		# own death, which is exactly where it wants to be found.
		w._drift = (vel as Vector2) * 0.18
	w._adopt_look(ship)
	parent.add_child(w)
	w.add_to_group("wrecks")
	_cull(w.get_tree())
	return w


## Keep the scene's wreck count under the ceiling, oldest first.
static func _cull(tree: SceneTree) -> void:
	if tree == null:
		return
	var all := tree.get_nodes_in_group("wrecks")
	if all.size() <= MAX_WRECKS:
		return
	var oldest: Wreck = null
	for n in all:
		var w := n as Wreck
		if w != null and (oldest == null or w._age > oldest._age):
			oldest = w
	if oldest != null:
		# LEAVE THE GROUP FIRST. queue_free() is deferred to the end of the frame, so the
		# node stays countable until then — and several ships dying in the same frame (a
		# convoy losing its escort, a bomb) each counted the same doomed wrecks and let the
		# field run past its ceiling. Removing from the group makes the cull take effect now.
		oldest.remove_from_group("wrecks")
		oldest.queue_free()


## Take the dead ship's own art so a Goshawk wreck is recognisably a Goshawk — which is
## what lets a pirate hull lying in Widows country tell you who lost that fight.
func _adopt_look(ship: Node2D) -> void:
	var src := ship.get("_hull_sprite") as Sprite2D
	if src != null and src.texture != null:
		_sprite = Sprite2D.new()
		_sprite.texture = src.texture
		_sprite.scale = src.scale
		_sprite.rotation = src.rotation
		_sprite.self_modulate = BURNT
		add_child(_sprite)
		return
	# No art yet: reuse the silhouette the ship was drawing, burnt down.
	var shape := ship.get("_hull_visual") as Polygon2D
	if shape != null and shape.polygon.size() > 2:
		_poly = Polygon2D.new()
		_poly.polygon = shape.polygon
		_poly.color = BURNT
		add_child(_poly)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	rotation += _spin * delta
	global_position += _drift * delta
	_drift = _drift.lerp(Vector2.ZERO, 0.4 * delta)   # space is not viscous, but the lane is busy
	var left := LIFETIME - _age
	if left < FADE:
		modulate.a = clampf(left / FADE, 0.0, 1.0)
