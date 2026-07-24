extends CanvasLayer
## Cockpit dashboard: two consoles along the bottom corners, top edges
## angling down toward the center (the world stays visible through the gap).
##   LEFT  — ship systems: the status effigy (shield ring / armor outline /
##           hull-tinted sprite), flight mode, throttle numbers, the weapons
##           rack (per-mount charge + future offline/destroyed states),
##           missions, keybind hints.
##   RIGHT — situational awareness: target readout + the radar scope.
## Between them: ONE contextual line (docking, scan notes, hold warnings).
## Threat banner stays big and top-center. [Tab] raises the hold manifest
## above the left console. The old top-left text block is retired.

## Layout lives in DATA (user decision): edit data/cockpits/default.json to
## rearrange the dashboard — future hulls/cockpit components point at their
## own layout file. Values below are only the fallback defaults.
const LAYOUT_PATH := "res://data/cockpits/default.json"

@onready var _legacy_info: Label = $Info

var ship: TestShip
var show_hold := false
var _layout := {}
var _panel_h := 170.0
var _floating_target := true

var _banner: Label
var _banner_settings: LabelSettings
var _left: DashPanel
var _right: DashPanel
var _status: StatusEffigy
var _target_effigy: StatusEffigy
var _sys: Label
var comm: CommTerminal
var _speed_gauge: SpeedGauge
var _cargo_gauge: CargoGauge
var _energy_gauge: EnergyGauge
var _ord_gauge: OrdnanceGauge
var _gem_bar: GemBar
var _missions: Label
var _group: GroupOverlay
var _target_info: Label
var _center_note: Label
var _hold_label: Label
var _loot_tip: Label


func _ready() -> void:
	ship = get_tree().get_first_node_in_group("player_ship")
	_legacy_info.visible = false
	if FileAccess.file_exists(LAYOUT_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
		if parsed is Dictionary:
			_layout = parsed
	_panel_h = float(_layout.get("panel_height", 170.0))

	_banner_settings = LabelSettings.new()
	_banner_settings.font_size = 19
	_banner_settings.font_color = UiTheme.DANGER
	_banner_settings.outline_size = 5
	_banner_settings.outline_color = Color(0, 0, 0, 0.9)
	_banner = Label.new()
	_banner.label_settings = _banner_settings
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 34
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_banner)

	var panel_frac := float(_layout.get("panel_frac", 0.46))
	_left = DashPanel.new()
	_left.flat_frac = float(_layout.get("flat_frac", 0.72))
	_left.drop_frac = float(_layout.get("drop_frac", 0.85))
	_left.anchor_top = 1.0
	_left.anchor_bottom = 1.0
	_left.anchor_left = 0.0
	_left.anchor_right = panel_frac
	_left.offset_top = -_panel_h
	add_child(_left)

	_right = DashPanel.new()
	_right.mirrored = true
	_right.flat_frac = _left.flat_frac
	_right.drop_frac = _left.drop_frac
	_right.anchor_top = 1.0
	_right.anchor_bottom = 1.0
	_right.anchor_left = 1.0 - panel_frac
	_right.anchor_right = 1.0
	_right.offset_top = -_panel_h
	add_child(_right)

	_status = StatusEffigy.new()
	_status.subject = ship
	_left.add_child(_status)
	_place(_status, "left", "effigy", [18, 52, 100, 100])
	# The effigy carries HULL/SHIELD/ARMOR (health) AND the reactor pill (energy),
	# so the "vitals" lesson points here to teach both at once.
	Tutor.register("effigy", _status)

	# Slim identity/credits/gems readout (the numeric stats are gauges now).
	# A CRT set into the dash, not a caption floating on it: black screen, green
	# phosphor, faint scanlines. Drawn behind the label by DashTerminal.
	var term := DashTerminal.new()
	_left.add_child(term)
	_place(term, "left", "sys", [216, 100, 118, 46])
	_sys = _panel_label(_left, 12)
	_sys.add_theme_color_override("font_color", Color(0.42, 0.98, 0.55))
	_sys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_sys, "left", "sys", [216, 100, 118, 46])
	_sys.position += Vector2(0, 6)
	# INSTRUMENTS — speed + cargo pair as twin vertical gauges left of the text;
	# ordnance sits right. Defaults mirror data/cockpits/default.json, which WINS
	# when present (edit the json to nudge the layout — no rebuild needed).
	_speed_gauge = SpeedGauge.new()
	_speed_gauge.ship = ship
	_left.add_child(_speed_gauge)
	_place(_speed_gauge, "left", "speed", [132, 58, 26, 96])
	_cargo_gauge = CargoGauge.new()
	_cargo_gauge.ship = ship
	_left.add_child(_cargo_gauge)
	_place(_cargo_gauge, "left", "cargo", [164, 58, 36, 96])
	Tutor.register("cargo_gauge", _cargo_gauge)
	# ENERGY floats near the SHIP (bottom-centre, LEFT of the crosshair) so it's read
	# without looking away mid-fight — energy is the resource abilities live on now.
	# (Ordnance mirrors it on the RIGHT below; guns that drain their own charge will
	# join it there.) Child of the HUD, not the dash panel, for screen-centre anchor.
	_energy_gauge = EnergyGauge.new()
	_energy_gauge.ship = ship
	add_child(_energy_gauge)
	_center_rect(_energy_gauge, {}, [-150, -250, 14, 92])
	_gem_bar = GemBar.new()
	_gem_bar.ship = ship
	_left.add_child(_gem_bar)
	_place(_gem_bar, "left", "gems", [524, 76, 190, 56])
	# ORDNANCE mirrors energy on the RIGHT of the crosshair, same combat-readable
	# band. (Guns that spend their own charge will sit here too, per the layout.)
	_ord_gauge = OrdnanceGauge.new()
	_ord_gauge.ship = ship
	add_child(_ord_gauge)
	_center_rect(_ord_gauge, {}, [180, -168, 130, 90])
	Tutor.register("ord_gauge", _ord_gauge)
	# Keybind hints moved to the Esc menu -> Controls (they were a near-invisible
	# dim line on the dash). The dash is instruments now, not a cheat-sheet.

	var radar := Radar.new()
	# Scope sized to sit CENTERED inside the console slab (120 box in a 170 panel)
	# rather than crowding it edge to edge.
	radar.radius = float(_spec("right", "radar").get("radius", 50.0))
	_right.add_child(radar)
	_place(radar, "right", "radar", [-136, 39, 120, 120])
	Tutor.register("radar", radar)   # navigation lessons point at the scope

	# The comm set, left of the scope on the right console. Same CRT as the dash
	# readout — one visual language for "screen", so a second one reads as more
	# of the same instrument rather than a new UI.
	# Tutor: the last step of "memorize" points at the gem bar in flight, so the
	# pilot sees WHERE the thing they just slotted actually lives.
	for a in ["gem_bar", "radar", "comm_term", "missions_hud",
			"cargo_gauge", "ord_gauge"]:
		var ping := TutorPing.new()
		ping.anchor = a
		add_child(ping)

	comm = CommTerminal.new()
	Tutor.register("comm_term", comm)
	_right.add_child(comm)
	_place(comm, "right", "comm", [-560, 40, 400, 118])

	# Target display, data-chosen (user design debate): "floating" = a
	# windshield PROJECTION centered above the dash V, aligned with the
	# combat view (housing-less, translucent — light, not hardware);
	# "console" = seated on the band beside the radar (cohesion, less
	# functional). Both live in data/cockpits/default.json.
	var target_spec: Dictionary = _layout.get("target", {})
	_floating_target = str(target_spec.get("mode", "floating")) == "floating"
	_target_effigy = StatusEffigy.new()
	_target_effigy.projection = _floating_target
	if _floating_target:
		add_child(_target_effigy)
		_center_rect(_target_effigy, target_spec.get("effigy", {}), [-44, -282, 88, 88])
		var ts := LabelSettings.new()
		ts.font_size = 13
		ts.font_color = UiTheme.TEXT
		ts.outline_size = 3
		ts.outline_color = Color(0, 0, 0, 0.85)
		_target_info = Label.new()
		_target_info.label_settings = ts
		_target_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_target_info)
		_center_rect(_target_info, target_spec.get("label", {}), [-190, -308, 380, 22])
	else:
		_right.add_child(_target_effigy)
		_place(_target_effigy, "right", "target_effigy", [-256, 70, 88, 88])
		_target_info = _panel_label(_right, 13)
		_place(_target_info, "right", "target_info", [-646, 68, 380, 80])
		_target_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var note_settings := LabelSettings.new()
	note_settings.font_size = 14
	note_settings.font_color = UiTheme.AMBER
	note_settings.outline_size = 3
	note_settings.outline_color = Color(0, 0, 0, 0.85)
	_center_note = Label.new()
	_center_note.label_settings = note_settings
	_center_note.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_center_note.offset_bottom = -40
	_center_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_center_note)

	# TOP-RIGHT STACK (no overlap): comms badge (comms_inbox, at the very top) ->
	# tracked MISSIONS (capped at 3) -> FRIENDLIES roster, in that order. The
	# missions block sits below the one-line comms badge; the roster is placed
	# dynamically right under the missions block each frame (see the update),
	# so a busy quest log never buries the friendlies. Top-LEFT stays reserved
	# for co-op party frames when multiplayer lands.
	var mission_settings := LabelSettings.new()
	mission_settings.font_size = 13
	mission_settings.font_color = UiTheme.AMBER
	mission_settings.outline_size = 3
	mission_settings.outline_color = Color(0, 0, 0, 0.85)
	_missions = Label.new()
	_missions.label_settings = mission_settings
	_missions.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_missions.offset_right = -16
	_missions.offset_top = 40   # clear of the comms badge (offset_top 12, one line)
	_missions.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_missions.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Tutor.register("missions_hud", _missions)
	add_child(_missions)

	_group = GroupOverlay.new()
	_group.ship = ship
	_group.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_group.offset_left = -280
	_group.offset_right = -14
	_group.offset_top = 40   # repositioned each frame under the missions block
	_group.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_group)

	# Screen-edge bearing to the current target when it's OFF-SCREEN — so a
	# Y-cycled ally (or any target you can't see) tells you which way to turn.
	var bearing := TargetBearing.new()
	bearing.ship = ship
	bearing.set_anchors_preset(Control.PRESET_FULL_RECT)
	bearing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bearing)

	var hold_settings := LabelSettings.new()
	hold_settings.font_size = 12
	hold_settings.font_color = UiTheme.TEXT
	hold_settings.outline_size = 3
	hold_settings.outline_color = Color(0, 0, 0, 0.85)
	_hold_label = Label.new()
	_hold_label.label_settings = hold_settings
	_hold_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hold_label.offset_left = 18
	_hold_label.offset_bottom = -(_panel_h + 10)
	_hold_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_hold_label)

	# Hover tooltip: names loot floating in space, follows the cursor.
	_loot_tip = Label.new()
	var tip_settings := LabelSettings.new()
	tip_settings.font_color = Color(0.95, 0.88, 0.6)
	tip_settings.outline_color = Color(0, 0, 0, 0.9)
	tip_settings.outline_size = 4
	_loot_tip.label_settings = tip_settings
	_loot_tip.add_theme_font_size_override("font_size", 13)
	_loot_tip.visible = false
	_loot_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_loot_tip)


