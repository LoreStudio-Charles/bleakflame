extends Node2D

## First authored geography of Cinder Reach. Enemies live in PLACES and fly
## between them; nothing ambient ever spawns relative to the player (that is
## reserved for authored ambush events). The Rust Shoal is the pirate den
## flanking the station-planetoid trade lane; the Vulture haunts the deep
## space beyond the planetoid.
const PIRATE_DEN := Vector2(2600, -7600)     # the Rust Shoal (pushed out — a real trip, off the new-pilot lanes)
const VULTURE_HAUNT := Vector2(11800, -1400)
const LANE_A := Vector2(2100, 1300)          # trade lane, station side
const LANE_B := Vector2(6300, 3900)          # trade lane, planet approach
## The Drift Belt: a CHARTED neutral mining field south of the lane. Safe-ish
## prospecting lives here; the Shoal's rocks are richer because they are not.
const BELT_CENTER := Vector2(4600, 6800)
## Wayfinder Core dig site: past the belt's far rim, so the triangulation
## actually sends you somewhere the seeded field doesn't already take you.
const DIG_SITE := Vector2(6400, 8600)
const BELT_COUNT := 16   # trimmed (was 26): two belts now, and aurite_min guarantees the veins
const BELT_SEED := 0xD81F7
## The Verge: a second CHARTED mining field on the quiet western rim — no
## pirates, aurite-rich. Where prospectors work when the Shoal is too hot.
const VERGE_CENTER := Vector2(-6000, 2600)
const VERGE_COUNT := 14   # trimmed (was 22): aurite_min 6 still guarantees the payoff
const VERGE_SEED := 0x5A17E

## ORIVEL — the Galean capital, the HEART of Cinder Reach. We start on the fringe;
## Orivel is ~10x the fringe->Epharon distance out, on the FAR side of the station
## from the colony (a clean -10x the planet's position). ~3x Epharon's size. A
## landmark only for now (no services, no waypoint) — a reward for the pilot mad
## enough to make the all-legs haul out there. Traversal stays a real haul until
## warp tech; nobody's meant to fly it yet.
const ORIVEL := Vector2(-84000, -52000)
## The Orivel Orbital Outpost's offset from the planet — ~9k out, clear of the
## 3x gravity well (radius ~6240), a stable parking orbit off the capital.
const ORIVEL_ORBITAL := Vector2(-84000, -52000) + Vector2(8200, -3600)
const ORIVEL_ORBITAL_OFFSET := Vector2(8200, -3600)

const DRONE_COUNT := 2
## Pirate kills that break Vyper's truce (Pilot.shoal_truce_kills). A promise, not
## a suicide pact — betray it this many times and the Shoal hunts you again.
const SHOAL_TRUCE_BREAK := 10

@onready var ship: TestShip = $Ship
## Untyped: flight_hud.gd has no class_name, so this is duck-typed (we only
## reach for `comm`, the cockpit's chat terminal).
@onready var hud = $HUD

var station: Station
var planetoid: Planetoid
var shoal: PirateDen
var station_screen: DockScreen
var planet_screen: DockScreen
var orivel_screen: OrivelDock
var _outpost: OrivelOutpost
var shoal_screen: SpeakEasy
var diggs: DiggsFreighter
var diggs_screen: ProspectDeck
var _was_docked_at: Node = null
var _launch_window: LaunchWindow = null
var _range_ruler: RangeRuler = null
var _dev_vitals: DevVitals = null


func _ready() -> void:
	SaveGame.load_game()   # once per app launch; no-op afterward

	station = Station.new()
	station.position = Vector2.ZERO
	# Sanctuary anchor: pirates and the Cinderweb both respect this point.
	AIShip.station_pos = station.position
	AIShip.sanctuary_suppressed = false
	add_child(station)

	# Far enough that the trip is real and sensors earn their keep.
	planetoid = Planetoid.new()
	planetoid.position = Vector2(8400, 5200)
	add_child(planetoid)

	# Orivel, the capital, ~3x Epharon's size far out on the far side. A real body
	# now — its own gravity well + surface collider (radius_mult 3) — but NOT
	# landable yet (no services): approach it, feel the pull, can't set down. The
	# payoff is SEEING it after the mad haul. Art assets/world/orivel.png (a
	# futuristic ocean-world capital with a domed megacity), 256px like planetoid.png.
	var orivel := Planetoid.new()
	orivel.radius_mult = 3.0
	orivel.landable = false
	orivel.sprite_path = "res://assets/world/orivel.png"
	orivel.position = ORIVEL
	orivel.z_index = -5
	add_child(orivel)

	# The Orivel Orbital Outpost — the capital's drydock ring, in a safe orbit just
	# OUTSIDE Orivel's gravity well (well radius ~6240; this sits ~9k out). A
	# landmark for now; a place to /warp near and see the capital's scale.
	_outpost = OrivelOutpost.new()
	_outpost.position = ORIVEL + ORIVEL_ORBITAL_OFFSET
	_outpost.z_index = -4
	add_child(_outpost)

	ship.apply_build(SampleBuilds.get_build(SampleBuilds.current))
	SaveGame.restore_ship(ship)
	ship.global_position = station.pad.global_position
	ship.dock(station.pad)

	# Fresh pilots sign the registry before anything else; the tutorial
	# holds until the ink is dry.
	if not Pilot.created:
		var creation := CharacterCreation.new(ship)
		creation.confirmed.connect(func() -> void:
			if not SaveGame.tutorial_done:
				add_child(Tutorial.new(ship)))
		add_child(creation)
	elif not SaveGame.tutorial_done:
		add_child(Tutorial.new(ship))

	_try_wake_leviathan()

	shoal = PirateDen.new()
	shoal.position = PIRATE_DEN
	add_child(shoal)

	# THE DIG — Doug's freighter, parked at the Verge's rim so the belt is right
	# outside her bay. She is what makes the Verge a destination instead of a
	# patch of rocks that pays the same as any other patch of rocks.
	diggs = DiggsFreighter.new()
	diggs.position = VERGE_CENTER + Vector2(-1500, -900)
	add_child(diggs)

	MissionLog.ensure_offers()
	station_screen = DockScreen.new(ship, true)
	add_child(station_screen)
	planet_screen = DockScreen.new(ship, false)
	add_child(planet_screen)
	orivel_screen = OrivelDock.new(ship)
	add_child(orivel_screen)
	shoal_screen = SpeakEasy.new(ship)
	add_child(shoal_screen)
	diggs_screen = ProspectDeck.new(ship)
	add_child(diggs_screen)

	# The chart: charted places start discovered; the rest must be FOUND.
	PoiMap.clear_scene()
	PoiMap.register("station", "Station", station.pad.global_position, "station", true)
	PoiMap.register("planetoid", "Epharon", planetoid.position, "planet", true)
	# Orivel is SECRET: it charts only when a pilot actually reaches it (the crazy
	# trip), and being uncharted it never shows on radar or auto-marks a waypoint.
	PoiMap.register("orivel", "Orivel — the Capital", ORIVEL, "planet")
	# The capital's orbital outpost — SECRET like Orivel, charts on arrival.
	PoiMap.register("orivel_orbital", "Orivel Orbital Outpost", ORIVEL_ORBITAL, "station")
	PoiMap.register("belt", "Drift Belt", BELT_CENTER, "belt", true)
	PoiMap.register("verge", "The Verge", VERGE_CENTER, "belt", true)
	PoiMap.register("the_dig", "The Dig — Doug Diggs", diggs.position, "station", true)
	PoiMap.register("rust_shoal", "The Rust Shoal", PIRATE_DEN, "den")
	PoiMap.register("haunt", "The Vulture's Haunt", VULTURE_HAUNT, "haunt")
	# Discovery-chain dig site: secret, charted by the chain itself (the
	# triangulation stage calls PoiMap.discover), not by flying near it.
	PoiMap.register("silent_beacon", "The Silent Beacon", DIG_SITE, "dig")
	# Campaign quest marks (position must match the quest def's `pos`).
	# Just off the lane, planet-side — and well OUTSIDE the planetoid's
	# 2080-unit gravity well: a quest diamond must never drag a new pilot
	# into a gravity check they didn't sign up for.
	# EPHEMERAL (ephemeral=true): quest-ONLY markers — nothing is there unless the
	# beat places it. They never proximity-chart, and Quests.refresh_pois shows them
	# ONLY while their stage is live, then hides them (no orphaned map clutter).
	PoiMap.register("meridian_fix", "Last Fix: Long Meridian", Vector2(6950, 3400), "signal", false, true)
	PoiMap.register("cold_patch_site", "Anomalous Return", Vector2(4200, -1600), "signal", false, true)
	PoiMap.register("ambush_site", "Plotted Intercept", Vector2(2800, -2800), "signal", false, true)
	PoiMap.register("tendril_site", "Severed Tendril", Vector2(3400, -3300), "signal", false, true)
	PoiMap.register("waygate", "The Ancient Gate", Vector2(-6800, 8200), "gate")
	if PoiMap.waypoint_id == "":
		PoiMap.waypoint_id = "station"   # a new pilot can always find home
	add_child(SystemMap.new(ship))
	add_child(CaptainsLog.new(ship))
	add_child(CommsInbox.new(ship))
	add_child(SalvagePanel.new(ship))
	add_child(FactionsView.new(ship))   # [U] factions & peace (docked or flying)
	add_child(GoingDark.new(ship))      # [K] systems offline: re-flash the Bus in flight
	# Last, so it receives Esc before the overlays above and can defer to any
	# of them that's currently open (they join "esc_capture" while visible).
	add_child(PauseMenu.new())
	# Dev range ruler (] toggles it) — world-space so distances read true.
	_range_ruler = RangeRuler.new(ship)
	add_child(_range_ruler)
	# Dev heartbeat monitor ([=] toggles it): live feed of stalls, planet crashes,
	# energy starves — the concerning stuff, as it happens. DEBUG-ONLY: it is not
	# even created in a release export, and the toggle key is gated too.
	if OS.is_debug_build():
		Telemetry.reset()
		_dev_vitals = DevVitals.new(ship)
		add_child(_dev_vitals)
		# Dev cheats now live in the comm terminal (Enter, then type). Registering
		# the hook is itself the dev gate — a release export skips this whole block,
		# so /cash & friends are simply unknown commands there.
		Chat.dev_command = _run_dev_command
		Chat.dev_help = "[dev] /cash [n] /insight [n] /xp [n] /gate /ruler /heartbeat /rearm"

	_populate_world()


