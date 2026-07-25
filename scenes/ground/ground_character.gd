class_name GroundCharacter
extends CharacterBody2D
## Reusable top-down actor for the ground/colony mode. Loads its look from a banked
## PixelLab character folder (rotations/<dir>.png + an animations/<group>/<dir>/*.png
## walk cycle) via raw Image.load, so freshly dropped-in art works with NO Godot import
## step (the same drop-in philosophy as hull sprites). Faces one of four cardinals from
## its travel vector — west mirrors east when that art is absent (our generation rule) —
## and plays walk vs idle. Drives itself toward a point (move_to) for click-to-move, or
## sits idle. Missing art degrades to a single frame, never crashes.

const DIRS := ["south", "north", "east", "west"]

## THE SUN — one light, shared by every projected shadow (characters AND buildings). A shadow
## is a dark, transparent copy of the sprite, flipped + squashed + skewed so it lies on the
## ground; SCALE.y is its LENGTH (low sun = longer), SKEW is its LEAN (the sun's bearing).
## Change these two and the whole town's shadows rotate + stretch together — the seam for a
## real fake-lighting / day-night pass (animate them and every shadow follows).
const SHADOW_TINT := Color(0.06, 0.05, 0.10, 0.45)
const SHADOW_SCALE := Vector2(1.0, -0.55)   # x = 1.0 so the base width MATCHES (corners line up); y flips + squashes (= length)
const SHADOW_SKEW := 0.5                       # radians lean (= the sun's bearing)
## Lift the shadow's start up onto the sprite's true base by this FRACTION of the sprite's
## visible height (art usually has a soft margin below the base, so the raw pivot sits low).
## One value auto-scales across sizes — a person vs a big building. Tune by eye.
const SHADOW_ANCHOR_PCT := 0.22

var speed := 175.0
var _anim: AnimatedSprite2D
var _shadow: AnimatedSprite2D
var _facing := "south"
var _target := Vector2.ZERO
var _has_target := false
var _move_dir := Vector2.ZERO   # per-frame velocity intent (WASD / hold-mouse), set by the controller
var _have_dir := {}  # dir -> bool: real art present for this facing


func setup(char_dir: String) -> void:
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = _build_frames(char_dir)
	# Anchor the NODE exactly at the feet (bottom of the sprite = origin) so y-sorting AND
	# the shadow's flip pivot both key off the true ground-contact point — the shadow then
	# starts right under the sprite instead of drifting off.
	var h := 68
	var t := _anim.sprite_frames.get_frame_texture("idle_south", 0)
	if t != null:
		h = t.get_height()
	_anim.offset = Vector2(0, -h * 0.5)
	# The projected shadow: a dark, squashed, skewed copy behind the sprite, locked to its
	# frame below (so it animates for free). Added first, so it draws behind.
	_shadow = AnimatedSprite2D.new()
	_shadow.sprite_frames = _anim.sprite_frames
	_shadow.offset = _anim.offset
	_shadow.scale = SHADOW_SCALE
	_shadow.skew = SHADOW_SKEW
	_shadow.modulate = SHADOW_TINT
	_shadow.position = Vector2(0, -h * SHADOW_ANCHOR_PCT)   # lift onto the true base
	add_child(_shadow)   # added FIRST, so it draws behind the main sprite (no z_index vs y-sort fight)
	add_child(_anim)
	# Collide with buildings (layer 1) but not with each other, so nobody walks through a
	# wall and nobody shoves anybody. A small circle at the feet.
	collision_layer = 2
	collision_mask = 1
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 13.0
	col.shape = shape
	add_child(col)
	_apply_anim(false)


func move_to(p: Vector2) -> void:
	_target = p
	_has_target = true


## Continuous drive from a controller (WASD or hold-mouse). Pass ZERO to stand still.
## Overrides any move_to target while non-zero.
func move_dir(d: Vector2) -> void:
	_move_dir = d
	if d != Vector2.ZERO:
		_has_target = false


func stop() -> void:
	_has_target = false
	velocity = Vector2.ZERO


func is_moving() -> bool:
	return _has_target


func face(dir: String) -> void:
	if dir in DIRS:
		_facing = dir
		_apply_anim(_has_target)


func _physics_process(_delta: float) -> void:
	var moving := false
	if _move_dir != Vector2.ZERO:
		velocity = _move_dir.normalized() * speed
		move_and_slide()
		_face_from(velocity)
		moving = true
	elif _has_target:
		var to := _target - global_position
		if to.length() <= 6.0:
			_has_target = false
			velocity = Vector2.ZERO
		else:
			velocity = to.normalized() * speed
			move_and_slide()
			_face_from(velocity)
			moving = true
	_apply_anim(moving)
	if _shadow != null:
		_shadow.frame = _anim.frame   # lock the shadow to the current animation frame


func _face_from(v: Vector2) -> void:
	if absf(v.x) > absf(v.y):
		_facing = "east" if v.x > 0.0 else "west"
	else:
		_facing = "south" if v.y > 0.0 else "north"


func _apply_anim(moving: bool) -> void:
	if _anim == null:
		return
	# west mirrors east when we never generated a west sheet
	var name := _facing
	var flip := false
	if _facing == "west" and not _have_dir.get("west", false) and _have_dir.get("east", false):
		name = "east"
		flip = true
	_anim.flip_h = flip
	var want := ("walk_" if moving else "idle_") + name
	if _anim.animation != want:
		_anim.play(want)
	if _shadow != null:
		_shadow.flip_h = flip
		if _shadow.animation != want:
			_shadow.play(want)


func _build_frames(base: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var group := _first_subdir(base + "/animations")
	for d in DIRS:
		var idle_tex := _tex("%s/rotations/%s.png" % [base, d])
		var walk: Array = []
		if group != "":
			walk = _frames_in("%s/%s" % [group, d])
		_have_dir[d] = idle_tex != null or not walk.is_empty()

		sf.add_animation("idle_" + d)
		sf.set_animation_loop("idle_" + d, true)
		sf.set_animation_speed("idle_" + d, 1.0)
		if idle_tex != null:
			sf.add_frame("idle_" + d, idle_tex)
		elif not walk.is_empty():
			sf.add_frame("idle_" + d, walk[0])
		else:
			sf.add_frame("idle_" + d, _placeholder())

		sf.add_animation("walk_" + d)
		sf.set_animation_loop("walk_" + d, true)
		sf.set_animation_speed("walk_" + d, 8.0)
		if not walk.is_empty():
			for t in walk:
				sf.add_frame("walk_" + d, t)
		else:
			sf.add_frame("walk_" + d, sf.get_frame_texture("idle_" + d, 0))
	return sf


## --- file helpers (res:// DirAccess works when running from source) ---

static func _first_subdir(root: String) -> String:
	var da := DirAccess.open(root)
	if da == null:
		return ""
	for sub in da.get_directories():
		return root + "/" + sub
	return ""


static func _frames_in(dirpath: String) -> Array:
	var out: Array = []
	var da := DirAccess.open(dirpath)
	if da == null:
		return out
	var files := da.get_files()
	files.sort()
	for f in files:
		if f.to_lower().ends_with(".png"):
			var t := _tex(dirpath + "/" + f)
			if t != null:
				out.append(t)
	return out


static func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is Texture2D:
			return r
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null


static func _placeholder() -> Texture2D:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.2, 0.8))
	return ImageTexture.create_from_image(img)
