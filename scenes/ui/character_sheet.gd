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
var _equip_rows: VBoxContainer
var _equip_stats: RichTextLabel
var _tech_slots: VBoxContainer
var _tech_book: VBoxContainer
var _tech_pick := -1   # which bus slot is waiting for a pick (-1 = none)
var _note: Label   # one status line for equip/unequip verbs — every refusal is VISIBLE


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

	# --- EQUIPMENT ---
	# The 9-slot ground paperdoll (docs/ground_combat.md). Left: one row per slot,
	# right-click a worn item to unequip it into the hold. Right: the derived stat block
	# (GroundStats — the same numbers the walker fights with).
	var eq := HBoxContainer.new()
	eq.name = "Equipment"
	eq.add_theme_constant_override("separation", 18)
	tabs.add_child(eq)
	var eq_scroll := ScrollContainer.new()
	eq_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eq_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	eq.add_child(eq_scroll)
	_equip_rows = VBoxContainer.new()
	_equip_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equip_rows.add_theme_constant_override("separation", 6)
	eq_scroll.add_child(_equip_rows)
	_equip_stats = _scrolling_body(eq)

	# --- TECHNIQUES ---
	# The character's own bus (docs/ground_combat.md): pick a slot, pick from what you
	# KNOW. The ship's gems auto-wire off the fit; techniques are TRAINING, so the
	# player places them deliberately — this is the placing surface.
	var tech := HBoxContainer.new()
	tech.name = "Techniques"
	tech.add_theme_constant_override("separation", 18)
	tabs.add_child(tech)
	var slot_col := VBoxContainer.new()
	slot_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_col.add_theme_constant_override("separation", 6)
	tech.add_child(slot_col)
	var sh_lbl := Label.new()
	sh_lbl.text = "THE BUS — [1]–[5] ON FOOT"
	sh_lbl.add_theme_color_override("font_color", UiTheme.AMBER)
	slot_col.add_child(sh_lbl)
	_tech_slots = VBoxContainer.new()
	_tech_slots.add_theme_constant_override("separation", 4)
	slot_col.add_child(_tech_slots)
	var book_col := VBoxContainer.new()
	book_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_col.add_theme_constant_override("separation", 6)
	tech.add_child(book_col)
	var bk_lbl := Label.new()
	bk_lbl.text = "WHAT YOU KNOW"
	bk_lbl.add_theme_color_override("font_color", UiTheme.AMBER)
	book_col.add_child(bk_lbl)
	var bscroll := ScrollContainer.new()
	bscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	book_col.add_child(bscroll)
	_tech_book = VBoxContainer.new()
	_tech_book.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tech_book.add_theme_constant_override("separation", 4)
	bscroll.add_child(_tech_book)

	# --- SHIP ---
	var sh := HBoxContainer.new()
	sh.name = "Ship"
	tabs.add_child(sh)
	_ship_body = _scrolling_body(sh)

	# --- INVENTORY ---
	# What you are actually carrying, as the SHARED InventoryGrid (the same widget the
	# shop counter puts on your side of the table). Mostly read-only on purpose — the
	# dossier can be up mid-fight, and a stray right-click should never jettison cargo
	# or sell a part (trading happens at a counter, jettisoning at the salvage panel).
	# The ONE verb it carries is EQUIP: right-click a piece of ground gear to put it on —
	# reversible, destroys nothing, and the ground has no other surface for it.
	var inv := VBoxContainer.new()
	inv.name = "Inventory"
	tabs.add_child(inv)
	_inv = InventoryGrid.new(null)   # ship is bound at refresh(), once we can find it
	_inv.title = "CARGO MANIFEST"
	_inv.empty_text = "— you are carrying nothing —"
	_inv.item_hint = func(c) -> String:
		return "RIGHT-CLICK to equip" if c is GroundGearDef else "trade or refit at a proper berth"
	_inv.material_hint = func(_k) -> String: return "sell at any market that wants it"
	_inv.on_item = func(comp: ComponentDef, _s: String) -> void: _equip_from_hold(comp)
	inv.add_child(_inv)

	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 13)
	_note.add_theme_color_override("font_color", UiTheme.AMBER)
	_note.visible = false
	root.add_child(_note)

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
	_say("")
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
	_refresh_equipment()
	_refresh_techniques()
	# The hull is found fresh each time — the dossier outlives any one ship (you can
	# board another at a hangar), so it must never cache the one it saw first.
	_inv.ship = get_tree().get_first_node_in_group("player_ship")
	_inv.refresh()