## One-time population. (This used to run on every dock-state change — every
## dock AND undock quietly spawned a full extra wave. The gauntlet was a bug.)
func _populate_world() -> void:
	for i in DRONE_COUNT:
		_spawn_drone(_drone_spot())
	_spawn_guard_wing()
	# Denser lanes (user, 2026-07-23): more raiders + wasps, the LIGHT harassers, so
	# the sky feels busier without stacking heavies on a new pilot. 4 raider / 1
	# brawler / 5 wasp on the trade lane (+ 1 vulture + the Verge prowler elsewhere).
	for kind in ["raider", "raider", "raider", "raider", "brawler", "wasp", "wasp", "wasp", "wasp", "wasp"]:
		var route := _patrol_route(kind)
		# Start mid-route: the world is already in motion, not queued at home.
		_spawn_pirate(route[randi() % route.size()] + _jitter(500.0), kind, route)
	var vulture_route := _patrol_route("vulture")
	_spawn_pirate(vulture_route[0] + _jitter(700.0), "vulture", vulture_route)
	_spawn_belt(BELT_CENTER, BELT_COUNT, BELT_SEED, 4)
	_spawn_belt(VERGE_CENTER, VERGE_COUNT, VERGE_SEED, 6)
	# Trader-guild lane traffic: civilian haulers running the trade lane (east) and
	# the Verge run (west). World-anchored like the pirates — you meet them en route.
	var trade_lane: Array[Vector2] = [Vector2(1300, 850), LANE_A, LANE_B, Vector2(7500, 4650)]
	_spawn_trader(trade_lane[randi() % trade_lane.size()] + _jitter(400.0), trade_lane)
	_spawn_trader(trade_lane[randi() % trade_lane.size()] + _jitter(400.0), trade_lane)
	# One Guardian patrol per lane: flying the road, gunning pirates it meets —
	# and exposed out there, so the Cinderweb's hunger can take them too.
	_spawn_lane_guardian(trade_lane[1] + _jitter(300.0), trade_lane)
	# Western lane -> the Verge (user, 2026-07-23): the gate road is dead now (the
	# WayGate is closed), so the hauler + Guardian that used to run it work the Verge
	# instead, and a lone raider prowls the APPROACH
	# — deliberately short of VERGE_CENTER, so the Verge stays the safer field vs the
	# Shoal (just no longer risk-free to reach). A Guardian rides the run too.
	var verge_run: Array[Vector2] = [Vector2(-1400, 1200), Vector2(-4200, 2600),
		VERGE_CENTER + _jitter(500.0)]
	_spawn_trader(verge_run[randi() % verge_run.size()] + _jitter(400.0), verge_run)
	var verge_prowl: Array[Vector2] = [Vector2(-1900, 900), Vector2(-4600, 2200),
		Vector2(-5400, 3900)]
	_spawn_pirate(verge_prowl[randi() % verge_prowl.size()] + _jitter(400.0), "raider", verge_prowl)
	_spawn_lane_guardian(verge_run[1] + _jitter(300.0), verge_run)


## Fixed-seed scatter: a Belt is a charted place; its rocks stay put. Each
## field guarantees `aurite_min` aurite nodes up front (so the trip out always
## pays), then rolls the rest — ore odds stay modest, the Shoal pays better
## because it shoots back.
func _spawn_belt(center: Vector2, count: int, seed_val: int, aurite_min: int) -> void:
	var marker := Node2D.new()
	marker.position = center
	marker.add_to_group("belts")
	add_child(marker)
	var pool := MineableAsteroid.load_pool()
	if pool.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	# Track each placed rock's centre + spacing radius so the next one can't land
	# on top of it. Deterministic: same seed -> same (non-overlapping) field.
	var placed: Array[Dictionary] = []
	for i in count:
		var type := ""
		var units := 0
		if i < aurite_min:
			type = "aurite_ore"; units = rng.randi_range(2, 3)   # guaranteed vein
		else:
			var roll := rng.randf()
			if roll < 0.38:
				type = "ferrite_ore"; units = rng.randi_range(3, 6)
			elif roll < 0.58:
				type = "cobalt_ore"; units = rng.randi_range(2, 4)
			elif roll < 0.68:
				type = "aurite_ore"; units = rng.randi_range(2, 3)
		var texture: Texture2D = pool[rng.randi() % pool.size()]
		var scale_mult := 2.0 if texture.get_width() >= 48 else rng.randf_range(1.2, 2.0)
		# Spacing radius = the sprite's visual half-width (+ a small gap), so two
		# rocks never cover each other. Reject-sample a clear spot; the belt is
		# far larger than its rocks, so a slot is found in a handful of tries.
		var r: float = texture.get_width() * 0.46 * scale_mult + 12.0
		var pos := center
		for _attempt in 48:
			pos = center + Vector2.RIGHT.rotated(rng.randf() * TAU) \
				* rng.randf_range(150.0, 1100.0)
			var clear := true
			for p in placed:
				if pos.distance_to(p.pos) < r + float(p.r):
					clear = false
					break
			if clear:
				break
		placed.append({"pos": pos, "r": r})
		add_child(MineableAsteroid.create(texture, pos, scale_mult, type, units))


func _process(_delta: float) -> void:
	_tick_distress(_delta)
	_tick_flight_lessons()
	_tick_dig_site()
	_tick_anomaly()
	_tick_ambush()
	_tick_protectors()
	_tick_goto_dialogue()
	_tick_chart_hint()
	_tick_landing_brief()
	_tick_shoal_fall()
	_tick_gate()
	_try_wake_leviathan()   # she enters the world the moment beat 3 is survived
	if not ship.dead and ship.docked_at == null:
		# Discovery is a SENSOR product: reach = sensor range (600 floor),
		# multiplied by a fitted survey scanner. A sensor-boat Kestrel with
		# a Prospector suite charts secrets from far outside their teeth.
		var reach := maxf(600.0, float(ship.stats.get("sensor_range", 0.0)))
		if ship.scanner_fitted:
			reach *= 1.5
		var found := PoiMap.tick_discovery(ship.global_position, reach)
		if found != "":
			ship._flash_note("DISCOVERED: %s — charted" % found.to_upper())
			Sfx.play("jingle", -10.0, 1.15)
			Standing.add("scout", 3)   # charting the dark is Sella's whole creed
		for note in Quests.tick_goto(ship.global_position):
			ship._flash_note(note)
			Sfx.play("jingle", -10.0, 0.85)
	if ship.docked_at == _was_docked_at:
		return
	_was_docked_at = ship.docked_at
	Sfx.reset_vo_session()   # new docking session: play-once greetings speak again
	# Exact-instance match: the Shoal berth is a DockingPad too, so `is DockingPad`
	# would wrongly raise the station screen for it.
	station_screen.visible = ship.docked_at == station.pad
	planet_screen.visible = ship.docked_at is Planetoid
	shoal_screen.visible = ship.docked_at == shoal.pad
	diggs_screen.visible = ship.docked_at == diggs.pad
	orivel_screen.visible = _outpost != null and _outpost.pads.has(ship.docked_at)
	if station_screen.visible:
		station_screen.refresh()
	if planet_screen.visible:
		planet_screen.refresh()
	if shoal_screen.visible:
		shoal_screen.refresh()
	if diggs_screen.visible:
		diggs_screen.show_deck()
	if orivel_screen.visible:
		orivel_screen.refresh()
	# Music follows place: docked comfort vs the drift. Silent until tracks
	# land in res://audio/music/ (station.ogg / drift.ogg).
	Sfx.play_music("station" if ship.docked_at != null else "drift")