## Name the loot under the cursor (a forgiving radius), so drifting salvage
## is identifiable at a glance — and hint the grab.
func _update_loot_tip(flying: bool) -> void:
	if not flying:
		_loot_tip.visible = false
		return
	var mouse := get_viewport().get_mouse_position()
	var world := ship.get_global_mouse_position()
	var best: Node2D = null
	var best_d := 70.0
	for n in get_tree().get_nodes_in_group("loot"):
		if not is_instance_valid(n):
			continue
		var d: float = world.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	if best == null:
		_loot_tip.visible = false
		return
	var carried: bool = ship.can_carry_mass(best.payload_mass())
	_loot_tip.text = "%s  (mass %.0f)%s\nright-click to salvage" % [
		best.payload_name(), best.payload_mass(), "" if carried else "  — HOLD FULL"]
	_loot_tip.label_settings.font_color = Color(0.95, 0.88, 0.6) if carried \
		else Color(0.95, 0.55, 0.5)
	_loot_tip.position = mouse + Vector2(16, 14)
	_loot_tip.visible = true


func _panel_label(parent: Control, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", UiTheme.TEXT)
	parent.add_child(lbl)
	return lbl


func _spec(section: String, key: String) -> Dictionary:
	var sec: Dictionary = _layout.get(section, {})
	return sec.get(key, {})


## Rect from layout data: {x, y, w, h} relative to the parent console;
## negative x measures from the console's right edge.
func _place(ctrl: Control, section: String, key: String, def: Array) -> void:
	var s := _spec(section, key)
	var x := float(s.get("x", def[0]))
	var y := float(s.get("y", def[1]))
	var w := float(s.get("w", def[2]))
	var h := float(s.get("h", def[3]))
	if x < 0.0:
		ctrl.anchor_left = 1.0
		ctrl.anchor_right = 1.0
	ctrl.offset_left = x
	ctrl.offset_right = x + w
	ctrl.offset_top = y
	ctrl.offset_bottom = y + h


## Rect anchored to bottom-center of the SCREEN (windshield projections):
## x measured from screen center, y (negative) from the bottom edge.
func _center_rect(ctrl: Control, spec, def: Array) -> void:
	var s: Dictionary = spec if spec is Dictionary else {}
	var x := float(s.get("x", def[0]))
	var y := float(s.get("y", def[1]))
	var w := float(s.get("w", def[2]))
	var h := float(s.get("h", def[3]))
	ctrl.anchor_left = 0.5
	ctrl.anchor_right = 0.5
	ctrl.anchor_top = 1.0
	ctrl.anchor_bottom = 1.0
	ctrl.offset_left = x
	ctrl.offset_right = x + w
	ctrl.offset_top = y
	ctrl.offset_bottom = y + h


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_TAB:
		show_hold = not show_hold


func _process(_delta: float) -> void:
	if ship == null or ship.build == null:
		return
	var flying := not ship.dead and ship.docked_at == null
	_left.visible = flying
	_right.visible = flying
	_center_note.visible = flying
	_missions.visible = flying
	_group.visible = flying
	_target_effigy.visible = flying
	_target_info.visible = flying
	_energy_gauge.visible = flying
	_ord_gauge.visible = flying
	_update_loot_tip(flying)
	_hold_label.visible = flying and show_hold
	if ship.dead:
		_banner.text = "SHIP LOST — cargo lost with it   [E] restart"
		_banner_settings.font_color = UiTheme.DANGER
		return
	if ship.docked_at != null:
		_banner.text = ""
		return

	# Threat banner: ensnarement outranks the gaze.
	var beast := get_tree().get_first_node_in_group("leviathan")
	if ship.snared > 0.0:
		_banner.text = ">>> ENSNARED IN UMBRAL BREATH — BURN FREE <<<"
		_banner_settings.font_color = Color(0.8, 0.45, 1.0)
	elif beast != null and beast.hunting:
		_banner.text = ">>> %s HAS SEEN YOU — RUN <<<" % beast.beast_name.to_upper()
		_banner_settings.font_color = UiTheme.DANGER
	elif ship.is_wanted():
		_banner.text = "WANTED — the law is hunting you"
		_banner_settings.font_color = UiTheme.AMBER
	else:
		_banner.text = ""

	var mode_line: String
	if ship.sliding():
		mode_line = ">> HYPERSLIDE <<"
	elif ship.mode == TestShip.ControlMode.CONNECTED:
		mode_line = "CONNECTED" + ("   [M] disconnect" if ship.decoupler_fitted else "")
	else:
		mode_line = "DISCONNECTED   [M] reconnect"
	# THE DASH TERMINAL (2026-07-22, user): green phosphor on black, and only
	# what actually CHANGES while flying. Cut for good: the hull name and class
	# (the effigy is the ship, and you know what you bought) and LOAD (a static
	# fit budget that cannot move in flight — dock information sitting on the
	# windshield). What's left is money and flight mode, which do change.
	_sys.text = "CR %d\n%s" % [Wallet.credits, mode_line]
	MissionTracker.sync_waypoint(ship)   # top tracked objective drives the marker
	_missions.text = _missions_line()
	# Stack the friendlies roster directly under the missions block — the corner
	# reads top-to-bottom: comms badge, missions, friendlies, never piled up.
	var missions_h: float = _missions.get_minimum_size().y if _missions.text != "" else 0.0
	_group.offset_top = _missions.offset_top + missions_h + (10.0 if missions_h > 0.0 else 0.0)

	# The target can be freed mid-frame (rock crumbles, pirate dies) before
	# the ship's physics tick clears it — assigning a freed instance to a
	# typed Node2D var throws, so validate HERE, not just in the drawers.
	_target_effigy.subject = ship.target if is_instance_valid(ship.target) else null
	_target_info.text = _target_text()
	_center_note.text = _center_text()
	# A refused ability flashes RED so it reads unmistakably as a failure; every
	# other center note keeps the amber. (label_settings here is _center_note's own.)
	_center_note.label_settings.font_color = UiTheme.DANGER \
		if (ship.scan_note_t > 0.0 and ship.scan_note_fail) else UiTheme.AMBER
	_hold_label.text = _hold_block() if show_hold else ""


func _target_text() -> String:
	if ship.target == null or not is_instance_valid(ship.target):
		# A projection with no target shows nothing — glass stays clear.
		return "" if _floating_target else "NO TARGET   (RMB click / [T] cycle)"
	var t: Node2D = ship.target
	var name_text := "contact"
	if t is BuildShip and t.build != null:
		name_text = t.build.hull.display_name
	elif t is MineableAsteroid:
		name_text = "Asteroid — " + (t.survey_text() if t.surveyed else "unsurveyed")
	elif t is TargetDrone:
		name_text = "Practice Drone"
	elif t.is_in_group("leviathan"):
		name_text = t.beast_name
	elif t is Station:
		name_text = "Station"
	# Range is targeting-computer data — it belongs right on the mark.
	var rng := int(round(ship.global_position.distance_to(t.global_position)))
	var out := "TARGET: %s   %d u" % [name_text, rng]
	if ship.scanning():
		out += "\nSCANNING %d%%" % int(ship.scan_fraction() * 100.0)
	elif ship.scanner_fitted:
		out += "\n[1] scan"
	return out


## One line, one message: the most urgent contextual thing right now.
func _center_text() -> String:
	if ship.scan_note_t > 0.0:
		return ship.scan_note
	return _approach_line()


## THE OBJECTIVE TRACKER, in the corner under COMMS. The player curates which
## objectives show and in what order (MissionTracker); TOP is current and wears a
## ▶ plus its next step, the rest are one glyph-tagged line each so campaign,
## contract and lead read distinct at a glance.
func _missions_line() -> String:
	var tracked: Array = MissionTracker.visible_tracked(ship)
	if tracked.is_empty():
		return ""
	var lines: Array[String] = ["OBJECTIVES"]
	for i in tracked.size():
		var t: Dictionary = tracked[i]
		var head := "%s %s %s" % ["▶" if i == 0 else " ",
			_kind_glyph(str(t.kind)), str(t.label)]
		if str(t.kind) == "contract":
			head += "   %s" % str(t.detail)         # progress reads inline
		lines.append(head)
		# The current objective also spells out its step; the rest stay one line.
		if i == 0 and str(t.kind) != "contract" and str(t.get("detail", "")) != "":
			lines.append("      %s" % str(t.detail))
	return "\n".join(lines)


## Per-kind marker so the three objective types read apart in the corner:
## filled diamond = campaign (the spine), bullet = side contract, open diamond =
## an expedition lead (discovery).
func _kind_glyph(kind: String) -> String:
	match kind:
		"campaign": return "◆"
		"lead": return "◇"
		_: return "•"


func _hold_block() -> String:
	if ship.cargo.is_empty() and ship.commodities.is_empty():
		return "HOLD — empty"
	var out := "HOLD  %.0f/%.0f:" % [ship.cargo_used(), ship.stats.cargo]
	for comp in ship.cargo:
		out += "\n  %s  —  Mk %d %s  (mass %.0f)" % [
			comp.display_name, comp.mark, Grades.display_name(comp.grade), comp.mass]
	for key in ship.commodities:
		out += "\n  %s x%d  (mass %.0f)" % [TradeGoods.display_name(key),
			ship.commodities[key], ship.commodities[key] * TradeGoods.unit_mass(key)]
	return out


func _approach_line() -> String:
	# THE WAYGATE — a persistent prompt while near it (the old one-shot flash was
	# too easy to fly past, so the finale gate read as un-interactable).
	for gate in get_tree().get_nodes_in_group("waygate"):
		var gd := ship.global_position.distance_to(gate.global_position)
		if gate.phase == WayGate.Phase.CLOSED and gd < 460.0:
			return "◆ THE WAYGATE IS DORMANT  —  [E] to enter Krayt's waking sequence"
		if gate.phase == WayGate.Phase.OPEN and gd < 340.0:
			return "◆ THE WAYGATE IS OPEN  —  fly into the light"
	for pad in get_tree().get_nodes_in_group("dock_pads"):
		if ship.global_position.distance_to(pad.global_position) < pad.UI_RANGE:
			var s: Dictionary = pad.status_for(ship)
			return "DOCK %s:  angle %s   speed %s   [E] to dock" % [
				"IN RANGE" if s.in_range else "approach",
				"OK" if s.angle_ok else "BAD", "OK" if s.speed_ok else "FAST"]
	for planet in get_tree().get_nodes_in_group("planetoids"):
		var s: Dictionary = planet.status_for(ship)
		var dist := ship.global_position.distance_to(planet.global_position)
		if dist < planet.GRAV_R + 200.0:
			if s.in_band:
				return "LANDING BAND:  descent %s   speed %s   [E] to land" % [
					"OK" if s.angle_ok else "BAD", "OK" if s.speed_ok else "HOT"]
			return "GRAVITY WELL — ride it down to the landing band"
	for pickup in get_tree().get_nodes_in_group("loot"):
		if ship.global_position.distance_to(pickup.global_position) < 90.0 \
				and not ship.can_carry_mass(pickup.payload_mass()):
			return "HOLD TOO FULL for %s (mass %.0f, %.0f free)" % [
				pickup.payload_name(), pickup.payload_mass(),
				ship.stats.cargo - ship.cargo_used()]
	return ""


## Screen-edge bearing arrow to the CURRENT target when it's off-screen. The world
## target marker (ship._target_marker, teal/orange corner arcs) shows an on-screen
## target fine, but a Y-cycled ally is often far out of view — this points the way.
## Full-rect, screen-space (CanvasLayer), so it converts the target's WORLD position
## with the viewport's canvas transform and clamps a chevron to the screen edge.
class TargetBearing:
	extends Control

	var ship: TestShip
	const MARGIN := 56.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if ship == null or ship.dead or ship.docked_at != null:
			return
		var t: Node2D = ship.target
		if not is_instance_valid(t) or t.get("dead") == true:
			return
		var sp: Vector2 = get_viewport().get_canvas_transform() * t.global_position
		var inner := Rect2(Vector2.ZERO, size).grow(-MARGIN)
		if inner.has_point(sp):
			return   # on-screen — the world marker is enough
		var center := size * 0.5
		var dir := sp - center
		if dir.length() < 1.0:
			return
		# Clamp the projected position into the inner rect: the chevron rides the
		# edge nearest the target, pointing outward toward it.
		var at := Vector2(clampf(sp.x, inner.position.x, inner.end.x),
			clampf(sp.y, inner.position.y, inner.end.y))
		var hostile: bool = t.is_in_group(ship.enemy_group)
		var col := Color(0.95, 0.45, 0.3) if hostile else Color(0.45, 0.9, 0.75)
		var fwd := dir.normalized()
		var perp := Vector2(-fwd.y, fwd.x)
		var tip := at + fwd * 12.0
		var b1 := at - fwd * 8.0 + perp * 9.0
		var b2 := at - fwd * 8.0 - perp * 9.0
		draw_colored_polygon(PackedVector2Array([tip, b1, b2]), col)
		draw_polyline(PackedVector2Array([tip, b1, b2, tip]), Color(0, 0, 0, 0.65), 1.0)
		var dist := int(ship.global_position.distance_to(t.global_position))
		draw_string(get_theme_default_font(), at - fwd * 8.0 + Vector2(-16, 20),
			"%du" % dist, HORIZONTAL_ALIGNMENT_CENTER, 60, 12, col)


## Top-right roster: the nearest friendlies within COMM RANGE — right-click a
## row to target it, left-click to hail it. Bounded to MAX_SHOWN so a busy
## sky (a capital world someday) can't bury the screen. Empty solo.
class GroupOverlay:
	extends VBoxContainer
	# Fewer rows now that the roster sits UNDER the missions block — a long
	# friendlies list would otherwise run off the bottom. Overflow -> "+N more".
	const MAX_SHOWN := 4
	const COMM_FLOOR := 900.0
	var ship: TestShip
	var _refresh := 0.0

	func _init() -> void:
		# The CONTAINER is mouse-transparent: only the FriendRows capture
		# clicks, and only when they exist. Empty roster (no friendlies in
		# range) = zero click-stealing; a busy sky captures clicks only on the
		# compact rows themselves — right where you'd expect, when you're near
		# friendlies and not fighting for pixel-precise targeting.
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override("separation", 3)

	func _process(delta: float) -> void:
		_refresh -= delta
		if _refresh > 0.0:
			return
		_refresh = 0.4
		var reach: float = maxf(COMM_FLOOR, float(ship.stats.get("sensor_range", 0.0)))
		var friends: Array[Node2D] = []
		for group in ["player_team", "friendly_targets"]:
			for node in get_tree().get_nodes_in_group(group):
				if node is BuildShip and node != ship and node.get("dead") != true \
						and not friends.has(node) \
						and ship.global_position.distance_to(node.global_position) <= reach:
					friends.append(node)
		friends.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			return ship.global_position.distance_squared_to(a.global_position) \
				< ship.global_position.distance_squared_to(b.global_position))
		for child in get_children():
			child.queue_free()
		for i in mini(friends.size(), MAX_SHOWN):
			add_child(FriendRow.new(friends[i], ship))
		if friends.size() > MAX_SHOWN:
			var more := Label.new()
			more.text = "+%d more in range" % (friends.size() - MAX_SHOWN)
			more.add_theme_font_size_override("font_size", 10)
			more.add_theme_color_override("font_color", Color(0.5, 0.55, 0.66))
			more.size_flags_horizontal = Control.SIZE_SHRINK_END
			more.mouse_filter = Control.MOUSE_FILTER_IGNORE   # display only
			add_child(more)


