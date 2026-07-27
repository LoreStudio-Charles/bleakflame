class_name BuildShip
extends CharacterBody2D
## Base for anything that flies as a ShipBuild — the player and AI pirates are
## the same machine with different brains. Owns build consumption (hull visual,
## plumes, weapon mounts), handling derived from ShipStats, and the damage
## flow: shields absorb and regenerate, then armor soaks, then hull dies.

signal died

const ACCEL_SCALE := 66.0
const SPEED_SCALE := 44.0
const SHIELD_REGEN_DELAY := 2.5

## --- ENERGY (docs/energy_system.md) ---------------------------------------
## The spendable pool module abilities draw from. CAPACITY (pool) and RECHARGE
## (rate) are now HARD STATS the REACTOR publishes (ReactorDef, 2026-07-22), so
## they are tuned directly. They used to be derived from LOAD/margin — a lean fit
## recharged fast, a full one crawled — which was realistic but coupled every
## fitting choice to regen and made the pool untunable. LOAD is still a real fit
## budget (modules draw against power_output); it just no longer secretly sets
## your regen.
##
## LEGACY FALLBACK: an OLD reactor with no energy_capacity/energy_recharge (0)
## keeps the pre-change derived values, so saves from before the split still fly.
const ENERGY_PER_OUTPUT := 2.0    # fallback pool = reactor Load x this (old reactors only)
const REGEN_BASE := 0.6           # fallback regen base (old reactors only)
const REGEN_PER_MARGIN := 0.05    # fallback regen per unused LOAD (old reactors only)
const REGEN_FLOOR := 0.3          # fallback backstop

@export var drift_damp := 0.25

var build: ShipBuild
var stats: Dictionary = {}
## The level this ship is FIELDED at. 0 = "whatever its hull was authored at",
## which is the default and keeps every existing spawn byte-identical. A spawner
## sets this BEFORE apply_build to run the same hull hotter or colder — see
## Progression.toughness_between for why that scales from the hull's own level
## rather than from 1.
var spawn_level := 0
var enemy_group := ""          # the group this ship's weapons target
## EVERYONE ON THIS SHIP'S SIDE — the other half of `enemy_group`, and set
## everywhere that is. A LIST because the player's side spans two groups that
## OVERLAP: a Guardian and a hauler each join player_team AND friendly_targets.
## Read it through allies_within(), never by hand — see that comment for what
## walking it by hand cost.
var ally_groups: Array[String] = []
## WHAT THIS ENCOUNTER IS BUILT FOR — Threat.Rank (NORMAL/ELITE/MILITARY/SPEC_OPS).
## AUTHORED, not derived: role cannot be recovered from pools, because a big hull and
## a multiplied one look identical in the stats. Set by the spawner; everything that
## does not bother is NORMAL, which is the honest default for most of the sky.
var rank := Threat.Rank.NORMAL
var dead := false
## AI ships draw a random skin from assets/ships/variants/<hull>/ so every
## pirate looks individually lived-in; the player keeps the canonical sprite.
var use_variant_skin := false
## Player ships lock narrow-arc mounts to the nose (steering is aiming);
## AI ships leave this off and keep in-arc fire-control tracking.
var lock_narrow_mounts := false

var shield := 0.0
var armor := 0.0
var hull := 0.0
var hit_radius := 12.0

var _accel := 0.0
var _max_speed := 0.0
var _turn_speed := 0.0
var _trail_color := Color(0.55, 0.75, 1.0)
var _hull_visual: Polygon2D
var _hull_sprite: Sprite2D
var _livery_node: Node2D
var _plumes: Array[Node2D] = []   # code-built CPUParticles2D OR an authored trail_scene root
var _mounts: Array[WeaponMount] = []
var _regen_blocked := 0.0
var energy := 0.0
var energy_max := 0.0
var energy_regen := 0.0
## Multiplier on regen — Going Dark raises it (the "meditate" seam), and the
## player's profession sets a standing rate. AI ships leave it at 1.0.
var energy_regen_mult := 1.0
## Player-only: a smaller hit profile from the Evasion skill (0 for everyone
## else). Projectiles multiply this ship's effective hit radius by (1 - evasion).
var evasion := 0.0
## Cloak/stealth veil: alpha the whole ship draws at (1.0 = solid). Set via
## set_veil() so the hit-flash tween restores THIS, not full opacity. is_hidden()
## gates AI target acquisition — cloaked ships (player now, raiders later) drop
## enemy locks. Lives on the base so both sides can cloak (the parity rule).
var _veil_alpha := 1.0
var _hidden := false
## Bulwark: a Guardian throws a damage-reduction field over self + nearby allies.
## Applied at cast time and held for a duration — on the BASE so ANY ship can be
## a beneficiary (the caster's wing, an escorted NPC, later an enemy anchor).
var _dmg_reduction := 0.0
var _bulwark_t := 0.0


## The level this ship actually fights at: an explicit `spawn_level` if one was
## set, else the level its hull was authored at, else 1.
func level() -> int:
	if spawn_level > 0:
		return spawn_level
	if build != null and build.hull != null:
		return maxi(1, build.hull.level)
	return 1