## The dig site spawns its rock the moment the chain opens it (that can
## happen mid-session, docked at the lab) — once per scene instance. If the
## player dies hauling the core, the reload finds the stage still open and
## an empty hold, and the site rebuilds: the artifact waits at its rock.
var _dig_spawned := false

func _tick_dig_site() -> void:
	if _dig_spawned or not Research.dig_site_open("wayfinder_core") \
			or ship.commodities.get("wayfinder_core", 0) > 0:
		return
	_dig_spawned = true
	var pool := MineableAsteroid.load_pool()
	if pool.is_empty():
		return
	add_child(MineableAsteroid.create(pool[randi() % pool.size()], DIG_SITE,
		2.6, "wayfinder_core", 1))


## Places the quest anomaly for an active scan_target stage — once, at its
## charted spot. It despawns itself when scanned (which advances the stage,
## so scan_site() then returns empty); a fresh scan_target quest spawns a new
## one. Persists in the world until read, like the dig rock.
var _anomaly: Anomaly

func _tick_anomaly() -> void:
	if _anomaly != null and is_instance_valid(_anomaly):
		return
	var site := Quests.scan_site()
	if site.is_empty():
		return
	_anomaly = Anomaly.create(site.pos, str(site.quest), str(site.get("anomaly", "residue")))
	add_child(_anomaly)


## Beat 4+: while a scan mission wants an escort, keep a small MILITARY
## Guardian wing flying protective formation on the player — they break off
## to gun down pirates on the approach, so travel no longer piles up into an
## impossible fight. Despawns when the beat ends or the player docks.
var _protectors: Array[GuardianShip] = []

func _tick_protectors() -> void:
	_protectors = _protectors.filter(func(g: GuardianShip) -> bool:
		return g != null and is_instance_valid(g) and not g.dead)
	var want: bool = Quests.escort_active() and not ship.dead and ship.docked_at == null
	if want and _protectors.is_empty():
		for i in 3:
			_protectors.append(GuardianShip.spawn_protector(self,
				SampleBuilds.guardian_sparrowhawk(), ship, i, 3))
	elif not want and not _protectors.is_empty():
		for g in _protectors:
			if is_instance_valid(g):
				g.dismiss()   # peel off and fly home, don't blink out
		_protectors.clear()


## Beat 3, the scripted ambush. Reaching the plotted intercept summons a
## lesser Cinderweb (the ambient one is suspended so you can't meet both);
## reaching the station's light alive advances the stage and the ambusher
## folds away. Dying just sends the ambusher off — the stage waits for a
## retry. On-player spawning is sanctioned here: this IS the authored event.
var _ambient_leviathan: Cinderweb

## THE BEAST SLEEPS UNTIL THE CAMPAIGN WAKES HER (2026-07-22, user).
## Cinderweb does not exist in the world until the scripted ambush of beat 3
## ("Caught in the Open") has been survived. Before that the Reach is only ever
## RUMOUR — an overdue hauler, a cold patch, no debris.
##
## This is the campaign's own premise enforced in code. The fiction is that she
## eats ships traceless and NOBODY has survived to report her; a player who can
## watch her take a hauler and then fly home has already disproved that, and the
## reveal beat has nothing left to reveal. It also removes a whole class of
## accident — being jumped mid-tutorial, or a wandering orbiter blundering into
## the ambush and spoiling its staging.
const WAKE_QUEST := "caught_looking"   # beat 3; surviving it looses her on the Reach

## AUTHORED DISTRESS CALLS (2026-07-22, user). Cinderweb is asleep until beat 3,
## so nothing was actually hunting the lane — and the campaign's urgency was
## being ASSERTED by NPCs instead of FELT. These are the hunt made audible: a
## voice on the band, cut off mid-word into static, from somewhere you can't see.
##
## Scripted rather than ambient ON PURPOSE. It is truer to the fiction (nobody
## who witnesses her lives to report it, so you only ever hear the victim, never
## see the kill) and it guarantees the beat lands — a random ambient event the
## player might never meet cannot carry a campaign.
##
## Each fires once ever, while its quest is ACTIVE, after a delay in open space —
## never docked, never dead, never mid-conversation.
const DISTRESS_EVENTS := [
	# The FIRST one fires on the very first real flight — the dirtside run. It
	# used to wait for "overdue" (campaign beat 1, several quests in), which
	# meant a pilot could play for hours before the Reach ever felt haunted.
	# The dread has to start before the mystery is named, not after.
	{"id": "d_first", "quest": "dirtside_run", "delay": 40.0,
		"who": "Ore hauler CINDER BELL",
		"line": "—repeat, this is the Cinder Bell, we have lost the lane, there's something out here with us, it's"},
	{"id": "d_overdue", "quest": "overdue", "delay": 22.0,
		"who": "Freighter LONG MERIDIAN",
		"line": "Any station, any hull — our lights won't hold her, she's coming apart, she's"},
	{"id": "d_cold", "quest": "cold_patch", "delay": 18.0,
		"who": "Survey tender MARROW",
		"line": "Anyone, ANYONE on this band — our lights won't reach, the dark is"},
	{"id": "d_caught", "quest": "caught_looking", "delay": 14.0,
		"who": "Unidentified hull",
		"line": "—oh god it's the size of a"},
]

var _distress_t := 0.0
var _distress_active := ""


## Run the authored distress schedule. Deliberately identical in presentation to
## Cinderweb._broadcast_distress (flash + static + Comms), so a player can never
## tell the scripted foreshadowing from the real thing later.
## Arm the in-flight lessons at the moment each first MATTERS — never on a
## timer, so the game only explains what the pilot is already looking at.
## Distance at which a hostile counts as a live threat — inside this, teaching
## stops. Comfortably outside weapon range, so a lesson never appears while
## anything can already shoot you.
const TEACH_THREAT_R := 1100.0


func _tick_flight_lessons() -> void:
	Tutor.tick(get_process_delta_time())   # a jammed lesson always gives up
	if ship.dead:
		return
	if ship.docked_at != null:
		Tutor.safe = true          # a dock is the safest room in the game
		Tutor.context = "dock"
		Tutor.pump()
		return
	Tutor.context = "flight"
	Tutor.venue = ""              # no dock underfoot; venue-tagged lessons wait

	# Is it safe to teach right now? A truce or the station's sanctuary bubble
	# both count — inside them nothing ambient will engage.
	var nearest := INF
	for node in get_tree().get_nodes_in_group("hostile_team"):
		if node is BuildShip and not node.dead:
			nearest = minf(nearest, ship.global_position.distance_to(node.global_position))
	var sheltered: bool = AIShip.parley \
		or ship.global_position.distance_to(AIShip.station_pos) < AIShip.SANCTUARY_R
	# A hunting leviathan is never a teachable moment, wherever you are.
	var hunted := false
	for lev in get_tree().get_nodes_in_group("leviathan"):
		if lev.get("hunting") == true:
			hunted = true
			break
	Tutor.safe = not hunted and (sheltered or nearest > TEACH_THREAT_R)

	# DECLARATIVE TUTOR (2026-07-23): hand the tutor a snapshot of what's true right
	# now and let each migrated lesson's own predicate decide arming + completion
	# (Tutor.observe -> Tutor._build_preds). These flight lessons — vitals, meet_doug,
	# log, running_dark, targeting — used to be scattered arm() calls here.
	var has_ore := false
	for key in ship.commodities:
		if str(key).ends_with("_ore") and int(ship.commodities[key]) > 0:
			has_ore = true
			break
	var live_ability := false
	for i in Pilot.GEM_SLOTS:
		var aid := Pilot.gem_at(i)
		if aid != "" and ship._known_abilities.has(aid):
			live_ability = true
			break
	var carrying_ordnance := false
	for m in ship._mounts:
		if m.def != null and m.def.magazine > 0:
			carrying_ordnance = true
			break
	var reach := maxf(600.0, float(ship.stats.get("sensor_range", 0.0)))
	Tutor.observe({
		"flying": true,
		"has_ore": has_ore,
		"met_doug": Pilot.has_met("doug"),
		"journal": not Research.journal.is_empty(),
		"energy_spent": ship.energy_max > 0.0 and ship.energy < ship.energy_max * 0.6 and live_ability,
		"has_wired_ability": live_ability,
		"has_target": ship.target != null and is_instance_valid(ship.target),
		"contact_far": nearest > TEACH_THREAT_R and nearest < reach,
		"waypoint_set": PoiMap.waypoint_id != "",
		"comms_any": not Comms.messages.is_empty(),
		"hold_full": ship.cargo_used() >= float(ship.stats.cargo),
		"carrying_ordnance": carrying_ordnance,
	})