## One friendly in the roster: effigy + name + distance, right-aligned.
## Right-click targets it; left-click hails it. Highlighted when it's the
## current target.
class FriendRow:
	extends PanelContainer
	var member: Node2D
	var ship: TestShip

	func _init(p_member: Node2D, p_ship: TestShip) -> void:
		member = p_member
		ship = p_ship
		size_flags_horizontal = Control.SIZE_SHRINK_END
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = "left-click: target   ·   right-click: hail"
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.35, 0.6, 0.5, 0.3) if ship.target == member \
			else Color(0.05, 0.07, 0.1, 0.55)
		style.set_corner_radius_all(3)
		style.set_content_margin_all(3.0)
		if ship.target == member:
			style.border_color = Color(0.55, 0.85, 0.7)
			style.set_border_width_all(1)
		add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		var settings := LabelSettings.new()
		settings.font_size = 12
		settings.font_color = UiTheme.TEXT
		settings.outline_size = 3
		settings.outline_color = Color(0, 0, 0, 0.85)
		var name_label := Label.new()
		name_label.label_settings = settings
		var dist := ship.global_position.distance_to(member.global_position)
		name_label.text = "%s   %dm" % [
			member.build.hull.display_name if member.build != null else "wingman", int(dist)]
		row.add_child(name_label)
		var effigy := StatusEffigy.new()
		effigy.subject = member
		effigy.custom_minimum_size = Vector2(40, 40)
		row.add_child(effigy)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			accept_event()
			if event.button_index == MOUSE_BUTTON_LEFT:
				ship.target = member          # select: the primary action
				Sfx.play("click", -6.0, 1.1)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				ship.hail_friendly(member)     # interact: hail / (future) dialogue


