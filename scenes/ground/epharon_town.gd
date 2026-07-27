extends Node2D
## Epharon ground-mode MVP — "film noir Tatooine". A walkable frontier colony that
## REPLACES the planet dock menu with a place: click-to-move, dusk-noir grade, NPC
## routines, your ship parked diegetically on the pad, a navigation spire, a heat
## boundary you can't cross, and the hermit's hut as the one true interior (our small
## first test of the enterable-building path). Buildings are placeholder geometry —
## drop-in PixelLab art layers over them later, same as the WayGate/anomaly seams.
##
## Run standalone:
##   <godot> --path . res://scenes/ground/epharon_town.tscn
## Wiring: flight_test hosts this in a SubViewport overlay, shows it when the ship docks
## at Epharon (the descent from space is UNCHANGED — only what touchdown raises), and
## calls enter_town() to reset you onto the pad. Launching emits launch_requested, which
## flight_test answers with the normal ship.undock() (pops you back above the planet).

signal launch_requested

const HEAT_LIMIT := 3300.0            # ~5 screen-widths from town center before the sun turns you back
const CENTER := Vector2.ZERO

## ---- THE LANDING APRON (user, 2026-07-25) ----
## Your ACTUAL ship, parked south of town, rendered from the hull you're flying — so
## boarding the Dowager changes what's sitting on the pad. The apron is deliberately
## sized for a SUPER_HEAVY even while a starter Rooster sits on it: this is the colony's
## only berth, and it should look like it could take the big hull that doesn't exist yet
## rather than being resized later (user: "room enough for a super heavy").
## Far enough south that the apron clears the Starport's base (the building spans to
## y=1100) instead of the hull appearing to park in its doorway.
const PAD_CENTER := Vector2(0, 1580)
const PAD_SIZE := Vector2(1180, 800)
## HOW BIG A PARKED HULL DRAWS, by size band, in world units of length.
##
## NOT derived from the flight sizes (HullDef.world_budget), and that is deliberate: in
## space a Light is 32 units and a Super-Heavy 256 — an 8x spread that is legible at
## flight distances but useless here, where the SMALL end has to stand beside a ~68-unit
## person and the BIG end has to fit a berth. On foot the interesting comparison is
## ship-to-PERSON, so these are authored for that: a starter Rooster reads as roughly
## five people long — a real vehicle you could climb into — and the ladder above it
## grows on a gentler curve so the largest hull still lands inside PAD_SIZE.
const GROUND_SHIP_W := {
	HullDef.SizeBand.LIGHT: 300.0,
	HullDef.SizeBand.MEDIUM: 450.0,
	HullDef.SizeBand.HEAVY: 640.0,
	HullDef.SizeBand.SUPER_HEAVY: 900.0,
	HullDef.SizeBand.SUPER_HEAVY_PLUS: 1040.0,
}
const IROOM := Vector2(12000.0, 0.0)  # interiors live far off the town grid; camera hides the gap
const IROOM_HALF := Vector2(430.0, 330.0)   # default room half-extent (a def may override)

## ENTERABLE BUILDINGS — one room each, data-driven (the cave proved the pattern; the plan
## has always been ALL buildings enterable, added room by room). A def gives the room its
## size, its door (where you re-emerge), its flash line, its title bar, and its SPOTS.
## `actor` names who is found inside: "hermit" = the dedicated cave actor, otherwise a
## town NPC by name — they step in with you (visibility swap) and step back out after.
const INTERIORS := {
	"?": {
		"half": Vector2(430.0, 330.0),
		"exit_pos": Vector2(2100, -1720),
		"flash": "You duck into the low mouth of the cave...",
		"title": "THE COUNTER'S CAVE   ·   [Esc] leave",
		"actor": "hermit",
		"actor_pos": Vector2(0, -160),
		"actor_spot": {"npc": "Counter", "prompt": "[E] Speak with the Counter", "action": "idle:hermit"},
		"exit_prompt": "[E] Leave the cave",
		# THE WRECKED STATE (Campaign beat 2). Swapped in ONLY while the beat is live, so
		# the world carries the story's damage exactly as long as the story does — see
		# _cave_wrecked(). The hermit is absent, scrit are sifting the remains, and the
		# scene is still warm: smoke that has not settled, ozone, and blaster scoring
		# grouped where a man would be.
		"wrecked": {
			"flash": "The cave mouth is scorched black. Inside: smoke still hanging flat in the cold, the stink of ozone, and something moving in the dark.",
			"title": "THE COUNTER'S CAVE   ·   WRECKED   ·   [Esc] leave",
		},
	},
	# THE EXPLORER'S UNION — Sella's map room, the seed of the Scout guild. Unlike Tam and
	# Bram (dedicated residents), Sella is a TOWN NPC: entering her Union finds her at the
	# chart wall (she steps in with you), and she returns to her wander when you leave.
	# Her survey POSTINGS live here now — walk in to read the board.
	"EXPLORERS GUILD": {
		"half": Vector2(410.0, 300.0),
		"exit_pos": Vector2(-800, -60),
		"flash": "Paper. Actual paper — charts on every wall, and half of them are holes.",
		"title": "THE EXPLORER'S UNION   ·   [Esc] leave",
		"actor": "Sella",
		"actor_pos": Vector2(-40, -150),
		"actor_spot": {"npc": "Sella", "prompt": "[E] Speak with Sella", "action": "idle:sella"},
		"exit_prompt": "[E] Back out to the street",
		"extra_spots": [
			# "TAKE", not "READ" (user, 2026-07-26: "it isn't obvious that you can use
			# the board in Sella's room and pick up missions"). The hotspot always
			# worked; the verb described LORE. Next to a chart wall that genuinely is
			# flavour, "read the postings" reads as more of the same, so a player walks
			# past a contract board. The prompt now names the transaction.
			{"pos": Vector2(230, -140), "range": 130,
				"prompt": "[E] Take survey work from Sella's board",
				"action": "board:sella"},
			{"pos": Vector2(-280, -150), "range": 140,
				"prompt": "[E] Study the chart wall",
				"action": "flavor:The Reach, in pencil and pins. Whole sectors are blank paper with a question mark — Sella pays for anything that fills one in."},
		],
	},
	# SELLA'S FARM (user, 2026-07-25: the aquaponics BELONGS to Sella — but she's not the
	# one standing in it; she's buried in charts at the Union. TAM, her farmhand, runs the
	# place day to day). The one thing alive for a thousand miles — fish tanks under
	# grow-racks, warm damp air on a desert rock.
	# THE COLONY MARKET (user, 2026-07-25: a location you ENTER, run by its own trader).
	# Bram keeps the floor; walking up to HIM is how you trade — the shop counter is a
	# person, not a menu. Imari stays the colony's Elder (quests/turn-ins), not its shopkeep.
	"MARKET": {
		"half": Vector2(420.0, 300.0),
		"exit_pos": Vector2(560, 470),
		"flash": "Crates, coolers and net-slung produce under one roof — everything the colony hauls, buys or barters.",
		"title": "COLONY MARKET   ·   [Esc] leave",
		"actor": "trader",
		"actor_pos": Vector2(60, -140),
		"actor_spot": {"npc": "Bram", "prompt": "[E] Trade with Bram", "action": "shop:bram"},
		"exit_prompt": "[E] Back out to the square",
		"extra_spots": [
			{"pos": Vector2(-230, -120), "range": 130,
				"prompt": "[E] Poke through the crates",
				"action": "flavor:Circuits stenciled STATION-SIDE, sacks of grown grain, a cooler of silverfin on ice. The route, sitting on shelves."},
		],
	},
	"AQUAPONICS": {
		"half": Vector2(390.0, 300.0),
		"exit_pos": Vector2(-560, -290),
		"flash": "Warm damp air, green light, the hum of pumps — the only growing thing on the rock.",
		"title": "SELLA'S AQUAPONICS FARM   ·   [Esc] leave",
		"actor": "farmhand",
		"actor_pos": Vector2(90, -120),
		"actor_spot": {"npc": "Tam", "prompt": "[E] Speak with Tam", "action": "idle:tam"},
		"exit_prompt": "[E] Step back into the heat",
		"extra_spots": [
			{"pos": Vector2(-190, -150), "range": 130,
				"prompt": "[E] Look into the tanks",
				"action": "flavor:Silverfin circle under the greens — roots drinking the fish-water, fish breathing the root-water. A closed little world."},
		],
	},
}
const CAVE_MOUTH := Vector2(2100, -1790)   # the "?" cave's entrance spot — where a hermit beat points

# building footprints (drawn, not nodes): pos = center, size = extent
const BUILDINGS := [
	{"pos": Vector2(0, 980), "size": Vector2(560, 240), "color": Color(0.50, 0.52, 0.58), "name": "STARPORT"},
	{"pos": Vector2(-640, 380), "size": Vector2(260, 200), "color": Color(0.50, 0.46, 0.40), "name": "CONTRACTS"},
	{"pos": Vector2(560, 320), "size": Vector2(240, 220), "color": Color(0.46, 0.44, 0.50), "name": "MARKET"},
	{"pos": Vector2(-360, -80), "size": Vector2(220, 190), "color": Color(0.48, 0.47, 0.5), "name": "SEALED"},
	{"pos": Vector2(-800, -240), "size": Vector2(300, 250), "color": Color(0.46, 0.5, 0.58), "name": "EXPLORERS GUILD"},
	{"pos": Vector2(-560, -430), "size": Vector2(230, 180), "color": Color(0.30, 0.55, 0.34), "name": "AQUAPONICS"},
	{"pos": Vector2(2100, -1880), "size": Vector2(210, 180), "color": Color(0.44, 0.37, 0.29), "name": "?"},
]

## Drop-in art: a building shows its PixelLab sprite (assets/ground/buildings/<key>.png)
## when the file exists, else falls back to the procedural box. SEALED reuses the hab art.
const BUILDING_ART := {
	"STARPORT": "starport",
	"EXPLORERS GUILD": "guild",
	"AQUAPONICS": "aquaponics",
	"MARKET": "market",
	"CONTRACTS": "hab",
	"SEALED": "hab",
	"?": "cave",
}

var _font: Font
var _player: GroundCharacter
var _npcs: Array = []          # each: {node, name, home, radius, timer, tint}
var _hermit: GroundCharacter   # interior-only actor (the Counter's cave)
var _farmhand: GroundCharacter # interior-only actor (Tam, at Sella's aquaponics farm)
var _trader: GroundCharacter   # interior-only actor (Bram, the colony market)
var _world: Node2D             # y-sorted container: building sprites + actors sort by depth
var _art := {}                 # building name -> true when a real sprite stands in for the box
var _shadow_pairs := []        # [{spr, shd}] building sprite + its shadow, for the contact test
var _dust_tex: Texture2D       # footstep-puff texture (sand cloud)
var _puff_accum := 0.0         # distance walked since the last kicked-up puff
var _walk_total := 0.0         # total distance walked this visit (for the "get out and walk" step)
var _last_ppos := Vector2.ZERO
var _spots: Array = []         # active interactables: {pos_fn/pos, range, prompt, action}
var _interior_id := ""   # which INTERIORS room we're in ("" = outside)
var _current_action := ""
var _flash_t := 0.0
var _flash_msg := ""
var _e_was := false
var _esc_was := false
## True for the first frame after a panel closes -- see _poll_actions.
var _thawed_frame := false
var _lmb_was := false
var _rmb_was := false
var _q_was := false
var _tab_was := false
var _kneel_was := false
var _kneeling := false
var _med_was := false
var _tech_was := {}      # bus slot -> key held last frame (edge detection)
var _tech_cd := {}       # technique id -> seconds remaining
var _active := true   # frozen while a dock panel is open over the town (flight_test drives it)
var _current_npc := ""   # name of the NPC under the [E] prompt (for the tutor's met-events)
var _tutor_cap: Label    # ground-lesson caption (top-center)
var _weather: CPUParticles2D   # the sandstorm — an OUTSIDE thing, hidden while indoors
var _ship_sprite: Sprite2D     # your hull, parked on the apron (null when it has no art)
var _ambushers: Array = []     # the pack lying in wait behind the dune on the cave road
var _cave_scavengers: Array = []   # Campaign beat 2: the scrit sifting the wrecked cave
var _drone_taken := false          # the Ooshu eye has been looted (once per visit)
var _ambush_sprung := false

@onready var _prompt: Label = $HUD/Prompt
@onready var _center: Label = $HUD/Center
@onready var _title: Label = $HUD/Title