func _tick_distress(delta: float) -> void:
	if ship.dead or ship.docked_at != null or ship.cinematic or _goto_talk_active:
		return
	for ev in DISTRESS_EVENTS:
		var id: String = ev.id
		var q := str(ev.quest)
		var reached: bool = Quests.active.has(q) or Quests.completed.has(q)
		if SaveGame.distress_heard.has(id) or not reached:
			continue
		if _distress_active != id:
			_distress_active = id      # a new one armed; start its clock
			_distress_t = 0.0
		_distress_t += delta
		if _distress_t < float(ev.delay):
			return
		SaveGame.distress_heard.append(id)
		_distress_active = ""
		ship._flash_note("⚠ DISTRESS — %s: \"%s—\"   ✂ STATIC" % [ev.who, ev.line])
		Comms.post("ruel", "Distress Relay",
			"A fragment came in over the open band, then nothing.\n\n\"%s—\"\n\n"
			% ev.line
			+ "The relay logged it as %s. No wreck. No beacon. No debris field. "
			% ev.who
			+ "Docking Control has stopped reading these aloud.")
		Sfx.play("static", -5.0)
		return


func _leviathan_awake() -> bool:
	return Quests.completed.has(WAKE_QUEST)


## Bring her into the world the moment the campaign earns her — at scene start
## for a save that is already past beat 3, or mid-flight the instant the ambush
## is survived. Never spawns twice.
func _try_wake_leviathan() -> void:
	if _ambient_leviathan != null or not _leviathan_awake():
		return
	_ambient_leviathan = Cinderweb.new()
	add_child(_ambient_leviathan)
	Telemetry.note("beast", "ambient Cinderweb awake (orbiter live)")
var _ambusher: Cinderweb
var _ambush_armed_noted := false
var _ambush_near_noted := false
var _ambush_active := false
var _ambush_quest := ""
var _escorts: Array[GuardianShip] = []
var _shadow_escorts: Array[GuardianShip] = []

func _tick_ambush() -> void:
	if _ambush_active:
		var reached_light: bool = not ship.dead and (ship.docked_at != null \
			or ship.global_position.distance_to(AIShip.station_pos) < AIShip.SANCTUARY_R)
		var ambusher_gone: bool = _ambusher == null or not is_instance_valid(_ambusher)
		if reached_light or (ambusher_gone and not ship.dead):
			_end_ambush(true)
		elif ship.dead:
			_end_ambush(false)
		return
	var site := Quests.survive_site()
	if site.is_empty():
		_ambush_armed_noted = false   # stage not active — reset for the next one
		_ambush_near_noted = false
		_stand_down_shadow()          # stage abandoned/done — send any escort home
		return
	# ARMED: a survive_event stage wants an ambush. Say so ONCE, with the target
	# and how far the player is — so "I never saw one" resolves to either "it
	# never armed" (quest gate) or "I never flew there" (navigation).
	if not _ambush_armed_noted:
		_ambush_armed_noted = true
		Telemetry.warn("beast", "AMBUSH ARMED (%s) — fly to %d,%d" % [
			str(site.quest), int(site.pos.x), int(site.pos.y)])
	# Keep a SHADOW ESCORT aloft the whole time the stage is live — launched from
	# home, trailing the players out to the site and patrolling it out of sight, so
	# it is already on-station when the beast opens (no cavalry teleporting in).
	_ensure_shadow_escort(site.pos)
	if ship.dead or ship.docked_at != null:
		return
	var d := ship.global_position.distance_to(site.pos)
	if d < 520.0:
		Telemetry.note("beast", "AMBUSH SPRUNG at %d,%d ✓" % [int(site.pos.x), int(site.pos.y)])
		_start_ambush(str(site.quest), site.pos)
	elif d < 1400.0 and not _ambush_near_noted:
		_ambush_near_noted = true
		Telemetry.note("beast", "approaching ambush site — %d units out" % int(d))


func _start_ambush(quest_id: String, pos: Vector2) -> void:
	_ambush_active = true
	_ambush_quest = quest_id
	if _ambient_leviathan != null:
		_ambient_leviathan.set_suspended(true)   # never two Cinderwebs at once
	# Spawn it beyond the player relative to home, so fleeing opens a gap.
	var behind: Vector2 = pos + (pos - AIShip.station_pos).normalized() * 650.0
	_ambusher = Cinderweb.spawn_ambush(self, behind)
	ship._flash_note("THE DARK OPENS BEHIND YOU — RUN FOR THE STATION")
	# A guard wing breaks the leash to answer — and dies buying you nothing.
	# Their fire is futile; the beast unmakes them. You escape by RUNNING,
	# never by their help (they can't hold it). False dawn, not cavalry.
	await get_tree().create_timer(1.6).timeout
	if not _ambush_active or ship.dead:
		return
	ship._flash_note("HARBOR WING RESPONDING — \"...what is that. What IS th—\"")
	# The escort that has been SHADOWING you the whole way out breaks toward the
	# beast — already on-station from wherever it was trailing, not cavalry blinking
	# in. (Fallback: if somehow nothing was trailing, launch a wing from home now.)
	_commit_shadow_escort(pos)


func _on_escort_lost() -> void:
	if _ambush_active and not ship.dead:
		ship._flash_note("GUARDIAN LOST — nothing is holding it. GO.")


## Keep a shadow escort wing aloft while the survive_event stage is live: launched
## from HOME toward the objective, it trails the players out and patrols the site
## out of sight. Respawned only if the whole wing is lost — pre-spring there is no
## beast, so it simply persists.
func _ensure_shadow_escort(objective: Vector2) -> void:
	_prune_shadow()
	if not _shadow_escorts.is_empty():
		return
	var out_dir := (objective - AIShip.station_pos).normalized()
	if out_dir == Vector2.ZERO:
		out_dir = Vector2.RIGHT
	var perp := out_dir.orthogonal()
	for i in 3:
		var spos: Vector2 = AIShip.station_pos + out_dir * (GuardianShip.MIN_R + 40.0) \
			+ perp * (float(i) - 1.0) * 160.0
		_shadow_escorts.append(GuardianShip.spawn_shadow_escort(self, spos, objective,
			SampleBuilds.guardian_kestrel()))


## The ambush sprang: the trailing wing breaks to engage the beast (doomed). If
## nothing was shadowing (edge case — teleport, instant spring), launch one from
## home now and commit it the same way.
func _commit_shadow_escort(objective: Vector2) -> void:
	_prune_shadow()
	if _shadow_escorts.is_empty():
		_ensure_shadow_escort(objective)
	for g in _shadow_escorts:
		if g == null or not is_instance_valid(g):
			continue
		g.shadow_escort = false
		g.escort_target = _ambusher
		g.died.connect(_on_escort_lost)
		_escorts.append(g)
	_shadow_escorts.clear()


func _prune_shadow() -> void:
	var live: Array[GuardianShip] = []
	for g in _shadow_escorts:
		if g != null and is_instance_valid(g) and not g.dead:
			live.append(g)
	_shadow_escorts = live


## Stage ended with no ambush (docked, abandoned): send the shadow wing home rather
## than leaving it loitering — never pop it out of existence.
func _stand_down_shadow() -> void:
	for g in _shadow_escorts:
		if g != null and is_instance_valid(g) and not g.dead:
			g.dismiss()
	_shadow_escorts.clear()


## survived = true when the player reached the light (or drove it off alive);
## false when they died to it (the stage waits for a retry).
func _end_ambush(survived: bool) -> void:
	_ambush_active = false
	if _ambusher != null and is_instance_valid(_ambusher):
		_ambusher.retreat()
	if _ambient_leviathan != null:
		_ambient_leviathan.set_suspended(false)
	for g in _escorts:
		if g != null and is_instance_valid(g) and not g.dead:
			g.dismiss()   # survivors peel off and run for home, not into nothing
	_escorts.clear()
	_stand_down_shadow()   # any wing that never committed goes home too
	if survived:
		Quests.note_survived(_ambush_quest)
		Sfx.play("jingle", -10.0, 0.7)


## Beat 6, the Rust Shoal: reaching a goto stage that carries a `dialogue`
## opens Krayt's comm in flight; closing it advances the stage.
var _goto_talk_active := false

func _tick_goto_dialogue() -> void:
	var site := Quests.goto_dialogue_site()
	# Safe passage: a truce beat (Krayt's parley) holds pirate fire on the player
	# for the whole approach + the comm, and lifts the moment the beat completes.
	# The Shoal's-fall set-piece owns parley while it runs — don't clobber it.
	# Safe passage ALSO covers the landing tutorial: a first-timer learning to put
	# a hull on a planet shouldn't be jumped on the way there. Pirates patrol the
	# outer lane, which sits right on the planet approach, so they hold off while
	# the dirtside milk run is active. (The crate itself is narrative — a crash
	# can't lose it — so the only real hazard to remove was being shot down.)
	AIShip.parley = _fall_active or Quests.active.has("dirtside_run") \
		or (not site.is_empty() and bool(site.get("truce", false)))
	if _goto_talk_active or ship.dead or ship.docked_at != null:
		return
	if site.is_empty():
		return
	# In-person beats (Krayt at the Shoal) are met by DOCKING, not a fly-by comm —
	# the Speak's Easy presents them; here we only chart + hold the truce.
	if bool(site.get("in_person", false)):
		return
	if ship.global_position.distance_to(site.pos) <= float(site.radius):
		_goto_talk_active = true
		var qid := str(site.quest)
		Comms.post(str(site.npc), Quests.quest_def(qid).get("title", "Transmission"),
			str(site.nodes.get("start", {}).get("text", "")))
		var panel := DialoguePanel.new(str(site.npc), site.nodes,
			func(_a: String) -> String: return "")
		panel.vo_prefix = qid   # goto-dialogue: <quest>_<node> (Krayt at the Shoal)
		panel.closed.connect(func() -> void:
			_goto_talk_active = false
			Quests.advance_goto_dialogue(qid)
			for note in Quests.take_notes():
				ship._flash_note(note))
		add_child(panel)