## Console slab: dark polygon whose top edge angles down toward screen
## center, rimmed in cyan. Pure backdrop — never eats the mouse.
## Drop-in art: assets/ui/dashboard.png (full-bleed console surface texture)
## is UV-mapped onto the polygon — the slab shape stays code (a mask), so
## future per-hull cockpit layouts can reshape it freely; the texture tiles
## horizontally across the width. Flat color until the art exists.
class DashPanel:
	extends Control
	const SURFACE_ART := "res://assets/ui/dashboard.png"
	var mirrored := false
	var flat_frac := 0.72
	var drop_frac := 0.85
	var _surface: Texture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		if ResourceLoader.exists(SURFACE_ART):
			_surface = load(SURFACE_ART)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var flat := w * flat_frac    # length of the level section
		var drop := h * drop_frac    # deep V: the slope runs almost to the floor
		var body: PackedVector2Array
		var rim: PackedVector2Array
		if not mirrored:
			body = PackedVector2Array([Vector2(0, 0), Vector2(flat, 0),
				Vector2(w, drop), Vector2(w, h), Vector2(0, h)])
			rim = PackedVector2Array([Vector2(0, 0), Vector2(flat, 0),
				Vector2(w, drop), Vector2(w, h)])
		else:
			body = PackedVector2Array([Vector2(w, 0), Vector2(w - flat, 0),
				Vector2(0, drop), Vector2(0, h), Vector2(w, h)])
			rim = PackedVector2Array([Vector2(w, 0), Vector2(w - flat, 0),
				Vector2(0, drop), Vector2(0, h)])
		# Dark slab always renders first: it backs the texture's transparent
		# corners and is the whole look when the art is absent.
		draw_colored_polygon(body, Color(0.05, 0.06, 0.09, 0.93))
		if _surface != null:
			# The art is TRIM, not wallpaper: drawn 2x scale (fewer repeats),
			# knocked well back in brightness, and mostly hidden behind the
			# recessed display band below — it reads as console housing
			# around a dark screen, and the tiling stops being noticeable.
			var tex_scale := (h / maxf(_surface.get_height(), 1.0)) * 2.0
			var uvs := PackedVector2Array()
			var colors := PackedColorArray()
			for point in body:
				var u := point.x / (_surface.get_width() * tex_scale)
				if mirrored:
					u = (w - point.x) / (_surface.get_width() * tex_scale)
				uvs.append(Vector2(u, 0.06 + (point.y / h) * 0.47))
				colors.append(Color(0.5, 0.55, 0.68, 1.0))
			draw_polygon(body, colors, uvs, _surface)
		# Recessed display band: everything readable sits on this dark glass,
		# framed by a bezel cropped from the console art itself.
		var band_top := h * 0.24
		var band: Rect2
		if not mirrored:
			band = Rect2(10, band_top, flat - 40, h - band_top - 10)
		else:
			band = Rect2(w - flat + 30, band_top, flat - 40, h - band_top - 10)
		draw_rect(band, Color(0.04, 0.05, 0.08, 0.9))
		var frame := UiTheme.bezel_frame()
		if frame != null:
			draw_style_box(frame, band)
		else:
			draw_rect(band, Color(0.3, 0.38, 0.52, 0.35), false, 1.0)
		# The V isn't a cut — it's the cockpit's central strut. A thick steel
		# beam runs the slope and down the inner edge, with an interior
		# highlight seam; the cyan rim rides its outer face to the floor.
		var beam: PackedVector2Array
		var seam: PackedVector2Array
		if not mirrored:
			beam = PackedVector2Array([Vector2(flat, 3), Vector2(w - 8, drop), Vector2(w - 8, h)])
			seam = PackedVector2Array([Vector2(flat - 14, 2), Vector2(w - 20, drop), Vector2(w - 20, h)])
		else:
			beam = PackedVector2Array([Vector2(w - flat, 3), Vector2(8, drop), Vector2(8, h)])
			seam = PackedVector2Array([Vector2(w - flat + 14, 2), Vector2(20, drop), Vector2(20, h)])
		draw_polyline(beam, Color(0.15, 0.18, 0.27), 16.0)
		draw_polyline(seam, Color(0.3, 0.36, 0.5, 0.6), 2.0)
		draw_polyline(rim, Color(UiTheme.ACCENT, 0.55), 2.0)