func apply_build(new_build: ShipBuild) -> void:
	add_to_group("ships")   # every hull is an obstacle to every other hull
	build = new_build
	stats = ShipStats.aggregate(build)

	# LEVEL SCALING (user, 2026-07-25). A hull's authored pools are what it fields
	# AT ITS OWN LEVEL, so this is a no-op for every ship that spawns at its hull's
	# authored level — which is all of them until a spawner says otherwise. Set
	# `spawn_level` before apply_build to field the same hull tougher or softer,
	# which is how one .tres covers a whole region band (rim 1-5, Long Lane 6-15)
	# instead of needing a separate hull per level.
	if build.hull != null and level() != build.hull.level:
		var t := Progression.toughness_between(build.hull.level, level())
		stats.hull_hp *= t
		stats.armor_hp *= t
		stats.shield_hp *= t

	_accel = stats.accel * ACCEL_SCALE
	_max_speed = stats.accel * SPEED_SCALE
	# Turn rate falls off with mass. The floor is 0.3 (was 1.2) so a CAPITAL hull is
	# genuinely ponderous — a Supercruiser (~780+ mass) turns at ~0.28 rad/s (~16 deg/s),
	# "can't maneuver fast, holds space" (user). No fringe hull is heavy enough to hit
	# the old floor (the Vulture at mass 150 turns at 1.47), so this only slows super-heavies.
	_turn_speed = clampf(220.0 / stats.mass, 0.3, 4.5)

	shield = stats.shield_hp
	armor = stats.armor_hp
	hull = stats.hull_hp

	# Refit tops the pool off — you leave the bay charged, same as repaired.
	# CAPACITY + RECHARGE come straight from the reactor now. A reactor that
	# publishes neither (a pre-2026-07-22 save) falls back to the old LOAD-derived
	# formula so it still flies.
	energy_max = float(stats.get("energy_capacity", 0.0))
	energy_regen = float(stats.get("energy_recharge", 0.0))
	if energy_max <= 0.0:
		energy_max = maxf(0.0, stats.power_output * ENERGY_PER_OUTPUT)
	if energy_regen <= 0.0:
		energy_regen = maxf(REGEN_FLOOR,
			REGEN_BASE + maxf(0.0, stats.power_margin) * REGEN_PER_MARGIN)
	energy = energy_max

	_trail_color = Color(0.55, 0.75, 1.0)
	for comp in build.slots.values():
		if comp is ReactorDef:
			_trail_color = comp.trail_color

	_rebuild_visuals()


func _rebuild_visuals() -> void:
	if _hull_visual != null:
		_hull_visual.queue_free()
	if _hull_sprite != null:
		_hull_sprite.queue_free()
	for p in _plumes:
		p.queue_free()
	_plumes.clear()
	for m in _mounts:
		m.queue_free()
	_mounts.clear()

	# Convention over config, like the audio overrides: a sprite at
	# res://assets/ships/<hullname>.png replaces the placeholder polygon.
	# Player hull art is weaponless — mounted components draw the guns.
	var hull_name := build.hull.display_name.to_snake_case()
	# art_path (the FACTION-FOLDER convention: assets/ships/<faction>/<class>-<n>.png,
	# e.g. galean-navy/cruiser-1) wins when set; else the display-name file. An AI
	# variant skin still overrides below.
	var sprite_path: String = build.hull.art_path if build.hull.art_path != "" else "res://assets/ships/%s.png" % hull_name
	if use_variant_skin:
		var variant := _random_variant(hull_name)
		if variant != "":
			sprite_path = variant
	if ResourceLoader.exists(sprite_path):
		var sprite := Sprite2D.new()
		sprite.texture = load(sprite_path)
		# Scale the sprite to its SIZE-BAND world budget so art authored at any
		# resolution renders at the right in-world size. Canvases are conventionally
		# 2x the band px (LIGHT 32, MEDIUM 64, HEAVY 128, SUPER_HEAVY 256), so a
		# correctly-sized sprite scales by 1.0 (no change); an undersized capital
		# (e.g. a 128px SUPER_HEAVY) scales up to fill its band. Fixes "the
		# Supercruiser is barely bigger than a Vulture".
		var tw := sprite.texture.get_width()
		if tw > 0:
			sprite.scale = Vector2.ONE * (HullDef.world_budget(build.hull.size_band) / float(tw))
		# Stencil behavior: decal children (stripes, logos, liveries) are
		# clipped to the hull's alpha silhouette.
		sprite.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		_hull_sprite = sprite
		add_child(sprite)
	else:
		_hull_sprite = null
	_hull_visual = Polygon2D.new()
	_hull_visual.polygon = build.hull.silhouette
	_hull_visual.color = Color(0.72, 0.76, 0.82)
	_hull_visual.visible = _hull_sprite == null
	add_child(_hull_visual)

	hit_radius = 8.0
	for point in build.hull.silhouette:
		hit_radius = maxf(hit_radius, point.length() * 0.7)

	var collision := get_node_or_null("Collision") as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "Collision"
		collision.shape = CircleShape2D.new()
		add_child(collision)
	(collision.shape as CircleShape2D).radius = hit_radius

	for i in build.hull.hardpoints.size():
		var hp := build.hull.hardpoints[i]
		var comp := build.component_at(i)
		if comp is WeaponDef:
			var mount := WeaponMount.new()
			add_child(mount)
			mount.shooter = self   # a ship never eats its own bolts (WANTED self-hit guard)
			# Wide-arc mounts get the turret housing sprite, scaled by the
			# weapon's Mark so a Mk1 ring gun doesn't dwarf a Light hull.
			if hp.arc_deg > 90.0:
				mount.sprite_scale = (8.0 + 3.0 * comp.mark) / 32.0
				mount.setup(hp, comp, enemy_group, "res://assets/mounts/turret_compact.png")
			else:
				mount.setup(hp, comp, enemy_group)
			mount.nose_locked = lock_narrow_mounts and hp.arc_deg <= WeaponMount.FIXED_ARC_DEG
			# Player bolts (all mounts) carry graze forgiveness; AI's carry none.
			mount.shot_grace = 5.0 if lock_narrow_mounts else 0.0
			# Auto-sort into arrays: guns fire forever, ordnance is finite —
			# they must never share a trigger state.
			mount.group = 2 if comp.magazine > 0 else 1
			_mounts.append(mount)
		elif comp is EngineDef:
			# AUTHORED-OR-PROCEDURAL: an artist's trail_scene (built in the Godot
			# particle editor) wins; else the code-built default below. Either way the
			# code only drives emitting + facing (_update_plumes) — an authored scene
			# owns its entire look.
			if comp.trail_scene != null:
				var authored: Node2D = comp.trail_scene.instantiate()
				authored.position = hp.offset
				authored.z_index = -1
				add_child(authored)
				_plumes.append(authored)
				continue
			var plume := CPUParticles2D.new()
			plume.position = hp.offset
			plume.z_index = -1   # draw the exhaust trail BEHIND the ship, not over it
			plume.emitting = false
			plume.amount = 40
			plume.lifetime = 0.38
			plume.local_coords = false
			plume.direction = Vector2(1, 0)
			plume.spread = comp.trail_spread_deg * 0.5   # narrower cone (was too wide)
			plume.gravity = Vector2.ZERO
			plume.initial_velocity_min = 40.0 * comp.trail_scale
			plume.initial_velocity_max = 90.0 * comp.trail_scale
			plume.damping_min = 60.0
			plume.damping_max = 120.0
			# PIXEL-ART plume: crisp texture means THIS is the real width knob now.
			# (Reset from ~0.008 — that was invisible-tiny for the hard sprite; the old
			# soft gradient hid every change, which is why nothing seemed to move.)
			plume.scale_amount_min = 0.5 * comp.trail_scale
			plume.scale_amount_max = 1.1 * comp.trail_scale
			# Stash the tuned base so _update_plumes multiplies it (boost) instead of
			# overwriting it. THIS pair is the width knob; edit here.
			plume.set_meta("base_scale_min", plume.scale_amount_min)
			plume.set_meta("base_scale_max", plume.scale_amount_max)
			# Crisp pixel sprite per particle + additive blend so they stack into light,
			# and a lifetime ramp — hot white core -> the engine's trail colour ->
			# transparent tail. NEAREST filter keeps the pixels blocky.
			# Sprite comes from the THRUSTER when it supplies one (alien tech drops in
			# its own here); else the shared default pixel spark.
			plume.texture = comp.trail_texture if comp.trail_texture != null else _soft_dot()
			plume.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			plume.material = _additive_plume_mat()
			var ramp := Gradient.new()
			ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
			ramp.set_color(1, Color(_trail_color.r, _trail_color.g, _trail_color.b, 0.0))
			ramp.add_point(0.35, _trail_color)
			plume.color_ramp = ramp
			plume.set_meta("trail_scale", comp.trail_scale)
			add_child(plume)
			_plumes.append(plume)


