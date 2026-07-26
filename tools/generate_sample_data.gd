extends SceneTree
## Generates the MVP sample data as inspectable .tres resources under res://data/.
## Run headless:
##   godot --headless --path <project> --script res://tools/generate_sample_data.gd
## Idempotent: re-running overwrites. Hand-edits in the editor survive until then,
## so treat this as the seed generator, not the source of truth forever.

const HullDefS := preload("res://scripts/schema/hull_def.gd")
const HardpointDefS := preload("res://scripts/schema/hardpoint_def.gd")
const WeaponDefS := preload("res://scripts/schema/weapon_def.gd")
const EngineDefS := preload("res://scripts/schema/engine_def.gd")
const ReactorDefS := preload("res://scripts/schema/reactor_def.gd")
const DefenseDefS := preload("res://scripts/schema/defense_def.gd")
const SystemDefS := preload("res://scripts/schema/system_def.gd")
const GradesS := preload("res://scripts/schema/grades.gd")


func _init() -> void:
	_generate_components()
	_generate_hulls()
	print("Sample data generated under res://data/")
	quit()


func _save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("failed to save " + path)
	else:
		print("  ", path)


func _weapon(name: String, grade: int, mark: int, mass: float, draw: float,
		damage: float, interval: float, desc: String) -> Resource:
	var w := WeaponDefS.new()
	w.display_name = name
	w.grade = grade
	w.mark = mark
	w.mass = mass
	w.power_draw = draw
	w.damage = damage
	w.fire_interval = interval
	w.description = desc
	return w