## The status effigy — works for ANY subject, player or target, so both
## read identically (user rule). Three layers, outside in, each layer
## HIDDEN when the subject doesn't have it:
##   shield — color-coded arc ring, sweep = charge remaining
##   armor  — thick tinted outline hugging the silhouette
##   hull   — the subject's own sprite, tinted green -> amber -> red
## AI ships show their actual variant skin; the Cinderweb's effigy animates
## (texture pulled live from its AnimatedSprite2D). Asteroids draw untinted.
class StatusEffigy:
	extends Control
	var subject: Node2D
	## Windshield-projection style: no bezel housing, translucent backing —
	## reads as light painted on glass instead of an instrument in the dash.
	var projection := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		if subject == null or not is_instance_valid(subject) or subject.get("dead") == true:
			return
		var center := size * 0.5
		# Breathing room: bezel border (~6) + interior padding so the ring
		# floats inside the housing instead of pressing against the glass.
		var ring_r := minf(size.x, size.y) * 0.5 - 18.0
		# Instrument housing: bezel from the console art, then a dark disc —
		# the effigy is a screen, never a decal dissolving into the dash.
		# Projections skip the hardware and go translucent.
		if not projection:
			var housing := UiTheme.bezel()
			if housing != null:
				draw_style_box(housing, Rect2(Vector2.ZERO, size))
		draw_circle(center, ring_r + 4.0,
			Color(0.035, 0.045, 0.075, 0.5 if projection else 0.95))

		var shield_max := 0.0
		var shield := 0.0
		var armor_max := 0.0
		var armor := 0.0
		var hull_frac := -1.0   # < 0 = no health concept: draw untinted
		if subject is BuildShip and subject.build != null:
			shield_max = subject.stats.shield_hp
			shield = subject.shield
			armor_max = subject.stats.armor_hp
			armor = subject.armor
			hull_frac = clampf(subject.hull / maxf(subject.stats.hull_hp, 1.0), 0.0, 1.0)
		elif subject is TargetDrone:
			hull_frac = clampf(subject.hp / 30.0, 0.0, 1.0)
		elif subject is Leviathan:
			hull_frac = clampf(subject.hp / maxf(subject.max_hp, 1.0), 0.0, 1.0)

		# Shields: two full rings that DIE rather than a dial that sweeps
		# (user spec). The thick outer ring bleeds cyan -> red and is gone
		# by ~35%; the thin inner ring carries the last stretch, red and
		# vanishing at zero. Losing the outer ring IS the critical warning.
		if shield_max > 0.0:
			var frac := clampf(shield / shield_max, 0.0, 1.0)
			var cyan := Color(0.45, 0.8, 1.0)
			var red := Color(0.95, 0.35, 0.3)
			const OUTER_CUT := 0.35
			if frac > OUTER_CUT:
				var t := (frac - OUTER_CUT) / (1.0 - OUTER_CUT)
				var outer := red.lerp(cyan, t)
				draw_arc(center, ring_r, 0, TAU, 48,
					Color(outer, clampf(t * 3.0, 0.0, 1.0) * 0.9), 4.5)
			if frac > 0.0:
				var inner := red.lerp(cyan, frac)
				draw_arc(center, ring_r - 6.0, 0, TAU, 44,
					Color(inner, clampf(frac * 3.0, 0.0, 1.0) * 0.85), 1.8)

		var hull_color := Color.WHITE if hull_frac < 0.0 else _hull_color(hull_frac)
		var texture := _resolve_texture()
		if texture == null:
			draw_circle(center, ring_r * 0.42, hull_color)
			return
		var art_scale := (ring_r * 1.3) / maxf(texture.get_width(), 1.0)
		draw_set_transform(center, -PI / 2, Vector2(art_scale, art_scale))
		var half := -texture.get_size() * 0.5
		if armor_max > 0.0:
			var armor_color := Color(0.28, 0.3, 0.36) \
				.lerp(Color(0.62, 0.72, 0.88), clampf(armor / armor_max, 0.0, 1.0))
			for i in 8:
				var off := Vector2.RIGHT.rotated(TAU * i / 8.0) * (2.5 / art_scale)
				draw_texture(texture, half + off, armor_color)
		draw_texture(texture, half, hull_color)
		# Weapon pips ON the silhouette, at each mount's actual hardpoint
		# (user's mock): a charge bar in the weapon's own color, pointing
		# the way the gun does. Enemy effigies show their recharge too —
		# free intel. Offline/destroyed states reserved, same as the rack.
		if subject is BuildShip:
			for mount in subject._mounts:
				if mount.def == null:
					continue
				var off: Vector2 = mount.hardpoint.offset
				var back := Rect2(off.x, off.y - 1.5, 7.0, 3.0)
				if mount.get("destroyed") == true:
					draw_rect(back, Color(0.4, 0.12, 0.12, 0.95))
				elif mount.get("offline") == true or (mount.def.magazine > 0 and mount.ammo <= 0):
					# Dry ordnance greys out — reload is back at the dock.
					draw_rect(back, Color(0.25, 0.27, 0.32, 0.95))
				else:
					# Ordnance pips fill by rounds left; energy pips by charge.
					var frac: float = mount.ready_fraction() if mount.def.magazine <= 0 \
						else float(mount.ammo) / float(mount.def.magazine)
					var c: Color = mount.def.bolt_color
					draw_rect(back, Color(c, 0.22))
					draw_rect(Rect2(off.x, off.y - 1.5, 7.0 * frac, 3.0), Color(c, 0.95))
		draw_set_transform_matrix(Transform2D())
		_draw_reactor_pill(center, ring_r)

	## THE REACTOR PILL — the ENERGY readout, drawn on the effigy where the
	## reactor sits, so you look at the reactor to read the reactor.
	##
	## White-hot blue = full, black = empty. That is a LUMINANCE ramp, not a hue
	## pair, so it survives every colour-vision deficiency — but per the house
	## rule ("colours always pair with pips") the level is ALSO encoded as a fill
	## height inside a permanently visible bezel. Without the bezel an empty
	## reactor and a missing pill would look identical on the dark ground.
	func _draw_reactor_pill(center: Vector2, ring_r: float) -> void:
		if subject is not BuildShip or subject.energy_max <= 0.0:
			return
		var frac: float = clampf(subject.energy / subject.energy_max, 0.0, 1.0)
		var w := 5.0
		var h := ring_r * 0.62
		# Sits low on the hull — reactors live aft of the mounts.
		var box := Rect2(center.x - w * 0.5, center.y + ring_r * 0.18, w, h)

		draw_rect(box, Color(0.02, 0.03, 0.05, 0.9))              # the empty well
		var fill_h := h * frac
		if fill_h > 0.0:
			# black -> deep blue -> white-hot as it fills
			var cold := Color(0.06, 0.12, 0.28)
			var hot := Color(0.70, 0.90, 1.0)
			var col := cold.lerp(hot, frac)
			draw_rect(Rect2(box.position.x, box.position.y + (h - fill_h),
				w, fill_h), col)
		draw_rect(box, Color(0.45, 0.62, 0.85, 0.75), false, 1.0)  # bezel: always visible

	func _resolve_texture() -> Texture2D:
		if subject is BuildShip:
			var hull_sprite = subject._hull_sprite
			return hull_sprite.texture if hull_sprite != null else null
		if subject is MineableAsteroid:
			return subject._sprite.texture
		var sprite = subject.get("_sprite")
		if sprite is Sprite2D:
			return sprite.texture
		if sprite is AnimatedSprite2D and sprite.sprite_frames != null:
			return sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		return null

	func _hull_color(f: float) -> Color:
		if f > 0.5:
			return Color(0.95, 0.8, 0.4).lerp(Color(0.5, 0.95, 0.6), (f - 0.5) * 2.0)
		return Color(0.95, 0.35, 0.3).lerp(Color(0.95, 0.8, 0.4), f * 2.0)


