class_name TestShip
extends BuildShip
## The player: BuildShip plus input, the two flight schemes, brake and boost.
##
##   CONNECTED    — A/D rotate, W/S thrust along the nose. Base mode.
##   DISCONNECTED — face mouse, WASD world-axis thrust. Requires a System
##                  component tagged "flight_decoupler".
## The mouse never aims weapons: narrow-arc guns are nose-locked (steering IS
## aiming), wide-arc turrets self-track. RMB click-selects a target — turrets
## prioritize it; the freed mouse is the seed of the future systems-engagement
## scheme (select target, press a system key, system engages it).

enum ControlMode { CONNECTED, DISCONNECTED }

@export var brake_accel := 1100.0
@export var boost_multiplier := 1.8

## Hyperslide: at speed, brake + hard steer breaks traction — the nose swings
## free (triple turn rate) while velocity keeps its heading. Guns stay live.
## Connected-mode only: the manual pilot's answer to the decoupling computer.
const SLIDE_DURATION := 0.85
const SLIDE_TURN_MULT := 3.2
const SLIDE_SPEED_FRACTION := 0.8   # of base max speed; boost gets you there
const SLIDE_COOLDOWN := 1.2

## How close (world units) an RMB click must land to a hostile to select it.
## Generous: at combat speeds a ship moves ~70 units in human reaction time.
## An empty-space click clears the selection — deselection stays possible.
const TARGET_CLICK_RADIUS := 150.0
## Forgiving right-click salvage reach — click ANYWHERE near loot to grab it.
const SALVAGE_RADIUS := 95.0
## The lead pip orbits the ship at this distance (bearing indicator ring).
const PIP_RING := 110.0

var _hold_full_cd := 0.0

var mode := ControlMode.CONNECTED
var decoupler_fitted := false
var target: Node2D = null
var _target_marker: Node2D
## Survey scanner (System tag "scanner"): the first systems-engagement key.
## Select a target, press [1], the scanner channels on it. Rocks reveal ore;
## anything alive yields Scan Data — the future currency of Insight.
var scanner_fitted := false
var _scan_range := 380.0
var _scan_time := 3.2
var _scan_progress := -1.0    # < 0 = idle
var scan_note := ""
var scan_note_t := 0.0
## True while the current center note is an ABILITY FAILURE (drawn red by the HUD,
## so a refused skill reads unmistakably as failed, not as any other flash).
var scan_note_fail := false
## Ensnared timer (kept alive by BreathCloud while inside one): heavy drag
## comes from the cloud; thrust gutters here. Burn free or be devoured.
var snared := 0.0
## Weapon arrays: [guns, ordnance]. [2]/[3] toggle them — the trigger only
## fires enabled arrays, so finite rockets never ride along with the guns
## unless you want them to.
var array_enabled := [true, true]
var _known_abilities: Array = []   # ability ids the current fit KNOWS (Abilities)
var _cloak_t := 0.0        # remaining cloak duration (>0 = cloaked)
var _cloak_cd := 0.0       # remaining cooldown
var _cloak_dur := 6.0      # seconds cloaked, from the fitted Umbral Cloak Field
var _cloak_cd_max := 14.0  # recharge, from the fitted cloak
var _bulwark_cd := 0.0     # remaining Bulwark cooldown
var _bulwark_cd_max := 18.0
var _bulwark_dur := 5.0
var _bulwark_radius := 420.0
var _bulwark_reduction := 0.5
# --- Profession-module actives (quartermaster gear; tuned from the module `extra`)
var _decoy_cd := 0.0
var _decoy_cd_max := 16.0
var _decoy_dur := 4.0
var _decoy_t := 0.0        # locks-broken window (feeds is_hidden)
var _repair_cd := 0.0
var _repair_cd_max := 20.0
var _repair_dur := 4.0
var _repair_radius := 380.0
var _repair_rate := 20.0
var _repair_t := 0.0       # active channel remaining
var _tangle_cd := 0.0
var _tangle_cd_max := 12.0
var _tangle_dur := 3.5
var _tangle_range := 900.0
var _warp_cd := 0.0
var _warp_cd_max := 10.0
var _warp_dist := 900.0
var _blackout_cd := 0.0
var _blackout_cd_max := 16.0
var _blackout_dur := 3.0
var _blackout_t := 0.0     # untargetable window (feeds is_hidden)
## Per-ability ENERGY costs, each pulled from its module's `<tag>_energy`.
## Survey Scan is deliberately FREE — see docs/energy_system.md.
var _cloak_energy := 22.0
var _bulwark_energy := 20.0
var _decoy_energy := 14.0
var _repair_energy := 25.0
var _drone_energy := 22.0
var _tangle_energy := 12.0
var _warp_energy := 10.0
var _blackout_energy := 14.0
## Crystalline Array (`_crystal_*`, NOT `_array_*` — `array_enabled` above is the
## weapon-group toggle and the two must not be confused).
var _crystal_cd := 0.0
var _crystal_cd_max := 16.0
var _crystal_dur := 7.0
var _crystal_radius := 128.0
var _crystal_place_range := 1000.0
var _crystal_energy := 18.0
var _overload_cd := 0.0
var _overload_cd_max := 18.0
var _overload_dur := 3.0
var _overload_range := 900.0
var _overload_energy := 16.0
var _jinx_cd := 0.0
var _jinx_cd_max := 22.0
var _jinx_t := 0.0
var _jinx_dur := 6.0
var _jinx_radius := 420.0
var _jinx_mult := 2.0
var _jinx_floor := 0.30
var _jinx_cap := 0.75
var _jinx_energy := 20.0
var _killshot_cd := 0.0
var _killshot_cd_max := 14.0
var _killshot_damage := 200.0
var _killshot_cone := 30.0        # FULL width of the forward cone, degrees
var _killshot_min_range := 300.0
var _killshot_max_range := 1800.0
var _killshot_shield_factor := 0.5
var _killshot_energy := 18.0
const KILLSHOT_RECOIL := 260.0   # backward kick on fire — the rail has weight, and it is visible feedback
var _blight_cd := 0.0
var _blight_cd_max := 20.0
var _blight_life := 30.0
var _blight_pulse := 6.0
var _blight_damage := 30.0
var _blight_range := 900.0
var _blight_energy := 6.0   # seam: drains while attached once energy exists
var _lance_cd := 0.0
var _lance_cd_max := 6.0
var _lance_damage := 120.0
var _lance_speed := 3600.0  # a FAST rail strike — a skill shot you aim by flying
var _lance_range := 1500.0
var _lance_homing := 40.0   # non-ship fallback bend (deg/SEC); the table drives ships
## Homing by the MARK's size band [light..super+], in DEGREES PER 10 UNITS TRAVELLED
## (speed-independent; see Projectile). User rule (2026-07-23): MORE bend against the
## small nimble hulls that are hard to hit, LESS against the big slow ones a straight
## lead already lands — so the hit rate evens across sizes. Starting numbers, tune freely.
const LANCE_HOMING_BY_BAND := [0.5, 0.4, 0.3, 0.2, 0.1]
var _lance_energy := 8.0    # seam: charged from the reactor once energy exists
var _drone_cd := 0.0
var _drone_cd_max := 36.0
var _drone_life := 30.0
var _drone_pulse := 3.0
var _drone_heal := 14.0
var _drone_range := 900.0
# --- Going Dark (systems offline; the in-flight Processor Bus re-flash) ---
var dark := false
var _reboot_t := 0.0       # lockout after coming back online
## Berthing cinematic: a docking/landing sequence has the helm. Physics + input
## are suspended so the pad can fly her in (or into the wall) for the beat.
var cinematic := false
const DARK_REGEN := 14.0   # hull/armor mended per second while dark ("meditation")
const DARK_ENERGY_MULT := 4.0   # energy recharge multiplier while dark
const DARK_DRAG := 0.15    # gentle drift decay — engines are cut, not braking
const REBOOT_TIME := 2.6
var wanted_t := 0.0        # WANTED heat: while >0 (or Guardian-hostile) the law hunts you
## Firing-solution state for the nose guns, computed each physics tick:
## the pip is where to point; _solution means pointing there right now —
## a shot fired this instant intersects the target's hull.
var _pip_world := Vector2.ZERO
var _pip_active := false
var _pip_in_range := false
var _solution := false
var _slide_time := 0.0
var _slide_cd := 0.0
var _slide_fx: CPUParticles2D
var _thrust_audio: AudioStreamPlayer2D
## Non-null while docked at a station pad or landed on a planetoid. Docked
## ships are hidden, invulnerable, fully repaired, and skip physics.
var docked_at: Node = null
## Salvaged components, weighed by mass against the build's cargo stat.
## Lost with the ship — hauling loot home is the risk.
var cargo: Array[ComponentDef] = []
## Stackable trade goods, key -> quantity. Same cargo budget, same risk.
var commodities: Dictionary = {}


func _ready() -> void:
	enemy_group = "hostile_team"
	add_to_group("player_ship")
	add_to_group("player_team")

	_slide_fx = CPUParticles2D.new()
	_slide_fx.emitting = false
	_slide_fx.amount = 40
	_slide_fx.lifetime = 0.35
	_slide_fx.local_coords = false
	_slide_fx.spread = 180.0
	_slide_fx.gravity = Vector2.ZERO
	_slide_fx.initial_velocity_min = 30.0
	_slide_fx.initial_velocity_max = 80.0
	_slide_fx.scale_amount_max = 1.4
	_slide_fx.color = Color(0.7, 0.9, 1.0)
	add_child(_slide_fx)

	_thrust_audio = AudioStreamPlayer2D.new()
	_thrust_audio.stream = Sfx.stream("thrust_loop")
	_thrust_audio.volume_db = -60.0
	_thrust_audio.max_distance = 900.0
	add_child(_thrust_audio)
	_thrust_audio.play()

	lock_narrow_mounts = true

	_target_marker = Node2D.new()
	_target_marker.top_level = true
	_target_marker.visible = false
	_target_marker.draw.connect(_draw_target_marker)
	add_child(_target_marker)


func sliding() -> bool:
	return _slide_time > 0.0


