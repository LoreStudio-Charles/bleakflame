class_name MineableAsteroid
extends StaticBody2D
## A rock that might be worth something. Contents are HIDDEN until surveyed
## with a scanner — sensors turn prospecting from gambling into geology.
## Any weapon chips rock at a fraction of its damage; a mining laser's
## mining_power extracts at full rate. Ore pops free as commodity pickups
## through the normal loot pipeline. Exhausted (or pulverized) rocks crumble.
##
## Doubles as terrain: asteroids block EVERY faction's projectiles, so a
## belt is cover — for you and for the pirates hunting you.

const ORE_COST := 14.0        # mining-power points per ore unit freed
const CHIP_FRACTION := 0.06   # combat damage -> mining power conversion

var ore_type := ""            # "" = barren
var ore_units := 0
var surveyed := false
var hit_radius := 14.0
var _mine_bank := 0.0
var _chip_hp := 70.0
var _flash := 0.0
var _sprite: Sprite2D


static func load_pool(dir_path := "res://assets/den/asteroids") -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		var file_name := f.trim_suffix(".import")
		if file_name.ends_with(".png"):
			var path := "%s/%s" % [dir_path, file_name]
			if ResourceLoader.exists(path):
				out.append(load(path))
	return out


static func create(texture: Texture2D, pos: Vector2, scale_mult: float,
		type: String, units: int) -> MineableAsteroid:
	var rock := MineableAsteroid.new()
	rock.position = pos
	rock.ore_type = type
	rock.ore_units = units
	rock._sprite = Sprite2D.new()
	rock._sprite.texture = texture
	rock._sprite.rotation = randf() * TAU
	rock._sprite.scale = Vector2.ONE * scale_mult
	rock.hit_radius = texture.get_width() * 0.36 * scale_mult
	return rock


func _ready() -> void:
	add_to_group("scannable")
	add_to_group("asteroids")
	add_child(_sprite)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = hit_radius
	collision.shape = shape
	add_child(collision)


func hit(damage: float, mining_power: float) -> void:
	var power := maxf(mining_power, damage * CHIP_FRACTION)
	_sprite.modulate = Color(1.5, 1.4, 1.2)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	if ore_units > 0:
		_mine_bank += power
		while _mine_bank >= ORE_COST and ore_units > 0:
			_mine_bank -= ORE_COST
			ore_units -= 1
			LootPickup.spawn_commodity(get_parent(), global_position, ore_type)
			Sfx.play_at("hit", global_position, -14.0, 0.7)
			# Aurite rock sometimes holds fused artifact fragments — but only
			# while a discovery chain is actively hunting them.
			if ore_type == "aurite_ore" and randf() < 0.35 \
					and Research.fragment_hunt_active("cinder_fragment"):
				LootPickup.spawn_commodity(get_parent(), global_position, "cinder_fragment")
		if ore_units <= 0:
			_crumble()
	else:
		_chip_hp -= power
		if _chip_hp <= 0.0:
			_crumble()


func survey_text() -> String:
	if ore_type == "" or ore_units <= 0:
		return "barren rock"
	return "%s x%d" % [TradeGoods.display_name(ore_type), ore_units]


func _crumble() -> void:
	Sfx.play_at("explosion", global_position, -14.0, 1.6)
	var burst := CPUParticles2D.new()
	burst.position = global_position
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 14
	burst.lifetime = 0.5
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 110.0
	burst.color = Color(0.55, 0.48, 0.4)
	get_parent().add_child(burst)
	burst.finished.connect(burst.queue_free)
	queue_free()