# (The old standalone weapons rack is gone: weapon state now lives as pips
# on the effigy silhouette itself, at each mount's real hardpoint.)


## THE PROCESSOR BUS: the [1]-[5] ability gems as real slots instead of a text
## list. Each slot reads at a glance — icon, live cooldown sweep, and the states
## that matter: empty, ready, RUNNING (an effect is up), and MEMORIZED BUT NOT
## FITTED (✕ — the gem won't fire because its module isn't aboard).
## Icons are drop-in at assets/icons/abilities/<ability_id>.png; until one lands
## a slot falls back to a short name, so the bar works with no art at all.
class GemBar:
	extends Control
	var ship: TestShip

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if ship == null or ship.build == null:
			return
		var f := get_theme_default_font()
		var n: int = Pilot.GEM_SLOTS
		var gap := 4.0
		# SQUARE slots (user, 2026-07-22): an ability icon is square art, so a
		# tall cell letterboxed it and read as a row of buttons rather than a
		# row of gems. Take the smaller axis and centre the run in the rect.
		var cell: float = (size.x - gap * float(n - 1)) / float(n)
		var w: float = minf(cell, size.y)
		var h := w
		var x0: float = (size.x - (w * float(n) + gap * float(n - 1))) * 0.5
		var y0: float = (size.y - h) * 0.5
		for i in n:
			var x := x0 + float(i) * (w + gap)
			var aid := Pilot.gem_at(i)
			var filled := aid != ""
			var fitted: bool = filled and ship._known_abilities.has(aid)
			var st: Dictionary = ship.gem_state(aid) if filled else {}
			var active: float = float(st.get("active", 0.0))
			var cd: float = float(st.get("cd", 0.0))
			var cd_max: float = maxf(1.0, float(st.get("cd_max", 1.0)))

			# Off cooldown but the bus is short: the gem reads BLUE, matching
			# the reactor pill, so "can't afford it" is never mistaken for
			# "still recharging" (which is amber) or "not fitted" (red).
			var broke: bool = fitted and cd <= 0.0 and active <= 0.0 \
				and ship.energy < ship.energy_cost(aid)

			# Body + border: dim empty, amber ready, green running, red unfitted.
			var edge := Color(0.30, 0.35, 0.44, 0.9)
			if filled and not fitted:
				edge = Color(0.85, 0.35, 0.32, 0.95)
			elif active > 0.0:
				edge = Color(0.45, 0.92, 0.6, 0.95)
			elif broke:
				edge = Color(0.40, 0.62, 0.95, 0.95)
			elif filled and cd <= 0.0:
				edge = Color(0.95, 0.75, 0.35, 0.95)
			elif filled:
				edge = Color(0.42, 0.5, 0.62, 0.9)
			draw_rect(Rect2(x, y0, w, h), Color(0.07, 0.09, 0.13, 0.88))

			if filled:
				var tex := Abilities.icon(aid)
				var tint := Color(1, 1, 1, 1) if fitted else Color(0.5, 0.5, 0.55, 0.7)
				if broke:
					tint = Color(0.62, 0.74, 0.92, 0.75)   # drained, not dead
				if tex != null:
					# Square cell, square art: fill it nearly edge to edge.
					var s := w - 5.0
					draw_texture_rect(tex,
						Rect2(x + (w - s) * 0.5, y0 + (h - s) * 0.5, s, s), false, tint)
				else:
					# No art yet: a short name keeps the slot legible.
					var nm := Abilities.display_name(aid)
					draw_string(f, Vector2(x + 2.0, y0 + h * 0.62), nm.substr(0, 4),
						HORIZONTAL_ALIGNMENT_CENTER, w - 4.0, 8,
						tint if fitted else Color(0.55, 0.55, 0.6))
				# Cooldown sweep: an unavailable gem darkens from the bottom up.
				if cd > 0.0:
					var k: float = clampf(cd / cd_max, 0.0, 1.0)
					draw_rect(Rect2(x, y0 + h - h * k, w, h * k),
						Color(0.02, 0.03, 0.05, 0.7))
					draw_string(f, Vector2(x, y0 + h - 2.0), "%d" % int(ceil(cd)),
						HORIZONTAL_ALIGNMENT_CENTER, w, 10, Color(0.85, 0.88, 0.95))
				elif active > 0.0:
					draw_string(f, Vector2(x, y0 + h - 2.0), "%d" % int(ceil(active)),
						HORIZONTAL_ALIGNMENT_CENTER, w, 10, Color(0.55, 0.95, 0.65))
				if not fitted:
					# Memorized but the module isn't aboard — it will not fire.
					draw_line(Vector2(x + 4, y0 + 4), Vector2(x + w - 4, y0 + h - 4),
						Color(0.9, 0.35, 0.3, 0.95), 1.6)
					draw_line(Vector2(x + w - 4, y0 + 4), Vector2(x + 4, y0 + h - 4),
						Color(0.9, 0.35, 0.3, 0.95), 1.6)
			draw_rect(Rect2(x, y0, w, h), edge, false, 1.0)
			# Slot key, tucked in the corner so it never fights the icon.
			draw_string(f, Vector2(x + 2.0, y0 + 8.0), str(i + 1),
				HORIZONTAL_ALIGNMENT_LEFT, w, 8,
				Color(0.75, 0.8, 0.9, 0.85) if filled else Color(0.4, 0.44, 0.52))