func apply_build(new_build: ShipBuild) -> void:
	enemy_group = "hostile_team"
	super(new_build)
	decoupler_fitted = build.has_system_tag("flight_decoupler")
	if not decoupler_fitted:
		mode = ControlMode.CONNECTED
	_scan_range = 380.0
	_scan_time = 3.2
	# Scan tuning comes from anything tagged "scanner" — a fitted module OR a chip
	# in the Coupling. The old Prospector Survey Scanner MODULE was deleted
	# (2026-07-22, vestigial: its values equalled the defaults and it never even
	# granted the ability); a "scanner" CHIP is now the upgrade path.
	for comp in build.slots.values():
		if comp is SystemDef and comp.has_tag("scanner"):
			_scan_range = float(comp.extra.get("scan_range", _scan_range))
			_scan_time = float(comp.extra.get("scan_time", _scan_time))
	for chip in build.chip_extras():
		if chip.tags.has("scanner"):
			_scan_range = float(chip.extra.get("scan_range", _scan_range))
			_scan_time = float(chip.extra.get("scan_time", _scan_time))
	_scan_time *= Research.scan_time_mult() * Pilot.scan_mult()
	_scan_progress = -1.0
	# ABILITY GEMS: the fit's activatable systems become KNOWN abilities; the
	# player MEMORIZES them into the [1]-[5] gem bar (Pilot.gems) at dock. In
	# flight a gem fires only if its ability is currently known (fitted).
	_known_abilities = Abilities.known_for_build(build)
	# "Can this ship scan?" = does it KNOW the scan ability. The ability now
	# comes from the Survey Routine CHIP (tag "scan"), not a scanner module — so
	# checking has_system_tag("scanner") reported false with the chip fitted and
	# [1] answered "NO SCANNER FITTED" on a ship that could plainly scan. Every
	# use of scanner_fitted (discovery reach, HUD range, the [1] gate) means
	# exactly "knows scan", so read it from there.
	scanner_fitted = _known_abilities.has("scan")
	# This file IS the player ship, so no ownership guard is needed here.
	Pilot.autowire(_known_abilities)   # reconcile the bus: equip wires to next open slot, unequip drops it
	# (buy_scanner + memorize now arm themselves off the dock/flight context via the
	# declarative tutor — needs_scan and has_wired_ability — no arm() call here.)
	# ("ordnance" lesson now arms itself off `carrying_ordnance` via the declarative
	# tutor — a magazine weapon aboard — and completes when they first press [Z].)
	_cloak_dur = 6.0
	_cloak_cd_max = 14.0
	for comp in _ability_sources():
		if comp.has_tag("cloak"):
			_cloak_dur = float(comp.extra.get("cloak_duration", _cloak_dur))
			_cloak_cd_max = float(comp.extra.get("cloak_cooldown", _cloak_cd_max))
			_cloak_energy = float(comp.extra.get("cloak_energy", _cloak_energy))
	_cloak_t = 0.0
	_cloak_cd = 0.0
	set_veil(1.0)
	_hidden = false
	_bulwark_dur = 5.0
	_bulwark_cd_max = 18.0
	_bulwark_radius = 420.0
	_bulwark_reduction = 0.5
	for comp in _ability_sources():
		if comp.has_tag("bulwark"):
			_bulwark_dur = float(comp.extra.get("bulwark_duration", _bulwark_dur))
			_bulwark_cd_max = float(comp.extra.get("bulwark_cooldown", _bulwark_cd_max))
			_bulwark_radius = float(comp.extra.get("bulwark_radius", _bulwark_radius))
			_bulwark_reduction = float(comp.extra.get("bulwark_reduction", _bulwark_reduction))
			_bulwark_energy = float(comp.extra.get("bulwark_energy", _bulwark_energy))
	_bulwark_cd = 0.0
	_dmg_reduction = 0.0
	_bulwark_t = 0.0
	# Profession-module actives: pull each fitted module's tuning from its `extra`.
	_decoy_cd_max = 16.0; _decoy_dur = 4.0
	_repair_cd_max = 20.0; _repair_dur = 4.0; _repair_radius = 380.0; _repair_rate = 20.0
	_tangle_cd_max = 12.0; _tangle_dur = 3.5; _tangle_range = 900.0
	_warp_cd_max = 10.0; _warp_dist = 900.0
	_blackout_cd_max = 16.0; _blackout_dur = 3.0
	_drone_cd_max = 36.0; _drone_life = 30.0; _drone_pulse = 3.0
	_drone_heal = 14.0; _drone_range = 900.0
	_lance_cd_max = 6.0; _lance_damage = 120.0; _lance_speed = 3600.0
	_lance_range = 1500.0; _lance_homing = 40.0; _lance_energy = 8.0
	_blight_cd_max = 20.0; _blight_life = 30.0; _blight_pulse = 6.0
	_blight_damage = 30.0; _blight_range = 900.0; _blight_energy = 6.0
	_cloak_energy = 22.0; _bulwark_energy = 20.0; _decoy_energy = 14.0
	_repair_energy = 25.0; _drone_energy = 22.0; _tangle_energy = 12.0
	_warp_energy = 10.0; _blackout_energy = 14.0
	_crystal_cd_max = 16.0; _crystal_dur = 7.0; _crystal_radius = 128.0
	_crystal_place_range = 1000.0; _crystal_energy = 18.0
	_overload_cd_max = 18.0; _overload_dur = 3.0; _overload_range = 900.0
	_overload_energy = 16.0
	_jinx_cd_max = 22.0; _jinx_dur = 6.0; _jinx_radius = 420.0
	_jinx_mult = 2.0; _jinx_floor = 0.30; _jinx_cap = 0.75; _jinx_energy = 20.0
	_killshot_cd_max = 14.0; _killshot_damage = 200.0; _killshot_cone = 30.0
	_killshot_min_range = 300.0; _killshot_max_range = 1800.0
	_killshot_shield_factor = 0.5; _killshot_energy = 18.0
	# CHIPS FIRST, then fitted modules: the Coupling is where abilities live now,
	# but a pre-Coupling save still has its modules bolted on and must keep
	# working. Both expose `has_tag` + `extra`, so one loop reads either.
	for comp in _ability_sources():
		if comp.has_tag("decoy"):
			_decoy_cd_max = float(comp.extra.get("decoy_cooldown", _decoy_cd_max))
			_decoy_dur = float(comp.extra.get("decoy_duration", _decoy_dur))
			_decoy_energy = float(comp.extra.get("decoy_energy", _decoy_energy))
		if comp.has_tag("repair"):
			_repair_cd_max = float(comp.extra.get("repair_cooldown", _repair_cd_max))
			_repair_dur = float(comp.extra.get("repair_duration", _repair_dur))
			_repair_radius = float(comp.extra.get("repair_radius", _repair_radius))
			_repair_rate = float(comp.extra.get("repair_rate", _repair_rate))
			_repair_energy = float(comp.extra.get("repair_energy", _repair_energy))
		if comp.has_tag("tangle"):
			_tangle_cd_max = float(comp.extra.get("tangle_cooldown", _tangle_cd_max))
			_tangle_dur = float(comp.extra.get("tangle_duration", _tangle_dur))
			_tangle_range = float(comp.extra.get("tangle_range", _tangle_range))
			_tangle_energy = float(comp.extra.get("tangle_energy", _tangle_energy))
		if comp.has_tag("warp"):
			_warp_cd_max = float(comp.extra.get("warp_cooldown", _warp_cd_max))
			_warp_dist = float(comp.extra.get("warp_distance", _warp_dist))
			_warp_energy = float(comp.extra.get("warp_energy", _warp_energy))
		if comp.has_tag("blackout"):
			_blackout_cd_max = float(comp.extra.get("blackout_cooldown", _blackout_cd_max))
			_blackout_dur = float(comp.extra.get("blackout_duration", _blackout_dur))
			_blackout_energy = float(comp.extra.get("blackout_energy", _blackout_energy))
		if comp.has_tag("crystal"):
			_crystal_cd_max = float(comp.extra.get("crystal_cooldown", _crystal_cd_max))
			_crystal_dur = float(comp.extra.get("crystal_duration", _crystal_dur))
			_crystal_radius = float(comp.extra.get("crystal_radius", _crystal_radius))
			_crystal_place_range = float(comp.extra.get("crystal_place_range", _crystal_place_range))
			_crystal_energy = float(comp.extra.get("crystal_energy", _crystal_energy))
		if comp.has_tag("overload"):
			_overload_cd_max = float(comp.extra.get("overload_cooldown", _overload_cd_max))
			_overload_dur = float(comp.extra.get("overload_duration", _overload_dur))
			_overload_range = float(comp.extra.get("overload_range", _overload_range))
			_overload_energy = float(comp.extra.get("overload_energy", _overload_energy))
		if comp.has_tag("jinx"):
			_jinx_cd_max = float(comp.extra.get("jinx_cooldown", _jinx_cd_max))
			_jinx_dur = float(comp.extra.get("jinx_duration", _jinx_dur))
			_jinx_radius = float(comp.extra.get("jinx_radius", _jinx_radius))
			_jinx_mult = float(comp.extra.get("jinx_mult", _jinx_mult))
			_jinx_floor = float(comp.extra.get("jinx_floor", _jinx_floor))
			_jinx_cap = float(comp.extra.get("jinx_cap", _jinx_cap))
			_jinx_energy = float(comp.extra.get("jinx_energy", _jinx_energy))
		if comp.has_tag("killshot"):
			_killshot_cd_max = float(comp.extra.get("killshot_cooldown", _killshot_cd_max))
			_killshot_damage = float(comp.extra.get("killshot_damage", _killshot_damage))
			_killshot_cone = float(comp.extra.get("killshot_cone", _killshot_cone))
			_killshot_min_range = float(comp.extra.get("killshot_min_range", _killshot_min_range))
			_killshot_max_range = float(comp.extra.get("killshot_max_range", _killshot_max_range))
			_killshot_shield_factor = float(comp.extra.get("killshot_shield_factor", _killshot_shield_factor))
			_killshot_energy = float(comp.extra.get("killshot_energy", _killshot_energy))
		if comp.has_tag("blight"):
			_blight_cd_max = float(comp.extra.get("blight_cooldown", _blight_cd_max))
			_blight_life = float(comp.extra.get("blight_life", _blight_life))
			_blight_pulse = float(comp.extra.get("blight_pulse", _blight_pulse))
			_blight_damage = float(comp.extra.get("blight_damage", _blight_damage))
			_blight_range = float(comp.extra.get("blight_range", _blight_range))
			_blight_energy = float(comp.extra.get("blight_energy", _blight_energy))
		if comp.has_tag("lance"):
			_lance_cd_max = float(comp.extra.get("lance_cooldown", _lance_cd_max))
			_lance_damage = float(comp.extra.get("lance_damage", _lance_damage))
			_lance_speed = float(comp.extra.get("lance_speed", _lance_speed))
			_lance_range = float(comp.extra.get("lance_range", _lance_range))
			_lance_homing = float(comp.extra.get("lance_homing", _lance_homing))
			_lance_energy = float(comp.extra.get("lance_energy", _lance_energy))
		if comp.has_tag("repair_drone"):
			_drone_cd_max = float(comp.extra.get("repair_drone_cooldown", _drone_cd_max))
			_drone_life = float(comp.extra.get("repair_drone_life", _drone_life))
			_drone_pulse = float(comp.extra.get("repair_drone_pulse", _drone_pulse))
			_drone_heal = float(comp.extra.get("repair_drone_heal", _drone_heal))
			_drone_range = float(comp.extra.get("repair_drone_range", _drone_range))
			_drone_energy = float(comp.extra.get("repair_drone_energy", _drone_energy))
	_decoy_cd = 0.0; _decoy_t = 0.0
	_repair_cd = 0.0; _repair_t = 0.0
	_tangle_cd = 0.0; _warp_cd = 0.0
	_blackout_cd = 0.0; _blackout_t = 0.0
	_drone_cd = 0.0; _lance_cd = 0.0; _blight_cd = 0.0; _killshot_cd = 0.0
	_jinx_cd = 0.0; _jinx_t = 0.0; _overload_cd = 0.0; _crystal_cd = 0.0
	# Pilot-background feel traits: tiny, player-only.
	_turn_speed *= Pilot.turn_mult()
	# Commission energy rate (player-only; AI ships stay at 1.0).
	energy_regen_mult = Pilot.energy_regen_mult()
	for mount in _mounts:
		mount.traverse_mult = Pilot.traverse_mult()
		mount.damage_mult = Pilot.damage_mult()
	# Pilot LEVEL buffs (player-only): raw combat growth onto the aggregated
	# maxes + skill efficiencies, then current hp topped to the new max. AI
	# ships never run this override, so their stats stay honest.
	stats.hull_hp *= Pilot.hull_mult()
	stats.armor_hp *= Pilot.armor_mult()
	stats.shield_hp *= Pilot.shield_hp_mult()
	stats.shield_regen *= Pilot.shield_regen_mult()
	stats.cargo *= Pilot.cargo_mult()
	# Miner commission perk: mineable rock paints the radar (see Radar._draw).
	stats["ore_sense"] = float(stats.get("ore_sense", 0.0)) + Pilot.ore_sense_range()
	hull = stats.hull_hp
	armor = stats.armor_hp
	shield = stats.shield_hp
	evasion = Pilot.evasion()
	_add_demo_livery()