func _generate_components() -> void:
	var G := GradesS.Grade

	# Range is a stat that matters: short-range guns hit harder for their cost,
	# long-range ones buy you standoff. Closing distance is a decision.
	var slug := _weapon("Junker Slugthrower", G.SALVAGE, 1, 6.0, 8.0, 6.0, 0.5,
		"Rebuilt mass-driver. Kicks like it resents you.")
	slug.weapon_range = 420.0
	slug.projectile_speed = 750.0
	slug.bolt_color = Color(1.0, 0.62, 0.3)   # hot slag orange, chunky
	slug.bolt_scale = 1.15
	_save(slug, "res://data/components/weapons/junker_slugthrower.tres")

	# Mining laser: a weapon by the rules, a tool by trade. Terrible in a
	# fight, peerless against rock.
	var cutter := _weapon("Ferro Cutter Beam", G.STANDARD, 1, 5.0, 10.0, 3.0, 0.12,
		"Industrial cutting beam. Asteroids yield; hulls mostly scoff.")
	cutter.weapon_range = 260.0
	cutter.projectile_speed = 900.0
	cutter.mining_power = 2.0
	cutter.beam = true                          # a LASER: continuous ray
	cutter.bolt_color = Color(0.4, 1.0, 0.55)   # industrial green
	cutter.bolt_scale = 0.8
	_save(cutter, "res://data/components/weapons/ferro_cutter_beam.tres")

	# First ORDNANCE weapon: unguided, slow, brutal, and it runs out. The
	# magazine is the economy sink; the fat warhead is the aim forgiveness.
	var rockets := _weapon("Bombard Rocket Pod", G.STANDARD, 1, 7.0, 3.0, 34.0, 0.9,
		"Twelve dumb rockets and a rail. Aim is your problem; the warhead forgives.")
	rockets.weapon_range = 520.0
	rockets.projectile_speed = 500.0
	rockets.magazine = 12
	rockets.ammo_price = 4
	rockets.hit_bonus = 6.0
	rockets.blast_radius = 48.0   # ship-sized burst: near enough IS a hit
	rockets.bolt_color = Color(1.0, 0.55, 0.35)
	rockets.bolt_scale = 1.6
	_save(rockets, "res://data/components/weapons/bombard_rocket_pod.tres")

	# HOMING ORDNANCE (the Dowager's escape tools): missiles that TRACK, hit hard,
	# and run dry fast — a way out of a scrap, never a weapon for a long hunt.
	# HEAT = fire-and-forget, re-seeks the nearest target every frame.
	# A blast weapon ALWAYS proximity-detonates near the rim, so its bite is
	# damage * blast_falloff-at-0.7-radius. With blast_falloff 0.7 that's ~0.79, so
	# 150 lands ~118 — one-shots a wasp (55) / raider (80) / cutlass (90), while a
	# 120-hull brawler and up survive. A five-round pod should make a fighter regret
	# the intercept. (Default 0.45 falloff had it landing only ~55 — "barely tickled".)
	var heat := _weapon("Heat-Seeker Missile Pod", G.ADVANCED, 2, 7.0, 4.0, 150.0, 1.1,
		"Fire and forget — the warhead chases the hottest engine in the sky. Five rounds that hit like a grudge; enough to break a fight you didn't start, never enough for a long hunt.")
	heat.weapon_range = 1860.0   # 3x reach (user, 2026-07-23) — it was hopeless up close only
	heat.projectile_speed = 682.0   # +10%
	heat.magazine = 5
	heat.ammo_price = 12
	heat.hit_bonus = 6.0
	heat.blast_radius = 26.0
	heat.blast_falloff = 0.7   # reliable even on a near miss (default 0.45 was too soft)
	heat.homing = 100.0   # on-switch + fallback rate vs a size-less mark (a station)
	# Turn rate in DEGREES PER 10 UNITS travelled (WeaponDef.homing_by_band), by
	# target size band. Guided ordnance deliberately does NOT get the guns' lead-aim
	# (that's gunnery — a trained skill; guided weapons are the no-training path:
	# "guns for gunners, guided for those who don't"). So it PURE-PURSUES, which
	# tail-chases, and we pay for that with a beefier turn rate instead — biased to
	# SMALL, since a heat-seeker's job is chasing fighters, not cruisers. (Flat 1.6
	# was the behaviour-preserving conversion; this is the tuned-up feel.)
	heat.homing_by_band = PackedFloat32Array([4.0, 3.2, 2.4, 1.8, 1.4])
	heat.seek_nearest = true
	heat.bolt_color = Color(1.0, 0.5, 0.28)
	heat.bolt_scale = 1.5
	_save(heat, "res://data/components/weapons/heatseeker_missile_pod.tres")

	# RADIO = command-guided: locks the shooter's SELECTED target and commits to
	# it. Hits harder, tracks tighter, but goes dumb if the mark slips the leash.
	var radio := _weapon("Radio-Guided Missile Rack", G.ADVANCED, 2, 8.0, 6.0, 150.0, 1.3,
		"Command-guided to whatever you've got locked — pick a target, and four heavy warheads WILL find it. The reload's dear and it goes dumb if your mark slips the leash. Use them to leave, not to hunt.")
	radio.weapon_range = 780.0
	radio.projectile_speed = 1200.0   # fast striker: short range (780) needs to CLOSE
	# quick or the mark leaves the window. Per-10u homing keeps the turn radius, so
	# faster = harder to dodge, not wider.
	radio.magazine = 4
	radio.ammo_price = 16
	radio.hit_bonus = 5.0
	radio.blast_radius = 20.0
	radio.blast_falloff = 0.7
	radio.homing = 150.0   # on-switch + fallback rate vs a size-less mark (a station)
	# Beefed turn rate to compensate for pure-pursuit (no gunnery lead), like the
	# heat-seeker — but FLAT across sizes, not small-biased: the RGM commits to
	# whatever YOU lock, fighter or cruiser, so it plays no size favourites. 3.0 was
	# 2.2 (the behaviour-preserving conversion).
	radio.homing_by_band = PackedFloat32Array([3.0, 3.0, 3.0, 3.0, 3.0])
	radio.seek_nearest = false
	radio.bolt_color = Color(0.5, 0.8, 1.0)
	radio.bolt_scale = 1.6
	_save(radio, "res://data/components/weapons/radio_missile_rack.tres")

	var vk2 := _weapon("VK-2 Autocannon", G.STANDARD, 1, 5.0, 10.0, 5.0, 0.25,
		"Factory-spec rotary cannon. The sound of the baseline.")
	vk2.weapon_range = 550.0
	vk2.bolt_color = Color(1.0, 0.9, 0.55)   # classic tracer yellow
	vk2.bolt_scale = 0.85
	_save(vk2, "res://data/components/weapons/vk2_autocannon.tres")

	var twinlance := _weapon("Twinlance Pulse Laser", G.ADVANCED, 2, 8.0, 22.0, 9.0, 0.3,
		"Paired emitters tuned a half-phase apart.")
	twinlance.weapon_range = 620.0
	twinlance.projectile_speed = 2200.0            # light-fast pulse front
	twinlance.bolt_color = Color(0.55, 0.8, 1.0)   # cyan
	twinlance.bolt_scale = 1.1
	twinlance.beam_tail = 170.0                    # the lance behind the light
	_save(twinlance, "res://data/components/weapons/twinlance_pulse.tres")

	# Station-grade defense weapons. Mark IV won't fit any Light hull — these
	# exist so stations visibly outgun ships. Traverse rule does the balance:
	# the battery mauls heavies but can't track a raider; the PD array can.
	var battery := _weapon("Bastion Heavy Battery", G.STANDARD, 4, 42.0, 48.0, 60.0, 1.4,
		"Fortress artillery. If it catches you square, you were already too slow.")
	battery.projectile_speed = 720.0
	battery.weapon_range = 700.0
	battery.bolt_color = Color(1.0, 0.45, 0.3)   # fortress shellfire
	battery.bolt_scale = 1.9
	_save(battery, "res://data/components/weapons/bastion_heavy_battery.tres")

	var pd := _weapon("Skeet PD Array", G.STANDARD, 1, 6.0, 18.0, 2.0, 0.08,
		"A hail of small answers to small problems.")
	pd.projectile_speed = 1100.0
	pd.weapon_range = 380.0
	pd.traverse = 540.0   # authored: a PD array's whole point is out-tracking its mark
	pd.bolt_color = Color(0.7, 0.9, 1.0)   # ice-white sparks
	pd.bolt_scale = 0.55
	_save(pd, "res://data/components/weapons/skeet_pd_array.tres")

	# ---- GALEAN NAVY ARMAMENT (user, 2026-07-24) ----
	# The fleet's own guns — "good tech for the navy, not the newbie garbage". A
	# proper tier above fringe salvage: ADVANCED (blue) standard issue, with one
	# EXPERIMENTAL (purple) piece the fleet only mounts on elite variants. Marks are
	# capital (3-4). The Mk4 lances keep the DERIVED traverse (90 deg/s): murder on
	# a cruiser, helpless against a fighter, which is why PD mounts and escorts
	# exist at all. The Palisade flak is the deliberate exception — see its note.
	# Pale-gold/ivory livery matches Orivel and the Confederacy.

	# AEGIS LANCE BATTERY — Mk4 LASER, the main + spinal armament. Beam (hit-scan),
	# so every tick lands; long reach; slow-tracking (90 deg/s) so it can't chase a gnat.
	var aegis := _weapon("Aegis Lance Battery", G.ADVANCED, 4, 12.0, 7.0, 8.0, 0.10,
		"Galean naval laser: a sustained ivory lance, instant on target. Line-standard, and it shows — steady, long-reaching, merciless to anything that lingers in the open.")
	aegis.beam = true
	aegis.beam_tail = 40.0
	aegis.projectile_speed = 2600.0
	aegis.weapon_range = 1000.0
	aegis.bolt_color = Color(1.0, 0.92, 0.66)   # pale gold / ivory
	aegis.bolt_scale = 1.4
	_save(aegis, "res://data/components/weapons/aegis_lance_battery.tres")

	# GALEAN NAVAL AUTOCANNON — Mk3 kinetic, the secondary. Fills the gaps the slow
	# lances can't sweep; navy-standard, a clear cut above the fringe VK-2.
	var navgun := _weapon("Galean Naval Autocannon", G.ADVANCED, 3, 10.0, 5.0, 34.0, 0.22,
		"Confederacy secondary armament: a fast-cycling autocannon that answers what the main lances are too slow to catch.")
	navgun.projectile_speed = 1500.0
	navgun.weapon_range = 820.0
	navgun.bolt_color = Color(1.0, 0.85, 0.4)   # gold tracer
	navgun.bolt_scale = 1.1
	_save(navgun, "res://data/components/weapons/naval_autocannon.tres")

	# SENTINEL RADAR BATTERY — Mk4 EXPERIMENTAL (purple), the elite-variant piece.
	# Up-tier of the Radio Missile: command-guided heavy warheads ride the ship's
	# radar to its locked target. Reach + blast the lances lack. Ordnance (magazine).
	var sentinel := _weapon("Sentinel Radar Battery", G.EXPERIMENTAL, 4, 14.0, 8.0, 95.0, 1.2,
		"Command-guided capital ordnance: heavy warheads ride the ship's targeting radar to whatever it has locked. Reaches where the lances can't — and the fleet doesn't hand these out.")
	sentinel.projectile_speed = 900.0
	sentinel.weapon_range = 1300.0
	sentinel.blast_radius = 34.0
	sentinel.blast_falloff = 0.7
	sentinel.homing = 120.0
	sentinel.seek_nearest = false
	sentinel.homing_by_band = PackedFloat32Array([2.6, 2.6, 2.4, 2.2, 2.0])
	sentinel.magazine = 6
	sentinel.ammo_price = 40
	sentinel.bolt_color = Color(0.6, 0.85, 1.0)   # radar blue
	sentinel.bolt_scale = 1.7
	_save(sentinel, "res://data/components/weapons/sentinel_radar_battery.tres")

	# PALISADE FLAK BATTERY — Mk4 ANTI-FIGHTER (user, 2026-07-25). The weapon the
	# old derived-traverse rule made impossible: a BIG gun built to shred small
	# fast things. It slews at 420 deg/s where its Mk4 neighbours crawl at 90, and
	# it pays for that in reach — 340 units against the Aegis Lance's 1000. A
	# fighter inside the wall dies; a cruiser outside it is untouched, because the
	# flak simply cannot get there.
	#
	# Proximity-fuzed on purpose: flak has never been about hitting, it is about
	# filling the sky with bursts. The small blast is what makes it murder on
	# something jinking, and the low per-shot damage is what stops it being an
	# all-purpose main gun.
	var flak := _weapon("Palisade Flak Battery", G.ADVANCED, 4, 13.0, 9.0, 12.0, 0.16,
		"Galean anti-fighter mount: a fence of proximity-fuzed bursts thrown up around the hull. It cannot reach a ship of the line and was never meant to — it is here for the ones that get close enough to matter.")
	flak.traverse = 420.0        # authored: big, and fast — the whole point
	flak.projectile_speed = 1400.0
	flak.weapon_range = 340.0    # the price of the tracking
	flak.blast_radius = 28.0
	flak.blast_falloff = 0.5
	flak.bolt_color = Color(1.0, 0.78, 0.45)   # burst-gold
	flak.bolt_scale = 0.9
	_save(flak, "res://data/components/weapons/palisade_flak_battery.tres")

	# DROVER DEFENSE TURRET — the civilian freight turret, and the reason an armed
	# hauler is annoying rather than safe. Mk2 so it physically fits a real ring,
	# with an AUTHORED, honestly mediocre 240 deg/s: it CAN follow a fighter that
	# jinks, it just can't make it regret much. Freight lines buy these by the
	# pallet; nobody has ever been proud of one.
	var drover := _weapon("Drover Defense Turret", G.STANDARD, 2, 9.0, 12.0, 7.0, 0.35,
		"Standard freight-line defensive mount. Slow, plain, and bolted to every hauler on the lane — enough to make a raider work for it, never enough to make one leave.")
	drover.traverse = 240.0
	drover.projectile_speed = 1000.0
	drover.weapon_range = 480.0
	drover.bolt_color = Color(0.95, 0.85, 0.6)
	drover.bolt_scale = 0.9
	_save(drover, "res://data/components/weapons/drover_defense_turret.tres")

	var e := EngineDefS.new()
	e.display_name = "Drifter Ion Drive"
	e.grade = G.SALVAGE
	e.mark = 1; e.mass = 8.0; e.power_draw = 10.0; e.thrust = 500.0
	e.description = "Slow to spool, cheap to feed."
	_save(e, "res://data/components/engines/drifter_ion.tres")

	e = EngineDefS.new()
	e.display_name = "Vectorjet Thruster"
	e.grade = G.STANDARD
	e.mark = 1; e.mass = 9.0; e.power_draw = 14.0; e.thrust = 800.0
	e.description = "Reliable gimbal-nozzle workhorse."
	_save(e, "res://data/components/engines/vectorjet.tres")

	e = EngineDefS.new()
	e.display_name = "Afterjet Sprint Drive"
	e.grade = G.ADVANCED
	e.mark = 2; e.mass = 14.0; e.power_draw = 26.0; e.thrust = 1200.0
	e.trail_scale = 1.5
	e.description = "Burns hot and loud. Freighter captains' favorite lie: 'just for emergencies.'"
	_save(e, "res://data/components/engines/afterjet_sprint.tres")

	var r := ReactorDefS.new()
	r.display_name = "Scrap-Cell Pile"
	r.grade = G.SALVAGE
	r.mark = 1; r.mass = 10.0; r.power_output = 40.0
	r.energy_capacity = 80.0; r.energy_recharge = 1.0
	r.trail_color = Color(0.75, 0.62, 0.35)
	r.description = "Salvaged cells wired in defiance of several manuals."
	_save(r, "res://data/components/reactors/scrap_cell_pile.tres")

	r = ReactorDefS.new()
	r.display_name = "Hearth Fusion Core"
	r.grade = G.STANDARD
	r.mark = 1; r.mass = 12.0; r.power_output = 70.0
	r.energy_capacity = 140.0; r.energy_recharge = 1.5
	r.trail_color = Color(0.55, 0.75, 1.0)
	r.description = "The steady blue everyone learned to fly by."
	_save(r, "res://data/components/reactors/hearth_fusion.tres")

	r = ReactorDefS.new()
	r.display_name = "Overcharged Cell"
	r.grade = G.EXPERIMENTAL
	r.mark = 2; r.mass = 16.0; r.power_output = 120.0
	r.energy_capacity = 240.0; r.energy_recharge = 2.5
	r.trail_color = Color(0.80, 0.45, 0.95)
	r.description = "Runs 40% past rated containment. The paperwork says don't."
	_save(r, "res://data/components/reactors/overdrive_bottle.tres")

	# KEELSTONE FUSION PLANT — the first Mk3 CAPITAL reactor (2026-07-25). It was
	# missing: the Supercruiser hull has a Mk3 "Capital Reactor" housing and the
	# heaviest plant in the game was a Mk2, so the fleet flagship was fitted with
	# an Overcharged Cell it could not actually feed — 134 load against 120
	# capacity, an illegal build that only ever flew because NPC fits skip the
	# refit screen's validation. tools/test_hulls.gd now catches that class.
	# Sized to run a capital's batteries AND its drives with headroom to spare,
	# because a ship of the line brings its own power station.
	r = ReactorDefS.new()
	r.display_name = "Keelstone Fusion Plant"
	r.grade = G.ADVANCED
	r.mark = 3; r.mass = 34.0; r.power_output = 260.0
	r.energy_capacity = 420.0; r.energy_recharge = 3.2
	r.trail_color = Color(0.62, 0.82, 1.0)
	r.description = "Capital-grade fusion, built around the keel rather than bolted to it. Freight lines and navies buy the same plant for the same reason: nothing aboard should ever have to wait its turn for power."
	_save(r, "res://data/components/reactors/keelstone_fusion.tres")

	var d := DefenseDefS.new()
	d.display_name = "Patchplate Armor"
	d.grade = G.FLOTSAM
	d.kind = DefenseDefS.Kind.ARMOR
	d.mark = 1; d.mass = 12.0; d.armor_hp = 40.0
	d.description = "Overlapping wreck-plates. Rattles at speed — that's the drawback affix talking."
	_save(d, "res://data/components/defense/patchplate_armor.tres")

	d = DefenseDefS.new()
	d.display_name = "Bulwark Plating"
	d.grade = G.STANDARD
	d.kind = DefenseDefS.Kind.ARMOR
	d.mark = 1; d.mass = 16.0; d.armor_hp = 80.0
	d.description = "Milled, matched, and bolted right."
	_save(d, "res://data/components/defense/bulwark_plating.tres")

	d = DefenseDefS.new()
	d.display_name = "Veil Shield Projector"
	d.grade = G.STANDARD
	d.kind = DefenseDefS.Kind.SHIELD
	d.mark = 1; d.mass = 6.0; d.power_draw = 16.0
	d.shield_hp = 60.0; d.shield_regen = 4.0
	d.description = "A soap-bubble against the dark. Regenerates; armor doesn't."
	_save(d, "res://data/components/defense/veil_shield.tres")

	d = DefenseDefS.new()
	d.display_name = "Aegis Composite Lattice"
	d.grade = G.EXPERIMENTAL
	d.kind = DefenseDefS.Kind.COMPOSITE
	d.mark = 2; d.mass = 12.0; d.power_draw = 14.0
	d.shield_hp = 50.0; d.shield_regen = 3.0; d.armor_hp = 50.0
	d.description = "Plate with a woven field. Best of both, master of neither."
	_save(d, "res://data/components/defense/aegis_composite.tres")

	var s := SystemDefS.new()
	s.display_name = "Wayfarer Sensor Suite"
	s.grade = G.STANDARD
	s.mark = 1; s.mass = 3.0; s.power_draw = 6.0; s.sensor_range = 1500.0
	s.tags = PackedStringArray(["sensor"])
	s.description = "Sees farther than you can run."
	_save(s, "res://data/components/systems/wayfarer_sensors.tres")

	s = SystemDefS.new()
	s.display_name = "Strapdown Cargo Pod"
	s.grade = G.SALVAGE
	s.mark = 1; s.mass = 4.0; s.cargo_capacity = 20.0
	s.tags = PackedStringArray(["cargo"])
	s.description = "Space for loot. Draws nothing but patience."
	_save(s, "res://data/components/systems/strapdown_cargo_pod.tres")

	# A mid-tier hold — twice the strapdown's space, sits between a starter and a
	# freighter. The Dowager's upgraded smuggler deck.
	s = SystemDefS.new()
	s.display_name = "False-Bottom Hold"
	s.grade = G.STANDARD
	s.mark = 1; s.mass = 7.0; s.cargo_capacity = 40.0
	s.tags = PackedStringArray(["cargo"])
	s.description = "A smuggler's hold with room the manifest never mentions — twice the strapdown pod's space, and just as quiet. Sits between a starter's pockets and a freighter's belly."
	_save(s, "res://data/components/systems/falsebottom_hold.tres")

	s = SystemDefS.new()
	s.display_name = "Prospector Survey Scanner"
	s.grade = G.STANDARD
	s.mark = 1; s.mass = 3.0; s.power_draw = 4.0
	s.tags = PackedStringArray(["scanner"])
	s.extra = {"scan_range": 380.0, "scan_time": 3.2}
	s.description = "Target something and press [1]: rocks reveal their ore, ships and stranger things yield Scan Data the station lab pays for."

	# THE PROFESSION SIGNATURE MODULES ARE GONE — they are CHIPS now, and the
	# chips are hand-authored under data/components/chips/ (bulwark_projector,
	# umbral_cloak_field, ...), which is what the quartermasters actually stock
	# (Professions.wares) and what the ability book reads.
	#
	# This generator used to ALSO write module copies to data/components/systems/,
	# the same vestigial shape the Prospector Survey Scanner was deleted for. They
	# were unobtainable by construction: profession-locked, so the open Armory
	# refuses them, while no quartermaster sells that path. Re-seeding the data
	# resurrected two dead files and turned test_abilities red — which is exactly
	# how it should behave. Do not re-add them here; edit the chips.

	# The Vector Decoupling Computer was removed 2026-07-19 (user decision).
	# Disconnected flight stays in the engine, gated on the "flight_decoupler"
	# tag — it returns later on EXOTIC-grade thrusters and/or an exotic hull.