## The dash CRT the readout sits on — a black screen with a green phosphor glow
## and scanlines, so the last remaining text reads as an INSTRUMENT rather than
## a caption painted over the cockpit art.
class DashTerminal:
	extends Control
	const PHOSPHOR := Color(0.30, 0.95, 0.45)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.01, 0.03, 0.02, 0.95))            # dead-black glass
		draw_rect(r, Color(PHOSPHOR, 0.05))                    # faint screen glow
		var y := 2.0
		while y < size.y:                                       # scanlines
			draw_line(Vector2(2, y), Vector2(size.x - 2, y), Color(0, 0, 0, 0.28), 1.0)
			y += 3.0
		draw_rect(r, Color(PHOSPHOR, 0.35), false, 1.0)        # bezel


## THE COMM TERMINAL — same CRT as the dash readout, sized for conversation.
## Single-player today: it shows the log and accepts commands, so the whole
## grammar (channels, /switch, history) is real and playable before there is a
## second pilot. Multiplayer feeds it through Chat.post() and nothing here
## changes.
##
## Opened with ENTER (talk) or SLASH (command, pre-filled). While it has focus
## `Chat.typing` is true and the ship stops steering — see ship.gd.
class CommTerminal:
	extends Control
	const PHOSPHOR := Color(0.30, 0.95, 0.45)
	const ROW_H := 12.0

	var input: LineEdit

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		input = LineEdit.new()
		input.placeholder_text = "say…  (/sys, /g, /help)"
		input.add_theme_font_size_override("font_size", 11)
		input.add_theme_color_override("font_color", PHOSPHOR)
		input.add_theme_color_override("font_placeholder_color", Color(PHOSPHOR, 0.35))
		input.add_theme_color_override("caret_color", PHOSPHOR)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.02, 0.06, 0.03, 0.95)
		box.border_color = Color(PHOSPHOR, 0.55)
		box.set_border_width_all(1)
		box.content_margin_left = 4.0
		input.add_theme_stylebox_override("normal", box)
		input.add_theme_stylebox_override("focus", box)
		input.visible = false
		input.text_submitted.connect(_on_submit)
		add_child(input)

	func _process(_delta: float) -> void:
		input.position = Vector2(3.0, size.y - 20.0)
		input.size = Vector2(size.x - 6.0, 17.0)
		queue_redraw()

	## ENTER opens the line, SLASH opens it already holding the slash — the two
	## habits every chat window in the genre has trained.
	func open(prefill := "") -> void:
		if Chat.typing:
			return
		Chat.typing = true
		input.visible = true
		input.text = prefill
		input.grab_focus()
		input.caret_column = prefill.length()

	func close() -> void:
		Chat.typing = false
		input.visible = false
		input.release_focus()
		input.text = ""

	func _on_submit(text: String) -> void:
		Chat.submit(text)
		close()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.01, 0.03, 0.02, 0.95))
		draw_rect(r, Color(PHOSPHOR, 0.05))
		var y := 2.0
		while y < size.y:
			draw_line(Vector2(2, y), Vector2(size.x - 2, y), Color(0, 0, 0, 0.28), 1.0)
			y += 3.0
		draw_rect(r, Color(PHOSPHOR, 0.35), false, 1.0)

		var f := get_theme_default_font()
		# Newest at the bottom, scrolling up out of the top — a terminal, not a
		# feed. The input line owns the last 20px when it's open.
		var bottom: float = size.y - (22.0 if Chat.typing else 6.0)
		var row: float = bottom
		var i: int = Chat.lines.size() - 1
		while i >= 0 and row > ROW_H:
			var entry: Dictionary = Chat.lines[i]
			var cdef := Chat.channel_def(str(entry.get("chan", "")))
			var col: Color = cdef.get("color", Color(0.6, 0.7, 0.65)) if not cdef.is_empty() \
				else Color(0.55, 0.70, 0.60)
			var who := str(entry.get("from", ""))
			var line := str(entry.get("text", ""))
			var text := line if who.is_empty() \
				else "[%s] %s: %s" % [str(cdef.get("tag", "")), who, line]
			draw_string(f, Vector2(5.0, row), text,
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 10.0, 10, col)
			row -= ROW_H
			i -= 1

		# Which channel a message would go to, always visible in the header.
		var active := Chat.channel_def(Chat.channel)
		draw_string(f, Vector2(5.0, 11.0), "COMM · %s" % str(active.get("tag", "—")),
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 10.0, 9, Color(PHOSPHOR, 0.75))
		draw_line(Vector2(3, 14), Vector2(size.x - 3, 14), Color(PHOSPHOR, 0.25), 1.0)


## Vertical throttle gauge: fills bottom-up with current speed. The redline band
## near the top lights when you're fast enough to HYPERSLIDE — the gauge is the
## tell for when the maneuver's available, not just a number.
class SpeedGauge:
	extends Control
	var ship: TestShip
	const REDLINE := 0.85   # ~SLIDE_SPEED_FRACTION: brake+hard-turn above here = slide

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if ship == null or ship.build == null:
			return
		var w := size.x
		# Reserve the SAME numeric strip the cargo gauge uses, so the two bodies
		# end on one line and read as a matched pair rather than two odd shapes.
		var num_h := 13.0
		var body_h := size.y - num_h
		var maxv: float = maxf(1.0, ship._max_speed)
		var spd: float = ship.velocity.length()
		var frac: float = clampf(spd / maxv, 0.0, 1.0)
		draw_rect(Rect2(0, 0, w, body_h), Color(0.08, 0.10, 0.14, 0.9))
		var fh := body_h * frac
		var col := Color(0.4, 0.85, 0.55)
		if frac >= REDLINE:
			col = Color(0.97, 0.45, 0.38)
		elif frac >= 0.6:
			col = Color(0.92, 0.82, 0.42)
		draw_rect(Rect2(2.0, body_h - fh, w - 4.0, fh), col)
		# Redline marker: hyperslide threshold.
		var ry := body_h * (1.0 - REDLINE)
		var rc := Color(0.97, 0.4, 0.35, 0.9) if frac >= REDLINE else Color(0.97, 0.4, 0.35, 0.5)
		draw_line(Vector2(0, ry), Vector2(w, ry), rc, 1.5)
		draw_rect(Rect2(0, 0, w, body_h), Color(0.42, 0.52, 0.64, 0.85), false, 1.0)
		var f := get_theme_default_font()
		draw_string(f, Vector2(0, size.y - 1), "%d" % int(spd),
			HORIZONTAL_ALIGNMENT_CENTER, w, 11,
			Color(0.95, 0.62, 0.55) if frac >= REDLINE else Color(0.72, 0.78, 0.88))