func _refresh_equipment() -> void:
	for c in _equip_rows.get_children():
		_equip_rows.remove_child(c)
		c.queue_free()
	var worn := Pilot.ground_gear_items()
	for slot_name in GroundGearDef.SLOT_NAMES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_equip_rows.add_child(row)
		var lbl := Label.new()
		lbl.text = str(slot_name).to_upper()
		lbl.custom_minimum_size.x = 92.0
		lbl.add_theme_color_override("font_color", UiTheme.ACCENT)
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lbl)
		var g: GroundGearDef = worn.get(slot_name)
		if g != null:
			var t := ItemTile.new(g, "worn", ItemTile.Style.SHOP)
			t.hint = "RIGHT-CLICK to unequip → hold"
			var slot_key := str(slot_name)
			t.on_interact = func(_c: ComponentDef, _s: String) -> void: _unequip_to_hold(slot_key)
			row.add_child(t)
			var nm := Label.new()
			nm.text = g.display_name
			nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(nm)
		else:
			var empty := Label.new()
			# The locked off hand explains ITSELF — "— empty —" under a rifle reads as a bug.
			var txt := "— empty —"
			if str(slot_name) == "Offhand" and Pilot.offhand_locked():
				var main: GroundGearDef = worn.get("Main")
				txt = "— both hands on the %s —" % (main.display_name if main != null else "two-hander")
			empty.text = txt
			empty.add_theme_color_override("font_color", Color(0.5, 0.55, 0.62))
			empty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(empty)
	_equip_stats.text = _equipment_text()


