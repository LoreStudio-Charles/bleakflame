class_name JinxField
extends Node2D
## Privateer "JINX Evasion Protocol" — the outlaw answer to Guardian's Bulwark.
## Where Bulwark SOAKS a spike, JINX makes the spike MISS: every ally in radius
## flies a smaller profile for a few seconds. Same job (survive the burst),
## opposite method — mitigation vs avoidance.
##
## DOUBLING ALONE WOULD BE A NO-OP for most of the team: `evasion` is 0.0 on
## every AI ship (only the player's Evasion skill sets it), and 2 × 0 = 0. So the
## buff is `max(base × mult, floor)` — doubling for a skilled pilot, a flat
## profile cut for everyone else. Without the floor this ability would do nothing
## in the exact situation it exists for: covering a wing.
##
## The field OWNS the restore. It captures each ship's true base on the way in
## and puts it back on the way out — including when freed early — so a buff can
## never leak into a ship permanently. Overlapping fields (two Privateers in
## coop) refcount through metadata rather than fighting over the base value.

const BASE_META := "jinx_base"
const STACK_META := "jinx_stack"
const RING := Color(0.85, 0.55, 1.0)

var radius := 420.0
var life := 6.0
var mult := 2.0
var floor_evasion := 0.30
var cap := 0.75

var _t := 0.0
var _touched: Array[Node] = []


func _ready() -> void:
	z_index = 2
	top_level = true   # the field stays where it was thrown, it doesn't ride the caster


## Buff everyone on our side standing inside the radius RIGHT NOW. Deliberately
## a snapshot, not a lingering aura: you throw it when the burst is coming, and
## flying into it late doesn't retroactively save you.
func apply_to_allies(origin: Vector2, groups: Array) -> void:
	global_position = origin
	for grp in groups:
		for ally in get_tree().get_nodes_in_group(grp):
			if ally in _touched or not (ally is BuildShip) or ally.dead:
				continue
			if origin.distance_to(ally.global_position) > radius:
				continue
			_buff(ally)
			_touched.append(ally)


func _buff(ally: Node) -> void:
	var base: float = ally.evasion
	if ally.has_meta(BASE_META):
		base = float(ally.get_meta(BASE_META))       # already jinxed — never re-base off a buffed value
	else:
		ally.set_meta(BASE_META, base)
	ally.set_meta(STACK_META, int(ally.get_meta(STACK_META, 0)) + 1)
	ally.evasion = minf(cap, maxf(base * mult, floor_evasion))


func _release(ally: Node) -> void:
	if not is_instance_valid(ally) or not ally.has_meta(BASE_META):
		return
	var stack := int(ally.get_meta(STACK_META, 1)) - 1
	if stack > 0:
		ally.set_meta(STACK_META, stack)
		return                                        # another field still holds it
	ally.evasion = float(ally.get_meta(BASE_META))
	ally.remove_meta(BASE_META)
	ally.remove_meta(STACK_META)


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _exit_tree() -> void:
	for ally in _touched:
		_release(ally)
	_touched.clear()


func _draw() -> void:
	var a := 1.0 - _t / life
	# a scatter of skewed rings — the shimmer of shots going wide
	for i in 3:
		var r := radius * (0.72 + 0.14 * i) * (0.96 + 0.04 * sin(_t * 5.0 + i))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(RING, 0.20 * a), 1.5)
	draw_circle(Vector2.ZERO, radius, Color(RING, 0.05 * a))