## Stencil demo: two amber racing stripes, clipped to the hull silhouette by
## clip_children — lazy full-width bars that only show where hull pixels are.
## Becomes the data-driven livery system later.
func _add_demo_livery() -> void:
	if _hull_sprite == null:
		return
	for offset_y in [-3.0, 2.0]:
		var stripe := Polygon2D.new()
		stripe.polygon = PackedVector2Array([
			Vector2(-16, offset_y), Vector2(16, offset_y - 4.0),
			Vector2(16, offset_y - 2.0), Vector2(-16, offset_y + 2.0)])
		stripe.color = Color(0.95, 0.62, 0.2, 0.85)
		_hull_sprite.add_child(stripe)


## Repairs cost credits now (the first economy sink). Shield recharge stays
## free — it regenerates on its own anyway. If the wallet can't cover the
## yard bill, you get PARTIAL repairs, never a refusal — and the dock
## screen shows the bill either way.
const HULL_REPAIR_COST := 1.0    # credits per hull point
const ARMOR_REPAIR_COST := 0.5   # credits per armor point

var dock_bill := {"repairs": 0, "ammo": 0}
## Why the last approach was graded down, if it was. Set by the pad/planetoid at
## touchdown and read by the dock screen — NOT by _flash_note, which draws on the
## flight HUD and is wiped the same frame docking hides it. The lesson has to be
## waiting where the bill is, or the player never sees it at all.
var approach_fault := ""


func dock(target_host: Node) -> void:
	docked_at = target_host
	_scan_progress = -1.0
	velocity = Vector2.ZERO
	visible = false
	shield = stats.shield_hp
	energy = energy_max      # the bay tops the bus off; charge is never billed
	var missing_hull: float = stats.hull_hp - hull
	var missing_armor: float = stats.armor_hp - armor
	var repair_cost := int(ceil((missing_hull * HULL_REPAIR_COST + missing_armor * ARMOR_REPAIR_COST) \
		* Research.repair_cost_mult() * Pilot.repair_mult()))
	var repair_paid := mini(repair_cost, Wallet.credits)
	if repair_cost > 0 and repair_paid > 0:
		var fraction := float(repair_paid) / float(repair_cost)
		hull = minf(hull + missing_hull * fraction, stats.hull_hp)
		armor = minf(armor + missing_armor * fraction, stats.armor_hp)
		Wallet.credits -= repair_paid
	# Ordnance restock: per-round, until full or broke.
	var ammo_paid := 0
	for mount in _mounts:
		if mount.def.magazine <= 0:
			continue
		while mount.ammo < mount.def.magazine and Wallet.credits >= mount.def.ammo_price:
			Wallet.credits -= mount.def.ammo_price
			mount.ammo += 1
			ammo_paid += mount.def.ammo_price
	dock_bill = {"repairs": repair_paid, "ammo": ammo_paid}
	# Docking advances the research calendar one game day and processes
	# discovery-chain stages (rumors, turn-ins, hauls) — before the save,
	# so what the lab consumed and concluded is what gets checkpointed. The Rust
	# Shoal is a lawless haven, NEITHER station nor colony — it runs no research
	# calendar and posts no contract board, so it skips these hooks entirely.
	# A bare berth (the Shoal; Orivel's capital pads while it has no services)
	# repairs + saves but runs NO station economy — no research calendar, no
	# contract board, no auto-started quests. Everything else runs the full hooks.
	var bare: bool = target_host is ShoalPad \
		or (target_host is DockingPad and not target_host.runs_dock_services)
	if not bare:
		Research.on_dock(target_host is DockingPad, self)
		Quests.on_dock(target_host is DockingPad, self, SaveGame.tutorial_done)
	# Docking is the save checkpoint: safe harbor (even a den), saved progress.
	SaveGame.save_game(self)


func undock() -> void:
	if docked_at == null:
		return
	var host := docked_at
	docked_at = null
	visible = true
	host.undock_exit(self)


func take_damage(amount: float, source: Node = null) -> void:
	if docked_at != null:
		return
	super(amount, source)


func cargo_used() -> float:
	var used := 0.0
	for comp in cargo:
		used += comp.mass
	for key in commodities:
		used += commodities[key] * TradeGoods.unit_mass(key)
	return used


func can_carry(comp: ComponentDef) -> bool:
	return can_carry_mass(comp.mass)


func can_carry_mass(mass: float) -> bool:
	return cargo_used() + mass <= stats.cargo


func add_cargo(comp: ComponentDef) -> void:
	cargo.append(comp)


func add_commodity(key: String, qty: int) -> void:
	commodities[key] = commodities.get(key, 0) + qty


func remove_commodity(key: String, qty: int) -> void:
	commodities[key] = maxi(0, commodities.get(key, 0) - qty)
	if commodities[key] == 0:
		commodities.erase(key)


# Raw events, deliberately not InputMap actions: the running editor can
# clobber project.godot additions, silently killing action-based bindings.
func _unhandled_input(event: InputEvent) -> void:
	if dead or docked_at != null or dark or cinematic:
		return   # dark = systems offline: no gems, no targeting (the Bus is re-flashed in the overlay)
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		_rmb_at(get_global_mouse_position())
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_T:
				_cycle_target(enemy_group)
			KEY_Y:
				_cycle_target("friendly_targets")
			KEY_1:
				_activate_gem(0)
			KEY_2:
				_activate_gem(1)
			KEY_3:
				_activate_gem(2)
			KEY_4:
				_activate_gem(3)
			KEY_5:
				_activate_gem(4)
			KEY_Z:
				_toggle_array(1, "ORDNANCE")   # guns stay hot; [Z] holds ordnance
				Tutor.did("held_ordnance")     # completes the "ordnance" lesson


## Cycle sensor-range contacts in a group, nearest first, wrapping. The
## reliable complement to clicking at things that jink at 300 units/second.
func _cycle_target(group: String) -> void:
	var sensor := maxf(600.0, float(stats.get("sensor_range", 0.0)))
	var candidates: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group(group):
		if node == self or node.get("dead") == true:
			continue
		if global_position.distance_to(node.global_position) <= sensor:
			candidates.append(node)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return global_position.distance_squared_to(a.global_position) \
			< global_position.distance_squared_to(b.global_position))
	var idx := candidates.find(target)   # -1 when untargeted -> nearest
	target = candidates[(idx + 1) % candidates.size()]
	Sfx.play("click", -6.0, 1.35 if group == enemy_group else 1.1)


## Right-click does the forgiving thing: near ONE piece of loot, grab it;
## near several overlapping, open the salvage window to pick; near nothing
## grabbable, fall back to selecting a target.
func _rmb_at(point: Vector2) -> void:
	var loot := _loot_near(point, SALVAGE_RADIUS)
	if loot.size() == 1:
		grab_loot(loot[0])
	elif loot.size() > 1:
		var panel := get_tree().get_first_node_in_group("salvage_panel")
		if panel != null:
			panel.open()
		else:
			grab_loot(loot[0])   # no window available — take the nearest
	else:
		_select_target_at(point)


## Loot within `radius` of a world point, nearest first.
func _loot_near(point: Vector2, radius: float) -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("loot"):
		if is_instance_valid(n) and point.distance_to(n.global_position) <= radius:
			out.append(n)
	out.sort_custom(func(a, b) -> bool:
		return point.distance_squared_to(a.global_position) \
			< point.distance_squared_to(b.global_position))
	return out


## Try to pull a specific pickup aboard. Full hold -> visible refusal.
func grab_loot(loot) -> bool:
	if not is_instance_valid(loot):
		return false
	if not can_carry_mass(loot.payload_mass()):
		note_hold_full()
		return false
	if loot.def != null:
		add_cargo(loot.def)
	else:
		add_commodity(loot.commodity, 1)
	Sfx.play("pickup", -8.0, 1.2)
	loot.queue_free()
	return true


## Drop cargo back into space to make room — the item drifts clear (armed
## delay) so it doesn't snap straight back into the hold.
func jettison_component(comp: ComponentDef) -> void:
	if not cargo.has(comp):
		return
	cargo.erase(comp)
	_eject(LootPickup.spawn(get_parent(), global_position, comp))
	_flash_note("Jettisoned %s." % comp.display_name)


func jettison_commodity(key: String) -> void:
	if commodities.get(key, 0) <= 0:
		return
	remove_commodity(key, 1)
	_eject(LootPickup.spawn_commodity(get_parent(), global_position, key))
	_flash_note("Jettisoned %s." % TradeGoods.display_name(key))


func _eject(loot) -> void:
	loot.arm_delay = 3.5
	loot._velocity = Vector2.RIGHT.rotated(randf() * TAU) * 140.0
	Sfx.play("click", -12.0, 0.7)


## Hail a friendly from the roster (left-click). A friendly that carries a
## dialogue opens it; everyone else answers with a canned comm. This is the
## seam for NPC-ship talks and, later, coop teammate pings.
func hail_friendly(member: Node2D) -> void:
	if member == null or not is_instance_valid(member):
		return
	var who: String = member.build.hull.display_name if member.get("build") != null else "wingman"
	# TODO(coop/NPCs): if member has an npc_id + dialogue, open DialoguePanel.
	_flash_note("%s: \"Reading you, Captain. Holding station — call if it gets loud.\"" % who)
	Sfx.play("click", -8.0, 1.3)