func _random_variant(hull_name: String) -> String:
	var dir_path := "res://assets/ships/variants/%s" % hull_name
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	var pool: Array[String] = []
	for f in dir.get_files():
		# Exported builds list remapped ".import" entries; trim to the source.
		var file_name := f.trim_suffix(".import")
		if file_name.ends_with(".png"):
			var p := "%s/%s" % [dir_path, file_name]
			if ResourceLoader.exists(p) and not pool.has(p):
				pool.append(p)
	return pool.pick_random() if not pool.is_empty() else ""


## A COMPONENT PROVIDES SOMETHING — that is the whole reason a ship carries its
## mass and power draw (user, 2026-07-26). Sensors sense, shields project, armor
## ablates, thrusters thrust. Not having one means not getting what it gives, which
## needs no rule; the rule worth enforcing is the INVERSE — never grant what a ship
## has not equipped, because every free floor is a component nobody needs to buy.
##
## GOING DARK is taking ALL of it offline AT ONCE, on purpose, and paying that
## total shutdown is what buys the benefits: energy recovers fast, radar print
## drops, the heat signature goes, and the bus goes cold enough to swap chips in
## flight.
##
## SO SILENCE IS NOT A SIDE EFFECT OF BLINDNESS. An earlier pass had a sensorless
## hull count as "running silent", handing it dark's stealth (hunters hold it at
## 0.4x range) while it kept shields, engines and guns — a large UNEARNED GRANT for
## omitting the cheapest part on the ship. The signature drop is earned by having
## everything off, never by lacking one thing.
func runs_silent() -> bool:
	return false


## How far this ship can PERCEIVE, or 0.0 with no sensor fitted.
##
## `floor_r` is the usable minimum for a ship that HAS eyes — a hull should not be
## unplayable just because its sensor is cheap. It deliberately does NOT apply to
## a hull with none, because a floor that applies to everyone is SENSING GRANTED
## FREE: it made the Tin-Ear set worthless to buy. Every "how far can this ship
## perceive" read goes through here, so the grant is paid for in one place rather
## than leaking from five scattered maxf() calls.
func sensor_reach(floor_r: float) -> float:
	var r := float(stats.get("sensor_range", 0.0))
	return 0.0 if r <= 0.0 else maxf(floor_r, r)


## The reach a hull has with nothing fitted — its own cargo door and manipulators.
## Matches the flat `SALVAGE_RADIUS` this replaced, so a bare ship behaves exactly
## as it did.
const BASE_INTERACTION := 95.0
## How much of the hull's physical size counts toward that reach, so a freighter
## scoops from further than a fighter without anyone authoring a number per hull.
const INTERACTION_PER_RADIUS := 2.4


## THE INTERACTION RADIUS — how far this ship can PULL: salvage, pickups, and the
## beneficial radius generally. The third of the three radii, and the one that is
## NOT about combat (see hit_profile_of for that, and hit_radius for physics).
##
## IT USED TO BE A FLAT CONSTANT ON THE PLAYER, which meant a Bellwether scooped
## from exactly the same distance as a Rooster and — worse — NO COMPONENT COULD
## AFFECT IT, so a cargo scoop module was literally unbuildable. A component has to
## provide something or there is no reason to carry its mass and draw.
##
## The HULL provides the baseline (it is a component too, and a bigger hull has a
## bigger door); gear raises it from there. Aggregated as a MAX rather than a sum —
## two scoops do not reach twice as far.
func interaction_radius() -> float:
	var from_hull := maxf(BASE_INTERACTION, hit_radius * INTERACTION_PER_RADIUS)
	return maxf(from_hull, float(stats.get("interaction_range", 0.0)))