## THE LANDING BRIEF. Docking is taught by the tutorial at the moment you do it;
## setting down on a planet had nothing — you arrived and it was pass/fail with
## no one explaining the procedure. So the colony hails any pilot who has never
## landed, BEFORE gravity has them, and walks through it: why it's different
## (gravity is already pulling), the three things that matter (band, speed,
## attitude), the key, and the safety valve. Shown once, until they've landed.
const LANDING_BRIEF := {
	"start": {
		"text": "Imari's voice crackles onto the approach channel, unhurried. \"Inbound hull, this is the colony. First time setting one down? Then listen — a planet doesn't forgive the way a docking arm does.\n\nYou're in our gravity now. It is already pulling you down, and it will keep pulling whether you're ready or not. Your job isn't to fly INTO the ground — it's to SLOW THE FALL.\n\nThree things. Get into the landing band — that ring of clear air above the surface. Bleed your speed off until the readout reads green. And come down TOWARD the pad, not skimming across it; flat approaches bounce.\n\nWhen it reads green, press [E]. And if you're ever unsure — slow down more. Nobody ever bent a hull going too gently.\"",
		"choices": [{"text": "Understood, colony.", "next": "end", "style": "primary"}],
	},
}

var _taught_landing := false

func _tick_landing_brief() -> void:
	if _taught_landing or ship.dead or ship.docked_at != null:
		return
	if SaveGame.landing_taught or planetoid == null or not is_instance_valid(planetoid):
		return
	# Well outside the gravity well, so it lands while they can still act on it.
	if ship.global_position.distance_to(planetoid.global_position) > Planetoid.GRAV_R * 1.8:
		return
	_taught_landing = true
	Comms.post("imari", "Colony Approach",
		str(LANDING_BRIEF.get("start", {}).get("text", "")))
	var panel := DialoguePanel.new("imari", LANDING_BRIEF,
		func(_a: String) -> String: return "")
	panel.vo_prefix = "landing_brief"   # audio/vo/landing_brief_start.mp3
	add_child(panel)


## Chart lesson, delivered at the moment it's needed: the first time the pilot is
## actually IN FLIGHT on the dirtside run, Ruel calls to point them at [G]. A new
## player has no idea where the colony is, and hunting for it is the confusing
## part — not the flying. Fires once per launch of the run.
var _taught_chart := false

func _tick_chart_hint() -> void:
	if _taught_chart or ship.dead or ship.docked_at != null:
		return
	if not Quests.active.has("dirtside_run"):
		return
	_taught_chart = true
	var line := "\"Colony's already on your chart. Press [G] for the nav map, set it as your waypoint, and follow the diamond. The Reach is bigger than it looks.\""
	ship._flash_note("RUEL: %s" % line)
	Comms.post("ruel", "Dirtside Run", line)
	# Ruel SAYS it; the ping SHOWS it. The "chart" lesson arms itself off a set
	# waypoint via the declarative tutor and completes when they open the chart.
	Sfx.play("click", -10.0, 1.1)


# --- The Fall of the Rust Shoal (witness set-piece) --------------------------
# After the in-person meeting, once the player undocks near the Shoal, the dark
# takes it. Krayt burns out on a vector AWAY from the player and DRAWS the beast
# off — both far too fast to follow. A held breath later his final transmission
# comes through (the finale begins), and Vyper hails with the Shoal's grief and
# a banner of truce. PURE WITNESS: the beast never sees you, the guns hold, and
# nothing you can do saves him. See docs/campaign_starter_system.md.

const VYPER_TRUCE := {
	"start": {
		"text": "The channel opens on breathing — ragged, young, furious. \"...You were there. You watched it take him.\" A hard swallow. \"Name's Vyper. Krayt ran this rock before there was a before. He talked about the rim like a man talks about a door he's too scared to open. And he opened it. For us. So the rest of us could run.\"",
		"choices": [
			{"text": "He drew it off. On purpose.", "next": "grief"},
			{"text": "I couldn't reach him.", "next": "grief"},
		]},
	"grief": {
		"text": "\"He was a thief and a liar and he cheated at cards and at customs and probably at his own funeral.\" Her voice breaks and re-forms harder in the same breath. \"He... we aren't bad guys. Not the way the Board paints us. We're just what's left when the light goes out and nobody comes.\" A pause. \"You came. You honored the deal. That's worth something out here, where nothing is.\"",
		"choices": [
			{"text": "What's it worth?", "next": "truce", "style": "primary"},
		]},
	"truce": {
		"text": "\"Your life, hero. I'm putting your paint out to every gun in the Shoal: OFF LIMITS. Honor it — the grief, the respect, the banner he died under — and no raider of mine will ever burn you.\" Steel now, under the tears. \"Soak it in his blood instead, and I will shed yours to the last drop. That's the truce. Don't make me choose the other thing.\"",
		"choices": [
			{"text": "The Shoal has my word.", "next": "end", "style": "primary"},
		]},
}

var _fall_active := false
var _fall_done := false


## Fires ONCE: the meeting is done (rust_shoal complete), the finale hasn't
## begun, and the player has undocked and is still near the (about-to-fall)
## Shoal. Everything after runs in _run_shoal_fall().
func _tick_shoal_fall() -> void:
	if _fall_active or _fall_done:
		return
	if not Quests.completed.has("rust_shoal"):
		return
	if Quests.active.has("nothing_left_behind") or Quests.completed.has("nothing_left_behind"):
		return
	if ship.dead or ship.docked_at != null:
		return
	if ship.global_position.distance_to(PIRATE_DEN) > 2400.0:
		return
	_run_shoal_fall()


func _run_shoal_fall() -> void:
	_fall_active = true
	AIShip.parley = true   # the guns hold through the whole witness beat (see _tick_goto_dialogue)
	if _ambient_leviathan != null:
		_ambient_leviathan.set_suspended(true)   # never two beasts at once
	# Outward, toward the rim (away from the station's light) — the vector Krayt
	# and the beast both run once the chase is on.
	var flee: Vector2 = PIRATE_DEN - AIShip.station_pos
	flee = flee.normalized() if flee.length() > 1.0 else Vector2.RIGHT

	# --- Phase 1: Krayt FORMS UP on your wing and holds. He's a companion beside
	# you, not a missile fired off the Shoal — that read was the confusion.
	var krayt := FleeingShip.new()
	krayt.use_variant_skin = true
	krayt.enemy_group = "leviathan"   # his guns bite the beast (to draw its ire)
	add_child(krayt)
	krayt.apply_build(SampleBuilds.pirate_vulture())
	krayt.set_hull_tint(Color(0.92, 0.74, 0.5))
	krayt.global_position = ship.global_position + Vector2.RIGHT.rotated(ship.rotation + PI / 2.0) * 130.0
	krayt.rotation = flee.angle()   # facing the rim, formed up (flee_vel stays 0 = holds)
	Sfx.play_voice("krayt_formup", -3.0)
	ship._flash_note("KRAYT forms up on your wing — \"Lead me to the rim.\"")
	await get_tree().create_timer(3.6).timeout
	if not _fall_ok():
		_fall_active = false
		return

	# --- Phase 2: the dark takes the Shoal and the beast comes for you BOTH,
	# looming in from behind the pair. (Pure witness: it can't actually bite.)
	Sfx.play("dread", -1.0)
	if shoal != null and is_instance_valid(shoal):
		shoal.go_dark()
	ship._flash_note("THE LIGHTS OF THE RUST SHOAL GO OUT.")
	var beast := Cinderweb.spawn_pursuit(self, ship.global_position - flee * 900.0, Vector2.ZERO, 0.0)
	Telemetry.note("beast", "Shoal's Fall — pursuit Cinderweb spawned ✓")
	beast.drive(flee, 340.0)   # looms in slowly, toward you and Krayt
	if is_instance_valid(krayt):
		krayt.harass = beast   # Krayt wheels around and pours fire into it — drawing its ire onto HIM
	ship._flash_note("SOMETHING VAST UNCOILS FROM THE DARK — KRAYT OPENS FIRE ON IT.")
	await get_tree().create_timer(2.3).timeout
	if not _fall_ok():
		_fall_active = false
		return

	# --- Phase 3: Krayt DRAWS IT OFF. He lights the engines and runs for the
	# rim; the beast abandons you and tears after the runner, too fast to follow.
	if is_instance_valid(krayt):
		krayt.launch(flee, 1000.0)
	Sfx.play_voice("krayt_draws_off", -2.0)
	Comms.post("krayt", "The Rust Shoal",
		"\"It followed me out. It sees me — GOOD. It wants the runner, not the cover. Get to the rim, hero. GO!\"")
	ship._flash_note("KRAYT breaks away, drawing it off — \"It wants the runner. GET TO THE RIM!\"")
	if is_instance_valid(beast):
		beast.chase(krayt, 950.0)   # aggro: it HOUNDS Krayt, not a parallel run beside him

	# --- Phase 4: a short breath in the dark, then the last transmission (never
	# while docked or dead — the beat has to land in the black).
	await get_tree().create_timer(13.5).timeout
	while is_inside_tree() and (ship.docked_at != null or ship.dead):
		await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	_present_krayt_final()


