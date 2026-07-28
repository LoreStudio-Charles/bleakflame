class_name PirateDen
extends Node2D

## How much room AI ships give this thing (BuildShip.separation_dir):
## rust-dressed sprawl.
var avoid_radius := 380.0
## The Rust Shoal: a scrap-built pirate station squatting inside its own
## asteroid shoal off the trade lane. The rocks are the fiction — cover,
## salvage, and the reason charts route traffic around this patch of dark.
##
## Drop-in art, no code changes (same convention as ships/audio):
##   assets/den/pirate_station.png   — the den itself (replaces placeholder)
##   assets/den/asteroids/*.png      — variant pool scattered as the shoal
## Placeholder dressing (rust-tinted station habs, vector rocks) renders
## until the art lands. Guns are real; structure not yet destructible —
## assaulting the den is future mission content.
##
## Deliberately NOT a radar landmark: nav charts don't mark pirate dens.
## It appears sensor-gated, like any contact. Finding the Shoal is the point.

const STATION_ART := "res://assets/den/pirate_station.png"
const ASTEROID_DIR := "res://assets/den/asteroids"
## Fixed seed: the Shoal is a place, so its rocks stay where they were.
const FIELD_SEED := 0xB1EAC0
const ASTEROID_COUNT := 16

## The berth outlaws put down at — a ShoalPad (gated on Standing.shoal_open()).
## Exposed like Station.pad so flight_test can reach it for E-dock + the screen.
var pad: ShoalPad
var fallen := false

func _ready() -> void:
	add_to_group("structures")
	add_to_group("pirate_dens")
	_build_station()
	_build_shoal()

	pad = ShoalPad.new()
	pad.position = Vector2(170, 0)   # a slot mouth clear of the den's collision hull
	add_child(pad)

	var body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 120.0   # matches the 160px station art at 2x
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

	# Junker emplacements: short fangs. The den bites if you linger close,
	# but a fast ship can graze the Shoal and live to tell the den's position.
	for offset in [Vector2(95, 60), Vector2(-105, -70)]:
		var turret := StationTurret.create(
			"res://data/components/weapons/junker_slugthrower.tres",
			StationTurret.TargetMode.NEAREST, "player_team")
		turret.position = offset
		add_child(turret)


## The dark takes the Shoal: the lights die and the emplacements go cold. A
## VISUAL death for the falling-Shoal set-piece — structure still isn't
## destructible, this just dresses the moment Krayt's home is unmade.
func go_dark() -> void:
	if fallen:
		return
	fallen = true
	create_tween().tween_property(self, "modulate", Color(0.2, 0.18, 0.24), 0.9)
	for c in get_children():
		if c is StationTurret:
			c.queue_free()   # the fangs go quiet


func _build_station() -> void:
	if ResourceLoader.exists(STATION_ART):
		var sprite := Sprite2D.new()
		sprite.texture = load(STATION_ART)
		sprite.scale = Vector2(2, 2)   # station-family art renders at 2x
		add_child(sprite)
		return
	# Placeholder: home-station habs gone to rust, welded at bad angles.
	var rust := Color(0.72, 0.5, 0.38)
	var dressing := [
		["res://assets/station/hab_a.png", Vector2.ZERO, 0.35],
		["res://assets/station/hab_b.png", Vector2(150, -90), -0.8],
		["res://assets/station/hab_a.png", Vector2(-130, 110), 2.4],
	]
	for cfg in dressing:
		if not ResourceLoader.exists(cfg[0]):
			continue
		var sprite := Sprite2D.new()
		sprite.texture = load(cfg[0])
		sprite.position = cfg[1]
		sprite.rotation = cfg[2]
		sprite.scale = Vector2(2, 2)
		sprite.modulate = rust
		add_child(sprite)


## An annulus of rock around the den. Big variants become MINEABLE — and
## rich: the Shoal's ore beats the Drift Belt's precisely because mining
## here means doing geology inside a pirate den. Danger is the paycheck.
func _build_shoal() -> void:
	var pool := MineableAsteroid.load_pool()
	var rng := RandomNumberGenerator.new()
	rng.seed = FIELD_SEED
	# Track placed rocks so none lands on another (spacing by visual radius).
	var placed: Array[Dictionary] = []
	for i in ASTEROID_COUNT:
		if pool.is_empty():
			var pr := 30.0
			var ppos := _clear_spot(rng, placed, pr)
			placed.append({"pos": ppos, "r": pr})
			_add_placeholder_rock(ppos, rng)
			continue
		var texture: Texture2D = pool[rng.randi() % pool.size()]
		var big := texture.get_width() >= 48
		if big:
			var roll := rng.randf()
			var type := ""
			var units := 0
			if roll < 0.30:
				type = "ferrite_ore"; units = rng.randi_range(4, 7)
			elif roll < 0.60:
				type = "cobalt_ore"; units = rng.randi_range(3, 5)
			elif roll < 0.80:
				type = "aurite_ore"; units = rng.randi_range(2, 3)
			var r: float = texture.get_width() * 0.46 * 2.0 + 12.0
			var pos := _clear_spot(rng, placed, r)
			placed.append({"pos": pos, "r": r})
			add_child(MineableAsteroid.create(texture, pos, 2.0, type, units))
		else:
			var spread_mult := rng.randf_range(1.0, 2.0)
			var r: float = texture.get_width() * 0.46 * spread_mult + 10.0
			var pos := _clear_spot(rng, placed, r)
			placed.append({"pos": pos, "r": r})
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.position = pos
			sprite.rotation = rng.randf() * TAU
			sprite.scale = Vector2.ONE * spread_mult
			add_child(sprite)


## Reject-sample a spot in the shoal's annulus that clears every rock already
## placed (spacing by radius). The field dwarfs its rocks, so a slot is found
## in a few tries; falls back to the last candidate if somehow crowded.
func _clear_spot(rng: RandomNumberGenerator, placed: Array, r: float) -> Vector2:
	var pos := Vector2.ZERO
	for _attempt in 48:
		pos = Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(300.0, 760.0)
		var clear := true
		for p in placed:
			if pos.distance_to(p.pos) < r + float(p.r):
				clear = false
				break
		if clear:
			break
	return pos


func _add_placeholder_rock(pos: Vector2, rng: RandomNumberGenerator) -> void:
	var rock := Polygon2D.new()
	var points := PackedVector2Array()
	var r := rng.randf_range(10.0, 26.0)
	for i in 8:
		points.append(Vector2.RIGHT.rotated(TAU * i / 8.0) * r * rng.randf_range(0.7, 1.15))
	rock.polygon = points
	rock.position = pos
	rock.rotation = rng.randf() * TAU
	rock.color = Color(0.38, 0.34, 0.3)
	add_child(rock)
