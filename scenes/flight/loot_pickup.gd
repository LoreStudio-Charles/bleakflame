class_name LootPickup
extends Node2D
## A component adrift in space, drawn in its grade color. Magnetizes toward
## the player over the last stretch (only if they can actually carry it) and
## goes into cargo on contact.

const PICKUP_RADIUS := 26.0
const MAGNET_RADIUS := 100.0
const MAGNET_ACCEL := 240.0
const LIFETIME := 120.0

var def: ComponentDef          # component payload...
var commodity := ""            # ...or a commodity key (exactly one is set)
var _velocity := Vector2.ZERO
var _age := 0.0
## Seconds before this pickup arms — jettisoned cargo sets this so it drifts
## clear instead of magnetizing straight back into the hold you just cleared.
var arm_delay := 0.0
var hit_radius := 14.0         # for RMB salvage / hover targeting


func _ready() -> void:
	add_to_group("loot")


static func spawn(parent: Node, pos: Vector2, component: ComponentDef) -> LootPickup:
	var p := _spawn_base(parent, pos)
	p.def = component
	return p


static func spawn_commodity(parent: Node, pos: Vector2, key: String) -> LootPickup:
	var p := _spawn_base(parent, pos)
	p.commodity = key
	return p


static func _spawn_base(parent: Node, pos: Vector2) -> LootPickup:
	var p := LootPickup.new()
	p.global_position = pos + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(4.0, 18.0)
	p._velocity = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(20.0, 70.0)
	parent.add_child(p)
	return p


func payload_mass() -> float:
	return def.mass if def != null else TradeGoods.unit_mass(commodity)


func payload_name() -> String:
	return def.display_name if def != null else TradeGoods.display_name(commodity)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return

	var player := get_tree().get_first_node_in_group("player_ship") as TestShip
	if player != null and not player.dead and player.docked_at == null and _age >= arm_delay:
		var to_player := player.global_position - global_position
		var dist := to_player.length()
		if player.can_carry_mass(payload_mass()):
			if dist <= PICKUP_RADIUS:
				if def != null:
					player.add_cargo(def)
				else:
					player.add_commodity(commodity, 1)
				Sfx.play("pickup", -10.0)
				queue_free()
				return
			if dist <= MAGNET_RADIUS:
				_velocity += to_player.normalized() * MAGNET_ACCEL * delta
		elif dist <= PICKUP_RADIUS:
			# Full hold, right on top of it — TELL the player, don't fail mute.
			player.note_hold_full()

	_velocity *= exp(-0.8 * delta)
	position += _velocity * delta
	queue_redraw()


func _draw() -> void:
	var color := Grades.color(def.grade) if def != null else Color(0.92, 0.82, 0.5)
	# Blink during the last 10 seconds of drift.
	if LIFETIME - _age < 10.0 and fmod(_age, 0.5) > 0.25:
		color = Color(color, 0.25)
	var pulse := 4.5 + sin(_age * 4.0) * 1.2
	if def != null:
		draw_colored_polygon(PackedVector2Array([
			Vector2(pulse, 0), Vector2(0, -pulse), Vector2(-pulse, 0), Vector2(0, pulse)]), color)
		# Affixed salvage glints amber — worth turning around for.
		if not def.affix_ids.is_empty():
			draw_arc(Vector2.ZERO, pulse + 7.5, _age * 2.0, _age * 2.0 + TAU * 0.6, 16,
				Color(0.95, 0.72, 0.35, 0.7), 1.4)
	else:
		# Commodity crates are square so they read differently from components.
		draw_rect(Rect2(-pulse * 0.8, -pulse * 0.8, pulse * 1.6, pulse * 1.6), color)
	draw_arc(Vector2.ZERO, pulse + 4.0, 0, TAU, 16, Color(color, 0.45), 1.2)