func _ready() -> void:
	add_to_group("ground_town")   # the character sheet freezes us by this group while open
	_font = ThemeDB.fallback_font
	_build_dusk()
	_build_weather()
	_world = Node2D.new()
	_world.y_sort_enabled = true   # buildings + actors occlude by depth
	add_child(_world)
	_build_buildings()
	_spawn_ambush()    # BEFORE the scatter: the ambush dune claims its own ground
	_scatter_props()   # rocks + dunes in the open roam (drop-in art)
	_spawn_player_ship()   # your hull on the apron, south of the Starport

	# A pilot who skipped character creation (every dev harness, and the very first frames
	# of a new game) has no callsign, and the frame drew a bare "?" over the player's own
	# unit frame. "?" is the honest answer for an unnamed bystander, never for you.
	_player = _make_actor("res://assets/characters/PilotM", Color.WHITE,
		Pilot.callsign if Pilot.callsign != "" else "Pilot")
	_player.global_position = Vector2(0, 780)
	_player.team = "player_team"
	_player.add_to_group("player_walker")
	Pilot.ensure_ground_kit()   # first landfall grants the rags + scrap pistol, once
	Pilot.autoprepare()         # the bus reconciles with what this character knows
	apply_gear(true)
	_player.died.connect(_on_player_down)
	_world.add_child(_player)
	_spawn_warren()
	var cam := Camera2D.new()
	cam.zoom = Vector2(1.3, 1.3)
	_player.add_child(cam)
	cam.make_current()
	_dust_tex = _load_tex("res://assets/ground/fx/dust_cloud.png")
	_last_ppos = _player.global_position

	# wants_talk drives the notice reaction: TRUE = walk over + start the conversation, FALSE =
	# a "huh?" glance. Driven each frame from QUEST business + the tutor target (_refresh_npc_business),
	# so an NPC approaches exactly when a quest (or the onboarding) wants you to see them.
	_spawn_npc("Imari", "res://assets/characters/Imari", Vector2(140, 700), 220, Color.WHITE, "idle:imari", false)
	_spawn_npc("Sella", "res://assets/characters/Sella", Vector2(-700, -320), 200, Color.WHITE, "idle:sella", false)
	_spawn_npc("Colonist", "res://assets/characters/Colonist", Vector2(0, 360), 300, Color(0.9, 0.85, 1.0), "talk_Colonist", false)

	# "The Counter" — the name npcs.gd registers him under and the one the cave prompt
	# already shows. His REAL name is the beat-4 reveal and must not appear on a plate.
	_hermit = _make_actor("res://assets/characters/Conall", Color.WHITE, "The Counter")
	_hermit.global_position = IROOM + Vector2(0, -160)
	_hermit.visible = false
	_world.add_child(_hermit)
	# Tam — Sella's farmhand, resident of the aquaponics interior.
	_farmhand = _make_actor("res://assets/characters/Tam", Color.WHITE, "Tam")
	_farmhand.global_position = IROOM + Vector2(90, -120)
	_farmhand.visible = false
	_world.add_child(_farmhand)
	# Bram — the colony market's trader, resident of the market interior.
	_trader = _make_actor("res://assets/characters/Bram", Color.WHITE, "Bram")
	_trader.global_position = IROOM + Vector2(60, -140)
	_trader.visible = false
	_world.add_child(_trader)

	_title.text = "EPHARON  ·  WASD or hold-mouse to move  ·  [E] interact"
	_tutor_cap = Label.new()
	_tutor_cap.anchor_right = 1.0
	_tutor_cap.offset_left = 220.0
	_tutor_cap.offset_right = -220.0
	_tutor_cap.offset_top = 74.0
	_tutor_cap.offset_bottom = 150.0
	_tutor_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutor_cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutor_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutor_cap.add_theme_font_size_override("font_size", 22)
	_tutor_cap.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62))
	_tutor_cap.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_tutor_cap.add_theme_constant_override("outline_size", 5)
	_tutor_cap.visible = false
	$HUD.add_child(_tutor_cap)
	var bar := TechniqueBar.new()
	bar.walker = _player
	bar.cooldowns = _tech_cd   # the LIVE dict — the bar reads, it never decides
	$HUD.add_child(bar)
	var frames := GroundHud.new()
	frames.walker = _player
	$HUD.add_child(frames)
	_rebuild_town_spots()


## YOUR SHIP, ON THE GROUND. Renders the hull you are actually flying, parked nose-north
## on the apron. Art resolves exactly the way build_ship.gd does — an explicit
## `art_path` first (the faction/company convention), else the display name — so a hull
## with no sprite yet (the Dowager) simply parks nothing and the berth still works.
func _spawn_player_ship() -> void:
	var b := SampleBuilds.get_build(SampleBuilds.current)
	if b == null or b.hull == null:
		return
	var path: String = b.hull.art_path if b.hull.art_path != "" \
		else "res://assets/ships/%s.png" % b.hull.display_name.to_snake_case()
	var tex := _load_tex(path)
	if tex == null:
		# No sprite for this hull yet (the Dowager ships without one). The berth and its
		# [E] launch still stand — an empty pad is honest, a placeholder would not be.
		push_warning("Epharon apron: no ground art for hull '%s' (%s)" % [b.hull.display_name, path])
		return
	var width: float = float(GROUND_SHIP_W.get(b.hull.size_band, 300.0))
	# INTEGER scale, never fractional: this is the most heavily upscaled art in the game
	# (a 32px hull drawn ~300 units wide), and at a fractional factor nearest-neighbour
	# has to make some source pixels 9 screen-pixels across and their neighbours 10 —
	# the hull reads subtly warped even standing still. Rounding costs a few units of
	# size and keeps every pixel square.
	var sc: float = maxf(1.0, roundf(width / float(maxf(1.0, tex.get_width()))))
	width = float(tex.get_width()) * sc
	# Hull art is authored nose +X (the flight convention). Parked, we want it facing
	# NORTH — pointing away down the apron, the way a ship waits to lift.
	var facing := -PI * 0.5
	# Shadow falls DOWN-LEFT, matching every building and character in the scene (the sun
	# sits off the upper right — check the Starport's cast shadow, not the sunlit-rim
	# comment in _draw_building, which describes the lit EDGE and misled the first pass).
	# A parked ship is seen from ABOVE, not standing on the sand, so this is a plain
	# offset copy — NOT the walker's projected, skewed silhouette, which would read as a
	# second ship lying on its side beside the first.
	var shd := Sprite2D.new()
	shd.texture = tex
	shd.scale = Vector2(sc, sc)
	shd.rotation = facing
	shd.position = PAD_CENTER + Vector2(-30, 22)
	shd.modulate = GroundCharacter.SHADOW_TINT
	# NEAREST-NEIGHBOUR. The project default is linear, which nothing else notices because
	# nothing else is scaled far past 1x — blown up ~9x it turned the hull to mush.
	shd.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world.add_child(shd)
	_ship_sprite = Sprite2D.new()
	_ship_sprite.texture = tex
	_ship_sprite.scale = Vector2(sc, sc)
	_ship_sprite.rotation = facing
	_ship_sprite.position = PAD_CENTER
	_ship_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# THE HULL ALWAYS DRAWS OVER YOU, so you pass UNDER it rather than appearing to stand
	# on the wing. _world is y-sorted, which is right for people and buildings but wrong
	# here: the ship is a raised object you walk beneath, not a footprint on the sand, and
	# y-sorting put the pilot on top the moment they stepped south of its centre. z_index
	# wins over y-sort within a layer, so this is the one exception.
	_ship_sprite.z_index = 10
	_world.add_child(_ship_sprite)
	# NO COLLIDER, deliberately. The first pass gave the hull a capsule so you walked
	# around it — but the ship now draws OVER the pilot so you can pass beneath it, and a
	# solid body makes that impossible: you'd bounce off thin air under the wing while the
	# art says there's room. It sits on its gear with clearance underneath; the berth is
	# open ground. (If it should read as solid again, the capsule belongs on the ENGINE
	# BLOCK alone, not the whole silhouette.)


## GEAR -> WALKER: derive the character's numbers from the worn kit (GroundStats — the
## ONE place character stats come from) and dress the Main weapon on the sprite. Public
## and in group "ground_town" so the dossier refreshes the live walker on equip/unequip:
##   get_tree().call_group("ground_town", "apply_gear", false)
## fresh=true (landfall) fills health/barrier; a mid-visit re-derive keeps the current
## fraction so swapping a vest is never a free heal.
func apply_gear(fresh := false) -> void:
	var stats := GroundStats.derive(Pilot.ground_gear_items())
	var frac := 1.0 if fresh or _player.max_health <= 0.0 else _player.health / _player.max_health
	_player.max_health = float(stats.max_health)
	_player.health = _player.max_health * frac
	_player.mitigation = float(stats.mitigation)
	_player.max_barrier = float(stats.barrier)
	_player.barrier = float(stats.barrier) if fresh else minf(_player.barrier, _player.max_barrier)
	_player.max_energy = float(stats.max_energy)
	_player.energy = _player.max_energy if fresh else minf(_player.energy, _player.max_energy)
	_player.energy_recharge = float(stats.energy_recharge)
	_player.attack_spec = (stats.attack as Dictionary).duplicate()
	var w: GroundGearDef = stats.weapon
	var views := w.weapon_views() if w != null else {}
	if views.is_empty():
		_player.unequip_weapon()   # fists or a shiv — the swing still plays, no sprite
	else:
		_player.equip_weapon_views(views, w.two_handed)


## CAMPAIGN BEAT 2 — is the Counter's cave currently a crime scene? True only while the
## `cave_wreck_looted` stage is live, so a player who has not reached the beat finds the
## cave exactly as it was, and one who has finished it does not keep walking into a
## museum of it. The town asks the QUEST rather than storing its own flag: one source of
## truth, and no save key that can drift out of step with the story.
func _cave_wrecked() -> bool:
	return Quests.ground_event_active("cave_wreck_looted")


## The scrit sifting the wreck. Authored by the BEAT, not the world: a dormant pack (the
## ambush machinery — a group that does nothing until sprung is exactly a group absorbed
## in looting) placed inside the room, plus the drone one of them is carrying.
func _spawn_cave_scavengers() -> void:
	if not _cave_scavengers.is_empty() or not _cave_wrecked():
		return
	for i in 3:
		var g := Scrit.new()
		_world.add_child(g)
		g.setup_scrit(IROOM + Vector2(-170 + i * 150, -40 + (i % 2) * 70))
		g.cornered = true   # one mouth, no line of retreat — they fight it out
		g.lie_in_wait()
		g.died.connect(_on_scrit_down.bind(g))
		_cave_scavengers.append(g)


## They notice you the moment you are properly inside — no trigger radius, because the
## room IS the trigger and there is nowhere to hide in it.
func _wake_cave_scavengers() -> void:
	var woke := 0
	for g in _cave_scavengers:
		if is_instance_valid(g) and not g.dead and g.dormant:
			g.spring(_player)
			woke += 1
	if woke > 0:
		_flash("They were IN here — three of them, elbow-deep in his things.", 2.6)
		Sfx.play("dread", -9.0, 1.5)


## THE DRONE. Looted off the scavengers, and the only reason the player ever learns the
## Ooshu were watching. Granted once, on the first corpse searched in the wrecked cave.
func _grant_drone() -> bool:
	if _drone_taken or not _cave_wrecked():
		return false
	_drone_taken = true
	# INTO THE HOLD, as freight you can look at. It was a flash message and a quest flag
	# before, which meant the fiction ("take it to Odessa") and the inventory disagreed.
	var ship := _player_ship()
	if ship != null:
		ship.add_commodity("ooshu_drone", 1)
	Quests.note_ground_event("cave_wreck_looted")
	_flash("Among the scrap: a scorched sensor stalk, one lens shattered. Somebody left an EYE on this cave.", 4.0)
	Sfx.play("jingle", -8.0, 0.85)
	return true


## The one place a town actor is built. `nm` is what the character CALLS ITSELF — the
## town's own `_npcs` dict still holds the name it is addressed BY (quest routing, spot
## actions), and those are not always the same string; the plate wants the former.
func _make_actor(dir: String, tint: Color, nm := "") -> GroundCharacter:
	var a := GroundCharacter.new()
	a.setup(dir)
	# set_tint, not `modulate`: the actor now has a nameplate child and modulate cascades.
	a.set_tint(tint)
	a.display_name = nm
	return a


func _spawn_npc(nm: String, dir: String, home: Vector2, radius: float, tint: Color,
		action := "", wants_talk := false) -> void:
	var a := _make_actor(dir, tint, nm)
	a.global_position = home
	_world.add_child(a)
	_npcs.append({"node": a, "name": nm, "home": home, "radius": radius, "timer": randf() * 3.0,
		"action": action, "wants_talk": wants_talk, "noticed": false, "approaching": false,
		"delivered": false, "react_cd": 0.0, "look_t": 0.0})


# ---------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
	if not _active:
		return   # a dock panel owns the screen; the town holds still behind it
	_drive_player()
	if _interior_id != "":
		var half: Vector2 = INTERIORS[_interior_id].get("half", IROOM_HALF)
		var lo := IROOM - half + Vector2(40, 40)
		var hi := IROOM + half - Vector2(40, 40)
		_player.global_position = _player.global_position.clamp(lo, hi)
	else:
		_tick_npcs(delta)
		_enforce_heat()
		_tick_footdust()
		_tick_ambush()
	# COMBAT POLLS EVERYWHERE, INDOORS INCLUDED (playtest 2026-07-25: "you can't attack
	# inside a building"). It sat in the exterior-only branch above, so the moment the
	# campaign put a fight INSIDE a room — the wrecked cave — the player could not select,
	# engage, toggle weapons, cycle targets, kneel or fire a technique. Exactly the shape
	# of the tutor bug from earlier today: a system trapped in the else-branch, unnoticed
	# until content walked indoors.
	_poll_combat()
	_tick_techniques(delta)   # cooldowns run indoors too — a room is not a time-out
	# The tutor observes EVERYWHERE — indoors too (user bug: opening Bram's shop inside
	# the market fired used_market, but the lesson only advanced after stepping back
	# outside, because observe() never ran while a room was up).
	_tick_tutor()
	_update_focus()
	_poll_actions()
	if _flash_t > 0.0:
		_flash_t -= delta
		_center.text = _flash_msg
		_center.visible = true
	else:
		_center.visible = false
	queue_redraw()