## Throttled so flying along a full hold isn't a wall of banners.
func note_hold_full() -> void:
	if _hold_full_cd > 0.0:
		return
	_hold_full_cd = 2.5
	_flash_note("HOLD FULL %d/%.0f — [B] to manage cargo & jettison" % [
		int(cargo_used()), stats.cargo])
	# ("salvage" lesson arms itself off `hold_full` via the declarative tutor.)


func _select_target_at(point: Vector2) -> void:
	Tutor.note("radar")   # RIGHT-CLICK targeting learned by doing it
	var best: Node2D = null
	var best_d := TARGET_CLICK_RADIUS
	# Hostiles and scannables (rocks) are both clickable targets.
	for group in [enemy_group, "scannable"]:
		for node in get_tree().get_nodes_in_group(group):
			if node.get("dead") == true:
				continue
			var d: float = point.distance_to(node.global_position)
			if d < best_d:
				best_d = d
				best = node
	target = best
	if target != null:
		Sfx.play("click", -6.0, 1.35)


## The player feels a collision: a note whose words scale with the force, plus
## the thud. AI takes the same damage silently (base class).
func on_collision_impact(dmg: float, impact_speed: float) -> void:
	super.on_collision_impact(dmg, impact_speed)
	if impact_speed > 620.0:
		_flash_note("HULL IMPACT — %d damage" % int(round(dmg)))
	else:
		_flash_note("Scrape — %d damage" % int(round(dmg)))


func _try_start_scan() -> void:
	if not scanner_fitted:
		_ability_fail("NO SCAN ABILITY — buy the Survey Routine chip (Armory), fit it in the Coupling")
		return
	if not _target_valid():
		_ability_fail("SCAN: no target selected (RMB / T)")
		return
	if global_position.distance_to(target.global_position) > _scan_range:
		_ability_fail("SCAN: out of range — close to %du" % int(_scan_range))
		return
	_scan_progress = 0.0
	Sfx.play("click", -8.0, 0.8)


func _flash_note(text: String) -> void:
	scan_note = text
	scan_note_t = 2.5
	scan_note_fail = false


## An ability that CANNOT fire aborts through here (user, 2026-07-23): an
## unmistakable FAILURE cue — a red "✕" note that lingers a beat longer + a distinct
## low thunk, NOT the soft nav click — so a skill that does nothing SAYS so, and
## why. Callers abort BEFORE spending energy/cooldown, so a refused ability is free.
func _ability_fail(reason: String) -> void:
	scan_note = "✕ " + reason
	scan_note_t = 3.2
	scan_note_fail = true
	Sfx.play("click", -6.0, 0.32)


func _tick_scan(delta: float) -> void:
	scan_note_t = maxf(0.0, scan_note_t - delta)
	_hold_full_cd = maxf(0.0, _hold_full_cd - delta)
	if _scan_progress < 0.0:
		return
	if not _target_valid():
		_scan_progress = -1.0
		_flash_note("SCAN ABORTED: target lost")
		return
	if global_position.distance_to(target.global_position) > _scan_range * 1.15:
		_scan_progress = -1.0
		_flash_note("SCAN ABORTED: out of range")
		return
	_scan_progress += delta
	if _scan_progress >= _scan_time:
		_scan_progress = -1.0
		_finish_scan()


func scanning() -> bool:
	return _scan_progress >= 0.0


func scan_fraction() -> float:
	return clampf(_scan_progress / _scan_time, 0.0, 1.0)


func _finish_scan() -> void:
	Sfx.play("pickup", -8.0, 1.4)
	if target is Anomaly:
		# A quest reading: no ore, no Scan Data — surveying it IS the beat.
		_flash_note("SCAN: " + target.survey_text())
		Quests.note_scan_target(target.quest_id)
		target.on_scanned()
		return
	if target is MineableAsteroid:
		# First-time surveys count toward triangulation chains; re-scanning
		# the same rock is not exploration — and the HUD must SAY so, or the
		# player grinds identical rocks wondering why the counter is stuck.
		var counted := false
		if not target.surveyed:
			counted = Research.note_rock_survey()
		target.surveyed = true
		var note: String = "SURVEY: " + target.survey_text()
		if Research.survey_hunt_active():
			note += "   [triangulation %s%s]" % [Research.survey_progress_text(),
				"" if counted else " — this rock was already surveyed"]
		elif counted:
			note += "   [TRIANGULATION COMPLETE — new site charted]"
		_flash_note(note)
		_grant_scan_data(1)
		return
	# Living things pay better: ships 2, the leviathan 5. Scanning the
	# Cinderweb at gaze range is exactly the terrible idea it sounds like.
	_grant_scan_data(5 if target.is_in_group("leviathan") else 2)


func _grant_scan_data(units: int) -> void:
	units += Research.scan_bonus()
	var granted := 0
	for i in units:
		if can_carry_mass(TradeGoods.unit_mass("scan_data")):
			add_commodity("scan_data", 1)
			granted += 1
	if granted < units:
		_flash_note("SCAN COMPLETE — HOLD FULL: %d/%d data stored" % [granted, units])
	elif scan_note_t <= 0.0:
		_flash_note("SCAN COMPLETE: +%d Scan Data" % granted)


## Gem bar: [1]-[5] fire the ability MEMORIZED into that slot (Pilot.gems), but
## only if the fit currently KNOWS it — an empty slot clicks softly, a gemmed
## ability whose module isn't fitted reports the gap instead of firing.
func _activate_gem(i: int) -> void:
	var aid := Pilot.gem_at(i)
	if aid == "":
		_ability_fail("BUS SLOT %d EMPTY — wire an ability at dock (Pilot tab)" % (i + 1))
		return
	if not _known_abilities.has(aid):
		_ability_fail("%s — MODULE NOT FITTED (fit its chip in Engineering)" % Abilities.display_name(aid))
		return
	# Firing a wired ability in flight completes the "memorize" lesson's last step
	# ("SYSTEM LIVE — press its key"). Without this the step had NO completion hook
	# and hung 50s until the watchdog killed it — the most satisfying beat in the
	# ability tutorial landed on a shrug. (Found in the stall log, 2026-07-23.)
	Tutor.did("fired_ability")   # completes the "memorize" (now: firing) lesson
	match aid:
		"scan":
			_try_start_scan()
		"cloak":
			_engage_cloak()
		"bulwark":
			_engage_bulwark()
		"decoy_flare":
			_engage_decoy()
		"repair_field":
			_engage_repair()
		"repair_drone":
			_engage_drone()
		"lance":
			_engage_lance()
		"blight":
			_engage_blight()
		"killshot":
			_engage_killshot()
		"jinx":
			_engage_jinx()
		"overload":
			_engage_overload()
		"crystal":
			_engage_crystal()
		"tangle_shot":
			_engage_tangle()
		"warp_jump":
			_engage_warp()
		"blackout":
			_engage_blackout()


## Umbral Cloak: a TIMED disengage, not a toggle. Engage → hostiles lose lock
## (is_hidden gates AI acquisition) and the hull goes translucent for _cloak_dur;
## then it fades and recharges. Firing a weapon collapses it (see _physics_process).
func _engage_cloak() -> void:
	if _cloak_t > 0.0:
		return   # already running
	if _cloak_cd > 0.0:
		_ability_fail("CLOAK COOLING — %.0fs" % ceil(_cloak_cd))
		return
	_cloak_t = _cloak_dur
	_hidden = true
	set_veil(0.32)
	_flash_note("CLOAK ENGAGED")
	Sfx.play("click", -4.0, 1.35)


func _drop_cloak(reason: String) -> void:
	if _cloak_t <= 0.0 and not _hidden:
		return
	_cloak_t = 0.0
	if not _spend(_cloak_energy, "Cloak"):
		return
	_cloak_cd = _cloak_cd_max
	_hidden = false
	set_veil(1.0)
	if reason != "":
		_flash_note(reason)
	Sfx.play("click", -8.0, 0.7)


## Bulwark Projector: brace self + every ally in radius with damage reduction for
## _bulwark_dur, and throw up the blue dome. A boss-burst cooldown, no offense.
func _engage_bulwark() -> void:
	if _bulwark_cd > 0.0:
		_ability_fail("BULWARK COOLING — %.0fs" % ceil(_bulwark_cd))
		return
	if not _spend(_bulwark_energy, "Bulwark"):
		return
	_bulwark_cd = _bulwark_cd_max
	var n := 1
	apply_bulwark(_bulwark_reduction, _bulwark_dur)
	for grp in ["player_team", "friendly_targets"]:
		for ally in get_tree().get_nodes_in_group(grp):
			if ally == self or not (ally is BuildShip) or ally.dead:
				continue
			if global_position.distance_to(ally.global_position) <= _bulwark_radius:
				ally.apply_bulwark(_bulwark_reduction, _bulwark_dur)
				n += 1
	var field: Node2D = preload("res://scenes/flight/bulwark_field.gd").new()
	field.radius = _bulwark_radius
	field.life = _bulwark_dur
	add_child(field)
	_flash_note("BULWARK UP — %d shielded" % n)
	Sfx.play("click", -4.0, 0.8)


# --- Profession-module actives (Processor Bus abilities) ---------------------
# One dispatch arm each in _activate_gem; tuning lives on the fitted module's
# `extra`, read in apply_build. All gate on their own cooldown, and every
# rejection is spoken (the VISIBLE-rejection rule).

## Per-frame upkeep for the module actives: cool the cooldowns, run the repair
## channel, and expire the soft-hide windows (decoy / blackout).
func _tick_module_actives(delta: float) -> void:
	_decoy_cd = maxf(0.0, _decoy_cd - delta)
	_tangle_cd = maxf(0.0, _tangle_cd - delta)
	_warp_cd = maxf(0.0, _warp_cd - delta)
	_drone_cd = maxf(0.0, _drone_cd - delta)
	_lance_cd = maxf(0.0, _lance_cd - delta)
	_blight_cd = maxf(0.0, _blight_cd - delta)
	_killshot_cd = maxf(0.0, _killshot_cd - delta)
	_overload_cd = maxf(0.0, _overload_cd - delta)
	_crystal_cd = maxf(0.0, _crystal_cd - delta)
	if _jinx_t > 0.0:
		_jinx_t -= delta
	else:
		_jinx_cd = maxf(0.0, _jinx_cd - delta)
	if _repair_t > 0.0:
		_repair_t -= delta
		_run_repair(delta)
	else:
		_repair_cd = maxf(0.0, _repair_cd - delta)
	if _decoy_t > 0.0:
		_decoy_t -= delta
		if _decoy_t <= 0.0:
			_end_soft_hide()
	if _blackout_t > 0.0:
		_blackout_t -= delta
		if _blackout_t <= 0.0:
			_end_soft_hide()
			_flash_note("TRANSPONDER RESTORED")
	else:
		_blackout_cd = maxf(0.0, _blackout_cd - delta)


