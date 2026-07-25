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
var _groups: Array[String] = []   # animation groups this character's bank carries
## Combat stance: "" = locomotion (walk/idle), else a pose group name ("aiming",
## "kneeling"). While set, the pose animation overrides walk/idle and the weapon
## anchors come from that group's anchor scene. [SPACE] kneel / engaging sets these.
var pose := ""

## ---- COMBAT (docs/ground_combat.md) ----
## The doc's damage order, verbatim: raw -> BARRIER soaks -> remainder x (1 - MITIGATION)
## -> HEALTH. Character armor MITIGATES (never depletes); barrier regens out of combat.
## Kneeling ([SPACE]) adds COVER_MITIGATION on top, multiplicatively.
signal died
signal damaged(amount: float)

const COVER_MITIGATION := 0.25
const BARRIER_REGEN_DELAY := 4.0   # seconds out of combat before the emitter rebuilds
const BARRIER_REGEN_RATE := 8.0

var team := ""                    # "player_team" / "hostile" — "" = non-combatant
var max_health := 100.0
var health := 100.0
var max_barrier := 0.0            # > 0 only with an emitter fitted
var barrier := 0.0
var mitigation := 0.0             # from worn PLATING (0..~0.6); SuitDef wires in later
var dead := false
## Who we're fighting. Assigning one SUBSCRIBES to its death — the ground half of the
## same mechanism the ship uses (Ship._hook_death), for the same reason: "my target is
## gone" cannot tell a KILL from a deselect, and in Godot 4 a freed reference even
## compares equal to null. The target announcing its own death removes the guesswork.
var combat_target: GroundCharacter = null:
	set(value):
		# Only skip the work when BOTH are real and identical — a freed target compares
		# equal to a null value, and bailing there would strand the freed reference.
		if is_instance_valid(value) and is_instance_valid(combat_target) and value == combat_target:
			return
		_unhook_death(combat_target)
		combat_target = value
		_hook_death(value)
var auto_attack := false          # [Q] weapons-free / RMB-engage sets this
## v1 weapon combat block: {damage, range, cooldown, melee}. Set by equip (ranged) or
## set_melee (claws). Replaced by real ground WeaponDefs when the gear schema lands.
var attack_spec := {}
## The CELL — techniques spend it (docs/ground_combat.md). Regenerates always; MEDITATE
## dumps the whole rig into recharge for a burst (the Going-Dark mirror).
var max_energy := 0.0
var energy := 0.0
var energy_recharge := 0.0
## Live technique effects, all timed and all read by the systems they modify:
##   _stun_t     — reeling: no attacking, no moving (Kick Sand)
##   _haste_t    — a speed burst (Second Wind)
##   _brace_t/_brace_mit — temporary mitigation ON TOP of worn plating (Brace)
var _stun_t := 0.0
var _haste_t := 0.0
var _brace_t := 0.0
var _brace_mit := 0.0
var meditating := false
var _attack_cd := 0.0
var _since_hit := 999.0
var _action_until := 0.0          # a one-shot action anim (Attack/Death) owns the frames


## The doc's order. Returns damage that actually reached HEALTH.
## RETALIATION TARGETING: the attacker becomes this character's target IF AND ONLY IF
## they had none (a fight in progress is never re-aimed by a flank hit). Target only —
## auto_attack is untouched, so a select never becomes a shot uninvited.
func take_damage(raw: float, attacker: GroundCharacter = null) -> float:
	if dead:
		return 0.0
	if attacker != null and combat_target == null and is_instance_valid(attacker) 			and not attacker.dead and attacker.team != team:
		combat_target = attacker
	_since_hit = 0.0
	var after_barrier := raw
	if barrier > 0.0:
		var soak := minf(barrier, after_barrier)
		barrier -= soak
		after_barrier -= soak
	if after_barrier <= 0.0:
		damaged.emit(0.0)
		return 0.0
	var mit := clampf(mitigation + (COVER_MITIGATION if pose == "kneeling" else 0.0)
		+ (_brace_mit if _brace_t > 0.0 else 0.0), 0.0, 0.85)
	var taken := maxf(1.0, after_barrier * (1.0 - mit))
	health -= taken
	damaged.emit(taken)
	_flash_hit()
	if health <= 0.0:
		die()
	return taken