## NPCs NOTICE the player. If one has business (wants_talk) it breaks its wander and walks
## over to start the conversation; otherwise it just GLANCES — stops, faces you, and lets out
## a "?" ("huh?"). Hostiles will snarl + attack off this same hook, later. Everyone else wanders.
const NOTICE_RANGE := 340.0
const TALK_RANGE := 118.0

func _tick_npcs(delta: float) -> void:
	_refresh_npc_business()
	var pp: Vector2 = _player.global_position
	for n in _npcs:
		var node: GroundCharacter = n.node
		var dist := node.global_position.distance_to(pp)
		n.react_cd = maxf(0.0, n.react_cd - delta)
		n.look_t = maxf(0.0, n.look_t - delta)

		if n.approaching:
			node.move_to(pp)                                 # walk over until close
			if dist <= TALK_RANGE:
				node.stop()
				node.face(_cardinal(pp - node.global_position))
				n.approaching = false
				n.wants_talk = false
				n.delivered = true                            # she's come to you — now she WAITS.
				n.react_cd = 4.0
				n.look_t = 1.6                                # hold facing you, don't robo-wander off
				# She SAYS something (non-locking) but never opens a panel — the PLAYER opens every
				# interaction ([E], in _poll_actions), and `met_<npc>` fires there, not on her arrival.
				# A BUBBLE OVER HER HEAD, not a centre-screen flash (user, 2026-07-26 —
				# this was a standing TODO in this file and is now done). A flash was
				# the wrong channel twice: it seized the middle of the screen for
				# something the player never asked for, and it did not say WHO was
				# speaking, which in a town with six people is a real question. It also
				# had to be read fast or not at all.
				ChatBubble.say(self, n.node, "\"Got a moment, pilot?\"", 4.5)
			continue

		# Someone with BUSINESS (a quest talk, or the tutor's target) walks over the moment they
		# clock you — even if they'd already glanced earlier with nothing to say. A plain
		# passer-by only lets out a single "huh?" glance and goes back to their day.
		if dist <= NOTICE_RANGE and n.wants_talk and str(n.action) != "":
			n.noticed = true
			node.stop()
			node.face(_cardinal(pp - node.global_position))
			n.approaching = true
			continue
		if dist <= NOTICE_RANGE and not n.noticed and n.react_cd <= 0.0:
			n.noticed = true
			n.react_cd = 3.0
			node.stop()
			node.face(_cardinal(pp - node.global_position))
			n.look_t = 1.2                                    # hold a glance
			_npc_notice(node)
		elif dist > NOTICE_RANGE + 130.0:
			n.noticed = false
			n.delivered = false   # you walked off and came back — she may approach again

		if n.look_t > 0.0:
			continue                                          # holding the glance; don't wander yet
		n.timer -= delta
		if n.timer <= 0.0:
			n.timer = randf_range(1.6, 4.2)
			var ang := randf() * TAU
			var rad: float = randf() * float(n.radius)
			var home: Vector2 = n.home
			node.move_to(home + Vector2(cos(ang), sin(ang)) * rad)


## THE WARREN — the scrit' authored place, out past the east dunes (living-world rule:
## enemies live somewhere, they don't spawn on you). Far enough out that a new pilot
## meets them by CHOOSING to roam; the town's light (Scrit.TOWN_SANCTUARY_R) keeps
## the streets safe regardless.
const WARREN := Vector2(2300, 1500)
const WARREN_PACK := 4

## ---- THE DUNE AMBUSH (user, 2026-07-25) ----
## The warren sits far south-east; the hermit's cave is far NORTH-east, so the walk to
## the Counter never met a thing (playtest: "he didn't get attacked going to see the
## hermit"). This is the authored answer — a pack lying in wait BEHIND a dune on that
## road, unseen until you are close, then breaking cover at you.
##
## Still not on-player spawning: the dune is a fixed place with a fixed pack, and walking
## a different way misses them entirely. The AUTHORED-AMBUSH exception to the
## living-world rule (see flight_test's scripted beats) — a place that hides, not a
## spawner that follows.
const AMBUSH_DUNE := Vector2(1680, -1180)   # on the town → cave diagonal
const AMBUSH_PACK := 3
const AMBUSH_TRIGGER := 330.0               # they hold until you are THIS close
## Where each hides, relative to the dune — the FAR side from a pilot walking up from
## town, so the sand is between you and them right up to the moment they move.
const AMBUSH_SPOTS := [Vector2(-120, -95), Vector2(35, -130), Vector2(165, -80)]

func _spawn_warren() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for i in WARREN_PACK:
		var g := Scrit.new()
		_world.add_child(g)
		var a := rng.randf() * TAU
		g.setup_scrit(WARREN + Vector2(cos(a), sin(a)) * rng.randf_range(30.0, 190.0))
		g.died.connect(_on_scrit_down.bind(g))


## Plant the ambush: an AUTHORED dune (not one of the scattered ones — the trap must not
## depend on where a seeded scatter happened to drop sand) with the pack tucked behind it.
## Called BEFORE _scatter_props so the dune claims its ground and the scatter avoids it.
func _spawn_ambush() -> void:
	var dune := _load_tex("res://assets/ground/props/dune.png")
	if dune != null:
		var pair := _spawn_prop(dune, AMBUSH_DUNE, 520.0, Color(0.80, 0.70, 0.55), false)
		_placed_props.append({"pos": AMBUSH_DUNE, "r": 260.0})   # scatter keeps its distance
		if pair.is_empty():
			pass
	for i in AMBUSH_PACK:
		var g := Scrit.new()
		_world.add_child(g)
		g.setup_scrit(AMBUSH_DUNE + AMBUSH_SPOTS[i % AMBUSH_SPOTS.size()])
		g.lie_in_wait()
		g.died.connect(_on_scrit_down.bind(g))
		_ambushers.append(g)


## Hold until the pilot is close, then break cover together. One-shot: once sprung they
## are ordinary scrit with an ordinary leash, so a survivor never re-hides.
func _tick_ambush() -> void:
	if _ambush_sprung or _ambushers.is_empty():
		return
	if _player.global_position.distance_to(AMBUSH_DUNE) > AMBUSH_TRIGGER:
		return
	_ambush_sprung = true
	var woke := 0
	for g in _ambushers:
		if is_instance_valid(g) and not g.dead:
			g.spring(_player)
			woke += 1
	if woke > 0:
		_flash("THEY WERE WAITING — %d of them, out of the sand!" % woke, 2.4)
		Sfx.play("dread", -8.0, 1.4)


func _on_scrit_down(g: Scrit) -> void:
	Wallet.xp += XP.activity("scrit")   # one spine: scrit pay the same currency as pirates
	_flash("Scrit down  ·  +6 XP", 1.6)
	if _player.combat_target == g:
		_player.engage(null)
	# The body stays: it settles into the DEAD state and becomes a loot container
	# (Scrit._become_corpse) — scavenge it with [E], or leave it to the sand.


## Ground death routes through THE seam (GroundDeath.apply — the open EQ-light policy
## lives there, nowhere else). v1: bag drops, wake at the Starport.
func _on_player_down() -> void:
	var ship := get_tree().get_first_node_in_group("player_ship")
	var result := GroundDeath.apply(ship)
	var lost: Array = result.get("dropped", [])
	var msg := "DOWN IN THE DUST...  you wake at the Starport"
	if not lost.is_empty():
		msg += "  ·  your bag spilled where you fell"
	_flash(msg, 4.0)
	# Wake: restore and stand the pilot back on the pad. (The satchel entity is an OPEN
	# seam — v1 the goods are simply gone from the hold; see GroundDeath.)
	await get_tree().create_timer(2.2).timeout
	_player.dead = false
	_player.health = _player.max_health
	_player.set_pose("")
	# REVIVE UNDOES EVERYTHING DEATH DID. Each of these was set on the way down and
	# never cleared on the way up:
	#  · meditating -- a SOFT-LOCK. _physics_process roots the pilot while it is
	#    true, so dying mid-meditate left them awake, standing, and unable to move
	#    or use a technique, with no clue but to guess [K].
	#  · the shadow -- die() tweens it to alpha 0 and nothing brings it back, so the
	#    pilot walked the rest of the session as the one thing in town casting none.
	#  · _kneeling -- the town's mirror of the pose, which desynced so the next
	#    [SPACE] silently did nothing and cover mitigation was not applied.
	_player.set_meditating(false)
	_player.restore_shadow()
	_kneeling = false
	# YOU WAKE OUTSIDE (playtest: died in the cave, respawned in a corner of it). The
	# death seam already says you wake at the Starport; leaving you in the room you were
	# killed in — with whatever killed you — is neither that nor survivable.
	if _interior_id != "":
		_exit_interior()
	_player.global_position = Vector2(0, 780)
	_player.face("south")


## ---- combat verbs (the input scheme, on foot) ----
## LMB = SELECT (a click on a scrit targets it; holding still walks). RMB on a hostile
## = target AND engage (the soft interact). [Q] toggles weapons-free. [TAB] cycles
## hostiles. [SPACE] kneels — cover mitigation + the braced pose.
func _poll_combat() -> void:
	var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if lmb and not _lmb_was:
		var hit := _hostile_at(_world.get_global_mouse_position())
		if hit != null:
			_player.combat_target = hit
	_lmb_was = lmb
	var rmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if rmb and not _rmb_was:
		var hit := _hostile_at(_world.get_global_mouse_position())
		if hit != null:
			_player.engage(hit)   # picking a fight and starting it are one gesture
			Tutor.did("ground_engaged")
	_rmb_was = rmb
	var q := Input.is_key_pressed(Keys.WEAPONS_FREE)
	if q and not _q_was:
		_player.auto_attack = not _player.auto_attack
		if _player.auto_attack and _player.combat_target == null:
			_player.combat_target = _nearest_hostile()
		if not _player.auto_attack:
			_player.set_pose("kneeling" if _kneeling else "")
		_flash("WEAPONS FREE" if _player.auto_attack else "WEAPONS TIGHT", 1.0)
		Tutor.did("ground_weapons_toggled")
	_q_was = q
	var tabk := Input.is_key_pressed(Keys.CYCLE_FOE)
	if tabk and not _tab_was:
		_player.combat_target = _nearest_hostile(_player.combat_target)
	_tab_was = tabk
	var kneel := Input.is_key_pressed(Keys.BRAKE)
	if kneel and not _kneel_was:
		_kneeling = not _kneeling
		_player.set_pose("kneeling" if _kneeling else "")
		Tutor.did("ground_kneeled")
	_kneel_was = kneel
	# [K] MEDITATE — the Going-Dark mirror on foot: power down into the cell, refill fast,
	# defenseless while you're down. Kneeling is the pose either way, so leaving meditation
	# restores whatever stance you chose.
	var med := Input.is_key_pressed(Keys.DARK)
	if med and not _med_was:
		_player.set_meditating(not _player.meditating)
		if not _player.meditating and _kneeling:
			_player.set_pose("kneeling")
		_flash("MEDITATING — systems down, cell charging" if _player.meditating
			else "Up. Systems live.", 1.6)
		Tutor.did("meditated")
	_med_was = med
	# [1]-[5] TECHNIQUES — the character's own bus (Pilot.techniques), distinct from the
	# ship's gems by design: hardware vs training.
	for i in Techniques.BUS_SLOTS:
		var key := Keys.ability_key(i)
		var down := Input.is_key_pressed(key)
		if down and not _tech_was.get(i, false):
			_use_technique(i)
		_tech_was[i] = down


## Fire the technique prepared in bus slot `i`. EVERY refusal is loud and specific (the
## ship's _ability_fail rule, mirrored) — and, the invariant that matters: the energy
## and the cooldown are only ever charged AFTER the last refusal, so a refused technique
## costs nothing.
func _use_technique(i: int) -> void:
	var tid := Pilot.technique_at(i)
	if tid == "":
		_tech_fail("[%d] IS EMPTY — prepare a technique in your dossier [P]" % (i + 1))
		return
	var d := Techniques.def(tid)
	if d.is_empty():
		return
	if _player.dead:
		return
	if _player.meditating:
		_tech_fail("%s — YOU'RE MEDITATING" % str(d.name).to_upper())
		return
	if _player.is_stunned():
		_tech_fail("%s — YOU'RE REELING" % str(d.name).to_upper())
		return
	if _tech_cd.get(tid, 0.0) > 0.0:
		_tech_fail("%s — %.0fs LEFT" % [str(d.name).to_upper(), float(_tech_cd[tid])])
		return
	# Target-needing techniques check the target BEFORE the cell is touched.
	var target := _player.combat_target
	if tid == "sand_kick":
		if target == null or not is_instance_valid(target) or target.dead:
			_tech_fail("KICK SAND — NO TARGET")
			return
		if _player.global_position.distance_to(target.global_position) > float(d.range):
			_tech_fail("KICK SAND — OUT OF RANGE")
			return
	if tid == "field_patch" and _player.health >= _player.max_health:
		_tech_fail("FIELD PATCH — YOU'RE UNHURT")
		return
	if not _player.spend_energy(float(d.get("energy", 0.0))):
		_tech_fail("%s — NOT ENOUGH ENERGY" % str(d.name).to_upper())
		return
	_tech_cd[tid] = float(d.get("cooldown", 0.0))
	Tutor.did("used_technique")   # fired AFTER every refusal, so only a real cast counts
	# ---- the dispatch (one arm per Techniques.LIST entry; effects live on the character) ----
	match tid:
		"field_patch":
			var healed := _player.mend(float(d.heal))
			_flash("FIELD PATCH — mended %d" % int(healed), 1.6)
		"sand_kick":
			target.apply_stun(float(d.duration))
			_flash("KICK SAND — it reels, clawing at its eyes", 1.8)
		"second_wind":
			_player.apply_haste(float(d.duration))
			_flash("SECOND WIND", 1.4)
		"brace":
			_player.apply_brace(float(d.duration), float(d.mitigation))
			_flash("BRACED — set your feet", 1.6)
	Sfx.play("pickup", -10.0)