## TEACH, don't do it for them (2026-07-22, user). When the ship knows an ability
## that isn't in any gem, arm the "memorize" lesson — the dock screen then PINGS
## the Pilot tab and the loadout panel until the pilot memorizes it themselves.
## Quietly slotting it would hide the entire gem system behind a convenience.
## Does the pilot have a live reason to SCAN but no way to do it? Covers both a
## quest scan stage (cold_patch) AND a Research survey lead (the belt/Expedition
## survey — survey_rocks). Shared by the dock so the lesson fires whether the
## trigger is a refit or simply arriving at the station holding the lead.
func _needs_scan_ability() -> bool:
	if _known_abilities.has("scan"):
		return false
	if Research.needs_scanner():
		return true
	for id in Quests.active:
		if Quests.stage_def(id).get("kind", "") == "scan_target":
			return true
	return false


func _arm_memorize_lesson() -> void:
	# The lab has asked for a scan and there is no scanner aboard: teach the
	# whole gear loop (buy → fit) first. It ends holding an ability, which arms
	# the memorize lesson below on the very next apply_build.
	if _needs_scan_ability():
		Tutor.arm("buy_scanner")
		return
	if _known_abilities.is_empty():
		return
	for aid in _known_abilities:
		for i in Pilot.GEM_SLOTS:
			if Pilot.gem_at(i) == aid:
				return      # something is already memorized; they know the drill
	Tutor.arm("memorize")


## Everything that can carry an ability tag + tuning: chips in the Coupling
## first, then fitted modules (legacy saves). Both duck-type `has_tag`/`extra`.
func _ability_sources() -> Array:
	var out := []
	if build != null:
		out.append_array(build.chip_extras())
		for comp in build.slots.values():
			if comp is SystemDef:
				out.append(comp)
	return out


## HUD hook for the gem bar: seconds ACTIVE (an effect running) and seconds of
## COOLDOWN left for a gemmed ability, so the bar can draw a live sweep without
## reaching into each ability's private timers. Unknown/instant ids read zero.
func gem_state(aid: String) -> Dictionary:
	match aid:
		"scan":
			# A channel, not a cooldown: "active" counts down the remaining survey
			# so the first gem a pilot ever presses actually shows it working.
			return {"active": maxf(0.0, _scan_time - _scan_progress) if scanning() else 0.0,
				"cd": 0.0, "cd_max": 0.0}
		"cloak":
			return {"active": _cloak_t, "cd": _cloak_cd, "cd_max": _cloak_cd_max}
		"bulwark":
			return {"active": _bulwark_t, "cd": _bulwark_cd, "cd_max": _bulwark_cd_max}
		"decoy_flare":
			return {"active": _decoy_t, "cd": _decoy_cd, "cd_max": _decoy_cd_max}
		"repair_field":
			return {"active": _repair_t, "cd": _repair_cd, "cd_max": _repair_cd_max}
		"repair_drone":
			return {"active": 0.0, "cd": _drone_cd, "cd_max": _drone_cd_max}
		"lance":
			return {"active": 0.0, "cd": _lance_cd, "cd_max": _lance_cd_max}
		"blight":
			return {"active": 0.0, "cd": _blight_cd, "cd_max": _blight_cd_max}
		"killshot":
			return {"active": 0.0, "cd": _killshot_cd, "cd_max": _killshot_cd_max}
		"jinx":
			return {"active": _jinx_t, "cd": _jinx_cd, "cd_max": _jinx_cd_max}
		"overload":
			return {"active": 0.0, "cd": _overload_cd, "cd_max": _overload_cd_max}
		"crystal":
			return {"active": 0.0, "cd": _crystal_cd, "cd_max": _crystal_cd_max}
		"tangle_shot":
			return {"active": 0.0, "cd": _tangle_cd, "cd_max": _tangle_cd_max}
		"warp_jump":
			return {"active": 0.0, "cd": _warp_cd, "cd_max": _warp_cd_max}
		"blackout":
			return {"active": _blackout_t, "cd": _blackout_cd, "cd_max": _blackout_cd_max}
	return {"active": 0.0, "cd": 0.0, "cd_max": 0.0}


## AI acquisition drops the ship while cloaked OR soft-hidden (blackout kills the
## transponder; decoy pulls locks onto the flare). Composes with the cloak.
func is_hidden() -> bool:
	return _hidden or _blackout_t > 0.0 or _decoy_t > 0.0


## Restore full opacity once nothing is hiding us (cloak owns its own fade).
func _end_soft_hide() -> void:
	if _cloak_t <= 0.0 and _blackout_t <= 0.0 and _decoy_t <= 0.0 and not _hidden:
		set_veil(1.0)


# --- Going Dark: systems offline, in-flight Processor Bus re-flash ------------
func is_dark() -> bool:
	return dark


func can_go_dark() -> bool:
	return not dead and docked_at == null and not dark and _reboot_t <= 0.0


func enter_dark() -> void:
	dark = true
	target = null            # sensors offline: the lock drops
	_drop_cloak("")          # a cloak can't run with the reactor cold
	# With nothing else drawing on the bus the pool refills fast — the
	# "meditation" the Going Dark design was always pointing at.
	energy_regen_mult = Pilot.energy_regen_mult() * DARK_ENERGY_MULT
	_flash_note("GOING DARK — all systems offline")


func exit_dark() -> void:
	if not dark:
		return
	dark = false
	energy_regen_mult = Pilot.energy_regen_mult()
	_reboot_t = REBOOT_TIME
	_flash_note("SYSTEMS REBOOTING…")


## While dark: drift (engines cut), shields offline, sensors blind, hull/armor
## slowly mend. Called from _physics_process BEFORE the weapons/targeting code,
## which is skipped entirely — nothing but drift and meditation runs.
func _tick_dark(delta: float) -> void:
	if _target_marker != null:
		_target_marker.visible = false
	shield = 0.0                          # offline: no absorption while dark
	repair(DARK_REGEN * delta)            # emergency mend (hull, then armor)
	velocity *= exp(-DARK_DRAG * delta)   # drift, gentle decay
	var pre := velocity
	move_and_slide()
	if get_slide_collision_count() > 0:
		bounce_off_obstacles(pre)
	_update_plumes(Vector2.ZERO, false)


## Trader Decoy Flare (was Privateer until the 2026-07-22 role swap): break locks
## (soft-hide window) + eject a flare the
## enemy fire-control chases in your place.
func _engage_decoy() -> void:
	if _decoy_t > 0.0:
		return
	if _decoy_cd > 0.0:
		_ability_fail("DECOY COOLING — %.0fs" % ceil(_decoy_cd))
		return
	if not _spend(_decoy_energy, "Decoy"):
		return
	_decoy_cd = _decoy_cd_max
	_decoy_t = _decoy_dur
	set_veil(0.5)
	var d: Decoy = preload("res://scenes/flight/decoy.gd").new()
	d.life = _decoy_dur
	d.velocity = velocity * 0.6
	get_parent().add_child(d)
	d.global_position = global_position
	_flash_note("DECOY AWAY — locks broken")
	Sfx.play("click", -4.0, 1.3)


## Science Repair Field: a green dome that channels hull/armor into you and every
## ally inside it for the duration (_run_repair ticks while _repair_t > 0).
func _engage_repair() -> void:
	if _repair_t > 0.0:
		return
	if _repair_cd > 0.0:
		_ability_fail("REPAIR FIELD COOLING — %.0fs" % ceil(_repair_cd))
		return
	if not _spend(_repair_energy, "Repair Field"):
		return
	_repair_cd = _repair_cd_max
	_repair_t = _repair_dur
	var field: Node2D = preload("res://scenes/flight/bulwark_field.gd").new()
	field.radius = _repair_radius
	field.life = _repair_dur
	field.modulate = Color(0.5, 1.05, 0.6)   # tint the blue dome green — a healing field
	add_child(field)
	_flash_note("REPAIR FIELD UP")
	Sfx.play("click", -4.0, 0.9)


## ENERGY GATE — every module ability routes its cost through here. Returns
## false and says WHY when the pool is short, so a dead key is never silent
## (the project rule: every rejection must be visible).
##
## Called only AFTER an ability's other checks pass, so a mis-aimed or
## out-of-range press costs nothing — you are charged for what you actually do.
func _spend(cost: float, label: String) -> bool:
	if cost <= 0.0:
		return true
	if energy < cost:
		_ability_fail("NOT ENOUGH ENERGY — %s needs %d, have %d" % [
			label.to_upper(), int(ceil(cost)), int(floor(energy))])
		Telemetry.note("energy", "%s starved (had %d, needed %d)" % [
			label, int(floor(energy)), int(ceil(cost))])
		return false
	energy -= cost
	return true


## FULL LIVE STATS for a gemmed ability — energy, cooldown, channel, duration,
## range and effect — read off the FITTED module, so a better chip shows better
## numbers with no extra wiring. Keys are optional; the tooltip renders whatever
## is present. `cd` is the remaining cooldown right now, `cd_max` the full one.
##
## This exists because a tooltip that only says what an ability DOES is not
## enough to choose a loadout: the pilot is comparing costs and cadences.
func ability_stats(aid: String) -> Dictionary:
	var d := {"energy": energy_cost(aid)}
	match aid:
		"scan":
			d.merge({"channel": _scan_time, "range": _scan_range,
				"note": "Channelled — hold the lock until it completes."})
		"cloak":
			d.merge({"cd": _cloak_cd, "cd_max": _cloak_cd_max, "duration": _cloak_dur,
				"note": "Breaks on fire."})
		"bulwark":
			d.merge({"cd": _bulwark_cd, "cd_max": _bulwark_cd_max, "duration": _bulwark_dur,
				"radius": _bulwark_radius,
				"effect": "%d%% damage reduction, you and allies in radius" % int(_bulwark_reduction * 100.0)})
		"decoy_flare":
			d.merge({"cd": _decoy_cd, "cd_max": _decoy_cd_max, "duration": _decoy_dur,
				"effect": "Breaks every lock; the decoy pulls their fire."})
		"repair_field":
			d.merge({"cd": _repair_cd, "cd_max": _repair_cd_max, "duration": _repair_dur,
				"radius": _repair_radius,
				"effect": "%d hull+armor per second to everyone inside" % int(_repair_rate)})
		"repair_drone":
			d.merge({"cd": 0.0, "cd_max": _drone_cd_max, "duration": _drone_life,
				"range": _drone_range,
				"effect": "%d healing every %.0fs for %.0fs" % [int(_drone_heal), _drone_pulse, _drone_life]})
		"tangle_shot":
			d.merge({"cd": _tangle_cd, "cd_max": _tangle_cd_max, "duration": _tangle_dur,
				"range": _tangle_range, "effect": "Snares and slows a single target."})
		"warp_jump":
			d.merge({"cd": _warp_cd, "cd_max": _warp_cd_max, "range": _warp_dist,
				"effect": "Instant jump toward the cursor."})
		"blackout":
			d.merge({"cd": _blackout_cd, "cd_max": _blackout_cd_max, "duration": _blackout_dur,
				"effect": "Untargetable — drops you off every threat table."})
		"lance":
			d.merge({"cd": _lance_cd, "cd_max": _lance_cd_max, "range": _lance_range,
				"effect": "%d damage, tracks slightly" % int(_lance_damage)})
		"blight":
			d.merge({"cd": _blight_cd, "cd_max": _blight_cd_max, "duration": _blight_life,
				"range": _blight_range,
				"effect": "%d damage every %.0fs for %.0fs" % [int(_blight_damage), _blight_pulse, _blight_life]})
		"killshot":
			d.merge({"cd": _killshot_cd, "cd_max": _killshot_cd_max,
				"range": _killshot_max_range, "min_range": _killshot_min_range,
				"cone": _killshot_cone,
				"effect": "%d damage, cannot miss in cone; %d%% vs shields" % [
					int(_killshot_damage), int(_killshot_shield_factor * 100.0)]})
		"jinx":
			d.merge({"cd": _jinx_cd, "cd_max": _jinx_cd_max, "duration": _jinx_dur,
				"radius": _jinx_radius,
				"effect": "×%.1f evasion for allies in radius" % _jinx_mult})
		"overload":
			d.merge({"cd": _overload_cd, "cd_max": _overload_cd_max, "duration": _overload_dur,
				"range": _overload_range, "effect": "Overloads systems; drops shields."})
		"crystal":
			d.merge({"cd": _crystal_cd, "cd_max": _crystal_cd_max, "duration": _crystal_dur,
				"range": _crystal_place_range, "radius": _crystal_radius,
				"effect": "Destroys incoming ordnance inside the array."})
	return d