## True while the set-piece can safely proceed (scene alive, player not lost to
## death mid-beat — a death just pauses it; see the wait loop above).
func _fall_ok() -> bool:
	return is_inside_tree() and not ship.dead


## HOW FAR THE STATIC OVERLAPS KRAYT'S FINAL LINE (seconds). The static crashes
## over the LAST this-many seconds of his VO, so it sounds like his ship coming
## apart mid-word. Tune to taste:
##   bigger  = static cuts in EARLIER, swallowing more of his last words
##   smaller = static waits LONGER, clipping only the very end
##   0.0     = static begins exactly as his line ends (back-to-back, no overlap)
## If there's no VO clip, STATIC_NO_VO_DELAY is used instead (a beat behind the text).
const STATIC_OVERLAP := 0.2
const STATIC_NO_VO_DELAY := 1.3

## Krayt's final transmission — delivered IN FLIGHT, in the dark, not as a dry
## dock briefing. Closing it BEGINS the finale (charts the gate), then Vyper.
func _present_krayt_final() -> void:
	var text: String = str(Quests.quest_def("nothing_left_behind").get("briefing", ""))
	var nodes := {"start": {
		"text": text, "vo": "nothing_left_behind_briefing",
		"choices": [{"text": "Krayt—", "next": "end", "style": "primary"}]}}
	Comms.post("krayt", "Final Transmission", text)
	var panel := DialoguePanel.new("krayt", nodes, func(_a: String) -> String: return "")
	# The channel dies WHILE he speaks, not after: bring the static up over the last
	# ~0.5s of his line so it sounds like his ship coming apart mid-word, the
	# "...don't let this be for—" cut off. A boxed flag makes it fire exactly once —
	# whichever comes first, the timed overlap or the player skipping ahead (which
	# plays it on close so the crash is never lost).
	var static_done := [false]
	var crash := func() -> void:
		if not static_done[0]:
			static_done[0] = true
			Sfx.play("static", -3.0)
	panel.closed.connect(func() -> void:
		crash.call()
		Quests.begin_manual("nothing_left_behind")
		for note in Quests.take_notes():
			ship._flash_note(note)
		_present_vyper_truce())
	add_child(panel)
	# add_child ran the panel's _ready, so his VO is already playing — time the
	# static to overlap its tail (or fall a beat behind the text if there's no clip).
	var vlen := Sfx.voice_length()
	var lead: float = maxf(vlen - STATIC_OVERLAP, 0.0) if vlen > 0.0 else STATIC_NO_VO_DELAY
	await get_tree().create_timer(lead).timeout
	if is_instance_valid(panel) and panel.is_inside_tree():
		crash.call()


## Vyper's grief and her banner of truce — the heal on the ending, on the heels
## of Krayt's death. Closing it makes the Shoal's peace permanent.
func _present_vyper_truce() -> void:
	Comms.post("vyper", "Rust Shoal", str(VYPER_TRUCE.get("start", {}).get("text", "")))
	var panel := DialoguePanel.new("vyper", VYPER_TRUCE, func(_a: String) -> String: return "")
	panel.vo_prefix = "vyper_truce"   # nodes speak audio/vo/vyper_truce_<node> (start/grief/truce)
	panel.closed.connect(_apply_vyper_truce)
	add_child(panel)


func _apply_vyper_truce() -> void:
	Standing.add("privateer", 20)     # the Shoal honors the banner he died under
	Pilot.shoal_invited = true        # stays open — Vyper's word now, not just Krayt's
	AIShip.parley = false             # the truce is carried by standing/shoal_open, not the beat flag
	if _ambient_leviathan != null:
		_ambient_leviathan.set_suspended(false)
	_fall_done = true
	_fall_active = false
	ship._flash_note("THE RUST SHOAL HOLDS ITS FIRE. Vyper's banner is yours.")


## Beat 7, the waygate: charted by the finale, it appears at the rim. Flying
## into its throat leaves the Cinder Reach — the demo's end.
var _waygate: WayGate
var _left_system := false
var _gate_console: GateConsole
var _gate_prompted := false
var _traversing := false
var _dev_gate := false          # a dev-summoned gate ([;]); drives the full flow too

func _tick_gate() -> void:
	if _left_system:
		return
	# The finale charts the gate; a dev summon ([;]) stands one in with no quest.
	var site := Quests.gate_site()
	var pos: Vector2
	var quest_id := ""
	if not site.is_empty():
		pos = site.pos
		quest_id = str(site.quest)
	elif _dev_gate and _waygate != null and is_instance_valid(_waygate):
		pos = _waygate.position
	else:
		return
	if _waygate == null or not is_instance_valid(_waygate):
		_waygate = WayGate.create(pos)
		add_child(_waygate)
	if ship.dead or ship.docked_at != null or _traversing:
		return
	var d := ship.global_position.distance_to(pos)
	if _waygate.is_open():
		# The ring is a doorway now — fly into the throat to leave the Reach.
		if d < 190.0:
			_traverse_gate(quest_id)
	elif _waygate.phase == WayGate.Phase.CLOSED and _gate_console == null:
		# Dormant: nudge the pilot to use it, once per approach.
		if d < 460.0 and not _gate_prompted:
			_gate_prompted = true
			ship._flash_note("THE WAYGATE IS DORMANT — press [E] to use it")
		elif d >= 460.0:
			_gate_prompted = false


## Open the alien console. Freeze the pilot so they don't drift off the ring while
## entering the code; control returns when the console closes (see _on_gate_console_closed).
func _open_gate_console() -> void:
	if _gate_console != null:
		return
	_gate_console = GateConsole.new()
	_gate_console.entered.connect(func() -> void: _waygate.begin_opening())
	_gate_console.tree_exited.connect(_on_gate_console_closed)
	ship.set_physics_process(false)
	add_child(_gate_console)


func _on_gate_console_closed() -> void:
	_gate_console = null
	if not ship.dead and not _traversing:
		ship.set_physics_process(true)   # watch the ring wake, then fly in


## Fly into the open ring: the ship shrinks and dims toward the throat so it reads
## as flying off into distant space. The camera is unpinned from the hull first, so
## it holds on the gate instead of zooming with the shrinking ship.
func _traverse_gate(quest_id: String) -> void:
	if _traversing:
		return
	_traversing = true
	_left_system = true
	if quest_id != "":
		Quests.note_gate_reached(quest_id)   # (dev-summoned gate has no quest to advance)
	ship.set_physics_process(false)
	Sfx.play("jingle", -6.0, 0.6)
	var cam := ship.get_node_or_null("Camera") as Camera2D
	if cam != null:
		var gpos := cam.global_position
		cam.reparent(self)
		cam.global_position = gpos
		cam.position_smoothing_enabled = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ship, "global_position", _waygate.position, 1.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ship, "scale", Vector2.ONE * 0.02, 1.9).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(ship, "modulate:a", 0.0, 1.9).set_ease(Tween.EASE_IN)
	await tw.finished
	_enter_gate()


func _enter_gate() -> void:
	ship.visible = false
	ship.set_physics_process(false)
	Sfx.play("jingle", -6.0, 0.6)
	# The send-off owns what happens next: HOLD to return home to the main menu
	# (it change_scenes there). No respawn into flight — the demo is over.
	var screen := ThankYou.new()
	screen.pilot_line = "Flown by %s" % Pilot.full_name()
	add_child(screen)


## Pirates raid the OUTER trade lane (LANE_B / the planet approach), NOT the
## station side — the inner system stays safe for new pilots learning to fly,
## and danger grows the farther from home you get. They still HOME to the far
## den and fly the long leg in, so travel time paces the threat. The Vulture
## sweeps the far dark and only grazes civilized space.
func _patrol_route(kind: String) -> Array[Vector2]:
	match kind:
		"wasp":
			return [PIRATE_DEN + _jitter(400.0), LANE_B + _jitter(700.0)]
		"vulture":
			return [VULTURE_HAUNT + _jitter(400.0), Vector2(9200, 1200) + _jitter(600.0),
				Vector2(12400, 4200) + _jitter(600.0)]
		_:
			return [PIRATE_DEN + _jitter(400.0), LANE_B + _jitter(500.0),
				Vector2(7600, 4600) + _jitter(500.0)]


func _jitter(radius: float) -> Vector2:
	return Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, radius)