func _tech_fail(reason: String) -> void:
	# The unmistakable refusal (ship rule: loud, red, distinct from the soft nav click).
	_flash("✕ " + reason, 2.2)
	Sfx.play("click", -6.0, 0.32)


func _tick_techniques(delta: float) -> void:
	for tid in _tech_cd.keys():
		var left: float = float(_tech_cd[tid]) - delta
		if left <= 0.0:
			_tech_cd.erase(tid)
		else:
			_tech_cd[tid] = left


func _hostile_at(point: Vector2) -> GroundCharacter:
	var best: GroundCharacter = null
	var best_d := 46.0
	for n in get_tree().get_nodes_in_group("ground_hostiles"):
		var g := n as GroundCharacter
		if g == null or g.dead:
			continue
		var d := point.distance_to(g.global_position - Vector2(0, 24))
		if d < best_d:
			best_d = d
			best = g
	return best


func _nearest_hostile(after: GroundCharacter = null) -> GroundCharacter:
	var all: Array = []
	for n in get_tree().get_nodes_in_group("ground_hostiles"):
		var g := n as GroundCharacter
		if g != null and not g.dead 				and _player.global_position.distance_to(g.global_position) < 900.0:
			all.append(g)
	if all.is_empty():
		return null
	all.sort_custom(func(a, b) -> bool:
		return _player.global_position.distance_to(a.global_position) 			< _player.global_position.distance_to(b.global_position))
	if after != null and all.has(after):
		return all[(all.find(after) + 1) % all.size()]
	return all[0]


func _cardinal(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "east" if v.x > 0.0 else "west"
	return "south" if v.y > 0.0 else "north"


## Drive the declarative Tutor from the ground. The town is the tutor's authority while you're
## on foot (flight_test yields — see its _tick_flight_lessons). Ground steps carry `target` +
## `text`; we light the target NPC's wants_talk (so they approach) and show the caption. Step
## completion is an IN-WORLD action fired as Tutor.did() (met_<npc> / used_<place>).
func _tick_tutor() -> void:
	Tutor.context = "ground"
	Tutor.venue = "planet"
	Tutor.safe = true
	var ship := get_tree().get_first_node_in_group("player_ship")
	Tutor.observe({
		"on_ground": true,
		"tutorial_done": SaveGame.tutorial_done,
		"cargo_food": int(ship.commodities.get("food", 0)) if ship != null else 0,
		# ON-FOOT COMBAT context. Each lesson arms on the SITUATION, so the snapshot has
		# to carry it: something visible to fight, a technique actually known, and how
		# much cell is left. Every key is read with a default on the other side, so a
		# missing one is falsy rather than a crash (the engine's can't-jam rule).
		"hostile_near": _nearest_hostile() != null,
		"has_technique": Pilot.technique_at(0) != "" or Pilot.first_empty_technique() != 0,
		"energy_frac": (_player.energy / _player.max_energy) if _player.max_energy > 0.0 else 1.0,
		"skill_points": Pilot.skill_points_available(),
	})
	# One caption for the ONE dirtside objective (onboarding step / a held quest talk / a dock
	# tutorial redirected to its building) — and the chevron in _draw_town points at the same spot.
	var obj := _dirtside_objective()
	# {TOKEN}s -> live bindings (Keys.expand), same as the flight ping's captions.
	_tutor_cap.text = Keys.expand(str(obj.get("text", "")))
	_tutor_cap.visible = not obj.is_empty()


## Who has BUSINESS with you (so they break their wander and walk over): an NPC the QUEST
## system has a pending talk queued for, OR the active ground-lesson's target. This is the
## whole "tutorial ↔ quests" seam — when a campaign beat queues a talk for Imari/Sella/etc.
## (Quests.on_dock, fired as you land), she now approaches you on the ground exactly as the
## onboarding's scripted "meet Imari" does. Only turns wants_talk ON; delivering it (the
## approach in _tick_npcs) turns it back off, and the [E] panel drains the quest talk.
func _refresh_npc_business() -> void:
	var tgt := str(_ground_step().get("target", ""))
	for n in _npcs:
		if n.delivered:
			continue   # she already walked over this visit — don't re-summon her every frame
		var nm := str(n.name)
		if nm == tgt or not Quests.talks_for(nm.to_lower()).is_empty():
			n.wants_talk = true


## The active Tutor step IF it's a ground step (else {}).
func _ground_step() -> Dictionary:
	var c := Tutor.current()
	if not c.is_empty() and str(c.get("where", "")) == "ground":
		return c
	return {}


## World position of a ground target (an NPC name or a building name); INF if unknown.
func _ground_target_pos(target: String) -> Vector2:
	for n in _npcs:
		if str(n.name) == target:
			return n.node.global_position
	for b in BUILDINGS:
		if str(b.name) == target:
			return b.pos
	return Vector2.INF


## The ONE thing to do dirtside right now, as a TOWN place + a line of copy — never a tab.
## Priority: the active onboarding step, then whoever holds a quest talk for you, then a
## tabbed dock tutorial redirected to its building (user: "direct toward the station or NPC,
## not a tab that doesn't exist"). {} = nothing to guide toward.
func _dirtside_objective() -> Dictionary:
	var gs := _ground_step()
	if not gs.is_empty():
		var tp := _ground_target_pos(str(gs.get("target", "")))
		if not is_inf(tp.x):
			return {"pos": tp, "text": str(gs.get("text", ""))}
	for n in _npcs:
		if not Quests.talks_for(str(n.name).to_lower()).is_empty():
			return {"pos": n.node.global_position,
				"text": "%s has something for you — walk over and press [E]." % n.name}
	# The Counter is a recluse, not a town NPC — a pending hermit beat points you to his cave.
	if not Quests.talks_for("hermit").is_empty():
		return {"pos": CAVE_MOUTH,
			"text": "The Counter keeps to his cave on the colony's edge. Head out and hear him."}
	return {}


## (The tab→building remap shim that lived here is DELETED — no dock lesson points at a
## planet tab any more; the colony visit is a native ground lesson.)


## Where the on-screen guide points — the single dirtside objective's place (INF if none).
func _current_objective_pos() -> Vector2:
	return _dirtside_objective().get("pos", Vector2.INF)


## A grounded guide at the pilot's FEET: a small ring marks the base, and a chevron orbits
## that point on a flattened ground ellipse (3/4 perspective), pointing toward the objective —
## so the cue reads as coming from where the character stands.
func _draw_nudge(dir: Vector2) -> void:
	var feet := _player.global_position
	var col := Color(1.0, 0.86, 0.45, 0.95)
	draw_arc(feet, 6.0, 0.0, TAU, 16, Color(1.0, 0.86, 0.45, 0.5), 2.0)   # the base marker
	var radial := Vector2(dir.x * 46.0, dir.y * 26.0)                     # flattened onto the ground
	var p := feet + radial
	var ang := radial.angle()
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(15, 0).rotated(ang),
		p + Vector2(-9, 10).rotated(ang),
		p + Vector2(-9, -10).rotated(ang)]), col)


## The "huh?" glance: a "?" pops over the NPC + a blip. A real "huh?" VO drops in for the noise.
func _npc_notice(node: GroundCharacter) -> void:
	var lbl := Label.new()
	lbl.text = "?"
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.position = node.global_position + Vector2(-7, -84)
	add_child(lbl)   # town root: world-space, drawn over the y-sorted world
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 22, 0.7)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.finished.connect(lbl.queue_free)
	Sfx.play("click", -7.0, 1.6)   # placeholder blip; a "huh?" VO drops in


## Let the tutor (or a quest) flip whether an NPC has business waiting — drives the approach.
func set_wants_talk(nm: String, val: bool) -> void:
	for n in _npcs:
		if str(n.name) == nm:
			n.wants_talk = val


## Kick up a little sand every stride the pilot actually walks (measured by distance moved,
## so it works for WASD and hold-mouse alike). Town only — no dust on the cave floor.
func _tick_footdust() -> void:
	var moved := _player.global_position.distance_to(_last_ppos)
	_last_ppos = _player.global_position
	if moved <= 0.5 or moved >= 100.0:
		return   # standing still, or a teleport (arrival / warp)
	_walk_total += moved
	if _walk_total > 120.0:
		Tutor.did("ground_moved")   # the "get out and walk" onboarding step completes
	if _dust_tex != null:
		_puff_accum += moved
		if _puff_accum >= 30.0:
			_puff_accum = 0.0
			_spawn_puff(_player.global_position)


func _spawn_puff(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = _dust_tex
	s.scale = Vector2(0.16, 0.16)
	s.modulate = Color(0.86, 0.76, 0.56, 0.5)
	s.position = pos + Vector2(0, -2)
	s.z_index = -1   # behind the walker
	_world.add_child(s)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector2(0.40, 0.40), 0.5)
	tw.tween_property(s, "modulate:a", 0.0, 0.5)
	tw.tween_property(s, "position", pos + Vector2(-5, -12), 0.5)
	tw.finished.connect(s.queue_free)


func _enforce_heat() -> void:
	var d := _player.global_position.length()
	if d > HEAT_LIMIT:
		_player.global_position = _player.global_position.normalized() * HEAT_LIMIT
		_player.stop()
		_flash("THE HEAT IS TOO MUCH — turn back toward town", 1.6)


func _update_focus() -> void:
	_current_action = ""
	_current_npc = ""
	var best := 1e9
	var text := ""
	for s in _spots:
		var p: Vector2 = s.node.global_position if s.has("node") else s.pos
		var dist := _player.global_position.distance_to(p)
		if dist <= s.range and dist < best:
			best = dist
			text = s.prompt
			_current_action = s.action
			_current_npc = str(s.get("npc", ""))
	# Loot corpses are dynamic interactables — nearest one within reach wins the prompt
	# if nothing else claimed it.
	# A BODY IN REACH OUTRANKS THE ROOM (playtest: no drone from the cave scrit). This
	# only ran when NOTHING else had claimed the prompt — and a room always has a
	# standing spot (the exit) whose range covers it, so indoors the loot prompt could
	# never appear and the corpses could not be searched at all. A corpse you are
	# standing on is always the more specific thing to offer.
	for n in get_tree().get_nodes_in_group("ground_loot"):
		var c := n as Node2D
		if c != null:
			var cd := _player.global_position.distance_to(c.global_position)
			if cd < 70.0 and cd < best:
				best = cd
				_current_action = "loot"
				_current_npc = ""
				text = "[E] Scavenge the scrit"
				break
	_prompt.text = text
	_prompt.visible = text != ""


# ---------------------------------------------------------------- input

func _drive_player() -> void:
	# WASD / arrows take priority; else hold LEFT-MOUSE to walk toward the cursor.
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if dir == Vector2.ZERO and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var to := get_global_mouse_position() - _player.global_position
		if to.length() > 16.0:
			dir = to
	_player.move_dir(dir)


# Actions are polled (edge-detected) rather than event-driven so they work identically
# whether the town runs standalone OR embedded in flight_test's SubViewport, where raw
# InputEvent routing is unreliable. Movement is polled the same way (see _drive_player).
func _poll_actions() -> void:
	var e := Input.is_key_pressed(KEY_E)
	if e and not _e_was:
		_interact()
	_e_was = e
	# RESYNC ACROSS THE FREEZE. _poll_actions is skipped entirely while a panel is up
	# (the `not _active` guard), so _esc_was stayed false while the player held Esc to
	# CLOSE that panel -- and the frame the town thawed it read the still-held key as a
	# fresh press and also walked them out of the room. Closing a shop inside the
	# Market ejected you to the square in the same gesture. Latch the key as already
	# down for the first frame back.
	var esc := Input.is_key_pressed(KEY_ESCAPE)
	if _thawed_frame:
		_thawed_frame = false
		_esc_was = esc          # whatever is held right now is NOT a new press
	if esc and not _esc_was and _interior_id != "":
		_exit_interior()
	_esc_was = esc


## Town NPC name -> campaign cast id (Npcs.CAST / quest givers). The Counter lives in the
## cave interior; everyone else stands in the town.
const NPC_IDS := {"Imari": "imari", "Sella": "sella", "Counter": "hermit", "Tam": "tam", "Bram": "bram"}