## Cost of a gemmed ability right now, for the HUD (so the gem bar can dim what
## the pilot cannot currently afford without knowing each ability's internals).
func energy_cost(aid: String) -> float:
	match aid:
		"scan": return 0.0
		"cloak": return _cloak_energy
		"bulwark": return _bulwark_energy
		"decoy_flare": return _decoy_energy
		"repair_field": return _repair_energy
		"repair_drone": return _drone_energy
		"tangle_shot": return _tangle_energy
		"warp_jump": return _warp_energy
		"blackout": return _blackout_energy
		"lance": return _lance_energy
		"blight": return _blight_energy
		"killshot": return _killshot_energy
		"jinx": return _jinx_energy
		"overload": return _overload_energy
		"crystal": return _crystal_energy
	return 0.0


## Crystalline Defense Array: the Miner DEFENSE signature, and the first ability
## to use the FREED MOUSE — it is placed AT THE CURSOR and stays there, so a
## Miner can screen an ALLY or cover a lane they aren't flying. The mouse still
## never aims a gun; the cursor says where a SYSTEM goes.
##
## Denies a damage TYPE (warheads) where Guardian's Bulwark soaks one. Gunfire
## passes through on purpose: a screen that stopped bullets as well would be a
## seven-second invulnerability bubble.
func _engage_crystal() -> void:
	if _crystal_cd > 0.0:
		_ability_fail("POINT-DEFENSE LATTICE REGROWING — %.0fs" % ceil(_crystal_cd))
		return

	# Clamp a far cursor to the placement limit rather than refusing the press —
	# the screen still deploys, just at arm's length, and the pilot SEES where.
	var want: Vector2 = get_global_mouse_position()
	var offset := want - global_position
	var clamped := offset.length() > _crystal_place_range
	if clamped:
		offset = offset.normalized() * _crystal_place_range

	if not _spend(_crystal_energy, "Array"):
		return
	_crystal_cd = _crystal_cd_max
	var screen: Node2D = preload("res://scenes/flight/crystal_screen.gd").new()
	screen.radius = _crystal_radius
	screen.life = _crystal_dur
	screen.shield_group = "player_team"   # cuts what is aimed at OUR side
	get_parent().add_child(screen)
	screen.global_position = global_position + offset
	# Name the FUNCTION at point of use — the ability is anti-ordnance point
	# defence, and with nothing firing missiles at you it otherwise reads as "did
	# nothing". This tells the pilot exactly what the screen is for.
	_flash_note(("POINT-DEFENSE SCREEN — shreds incoming missiles (max range)" if clamped \
		else "POINT-DEFENSE SCREEN — shreds incoming missiles"))
	Sfx.play("click", -4.0, 1.6)


## Overload Pulse: the Science CONTROL signature — an INSTANT EMP that collapses
## a target's shields for a few seconds, after which they blink back at exactly
## the strength they held. It takes nothing away; it opens a window, and what the
## wing does with it is the ability.
##
## Deliberately SINGLE-TARGET: it is the only module in the game aimed at an
## enemy, which is what keeps Science from being a second team-aura profession.
##
## Re-pulsing an already-suppressed hull is refused rather than re-seizing it —
## a second seize would store a shield of 0 and permanently delete the victim's
## shields on release.
func _engage_overload() -> void:
	if _overload_cd > 0.0:
		_ability_fail("OVERLOAD CHARGING — %.0fs" % ceil(_overload_cd))
		return
	if not is_instance_valid(target) or target is not BuildShip or target.dead:
		_ability_fail("OVERLOAD NEEDS A TARGET (RMB / T)")
		return
	if _is_ally(target):
		_ability_fail("OVERLOAD: that's one of ours")
		return
	if global_position.distance_to(target.global_position) > _overload_range:
		_ability_fail("OVERLOAD: target out of range (max %du)" % int(_overload_range))
		return
	for node in get_parent().get_children():
		if node is ShieldOverload and node.target == target:
			_ability_fail("OVERLOAD: that target's shields are already down")
			return

	if not _spend(_overload_energy, "Pulse"):
		return
	_overload_cd = _overload_cd_max
	var pulse: Node2D = preload("res://scenes/flight/shield_overload.gd").new()
	pulse.life = _overload_dur
	pulse.global_position = target.global_position
	get_parent().add_child(pulse)
	pulse.seize(target)
	Projectile.spark(get_parent(), target.global_position, Color(0.6, 0.88, 1.0), 10)
	_flash_note("SHIELDS DOWN — HIT IT NOW")
	Sfx.play("shield_hit", -3.0, 0.5)


## JINX Evasion Protocol: the Privateer DEFENSE signature, and the outlaw
## counterpart to Guardian's Bulwark. Bulwark SOAKS a spike; JINX makes it MISS —
## every ally in radius flies a smaller profile for a few seconds. Same job,
## opposite method, which is the whole point of the two tanks being different.
##
## The buff is max(base x2, floor) rather than a plain doubling: AI allies have
## evasion 0.0 (only the player's Evasion skill sets it), so doubling alone would
## do NOTHING for a wing — the exact case the ability exists to cover.
func _engage_jinx() -> void:
	if _jinx_t > 0.0:
		return   # already running
	if _jinx_cd > 0.0:
		_ability_fail("JINX RELOADING — %.0fs" % ceil(_jinx_cd))
		return
	if not _spend(_jinx_energy, "JINX"):
		return
	_jinx_cd = _jinx_cd_max
	_jinx_t = _jinx_dur

	var field: Node2D = preload("res://scenes/flight/jinx_field.gd").new()
	field.radius = _jinx_radius
	field.life = _jinx_dur
	field.mult = _jinx_mult
	field.floor_evasion = _jinx_floor
	field.cap = _jinx_cap
	get_parent().add_child(field)
	field.apply_to_allies(global_position, ["player_team", "friendly_targets"])
	_flash_note("JINX UP — FLY LOOSE")
	Sfx.play("click", -4.0, 1.4)


## Killshot: the Scout DAMAGE signature — a sniper that turns REACH into damage.
## It CANNOT MISS, so every constraint lives in the conditions to fire: the mark
## must sit inside the forward cone (aiming is still flying), far enough out that
## the rail can spin up, and inside the coilgun's own optics. Live shields blunt
## it, so the clean shot is on a stripped hull — which is exactly what a Science
## officer's shield EMP sets up.
##
## Every rejection names ITS OWN reason: "too close" and "out of arc" are
## different mistakes and the pilot has to know which one they made.
func _engage_killshot() -> void:
	if _killshot_cd > 0.0:
		_ability_fail("KILLSHOT COOLING — %.0fs" % ceil(_killshot_cd))
		return
	if not is_instance_valid(target) or target is not BuildShip or target.dead:
		_ability_fail("KILLSHOT NEEDS A MARK — select a target (RMB / T)")
		return
	if _is_ally(target):
		_ability_fail("KILLSHOT: that's one of ours")
		return

	var to_target: Vector2 = target.global_position - global_position
	var dist := to_target.length()
	if dist < _killshot_min_range:
		_ability_fail("KILLSHOT: TOO CLOSE — open the range past %du" % int(_killshot_min_range))
		return
	if dist > _killshot_max_range:
		_ability_fail("KILLSHOT: mark beyond reach (max %du)" % int(_killshot_max_range))
		return
	var off_axis := absf(rad_to_deg(Vector2.RIGHT.rotated(rotation).angle_to(to_target)))
	if off_axis > _killshot_cone * 0.5:
		_ability_fail("KILLSHOT: mark out of arc — put the nose on it")
		return

	if not _spend(_killshot_energy, "Killshot"):
		return
	_killshot_cd = _killshot_cd_max

	# Live shields blunt the rail: while any shield holds, the shot lands for a
	# fraction. Strip the shield first (or have it knocked offline) for the full
	# hit — that ordering IS the ability's skill expression.
	var dmg := _killshot_damage * Pilot.damage_mult()
	var blunted: bool = float(target.get("shield")) > 0.0
	if blunted:
		dmg *= _killshot_shield_factor

	var nose_dir := Vector2.RIGHT.rotated(rotation)
	var muzzle := global_position + nose_dir * 26.0
	var beam: Node2D = preload("res://scenes/flight/killshot_beam.gd").new()
	beam.from_point = muzzle
	beam.to_point = target.global_position
	get_parent().add_child(beam)
	Projectile.spark(get_parent(), target.global_position, Color(0.75, 0.92, 1.0), 8)

	# LOCAL FEEDBACK. Killshot's mark is 700-2400 units off — usually off-screen —
	# so the beam and the impact land where the player can't see them, and firing
	# read as "nothing happened but a sound". A muzzle flash + a hard recoil kick
	# at the SHIP make the shot visibly LEAVE, right where the player is looking.
	Projectile.spark(get_parent(), muzzle, Color(0.9, 0.97, 1.0), 14)
	velocity -= nose_dir * KILLSHOT_RECOIL   # the rail shoves you back

	target.take_damage(dmg, self)
	_flash_note("KILLSHOT — SHIELDS BLUNTED IT" if blunted else "KILLSHOT — CLEAN HIT")
	Sfx.play("shot", -1.0, 0.42)


