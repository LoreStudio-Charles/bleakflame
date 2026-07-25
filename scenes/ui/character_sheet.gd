class_name CharacterSheet
extends CanvasLayer
## The pilot DOSSIER — pull it up ANYWHERE ([P] toggles, [Esc] closes): in flight, on the
## ground in town, or docked. Two tabs:
##   CHARACTER — identity, background, level/XP, credits, commission, skills, standing,
##               and the ability bus.
##   SHIP      — read-only loadout + rated stats. Refitting still needs an Engineering bay
##               (this is informational only), so nothing here mutates the build.
## Self-contained: reads the Pilot/Wallet/Standing statics and the current `player_ship`
## from its group, so it needs no wiring beyond existing in the tree. Freezes the ground
## town (group "ground_town") while open so you don't walk around behind it.

const KEY_TOGGLE := Keys.DOSSIER
const AMBER := "#f2b859"
const CYAN := "#7fd3e0"
const MUTE := "#8890a0"
const TEXT := "#d8dce4"

var _portrait: TextureRect
var _char_body: RichTextLabel
var _ship_body: RichTextLabel
var _inv: InventoryGrid


func _init() -> void:
	layer = 20   # above the dock (5) and the town overlay (3)
	visible = false


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -450.0
	panel.offset_top = -330.0
	panel.offset_right = 450.0
	panel.offset_bottom = 330.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.BG, 0.99)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var header := Label.new()
	header.text = "PILOT DOSSIER"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", UiTheme.AMBER)
	root.add_child(header)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)

	# --- CHARACTER ---
	var ch := HBoxContainer.new()
	ch.name = "Character"
	ch.add_theme_constant_override("separation", 18)
	tabs.add_child(ch)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(168, 168)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ch.add_child(_portrait)
	_char_body = _scrolling_body(ch)

	# --- SHIP ---
	var sh := HBoxContainer.new()
	sh.name = "Ship"
	tabs.add_child(sh)
	_ship_body = _scrolling_body(sh)

	# --- INVENTORY ---
	# What you are actually carrying, as the SHARED InventoryGrid (the same widget the
	# shop counter puts on your side of the table). Read-only HERE on purpose: the
	# dossier is something you pull up anywhere, including mid-fight, and a stray
	# right-click should never jettison cargo or sell a part. Trading happens at a
	# counter, jettisoning at the salvage panel — this is the manifest.
	var inv := VBoxContainer.new()
	inv.name = "Inventory"
	tabs.add_child(inv)
	_inv = InventoryGrid.new(null)   # ship is bound at refresh(), once we can find it
	_inv.title = "CARGO MANIFEST"
	_inv.empty_text = "— you are carrying nothing —"
	_inv.item_hint = func(_c) -> String: return "trade or refit at a proper berth"
	_inv.material_hint = func(_k) -> String: return "sell at any market that wants it"
	inv.add_child(_inv)

	var foot := Label.new()
	foot.text = "[P] / [Esc]  close"
	foot.add_theme_font_size_override("font_size", 12)
	foot.add_theme_color_override("font_color", UiTheme.ACCENT)
	root.add_child(foot)


func _scrolling_body(parent: Node) -> RichTextLabel:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	return body


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if Chat != null and Chat.typing:
		return   # don't steal a keystroke meant for the comm line
	if event.keycode == KEY_TOGGLE:
		toggle()
		get_viewport().set_input_as_handled()
	elif event.keycode == Keys.MENU and visible:
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	_refresh()
	visible = true
	add_to_group("esc_capture")   # so the pause menu defers Esc to us
	_freeze_town(true)


func close() -> void:
	visible = false
	remove_from_group("esc_capture")
	_freeze_town(false)


func _freeze_town(frozen: bool) -> void:
	for t in get_tree().get_nodes_in_group("ground_town"):
		if t.has_method("set_active"):
			t.set_active(not frozen)


func _refresh() -> void:
	_portrait.texture = Pilot.portrait()
	_char_body.text = _character_text()
	_ship_body.text = _ship_text()
	# The hull is found fresh each time — the dossier outlives any one ship (you can
	# board another at a hangar), so it must never cache the one it saw first.
	_inv.ship = get_tree().get_first_node_in_group("player_ship")
	_inv.refresh()