## Practice drones belong to the station's training range, not to the player.
func _drone_spot() -> Vector2:
	return station.position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(550.0, 950.0)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	# COMMS LINE. ENTER talks, SLASH opens already holding the slash — the two
	# habits every chat window in the genre trains. ESC backs out without
	# sending. Checked FIRST so a keystroke meant for the message can never
	# also trigger a cockpit binding.
	if hud != null and hud.comm != null:
		if Chat.typing:
			if event.keycode == KEY_ESCAPE:
				hud.comm.close()
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			hud.comm.open()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_SLASH:
			hud.comm.open("/")
			get_viewport().set_input_as_handled()
			return
	# Dev cheats now live in the COMM TERMINAL as slash commands (Enter, then type
	# /cash, /warp, /gate…) — see _run_dev_command. The hook is registered only in
	# a debug build, so release exports can never reach them. They moved off the
	# keyboard so a stray keypress can't fire one and so there's ONE dev gate, not
	# five scattered is_debug_build() key checks.
	match event.keycode:
		KEY_F1:
			get_tree().change_scene_to_file("res://scenes/debug/assembly_viewer.tscn")
		KEY_F12:
			_save_screenshot()
		KEY_E:
			_handle_interact()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			# Boarding happens at the station: docked only, owned ships only.
			var index: int = event.keycode - KEY_1
			if not ship.dead and ship.docked_at is DockingPad \
					and SampleBuilds.owned.has(index) and index != SampleBuilds.current:
				SampleBuilds.current = index
				ship.apply_build(SampleBuilds.get_build(index))
				station_screen.refresh()


## DEV COMMANDS — the old dev keys, now typed into the comm terminal (Enter, then
## e.g. "/cash 5000"). Registered on Chat ONLY in a debug build (see _ready), so
## release exports can never reach this. Returns true if the command was handled;
## a false return lets Chat print "unknown command". Feedback goes to BOTH the
## ship note (read in flight) and the terminal log (read where you typed it).
func _run_dev_command(cmd: String, rest: String) -> bool:
	match cmd:
		"cash", "c", "money":
			var amt := int(rest) if rest.is_valid_int() else 10000
			Wallet.credits += amt
			_dev_feedback("+%s credits (now %s)" % [amt, Wallet.credits])
			get_tree().call_group("dock_screens", "refresh")
			return true
		"insight", "in":
			var amt := int(rest) if rest.is_valid_int() else 100
			Research.insight += float(amt)
			_dev_feedback("+%s Insight (now %s)" % [amt, int(Research.insight)])
			get_tree().call_group("dock_screens", "refresh")
			return true
		"xp":
			var amt := int(rest) if rest.is_valid_int() else 100
			Wallet.xp += amt
			_dev_feedback("+%s XP (now %s)" % [amt, Wallet.xp])
			get_tree().call_group("dock_screens", "refresh")
			return true
		"warp":
			return _dev_warp(rest)
		"gate":
			_dev_summon_gate()
			return true
		"ruler":
			_range_ruler.visible = not _range_ruler.visible
			_dev_feedback("Range ruler %s" % ("ON" if _range_ruler.visible else "off"))
			return true
		"heartbeat", "vitals":
			if _dev_vitals != null:
				_dev_vitals.visible = not _dev_vitals.visible
				_dev_feedback("Heartbeat %s" % ("ON" if _dev_vitals.visible else "off"))
			return true
		"rearm", "tutorials":
			_dev_rearm_tutorials()
			return true
	return false


## Dev feedback goes two places on purpose: the flash note is seen in flight, the
## terminal notice is seen in the log you just typed into (they don't overlap).
func _dev_feedback(msg: String) -> void:
	ship._flash_note("%s [dev]" % msg)
	Chat.notice("[dev] " + msg)


## /warp <x> <y>  ·  /warp <x>,<y>  ·  /warp <poi>  — teleport the ship. Orivel is
## a ~100k-unit haul on thrusters; this drops you on a landmark (or raw coords) so
## the capital/gate flows are testable in seconds, not minutes of holding W.
func _dev_warp(rest: String) -> bool:
	var arg := rest.strip_edges()
	if arg.is_empty():
		_dev_feedback("warp where? /warp <x> <y>  or  /warp <poi>")
		return true
	var parts := arg.replace(",", " ").split(" ", false)
	# A single non-numeric token = a POI id or name fragment (e.g. /warp orivel).
	if parts.size() == 1 and not parts[0].is_valid_float():
		var q := parts[0].to_lower()
		for p in PoiMap.pois:
			if str(p.id).to_lower() == q or str(p.name).to_lower().contains(q):
				var arrival := _safe_arrival(p.pos)
				_warp_to(arrival, p.pos)
				PoiMap.discover(str(p.id))
				var off := "  (safe standoff)" if arrival != p.pos else ""
				_dev_feedback("Warped to %s%s" % [str(p.name), off])
				return true
		_dev_feedback("no POI matching \"%s\"" % parts[0])
		return true
	if parts.size() < 2 or not parts[0].is_valid_float() or not parts[1].is_valid_float():
		_dev_feedback("warp needs two numbers: /warp <x> <y>")
		return true
	var dest := Vector2(parts[0].to_float(), parts[1].to_float())
	var arr := _safe_arrival(dest)
	_warp_to(arr, dest if arr != dest else Vector2.INF)
	var note := "  (stood off a body)" if arr != dest else ""
	_dev_feedback("Warped to (%s, %s)%s" % [int(arr.x), int(arr.y), note])
	return true


## Nudge a warp destination so we never materialise inside a gravity well (Orivel
## would crush you) or on top of a station. Returns the target UNCHANGED if it's
## already clear. Approaches from the ship's current side, so paired with a
## face-target you arrive looking AT the body.
func _safe_arrival(target: Vector2) -> Vector2:
	var from := ship.global_position
	for g in ["planetoids", "outposts", "structures"]:
		for node in get_tree().get_nodes_in_group(g):
			if not (node is Node2D):
				continue
			var keep := 900.0
			var gr: Variant = node.get("grav_r")
			var ar: Variant = node.get("avoid_radius")
			if gr != null:
				keep = float(gr) + 900.0
			elif ar != null:
				keep = float(ar) + 500.0
			var center: Vector2 = (node as Node2D).global_position
			if target.distance_to(center) < keep:
				var dir := from - center
				if dir.length() < 1.0:
					dir = Vector2.RIGHT
				return center + dir.normalized() * keep
	return target


func _warp_to(pos: Vector2, face_target := Vector2.INF) -> void:
	ship.global_position = pos
	ship.velocity = Vector2.ZERO
	if face_target != Vector2.INF and face_target.distance_to(pos) > 1.0:
		ship.rotation = (face_target - pos).angle()


func _dev_summon_gate() -> void:
	if _waygate == null or not is_instance_valid(_waygate):
		_dev_gate = true
		_waygate = WayGate.create(ship.global_position
			+ Vector2.RIGHT.rotated(ship.rotation) * 700.0)
		add_child(_waygate)
		_dev_feedback("WayGate summoned ahead — fly to it, press [E]")
	else:
		_dev_feedback("WayGate already present")


## Re-arm the approach tutorials + every Tutor lesson WITHOUT wiping the save, so
## the docking/landing teaching can be replayed in place (a lesson is once-ever).
func _dev_rearm_tutorials() -> void:
	SaveGame.docking_taught = false
	SaveGame.landing_taught = false
	SaveGame.crash_taught = false
	SaveGame.crater_taught = false
	_taught_landing = false          # the in-session latch, or it won't re-fire
	_taught_chart = false
	ship.approach_fault = ""
	Tutor.seen.clear()
	Tutor.pending.clear()
	Tutor.active = ""
	Tutor.step = 0
	_dev_feedback("Tutorials + tutor lessons re-armed")


func _handle_interact() -> void:
	# While the launch window is up it owns [E]/[Q] — don't re-trigger from here.
	if _launch_window != null and is_instance_valid(_launch_window):
		return
	if ship.dead:
		get_tree().reload_current_scene()
	elif ship.docked_at != null:
		# Power/fit problems keep you grounded — the hard constraint.
		if ShipStats.validate(ship.build).is_empty():
			_open_launch_window()
		elif ship.docked_at == shoal.pad:
			shoal_screen.refresh()
		elif ship.docked_at == diggs.pad:
			diggs_screen.refresh()
		elif _outpost != null and _outpost.pads.has(ship.docked_at):
			orivel_screen.refresh()
		elif ship.docked_at is Planetoid:
			planet_screen.refresh()
		else:
			station_screen.refresh()
	elif _waygate != null and is_instance_valid(_waygate) \
			and _waygate.phase == WayGate.Phase.CLOSED and _gate_console == null \
			and ship.global_position.distance_to(_waygate.position) < 460.0:
		_open_gate_console()          # feed the ring the waking sequence Krayt sent
	elif station.pad.status_for(ship).in_range:
		station.pad.try_dock(ship)
	elif shoal.pad.status_for(ship).in_range:
		shoal.pad.try_dock(ship)
	elif diggs.pad.status_for(ship).in_range:
		diggs.pad.try_dock(ship)
	elif planetoid.status_for(ship).in_band:
		planetoid.try_land(ship)
	elif _outpost != null:
		# The capital ring's 8 berths — dock whichever the pilot is lined up on.
		for pad in _outpost.pads:
			if pad.status_for(ship).in_range:
				pad.try_dock(ship)
				break