## The PLAYER always initiates (user rule): [E] engages whatever is focused right now — an NPC,
## a building, the ship. NPCs only ever WALK OVER to get your attention; they never open a panel
## themselves. So `met_<npc>` and the action both fire HERE, on your button, never on her arrival.
##
## QUEST TALKS COME FIRST (the Saga beats, ground-native): if the person you pressed [E] on
## holds a queued campaign conversation, it presents RIGHT HERE as a DialoguePanel over the
## town — no dock panel in between. Only with nothing queued does [E] fall through to their
## ordinary action (idle line, a shop, a door).
func _interact() -> void:
	if _current_action == "":
		return
	if _current_npc != "":
		Tutor.did("met_" + _current_npc.to_lower())
		if _try_quest_talks(str(NPC_IDS.get(_current_npc, ""))):
			return
	_do_action(_current_action)


# ---------------------------------------------------------------- quest talks (ground-native)

## Present every queued campaign talk this person holds, one DialoguePanel after another —
## the same drain-the-chain rule as the dock (a giver commonly holds a finished quest's
## debrief AND the next briefing; making the player re-press [E] between them read as the
## conversation ending early). Returns false if they hold nothing.
func _try_quest_talks(npc_id: String) -> bool:
	if npc_id == "" or Quests.talks_for(npc_id).is_empty():
		return false
	_show_next_town_talk(npc_id)
	return true


## Two queued talks that are the SAME conversation. Compared on quest + opening line
## rather than identity, because check_new_work rebuilds the dictionary each time.
static func _same_talk(a: Dictionary, b: Dictionary) -> bool:
	if str(a.get("quest", "")) != str(b.get("quest", "")):
		return false
	var at := str(a.get("text", "")) + str(a.get("nodes", {}).get("start", {}).get("text", ""))
	var bt := str(b.get("text", "")) + str(b.get("nodes", {}).get("start", {}).get("text", ""))
	return at == bt


func _show_next_town_talk(npc_id: String) -> void:
	var talks := Quests.talks_for(npc_id)
	if talks.is_empty():
		set_active(true)   # chain done — hand the town back
		return
	set_active(false)      # the conversation owns the screen; the town holds still
	var talk: Dictionary = talks[0]
	Quests.take_talk(npc_id)
	var nodes: Dictionary
	if talk.has("nodes"):
		# A full talk-stage conversation, authored in the quest def.
		nodes = talk.nodes
	else:
		# A one-line briefing/debrief; append the reward stamp (same dress as the dock).
		var reward_line := ""
		if str(talk.get("rewards", "")) != "":
			reward_line = "\n\n[color=#f2b859]▸ %s — %s[/color]" % [talk.quest, talk.rewards]
		nodes = {"start": {
			"text": str(talk.text) + reward_line,
			"vo": str(talk.get("vo", "")),
			"choices": [{"text": "Understood.", "next": "end", "style": "primary"}]}}
	# Archive the moment it's shown, so dismissing never loses the beat.
	Comms.post(str(talk.giver), str(talk.get("quest", "Conversation")),
		str(nodes.get("start", {}).get("text", "")))
	var panel := DialoguePanel.new(str(talk.giver), nodes, func(_a: String) -> String:
		return "")
	panel.vo_prefix = str(talk.get("advance", ""))
	panel.closed.connect(func() -> void:
		# Finishing a talk STAGE advances that quest, which may queue the debrief and
		# make the NEXT quest eligible — check here so the campaign flows on without a
		# re-landing (the same rule the dock follows).
		if talk.has("advance"):
			Quests.advance_talk(str(talk.advance))
		Quests.check_new_work(false, SaveGame.tutorial_done)
		# NEVER REPLAY THE TALK YOU JUST FINISHED (playtest: the Counter said "Thirty
		# years..." twice — closing his conversation started it again from the top).
		# check_new_work re-queues an ACTIVE talk stage's conversation, so if the stage
		# did not advance for any reason, the drain loop below picks the very same talk
		# straight back up. Dropping an identical repeat makes the loop safe whatever the
		# cause: a conversation ends when the player ends it.
		var pending := Quests.talks_for(npc_id)
		if not pending.is_empty() and _same_talk(pending[0], talk):
			Quests.take_talk(npc_id)
		_show_next_town_talk(npc_id))
	add_child(panel)


## WHAT THE GROUND MAP DRAWS for this place. The map asks; it never reaches into our
## internals — so a second colony later answers the same call and the map needs no edit.
func map_data() -> Dictionary:
	var features: Array = []
	for b in BUILDINGS:
		features.append({"name": str(b.name), "pos": b.pos, "size": b.size,
			"kind": "cave" if str(b.name) == "?" else "building"})
	for n in _npcs:
		features.append({"name": str(n.name), "pos": n.node.global_position,
			"size": Vector2.ZERO, "kind": "person"})
	return {
		"name": "EPHARON — COLONY SURFACE",
		"features": features,
		"player": _player.global_position,
		"extent": HEAT_LIMIT,          # the heat boundary IS the edge of the walkable world
	}


## Called by flight_test each time the ship touches down at Epharon: reset the pilot onto
## the pad, clear any interior state from a prior visit. Standalone runs never call it.
func enter_town() -> void:
	_interior_id = ""
	_set_cam_offset(Vector2.ZERO)
	_hermit.visible = false
	_farmhand.visible = false
	_trader.visible = false
	for n in _npcs:
		n.node.visible = true
		n.noticed = false        # fresh visit: nobody has clocked you or come over yet
		n.approaching = false
		n.delivered = false
		n.wants_talk = false     # re-derived by _refresh_npc_business from live quest/tutor state
	_player.move_dir(Vector2.ZERO)
	_player.stop()
	_player.global_position = Vector2(0, 780)
	_player.face("south")
	_last_ppos = _player.global_position
	_walk_total = 0.0
	_rebuild_town_spots()
	_flash_t = 0.0
	_active = true   # always thaw on arrival, whatever the sheet left it at


## Launch refused (bad build) — say why, stay grounded.
func reject_launch(msg: String) -> void:
	_flash(msg, 2.6)


## flight_test freezes the town while a dock panel is open over it, and thaws it on close.
func set_active(on: bool) -> void:
	if on and not _active:
		_thawed_frame = true      # do not read a still-held Esc as a new press
	_active = on
	if not on:
		_player.move_dir(Vector2.ZERO)
		_player.stop()
		for n in _npcs:
			n.node.stop()


func _clamp_target(t: Vector2) -> Vector2:
	if _interior_id != "":
		var half: Vector2 = INTERIORS[_interior_id].get("half", IROOM_HALF)
		return Vector2(
			clampf(t.x, IROOM.x - half.x + 40, IROOM.x + half.x - 40),
			clampf(t.y, IROOM.y - half.y + 40, IROOM.y + half.y - 40))
	if t.length() > HEAT_LIMIT:
		_flash("THE HEAT IS TOO MUCH — turn back toward town", 1.4)
		return t.normalized() * (HEAT_LIMIT * 0.98)
	return t


func _do_action(action: String) -> void:
	# GROUND-NATIVE SERVICES, all of them (user, 2026-07-25): the spatialized dock panel
	# was the scaffolding that let the ground exist; nothing routes through it any more.
	# "shop:<npc>" = that person's counter, "board:<npc>" = a contract board, "starport" =
	# the landing receipt. On the ground you deal with PEOPLE and PLACES, not tabs.
	if action.begins_with("shop:"):
		_open_shop(action.substr(5))
		return
	if action.begins_with("board:"):
		_open_board(action.substr(6))
		return
	if action.begins_with("enter:"):
		_enter_interior(action.substr(6))
		return
	if action.begins_with("flavor:"):
		_flash(action.substr(7), 3.0)
		return
	match action:
		"starport":
			_open_starport()
		"launch":
			Tutor.did("launched")
			_flash("Boarding your ship  ·  lifting off...", 1.2)
			launch_requested.emit()
		"leave":
			_exit_interior()
		"talk_Colonist":
			_flash("Colonist: \"...you're not from the patrol, are you.\" (they look away)", 2.6)
		"sealed":
			_flash("The door is sealed tight. No handle, no panel. Nothing.", 2.0)
		"loot":
			var best: Scrit = null
			var best_d := 80.0
			for n in get_tree().get_nodes_in_group("ground_loot"):
				var c := n as Scrit
				if c != null:
					var dd := _player.global_position.distance_to(c.global_position)
					if dd < best_d:
						best_d = dd
						best = c
			if best != null:
				# ASK BEFORE TAKING. A drop the hold can't hold stays ON THE BODY and
				# the corpse stays searchable, instead of being handed over into
				# nothing. Stashing it was the other candidate and is wrong here: the
				# station stash is a system away, and teleporting a purchase into it
				# is the exact bug that was fixed at the Verge counter.
				var ship_now := get_tree().get_first_node_in_group("player_ship")
				var room: bool = best.held_gear == null \
					or (ship_now != null and ship_now.can_carry(best.held_gear))
				var haul := best.loot(room)
				var coin := int(haul.get("credits", 0))
				Wallet.credits += coin
				# THE SECOND SEARCH. Coming back with the trinkets already taken and
				# the hold still full returns an EMPTY haul — and keying the whole
				# message off `not haul.is_empty()` made that press do nothing at all,
				# which is the same dead-button shape being fixed at the contract
				# boards. Every search says something now.
				var note := ("Scavenged the scavenger — %dc in trinkets." % coin) if coin > 0 \
					else "You have already picked this one over."
				# THE OOSHU EYE. Only in the wrecked cave, only once — the object the
				# whole beat turns on, so it is granted by the LOOT verb rather than
				# dropped randomly: the player must actually search the bodies.
				if _interior_id == "?" and _grant_drone():
					note = "Scavenged the scavenger — %dc, and something that was never theirs." % coin
				# A gear find goes to the SHIP HOLD (the ground v1 inventory — same place
				# a jettisoned crate would land), where the dossier can equip it from.
				var gear: GroundGearDef = haul.get("gear")
				if gear != null:
					ship_now.add_cargo(gear)
					note += "  It was clutching: %s (in your hold)." % gear.display_name
				elif best.held_gear != null:
					# STILL THERE — say where it is, not merely that you failed.
					note += "  It is still clutching %s. Your hold is full; come back for it." \
						% best.held_gear.display_name
				_flash(note, 2.8)
		_:
			# "idle:<id>" — nothing queued for this person; a spoken one-liner so saying
			# hello is never a dead click (same rule as the dock's NPC desks).
			if action.begins_with("idle:"):
				var who := action.substr(5)
				# A CONVERSATION IS A CONVERSATION WHEREVER YOU HAVE IT (user,
				# 2026-07-26). This flashed a toast that faded in three seconds, so a
				# player could miss a line entirely by looking at the wrong part of
				# the screen — and the same exchange with the same person AT THE
				# STATION opened a proper panel with their portrait. Campaign talks
				# down here already present as a DialoguePanel (_try_quest_talks);
				# only the idle ones were second-class. Same construction as the
				# dock's _idle_chat, so the two venues cannot drift apart again.
				Pilot.meet(who)
				var nodes := {"start": {
					"text": Npcs.idle_line(who),
					"choices": [{"text": "Fly safe.", "next": "end"}]}}
				add_child(DialoguePanel.new(who, nodes,
					func(_a: String) -> String: return ""))
				# Spoken where recorded: audio/vo/idle_<id>.* is a drop-in — a missing
				# file is a silent no-op (Sfx.play_voice returns false), never an error.
				Sfx.play_voice("idle_" + who)


## Open an NPC's shop counter over the town. The town FREEZES while it's up (same
## contract as a dock panel) and thaws when it closes — the ShopView owns Esc itself.
## The trade RULES live in TradeGoods, shared with the station dock; this only hosts.
## BRAM'S SHELF — the colony's first ground-gear stock (SALVAGE tier, docs/ground_combat.md).
## Clean factory pieces; the affixed versions come off scrit. Only his counter stocks
## equipment — Imari is the Elder, not a shopkeep.
const BRAM_GEAR: Array = [
	"res://data/ground/dune_rifle.tres",
	"res://data/ground/scrap_buckler.tres",
	"res://data/ground/rag_hood.tres",
	"res://data/ground/work_gloves.tres",
	"res://data/ground/surveyor_belt.tres",
]


func _open_shop(npc: String) -> void:
	var ship := _player_ship()
	if ship == null:
		return
	Tutor.did("used_market")   # a ground shop IS the market lesson, satisfied spatially
	set_active(false)
	var shop := ShopView.new(npc, TradeGoods.PLANET_MARKET, ship,
		BRAM_GEAR if npc == "bram" else [])
	shop.closed.connect(func() -> void: set_active(true))
	add_child(shop)


## Open a contract board over the town. `npc` = whose board ("" for the colony kiosk).
func _open_board(npc: String) -> void:
	var ship := _player_ship()
	if ship == null:
		return
	Tutor.did("used_mission_uplink")   # reaching the board spatially IS the lesson
	set_active(false)
	var board := BoardView.new(npc, "planet", ship)
	board.closed.connect(func() -> void: set_active(true))
	add_child(board)


## The landing receipt + ship state — the ground-native Starport counter.
func _open_starport() -> void:
	var ship := _player_ship()
	if ship == null:
		return
	Tutor.did("used_landing_pad")
	set_active(false)
	var view := StarportView.new(ship)
	view.closed.connect(func() -> void: set_active(true))
	view.launch_requested.connect(func() -> void:
		view.close()
		_do_action("launch"))
	add_child(view)