func die() -> void:
	if dead:
		return
	dead = true
	auto_attack = false
	combat_target = null
	stop()
	died.emit()
	# A Death animation group holds the fall; without one the sprite just stops.
	if _anim.sprite_frames.has_animation("pose_death_" + _facing):
		play_action("death", 7.0, false)
	# THE SHADOW DIES WITH THEM (user: corpses looked airborne). The projected shadow is
	# a flipped copy of a STANDING body — flip a lying corpse and you get a phantom
	# standing shadow beside it. A flat body on the ground casts nothing at this
	# stylization, so the shadow fades out over the fall.
	if _shadow != null:
		var tw := create_tween()
		tw.tween_property(_shadow, "modulate:a", 0.0, 0.9)


func set_melee(damage: float, reach: float, cooldown: float) -> void:
	attack_spec = {"damage": damage, "range": reach, "cooldown": cooldown, "melee": true}


## ---- TECHNIQUE EFFECTS ----
## The effects themselves live HERE, on the character, not in the town's dispatch — so
## a scrit shaman or an allied NPC applies the identical effect through the identical
## call, exactly the way AI ships reuse the player's bulwark/repair (never a divergent
## copy). The town only decides WHO gets one and pays the energy.

const HASTE_MULT := 1.55


## Mend flesh — never past full, and never on the dead.
func mend(amount: float) -> float:
	if dead:
		return 0.0
	var before := health
	health = minf(max_health, health + amount)
	return health - before


## Reel: rooted and unable to attack for `secs`. Refreshes rather than stacking.
func apply_stun(secs: float) -> void:
	if dead:
		return
	_stun_t = maxf(_stun_t, secs)
	auto_attack = false
	stop()


func apply_haste(secs: float) -> void:
	_haste_t = maxf(_haste_t, secs)


## Temporary mitigation on top of worn plating (the take_damage sum clamps the total).
func apply_brace(secs: float, amount: float) -> void:
	_brace_t = maxf(_brace_t, secs)
	_brace_mit = maxf(_brace_mit, amount)


func is_stunned() -> bool:
	return _stun_t > 0.0


func is_braced() -> bool:
	return _brace_t > 0.0


func is_hasted() -> bool:
	return _haste_t > 0.0


## Spend from the cell. Returns false (and spends NOTHING) when the cell is short —
## the ship's invariant, mirrored: a refused technique costs no energy and no cooldown.
func spend_energy(amount: float) -> bool:
	if energy < amount:
		return false
	energy -= amount
	return true


## Engage a target and open fire/claws. TARGET-LOCKED resolution (design: no aiming —
## attacks resolve by stats, not geometry): in range + off cooldown = the hit lands.
func engage(target: GroundCharacter) -> void:
	combat_target = target
	auto_attack = target != null


## ---- TARGET DEATH SUBSCRIPTION (the ship's mechanism, on foot) ----
## Only a GroundCharacter is ever a combat target here, so there's one signal to watch —
## unlike space, where drones and hulls announce themselves differently.
func _hook_death(node: GroundCharacter) -> void:
	if node != null and is_instance_valid(node) and not node.died.is_connected(_on_target_died):
		node.died.connect(_on_target_died, CONNECT_ONE_SHOT)