## SELECT-SLOT-THEN-PICK (the ship bus's idiom, mirrored so the gesture transfers):
## click a bus slot to arm it, then click a technique to prepare it there. Clicking an
## armed slot again clears it — the only way to leave a key empty on purpose.
func _refresh_techniques() -> void:
	for c in _tech_slots.get_children():
		_tech_slots.remove_child(c)
		c.queue_free()
	for c in _tech_book.get_children():
		_tech_book.remove_child(c)
		c.queue_free()

	for i in Techniques.BUS_SLOTS:
		var tid := Pilot.technique_at(i)
		var b := Button.new()
		b.text = "[%d]   %s" % [i + 1, Techniques.display_name(tid) if tid != "" else "— empty —"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTheme.button_flavor(b, "primary" if i == _tech_pick else "tertiary")
		if tid != "":
			b.tooltip_text = " "   # a custom tooltip needs a non-empty text to trigger
			b.set_meta("tid", tid)
		var slot := i
		b.pressed.connect(func() -> void: _on_slot_pressed(slot))
		_tech_slots.add_child(b)

	var hint := Label.new()
	hint.text = "Pick a slot, then a technique.  Re-click an armed slot to clear it." \
		if _tech_pick < 0 else "Slot [%d] armed — choose what goes on it." % (_tech_pick + 1)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UiTheme.ACCENT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tech_slots.add_child(hint)

	var known := Techniques.known()
	if known.is_empty():
		var none := Label.new()
		none.text = "— you have been trained in nothing yet —"
		none.add_theme_color_override("font_color", Color(0.5, 0.55, 0.62))
		_tech_book.add_child(none)
		return
	for tid in known:
		var id := str(tid)
		var d := Techniques.def(id)
		var b := Button.new()
		var prepared := Pilot.techniques.has(id)
		b.text = "%s%s" % [Techniques.display_name(id), "   ✓ prepared" if prepared else ""]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTheme.button_flavor(b, "secondary" if not prepared else "tertiary")
		b.tooltip_text = "%s — %s" % [str(d.get("name", id)), str(d.get("desc", ""))]
		b.pressed.connect(func() -> void: _on_book_pressed(id))
		_tech_book.add_child(b)


func _on_slot_pressed(i: int) -> void:
	if _tech_pick == i:
		# Second click on the armed slot = clear it (and disarm).
		Pilot.set_technique(i, "")
		_tech_pick = -1
		_say("Slot [%d] cleared." % (i + 1))
	else:
		_tech_pick = i
	Sfx.play("click", -16.0)
	_refresh_techniques()


func _on_book_pressed(tid: String) -> void:
	if _tech_pick < 0:
		# No slot armed: fall to the first free one, so a single click still does the
		# obvious thing rather than nothing.
		var free := Pilot.first_empty_technique()
		if free < 0:
			_say("Every slot is full — pick the one to replace.")
			return
		_tech_pick = free
	Pilot.set_technique(_tech_pick, tid)
	_say("Prepared %s on [%d]." % [Techniques.display_name(tid), _tech_pick + 1])
	_tech_pick = -1
	Sfx.play("click", -16.0)
	_refresh_techniques()


func _equipment_text() -> String:
	var stats := GroundStats.derive(Pilot.ground_gear_items())
	var s := "[b][color=%s]ON FOOT[/color][/b]\n" % AMBER
	s += _stat("Health", "%.0f" % stats.max_health)
	s += _stat("Mitigation", "%d%%" % int(round(float(stats.mitigation) * 100.0)))
	s += _stat("Barrier", "%.0f" % stats.barrier)
	var atk: Dictionary = stats.attack
	var w: GroundGearDef = stats.weapon
	s += "\n[b][color=%s]WEAPON[/color][/b]\n" % AMBER
	s += _stat("Carrying", w.display_name if w != null else "Bare hands")
	s += _stat("Damage", "%.0f every %.1fs" % [float(atk.damage), float(atk.cooldown)])
	s += _stat("Reach", "%.0f%s" % [float(atk.range), "  (melee)" if bool(atk.melee) else ""])
	s += "\n[b][color=%s]CELL[/color][/b]\n" % AMBER
	s += _stat("Energy", "%.0f" % stats.max_energy)
	s += _stat("Recharge", "%.1f /s" % stats.energy_recharge)
	s += "\n[color=%s]Worn gear mitigates — it never wears down. Kneel for cover (+25%%).\nTechniques spend the cell; [K] meditates to refill it, defenseless.[/color]\n" % MUTE
	return s


## Right-click verb on the Inventory grid: put a piece of ground gear on. Whatever it
## displaces goes back to the hold (add_cargo never destroys; an overfull hold just
## blocks new pickups until you sell). The live walker re-derives immediately.
func _equip_from_hold(comp: ComponentDef) -> void:
	var g := comp as GroundGearDef
	if g == null:
		return
	var res := Pilot.equip_ground(g)
	if not bool(res.ok):
		_say(str(res.msg))
		return
	var ship := get_tree().get_first_node_in_group("player_ship")
	if ship != null:
		ship.cargo.erase(g)
		for prev in res.out:
			ship.add_cargo(prev)
	Sfx.play("click")
	_say("Equipped: %s" % g.display_name)
	get_tree().call_group("ground_town", "apply_gear", false)
	_refresh()


func _unequip_to_hold(slot: String) -> void:
	var item := Pilot.unequip_ground(slot)
	if item == null:
		return
	var ship := get_tree().get_first_node_in_group("player_ship")
	if ship != null:
		ship.add_cargo(item)
		_say("Unequipped: %s → hold" % item.display_name)
	else:
		# No ship in the tree (shouldn't happen in play) — refuse rather than vanish it.
		Pilot.equip_ground(item)
		_say("No hold to stow the %s in." % item.display_name)
		return
	Sfx.play("click")
	get_tree().call_group("ground_town", "apply_gear", false)
	_refresh()


func _say(msg: String) -> void:
	_note.text = msg
	_note.visible = msg != ""


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