## The hull whose hold/manifest these counters act on. Ground views are useless without
## it, so say so rather than opening an empty panel.
func _player_ship() -> Node:
	var ship := get_tree().get_first_node_in_group("player_ship")
	if ship == null:
		_flash("Your ship's manifest is out of reach from here.", 2.0)
	return ship


# ---------------------------------------------------------------- interior

func _rebuild_town_spots() -> void:
	_spots = [
		# The launch prompt lives ON THE APRON now, at your actual parked ship — you board
		# the thing you can see. (The Starport counter still offers a lift-off button, so
		# the older route in and the tutorial's "return to the spaceport" both still work.)
		{"pos": PAD_CENTER, "range": 230, "prompt": "[E] Board your ship and launch", "action": "launch"},
		{"pos": Vector2(0, 900), "range": 165, "prompt": "[E] Starport services", "action": "starport"},
		{"pos": Vector2(560, 430), "range": 160, "prompt": "[E] Enter the colony market", "action": "enter:MARKET"},
		{"pos": Vector2(-640, 480), "range": 160, "prompt": "[E] Take work from the colony contract board", "action": "board:"},
		{"pos": Vector2(-800, -110), "range": 170, "prompt": "[E] Enter the Explorer's Union", "action": "enter:EXPLORERS GUILD"},
		{"pos": Vector2(-560, -340), "range": 150, "prompt": "[E] Enter the aquaponics farm", "action": "enter:AQUAPONICS"},
		{"pos": Vector2(-360, 15), "range": 140, "prompt": "[E] Sealed hab", "action": "sealed"},
		{"pos": Vector2(2100, -1790), "range": 175, "prompt": "[E] Enter the cave", "action": "enter:?"},
	]
	# NPCs point at their stored action (the same one the approach uses); unmapped = flavor line.
	for n in _npcs:
		var act: String = str(n.action) if str(n.action) != "" else "talk_" + str(n.name)
		_spots.append({"node": n.node, "range": 130, "npc": str(n.name),
			"prompt": "[E] Speak with %s" % n.name, "action": act})


func _enter_interior(id: String) -> void:
	if not INTERIORS.has(id):
		return
	var def: Dictionary = INTERIORS[id]
	_interior_id = id
	# OWN ESC WHILE INDOORS (user, 2026-07-26: "it says esc to leave but you have to
	# walk to the edge and press E"). Esc WAS wired -- _poll_actions calls
	# _exit_interior -- but the pause menu is added last in flight precisely so it
	# sees Esc first, and it only stands down for something in "esc_capture". The
	# interior was not in it, so Esc opened the menu, the menu paused the tree, and
	# the town's poll never ran. The prompt described the intent correctly and the
	# result not at all. Every panel that owns Esc does this; the room is a panel too.
	add_to_group("esc_capture")
	if _weather != null:
		_weather.visible = false   # no sandstorm inside a greenhouse
	var half: Vector2 = def.get("half", IROOM_HALF)
	for n in _npcs:
		n.node.visible = false
	_player.stop()
	_player.global_position = IROOM + Vector2(0, half.y - 70)
	_player.face("north")
	_spots = []
	# Who's home — a room may have its own resident actor (the hermit, Tam the farmhand).
	# Frame the ROOM: the entry stands at the south wall and rooms extend north, so an
	# unshifted camera showed the room crammed at the top of the screen over a void
	# (user). Bias the view up while inside; restored on exit.
	_set_cam_offset(Vector2(0, -half.y * 0.55))
	if id == "?" and _cave_wrecked():
		_spawn_cave_scavengers()
		_wake_cave_scavengers()
	# CAMPAIGN BEAT 2: the cave is a crime scene while the beat runs. Its resident is
	# GONE (that is the beat), the room announces itself differently, and the scrit
	# already inside come up out of the dark the moment you are in with them.
	var wrecked: bool = id == "?" and _cave_wrecked()
	if wrecked:
		var w: Dictionary = def.get("wrecked", {})
		if w.has("flash"):
			def = def.duplicate()
			def["flash"] = w["flash"]
			def["title"] = str(w.get("title", def.get("title", "")))
	var actor := _interior_actor(def)
	if wrecked:
		actor = null   # nobody home — no resident, no [E] to speak with him
	if actor != null:
		actor.visible = true
		actor.stop()
		actor.global_position = IROOM + def.get("actor_pos", Vector2.ZERO)
		actor.face("south")
		var aspot: Dictionary = def.get("actor_spot", {}).duplicate()
		aspot["node"] = actor
		aspot["range"] = 150
		_spots.append(aspot)
	for extra in def.get("extra_spots", []):
		var e: Dictionary = extra.duplicate()
		e["pos"] = IROOM + e["pos"]
		_spots.append(e)
	_spots.append({"pos": IROOM + Vector2(0, half.y - 30), "range": 150,
		"prompt": str(def.get("exit_prompt", "[E] Leave")), "action": "leave"})
	_flash(str(def.get("flash", "")), 1.8)


## The resident of the current room (null = an empty room). "hermit"/"farmhand"/"trader"
## are DEDICATED interior actors; any other name is a TOWN NPC who steps inside with you
## (Sella at her Union) — _exit_interior returns them to their street haunt.
func _interior_actor(def: Dictionary) -> GroundCharacter:
	match str(def.get("actor", "")):
		"hermit":
			return _hermit
		"farmhand":
			return _farmhand
		"trader":
			return _trader
	for n in _npcs:
		if str(n.name) == str(def.get("actor", "")):
			return n.node
	return null


func _set_cam_offset(ofs: Vector2) -> void:
	for c in _player.get_children():
		if c is Camera2D:
			(c as Camera2D).offset = ofs


func _exit_interior() -> void:
	var def: Dictionary = INTERIORS.get(_interior_id, {})
	_interior_id = ""
	# Hand Esc back, or the pause menu could never open again on foot.
	remove_from_group("esc_capture")
	if _weather != null:
		_weather.visible = true
	_hermit.visible = false
	_farmhand.visible = false
	_trader.visible = false
	for n in _npcs:
		n.node.visible = true
		# A town NPC who hosted you inside steps back out to their street haunt —
		# without this, Sella would be left standing in the far-off room space.
		if str(def.get("actor", "")) == str(n.name):
			n.node.global_position = n.home
			n.node.stop()
	_player.stop()
	_player.global_position = def.get("exit_pos", Vector2(2100, -1720))
	_player.face("south")
	_set_cam_offset(Vector2.ZERO)
	_rebuild_town_spots()


func _flash(msg: String, secs: float) -> void:
	_flash_msg = msg
	_flash_t = secs


# ---------------------------------------------------------------- rendering
## Film-noir dusk: a low SW sun, so everything throws a long shadow to the NE. Procedural
## for now (drop-in PixelLab sprites layer over this later, per the WayGate/anomaly seam).

const SHADOW_COL := Color(0.09, 0.06, 0.12, 0.22)   # cool shadow against warm sand
const SAND := Color(0.70, 0.54, 0.38)
const WINDOW := Color(1.0, 0.72, 0.34)               # lit at dusk
const B_OFS := Vector2(34, -20)                      # building drop-shadow (small — a flat roof on sand)
const A_OFS := Vector2(36, -22)                      # actor shadow offset


func _build_dusk() -> void:
	var cm := CanvasModulate.new()
	cm.color = Color(0.93, 0.75, 0.60)   # warm golden-hour cast over everything
	add_child(cm)
	# Screen-space vignette for the noir framing — behind the HUD text, over the world.
	var vig := TextureRect.new()
	vig.texture = _vignette_tex()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	$HUD.add_child(vig)
	$HUD.move_child(vig, 0)


## Ambient blowing sand: dust wisps drift across the screen on the wind. Screen-space (on
## the HUD, behind the vignette) so it always reads regardless of where the camera is. A
## full storm EVENT can crank amount/velocity/alpha off this same emitter later.
func _build_weather() -> void:
	var tex := _load_tex("res://assets/ground/fx/dust_wisp.png")
	if tex == null:
		return
	var p := CPUParticles2D.new()
	_weather = p
	p.texture = tex
	p.amount = 14
	p.lifetime = 7.0
	p.preprocess = 7.0            # start mid-stream so the screen isn't bare on arrival
	p.local_coords = false
	p.position = Vector2(-160, 540)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(40, 720)
	p.direction = Vector2(1, 0.15)
	p.spread = 12.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 250.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.4
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([
		Color(0.86, 0.76, 0.56, 0.0), Color(0.86, 0.76, 0.56, 0.22), Color(0.86, 0.76, 0.56, 0.0)])
	p.color_ramp = g
	$HUD.add_child(p)
	$HUD.move_child(p, 0)   # behind the vignette + labels


func _vignette_tex() -> Texture2D:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / (c * 1.16)
			img.set_pixel(x, y, Color(0.02, 0.01, 0.05, clampf((d - 0.55) / 0.45, 0.0, 1.0) * 0.6))
	return ImageTexture.create_from_image(img)


## Spawn a base-anchored sprite for every building that has drop-in art. The node sits at
## the footprint's south edge, so y-sorting occludes the player correctly against a 3/4
## building's height. Art-less buildings fall through to the procedural box in _draw.
func _build_buildings() -> void:
	for b in BUILDINGS:
		var key: String = BUILDING_ART.get(b.name, "")
		var tex := _load_tex("res://assets/ground/buildings/%s.png" % key) if key != "" else null
		if tex == null:
			_add_building_body(b, {})   # no art: the procedural box IS the footprint
			continue
		var base: Vector2 = b.pos + Vector2(0, b.size.y * 0.5)
		var tint: Color = Color(0.55, 0.55, 0.62) if b.name == "SEALED" else Color.WHITE
		var pair := _spawn_prop(tex, base, b.size.x * 1.25, tint, true)
		pair["name"] = str(b.name)
		_shadow_pairs.append(pair)
		_art[b.name] = true
		# THE COLLIDER IS MEASURED FROM THE ART, not the old procedural footprint — the
		# two disagreed, which is why you bumped into nothing and walked through walls.
		_add_building_body(b, pair)


## Place a base-anchored art prop in the y-sorted world: pivots on its WIDEST base row so it
## sits on the sand, and (if cast_shadow) drops the same projected shadow the buildings use —
## which then touches at the base corners (see test_ground_shadow). Used by buildings AND the
## scattered rocks/dunes. Returns the sprite/shadow pair + base-corner columns for the test.
func _spawn_prop(tex: Texture2D, base_pos: Vector2, target_w: float, tint: Color, cast_shadow: bool) -> Dictionary:
	var img := tex.get_image()
	if img != null and img.is_compressed():
		img.decompress()
	var br: Dictionary = _base_row(img) if img != null else {
		"y": tex.get_height(), "left": 0, "right": tex.get_width(), "center": tex.get_width() * 0.5}
	var off := ArtAnchor.base_offset(br)
	var sc: float = target_w / float(tex.get_width())
	var shd: Sprite2D = null
	if cast_shadow:
		shd = Sprite2D.new()
		shd.texture = tex
		shd.centered = false
		shd.offset = off
		shd.position = base_pos
		shd.scale = Vector2(sc * GroundCharacter.SHADOW_SCALE.x, sc * GroundCharacter.SHADOW_SCALE.y)
		shd.skew = GroundCharacter.SHADOW_SKEW
		shd.modulate = GroundCharacter.SHADOW_TINT
		_world.add_child(shd)   # before the sprite -> drawn behind it
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.scale = Vector2(sc, sc)
	spr.offset = off
	spr.position = base_pos
	spr.modulate = tint
	_world.add_child(spr)
	return {"spr": spr, "shd": shd, "y": int(br.y), "left": int(br.left), "right": int(br.right),
		"scale": sc, "base": base_pos}