## Cargo hold: a vertical stack of crate SLATS that fills bottom-up, framed with
## container corner-brackets so it reads as cargo rather than a generic bar.
## The slat count is FIXED — each slat is 1/SLATS of the hold, NOT a unit — so it
## reads identically whether the hold is 44 or 44,000. Reddens when FULL (the
## glanceable "dock or dump" tell); exact figures live in the number below.
class CargoGauge:
	extends Control
	var ship: TestShip
	const SLATS := 16

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if ship == null or ship.build == null:
			return
		var used: float = ship.cargo_used()
		var cap: float = maxf(1.0, ship.stats.cargo)
		var frac: float = clampf(used / cap, 0.0, 1.0)
		var full := frac >= 0.999
		var w := size.x
		var num_h := 13.0
		var body_h := size.y - num_h
		# Any cargo at all lights at least one slat — "not empty" must be visible.
		var lit := 0
		if frac > 0.0:
			lit = maxi(1, int(ceil(frac * SLATS)))
		var on_col := Color(0.95, 0.42, 0.36) if full else Color(0.55, 0.8, 0.92)
		var off_col := Color(0.18, 0.22, 0.28, 0.85)
		draw_rect(Rect2(0, 0, w, body_h), Color(0.08, 0.10, 0.14, 0.9))
		var step := body_h / float(SLATS)
		var gap := 1.0
		for i in SLATS:
			# i = 0 is the BOTTOM slat: a hold fills from the deck up.
			var y := body_h - float(i + 1) * step
			draw_rect(Rect2(2.0, y + gap * 0.5, w - 4.0, step - gap),
				on_col if i < lit else off_col)
		# Container corner brackets — the "this is a cargo hold" silhouette.
		var edge := Color(0.95, 0.55, 0.5, 0.9) if full else Color(0.5, 0.62, 0.75, 0.9)
		var t := 5.0
		for corner in [Vector2(0, 0), Vector2(w, 0), Vector2(0, body_h), Vector2(w, body_h)]:
			var sx: float = 1.0 if corner.x == 0.0 else -1.0
			var sy: float = 1.0 if corner.y == 0.0 else -1.0
			draw_line(corner, corner + Vector2(t * sx, 0), edge, 1.5)
			draw_line(corner, corner + Vector2(0, t * sy), edge, 1.5)
		var f := get_theme_default_font()
		draw_string(f, Vector2(0, size.y - 1), "%d/%d" % [int(used), int(cap)],
			HORIZONTAL_ALIGNMENT_CENTER, w, 11,
			Color(0.95, 0.6, 0.55) if full else Color(0.72, 0.78, 0.88))


## REACTOR ENERGY — a slatted vertical gauge beside speed + cargo, because energy
## is a real resource now (abilities spend it, it recharges over time) and the
## effigy pill alone was too small to read. Cyan when healthy, amber when low, red
## when nearly dry; a bolt glyph + the current value so it can't be mistaken for
## the cargo bar next to it.
class EnergyGauge:
	extends Control
	var ship: TestShip
	const SLATS := 16

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if ship == null or ship.build == null or ship.energy_max <= 0.0:
			return
		var frac: float = clampf(ship.energy / ship.energy_max, 0.0, 1.0)
		var w := size.x
		var body_h := size.y - 13.0
		var lit := 0
		if frac > 0.0:
			lit = maxi(1, int(ceil(frac * SLATS)))
		var on_col := Color(0.35, 0.85, 1.0)          # energy cyan
		if frac < 0.15:
			on_col = Color(0.95, 0.42, 0.36)          # critical — can't cast
		elif frac < 0.35:
			on_col = Color(0.95, 0.78, 0.36)          # low
		var off_col := Color(0.12, 0.18, 0.26, 0.85)
		draw_rect(Rect2(0, 0, w, body_h), Color(0.05, 0.09, 0.14, 0.9))
		var step := body_h / float(SLATS)
		for i in SLATS:
			var y := body_h - float(i + 1) * step   # fills deck-up like a charge
			draw_rect(Rect2(2.0, y + 0.5, w - 4.0, step - 1.0), on_col if i < lit else off_col)
		# A lightning bolt across the top so it reads ENERGY, not a second hold.
		var cx := w * 0.5
		draw_polyline(PackedVector2Array([
			Vector2(cx + 3, 2), Vector2(cx - 3, body_h * 0.42),
			Vector2(cx + 1, body_h * 0.42), Vector2(cx - 3, body_h - 3)]),
			Color(on_col, 0.9), 1.6)
		var f := get_theme_default_font()
		draw_string(f, Vector2(0, size.y - 1), "%d" % int(round(ship.energy)),
			HORIZONTAL_ALIGNMENT_CENTER, w, 11, on_col)


## Ordnance readout: for each magazine weapon, a HOT (colour) / COLD (grey) box
## with its remaining rounds. Scales to any launcher (count, not one-pip-per-
## round). Grey when dry OR safed with [Z]. Hidden when no ordnance is fitted.
class OrdnanceGauge:
	extends Control
	var ship: TestShip

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if ship == null or ship.build == null:
			return
		var held: bool = not ship.array_enabled[1]   # [Z] hold = ordnance safed/cold
		var f := get_theme_default_font()
		# `def`, not `weapon` — WeaponMount has no `weapon` property. This only
		# ever evaluates for a group-2 mount, so it stayed hidden until a hull
		# actually carried ordnance (the Dowager with pods fitted).
		var racks := []
		for m in ship._mounts:
			if m.group == 2 and m.def != null and m.def.magazine > 0:
				racks.append(m)
		# BOTTOM-ALIGNED (user, 2026-07-22): rows grow upward from the floor of
		# the rect, so one pod sits level with the speed and cargo gauges instead
		# of floating at the top of an otherwise empty 96px box.
		var y: float = size.y - float(racks.size()) * 24.0
		for m in racks:
			var ammo: int = m.ammo
			var maxa: int = m.def.magazine
			var hot: bool = ammo > 0 and not held
			var col := Color(1.0, 0.68, 0.36) if hot else Color(0.44, 0.47, 0.55)
			draw_rect(Rect2(0, y, 30, 20), Color(col.r, col.g, col.b, 0.22))
			draw_rect(Rect2(0, y, 30, 20), col, false, 1.0)
			# a little missile glyph
			draw_line(Vector2(8, y + 15), Vector2(22, y + 5), col, 1.5)
			draw_string(f, Vector2(36, y + 15), "%d/%d" % [ammo, maxa],
				HORIZONTAL_ALIGNMENT_LEFT, 70, 14, col)
			y += 24.0