## THE HIT PROFILE — how big this thing is TO A WEAPON, which is deliberately not
## how big it is to the physics engine.
##
## `hit_radius` is the PHYSICAL size: it is the CircleShape2D radius, and it drives
## bumping, planetoid surfaces and AI spacing. An evasive ship is not physically
## smaller, so none of that ever shrinks. What evasion shrinks is how easy the ship
## is to SHOOT.
##
## KEPT AS PLAIN MATH, NOT A SECOND COLLIDER (user, 2026-07-26). A separate "combat"
## Area2D per hull would be the tidier object model and a good deal more expensive —
## dozens of ships and hundreds of bolts in flight, each wanting overlap callbacks.
## A distance check is cheaper and the bolts already do swept geometry anyway.
##
## EVERY WEAPON TEST GOES THROUGH HERE so the shrink applies to all of them. It used
## to be a multiply inlined in the bolt sweep and nowhere else, which meant Evasion —
## a favoured 5-cap skill for two commissions — did nothing whatsoever against
## beams, proximity fuzes, splash or any ability.
##
## Duck-typed and static: asteroids, decoys and the leviathan carry a `hit_radius`
## and no `evasion`, so they get their honest full size.
static func hit_profile_of(node: Object, fallback := 12.0) -> float:
	if node == null:
		return fallback
	var r: float = node.get("hit_radius") if node.get("hit_radius") != null else fallback
	var ev: float = node.get("evasion") if node.get("evasion") != null else 0.0
	return maxf(0.0, r * (1.0 - clampf(ev, 0.0, 0.95)))


## Tints the hull art (sprite modulate or polygon color, whichever is active).
## SELF_MODULATE, NOT MODULATE (2026-07-25). `modulate` cascades to CHILDREN, and
## every decal is a child of the hull sprite — the Guardian stripe, the livery
## chevron, the Widows hourglass. So tinting through `modulate` multiplied the
## decals too, and the Widows's red mark (0.80, 0.05, 0.09) times their black
## hull (0.13, 0.12, 0.15) came out effectively BLACK: the single point of red
## that is the entire faction read, erased by the tint meant to carry it.
##
## It was invisible until now only because no lane hull has art yet — the
## silhouette path tints `_hull_visual.color`, which is a fill and does not
## cascade. The bug would have appeared the day the PNGs dropped in.
##
## `self_modulate` colours this node alone, so decals keep their authored colour.
## The cloak/stealth veil is unaffected: set_veil uses the SHIP's modulate, which
## still cascades over hull and decals alike, which is what it wants.
func set_hull_tint(tint: Color) -> void:
	if _hull_sprite != null:
		_hull_sprite.self_modulate = tint
	else:
		_hull_visual.color = tint


## FACTION LIVERY — a forward-pointing chevron on the deck in the faction's colour,
## clipped to the hull silhouette by the sprite stencil and scaled to the sprite, so
## it fits any hull. Replaces any prior livery. Faction-driven eventually; tunable
## now via the /livery <colour> dev command. No-op on a silhouette-only (art-less) hull.
func apply_livery(color: Color) -> void:
	if _hull_sprite == null or _hull_sprite.texture == null:
		return
	if _livery_node != null and is_instance_valid(_livery_node):
		_livery_node.queue_free()
	var h := 0.5 * float(_hull_sprite.texture.get_width())   # half-width, sprite-local
	# Half-thick chevron band (~0.06h), forward-pointing.
	var pts := PackedVector2Array([
		Vector2(0.28 * h, 0.0),
		Vector2(-0.06 * h, -0.38 * h),
		Vector2(-0.12 * h, -0.38 * h),
		Vector2(0.22 * h, 0.0),
		Vector2(-0.12 * h, 0.38 * h),
		Vector2(-0.06 * h, 0.38 * h)])
	var root := Node2D.new()
	# Thin BLACK BORDER first: a closed stroke on the chevron edge. The fill covers
	# its inner half, leaving a hair of black outline for definition.
	var loop := PackedVector2Array(pts)
	loop.append(pts[0])
	var border := Line2D.new()
	border.points = loop
	border.width = 0.035 * h
	border.default_color = Color(0.0, 0.0, 0.0, 0.9)
	border.joint_mode = Line2D.LINE_JOINT_ROUND
	root.add_child(border)
	# FILL at ~60% alpha so the hull's panelling reads THROUGH it — the "50-70%
	# layer" look (a see-through tint, not a flat decal). NOTE: alpha, not a true
	# multiply/overlay — those need a shader or baking into the sprite; this plays
	# clean with the hull's clip stencil and reads the same on the white hull.
	var fill := Polygon2D.new()
	fill.polygon = pts
	fill.color = Color(color.r, color.g, color.b, 0.6)
	root.add_child(fill)
	_hull_sprite.add_child(root)
	_livery_node = root


## Per-particle sprite for engine plumes. PIXEL-ART + CRISP (was a soft radial
## gradient, whose fuzzy falloff hid every scale change — so scale_amount now
## actually controls the visible width). Drop a pixel-art flame at
## res://assets/fx/plume.png to override; else a small procedural diamond spark.
## Rendered NEAREST (set on the plume) to stay blocky; tinted per-particle by the
## color_ramp and additive-blended into a trail.
static var _plume_dot: Texture2D
static func _soft_dot() -> Texture2D:
	if _plume_dot == null:
		if ResourceLoader.exists("res://assets/fx/plume.png"):
			_plume_dot = load("res://assets/fx/plume.png")
		else:
			var s := 8
			var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
			img.fill(Color(0, 0, 0, 0))
			var c := (s - 1) * 0.5
			for y in s:
				for x in s:
					if absf(x - c) + absf(y - c) <= c:   # crisp diamond, hard pixels
						img.set_pixel(x, y, Color(1, 1, 1, 1))
			_plume_dot = ImageTexture.create_from_image(img)
	return _plume_dot


## Shared additive blend material so overlapping plume particles stack as light.
static var _plume_mat: CanvasItemMaterial
static func _additive_plume_mat() -> CanvasItemMaterial:
	if _plume_mat == null:
		_plume_mat = CanvasItemMaterial.new()
		_plume_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _plume_mat


## Shared per-frame upkeep: shield regeneration and energy recharge.
func tick_common(delta: float) -> void:
	_collision_cd = maxf(0.0, _collision_cd - delta)
	if energy < energy_max:
		energy = minf(energy_max, energy + energy_regen * energy_regen_mult * delta)
	_regen_blocked = maxf(0.0, _regen_blocked - delta)
	if _regen_blocked == 0.0 and shield < stats.shield_hp:
		shield = minf(stats.shield_hp, shield + stats.shield_regen * delta)
	if _bulwark_t > 0.0:
		_bulwark_t -= delta
		if _bulwark_t <= 0.0:
			_dmg_reduction = 0.0