## Withering Timbers: the Privateer DoT. Infects a HOSTILE hull with a nanobot
## blight that bites every few seconds for half a minute — patient damage that
## keeps working after you have broken away, which is why it pairs with Decoy
## Flare (drop the lock, let the blight finish the job).
##
## Re-casting on an already-infected target REFRESHES rather than stacking, so
## mashing the gem can never multiply the damage.
func _engage_blight() -> void:
	if _blight_cd > 0.0:
		_ability_fail("BLIGHT CULTURING — %.0fs" % ceil(_blight_cd))
		return
	if not is_instance_valid(target) or target is not BuildShip or target.dead:
		_ability_fail("BLIGHT NEEDS A TARGET (RMB / T)")
		return
	if _is_ally(target):
		_ability_fail("BLIGHT: pick a foe, not one of ours")
		return
	if global_position.distance_to(target.global_position) > _blight_range:
		_ability_fail("BLIGHT: target out of range (max %du)" % int(_blight_range))
		return

	if not _spend(_blight_energy, "Timbers"):
		return
	_blight_cd = _blight_cd_max
	for node in get_parent().get_children():
		if node is Blight and node.target == target:
			node.refresh()
			_flash_note("TIMBERS RENEWED")
			Sfx.play("click", -6.0, 0.8)
			return

	var blight: Node2D = preload("res://scenes/flight/blight.gd").new()
	blight.target = target
	blight.owner_ship = self
	blight.life = _blight_life
	blight.pulse = _blight_pulse
	blight.damage = _blight_damage
	blight.global_position = target.global_position
	get_parent().add_child(blight)
	_flash_note("TIMBERS SET — SHE'S ROTTING")
	Sfx.play("click", -4.0, 0.7)


## Hyper-Conductive Lance: the Guardian DAMAGE signature. A charged javelin of
## energy thrown down the nose that BENDS SLIGHTLY toward your mark — it is not a
## seeker, so a hard-jinking target still slips it; the tracking only forgives a
## near miss. Aiming is still flying (the mouse never aims), which is what keeps
## it a Guardian tool rather than a missile.
##
## Built on the existing homing projectile engine: a WeaponDef assembled from the
## module's `extra` and fired through Projectile.spawn, so it inherits bolt
## rendering, blast, grace and the damage_mult path for free.
func _engage_lance() -> void:
	if _lance_cd > 0.0:
		_ability_fail("LANCE CHARGING — %.0fs" % ceil(_lance_cd))
		return
	if not _spend(_lance_energy, "Lance"):
		return
	_lance_cd = _lance_cd_max

	var def := WeaponDef.new()
	def.damage = _lance_damage
	def.projectile_speed = _lance_speed
	def.weapon_range = _lance_range
	# Tracking scales to the MARK's size via the reusable per-band table (Projectile
	# resolves it each frame): a nimble fighter gets the most bend, a capital the
	# least. `homing` stays the base rate + the gate (non-ship marks fall back to it).
	def.homing = _lance_homing
	def.homing_by_band = PackedFloat32Array(LANCE_HOMING_BY_BAND)
	def.seek_nearest = false        # it bends toward YOUR mark, never picks one
	def.bolt_color = Color(0.62, 0.88, 1.0)
	def.bolt_scale = 2.4
	def.beam_tail = 26.0            # the javelin shape — a long drawn bolt

	# A skill shot, but a landable one: give it the same forgiving hit radius the
	# player's guns get (mount.shot_grace = 5) and a touch more, since the lance is a
	# fat javelin (bolt_scale 2.4) and reading a near-miss as a miss feels unfair.
	var nose := global_position + Vector2.RIGHT.rotated(rotation) * 26.0
	Projectile.spawn(get_parent(), nose, Vector2.RIGHT.rotated(rotation), def,
		enemy_group, 7.0, Pilot.damage_mult(), self)
	_flash_note("LANCE AWAY")
	Sfx.play("shot", -2.0, 0.55)


## Tender Drone: the Trader HEAL-OVER-TIME. Launched at your selected ALLY (no
## ally selected = patch yourself, never a wasted press), it then works on its
## own for half a minute while you fly. Contrast with Science's Repair Field:
## that one is a big channelled burst on everyone in a radius; this is a small
## trickle that follows one ship anywhere.
func _engage_drone() -> void:
	if _drone_cd > 0.0:
		_ability_fail("TENDER DRONE REBUILDING — %.0fs" % ceil(_drone_cd))
		return

	var patient: Node2D = self
	if is_instance_valid(target) and target is BuildShip and not target.dead:
		if _is_ally(target):
			if global_position.distance_to(target.global_position) > _drone_range:
				_ability_fail("TENDER DRONE: ally out of range (max %du)" % int(_drone_range))
				return
			patient = target
		else:
			_ability_fail("TENDER DRONE won't service a hostile — it patches self/allies")
			return

	if not _spend(_drone_energy, "Tender Drone"):
		return
	_drone_cd = _drone_cd_max
	var drone: Node2D = preload("res://scenes/flight/repair_drone.gd").new()
	drone.target = patient
	drone.life = _drone_life
	drone.pulse = _drone_pulse
	drone.heal = _drone_heal
	drone.global_position = patient.global_position
	get_parent().add_child(drone)
	_flash_note("TENDER DRONE AWAY — %s" % ("YOURSELF" if patient == self \
		else str(patient.get("ship_name") if patient.get("ship_name") else "ALLY")).to_upper())
	Sfx.play("click", -4.0, 1.2)


## Anything on our side of the fight — the drone services allies only.
func _is_ally(node: Node) -> bool:
	return node.is_in_group("player_team") or node.is_in_group("friendly_targets")


func _run_repair(delta: float) -> void:
	repair(_repair_rate * delta)
	for grp in ["player_team", "friendly_targets"]:
		for ally in get_tree().get_nodes_in_group(grp):
			if ally == self or not (ally is BuildShip) or ally.dead:
				continue
			if global_position.distance_to(ally.global_position) <= _repair_radius:
				ally.repair(_repair_rate * delta)


## Miner Tangle Shot: clamp a selected target's speed for a few seconds.
func _engage_tangle() -> void:
	if _tangle_cd > 0.0:
		_ability_fail("TANGLE COOLING — %.0fs" % ceil(_tangle_cd))
		return
	if target == null or not is_instance_valid(target) or target.get("dead") == true:
		_ability_fail("TANGLE SHOT needs a target (RMB / T)")
		return
	if global_position.distance_to(target.global_position) > _tangle_range:
		_ability_fail("TANGLE SHOT: target out of range")
		return
	if not _spend(_tangle_energy, "Tangle"):
		return
	_tangle_cd = _tangle_cd_max
	var tf: TangleField = preload("res://scenes/flight/tangle_field.gd").new()
	tf.target = target
	tf.life = _tangle_dur
	get_parent().add_child(tf)
	_flash_note("TANGLE SHOT — target snared")
	Sfx.play("click", -6.0, 1.1)


## Scout Micro-Warp: a short blink toward the selected target (or straight ahead
## with none), stopping short of the target.
func _engage_warp() -> void:
	if _warp_cd > 0.0:
		_ability_fail("MICRO-WARP COOLING — %.0fs" % ceil(_warp_cd))
		return
	var dir := Vector2.RIGHT.rotated(rotation)
	var dist := _warp_dist
	if target != null and is_instance_valid(target):
		var to_t: Vector2 = target.global_position - global_position
		if to_t.length() > 1.0:
			dir = to_t.normalized()
			dist = minf(_warp_dist, maxf(0.0, to_t.length() - 120.0))
	if not _spend(_warp_energy, "Micro-Warp"):
		return
	_warp_cd = _warp_cd_max
	var from := global_position
	global_position += dir * dist
	Projectile.spark(get_parent(), from, Color(0.6, 0.85, 1.0), 10)
	Projectile.spark(get_parent(), global_position, Color(0.7, 0.9, 1.0), 10)
	_flash_note("MICRO-WARP")
	Sfx.play("click", -4.0, 1.4)


## Trader Blackout: kill the transponder — untargetable (soft-hide) for a beat.
func _engage_blackout() -> void:
	if _blackout_t > 0.0:
		return
	if _blackout_cd > 0.0:
		_ability_fail("BLACKOUT COOLING — %.0fs" % ceil(_blackout_cd))
		return
	if not _spend(_blackout_energy, "Blackout"):
		return
	_blackout_cd = _blackout_cd_max
	_blackout_t = _blackout_dur
	set_veil(0.45)
	_flash_note("BLACKOUT — transponder dark")
	Sfx.play("click", -6.0, 0.8)


## Crimes make you WANTED for a while (attacking/robbing a civilian). Refreshes
## on each new offense; the heat cools if you lie low.
func mark_wanted(seconds: float) -> void:
	wanted_t = maxf(wanted_t, seconds)
	_refresh_wanted()


func is_wanted() -> bool:
	return wanted_t > 0.0 or Standing.is_hostile("guardian")


## An outlaw the law will actually SHOOT: while wanted (fresh crime) OR hostile
## with the Guardians, the player rides in "hostile_team" so guardians and station
## turrets engage — coming home turns dangerous. Clears when the heat cools and
## you're back above their hostile line.
func _refresh_wanted() -> void:
	var outlaw := is_wanted()
	if outlaw and not is_in_group("hostile_team"):
		add_to_group("hostile_team")
	elif not outlaw and is_in_group("hostile_team"):
		remove_from_group("hostile_team")


func _toggle_array(index: int, label: String) -> void:
	array_enabled[index] = not array_enabled[index]
	_flash_note("%s ARRAY %s" % [label, "ONLINE" if array_enabled[index] else "OFFLINE"])
	Sfx.play("click", -8.0, 1.5 if array_enabled[index] else 0.7)


func _target_valid() -> bool:
	return is_instance_valid(target) and target.is_inside_tree() \
		and target.get("dead") != true