## EVERY launch is a deliberate act: a countdown + your hold at risk, station or
## planet alike. [E] launches now, [Q]/[Esc] aborts, zero launches. No pilot gets
## to say they weren't warned about what the dark can take.
func _open_launch_window() -> void:
	if _launch_window != null and is_instance_valid(_launch_window):
		return
	# The countdown is about to exist for four seconds — offer the scrub lesson
	# NOW or not at all (queue = false), so its copy can never appear after the
	# window it describes has closed.
	Tutor.arm("launch", false)
	_launch_window = LaunchWindow.new(ship)
	_launch_window.launched.connect(func() -> void:
		_launch_window = null
		ship.undock())
	_launch_window.aborted.connect(func() -> void:
		_launch_window = null)
	add_child(_launch_window)


func _spawn_drone(pos: Vector2) -> void:
	var drone := TargetDrone.new()
	drone.position = pos
	drone.destroyed.connect(_respawn_drone_later)
	# Any drone counts for the license test — players can't tell them apart.
	drone.destroyed.connect(func() -> void:
		var tut := get_tree().get_first_node_in_group("tutorial")
		if tut != null:
			tut._on_drone_killed())
	add_child(drone)


func _respawn_drone_later() -> void:
	await get_tree().create_timer(4.0).timeout
	if is_inside_tree():
		_spawn_drone(_drone_spot())


## The harbor guard: a tight blue ring around the station, white stripe on
## the right wing. Kestrels inner, Sparrowhawks middle, the Vulture outermost
## — all leashed inside GuardianShip.PERIMETER, always.
## HALVED 2026-07-22 (7 -> 4). Pirates already leave you alone inside the
## sanctuary while you learn, so a seven-ship wing was crowding the one piece of
## sky the player spends their first hour in — and seven hulls orbiting the same
## station is most of what made the harbour look like a demolition derby. One of
## each class keeps the silhouette lesson (light / medium / heavy) intact.
const GUARD_WING := ["kestrel", "kestrel", "sparrowhawk", "vulture"]


func _spawn_guard_wing() -> void:
	for i in GUARD_WING.size():
		_spawn_guardian(GUARD_WING[i], i)


func _spawn_guardian(kind: String, i: int) -> void:
	var g := GuardianShip.new()
	# Rings live in the 700-1500 patrol band; the Vulture takes the rim.
	var ring := 780.0 + 190.0 * float(i % 3)
	if kind == "vulture":
		ring = 1360.0
	g.position = station.position + Vector2.RIGHT.rotated(TAU * float(i) / GUARD_WING.size()) * ring
	add_child(g)
	match kind:
		"sparrowhawk":
			g.setup_guard(SampleBuilds.guardian_sparrowhawk(), ring)
		"vulture":
			g.setup_guard(SampleBuilds.guardian_vulture(), ring)
		_:
			g.setup_guard(SampleBuilds.guardian_kestrel(), ring)
	g.died.connect(_respawn_guardian_later.bind(kind, i))


## The harbor replaces its losses — launched from the station, like all
## living-world replacements come from home.
func _respawn_guardian_later(kind: String, i: int) -> void:
	await get_tree().create_timer(30.0).timeout
	if is_inside_tree():
		_spawn_guardian(kind, i)


func _spawn_pirate(pos: Vector2, kind: String, route: Array[Vector2] = []) -> void:
	var pirate := AIShip.new()
	pirate.position = pos
	add_child(pirate)
	pirate.patrol_points = route
	match kind:
		"brawler":
			pirate.setup(SampleBuilds.pirate_brawler(), AIShip.Tactic.BOOM_ZOOM)
		"wasp":
			pirate.setup(SampleBuilds.pirate_wasp(), AIShip.Tactic.ORBIT, Color(0.95, 0.62, 0.3))
			pirate.preferred_range = 120.0   # wasps knife-fight
		"vulture":
			# Variant skins are already pirate-colored; only a light menace tint.
			pirate.setup(SampleBuilds.pirate_vulture(), AIShip.Tactic.ORBIT, Color(0.95, 0.8, 0.8))
		_:
			pirate.setup(SampleBuilds.pirate_raider(), AIShip.Tactic.ORBIT)
	pirate.died.connect(_grant_kill_xp.bind(pirate, kind))
	pirate.died.connect(_respawn_pirate_later.bind(kind))


## Kill XP by archetype — the seed the leveling system will grow from.
const KILL_XP := {"wasp": 8, "raider": 10, "brawler": 14, "vulture": 40}


## Only the player's own kills pay out: guardians and pirates gunning each
## other down (or a pirate lost to an asteroid) credit nobody. `ship` is still
## valid here — died.emit() fires before the wreck frees itself.
func _grant_kill_xp(pirate: Node, kind: String) -> void:
	if not is_instance_valid(pirate) or not pirate.killed_by_player():
		return
	MissionLog.note_kill()           # a bounty tally is the player's contract
	var xp := int(round(float(KILL_XP.get(kind, 10)) * Pilot.kill_xp_mult()))
	Wallet.xp += xp
	Standing.add("guardian", 1)     # kills are the Guardian verb (Ruel's watching)
	Standing.add("privateer", -1)   # ...and the Shoal remembers who guns down their own
	if not ship.dead:
		ship._flash_note("+%d XP" % xp)
	# Vyper's truce is a PROMISE, not immunity (user, 2026-07-23 — "kill ten and
	# it's: No truce. That was her promise."). Gun down enough of the Shoal's own
	# under their own banner and they revoke it — you become prey again. This also
	# closes the exploit of farming pirates who won't fire back while the truce holds.
	if Pilot.shoal_invited:
		Pilot.shoal_truce_kills += 1
		if Pilot.shoal_truce_kills >= SHOAL_TRUCE_BREAK:
			_break_shoal_truce()


## Vyper revokes the banner. Breaking Krayt's OWN truce is the one true betrayal,
## so it isn't a slap — it SPIKES privateer standing straight to the floor (-100,
## KoS with the Shoal) in a single stroke. shoal_invited flips off, which both makes
## Standing.shoal_open() false (the Shoal hunts again) AND disarms the counter in
## _grant_kill_xp, so the spike can only ever land ONCE.
func _break_shoal_truce() -> void:
	Pilot.shoal_invited = false
	# Land exactly at -100 no matter the current standing (add() clamps to MIN).
	Standing.add("privateer", -100 - Standing.get_points("privateer"))
	var line := "Vyper's voice comes back, and every trace of the grief is gone from it. "
	line += "\"You spilled our blood under our OWN banner. That was Krayt's name you fouled "
	line += "— his memory, his last promise. It's void. There's no truce. Fly careful now, "
	line += "pilot. We remember faces.\""
	Comms.post("vyper", "Rust Shoal", line)
	if not ship.dead:
		ship._flash_note("TRUCE BROKEN — the Rust Shoal hunts you now")
	Sfx.play("static", -8.0)


func _respawn_pirate_later(kind: String) -> void:
	# Replacements launch from HOME and fly their route in — the world refills
	# from places, never around the player. Travel time is the pacing.
	await get_tree().create_timer(40.0 if kind == "vulture" else 15.0).timeout
	if is_inside_tree():
		var route := _patrol_route(kind)
		_spawn_pirate(route[0] + _jitter(300.0), kind, route)


## Neutral Trader-guild hauler on a lane route. Phase 1: it just flies and can
## be hailed. Phase 2 wires piracy (flip hostile, drop plunder, standing hits).
func _spawn_trader(pos: Vector2, route: Array[Vector2]) -> void:
	var trader := TraderShip.new()
	trader.position = pos
	add_child(trader)
	trader.patrol_points = route
	trader.setup_trader(SampleBuilds.trader_mule())
	trader.died.connect(_respawn_trader_later.bind(route))


func _respawn_trader_later(route: Array[Vector2]) -> void:
	await get_tree().create_timer(25.0).timeout
	if is_inside_tree() and not route.is_empty():
		_spawn_trader(route[0] + _jitter(400.0), route)


## A lone Guardian patrolling a trade lane. Killed or devoured, the Board sends
## another from home — the patrol never truly stops.
func _spawn_lane_guardian(pos: Vector2, route: Array[Vector2]) -> void:
	var g := GuardianShip.spawn_lane_patrol(self, pos, SampleBuilds.guardian_sparrowhawk(), route)
	g.died.connect(_respawn_lane_guardian_later.bind(route))


func _respawn_lane_guardian_later(route: Array[Vector2]) -> void:
	await get_tree().create_timer(35.0).timeout
	if is_inside_tree() and not route.is_empty():
		_spawn_lane_guardian(route[0] + _jitter(400.0), route)


## F12: dump the frame to bleakflame/screenshots/ for UI review.
func _save_screenshot() -> void:
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/shot_%d.png" % [dir, Time.get_ticks_msec()]
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved: ", path)