## Saves a hull, appending the UNIVERSAL COUPLING first if it hasn't authored
## its own. Every hull carries one — it's the rack the ability chips ride in.
##
## THIS EXISTS BECAUSE REGENERATING USED TO DESTROY IT. The coupling hardpoint
## lived only in the .tres files as a hand-edit, so re-seeding the data silently
## stripped the chip rack off every hull in the game and no test noticed. It is
## APPENDED LAST (never authored mid-list) so existing hardpoint indices stay
## stable — the same reason SlotType.COUPLING is last in its enum.
func _save_hull(h: Resource, path: String) -> void:
	var has_coupling := false
	for hp in h.hardpoints:
		if hp.slot_type == HardpointDefS.SlotType.COUPLING:
			has_coupling = true
			break
	if not has_coupling:
		var hps: Array = Array(h.hardpoints)
		hps.append(_hardpoint("Universal Coupling", Vector2(-2, 0),
			HardpointDefS.SlotType.COUPLING, 5))
		h.hardpoints.assign(hps)
	# A hull whose silhouette or hardpoints overflow its size band's art canvas
	# can't be drawn correctly. Fail loudly at seed time, not in the shipyard.
	if not h.fits_art_budget():
		push_error("%s overflows the %s art canvas" % [h.display_name, h.size_band])
	_save(h, path)