func _character_text() -> String:
	var s := "[b][color=%s]%s[/color][/b]" % [AMBER, Pilot.full_name()]
	if Pilot.callsign != "":
		s += "   [color=%s]“%s”[/color]" % [MUTE, Pilot.callsign]
	s += "\n"
	var bg := Pilot.background_def(Pilot.background)
	if not bg.is_empty():
		s += "[color=%s]%s[/color] — [i][color=%s]%s[/color][/i]\n" % [CYAN, bg.name, MUTE, bg.trait]

	var lv := Pilot.level()
	var span := Pilot.xp_span_to_next()
	s += "\n[b]Level %d[/b]   " % lv
	if span > 0:
		s += "[color=%s]XP %d / %d to next[/color]\n" % [MUTE, Pilot.xp_into_level(), span]
	else:
		s += "[color=%s]MAX LEVEL[/color]\n" % MUTE
	s += "[color=%s]Credits:[/color] [color=%s]%d[/color]\n" % [MUTE, AMBER, Wallet.credits]
	var comm := Professions.display_name(Pilot.profession) if Pilot.profession != "" \
		else "Independent — no commission"
	s += "[color=%s]Commission:[/color] %s\n" % [MUTE, comm]

	s += "\n[b][color=%s]SKILLS[/color][/b]   [color=%s]%d points to spend[/color]\n" % [
		AMBER, MUTE, Pilot.skill_points_available()]
	for sk in Skills.LIST:
		var rank := Pilot.skill_rank(sk.id)
		var cap := Pilot.skill_cap(sk.id)
		s += "[color=%s]%s[/color]  [color=%s]%d/%d[/color]\n" % [
			CYAN if rank > 0 else MUTE, sk.name, TEXT if rank > 0 else MUTE, rank, cap]

	s += "\n[b][color=%s]STANDING[/color][/b]\n" % AMBER
	var any := false
	for fac in Standing.points:
		if str(fac) == "privateer":
			continue   # a secret commission — never surfaced
		any = true
		s += "[color=%s]%s[/color]  %d  [color=%s](%s)[/color]\n" % [
			CYAN, str(fac).capitalize(), Standing.get_points(fac), MUTE, Standing.state(fac)]
	if not any:
		s += "[color=%s]No reputation earned yet.[/color]\n" % MUTE

	s += "\n[b][color=%s]ABILITY BUS[/color][/b]\n" % AMBER
	for i in Pilot.GEM_SLOTS:
		var gid := Pilot.gem_at(i)
		var label := Abilities.display_name(gid) if gid != "" else "— empty —"
		s += "[color=%s][%d][/color]  [color=%s]%s[/color]\n" % [
			AMBER, i + 1, TEXT if gid != "" else MUTE, label]
	return s


func _ship_text() -> String:
	var ship := get_tree().get_first_node_in_group("player_ship")
	if ship == null or ship.build == null:
		return "[color=%s]No ship boarded.[/color]" % MUTE
	var b: ShipBuild = ship.build
	var st: Dictionary = ship.stats
	if st.is_empty():
		st = ShipStats.aggregate(b)
	var hull: HullDef = b.hull

	var s := "[b][color=%s]%s[/color][/b]\n" % [AMBER, hull.display_name]
	s += "[color=%s]%s · Level %d[/color]\n" % [
		MUTE, HullDef.SizeBand.keys()[hull.size_band].capitalize(), hull.level]

	s += "\n[b][color=%s]INTEGRITY[/color][/b]\n" % AMBER
	s += _stat("Hull", "%d / %d" % [int(ship.hull), int(st.get("hull_hp", 0.0))])
	s += _stat("Armor", "%d / %d" % [int(ship.armor), int(st.get("armor_hp", 0.0))])
	s += _stat("Shield", "%d / %d" % [int(ship.shield), int(st.get("shield_hp", 0.0))])
	s += _stat("Energy", "%d / %d" % [int(ship.energy), int(ship.energy_max)])

	s += "\n[b][color=%s]SYSTEMS[/color][/b]\n" % AMBER
	s += _stat("Power", "%.0f load / %.0f output" % [st.get("power_draw", 0.0), st.get("power_output", 0.0)])
	s += _stat("Recharge", "%.1f /s" % st.get("energy_recharge", 0.0))
	s += _stat("Cargo", "%.0f / %.0f" % [ship.cargo_used(), st.get("cargo", 0.0)])
	s += _stat("Sensor", "%.0f" % st.get("sensor_range", 0.0))
	s += _stat("Mass", "%.0f" % st.get("mass", 0.0))
	s += _stat("Damage", "%.1f dps" % st.get("dps", 0.0))

	s += "\n[b][color=%s]LOADOUT[/color][/b]\n" % AMBER
	for i in hull.hardpoints.size():
		var hp: HardpointDef = hull.hardpoints[i]
		var slot_name: String = HardpointDef.SlotType.keys()[hp.slot_type].capitalize()
		var comp: ComponentDef = b.slots.get(i)
		if comp != null:
			s += "[color=%s]%s[/color]  [color=%s]%s[/color]\n" % [CYAN, slot_name, TEXT, comp.display_name]
		else:
			s += "[color=%s]%s[/color]  [color=%s]— empty —[/color]\n" % [MUTE, slot_name, MUTE]
	return s


func _stat(label: String, value: String) -> String:
	return "[color=%s]%s[/color]  [color=%s]%s[/color]\n" % [MUTE, label, TEXT, value]