## UNTYPED: the node being released is often the one that just died, and a typed
## parameter refuses a freed object outright rather than letting the body check it.
func _unhook_death(node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.died.is_connected(_on_target_died):
		node.died.disconnect(_on_target_died)


## THE KILL STANDS YOU DOWN (user, 2026-07-25 — the same rule in space): auto-attack
## clears the moment your target dies. Without it the lingering weapons-free state made
## the next LMB-SELECT open fire, quietly breaking "LMB never arms". Re-engaging is one
## RMB on the next foe. Only the CURRENT target is subscribed, so getting here IS the kill.
func _on_target_died() -> void:
	auto_attack = false
	if pose == "aiming":
		set_pose("")


## Meditate ([K], the Going-Dark mirror): the rig powers down into the cell. Energy
## floods back at MEDITATE_REGEN, but you are DEFENSELESS — no attacking, and the mend
## you can do is the one thing cold circuits allow: re-preparing the bus.
const MEDITATE_REGEN := 9.0

func set_meditating(on: bool) -> void:
	if dead:
		return
	meditating = on
	if on:
		auto_attack = false
		stop()
	set_pose("kneeling" if on else "")


func _tick_combat(delta: float) -> void:
	_since_hit += delta
	for t in ["_stun_t", "_haste_t", "_brace_t"]:
		if float(get(t)) > 0.0:
			set(t, maxf(0.0, float(get(t)) - delta))
	if barrier < max_barrier and _since_hit > BARRIER_REGEN_DELAY:
		barrier = minf(max_barrier, barrier + BARRIER_REGEN_RATE * delta)
	if energy < max_energy:
		energy = minf(max_energy, energy
			+ (MEDITATE_REGEN if meditating else energy_recharge) * delta)
	if _attack_cd > 0.0:
		_attack_cd -= delta
	# Let go of something we can no longer fight. THIS RUNS BEFORE THE auto_attack GUARD
	# BELOW, and must: the death EVENT clears auto_attack the instant the target dies, so
	# housekeeping placed after that guard would never run again and the corpse would stay
	# selected forever. (Under the old polling design the same block did both jobs, which
	# hid the ordering dependency.) The STAND-DOWN itself is _on_target_died's job.
	if combat_target != null and (not is_instance_valid(combat_target) or combat_target.dead):
		combat_target = null
	if dead or meditating or _stun_t > 0.0 or not auto_attack or attack_spec.is_empty():
		return
	if combat_target == null:
		return
	var dist := global_position.distance_to(combat_target.global_position)
	if dist > float(attack_spec.range):
		return   # the CONTROLLER decides whether to close distance; we just hold fire
	# In range: face them, brace (ranged), swing/shoot on cooldown.
	_face_from(combat_target.global_position - global_position)
	if not bool(attack_spec.melee) and pose == "" :
		set_pose("aiming")
	if _attack_cd > 0.0:
		return
	_attack_cd = float(attack_spec.cooldown)
	if bool(attack_spec.melee):
		play_action("attack", 9.0, false)
	else:
		_recoil()
		# The shot you can SEE: muzzle flash + tracer + impact fleck (target-locked
		# resolution means no projectile exists — the fx IS the shot).
		ShotFx.spawn(self, muzzle_point(), combat_target.global_position + Vector2(0, -14))
		Sfx.play("pew", -14.0)
	combat_target.take_damage(float(attack_spec.damage), self)


## One-shot action animation (Attack swing, the Death fall). Owns the frames until it
## ends; Death holds its last frame forever.
func play_action(group: String, fps: float, loop: bool) -> void:
	var aname := "pose_%s_%s" % [group, _facing]
	if not _anim.sprite_frames.has_animation(aname):
		return
	_anim.sprite_frames.set_animation_loop(aname, loop)
	_anim.sprite_frames.set_animation_speed(aname, fps)
	_anim.play(aname)
	if _shadow != null and _shadow.sprite_frames.has_animation(aname):
		_shadow.sprite_frames.set_animation_loop(aname, loop)
		_shadow.play(aname)
	var frames := _anim.sprite_frames.get_frame_count(aname)
	_action_until = Time.get_ticks_msec() / 1000.0 + (frames / maxf(1.0, fps)) 		+ (999999.0 if group == "death" else 0.0)


## Brief red blink so a hit is never silent.
func _flash_hit() -> void:
	if _anim == null:
		return
	_anim.modulate = Color(1.0, 0.45, 0.45)
	var tw := create_tween()
	tw.tween_property(_anim, "modulate", Color.WHITE, 0.22)


## The weapon-layer recoil: the gun kicks back along its own axis and springs home.
func _recoil() -> void:
	if _weapon == null or not _weapon.visible:
		return
	var kick := Vector2(-2, 0).rotated(_weapon.rotation)
	var home := _weapon.position
	_weapon.position = home + kick
	var tw := create_tween()
	tw.tween_property(_weapon, "position", home, 0.1)

## ---- WEAPON DISPLAY (the hand-anchor standard; docs/ground_combat.md) ----
## The drawn weapon is a CHILD of the animation sprite, repositioned every frame from the
## character's WeaponAnchors set (hand-authored scene, else the detected/fallback table).
## `show_behind_parent` is the per-frame front/back toggle — no z_index vs y-sort fights.
var _weapon: Sprite2D
var _weapon_two_handed := false
var _anchor_sets := {}             # group name -> WeaponAnchors.load_set result
var _canvas := 68
var _char_folder := ""
## Per-FACING weapon art (user, 2026-07-25: a rotated side-profile gun doesn't read
## front-on). Keys "side"/"south"/"north" -> {tex, grip}; south/north fall back to the
## rotated side view when a variant isn't authored. Drop-in convention:
##   assets/ground/weapons/<key>.png        (side view, barrel +X — REQUIRED)
##   assets/ground/weapons/<key>_south.png  (seen from the front — optional)
##   assets/ground/weapons/<key>_north.png  (seen from behind — optional)
var _weapon_views := {}


func setup(char_dir: String) -> void:
	_char_folder = char_dir.get_file()   # "res://assets/characters/PilotM" -> "PilotM"
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
	_anim.frame_changed.connect(_sync_weapon)
	_anim.animation_changed.connect(_sync_weapon)
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


## Enter/leave a combat stance ("aiming", "kneeling", "" = stand down). Falls back
## gracefully: a character without that pose group keeps walk/idle frames (the weapon
## still aims — the body just doesn't brace).
func set_pose(p: String) -> void:
	pose = p.to_lower()
	_apply_anim(_has_target or _move_dir != Vector2.ZERO)


func _physics_process(_delta: float) -> void:
	_tick_combat(_delta)
	if dead:
		return   # the fallen neither walk nor re-animate; Death holds its last frame
	var moving := false
	# REELING (Kick Sand) or MEDITATING roots you: the whole point of both is that the
	# body is not available. Gated here, the ONE place motion happens, so no controller
	# — player, scrit or future ally — can walk out of it.
	var rooted := _stun_t > 0.0 or meditating
	var spd := speed * (HASTE_MULT if _haste_t > 0.0 else 1.0)
	if rooted:
		velocity = Vector2.ZERO
	elif _move_dir != Vector2.ZERO:
		velocity = _move_dir.normalized() * spd
		move_and_slide()
		_face_from(velocity)
		moving = true
	elif _has_target:
		var to := _target - global_position
		if to.length() <= 6.0:
			_has_target = false
			velocity = Vector2.ZERO
		else:
			velocity = to.normalized() * spd
			move_and_slide()
			_face_from(velocity)
			moving = true
	# A one-shot action (Attack swing) owns the frames until it finishes.
	if Time.get_ticks_msec() / 1000.0 < _action_until:
		pass
	else:
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
	if pose != "" and _anim.sprite_frames.has_animation("pose_%s_%s" % [pose, name]):
		want = "pose_%s_%s" % [pose, name]
	if _anim.animation != want:
		_anim.play(want)
	if _shadow != null:
		_shadow.flip_h = flip
		if _shadow.animation != want:
			_shadow.play(want)


## Show a weapon in this character's hands. `tex` = the SIDE view (grip at `grip` px,
## barrel/blade pointing +X); optional per-facing variants come via equip_weapon_views.
## Two-handed weapons use the carry-pose anchors.
func equip_weapon(tex: Texture2D, grip: Vector2, two_handed := false) -> void:
	equip_weapon_views({"side": {"tex": tex, "grip": grip}}, two_handed)


## Full form: views = {"side": {tex, grip}, "south": {...}?, "north": {...}?}. Facing
## south/north uses its authored variant UNROTATED when present (a front-on gun is its
## own drawing, not a rotated profile); missing variants fall back to the rotated side.
func equip_weapon_views(views: Dictionary, two_handed := false) -> void:
	if _weapon == null:
		_weapon = Sprite2D.new()
		_weapon.centered = false
		_anim.add_child(_weapon)   # child of the anim: inherits its offset space + flip toggle
	_weapon_views = views
	_weapon_two_handed = two_handed
	var t := _anim.sprite_frames.get_frame_texture("idle_south", 0)
	if t != null:
		_canvas = t.get_width()
	_weapon.visible = true
	_sync_weapon()


func unequip_weapon() -> void:
	if _weapon != null:
		_weapon.visible = false


## Where the barrel ends, in WORLD space — the drawn weapon's own tip (its grip pixel
## sits at the sprite's local origin, barrel +X; to_global carries rotation + the anim's
## flip). Chest height when nothing is drawn.
func muzzle_point() -> Vector2:
	if _weapon != null and _weapon.visible and _weapon.texture != null:
		return _weapon.to_global(Vector2(_weapon.texture.get_width() + _weapon.offset.x, 0))
	return global_position + Vector2(0, -14)


## Place the weapon for the CURRENT (direction, frame) from the anchor table. Runs on
## every frame/animation change; cheap (a dict lookup + a few sets).
func _sync_weapon() -> void:
	if _weapon == null or not _weapon.visible:
		return
	# "walk_east"/"idle_east" -> east; "pose_aiming_east" -> east via its pose group.
	# Mirrored west plays "east" flipped, and the anim's own flip_h flips our child
	# sprite with it, so we read the PLAYED name.
	var played := str(_anim.animation)
	var d := played.get_slice("_", 1)
	var group := "Walking"
	if played.begins_with("pose_"):
		var pname := played.get_slice("_", 1)
		d = played.get_slice("_", 2)
		for g in _groups:
			if g.to_lower() == pname:
				group = g
	# Each group has its own anchor scene (an aiming stance holds hands elsewhere than a
	# walk); missing scene = the fallback table, so an unauthored pose still carries.
	if not _anchor_sets.has(group):
		_anchor_sets[group] = WeaponAnchors.load_set(_char_folder, group, _canvas)
	var anchors: Dictionary = _anchor_sets[group]
	if not anchors.has(d):
		return
	var frames: Array = anchors[d]
	var f: int = clampi(_anim.frame, 0, frames.size() - 1)
	if played.begins_with("idle_"):
		f = 0   # idle poses ride the first walk frame's anchor (close enough until authored)
	var style := "two" if _weapon_two_handed else "one"
	var entry: Dictionary = frames[f].get(style, {})
	if entry.is_empty():
		return
	# Pick the art for this facing: an authored front/back variant draws UNROTATED
	# (it already depicts that view); otherwise the side view rotates per the anchor.
	var view: Dictionary = _weapon_views.get("side", {})
	var rot := float(entry["rot"])
	if (d == "south" or d == "north") and _weapon_views.has(d):
		view = _weapon_views[d]
		rot = 0.0
	if view.is_empty():
		return
	_weapon.texture = view["tex"]
	var tex := _anim.sprite_frames.get_frame_texture(played, 0)
	var canvas_w: float = tex.get_width() if tex != null else 68.0
	var canvas_h: float = tex.get_height() if tex != null else 68.0
	# _anim is CENTERED with offset (0, -h/2): its canvas top-left sits at (-w/2, -h) in
	# _anim's child space. Anchor px -> local point, then stand the GRIP on it.
	var local := Vector2(entry["pos"]) + Vector2(-canvas_w * 0.5, -canvas_h)
	_weapon.rotation = rot
	_weapon.offset = -Vector2(view["grip"])
	_weapon.position = local
	_weapon.show_behind_parent = bool(entry["behind"])


func _build_frames(base: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	# EVERY animation group in the folder loads as its own set — Walking is just the
	# locomotion one. A POSE group (Aiming, Kneeling) plays as pose_<group>_<dir>; combat
	# states are folders of frames like everything else, drop-in like everything else.
	var groups := _subdirs(base + "/animations")
	_groups.clear()
	var walk_group := ""
	for g in groups:
		var gname := g.get_file()
		_groups.append(gname)
		if gname.to_lower().begins_with("walk"):
			walk_group = g
	if walk_group == "" and not groups.is_empty():
		walk_group = groups[0]   # old banks: whatever single group exists is the gait
	for d in DIRS:
		var idle_tex := _tex("%s/rotations/%s.png" % [base, d])
		var walk: Array = []
		if walk_group != "":
			walk = _frames_in("%s/%s" % [walk_group, d])
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

		# Pose/state groups: pose_<group-lower>_<dir>, looping, slow (a held stance).
		for g in groups:
			if g == walk_group:
				continue
			var frames := _frames_in("%s/%s" % [g, d])
			var aname := "pose_%s_%s" % [g.get_file().to_lower(), d]
			sf.add_animation(aname)
			sf.set_animation_loop(aname, true)
			sf.set_animation_speed(aname, 4.0)
			if frames.is_empty():
				sf.add_frame(aname, sf.get_frame_texture("idle_" + d, 0))
			else:
				for t in frames:
					sf.add_frame(aname, t)
	return sf


## --- file helpers (res:// DirAccess works when running from source) ---

static func _first_subdir(root: String) -> String:
	var da := DirAccess.open(root)
	if da == null:
		return ""
	for sub in da.get_directories():
		return root + "/" + sub
	return ""


static func _subdirs(root: String) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(root)
	if da == null:
		return out
	for sub in da.get_directories():
		out.append(root + "/" + sub)
	return out


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