func _hardpoint(name: String, offset: Vector2, type: int, mark: int,
		arc := 30.0, facing := 0.0) -> Resource:
	var hp := HardpointDefS.new()
	hp.display_name = name
	hp.offset = offset
	hp.slot_type = type
	hp.mark = mark
	hp.arc_deg = arc
	hp.facing_deg = facing
	return hp


func _generate_hulls() -> void:
	var T := HardpointDefS.SlotType

	var fighter := HullDefS.new()
	fighter.display_name = "Sparrowhawk"
	fighter.grade = GradesS.Grade.SALVAGE   # everything so far is second-hand
	fighter.category = "Fighter"
	fighter.level = 3   # Sparrowhawk
	fighter.size_band = HullDefS.SizeBand.LIGHT
	fighter.mass = 40.0
	fighter.hull_hp = 120.0
	fighter.cargo_base = 12.0
	fighter.price = 3500
	fighter.trait_id = "knife_fighter"
	fighter.trait_description = "Knife-fighter: weapon gimbal arcs are 50% wider on this hull."
	# Light band: 16px art canvas = 32 world units max extent.
	fighter.silhouette = PackedVector2Array([
		Vector2(18, 0), Vector2(3, -6), Vector2(-8, -10), Vector2(-14, -4),
		Vector2(-14, 4), Vector2(-8, 10), Vector2(3, 6)])
	var fighter_hps: Array = [
		_hardpoint("Port Nose Gun", Vector2(10, -5), T.WEAPON, 2, 30.0),
		_hardpoint("Starboard Nose Gun", Vector2(10, 5), T.WEAPON, 2, 30.0),
		_hardpoint("Dorsal Flex Mount", Vector2(-2, 0), T.WEAPON, 1, 180.0),
		_hardpoint("Main Drive", Vector2(-12, 0), T.ENGINE, 2),
		_hardpoint("Reactor Cradle", Vector2(-4, 0), T.REACTOR, 1),
		_hardpoint("Defense Bay", Vector2(2, 0), T.DEFENSE, 1),
	]
	fighter.hardpoints.assign(fighter_hps)
	_save_hull(fighter, "res://data/hulls/sparrowhawk.tres")

	var scout := HullDefS.new()
	scout.display_name = "Kestrel"
	scout.grade = GradesS.Grade.SALVAGE   # everything so far is second-hand
	scout.category = "Scout"
	scout.level = 2   # Kestrel
	scout.size_band = HullDefS.SizeBand.LIGHT
	scout.mass = 32.0
	scout.hull_hp = 80.0
	scout.cargo_base = 8.0
	scout.price = 3000
	scout.trait_id = "long_sight"
	scout.trait_description = "Long Sight: sensor ranges +25%; contacts are identified one grade sooner."
	scout.silhouette = PackedVector2Array([
		Vector2(19, 0), Vector2(2, -4), Vector2(-13, -6),
		Vector2(-10, 0), Vector2(-13, 6), Vector2(2, 4)])
	var scout_hps: Array = [
		_hardpoint("Chin Gun", Vector2(11, 0), T.WEAPON, 1, 90.0),
		_hardpoint("Port Drive", Vector2(-11, -4), T.ENGINE, 1),
		_hardpoint("Starboard Drive", Vector2(-11, 4), T.ENGINE, 1),
		_hardpoint("Reactor Cradle", Vector2(-5, 0), T.REACTOR, 1),
		_hardpoint("Sensor Spine", Vector2(5, 0), T.SYSTEM, 2),
		_hardpoint("Utility Bay A", Vector2(0, -3), T.SYSTEM, 1),
		_hardpoint("Utility Bay B", Vector2(0, 3), T.SYSTEM, 1),
	]
	scout.hardpoints.assign(scout_hps)
	_save_hull(scout, "res://data/hulls/kestrel.tres")

	var freighter := HullDefS.new()
	freighter.display_name = "Mule"
	freighter.grade = GradesS.Grade.SALVAGE   # everything so far is second-hand
	freighter.category = "Freighter"
	freighter.level = 2   # Mule: rim hauler
	freighter.size_band = HullDefS.SizeBand.LIGHT
	freighter.mass = 70.0
	freighter.hull_hp = 150.0
	freighter.cargo_base = 60.0
	freighter.price = 3000
	freighter.trait_id = "packrat"
	freighter.trait_description = "Packrat: cargo components 25% lighter; jettisoned cargo can be re-scooped."
	freighter.silhouette = PackedVector2Array([
		Vector2(14, 0), Vector2(9, -9), Vector2(-14, -10), Vector2(-18, -4),
		Vector2(-18, 4), Vector2(-14, 10), Vector2(9, 9)])
	var freighter_hps: Array = [
		_hardpoint("Topside Turret Ring", Vector2(0, 0), T.WEAPON, 1, 360.0),
		_hardpoint("Main Drive", Vector2(-16, 0), T.ENGINE, 2),
		_hardpoint("Reactor Cradle", Vector2(-7, 0), T.REACTOR, 2),
		_hardpoint("Defense Bay Fore", Vector2(7, 0), T.DEFENSE, 1),
		_hardpoint("Defense Bay Aft", Vector2(-11, 0), T.DEFENSE, 1),
		_hardpoint("Utility Bay", Vector2(4, 5), T.SYSTEM, 1),
	]
	freighter.hardpoints.assign(freighter_hps)
	_save_hull(freighter, "res://data/hulls/mule.tres")

	# The starter: sits at the intersection of fighter/scout/freighter.
	# Not as good as any of them — more versatile than all of them.
	var starter := HullDefS.new()
	starter.display_name = "Rooster"
	starter.grade = GradesS.Grade.FLOTSAM   # junk-tier: held together by habit
	starter.category = "Multirole"
	starter.level = 1   # the starter, by definition
	starter.size_band = HullDefS.SizeBand.LIGHT
	starter.mass = 45.0
	starter.hull_hp = 110.0
	starter.cargo_base = 24.0
	starter.price = 1800
	starter.trait_id = "jack_of_all"
	starter.trait_description = "Jack of All Trades: no bonuses, no penalties, no excuses."
	starter.silhouette = PackedVector2Array([
		Vector2(16, 0), Vector2(6, -8), Vector2(-8, -11), Vector2(-15, -5),
		Vector2(-15, 5), Vector2(-8, 11), Vector2(6, 8)])
	var starter_hps: Array = [
		_hardpoint("Port Gun", Vector2(10, -4), T.WEAPON, 1, 45.0),
		_hardpoint("Starboard Gun", Vector2(10, 4), T.WEAPON, 1, 45.0),
		_hardpoint("Main Drive", Vector2(-14, 0), T.ENGINE, 1),
		_hardpoint("Reactor Cradle", Vector2(-6, 0), T.REACTOR, 1),
		_hardpoint("Defense Bay", Vector2(0, 0), T.DEFENSE, 1),
		_hardpoint("Sensor Mount", Vector2(6, -6), T.SYSTEM, 1),
		_hardpoint("Utility Bay", Vector2(2, 7), T.SYSTEM, 1),
	]
	starter.hardpoints.assign(starter_hps)
	_save_hull(starter, "res://data/hulls/rooster.tres")

	# The Cutlass: first true Interceptor — a crescent blade that closes on
	# its prey. User-generated art; the claw is the nose.
	var interceptor := HullDefS.new()
	interceptor.display_name = "Cutlass"
	interceptor.grade = GradesS.Grade.SALVAGE   # everything so far is second-hand
	interceptor.category = "Interceptor"
	interceptor.level = 3   # Cutlass
	interceptor.size_band = HullDefS.SizeBand.LIGHT
	interceptor.mass = 34.0
	interceptor.hull_hp = 90.0
	interceptor.cargo_base = 6.0
	interceptor.price = 3800
	interceptor.trait_id = "closing_talon"
	interceptor.trait_description = "Closing Talon: born to chase, built to catch."
	interceptor.silhouette = PackedVector2Array([
		Vector2(14, -13), Vector2(4, -15), Vector2(-8, -11), Vector2(-13, 0),
		Vector2(-8, 11), Vector2(4, 15), Vector2(14, 13), Vector2(6, 9),
		Vector2(-2, 6), Vector2(-5, 0), Vector2(-2, -6), Vector2(6, -9)])
	var interceptor_hps: Array = [
		_hardpoint("Upper Talon Gun", Vector2(10, -8), T.WEAPON, 1, 25.0),
		_hardpoint("Lower Talon Gun", Vector2(10, 8), T.WEAPON, 1, 25.0),
		_hardpoint("Main Drive", Vector2(-8, 0), T.ENGINE, 2),
		_hardpoint("Reactor Cradle", Vector2(0, 0), T.REACTOR, 1),
		_hardpoint("Defense Bay", Vector2(4, 0), T.DEFENSE, 1),
		_hardpoint("Utility Bay", Vector2(-2, -4), T.SYSTEM, 1),
	]
	interceptor.hardpoints.assign(interceptor_hps)
	_save_hull(interceptor, "res://data/hulls/cutlass.tres")

	# Enemy-only hulls (not in the shop or sample player builds).
	var wasp := HullDefS.new()
	wasp.display_name = "Wasp"
	wasp.grade = GradesS.Grade.SALVAGE   # everything so far is second-hand
	wasp.category = "Interceptor"
	wasp.level = 1   # the weakest thing that flies
	wasp.size_band = HullDefS.SizeBand.LIGHT
	wasp.mass = 22.0
	wasp.hull_hp = 55.0
	wasp.cargo_base = 2.0
	wasp.trait_id = "stinger"
	wasp.trait_description = "Stinger: barely more than an engine with a gun. Fast, fragile, furious."
	wasp.silhouette = PackedVector2Array([
		Vector2(10, 0), Vector2(-2, -5), Vector2(-8, -3), Vector2(-8, 3), Vector2(-2, 5)])
	var wasp_hps: Array = [
		_hardpoint("Sting Gun", Vector2(7, 0), T.WEAPON, 1, 30.0),
		_hardpoint("Drive", Vector2(-7, 0), T.ENGINE, 1),
		_hardpoint("Cell Mount", Vector2(-2, 0), T.REACTOR, 1),
	]
	wasp.hardpoints.assign(wasp_hps)
	_save_hull(wasp, "res://data/hulls/wasp.tres")

	# First MEDIUM hull: 32px art budget, 64 world units. Twice the size of
	# anything the player can fly in the MVP — the ladder made visible.
	var vulture := HullDefS.new()
	vulture.display_name = "Vulture"
	vulture.grade = GradesS.Grade.SALVAGE   # everything so far is second-hand
	vulture.category = "Gunship"
	vulture.level = 5   # the rim mini-boss: top of the starting band
	vulture.size_band = HullDefS.SizeBand.MEDIUM
	vulture.mass = 150.0
	vulture.hull_hp = 320.0
	vulture.cargo_base = 20.0
	vulture.trait_id = "carrion_lord"
	vulture.trait_description = "Carrion Lord: slow, patient, and armed like a grudge."
	vulture.silhouette = PackedVector2Array([
		Vector2(30, 0), Vector2(12, -14), Vector2(-16, -20), Vector2(-30, -8),
		Vector2(-30, 8), Vector2(-16, 20), Vector2(12, 14)])
	var vulture_hps: Array = [
		_hardpoint("Turret Ring", Vector2(0, 0), T.WEAPON, 2, 360.0),
		_hardpoint("Nose Cannon", Vector2(24, 0), T.WEAPON, 2, 60.0),
		_hardpoint("Main Drive", Vector2(-28, 0), T.ENGINE, 2),
		_hardpoint("Reactor Housing", Vector2(-12, 0), T.REACTOR, 2),
		_hardpoint("Defense Bay Port", Vector2(2, -10), T.DEFENSE, 2),
		_hardpoint("Defense Bay Starboard", Vector2(2, 10), T.DEFENSE, 1),
	]
	vulture.hardpoints.assign(vulture_hps)
	_save_hull(vulture, "res://data/hulls/vulture.tres")

	# The Dowager: the FIRST medium a player can buy — a beaten-up smuggler's
	# "old girl", junk for what a medium becomes but a real step up in the Reach.
	# Everything is Mk1 and forty years old EXCEPT the one gun she brags about
	# (Mk2 foredeck mount) and the Mk2 reactor strapped in to feed it.
	var dowager := HullDefS.new()
	dowager.display_name = "Dowager"
	dowager.grade = GradesS.Grade.FLOTSAM   # junk-tier: held together by habit
	dowager.category = "Gunboat"
	dowager.level = 4   # the local ceiling a player can buy
	dowager.size_band = HullDefS.SizeBand.MEDIUM
	dowager.mass = 118.0
	dowager.hull_hp = 230.0
	dowager.cargo_base = 34.0
	dowager.price = 5500
	dowager.trait_id = "old_girl"
	dowager.trait_description = "The Old Girl: she isn't a dancer. More stomp than step. Forty years of patches, one gun worth the bragging, half her systems running on faith — but full of memories, though."
	dowager.silhouette = PackedVector2Array([
		Vector2(28, 0), Vector2(20, -11), Vector2(-6, -16), Vector2(-24, -12),
		Vector2(-28, -4), Vector2(-28, 4), Vector2(-24, 12), Vector2(-6, 16), Vector2(20, 11)])
	var dowager_hps: Array = [
		_hardpoint("Foredeck Turret", Vector2(16, 0), T.WEAPON, 2, 360.0),
		_hardpoint("Spite Gun", Vector2(6, -8), T.WEAPON, 1, 200.0),
		_hardpoint("Tired Drive", Vector2(-26, 0), T.ENGINE, 1),
		_hardpoint("Reactor Cradle", Vector2(-12, 0), T.REACTOR, 2),
		_hardpoint("Patched Plate", Vector2(0, 6), T.DEFENSE, 1),
		_hardpoint("Smuggler's Hold", Vector2(-4, -6), T.SYSTEM, 1),
	]
	dowager.hardpoints.assign(dowager_hps)
	_save_hull(dowager, "res://data/hulls/dowager.tres")

	# SUPERCRUISER — the first true capital hull (SUPER_HEAVY), the Galean Navy's
	# line-of-battle ship and the reason the Orivel drydocks exist. Two size bands
	# above anything else (Vulture/Dowager top out at MEDIUM). A Mk4 CRUISER
	# (user, 2026-07-24) — the first Galean Confederacy capital tier (their navy runs
	# a whole line: scouts/fighters -> bombers/gunships -> supercruisers/carriers).
	# Mixed batteries: Mk4 mains punch at 90 deg/s, Mk1 point-defense actually swats
	# fighters — lethal solo, better with escorts. NPC
	# fleet for now (price 0, not for sale until the capital shipyard opens); level
	# 35 is a display seam until level-scaling lands in main. Aligns with the
	# GALEAN CONFEDERACY faction when that's built.
	var cruiser := HullDefS.new()
	cruiser.display_name = "Supercruiser"
	cruiser.art_path = "res://assets/ships/galean-navy/cruiser-1.png"   # faction-folder convention
	cruiser.grade = GradesS.Grade.STANDARD   # Galean Navy line ship, not salvage
	cruiser.level = 35
	cruiser.category = "Cruiser"
	cruiser.size_band = HullDefS.SizeBand.SUPER_HEAVY
	cruiser.mass = 780.0
	cruiser.hull_hp = 1800.0
	cruiser.cargo_base = 40.0
	cruiser.price = 0   # not for sale yet — the MEDIUM-capped station can't; Orivel's shipyard is "coming"
	cruiser.trait_id = "line_of_battle"
	cruiser.trait_description = "Line of Battle: a wall of the Reach — built to stand in the lane and trade fire. The main batteries gut a cruiser; its point-defense turrets swat the gnats the big guns can't track. Escorts extend the screen, but it dies hard alone."
	# SUPER_HEAVY band: 128px art canvas = 256 world units max extent.
	cruiser.silhouette = PackedVector2Array([
		Vector2(115, 0), Vector2(80, -18), Vector2(20, -30), Vector2(-60, -32),
		Vector2(-100, -20), Vector2(-110, 0), Vector2(-100, 20), Vector2(-60, 32),
		Vector2(20, 30), Vector2(80, 18)])
	var cruiser_hps: Array = [
		_hardpoint("Spinal Lance", Vector2(100, 0), T.WEAPON, 4, 45.0),
		_hardpoint("Dorsal Main Battery", Vector2(35, -16), T.WEAPON, 4, 360.0),
		_hardpoint("Ventral Main Battery", Vector2(35, 16), T.WEAPON, 4, 360.0),
		_hardpoint("Port Point-Defense", Vector2(-15, -30), T.WEAPON, 1, 360.0),
		_hardpoint("Starboard Point-Defense", Vector2(-15, 30), T.WEAPON, 1, 360.0),
		_hardpoint("Secondary Battery", Vector2(-45, 0), T.WEAPON, 3, 360.0),
		_hardpoint("Main Drive", Vector2(-100, -12), T.ENGINE, 3),
		_hardpoint("Auxiliary Drive", Vector2(-100, 12), T.ENGINE, 3),
		_hardpoint("Capital Reactor", Vector2(-60, 0), T.REACTOR, 3),
		_hardpoint("Armor Belt Port", Vector2(5, -22), T.DEFENSE, 3),
		_hardpoint("Armor Belt Starboard", Vector2(5, 22), T.DEFENSE, 3),
		_hardpoint("Command Deck", Vector2(60, 0), T.SYSTEM, 3),
		_hardpoint("Universal Coupling", Vector2(-35, 0), T.COUPLING, 5),
	]
	cruiser.hardpoints.assign(cruiser_hps)
	_save_hull(cruiser, "res://data/hulls/supercruiser.tres")

	# ==== THE LONG LANE (docs/the_long_lane.md, user 2026-07-25) ====
	# Freight between Orivel and the rim is a different voyage from the little
	# station<->colony hop, and it should LOOK like one. Four hulls flying the
	# capital run: two haulers worth escorting and two escorts worth hiring.
	#
	# ALL FOUR ARE STANDARD GRADE (green) — a visible tier above the Reach's
	# grey/white salvage. That IS the point: these are factory hulls owned by
	# freight companies and escort outfits out of the capital, not scrap the
	# fringe keeps flying out of habit. Killing one in the Gap is how a rim
	# pilot first sees clean gear, since loot is the victim's actual build.
	#
	# NOT FOR SALE YET (price 0), like the Supercruiser: the Reach station caps
	# berths at MEDIUM, and a STANDARD medium would walk straight past the
	# Dowager, which is deliberately the local ceiling. Setting a price is the
	# one-line change when the capital shipyard opens.
	#
	# TURRET NOTE: traverse is AUTHORED per weapon now (WeaponDef.traverse), so a
	# ring's MARK says how big a gun it can hold and the GUN says what it can
	# track. Haulers get real Mk2/Mk3 rings carrying the Drover Defense Turret —
	# 240 deg/s, which follows a jinking fighter and barely scratches it. An armed
	# hauler is annoying, never safe, and the balance lever is the gun, not the
	# mount: refit the same ring with something meaner and the calculus changes.

	# HARRIER — the light escort. Long-winged, cheap, and bought by the dozen;
	# the ship you see FOUR of, never one. Lean slot set (two fixed guns) so it
	# is a different animal from the Sparrowhawk knife-fighter rather than a
	# strictly better one — it trades the third gun for a utility bay.
	var harrier := HullDefS.new()
	harrier.display_name = "Harrier"
	harrier.grade = GradesS.Grade.STANDARD
	harrier.level = 6
	harrier.category = "Fighter"
	harrier.size_band = HullDefS.SizeBand.LIGHT
	harrier.mass = 38.0
	harrier.hull_hp = 105.0
	harrier.cargo_base = 6.0
	harrier.price = 0
	harrier.trait_id = "wing_discipline"
	harrier.trait_description = "Wing Discipline: built to fly in a wing and priced to be replaced. Alone it is a nuisance; in fours it is a fence."
	# LIGHT band: 16px art canvas = 32 world units max extent.
	harrier.silhouette = PackedVector2Array([
		Vector2(16, 0), Vector2(6, -4), Vector2(-6, -14), Vector2(-12, -12),
		Vector2(-10, -3), Vector2(-14, 0), Vector2(-10, 3), Vector2(-12, 12),
		Vector2(-6, 14), Vector2(6, 4)])
	var harrier_hps: Array = [
		_hardpoint("Port Wing Gun", Vector2(4, -6), T.WEAPON, 1, 35.0),
		_hardpoint("Starboard Wing Gun", Vector2(4, 6), T.WEAPON, 1, 35.0),
		_hardpoint("Main Drive", Vector2(-12, 0), T.ENGINE, 2),
		_hardpoint("Reactor Cradle", Vector2(-4, 0), T.REACTOR, 1),
		_hardpoint("Defense Bay", Vector2(1, 0), T.DEFENSE, 1),
		_hardpoint("Utility Bay", Vector2(-1, -8), T.SYSTEM, 1),
	]
	harrier.hardpoints.assign(harrier_hps)
	_save_hull(harrier, "res://data/hulls/harrier.tres")

	# GOSHAWK — the real escort, and the pirate you should be afraid of. Named
	# for the sparrowhawk's bigger cousin ON PURPOSE: the ladder is legible from
	# the name alone. Twin Mk2 nose guns to hurt, plus a Mk1 dorsal turret
	# (360 deg/s) that covers the six a fixed-arc fighter cannot — which is what
	# makes it an ESCORT rather than just a heavier interceptor.
	var goshawk := HullDefS.new()
	goshawk.display_name = "Goshawk"
	goshawk.grade = GradesS.Grade.STANDARD
	goshawk.level = 12
	goshawk.category = "Fighter"
	goshawk.size_band = HullDefS.SizeBand.MEDIUM
	goshawk.mass = 130.0
	goshawk.hull_hp = 280.0
	goshawk.cargo_base = 14.0
	goshawk.price = 0
	goshawk.trait_id = "hunting_pair"
	goshawk.trait_description = "Hunting Pair: goshawks work a hedgerow in twos — one flushes, one waits. Faster than the gunships and better armed than anything that can catch it."
	# MEDIUM band: 32px art canvas = 64 world units max extent.
	goshawk.silhouette = PackedVector2Array([
		Vector2(30, 0), Vector2(16, -8), Vector2(-4, -22), Vector2(-18, -20),
		Vector2(-14, -6), Vector2(-26, -4), Vector2(-26, 4), Vector2(-14, 6),
		Vector2(-18, 20), Vector2(-4, 22), Vector2(16, 8)])
	var goshawk_hps: Array = [
		_hardpoint("Port Nose Gun", Vector2(20, -5), T.WEAPON, 2, 30.0),
		_hardpoint("Starboard Nose Gun", Vector2(20, 5), T.WEAPON, 2, 30.0),
		_hardpoint("Dorsal Turret", Vector2(0, 0), T.WEAPON, 1, 360.0),
		_hardpoint("Main Drive", Vector2(-24, 0), T.ENGINE, 2),
		_hardpoint("Reactor Housing", Vector2(-10, 0), T.REACTOR, 2),
		_hardpoint("Defense Bay Port", Vector2(8, -10), T.DEFENSE, 2),
		_hardpoint("Defense Bay Starboard", Vector2(8, 10), T.DEFENSE, 1),
		_hardpoint("Utility Bay", Vector2(-4, -12), T.SYSTEM, 1),
	]
	goshawk.hardpoints.assign(goshawk_hps)
	_save_hull(goshawk, "res://data/hulls/goshawk.tres")

	# DRAY — the medium freighter, and the workhorse of the lane. A dray is the
	# flat cart that hauls the load, which is the whole personality: it carries
	# more than four Mules and answers with two fast, feeble turret rings. It
	# cannot win a fight; it can make one expensive enough to be worth breaking
	# off. Mule -> Dray -> Bellwether is the freight ladder.
	var dray := HullDefS.new()
	dray.display_name = "Dray"
	dray.grade = GradesS.Grade.STANDARD
	dray.level = 8
	dray.category = "Freighter"
	dray.size_band = HullDefS.SizeBand.MEDIUM
	dray.mass = 190.0
	dray.hull_hp = 300.0
	dray.cargo_base = 140.0
	dray.price = 0
	dray.trait_id = "steady_hand"
	dray.trait_description = "Steady Hand: a hauler holds course when it is shot at, because the cargo is the job. Turret rings fore and aft do the flinching for her."
	dray.silhouette = PackedVector2Array([
		Vector2(26, 0), Vector2(20, -12), Vector2(-14, -18), Vector2(-28, -12),
		Vector2(-30, 0), Vector2(-28, 12), Vector2(-14, 18), Vector2(20, 12)])
	var dray_hps: Array = [
		_hardpoint("Dorsal Turret Ring", Vector2(4, -8), T.WEAPON, 2, 360.0),
		_hardpoint("Ventral Turret Ring", Vector2(4, 8), T.WEAPON, 2, 360.0),
		_hardpoint("Main Drive", Vector2(-26, 0), T.ENGINE, 2),
		_hardpoint("Reactor Cradle", Vector2(-12, 0), T.REACTOR, 2),
		_hardpoint("Defense Bay Fore", Vector2(14, 0), T.DEFENSE, 2),
		_hardpoint("Defense Bay Aft", Vector2(-20, 0), T.DEFENSE, 1),
		_hardpoint("Cargo Bay A", Vector2(-2, -14), T.SYSTEM, 2),
		_hardpoint("Cargo Bay B", Vector2(-2, 14), T.SYSTEM, 2),
	]
	dray.hardpoints.assign(dray_hps)
	_save_hull(dray, "res://data/hulls/dray.tres")

	# BELLWETHER — the heavy freighter, and the convoy's reason to exist. The
	# bellwether is the animal the flock follows, which is exactly what this is:
	# the ship the escorts are formed around and the one the V-Shrike cross the
	# Gap for. Slow, enormously valuable, three turrets that are not enough.
	# NOTE she is HEAVY, so the MEDIUM-capped Reach station can never berth her
	# (DockingPad.max_size_band) — she runs Orivel's bays and Epharon's surface,
	# which is precisely why the little station still sees Mules.
	var bellwether := HullDefS.new()
	bellwether.display_name = "Bellwether"
	bellwether.grade = GradesS.Grade.STANDARD
	bellwether.level = 15
	bellwether.category = "Freighter"
	bellwether.size_band = HullDefS.SizeBand.HEAVY
	bellwether.mass = 420.0
	bellwether.hull_hp = 900.0
	bellwether.cargo_base = 400.0
	bellwether.price = 0
	bellwether.trait_id = "convoy_heart"
	bellwether.trait_description = "Convoy Heart: everything else on the lane is arranged around her. She is worth more than her escort, slower than her attackers, and perfectly aware of both."
	# HEAVY band: 64px art canvas = 128 world units max extent.
	bellwether.silhouette = PackedVector2Array([
		Vector2(58, 0), Vector2(48, -20), Vector2(-20, -34), Vector2(-52, -26),
		Vector2(-60, -10), Vector2(-60, 10), Vector2(-52, 26), Vector2(-20, 34),
		Vector2(48, 20)])
	var bellwether_hps: Array = [
		_hardpoint("Dorsal Turret Ring", Vector2(10, -18), T.WEAPON, 3, 360.0),
		_hardpoint("Ventral Turret Ring", Vector2(10, 18), T.WEAPON, 3, 360.0),
		_hardpoint("Aft Turret", Vector2(-40, 0), T.WEAPON, 2, 360.0),
		_hardpoint("Main Drive", Vector2(-54, -12), T.ENGINE, 3),
		_hardpoint("Auxiliary Drive", Vector2(-54, 12), T.ENGINE, 2),
		_hardpoint("Reactor Housing", Vector2(-26, 0), T.REACTOR, 3),
		_hardpoint("Armor Belt Port", Vector2(0, -26), T.DEFENSE, 3),
		_hardpoint("Armor Belt Starboard", Vector2(0, 26), T.DEFENSE, 2),
		_hardpoint("Cargo Hold Fore", Vector2(32, 0), T.SYSTEM, 3),
		_hardpoint("Cargo Hold Aft", Vector2(-10, 0), T.SYSTEM, 3),
		_hardpoint("Bridge", Vector2(44, 0), T.SYSTEM, 2),
	]
	bellwether.hardpoints.assign(bellwether_hps)
	_save_hull(bellwether, "res://data/hulls/bellwether.tres")