## Scatter rocks + dunes across the OPEN ROAM (the ring of dust between the town and the heat
## boundary), drop-in from assets/ground/props/<key>.png. Seeded, so the field is stable.
func _scatter_props() -> void:
	# `solid` = you bump into it. `spread` = how much elbow room it claims, as a fraction of
	# its width: rock stands well apart (its shadow must not touch another's), while a dune
	# is flat sand that can nestle close without reading as clutter.
	var defs := [
		{"key": "boulders", "w": 240.0, "shadow": true, "solid": true, "spread": 0.55,
			"tint": Color.WHITE},
		{"key": "mesa", "w": 380.0, "shadow": true, "solid": true, "spread": 0.55,
			"tint": Color.WHITE},
		# Dunes are just piled sand — tint them down toward the ground so they don't glare.
		{"key": "dune", "w": 480.0, "shadow": false, "solid": false, "spread": 0.34,
			"tint": Color(0.80, 0.70, 0.55)},
	]
	var avail: Array = []
	for d in defs:
		var t := _load_tex("res://assets/ground/props/%s.png" % d.key)
		if t != null:
			avail.append({"tex": t, "key": str(d.key), "w": float(d.w), "shadow": bool(d.shadow),
				"solid": bool(d.get("solid", false)), "spread": float(d.spread),
				"tint": d.tint})
	if avail.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 42317
	for i in 30:
		var d: Dictionary = avail[rng.randi() % avail.size()]
		var w: float = float(d.w) * rng.randf_range(0.7, 1.35)
		var pos := _prop_spot(rng, 1500.0, HEAT_LIMIT - 260.0, w * float(d.spread))
		if is_inf(pos.x):
			continue   # the field is full here; skip rather than stack one on another
		var pair := _spawn_prop(d.tex, pos, w, d.tint, bool(d.shadow))
		if bool(d.shadow):
			pair["name"] = "prop"
			_shadow_pairs.append(pair)
		# Rock is SOLID (user: props had no colliders at all). Dunes are drifts you walk
		# over, so they stay passable — `solid` says which is which.
		if bool(d.get("solid", false)):
			_add_prop_body(pair, str(d.key))

	# Ambient small boulders across the mid + far field — these REPLACE the old procedural
	# pebbles (whose fake ellipse shadow pointed the wrong way). Real pixel boulders with the
	# correct projected shadow, kept clear of the town's buildings AND of each other.
	var boulder := _load_tex("res://assets/ground/props/boulders.png")
	if boulder != null:
		var brng := RandomNumberGenerator.new()
		brng.seed = 771
		for i in 40:
			var w: float = brng.randf_range(55.0, 130.0)
			var pos := _prop_spot(brng, 1000.0, HEAT_LIMIT - 140.0, w * 0.55)
			if is_inf(pos.x):
				continue
			_add_prop_body(_spawn_prop(boulder, pos, w, Color.WHITE, true), "boulders")


## Breathing room between two props, on top of their own radii — touching art reads as one
## clumsy blob even when it isn't overlapping.
const PROP_GAP := 26.0
## How many times to re-roll a position before giving up on a prop entirely.
const PROP_TRIES := 24

## Every prop already placed, as {pos, r} — the declutter pass tests against this.
var _placed_props: Array = []


## Find somewhere in the roam ring this prop actually FITS: clear of every prop already
## placed and of every building. Vector2.INF if the field is too crowded to take it.
##
## WHY (user, 2026-07-25): the scatter placed props at pure random with NO checks at all —
## so art overlapped art and, because each prop casts its own projected shadow, two
## overlapping props stacked TWO darkenings into a confusing blot. It also let props sit on
## top of buildings (only the boulder pass tested for that, and only against b.pos). One
## helper now enforces both, for every prop.
func _prop_spot(rng: RandomNumberGenerator, min_d: float, max_d: float, radius: float) -> Vector2:
	for _try in PROP_TRIES:
		var a := rng.randf() * TAU
		var dist := rng.randf_range(min_d, max_d)
		var pos := Vector2(cos(a), sin(a)) * dist
		if _prop_clear(pos, radius):
			_placed_props.append({"pos": pos, "r": radius})
			return pos
	return Vector2.INF


func _prop_clear(pos: Vector2, radius: float) -> bool:
	for p in _placed_props:
		if pos.distance_to(p.pos) < radius + float(p.r) + PROP_GAP:
			return false
	for b in BUILDINGS:
		# Buildings draw 1.25x their footprint, so clear the ART's half-width, not the box's.
		var half: float = maxf(b.size.x, b.size.y) * 0.75
		if pos.distance_to(b.pos) < radius + half + PROP_GAP:
			return false
	# THE APRON IS SWEPT GROUND. Nothing scatters onto a working berth — the first pass
	# dropped a stack of crates inside the painted box, which read as the pad being
	# derelict rather than the colony's live front door.
	if Rect2(PAD_CENTER - PAD_SIZE * 0.5, PAD_SIZE).grow(radius + PROP_GAP).has_point(pos):
		return false
	return true


## How deep a building's ground footprint is, as a fraction of its drawn base width. A 3/4
## sprite can't tell us how far "back" the building goes, so we assume a roughly square
## footprint standing behind its front edge.
const FOOTPRINT_DEPTH := 0.55
## Shave the collider slightly inside the art so corners feel forgiving rather than sticky.
const FOOTPRINT_INSET := 0.94


## The solid a building presents to walkers.
##
## THE BUG THIS FIXES (user, 2026-07-25): the collider was built from the BUILDINGS
## footprint (`pos` centred, `size` × 0.82/0.72) while the ART is spawned base-anchored at
## the footprint's SOUTH edge and 1.25× as wide. So the solid was only ~66% of the drawn
## width and sat ~14% of the height BEHIND the visible base — you bumped into nothing in
## front of a wall and walked through its edges. Measuring the collider off the SPRITE
## keeps the two in agreement no matter what art drops in.
##
## `pair` is a _spawn_prop result (empty for art-less buildings, which keep the old box —
## there the procedural footprint IS what's drawn, so it was never wrong).
func _add_building_body(b: Dictionary, pair: Dictionary) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	# A HAND-AUTHORED polygon wins over the measurement (see collider_points): open
	# scenes/ground/colliders/<art key>.tscn and drag the points to match the art exactly.
	var art_key: String = BUILDING_ART.get(str(b.name), "")
	var pts := collider_points(art_key) if (art_key != "" and not pair.is_empty()) \
		else PackedVector2Array()
	if not pts.is_empty():
		body.position = pair["base"]
		var poly := CollisionPolygon2D.new()
		var sc: float = float(pair["scale"])
		var scaled := PackedVector2Array()
		for p in pts:
			scaled.append(p * sc)
		poly.polygon = scaled
		body.add_child(poly)
		body.set_meta("building", str(b.name))
		add_child(body)
		return
	var shape := RectangleShape2D.new()
	if pair.is_empty():
		body.position = b.pos
		shape.size = Vector2(b.size.x * 0.82, b.size.y * 0.72)
	else:
		# The art's own base line: its width, and its front edge, in world units.
		var sc: float = float(pair["scale"])
		var base: Vector2 = pair["base"]
		var w: float = (float(pair["right"]) - float(pair["left"])) * sc
		var depth: float = w * FOOTPRINT_DEPTH
		shape.size = Vector2(w * FOOTPRINT_INSET, depth)
		# Front edge ON the drawn base, footprint standing BEHIND it (north).
		body.position = base + Vector2(0.0, -depth * 0.5)
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	body.set_meta("building", str(b.name))
	add_child(body)


## HAND-AUTHORED COLLIDER SHAPES (user, 2026-07-25 — "can I adjust the point data of the
## polygon in the Godot UI?"). Drop a scene at `scenes/ground/colliders/<key>.tscn` holding
## a CollisionPolygon2D and its points REPLACE the measured rectangle for that art. Points
## are authored in SOURCE-PIXEL space relative to the art's BASE ANCHOR (origin = the
## middle of the sprite's base line, +y down/toward the viewer), which is exactly what the
## authoring scene shows you, so what you drag is what you get at any prop scale.
##
## Generate the starter scenes with:
##   <godot> --headless --path . --script res://tools/make_collider_scenes.gd
## then open one in the editor and drag the points. No code, no re-generation needed —
## missing file = the automatic rectangle, unchanged.
const COLLIDER_DIR := "res://scenes/ground/colliders/%s.tscn"

static var _poly_cache := {}


## Points for a hand-authored collider, in source-pixel space, or [] if none exists.
static func collider_points(key: String) -> PackedVector2Array:
	if _poly_cache.has(key):
		return _poly_cache[key]
	var pts := PackedVector2Array()
	var path := COLLIDER_DIR % key
	if ResourceLoader.exists(path):
		var packed: PackedScene = load(path)
		var inst := packed.instantiate()
		for c in inst.get_children():
			if c is CollisionPolygon2D:
				pts = (c as CollisionPolygon2D).polygon
				break
		inst.queue_free()
	_poly_cache[key] = pts
	return pts


## The same art-measured footprint, for a scattered prop (rock, mesa). Props had NO
## colliders at all — you walked straight through a boulder the size of a hab (user).
## Dunes stay passable; only `solid` props get one. A hand-authored polygon wins.
func _add_prop_body(pair: Dictionary, key := "") -> void:
	if pair.is_empty():
		return
	var sc: float = float(pair["scale"])
	var base: Vector2 = pair["base"]
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var pts := collider_points(key) if key != "" else PackedVector2Array()
	if not pts.is_empty():
		# Authored in source pixels about the base anchor: just scale to this instance.
		body.position = base
		var poly := CollisionPolygon2D.new()
		var scaled := PackedVector2Array()
		for p in pts:
			scaled.append(p * sc)
		poly.polygon = scaled
		body.add_child(poly)
	else:
		var w: float = (float(pair["right"]) - float(pair["left"])) * sc
		var depth: float = w * FOOTPRINT_DEPTH
		body.position = base + Vector2(0.0, -depth * 0.5)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(w * FOOTPRINT_INSET, depth)
		var col := CollisionShape2D.new()
		col.shape = shape
		body.add_child(col)
	add_child(body)


func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is Texture2D:
			return r
	if not FileAccess.file_exists(path):
		return null   # art not dropped in yet — fall back to the procedural box, quietly
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null


## The sprite's ground-CONTACT ROW: the WIDEST opaque row in the lower part of the sprite —
## its left/right ends are the base's outer corners (for a 3/4 cube, the left + right points
## of the base diamond). The shadow flips about THIS row, so those two corners stay fixed and
## the shadow touches the sprite there (no gap = not floating). Returns {y, left, right, center}.
## The art's base line. Delegates to the SHARED measurement (ArtAnchor) so the collider
## authoring tool anchors polygons to exactly the row the game places them against.
func _base_row(img: Image) -> Dictionary:
	return ArtAnchor.base_row(img)


func _draw() -> void:
	if _interior_id != "":
		_draw_interior()
	else:
		_draw_town()


func _draw_town() -> void:
	_draw_ground()
	_draw_apron()   # painted onto the ground, under every sprite and shadow
	# All cast shadows FIRST, so no body ever gets a shadow drawn over it. Buildings with
	# real art carry their OWN painted shadow (baked into the sprite in Aseprite) — only the
	# procedural-box fallbacks get an engine shadow.
	for b in BUILDINGS:
		if not _art.get(b.name, false):
			_building_shadow(Rect2(b.pos - b.size * 0.5, b.size), B_OFS)
	_spire_shadow(Vector2(300, -560))
	# Character shadows are BAKED into the sprites (animated, painted in Aseprite) — the
	# engine no longer draws them.
	# Then the ground-layer bodies (art buildings + actors are y-sorted nodes in _world).
	for b in BUILDINGS:
		_draw_building(b)
	_draw_spire(Vector2(300, -560))
	# NAMES, HEALTH BARS AND THE TARGET RING ALL MOVED TO THE NAMEPLATE (2026-07-27).
	# Three separate draws lived here — an unconditional name over every NPC, a world-space
	# hp bar over every fighter, and a ring under the target — each with its own idea of
	# when to show and what colour to be. The plate is one answer, distance-gated and
	# colour-coded by relationship, and it travels to any ground scene because it hangs off
	# the character rather than off this town's draw loop.

	# Guide nudge: a soft chevron over the pilot pointing toward the current objective — a ground
	# lesson's target, or whoever the quest system wants you to talk to.
	var obj := _current_objective_pos()
	if not is_inf(obj.x) and _player.global_position.distance_to(obj) > 150.0:
		_draw_nudge((obj - _player.global_position).normalized())


## THE LANDING APRON — compacted blast-scarred ground with a painted berth. Drawn with
## the GROUND (under every sprite) so the parked hull and the walker both stand on it.
## Sized by PAD_SIZE, which fits a SUPER_HEAVY: the empty margin around a small starter
## ship is the point, not a mistake — it's a berth waiting for a bigger hull.
func _draw_apron() -> void:
	var rect := Rect2(PAD_CENTER - PAD_SIZE * 0.5, PAD_SIZE)
	draw_rect(rect, Color(0.34, 0.29, 0.26))                       # scorched hardstand
	draw_rect(rect.grow(-16.0), Color(0.38, 0.33, 0.29))           # inner slab
	draw_rect(rect, Color(0.86, 0.72, 0.42, 0.55), false, 4.0)     # painted edge
	# Hazard chevrons along the north lip — the side you walk in from.
	var y := rect.position.y + 8.0
	var x := rect.position.x + 24.0
	while x < rect.end.x - 40.0:
		draw_line(Vector2(x, y), Vector2(x + 22.0, y + 16.0), Color(0.90, 0.75, 0.40, 0.45), 5.0)
		x += 46.0
	# Corner brackets, the universal "set it down inside this" mark.
	var arm := 74.0
	for c in [[rect.position, 1.0, 1.0], [Vector2(rect.end.x, rect.position.y), -1.0, 1.0],
			[Vector2(rect.position.x, rect.end.y), 1.0, -1.0], [rect.end, -1.0, -1.0]]:
		var p: Vector2 = c[0] + Vector2(18.0 * float(c[1]), 18.0 * float(c[2]))
		draw_line(p, p + Vector2(arm * float(c[1]), 0), Color(0.93, 0.80, 0.48, 0.75), 5.0)
		draw_line(p, p + Vector2(0, arm * float(c[2])), Color(0.93, 0.80, 0.48, 0.75), 5.0)
	# Touchdown cross at the berth's centre, where the ship actually sits.
	draw_line(PAD_CENTER - Vector2(52, 0), PAD_CENTER + Vector2(52, 0), Color(0.88, 0.74, 0.44, 0.30), 3.0)
	draw_line(PAD_CENTER - Vector2(0, 52), PAD_CENTER + Vector2(0, 52), Color(0.88, 0.74, 0.44, 0.30), 3.0)