## Take a Bulwark buff: cut incoming damage by `reduction` for `duration`. Never
## downgrades an existing stronger/longer field.
func apply_bulwark(reduction: float, duration: float) -> void:
	_dmg_reduction = maxf(_dmg_reduction, reduction)
	_bulwark_t = maxf(_bulwark_t, duration)


## Mend the hull, then spill any remainder into armor (never shields — those
## regen on their own). The Science Repair Field's per-tick heal, and reusable
## for any future repair effect on self or an ally.
func repair(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	var hull_missing: float = stats.hull_hp - hull
	var to_hull := minf(amount, hull_missing)
	hull += to_hull
	amount -= to_hull
	if amount > 0.0:
		armor = minf(stats.armor_hp, armor + amount)


## Every living ally inside `radius`, EACH ONE EXACTLY ONCE.
##
## THE GROUPS OVERLAP AND THAT IS THE WHOLE POINT OF THIS FUNCTION. A Guardian
## joins player_team AND friendly_targets (guardian_ship._ready); so does every
## hauler (trader_ship._ready). Five sites walked the pair by hand and two got it
## wrong — the Science Repair Field mended every Guardian and hauler in reach at
## DOUBLE RATE for as long as it has existed, and Bulwark reported more ships
## braced than it had braced. Neither was visible in play: an ability that is
## twice as good as authored reads as a generous ability, not as a bug. That is
## why this is a function and not a convention.
##
## It is also the single home of the WANTED-PLAYER rule. A wanted pilot joins
## hostile_team (ship.gd _refresh_wanted), so a pirate asking for "my side" was
## handed the person it is shooting at. Stated as "never an ally if I am shooting
## at them" rather than "never the player", so a Guardian — who genuinely does
## count the pilot as an ally — still gets them.
##
## `include_self` is opt-in because most callers already treat themselves
## specially (Bulwark braces self then counts, the Repair Field mends self at a
## different site); only a mender wants itself folded into the same list.
func allies_within(radius: float, include_self: bool = false) -> Array[BuildShip]:
	var out: Array[BuildShip] = []
	var r2 := radius * radius
	for grp in ally_groups:
		for node in get_tree().get_nodes_in_group(grp):
			if node == self or not is_instance_valid(node):
				continue
			var ally := node as BuildShip
			if ally == null or ally.dead or out.has(ally):
				continue
			if enemy_group != "" and ally.is_in_group(enemy_group):
				continue
			if global_position.distance_squared_to(ally.global_position) <= r2:
				out.append(ally)
	if include_self and not dead:
		out.append(self)
	return out


## Restitution when a ship runs into something solid — it rebounds instead of
## clinging. move_and_slide alone just scrubs the into-surface velocity and
## leaves the hull pressed flat (thrust into it forever = Velcro). Mirrors the
## planetoid/dock bounces the rest of the world already had.
const OBSTACLE_BOUNCE := 0.45   # fraction of incoming speed kept after a bounce
const OBSTACLE_KICK := 55.0     # extra shove straight off the surface, no cling

## COLLISION DAMAGE (2026-07-22). Now that everyone avoids obstacles, a real
## impact is a MISTAKE and should cost something — it reads as physics rather
## than as a tax. Damage scales with how fast you drove INTO the surface (the
## normal component only, so a glancing scrape is cheap and a head-on ram is
## not), and everything below a gentle-contact floor is free — creep-docking and
## light bumps never hurt. Tiers through shield -> armor -> hull via take_damage.
const COLLISION_MIN_SPEED := 260.0    # closing speed below this = a harmless nudge
const COLLISION_DMG_PER_SPEED := 0.06 # ~20 dmg at 600, ~38 at a 900 head-on
const COLLISION_DMG_CD := 0.7         # one hit per impact, not per sliding frame
var _collision_cd := 0.0


## Shared movement integration: thrust, drift decay, speed cap, plumes.
func apply_movement(thrust: Vector2, delta: float, speed_mult := 1.0, boosting := false) -> void:
	# AI ships steer around what they are about to hit. Done HERE rather than at
	# each behaviour's call site because a ship has many movement paths (the guard
	# wing alone has eight: formation, ring patrol, lane, escort, regroup...) and
	# only one of them used to avoid anything — so guardians rammed the station
	# and each other while "avoidance" looked implemented. Opt-in: the PLAYER
	# never gets steered by the game.
	if avoids_obstacles and thrust.length_squared() > 1.0:
		var away := separation_dir()
		if away != Vector2.ZERO:
			var dir := thrust.normalized()
			# HEAD-ON NEEDS A TANGENT. A purely radial push cannot turn a ship
			# flying straight at something — RIGHT + LEFT*0.85 still points
			# right, so it only brakes while the hull ploughs on. When the
			# obstacle is nearly dead ahead, steer AROUND it instead of backing
			# off it. Side is picked by instance id so two ships meeting nose to
			# nose choose opposite ways rather than mirroring into each other.
			if away.dot(dir) < -0.55:
				var side := dir.orthogonal()
				if int(get_instance_id()) % 2 == 1:
					side = -side
				away = (away + side * 1.8).normalized()
			# NOTHING IS WORTH FLYING INTO A PLANET (2026-07-26). The blend above is
			# a NUDGE: with `away` opposite `dir`, `dir + away * 0.85` still points
			# along `dir` — it brakes slightly while the hull ploughs on. That is
			# right for a station (bumping one costs a little hull) and fatally
			# wrong for a gravity well, so a pirate chasing a hauler toward the
			# colony would ride its intent straight into the surface. Widening
			# avoid_radius never fixed it because the weight, not the reach, was
			# the limit.
			#
			# So the weight ESCALATES with how deep the ship is in a LETHAL field
			# until avoidance overrides intent outright. Only bodies that kill
			# count — see hazard_urgency().
			var weight := lerpf(SEPARATION_WEIGHT, HAZARD_WEIGHT, hazard_urgency())
			var want := (dir + away * weight).normalized()
			thrust = want * thrust.length()
			# TURN THE NOSE, not just the thrust vector. These AI steer by
			# rotation — `rotation = rotate_toward(...)` then
			# `thrust = RIGHT.rotated(rotation) * accel` — so deflecting the
			# thrust alone was undone on the very next frame while the hull kept
			# pointing at whatever it was about to hit. That is why guardians
			# still rammed the station after separation "worked": the maths was
			# right and aimed at the wrong variable.
			rotation = rotate_toward(rotation, want.angle(),
				_turn_speed * delta * AVOID_TURN_GAIN)
	velocity += thrust * delta
	velocity *= exp(-drift_damp * delta)
	velocity = velocity.limit_length(_max_speed * speed_mult * limp_speed_mult())
	var pre := velocity
	move_and_slide()
	if get_slide_collision_count() > 0:
		bounce_off_obstacles(pre)
	_update_plumes(thrust, boosting)


## PROXIMITY avoidance: a push away from anything we are too close to, right now.
##
## This is the companion to avoid_obstacles_dir(), which only looks AHEAD along
## the travel lane and only at asteroids. Bumping happens in the cases that miss:
## a structure you are orbiting rather than flying at, and other SHIPS, which
## move. Cheap and always-on, so a ship drifts clear instead of grinding.
##
## Deliberately soft — SEPARATION_WEIGHT keeps it a nudge, not an autopilot, so
## contact still happens occasionally. It should look like flying, not like a
## force field.
## HOW BADLY THIS SHIP NEEDS TO GET OUT — 0 in clear space, 1 inside a lethal field.
##
## Only bodies that KILL are counted. Scraping a station or another hull costs a
## little hull and a bounce; entering a planetoid's gravity well costs the ship, so
## the two cannot share one avoidance strength. `separation_dir()` normalizes its
## sum and therefore throws away exactly this information — a ship deep in the well
## gets the same unit push as one grazing the far edge. This puts the urgency back.
##
## Ramps from 0 at the body's `avoid_radius` to 1 just outside its `grav_r`, and
## stays 1 inside. Keyed off `grav_r` (duck-typed), which only planetoids publish,
## so nothing else is caught by it.
func hazard_urgency() -> float:
	var worst := 0.0
	for st in get_tree().get_nodes_in_group("planetoids"):
		if not is_instance_valid(st) or not (st is Node2D):
			continue
		var lethal: float = float(st.get("grav_r") if st.get("grav_r") != null else 0.0)
		if lethal <= 0.0:
			continue
		var reach: float = float(st.get("avoid_radius") if st.get("avoid_radius") != null
			else lethal * 1.9)
		var inner := lethal * 1.15
		if reach <= inner:
			continue
		var d := global_position.distance_to((st as Node2D).global_position)
		worst = maxf(worst, clampf((reach - d) / (reach - inner), 0.0, 1.0))
		if worst >= 1.0:
			break
	return worst


## Top-speed multiplier from structural damage — see the LIMP_* constants.
##
## STEPS, NOT A RAMP, on purpose. A smooth curve is invisible: the pilot never
## notices the moment the decision changed, which is the entire point of the
## mechanic. A step is felt, and the project's rule that every rejection must be
## VISIBLE applies here too — losing a quarter of your speed is a rejection of the
## plan you had. Ship announces the crossings; the AI just gets slower.
func limp_speed_mult() -> float:
	var full := float(stats.get("hull_hp", 0.0))
	if full <= 0.0:
		return 1.0
	var frac := hull / full
	if frac <= LIMP_CRIPPLED_AT:
		return LIMP_CRIPPLED_MULT
	if frac <= LIMP_HURT_AT:
		return LIMP_HURT_MULT
	return 1.0


func separation_dir() -> Vector2:
	var away := Vector2.ZERO
	var react := velocity.length() * AVOID_REACT_TIME
	# STRUCTURES — station, outposts, dens. Big, static, and the thing guardians
	# were most visibly slamming into.
	# "planetoids" included so AI give the gravity WELL a wide berth — it was the
	# one landmark not in the avoidance, so ships drifted into the pull and
	# crash-looped to death at the planet. The player is never auto-steered, so
	# they can still fly in and land.
	for g in ["structures", "outposts", "pirate_dens", "planetoids"]:
		for st in get_tree().get_nodes_in_group(g):
			if not is_instance_valid(st) or not (st is Node2D):
				continue
			var r: float = float(st.get("avoid_radius") if st.get("avoid_radius") != null
				else STRUCTURE_AVOID_R)
			away += _push_from((st as Node2D).global_position, r + hit_radius + react)
	# OTHER SHIPS, including the player. Anything that flies is a moving obstacle.
	for other in get_tree().get_nodes_in_group("ships"):
		if other == self or not is_instance_valid(other):
			continue
		var b := other as BuildShip
		if b == null or b.dead:
			continue
		away += _push_from(b.global_position,
			hit_radius + b.hit_radius + SHIP_CLEARANCE + react)
	return away.normalized() if away.length_squared() > 0.0001 else Vector2.ZERO


## Outward push that grows as the gap closes, and is nothing at all beyond `reach`.
func _push_from(at: Vector2, reach: float) -> Vector2:
	var to_me := global_position - at
	var d := to_me.length()
	if d >= reach or reach <= 0.0:
		return Vector2.ZERO
	if d < 1.0:
		return Vector2.RIGHT.rotated(float(get_instance_id() % 617))   # exactly stacked
	return (to_me / d) * (1.0 - d / reach)


## Rebound off whatever move_and_slide just hit, rather than sliding along it.
## `pre_vel` is the velocity carried into the collision (slide has since
## flattened its normal component, so we reflect the pre-move velocity).
func bounce_off_obstacles(pre_vel: Vector2) -> void:
	for i in get_slide_collision_count():
		var n := get_slide_collision(i).get_normal()
		var into := -pre_vel.dot(n)                 # closing speed INTO the surface
		if into <= 0.0:
			continue                                # heading away; not a real hit
		velocity = pre_vel.bounce(n) * OBSTACLE_BOUNCE + n * OBSTACLE_KICK
		_apply_collision_damage(into)
		return


## Hurt the ship for driving into something, once per impact. Docking and
## landing have their OWN scrape/crash handling and set `cinematic`, so this is
## suppressed there to avoid double-charging; a docked ship never collides.
func _apply_collision_damage(impact_speed: float) -> void:
	# `cinematic`/`docked_at` live on TestShip, not this base, so duck-type them:
	# AI never docks and has no cinematic, so absent == false is exactly right.
	if dead or _collision_cd > 0.0:
		return
	if get("cinematic") == true or get("docked_at") != null:
		return
	if impact_speed < COLLISION_MIN_SPEED:
		return                                      # gentle contact is free
	_collision_cd = COLLISION_DMG_CD
	var dmg := (impact_speed - COLLISION_MIN_SPEED) * COLLISION_DMG_PER_SPEED
	take_damage(dmg)
	on_collision_impact(dmg, impact_speed)


## Feedback hook. Base ship just thuds, pitched by force; TestShip overrides to
## flash the cockpit note. AI stays silent.
func on_collision_impact(_dmg: float, impact_speed: float) -> void:
	var force: float = clampf(impact_speed / 900.0, 0.2, 1.0)
	Sfx.play("scrape", -10.0 + 6.0 * force, 0.8 + 0.3 * force)


## Look-ahead steering. If a solid rock sits in the travel path within
## AVOID_LOOKAHEAD, return a heading that SKIRTS it — the current heading blended
## with a perpendicular shove away from the obstacle. Vector2.ZERO when the lane
## is clear. AI callers steer toward this to dodge, then resume their behaviour;
## the bounce above is the last-ditch net for when a dodge comes too late.
const AVOID_LOOKAHEAD := 320.0
## How hard proximity avoidance pulls against the ship's own intent. Low on
## purpose: the user asked for fewer collisions, NOT none — "I don't mind it
## happening sometimes". Raise toward 1.0 for pilots who never touch anything.
## ---- A HOLED SHIP CANNOT RUN (user, 2026-07-26) ----
##
## Below 30% hull you lose a quarter of your top speed; below 10%, half. Applies to
## the PLAYER AND EVERY AI equally — it is a property of a broken ship, not a
## difficulty setting.
##
## WHAT IT BUYS: fleeing stops being a free option always available at the bottom of
## the health bar and becomes a DECISION ABOUT TIMING. Break off at 40% and you get
## away; ride it to 15% hoping to win and the escape you were counting on is not
## there any more. It also makes chases resolve — the loser of an exchange gets
## slower, so a pursuit ends instead of dribbling out over 10km.
##
## KEYED ON HULL, NOT TOTAL EFFECTIVE HP. Shields regenerate and armor is mitigation;
## hull is the structural layer that does NOT come back without a dock, so it is the
## only one that can honestly mean "this ship is wrecked". A ship with flat shields
## and an intact hull is in trouble, not crippled.
##
## MAX SPEED ONLY — never acceleration or turn rate. Losing accel and turn would read
## as broken controls and take the fight away from the player as well as the escape;
## a lower ceiling reads as engines that cannot hold full output, which is the fiction
## and leaves the ship responsive enough to still be flown well.
const LIMP_HURT_AT := 0.30
const LIMP_HURT_MULT := 0.75
const LIMP_CRIPPLED_AT := 0.10
const LIMP_CRIPPLED_MULT := 0.50

const SEPARATION_WEIGHT := 0.85
## Avoidance weight at full hazard_urgency(). Above 1.0 on purpose: at 4.0 the
## blend `dir + away * 4` points essentially along `away`, so a ship inside a
## gravity well turns and runs REGARDLESS of what it was chasing. The escalation
## is smooth, so ordinary flying near a planet is still only nudged.
const HAZARD_WEIGHT := 4.0
## How hard avoidance may fight the behaviour's own steering for the nose. Above
## 1.0 so a ship about to hit something turns away FASTER than its brain turns it
## back — otherwise the two cancel and it grinds along the obstacle.
const AVOID_TURN_GAIN := 1.6
## Personal space between hulls, on top of both radii. Was 46 — about a hull and
## a half, which meant avoidance only woke up when two ships were already
## touching and there was no room left to turn. A ship needs to see the problem
## while it can still do something about it.
const SHIP_CLEARANCE := 120.0
## ...plus a braking-distance term: how many seconds ahead a ship looks. At
## cruise this adds a few hundred units of warning, so fast traffic starts its
## turn early and slow traffic is not pushed around for no reason.
const AVOID_REACT_TIME := 0.7
const STRUCTURE_AVOID_R := 260.0    # fallback when a structure declares no radius

## Opt-in; the player is never auto-steered.
var avoids_obstacles := false
const AVOID_CLEARANCE := 60.0

func avoid_obstacles_dir(intent: Vector2) -> Vector2:
	var heading := velocity if velocity.length_squared() > 400.0 else intent
	if heading.length_squared() < 1.0:
		return Vector2.ZERO
	var dir := heading.normalized()
	var worst := 0.0
	var steer := Vector2.ZERO
	for rock in get_tree().get_nodes_in_group("asteroids"):
		if not is_instance_valid(rock):
			continue
		var to_o: Vector2 = rock.global_position - global_position
		var ahead := to_o.dot(dir)
		if ahead <= 0.0 or ahead > AVOID_LOOKAHEAD:
			continue                                  # behind us, or too far to matter
		var clear_r: float = float(rock.hit_radius) + hit_radius + AVOID_CLEARANCE
		var perp := to_o - dir * ahead                # offset of the rock from our path line
		var pd := perp.length()
		if pd >= clear_r:
			continue                                  # the lane clears this rock
		# Blocked: nearer + more centred = more urgent. Steer to the side the
		# rock ISN'T on (or pick one if it's dead ahead).
		var urgency := (1.0 - ahead / AVOID_LOOKAHEAD) + (1.0 - pd / clear_r)
		if urgency > worst:
			worst = urgency
			var side := (-perp / pd) if pd > 2.0 else dir.orthogonal()
			steer = (dir + side * 1.35).normalized()
	return steer


func update_mounts(aim: Vector2, delta: float, aim_vel := Vector2.ZERO) -> void:
	for mount in _mounts:
		mount.aim_at(aim, delta, aim_vel)


## Fires every mount whose weapon reaches `target_dist` (0 = fire regardless).
func fire_mounts(target_dist := 0.0) -> void:
	for mount in _mounts:
		if target_dist <= mount.def.weapon_range:
			mount.fire()


## Fire ONE weapon array. Group 1 = guns (no magazine, so they can be a held state),
## group 2 = ordnance (finite rounds, so it stays an on-demand verb). The player's
## weapons-free toggle drives the first; [R] drives the second. AI still uses
## fire_mounts() and shoots everything it has.
func fire_array(group: int, target_dist := 0.0) -> void:
	for mount in _mounts:
		if mount.group == group and target_dist <= mount.def.weapon_range:
			mount.fire()


func fire_guns(target_dist := 0.0) -> void:
	fire_array(1, target_dist)


func fire_ordnance(target_dist := 0.0) -> void:
	fire_array(2, target_dist)


## Does this hull actually carry ordnance? Drives the HUD prompt and stops [R] from
## reporting a dry click on a ship that never had a launcher.
func has_ordnance() -> bool:
	for mount in _mounts:
		if mount.group == 2:
			return true
	return false


## Whoever last dealt us damage — kill credit. XP and loot are the PLAYER's
## reward alone (guardians/pirates killing each other pay nobody), so death
## handlers gate on killed_by_player().
var _last_attacker: Node = null


## True only if the killing blow traces to the player's ship — the gate for
## XP, loot drops, and bounty tallies.
func killed_by_player() -> bool:
	return is_instance_valid(_last_attacker) and _last_attacker.is_in_group("player_ship")


func take_damage(amount: float, source: Node = null) -> void:
	if dead:
		return
	if source != null:
		_last_attacker = source
	_regen_blocked = SHIELD_REGEN_DELAY
	var remaining := amount * (1.0 - _dmg_reduction)
	var shield_absorbed := minf(shield, remaining)
	shield -= shield_absorbed
	remaining -= shield_absorbed
	var armor_absorbed := minf(armor, remaining)
	armor -= armor_absorbed
	remaining -= armor_absorbed
	hull -= remaining
	Sfx.play_at("shield_hit" if shield_absorbed > 0.0 else "hit", global_position, -10.0)
	_flash()
	if hull <= 0.0:
		_die()


func _flash() -> void:
	modulate = Color(1.9, 1.9, 1.9)
	# Restore to the veil, not full opacity — a cloaked ship stays dim after a hit
	# (the flash is a brief tell that something's there).
	create_tween().tween_property(self, "modulate", Color(1, 1, 1, _veil_alpha), 0.12)


## Draw the whole ship at alpha `a` (cloak/stealth). Tint on _hull_sprite is a
## child modulate, so it multiplies through and survives.
func set_veil(a: float) -> void:
	_veil_alpha = a
	modulate = Color(1, 1, 1, a)


func is_hidden() -> bool:
	return _hidden


func _die() -> void:
	dead = true
	_explode()
	# THE BODY STAYS. Spawned BEFORE _on_death, because that frees the ship and the wreck
	# copies its art and momentum off it. Deliberately absent from devour(), which is the
	# whole point: the beast leaves nothing and now that is something you can SEE.
	Wreck.spawn(self)
	died.emit()
	_on_death()


## Devoured by a leviathan: gone TRACELESS — no wreck, no cargo, no rap sheet,
## just an empty patch where a ship used to be. A quiet shadow-swallow instead
## of the loud explosion of a normal death (an explosion is evidence; the beast
## leaves none — the campaign's whole horror). Emits `died` so the world's
## respawn hooks refill the lane, but bypasses _on_death so nothing drops.
func devour() -> void:
	if dead:
		return
	dead = true
	_devour_implosion()
	died.emit()
	queue_free()


## A dark inward collapse where the ship was — particles pulled to the centre
## (radial_accel negative), violet-black. Reads as swallowed, not blown up.
func _devour_implosion() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.position = global_position
	p.one_shot = true
	p.emitting = true
	p.amount = 18
	p.lifetime = 0.5
	p.explosiveness = 0.9
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 150.0
	p.radial_accel_min = -300.0   # pull inward — a collapse, not a blast
	p.radial_accel_max = -360.0
	p.scale_amount_max = 2.4
	p.color = Color(0.34, 0.2, 0.5, 0.9)
	parent.add_child(p)
	p.finished.connect(p.queue_free)


## AI ships free themselves; the player overrides this to linger for respawn.
func _on_death() -> void:
	queue_free()


func _explode() -> void:
	Sfx.play_at("explosion", global_position, -3.0,
		clampf(1.4 - stats.mass / 180.0, 0.55, 1.3))
	var burst := CPUParticles2D.new()
	burst.position = global_position
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 36
	burst.lifetime = 0.6
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = 80.0
	burst.initial_velocity_max = 220.0
	burst.scale_amount_max = 2.4
	burst.color = Color(1.0, 0.62, 0.28)
	burst.emitting = true
	get_parent().add_child(burst)
	burst.get_tree().create_timer(1.2).timeout.connect(burst.queue_free)


func _update_plumes(thrust: Vector2, boosting: bool) -> void:
	var thrusting := thrust.length_squared() > 1.0
	for plume in _plumes:
		plume.set("emitting", thrusting)   # duck-typed: code-built CPU or authored GPU/CPU
		if not thrusting:
			continue
		plume.rotation = thrust.angle() - rotation + PI
		# The code-built default (CPUParticles2D) carries the width knob; boost widens
		# it RELATIVE to the tuned base (it used to OVERWRITE scale_amount_max, so every
		# setup-time width edit silently did nothing). An AUTHORED trail_scene owns its
		# own scale — left untouched.
		if plume is CPUParticles2D:
			var boost := 1.45 if boosting else 1.0
			plume.scale_amount_min = float(plume.get_meta("base_scale_min", 0.5)) * boost
			plume.scale_amount_max = float(plume.get_meta("base_scale_max", 1.1)) * boost