func _physics_process(delta: float) -> void:
	if build == null or dead or docked_at != null:
		if _target_marker != null:
			_target_marker.visible = false
		return
	if cinematic:
		return   # the berthing sequence owns the helm this beat
	if dark:
		_tick_dark(delta)   # drift + meditation only; skip weapons/targeting/thrust
		return
	_reboot_t = maxf(0.0, _reboot_t - delta)
	tick_common(delta)
	_slide_cd = maxf(0.0, _slide_cd - delta)
	snared = maxf(0.0, snared - delta)
	_tick_scan(delta)
	if _cloak_t > 0.0:
		_cloak_t -= delta
		if _cloak_t <= 0.0:
			_drop_cloak("CLOAK FADED")
	elif _cloak_cd > 0.0:
		_cloak_cd = maxf(0.0, _cloak_cd - delta)
	_bulwark_cd = maxf(0.0, _bulwark_cd - delta)
	_tick_module_actives(delta)
	if wanted_t > 0.0:
		wanted_t = maxf(0.0, wanted_t - delta)
	_refresh_wanted()

	# HANDS OFF THE STICK WHILE TYPING. Controls are polled with
	# Input.is_action_pressed, which a focused text field does NOT suppress —
	# without this the letters of a chat message fly the ship. Physics still
	# runs (you keep your momentum and drift), you simply stop steering.
	if Chat.typing:
		_normal_physics_coasting(delta)
		return

	if Input.is_action_just_pressed("toggle_control_mode") and decoupler_fitted:
		mode = ControlMode.DISCONNECTED if mode == ControlMode.CONNECTED else ControlMode.CONNECTED

	if _slide_time > 0.0:
		_slide_physics(delta)
	else:
		_slide_fx.emitting = false
		_normal_physics(delta)

	# Array toggles reach the mounts as the offline flag (pips grey out).
	for mount in _mounts:
		mount.offline = not array_enabled[mount.group - 1]

	# Turrets serve the selected target first, then whatever is closest.
	# A FRIENDLY selection never steers guns — it exists for future systems
	# (repair nanites, scanners); weapons keep hunting hostiles past it.
	# Nose-locked guns ignore all of this and hold the line you're flying.
	if not _target_valid():
		target = null
	var aim_node := target if (target != null and target.is_in_group(enemy_group)) \
		else _nearest_hostile()
	if aim_node != null:
		update_mounts(aim_node.global_position, delta, _velocity_of(aim_node))
	else:
		update_mounts(global_position + Vector2.RIGHT.rotated(rotation) * 400.0, delta)
	if Input.is_action_pressed("fire"):
		if _cloak_t > 0.0:
			_drop_cloak("CLOAK BROKEN — WEAPONS HOT")
		fire_mounts()

	_target_marker.visible = target != null
	if target != null:
		_target_marker.global_position = target.global_position
		_target_marker.queue_redraw()
	_update_firing_solution()
	queue_redraw()   # aim tracer

	# Engine audio follows the plumes.
	var thrusting := false
	for plume in _plumes:
		if plume.emitting:
			thrusting = true
			break
	var target_db := -13.0 if thrusting else -60.0
	_thrust_audio.volume_db = lerpf(_thrust_audio.volume_db, target_db, 1.0 - exp(-8.0 * delta))
	_thrust_audio.pitch_scale = 1.25 if Input.is_action_pressed("boost") and thrusting else 1.0


## Traction broken: nose swings free, velocity keeps its heading, guns live.
## Steer through for the C-curve reversal; counter-steer for the S-cut.
func _slide_physics(delta: float) -> void:
	_slide_time -= delta
	if _slide_time <= 0.0:
		_slide_cd = SLIDE_COOLDOWN
	var turn := Input.get_axis("thrust_left", "thrust_right")
	rotation += turn * _turn_speed * SLIDE_TURN_MULT * delta
	velocity *= exp(-0.06 * delta)   # barely scrubs speed
	var pre := velocity
	move_and_slide()
	if get_slide_collision_count() > 0:
		bounce_off_obstacles(pre)
	_update_plumes(Vector2.ZERO, false)
	_slide_fx.emitting = true


## Flight with NO pilot input — used while the chat line has the keyboard. The
## hull keeps its momentum and drifts (a ship doesn't stop because you typed),
## it just receives no thrust, no steering and no trigger.
func _normal_physics_coasting(delta: float) -> void:
	apply_movement(Vector2.ZERO, delta, 1.0, false)


func _normal_physics(delta: float) -> void:
	var boosting := Input.is_action_pressed("boost")
	var thrust_accel := _accel * (boost_multiplier if boosting else 1.0)
	var thrust := Vector2.ZERO
	var braking := Input.is_action_pressed("brake")

	match mode:
		ControlMode.CONNECTED:
			var turn := Input.get_axis("thrust_left", "thrust_right")
			# Hyperslide trigger: fast + brake + hard steer, Connected only.
			if braking and absf(turn) > 0.5 and _slide_cd <= 0.0 \
					and velocity.length() >= _max_speed * SLIDE_SPEED_FRACTION:
				_slide_time = SLIDE_DURATION
				Sfx.play("slide", -9.0, 1.1)
				return
			rotation += turn * _turn_speed * delta
			var throttle := Input.get_axis("thrust_back", "thrust_forward")
			thrust = Vector2.RIGHT.rotated(rotation) * throttle * thrust_accel
		ControlMode.DISCONNECTED:
			var to_mouse := get_global_mouse_position() - global_position
			if to_mouse.length_squared() > 4.0:
				rotation = lerp_angle(rotation, to_mouse.angle(), 1.0 - exp(-12.0 * delta))
			var axis := Input.get_vector("thrust_left", "thrust_right", "thrust_forward", "thrust_back")
			thrust = axis * thrust_accel

	# Engines point backward: thrust off the nose axis is weaker. Full power
	# forward, ~70% lateral, ~40% reverse — escaping means turning away from
	# your guns, which is what makes maneuvering a real choice.
	if thrust.length_squared() > 1.0:
		var alignment := thrust.normalized().dot(Vector2.RIGHT.rotated(rotation))
		thrust *= lerpf(0.4, 1.0, (alignment + 1.0) * 0.5)

	# Umbral breath clinging to the hull: thrusters gutter.
	if snared > 0.0:
		thrust *= 0.6

	if braking and velocity.length_squared() > 1.0:
		var brake := velocity.normalized() * -brake_accel * delta
		velocity = Vector2.ZERO if brake.length_squared() >= velocity.length_squared() else velocity + brake

	apply_movement(thrust, delta, boost_multiplier if boosting else 1.0, boosting)


## The player ship lingers as a wreck so the camera and HUD survive; the
## flight scene handles the restart key. Cargo dies with the ship.
func _on_death() -> void:
	cargo.clear()
	commodities.clear()
	visible = false
	for mount in _mounts:
		mount.set_physics_process(false)


## Four rotating corner arcs bracketing the selected target, sized to it —
## plus the LEAD PIP: the point to fly the nose through so fixed guns connect.
func _draw_target_marker() -> void:
	if not _target_valid():
		return
	var hr = target.get("hit_radius")
	var r: float = (float(hr) if hr != null else 12.0) * 1.35 + 6.0
	var spin := Time.get_ticks_msec() * 0.0012
	var hostile := target.is_in_group(enemy_group)
	var color := Color(0.45, 0.9, 0.75)              # friendly teal
	if hostile:
		color = Color(0.95, 0.45, 0.3)               # hostile orange
	elif target is MineableAsteroid:
		color = Color(0.8, 0.8, 0.88)                # neutral rock grey
	if scanning():
		color = Color(0.5, 0.85, 1.0)                # scan channel cyan
	for i in 4:
		var a := spin + TAU * i / 4.0
		_target_marker.draw_arc(Vector2.ZERO, r, a, a + TAU * 0.14, 8, color, 1.6)

	# (The lead pip rides a ring around the SHIP, not the target — see _draw.)


## The gunsight math. Tolerance is the real angular width of the target's
## hull at pip distance — "solution" is literally "this shot intersects".
func _update_firing_solution() -> void:
	var had_solution := _solution
	_pip_active = false
	_solution = false
	var speed := 0.0
	var gun_range := INF
	for mount in _mounts:
		if mount.nose_locked:
			if speed <= 0.0:
				speed = mount.def.projectile_speed
			gun_range = minf(gun_range, mount.def.weapon_range)
	if speed <= 0.0 or not _target_valid() or not target.is_in_group(enemy_group):
		return
	var tv := _velocity_of(target)
	var pred := target.global_position
	for i in 2:
		var t := global_position.distance_to(pred) / speed
		pred = target.global_position + tv * t
	_pip_world = pred
	_pip_active = true
	var dist := global_position.distance_to(pred)
	_pip_in_range = dist <= gun_range
	var hr = target.get("hit_radius")
	# 1.25x hull width: green a touch early — the magnetism closes the gap.
	var tolerance := atan(((float(hr) if hr != null else 12.0) * 1.25) / maxf(dist, 1.0))
	var off_angle := absf(angle_difference(rotation, (pred - global_position).angle()))
	_solution = _pip_in_range and off_angle <= tolerance
	if _solution and not had_solution:
		Sfx.play("click", -16.0, 1.9)   # soft lock tick on acquisition
	# Feed the assist: nose guns bend near-solution shots onto the pip.
	for mount in _mounts:
		if mount.nose_locked:
			mount.assist_active = _pip_active
			mount.assist_point = _pip_world


## Aim tracer: the dotted line your fixed guns actually shoot down, out to
## their range. Faint while hunting; hard bright the moment the solution is
## good. Flying the pip is the game — this is the confirmation.
func _draw() -> void:
	if build == null or dead or docked_at != null:
		return
	var gun_range := 0.0
	for mount in _mounts:
		if mount.nose_locked:
			gun_range = maxf(gun_range, mount.def.weapon_range)
	if gun_range <= 0.0:
		return
	var color := Color(0.5, 1.0, 0.6, 0.9) if _solution else Color(1.0, 0.9, 0.6, 0.26)
	var d := 56.0
	while d < gun_range:
		draw_circle(Vector2(d, 0), 1.4 if _solution else 1.0, color)
		d += 48.0
	draw_arc(Vector2(gun_range, 0), 3.0, 0, TAU, 10, color, 1.2)   # range cap

	# Lead pip: a bearing indicator riding a fixed ring around the ship —
	# half-transparent, clearly HUD, always in view beside you (fighter-jet
	# style: the pip's DIRECTION is the information, not its distance).
	# Swing the nose onto it; when it lands on the tracer, you're on target.
	if not _pip_active:
		return
	var bearing := (_pip_world - global_position).angle() - rotation
	var pip := Vector2.RIGHT.rotated(bearing) * PIP_RING
	var pip_color := Color(0.5, 1.0, 0.6, 0.5) if _solution else Color(1.0, 0.85, 0.4, 0.5)
	if _pip_in_range:
		draw_circle(pip, 3.4, pip_color)
	else:
		draw_arc(pip, 3.4, 0, TAU, 12, pip_color, 1.5)   # hollow: out of gun range
	for i in 4:
		var tick := Vector2.RIGHT.rotated(TAU * i / 4.0)
		draw_line(pip + tick * 5.5, pip + tick * 10.0, pip_color, 1.5)


func _velocity_of(node: Node2D) -> Vector2:
	var v = node.get("velocity")
	return v if v is Vector2 else Vector2.ZERO


func _nearest_hostile() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for hostile in get_tree().get_nodes_in_group(enemy_group):
		if hostile.get("dead") == true or hostile == self:
			continue   # a WANTED player is in hostile_team — never auto-aim at yourself
		var d: float = global_position.distance_squared_to(hostile.global_position)
		if d < best_dist:
			best_dist = d
			best = hostile
	return best