func _draw_ground() -> void:
	draw_rect(Rect2(Vector2(-7000, -7000), Vector2(14000, 14000)), SAND)
	# Dune banding — subtle light/dark stripes so the sand isn't a flat sheet.
	for i in 22:
		var y := -7000.0 + i * 640.0
		var tint := SAND.lightened(0.05) if i % 2 == 0 else SAND.darkened(0.06)
		draw_rect(Rect2(Vector2(-7000, y), Vector2(14000, 320)), Color(tint.r, tint.g, tint.b, 0.35))
	# (Center square + rocks were procedural MVP bits — removed; buildings + real props stand in.)
	# Heat haze at the world's edge (the "too hot" telegraph).
	for k in 3:
		draw_arc(CENTER, HEAT_LIMIT - k * 60.0, 0, TAU, 96,
			Color(0.78, 0.32, 0.18, 0.10 + k * 0.05), 6.0)


func _draw_building(b: Dictionary) -> void:
	# A real sprite stands in _world for this one — just tag it beneath its base.
	if _art.get(b.name, false):
		if b.name != "" and b.name != "?":
			draw_string(_font, Vector2(b.pos.x - b.size.x * 0.5, b.pos.y + b.size.y * 0.5 + 30),
				b.name, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 14, Color(0.95, 0.9, 0.8, 0.6))
		return
	var sz: Vector2 = b.size
	var half: Vector2 = sz * 0.5
	var rect := Rect2(b.pos - half, sz)
	var col: Color = b.color
	if b.name == "AQUAPONICS":
		draw_circle(b.pos, half.length() * 0.95, Color(0.25, 0.95, 0.45, 0.12))   # biodome glow
	draw_rect(rect, col)   # flat roof
	draw_rect(Rect2(b.pos - half * 0.62, sz * 0.62), col.lightened(0.07))          # inset panel
	# Sunlit SW rim (the low sun catches the left + bottom edges).
	draw_line(rect.position, Vector2(rect.position.x, rect.end.y), Color(1.0, 0.82, 0.5, 0.45), 2.0)
	draw_line(Vector2(rect.position.x, rect.end.y), rect.end, Color(1.0, 0.82, 0.5, 0.28), 2.0)
	draw_rect(rect, Color(0, 0, 0, 0.5), false, 2.0)
	draw_rect(Rect2(b.pos.x - 12, rect.end.y - 4, 24, 16), Color(0.08, 0.07, 0.10))  # door
	# Lit windows along the top (dusk = lights on); a sealed hab reads cold + dark.
	var win: Color = WINDOW if b.name != "SEALED" else Color(0.20, 0.20, 0.24)
	var count := int(sz.x / 46.0)
	for i in count:
		draw_rect(Rect2(rect.position.x + 20.0 + i * 46.0, rect.position.y + 8.0, 12, 9), win)
	if b.name != "":
		draw_string(_font, Vector2(rect.position.x + 8, b.pos.y + 5), b.name,
			HORIZONTAL_ALIGNMENT_CENTER, sz.x - 16, 15, Color(0.97, 0.94, 0.86, 0.92))


func _cast_ellipse(base: Vector2, ofs: Vector2, r: float) -> void:
	var dir := ofs.normalized() if ofs.length() > 0.1 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var center := base + ofs * 0.5
	var along := ofs.length() * 0.5 + r
	var pts := PackedVector2Array()
	for i in 16:
		var a := float(i) / 16.0 * TAU
		pts.append(center + dir * (cos(a) * along) + perp * (sin(a) * r * 0.7))
	draw_colored_polygon(pts, SHADOW_COL)


func _building_shadow(rect: Rect2, ofs: Vector2) -> void:
	# A soft ground ellipse hugging the footprint base — reads as a shadow under any
	# building shape (round dome, boxy hab) instead of a hard rectangle sticking out.
	var base := Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y - 12.0)
	_cast_ellipse(base, ofs, rect.size.x * 0.44)


func _spire_shadow(pos: Vector2) -> void:
	var far := Vector2(190, -114)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-14, 4), pos + Vector2(14, 4),
		pos + Vector2(14, 4) + far, pos + Vector2(-14, 4) + far]), SHADOW_COL)


func _draw_spire(pos: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-14, 0), pos + Vector2(14, 0),
		pos + Vector2(8, -300), pos + Vector2(-8, -300)]), Color(0.44, 0.44, 0.5))
	draw_line(pos + Vector2(-14, 0), pos + Vector2(-8, -300), Color(1.0, 0.82, 0.5, 0.5), 2.0)
	draw_circle(pos + Vector2(0, -300), 22, Color(1.0, 0.7, 0.3, 0.25))
	draw_circle(pos + Vector2(0, -300), 12, Color(1.0, 0.85, 0.5))


## One generic room shell (floor + walls + title from the INTERIORS def), then per-room
## DRESSING so each place has a face. Procedural for now — drop-in interior art is a later
## seam, same as the buildings got.
## The combat readouts (thin hp bars, the amber target ring) — shared by the open town
## and the interiors. It lived inside _draw_town only, so the cave fight had no health
## bars and no target marker at all (playtest); a fight indoors is still a fight.
func _draw_interior() -> void:
	_draw_room()


func _draw_room() -> void:
	var def: Dictionary = INTERIORS.get(_interior_id, {})
	var half: Vector2 = def.get("half", IROOM_HALF)
	var rect := Rect2(IROOM - half, half * 2.0)
	match _interior_id:
		"AQUAPONICS":
			_dress_aquaponics(rect)
		"MARKET":
			_dress_market(rect)
		"EXPLORERS GUILD":
			_dress_guild(rect)
		_:
			_dress_cave(rect)
	draw_string(_font, IROOM + Vector2(-half.x + 20, -half.y + 30),
		str(def.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, 700, 18,
		Color(0.9, 0.82, 0.62))


func _dress_cave(rect: Rect2) -> void:
	draw_rect(rect, Color(0.20, 0.16, 0.14))                      # dark earth floor
	draw_rect(rect, Color(0.10, 0.08, 0.07), false, 16.0)         # rough rock walls
	draw_rect(rect.grow(-8), Color(0.26, 0.20, 0.17), false, 6.0)
	for k in 3:
		draw_circle(IROOM + Vector2(0, -110), 210 - k * 40, Color(0.95, 0.7, 0.38, 0.06))
	draw_circle(IROOM + Vector2(0, -110), 8, Color(1.0, 0.8, 0.45))   # the lamp


## Sella's map room: the Reach in pencil and pins — and the HOLES, which are the point.
## Blank chart panels with a "?" are what she pays pilots to fill; the room says her whole
## deal without a line of dialogue.
func _dress_guild(rect: Rect2) -> void:
	draw_rect(rect, Color(0.21, 0.19, 0.16))                      # dusty plank floor
	draw_rect(rect, Color(0.10, 0.09, 0.08), false, 14.0)
	draw_rect(rect.grow(-7), Color(0.33, 0.29, 0.23), false, 4.0)
	# The chart wall along the north: paper rects, some INKED, some blank holes.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331   # stable wall — the same charts every visit
	for i in 6:
		var c := Rect2(IROOM + Vector2(-350 + i * 118, -260), Vector2(100, 74))
		var known := i % 2 == 0
		draw_rect(c, Color(0.82, 0.76, 0.62) if known else Color(0.30, 0.27, 0.23))
		draw_rect(c, Color(0.16, 0.13, 0.10), false, 2.0)
		if known:
			# Pencil squiggles + a pin.
			for k in 3:
				var y := c.position.y + 16 + k * 18
				draw_line(Vector2(c.position.x + 8, y),
					Vector2(c.position.x + 30 + rng.randf() * 55, y + rng.randf_range(-6, 6)),
					Color(0.35, 0.32, 0.3), 1.5)
			draw_circle(c.position + Vector2(14 + rng.randf() * 70, 14 + rng.randf() * 44),
				3.0, Color(0.85, 0.3, 0.25))
		else:
			draw_string(_font, c.position + Vector2(40, 46), "?",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.55, 0.5, 0.42))
	# Her chart table, mid-room — a big working map weighted at the corners.
	var tbl := Rect2(IROOM + Vector2(-140, -60), Vector2(280, 130))
	draw_rect(tbl, Color(0.36, 0.30, 0.22))
	draw_rect(tbl, Color(0.14, 0.11, 0.09), false, 3.0)
	draw_rect(tbl.grow(-14), Color(0.80, 0.74, 0.60))
	draw_arc(tbl.get_center(), 30.0, 0, TAU, 24, Color(0.4, 0.36, 0.32), 1.2)
	draw_arc(tbl.get_center() + Vector2(40, -10), 16.0, 0, TAU, 18, Color(0.4, 0.36, 0.32), 1.2)
	for corner in [tbl.grow(-14).position, tbl.grow(-14).end - Vector2(8, 8)]:
		draw_circle(corner + Vector2(4, 4), 5.0, Color(0.5, 0.48, 0.5))
	# Shelf of rolled charts by the postings board.
	for i in 4:
		draw_line(IROOM + Vector2(190 + i * 18, -210), IROOM + Vector2(196 + i * 18, -160),
			Color(0.72, 0.66, 0.52), 7.0)


## Sella's farm: rows of fish tanks under grow-racks, everything faintly green and wet.
func _dress_aquaponics(rect: Rect2) -> void:
	draw_rect(rect, Color(0.16, 0.20, 0.17))                      # damp deck plating
	draw_rect(rect, Color(0.08, 0.11, 0.09), false, 14.0)         # greenhouse frame
	draw_rect(rect.grow(-7), Color(0.24, 0.34, 0.26), false, 4.0)
	# Green wash — the grow-lights that make the dome glow from outside.
	draw_rect(rect.grow(-20), Color(0.35, 0.75, 0.42, 0.06))
	# Three tank rows along the west side, water shimmering.
	for i in 3:
		var t := Rect2(IROOM + Vector2(-330, -220 + i * 130), Vector2(240, 84))
		draw_rect(t, Color(0.10, 0.22, 0.30))                     # tank body
		draw_rect(t, Color(0.30, 0.44, 0.52), false, 3.0)
		draw_rect(Rect2(t.position + Vector2(6, 6), Vector2(228, 40)),
			Color(0.22, 0.52, 0.62, 0.85))                        # water
		# A couple of silverfin, frozen mid-circle.
		draw_circle(t.position + Vector2(60 + i * 40, 24), 5.0, Color(0.85, 0.9, 0.95, 0.9))
		draw_circle(t.position + Vector2(150 - i * 30, 30), 4.0, Color(0.75, 0.85, 0.9, 0.8))
	# Grow racks along the east: green rows on shelf lines.
	for i in 4:
		var y := -210.0 + i * 110.0
		draw_line(IROOM + Vector2(120, y + 22), IROOM + Vector2(350, y + 22),
			Color(0.30, 0.26, 0.20), 5.0)
		for g in 6:
			draw_circle(IROOM + Vector2(140 + g * 38, y + 10), 9.0, Color(0.34, 0.62, 0.30))
			draw_circle(IROOM + Vector2(146 + g * 38, y + 4), 6.0, Color(0.45, 0.75, 0.38))
	# A feed pipe with a slow drip.
	draw_line(IROOM + Vector2(-330, -260), IROOM + Vector2(350, -260), Color(0.45, 0.5, 0.55), 4.0)


## Bram's floor: crate stacks, a counter, produce nets — the trade route as a room.
func _dress_market(rect: Rect2) -> void:
	draw_rect(rect, Color(0.23, 0.19, 0.14))                      # worn board floor
	draw_rect(rect, Color(0.11, 0.09, 0.07), false, 14.0)
	draw_rect(rect.grow(-7), Color(0.34, 0.27, 0.19), false, 4.0)
	# Bram's counter — he stands behind it (actor_pos is just north of here).
	draw_rect(Rect2(IROOM + Vector2(-60, -100), Vector2(240, 34)), Color(0.38, 0.30, 0.20))
	draw_rect(Rect2(IROOM + Vector2(-60, -100), Vector2(240, 34)), Color(0.16, 0.12, 0.08), false, 3.0)
	# Crate stacks west (station imports), sacks east (colony grain).
	for i in 3:
		for j in 2 - (i % 2):
			var c := Rect2(IROOM + Vector2(-330 + j * 12, -200 + i * 92), Vector2(74, 60))
			draw_rect(c, Color(0.42, 0.36, 0.28))
			draw_rect(c, Color(0.2, 0.16, 0.11), false, 2.5)
			draw_line(c.position + Vector2(8, 30), c.position + Vector2(66, 30),
				Color(0.2, 0.16, 0.11), 2.0)
	for i in 4:
		draw_circle(IROOM + Vector2(240 + (i % 2) * 46, -40 + (i / 2) * 60), 24.0,
			Color(0.55, 0.48, 0.32))
	# A cooler with the silverfin — Tam's fish, one building over.
	var cool := Rect2(IROOM + Vector2(220, -220), Vector2(120, 60))
	draw_rect(cool, Color(0.72, 0.76, 0.8))
	draw_rect(cool, Color(0.4, 0.48, 0.55), false, 3.0)
