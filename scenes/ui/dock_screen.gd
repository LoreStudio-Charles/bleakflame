class_name DockScreen
extends CanvasLayer
## Docked services, organized as diegetic station locations in tabs:
##   Landing Bay (overview + full hold) | Armory (equipment shop, components)
##   Engineering Bay (refit) | Market Terminal (commodities) | Mission Computer
## The hold is context, not a place — each location shows the slice it needs.
## Planet variant: Landing Pad / Market / Mission Uplink.

const SHOP_STOCK := [
	"res://data/components/weapons/junker_slugthrower.tres",
	"res://data/components/weapons/vk2_autocannon.tres",
	"res://data/components/weapons/twinlance_pulse.tres",
	"res://data/components/weapons/ferro_cutter_beam.tres",
	"res://data/components/weapons/bombard_rocket_pod.tres",
	"res://data/components/weapons/heatseeker_missile_pod.tres",
	"res://data/components/weapons/radio_missile_rack.tres",
	"res://data/components/engines/drifter_ion.tres",
	"res://data/components/engines/vectorjet.tres",
	"res://data/components/engines/afterjet_sprint.tres",
	"res://data/components/reactors/scrap_cell_pile.tres",
	"res://data/components/reactors/hearth_fusion.tres",
	"res://data/components/reactors/overdrive_bottle.tres",
	"res://data/components/defense/patchplate_armor.tres",
	"res://data/components/defense/bulwark_plating.tres",
	"res://data/components/defense/veil_shield.tres",
	"res://data/components/defense/aegis_composite.tres",
	"res://data/components/systems/wayfarer_sensors.tres",
	"res://data/components/systems/strapdown_cargo_pod.tres",
	"res://data/components/systems/falsebottom_hold.tres",
	# COUPLINGS are open-market hardware — the rack is not profession gear, only
	# the chips that ride in it are. Upgrading your book's size is something any
	# pilot can save up for.
	# The one ability every pilot starts from, sold openly — curiosity is not
	# profession gear.
	"res://data/components/chips/survey_scan_chip.tres",
	"res://data/components/couplings/scrap_coupling.tres",
	"res://data/components/couplings/standard_coupling.tres",
	"res://data/components/couplings/broadband_coupling.tres",
	"res://data/components/couplings/lattice_coupling.tres",
	# No flight_decoupler item exists anymore (removed 2026-07-19):
	# Disconnected flight returns on future EXOTIC thrusters/hulls.
]
const BUY_MULT := 2.0
## Engineering paperdoll MINIMUM box; the hologram scales to whatever space
## the tab actually gives it. Kept modest: a tall minimum here inflates the
## TabContainer's minimum for EVERY tab (it sizes to its tallest child) and
## squeezes the info bar off the panel.
const DOLL_MIN := Vector2(500, 360)
const HOLO_BLUE := Color(0.45, 0.85, 1.0)

var ship: TestShip
var is_station := true
var market: Dictionary

var _header: Label
var _tabs: TabContainer
var _info: RichTextLabel
var _flash_msg := ""
var _detail := ""

var _overview_text: RichTextLabel
var _overview_hold: ItemList
var _overview_stash: ItemList
var _mend_box: VBoxContainer   # planet only: the Counter mends burned factions
var _shop_grid: GridContainer
var _armory_grid: GridContainer
var _armory_detail: RichTextLabel
var _armory_filter := -1               # -1 = all; else a HardpointDef.SlotType value
var _armory_filter_row: HBoxContainer
var _cargo_grid: GridContainer
var _stash_grid: GridContainer
var _board_row: HBoxContainer
var _doll: Control
var _chip_row: HBoxContainer   # the Coupling's bag slots
## NPC id -> talks waiting for the player to come and hear them. Nothing plays
## on arrival any more (docs/npc_homes.md): a talk sits here, its owner's home
## tab wears a pip, and the conversation starts when the player chooses.
var _held_talks := {}
var _person_bodies := {}
var _npc_desks := {}          # npc -> NpcDesk (the one talk affordance per tab)
var _person_boards := {}
## NPCs who post their own contracts, and the board name their templates use.
const PERSON_BOARDS := {"sella": "Explorer's Union"}
var _tab_pips: TabPips
var _eng_stats: RichTextLabel
var _eng_selected: Array = []      # [comp, source] of the clicked tile
var _selected_slot := -1
var _market_hold: ItemList
var _commodity_box: VBoxContainer
var _pilot_info: VBoxContainer
var _skills_box: VBoxContainer
var _commission_info: VBoxContainer
var _loadout_box: VBoxContainer
var _sel_gem := -1     # gem slot selected for memorizing in the Loadout panel
var _offers_list: ItemList
var _active_box: VBoxContainer
var _yard_list: ItemList
var _reset_button: Button
var _reset_armed := false
var _lab_status: RichTextLabel
var _lab_leads: ItemList
var _mission_log: RichTextLabel
var _quests_active: QuestLogView
var _quests_done: QuestLogView
var _bar_row: Control
var _bar_feed: RichTextLabel
var _bar_last_rumor := ""
var _talk_queue: Array[Dictionary] = []
var _active_talk: DialoguePanel
var _bar_panel: DialoguePanel            # live bar conversation, so choices can re-dress
var _bar_pending_talk: Dictionary = {}   # Odessa's quest talk, held for Ember Row
var _tech_list: ItemList
var _fab_list: ItemList


func _init(p_ship: TestShip, p_is_station: bool) -> void:
	ship = p_ship
	is_station = p_is_station
	market = TradeGoods.STATION_MARKET if is_station else TradeGoods.PLANET_MARKET
	layer = 5
	visible = false
	_build_ui()


func _ready() -> void:
	add_to_group("dock_screens")


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_top = 70
	panel.offset_right = -40
	panel.offset_bottom = -30
	# Opaque: the game world must not bleed through the services screen.
	# The flat box is the backing; the pixel-art trim overlays it below.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.BG, 0.99)
	style.set_corner_radius_all(12)
	# Content clears the nine-patch trim generously: the corner plates reach
	# inward, so the header/bottom line need real breathing room or the art
	# swallows them (top-left "STATION SERVICES", bottom status especially).
	style.content_margin_left = 48.0
	style.content_margin_top = 52.0
	style.content_margin_right = 48.0
	# The frame's corner plates are 100px tall (add_frame patch_margin), so the
	# bottom bar has to clear them or the log's last lines vanish under the art.
	style.content_margin_bottom = 112.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	UiTheme.add_frame(self, 34, 64, -34, -24)
	# Ping overlays sit ABOVE the whole screen and ignore the mouse, so they can
	# point at any control on any tab without ever being the thing you click.
	for a in ["tab_pilot", "loadout", "commissions", "tab_market", "market_goods",
			"tab_missions", "offers", "contracts_held", "market_goods_planet",
			"tab_missions_planet", "tab_market_planet", "launch_hint", "coupling",
			"tab_explorers", "office_door",
			"tab_armory", "armory_shop", "tab_engineering", "paperdoll",
			"panel_bay", "panel_armory", "panel_engineering", "panel_market",
			"panel_missions", "panel_shipyard", "panel_research", "panel_bar",
			"panel_pilot"]:
		var ping := TutorPing.new()
		ping.anchor = a
		add_child(ping)

	var root := VBoxContainer.new()
	panel.add_child(root)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 17)
	_header.add_theme_color_override("font_color", UiTheme.AMBER)
	root.add_child(_header)
	Tutor.register("launch_hint", _header)   # the header carries "[E] launch"

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	# The TAB STRIP is the anchor for "go to the Pilot tab" — TabContainer draws
	# its tabs itself, so we point at the strip along the top rather than at a
	# button node that doesn't exist. Advancing happens on tab_changed below.
	for t in ["tab_pilot", "tab_armory", "tab_engineering"]:
		Tutor.register(t, _tabs)

	_build_overview_tab("Landing Bay" if is_station else "Landing Pad")
	_build_pilot_tab()
	if is_station:
		_build_shipyard_tab()
		_build_armory_tab()
		_build_engineering_tab()   # now also the Hangar: board + refit in one
		_build_research_tab()
		_build_bar_tab()
	else:
		# PLANET-ONLY ROOMS. The Counter is a recluse: giving him his own cave
		# makes visiting him an ACT rather than a stop on a menu. Sella gets the
		# Explorer's Union, the seed of the Scout guild.
		_build_person_tab("Cave", "hermit",
			"A crawlspace of tally marks and dead instruments, dug into the colony's edge. "
			+ "Nobody comes out here. That is rather the point.")
		Tutor.register("tab_explorers", _tabs)
		_build_person_tab("Explorer's Union", "sella",
			"A dusty map room off the colony's main dome, every wall a chart with "
			+ "holes in it. Sella pays hard credits for anything that fills one in.")
	_build_market_tab()
	_build_missions_tab("Mission Computer" if is_station else "Mission Uplink")
	# Odessa's quest talk waits until the player actually reaches Ember Row.
	_tabs.tab_changed.connect(_on_tab_changed)
	# Pips ride ABOVE the tab strip so they can pulse.
	_tab_pips = TabPips.new(_tabs, self)
	add_child(_tab_pips)

	# The Captain's Log strip: its OWN framed window pinned to the bottom, fully
	# inside the safe area (the panel's content margin now clears the frame's
	# corner plates). Bounded height + scroll-follow means a long log never
	# bleeds past its rect — it scrolls, newest lines (and the status line)
	# always in view — so docking never obscures it. Same journal text the
	# [L] flight overlay and the Chronicle tab show.
	var log_box := PanelContainer.new()
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0.06, 0.07, 0.10, 0.92)
	log_style.set_corner_radius_all(6)
	log_style.set_border_width_all(1)
	log_style.border_color = Color(UiTheme.ACCENT, 0.45)
	log_style.set_content_margin_all(8.0)
	log_box.add_theme_stylebox_override("panel", log_style)
	root.add_child(log_box)

	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = false
	_info.scroll_active = true
	_info.scroll_following = true   # keep the newest events + status line visible
	_info.custom_minimum_size = Vector2(0, 150)
	log_box.add_child(_info)


func _build_overview_tab(title: String) -> void:
	var row := HBoxContainer.new()
	row.name = title
	Tutor.register("panel_bay", row)
	row.add_theme_constant_override("separation", 18)
	_tabs.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	_overview_text = RichTextLabel.new()
	_overview_text.bbcode_enabled = true
	_overview_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overview_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_overview_text)
	# The harbormaster keeps this desk (Imari meets you at the ramp dirtside):
	# one always-visible NPC desk, lit when they have something for you.
	_mount_desk(left, "ruel" if is_station else "imari")
	var hold_col := _stakes_column(row, "⚠  HOLD — FLIES WITH YOU, DIES WITH YOU", UiTheme.DANGER,
		"Everything in your hold is destroyed with your ship. Dock and move anything worth keeping to the Stash.",
		Color(0.86, 0.52, 0.47))
	_overview_hold = _list(hold_col)
	if is_station:
		var stash_col := _stakes_column(row, "✔  STATION STASH — SAFE", Color(0.5, 0.82, 0.56),
			"Kept safe here between runs. Death never touches it.", Color(0.48, 0.68, 0.53))
		_overview_stash = _list(stash_col)
		_reset_button = Button.new()
		_reset_button.text = "New Pilot (wipe all progress)"
		_reset_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_reset_button.modulate = Color(0.8, 0.55, 0.5)
		_reset_button.pressed.connect(_on_reset_pressed)
		stash_col.add_child(_reset_button)
	else:
		# The planet is the neutral hub — the Counter (hermit) will put in a word
		# to mend a faction you've wronged. Slow, and only out of the red.
		var mend_col := _column(row, "MEND FENCES — the Counter mediates")
		_mend_box = VBoxContainer.new()
		_mend_box.add_theme_constant_override("separation", 6)
		mend_col.add_child(_mend_box)


## Pilot progression: level + XP, spendable skill points into the seven skills
## (profession-gated caps), and standing with faction leaders — where you accept
## a commission once a leader's trust hits the threshold.
func _build_pilot_tab() -> void:
	var row := HBoxContainer.new()
	row.name = "Pilot"
	Tutor.register("panel_pilot", row)
	row.add_theme_constant_override("separation", 18)
	_tabs.add_child(row)
	var left := _column(row, "PILOT")
	_pilot_info = VBoxContainer.new()
	_pilot_info.add_theme_constant_override("separation", 4)
	left.add_child(_pilot_info)
	var gsep := HSeparator.new()
	left.add_child(gsep)
	_loadout_box = VBoxContainer.new()
	_loadout_box.add_theme_constant_override("separation", 4)
	left.add_child(_loadout_box)
	# Tutor anchor: the ping points here for "memorize your first ability".
	Tutor.register("loadout", _loadout_box)
	var mid := _column(row, "SKILLS — spend points; your commission raises the caps")
	mid.size_flags_stretch_ratio = 1.4
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(scroll)
	_skills_box = VBoxContainer.new()
	_skills_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skills_box.add_theme_constant_override("separation", 5)
	scroll.add_child(_skills_box)
	var right := _column(row, "COMMISSION & STANDING")
	right.size_flags_stretch_ratio = 1.1
	_commission_info = VBoxContainer.new()
	Tutor.register("commissions", _commission_info)
	_commission_info.add_theme_constant_override("separation", 6)
	right.add_child(_commission_info)


func _refresh_pilot() -> void:
	if _pilot_info == null:
		return
	for c in _pilot_info.get_children():
		c.queue_free()
	for c in _skills_box.get_children():
		c.queue_free()
	for c in _commission_info.get_children():
		c.queue_free()
	for c in _loadout_box.get_children():
		c.queue_free()
	_populate_loadout()

	var lv := Pilot.level()
	var into := Pilot.xp_into_level()
	var span := Pilot.xp_span_to_next()
	var bar := ""
	if span > 0:
		var filled := clampi(int(round(18.0 * into / span)), 0, 18)
		bar = "\n[color=#73bff2]%s[/color][color=#333a4a]%s[/color]  %d/%d" % [
			"█".repeat(filled), "█".repeat(18 - filled), into, span]
	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.text = "[b]%s[/b]\n[color=#f2b859]Level %d%s[/color]%s\n\n[b][color=#8fe08f]%d skill point%s[/color][/b] to spend\n[color=#8890a0](%d of %d used)[/color]" % [
		Pilot.full_name(), lv, "  (max)" if lv >= Pilot.MAX_LEVEL else "", bar,
		Pilot.skill_points_available(), "" if Pilot.skill_points_available() == 1 else "s",
		Pilot.skill_points_spent(), Pilot.skill_points_total()]
	_pilot_info.add_child(info)

	for sid in Skills.ids():
		var sd := Skills.def(sid)
		var rank := Pilot.skill_rank(sid)
		var cap := Pilot.skill_cap(sid)
		var rowb := HBoxContainer.new()
		rowb.add_theme_constant_override("separation", 8)
		_skills_box.add_child(rowb)
		var lbl := RichTextLabel.new()
		lbl.bbcode_enabled = true
		lbl.fit_content = true
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.text = "[b]%s[/b]  [color=#f2b859]%s[/color][color=#333a4a]%s[/color]\n[color=#8890a0]%s[/color]" % [
			sd.name, "●".repeat(rank), "○".repeat(maxi(0, cap - rank)), sd.desc]
		rowb.add_child(lbl)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(36, 0)
		plus.disabled = not Pilot.can_raise_skill(sid)
		plus.pressed.connect(func() -> void:
			if Pilot.raise_skill(sid):
				Sfx.play("click", -12.0)
				refresh())
		rowb.add_child(plus)

	# THE COMMISSION USED TO LIVE HERE (moved 2026-07-22). Wares, the accept
	# button and the standing meters now belong to each LEADER, in their own
	# office — you buy Vyper's cloak from Vyper, at the Shoal. What is left on
	# this tab is the character sheet: your level, your points, your gems.
	# The meters stay, read-only, because "how close am I to an invitation" is a
	# question about YOU and has no single leader to ask.
	var cinfo := RichTextLabel.new()
	cinfo.bbcode_enabled = true
	cinfo.fit_content = true
	if Pilot.profession != "":
		var pd := Professions.def(Pilot.profession)
		cinfo.text = "[b][color=#f2b859]%s[/color][/b]  [color=#8890a0](combat +%.1f%%/level)[/color]
[color=#8890a0]Your commission. %s keeps the office — tree, wares and terms are there.[/color]" % [
			pd.name, Professions.combat_tier(Pilot.profession) * 100.0,
			Npcs.display_name(Professions.leader(Pilot.profession))]
	else:
		cinfo.text = "[color=#8890a0]No commission yet. Earn a leader's trust (below), then visit their office — they will show you the tree before you sign anything.[/color]"
	_commission_info.add_child(cinfo)

	for pd2 in Professions.visible():
		var fid := str(pd2.id)
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		_commission_info.add_child(box)
		var pts := mini(Standing.get_points(fid), Standing.INVITE_AT)
		var meter := Label.new()
		meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meter.text = "%s — %s  %d/%d" % [pd2.name, Npcs.display_name(str(pd2.leader)),
			pts, Standing.INVITE_AT]
		meter.add_theme_color_override("font_color",
			Color(0.55, 0.85, 0.6) if Standing.eligible(fid) else Color(0.5, 0.55, 0.66))
		box.add_child(meter)
		var tag := Label.new()
		if Pilot.profession == fid:
			tag.text = "ACTIVE"
			tag.add_theme_color_override("font_color", UiTheme.AMBER)
		elif Standing.eligible(fid):
			tag.text = "invited — see %s" % Npcs.display_name(str(pd2.leader))
			tag.add_theme_color_override("font_color", Color(0.55, 0.85, 0.6))
		tag.add_theme_font_size_override("font_size", 11)
		box.add_child(tag)


## The LOADOUT panel (Pilot tab, left column): the [1]-[5] gem bar + the ability
## book. Select a gem, then click a book entry to MEMORIZE it there. Only
## abilities the BOARDED ship currently KNOWS (has the system fitted) can fire;
## a gemmed-but-unfitted ability shows ✕. The book is built from fitted systems.
func _populate_loadout() -> void:
	var known := Abilities.known_for_build(ship.build)

	var head := Label.new()
	head.text = "PROCESSOR BUS — keys [1]–[5]"
	head.add_theme_color_override("font_color", UiTheme.AMBER)
	_loadout_box.add_child(head)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	_loadout_box.add_child(bar)
	for i in Pilot.GEM_SLOTS:
		var aid := Pilot.gem_at(i)
		var lit: bool = aid != "" and known.has(aid)
		var gb := AbilityButton.new(aid, Abilities.tooltip_body(aid, ship, known))
		if aid == "" or not lit:
			gb.tooltip_text = "Empty bus slot — select it, then pick an ability below." 				if aid == "" else "%s — its module is not fitted, so this slot will not fire." % Abilities.display_name(aid)
		gb.custom_minimum_size = Vector2(0, 52)
		gb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gb.toggle_mode = true
		gb.button_pressed = (i == _sel_gem)
		gb.add_theme_font_size_override("font_size", 10)
		# Abilities come from fitted modules — a gem only shows its ability once
		# the ship actually grants it (else the slot reads empty, not "scan ✕").
		var caption := Abilities.display_name(aid) if lit else "—"
		gb.text = "%d\n%s" % [i + 1, caption]
		# The slot wears the ability's face when there is art; the name stays
		# under it so the memorized slot is readable either way.
		gb.icon = Abilities.icon(aid) if lit else null
		gb.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		gb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gb.expand_icon = true
		gb.add_theme_constant_override("icon_max_width", 22)
		var slot := i
		gb.pressed.connect(func() -> void:
			_sel_gem = -1 if _sel_gem == slot else slot
			Sfx.play("click", -14.0)
			_refresh_pilot())
		bar.add_child(gb)

	var hint := Label.new()
	hint.text = "Select a slot, then pick an ability below to wire it in."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UiTheme.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loadout_box.add_child(hint)

	var bhead := Label.new()
	bhead.text = "ABILITY LIBRARY"
	bhead.add_theme_color_override("font_color", UiTheme.ACCENT)
	_loadout_box.add_child(bhead)

	if known.is_empty():
		var none := Label.new()
		none.text = "No activatable systems fitted. Fit a scanner (or cloak) in Engineering."
		none.add_theme_font_size_override("font_size", 11)
		none.add_theme_color_override("font_color", UiTheme.DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_loadout_box.add_child(none)

	for aid in known:
		var ab := AbilityButton.new(aid, Abilities.tooltip_body(aid, ship, known))
		ab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ab.icon = Abilities.icon(aid)
		ab.expand_icon = true
		ab.add_theme_constant_override("icon_max_width", 20)
		ab.custom_minimum_size = Vector2(0, 26)
		var slotted := -1
		for j in Pilot.GEM_SLOTS:
			if Pilot.gem_at(j) == aid:
				slotted = j
				break
		if slotted >= 0:
			ab.text = "  %s   [%d]" % [Abilities.display_name(aid), slotted + 1]
			ab.add_theme_color_override("font_color", UiTheme.AMBER)
		else:
			ab.text = "  " + Abilities.display_name(aid)
		var id: String = aid
		ab.pressed.connect(func() -> void:
			var tgt := _sel_gem if _sel_gem >= 0 else Pilot.first_empty_gem()
			if tgt < 0:
				tgt = 0
			Pilot.set_gem(tgt, id)
			Sfx.play("click", -12.0)
			_refresh_pilot())
		_loadout_box.add_child(ab)

	var clr := Button.new()
	clr.alignment = HORIZONTAL_ALIGNMENT_LEFT
	clr.text = "  ✕ Empty selected slot"
	clr.disabled = _sel_gem < 0 or Pilot.gem_at(_sel_gem) == ""
	clr.pressed.connect(func() -> void:
		Pilot.clear_gem(_sel_gem)
		Sfx.play("click", -14.0)
		_refresh_pilot())
	_loadout_box.add_child(clr)


func _build_shipyard_tab() -> void:
	var row := HBoxContainer.new()
	row.name = "Shipyard"
	Tutor.register("panel_shipyard", row)
	row.add_theme_constant_override("separation", 18)
	_tabs.add_child(row)
	var col := _column(row, "HULLS FOR SALE — flight-ready with standard loadout")
	_yard_list = _list(col)
	_yard_list.item_selected.connect(_on_ship_selected.bind(false))
	_button(col, "Purchase selected", _on_buy_ship)


func _build_armory_tab() -> void:
	var root := VBoxContainer.new()
	root.name = "Armory"
	Tutor.register("panel_armory", root)
	root.add_theme_constant_override("separation", 10)
	_tabs.add_child(root)
	# Filter bar gates the icon grids below by slot type; icons stay prominent.
	_armory_filter_row = HBoxContainer.new()
	_armory_filter_row.add_theme_constant_override("separation", 6)
	root.add_child(_armory_filter_row)
	var fgroup := ButtonGroup.new()
	_add_filter_button("All", -1, fgroup)
	for t in [HardpointDef.SlotType.WEAPON, HardpointDef.SlotType.ENGINE,
			HardpointDef.SlotType.REACTOR, HardpointDef.SlotType.DEFENSE,
			HardpointDef.SlotType.SYSTEM]:
		_add_filter_button(HardpointDef.SlotType.keys()[t].capitalize(), t, fgroup)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	var shop_col := _action_column(row, "EQUIPMENT FOR SALE", "right-click to buy")
	_shop_grid = _grid_in(shop_col)
	Tutor.register("armory_shop", _shop_grid)
	var hold_col := _action_column(row, "YOUR COMPONENTS", "right-click to sell")
	_armory_grid = _grid_in(hold_col)
	var detail_col := _column(row, "DETAILS")
	detail_col.size_flags_stretch_ratio = 1.2
	_armory_detail = RichTextLabel.new()
	_armory_detail.bbcode_enabled = true
	_armory_detail.fit_content = true
	_armory_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_armory_detail.custom_minimum_size = Vector2(240, 0)
	_armory_detail.add_theme_color_override("default_color", Color(0.82, 0.85, 0.92))
	_armory_detail.text = "[color=#8890a0]Select an item to inspect it. Right-click to buy or sell.[/color]"
	detail_col.add_child(_armory_detail)


## A scrollable 4-wide icon grid inside a column.
func _grid_in(parent: Node) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	return grid


func _add_filter_button(label: String, type: int, group: ButtonGroup) -> void:
	var b := Button.new()
	b.text = label
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = _armory_filter == type
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(func() -> void:
		_armory_filter = type
		Sfx.play("click", -16.0)
		_refresh_armory())
	_armory_filter_row.add_child(b)


## The ship deck: board any owned ship AND refit it, from one screen. Left =
## cargo (flies with you) over stash (safe here), visibly separate. Middle =
## board-ship icons above the hull paperdoll. Right = fabricator. All item
## moves are drag / right-click — no buttons.
func _build_engineering_tab() -> void:
	var row := HBoxContainer.new()
	row.name = "Engineering Bay"
	Tutor.register("panel_engineering", row)
	row.add_theme_constant_override("separation", 18)
	_tabs.add_child(row)

	# LEFT: cargo (small, scrolls) over stash (fills the rest), each its own
	# titled, bordered area so you always know what flies vs what stays.
	var inv_col := _column(row, "INVENTORY — drag to a slot · right-click auto-fit · shift+right-click cargo⇄stash")
	inv_col.custom_minimum_size.x = 250
	_cargo_grid = _titled_grid(inv_col, "SHIP CARGO — flies with you, lost on death",
		Color(0.16, 0.13, 0.09), 190.0, false, "hold")
	_stash_grid = _titled_grid(inv_col, "STATION STASH — safe here",
		Color(0.09, 0.11, 0.15), 0.0, true, "stash")

	# MIDDLE: board-ship strip, then the hull paperdoll + live stats.
	var ship_col := _column(row, "SHIP — drop equipment on a slot · right-click a slot to unfit")
	ship_col.size_flags_stretch_ratio = 1.8
	var board_label := Label.new()
	board_label.text = "BOARD SHIP"
	board_label.add_theme_font_size_override("font_size", 11)
	board_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	ship_col.add_child(board_label)
	_board_row = HBoxContainer.new()
	_board_row.add_theme_constant_override("separation", 6)
	ship_col.add_child(_board_row)
	_doll = Control.new()
	_doll.custom_minimum_size = DOLL_MIN
	_doll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ship_col.add_child(_doll)
	Tutor.register("paperdoll", _doll)

	# THE COUPLING — a BAG SLOT, not another paperdoll socket (user). It sits
	# apart from the hull diagram because it isn't hull hardware: it's the rack
	# your ability book rides in. Chips go in here and nowhere else.
	var cpl_label := Label.new()
	cpl_label.text = "UNIVERSAL COUPLING — ability chips"
	cpl_label.add_theme_font_size_override("font_size", 11)
	cpl_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	ship_col.add_child(cpl_label)
	_chip_row = HBoxContainer.new()
	_chip_row.add_theme_constant_override("separation", 4)
	ship_col.add_child(_chip_row)
	Tutor.register("coupling", _chip_row)
	# Rebuild once the container gives the doll its real size, so it isn't drawn
	# small and top-left-anchored on first open (it used the fallback minimum
	# before layout settled — a click used to be what forced the correct rebuild).
	_doll.resized.connect(_refresh_paperdoll)
	_eng_stats = RichTextLabel.new()
	_eng_stats.bbcode_enabled = true
	_eng_stats.fit_content = true
	ship_col.add_child(_eng_stats)

	# RIGHT: the fabricator (offline until Fabrication is commissioned).
	var fab_col := _column(row, "FABRICATOR — craft from materials")
	_fab_list = _list(fab_col)
	_fab_list.item_selected.connect(_on_recipe_selected)
	_button(fab_col, "Fabricate selected", _on_fabricate)


## A labelled, softly-tinted equipment area: title + a bordered scroll holding
## a 4-wide tile grid. `fixed_h` > 0 caps the height (cargo); 0 = fill (stash).
## The panel is a DROP ZONE for `drop_target` ("hold"/"stash"): drag a tile or
## a fitted component here to move it in.
func _titled_grid(parent: Node, title: String, tint: Color, fixed_h: float,
		fill: bool, drop_target: String) -> GridContainer:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", UiTheme.ACCENT)
	parent.add_child(lbl)
	var panel := InvDropZone.new()
	panel.target = drop_target
	panel.screen = self
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.border_color = Color(0.25, 0.3, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6.0)
	panel.add_theme_stylebox_override("panel", style)
	if fixed_h > 0.0:
		panel.custom_minimum_size = Vector2(0, fixed_h)
	if fill:
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	return grid


## The lab: the artifact COLLECTION trickles Insight by the calendar (a day
## passes per docking), LEADS track discovery chains in progress, Scan Data
## trades in flat, and the tech trees are where Insight goes to work.
func _build_research_tab() -> void:
	var row := HBoxContainer.new()
	row.name = "Research Lab"
	Tutor.register("panel_research", row)
	row.add_theme_constant_override("separation", 18)
	_tabs.add_child(row)
	var lab_col := _column(row, "ARTIFACT COLLECTION & EXPEDITION LEADS")
	_mount_desk(lab_col, "lab")
	_lab_status = RichTextLabel.new()
	_lab_status.bbcode_enabled = true
	_lab_status.fit_content = true
	_lab_status.custom_minimum_size = Vector2(0, 44)
	lab_col.add_child(_lab_status)
	_lab_leads = _list(lab_col)
	_lab_leads.item_selected.connect(_on_lead_selected)
	_button(lab_col, "Trade in all Scan Data (+%d Insight each)" % Research.SCAN_DATA_INSIGHT,
		_on_trade_scan_data)
	var tech_col := _column(row, "TECH TREES — spend Insight")
	_tech_list = _list(tech_col)
	_tech_list.item_selected.connect(_on_tech_selected)
	_button(tech_col, "Research selected", _on_research_node)


## Ember Row: the station lounge. Rumors are OVERHEARD here — walking in
## (selecting the tab) is the trigger. The bar is where the world talks.
func _build_bar_tab() -> void:
	var row := HBoxContainer.new()
	row.name = "Ember Row"
	Tutor.register("panel_bar", row)
	row.add_theme_constant_override("separation", 18)
	_tabs.add_child(row)
	_bar_row = row
	var col := _column(row, "EMBER ROW — Odessa's place. Listen more than you talk.")
	var feed_row := HBoxContainer.new()
	feed_row.add_theme_constant_override("separation", 12)
	col.add_child(feed_row)
	var portrait := Npcs.portrait("odessa")
	if portrait != null:
		var face := TextureRect.new()
		face.texture = portrait
		face.custom_minimum_size = Vector2(128, 128)
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		feed_row.add_child(face)
	_bar_feed = RichTextLabel.new()
	_bar_feed.bbcode_enabled = true
	_bar_feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bar_feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed_row.add_child(_bar_feed)
	feed_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# ONE NPC desk for Odessa, like every other face. Talking always routes through
	# _on_talk_odessa (quest business FIRST, bar rumour chat as the fallthrough), so
	# there can never again be a second, redundant "Talk to Odessa" button hiding a
	# held quest talk — the ~46-day ember_word freeze (found 2026-07-23 from the
	# save). Her desk lights on a held talk OR a rumour she's ready to share.
	_mount_desk(col, "odessa")


## Rumors come from conversation now, not from walking through a door:
## ask Odessa what the word is (DialoguePanel action "rumor").
func _on_talk_odessa() -> void:
	Pilot.meet("odessa")
	# QUEST BUSINESS FIRST. If Odessa has a pending campaign talk (ember_word's
	# "meet Odessa" beat, or any future one), present THAT — advancing it is what
	# unfreezes the campaign. Only fall through to the bar rumour chat when she
	# has no story business waiting. This is the whole ember_word fix: the button
	# now does the thing the player expected it to.
	if not (_held_talks.get("odessa", []) as Array).is_empty():
		_talk_to("odessa")
		return
	var panel := DialoguePanel.new("odessa", _odessa_nodes(), _odessa_action)
	_bar_panel = panel
	panel.vo_prefix = "odessa_bar"
	panel.closed.connect(refresh)
	add_child(panel)


## Her dialogue with the rumor choice DRESSED FOR THE TRUTH. Gold means
## something happens here; a choice that can only answer "quiet week" must not
## wear it.
##
## RE-DRESSED AFTER EVERY ASK, not just at construction: DialoguePanel re-reads
## `nodes` on each navigation, so mutating the dict in place is what makes the
## button change. Styling it once when the panel opened left a spent rumor still
## glowing gold — ask, hear it, pick "Anything else?", and the same promising
## button was sitting there offering nothing.
func _odessa_nodes() -> Dictionary:
	var nodes: Dictionary = Dialogues.ODESSA_BAR.duplicate(true)
	_dress_odessa(nodes, Research.rumor_ready())
	return nodes


## HIDDEN, not greyed (user, 2026-07-22). An option that answers "quiet week" is
## not a choice, it is a dead end wearing a button — better that she simply has
## nothing to offer today and the ask isn't there. It returns by itself the next
## time she's holding something, because the panel is rebuilt on each visit.
##
## `ready` is a PARAMETER so the rule can be tested without staging research
## chain state.
static func _dress_odessa(nodes: Dictionary, ready: bool) -> void:
	for key in nodes:
		var choices: Array = nodes[key].get("choices", [])
		for i in range(choices.size() - 1, -1, -1):
			if str(choices[i].get("action", "")) != "rumor":
				continue
			if ready:
				choices[i]["style"] = "primary"   # gold: something happens here
			else:
				choices.remove_at(i)


func _odessa_action(action: String) -> String:
	if action != "rumor":
		return "\"Hm.\""
	var rumor := Research.hear_rumor()
	if rumor == "":
		return "\"Quiet week. The Reach is holding its breath.\" She refills your glass without being asked. \"Come back after you've made some noise.\""
	_bar_last_rumor = rumor
	# She just spent it: the button stops promising one.
	if _bar_panel != null and is_instance_valid(_bar_panel):
		_dress_odessa(_bar_panel.nodes, Research.rumor_ready())
	# Some rumors are AUTHORED story leads — she speaks those aloud (her voice),
	# not just prints them. Generic rumors stay silent-with-a-jingle.
	if Research.last_rumor_vo != "":
		Sfx.play_voice(Research.last_rumor_vo)
	else:
		Sfx.play("jingle", -10.0, 1.1)
	return "She leans in, voice under the room's hum.\n\n\"%s\"" % rumor.trim_prefix("RUMOR OVERHEARD: ")


func _refresh_bar() -> void:
	var txt := "[i][color=#a8b0c2]%s[/color][/i]\n\n" % Npcs.flavor("odessa")
	txt += "The room hums: dock crews, off-shift miners, a card game nobody is winning.\n\n"
	txt += "[color=#8890a0]Around the bar: \"%s\"[/color]\n\n" % _dockside_talk()
	if _bar_last_rumor != "":
		txt += "[b][color=#f2b859]OVERHEARD:[/color][/b] %s\n\n" % _bar_last_rumor
	elif Research.rumor_ready():
		txt += "[color=#73bff2]Odessa catches your eye. She's heard something.[/color]\n\n"
	txt += "[color=#8890a0]Stories come to those who ask — and buy somebody a drink now and then.[/color]"
	_bar_feed.text = txt


## A ROOM THAT IS ONE PERSON. Portrait, their flavour, the place described, and
## whatever they currently have to say. Used for NPCs whose home isn't already a
## service screen (the Counter's cave, Sella's union hall) — and it is the
## template for any future face who deserves somewhere to stand.
func _build_person_tab(title: String, npc: String, place: String) -> void:
	var row := HBoxContainer.new()
	row.name = title
	row.add_theme_constant_override("separation", 18)
	_tabs.add_child(row)
	Tutor.register("panel_%s" % npc, row)

	var col := _column(row, title.to_upper())
	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(128, 128)
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture = Npcs.portrait(npc)
	col.add_child(face)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.text = "[b][color=#f2b859]%s[/color][/b]  [color=#8890a0]— %s[/color]\n\n%s\n\n[i][color=#a8b0c2]%s[/color][/i]" % [
		Npcs.display_name(npc), Npcs.role(npc), place, Npcs.flavor(npc)]
	col.add_child(body)
	_person_bodies[npc] = body

	# The person's talk desk — the same object every tab uses.
	_mount_desk(col, npc)

	# A PRIVATE BOARD, if this person keeps one. Sella's survey work is posted
	# at the Union rather than mixed into the colony's general contracts —
	# which is what makes the room worth walking into.
	var board := str(PERSON_BOARDS.get(npc, ""))
	if board != "":
		var bcol := _column(row, "%s — SURVEY CONTRACTS" % board.to_upper())
		var blist := _list(bcol)
		blist.fixed_icon_size = Vector2i(36, 36)
		blist.icon_mode = ItemList.ICON_MODE_LEFT
		_person_boards[npc] = blist
		_button(bcol, "Accept selected", _on_accept_person_board.bind(npc))
		var note := Label.new()
		note.text = "Survey work files at EITHER desk — here, or the station."
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", UiTheme.ACCENT)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bcol.add_child(note)


func _build_market_tab() -> void:
	var row := HBoxContainer.new()
	row.name = "Market Terminal" if is_station else "Market"
	Tutor.register("panel_market", row)
	Tutor.register("tab_market" if is_station else "tab_market_planet", _tabs)
	row.add_theme_constant_override("separation", 18)
	_tabs.add_child(row)
	var trade_col := _column(row, "%s EXCHANGE" % market.name.to_upper())
	_commodity_box = VBoxContainer.new()
	trade_col.add_child(_commodity_box)
	# Venue-specific anchor as well as the shared one: the outbound lesson buys
	# at the STATION and the return leg buys at the COLONY, and they must not
	# advance each other.
	Tutor.register("market_goods" if is_station else "market_goods_planet", _commodity_box)
	Tutor.register("market_goods_any", _commodity_box)
	var hold_col := _column(row, "YOUR GOODS")
	_market_hold = _list(hold_col)


func _build_missions_tab(title: String) -> void:
	var row := HBoxContainer.new()
	row.name = title
	Tutor.register("panel_missions", row)
	Tutor.register("tab_missions" if is_station else "tab_missions_planet", _tabs)
	row.add_theme_constant_override("separation", 18)
	_tabs.add_child(row)
	# Both venues post work now: the station board and the colony board.
	var offer_col := _column(row, "CONTRACTS ON OFFER" if is_station else "COLONY CONTRACTS")
	# Voss works this board (Sella's colony contracts are hers, but her HOME is
	# the Explorer's Union — she is only ever spoken to there).
	if is_station:
		_mount_desk(offer_col, "voss")
	_offers_list = _list(offer_col)
	Tutor.register("offers", _offers_list)
	# Row-height icons so each offer wears its giver's face.
	_offers_list.fixed_icon_size = Vector2i(36, 36)
	_offers_list.icon_mode = ItemList.ICON_MODE_LEFT
	_button(offer_col, "Accept selected", _on_accept)
	var active_col := _column(row, "CONTRACTS IN HAND")
	_active_box = VBoxContainer.new()
	Tutor.register("contracts_held", _active_box)
	active_col.add_child(_active_box)
	# The quest log proper: Active (expandable entries), Completed (history
	# you can re-read), Chronicle (the day-stamped Captain's Log stream).
	var log_col := _column(row, "QUEST LOG")
	log_col.size_flags_stretch_ratio = 1.3
	# Curation lives ON the Active-tab entries now (★ / ▲▼ / tint) — no separate panel.
	var subtabs := TabContainer.new()
	subtabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_col.add_child(subtabs)
	_quests_active = QuestLogView.new(ship, "active")
	_quests_active.name = "Active"
	subtabs.add_child(_quests_active)
	_quests_done = QuestLogView.new(ship, "completed")
	_quests_done.name = "Completed"
	subtabs.add_child(_quests_done)
	_mission_log = RichTextLabel.new()
	_mission_log.name = "Chronicle"
	_mission_log.bbcode_enabled = true
	_mission_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	subtabs.add_child(_mission_log)


func _column(parent: Node, title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(col)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", UiTheme.ACCENT)
	col.add_child(lbl)
	return col


## A titled column whose ACTION HINT (e.g. "right-click to buy") is amber+bold,
## not buried in the cyan heading — it's easy-to-miss instruction, so it reads.
func _action_column(parent: Node, title: String, hint: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(col)
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.add_theme_font_size_override("normal_font_size", 12)
	lbl.text = "[color=#%s]%s[/color]  —  [b][color=#f2b859]%s[/color][/b]" % [
		UiTheme.ACCENT.to_html(false), title, hint]
	col.add_child(lbl)
	return col


## A titled column whose header carries STAKES — a coloured heading plus a
## plain-language subtitle. Used for the hold (lost on death) vs stash (safe)
## contrast, so the risk of flying with cargo is stated outright, not implied.
func _stakes_column(parent: Node, title: String, title_color: Color,
		note: String, note_color: Color) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	parent.add_child(col)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", title_color)
	col.add_child(lbl)
	var sub := Label.new()
	sub.text = note
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", note_color)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	return col


func _list(parent: Node) -> ItemList:
	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(150, 120)
	parent.add_child(list)
	return list


func _button(parent: Node, text: String, handler: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: Sfx.play("click", -16.0))
	b.pressed.connect(handler)
	parent.add_child(b)


## Empty storage should say so, not sit as a blank void.
func _placeholder_if_empty(list: ItemList, text := "— empty —") -> void:
	if list.item_count == 0:
		var i := list.add_item(text)
		list.set_item_disabled(i, true)
		list.set_item_custom_fg_color(i, Color(0.38, 0.41, 0.5))


func refresh() -> void:
	# Docked is SAFE and is the "dock" context — asserted here rather than
	# inherited from whatever the flight tick last wrote, which could be
	# `safe = false` if you docked while something was hunting you.
	Tutor.safe = true
	Tutor.context = "dock"
	Tutor.venue = "station" if is_station else "planet"
	_header.text = "%s SERVICES        credits %dc    xp %d        [E] launch    [F1] assembly viewer" % [
		market.name.to_upper(), Wallet.credits, Wallet.xp]
	# THE TRADE LESSON, armed at the station while the planet run is live: they
	# are flying there anyway, so filling the hold costs them nothing and the
	# markup lands as a discovery. The second half waits at the colony.
	# ...but ONLY once Ruel has actually SAID it. Quests go active the moment you
	# dock, while his briefing now waits on his desk until you go and hear it —
	# so this used to tell you to prep a run nobody had asked you to make yet.
	# The lesson follows the conversation, never precedes it.
	# Chain and quest events that fired on this docking (rumors overheard,
	# turn-ins, new work, completions) surface here — whichever screen is up.
	var notes := Research.take_notes() + Quests.take_notes()
	# A graded-down approach announces itself in the AMBER NOTICE line with the
	# other "this happened on arrival" events — not buried in the overview body,
	# where it reads as one more paragraph of ship stats and goes unseen.
	if ship.approach_fault != "":
		notes.append("%s   Repairs are on the bill." % ship.approach_fault)
		ship.approach_fault = ""
	if not notes.is_empty():
		var joined := "\n".join(PackedStringArray(notes))
		_flash_msg = joined if _flash_msg == "" else _flash_msg + "\n" + joined

	# WHO IS WAITING IS DECIDED FIRST. This used to run at the bottom, after the
	# tabs had already drawn — so on the docking that queued a talk, the person's
	# home tab had been built while _held_talks was still empty: no button, no
	# pip, no notice line, and Imari sat there with the crate you were carrying
	# until something else forced a second refresh. Collect, then draw.
	_collect_talks()

	_refresh_overview()
	_refresh_pilot()
	if is_station:
		_refresh_shipyard()
		_refresh_armory()
		_refresh_engineering()
		_refresh_research()
		_refresh_bar()
	_refresh_market()
	_refresh_missions()
	_refresh_persons()
	_refresh_info()
	_present_talks()
	# DECLARATIVE TUTOR — LAST, so the snapshot sees the FINAL state of this refresh
	# (esp. _held_talks, which drives the pip lesson). Every dock lesson arms +
	# completes from _dock_context via its own predicate; see Tutor._build_preds.
	Tutor.observe(_dock_context())


## Quest givers speak in person at the dock: briefings when work is handed
## out, talk-stage conversations, and debriefs when work is done. Shown as
## DialoguePanels, one after another.
## NOBODY AMBUSHES YOU ANY MORE (2026-07-22, docs/npc_homes.md). Talks are
## filed under their giver and wait on that person's home tab behind a "Talk to
## X" button; a pip on the tab says someone is waiting. Docking becomes
## NOTICING rather than being shown, and every venue gets a reason to be walked
## into. Odessa always worked this way — this is her pattern applied to everyone.
##
## Talks whose giver has NO home (Doug Diggs until his freighter exists) fall
## back to the old behaviour rather than being lost forever.
## Drain what the dock queued into each person's in-tray. Runs BEFORE the tabs
## are built so the buttons, pips and notice line all see the same truth.
func _collect_talks() -> void:
	if not visible:
		return
	for talk in Quests.take_talks(is_station):
		var giver := str(talk.get("giver", ""))
		if Npcs.home(giver) == "":
			_talk_queue.append(talk)   # homeless: speak now or never be heard
			continue
		if not _held_talks.has(giver):
			_held_talks[giver] = []
		_held_talks[giver].append(talk)
	# ("pips" lesson arms itself off `pip_showing` in the dock context.)
	_announce_waiting()


## Anything that must be SHOWN (homeless talks with nowhere to wait) plays after
## the screen is built, so it opens over a finished dock rather than a half-built one.
func _present_talks() -> void:
	_show_next_talk()


## Build one NPC desk into `parent` and wire it. The desk owns the look (portrait,
## always-visible talk button, news dot); the host owns the meaning — routed here
## through _on_desk_talk, refreshed by _refresh_persons.
func _mount_desk(parent: Node, npc: String) -> NpcDesk:
	var desk := NpcDesk.new(npc)
	desk.talk_pressed.connect(_on_desk_talk)
	parent.add_child(desk)
	_npc_desks[npc] = desk
	return desk


## The single talk router. Odessa keeps her quest-first / rumour-chat path; anyone
## else opens their held talks, or a short idle exchange when they hold nothing —
## the always-visible button is never a dead click.
func _on_desk_talk(npc: String) -> void:
	if npc == "odessa":
		_on_talk_odessa()
		return
	if (_held_talks.get(npc, []) as Array).is_empty():
		_idle_chat(npc)
	else:
		_talk_to(npc)


func _idle_chat(npc: String) -> void:
	Pilot.meet(npc)
	var nodes := {"start": {
		"text": Npcs.idle_line(npc),
		"choices": [{"text": "Fly safe.", "next": "end"}]}}
	add_child(DialoguePanel.new(npc, nodes, func(_a: String) -> String: return ""))


## Every desk gets its news state and its office door refreshed uniformly. Service
## tabs (Landing Bay, Mission Computer, Research Lab, Ember Row) carry a desk too —
## the person lives there even though the room does other work.
func _refresh_persons() -> void:
	# Private boards first — a person's own postings, kept off the public board.
	for npc in _person_boards:
		var lst: ItemList = _person_boards[npc]
		lst.clear()
		for entry in MissionLog.offers_for(is_station, str(PERSON_BOARDS.get(npc, ""))):
			var m: Dictionary = entry.m
			var idx := lst.add_item("%s  —  %dc" % [MissionLog.label(m), m.reward])
			lst.set_item_metadata(idx, int(entry.index))
			var face := Npcs.portrait(str(m.get("giver", "")))
			if face != null:
				lst.set_item_icon(idx, face)
		_placeholder_if_empty(lst, "— no survey work posted —")

	for npc in _npc_desks:
		var desk: NpcDesk = _npc_desks[npc]
		desk.clear_extras()
		var news := not (_held_talks.get(npc, []) as Array).is_empty()
		if npc == "odessa" and Research.rumor_ready():
			news = true
		desk.set_news(news)
		_add_office_door(desk.extras, npc)


## Say who is waiting, in the amber notice line. The pip is the glance; this is
## the sentence — and it keeps the campaign findable for a player who never
## learns to read pips at all.
func _announce_waiting() -> void:
	var names := []
	for giver in _held_talks:
		if not (_held_talks[giver] as Array).is_empty():
			names.append("%s (%s)" % [Npcs.display_name(giver), Npcs.home(giver)])
	if names.is_empty():
		return
	var line := "%s wants a word." % " · ".join(PackedStringArray(names))
	_flash_msg = line if _flash_msg == "" else _flash_msg + "\n" + line


## THE DOOR BEHIND THE COUNTER. If this person leads a commission and you have
## earned an invitation (or already hold it), their office opens from wherever
## they work. Before that there is no door — they are just a person at a desk,
## and the commission is something you have not been offered.
func _add_office_door(box: VBoxContainer, npc: String) -> void:
	var prof := Professions.led_by(npc)
	if prof == "" or not Professions.office_open(prof):
		return
	var door := Button.new()
	var member: bool = Pilot.profession == prof
	door.text = "%s  →  %s" % ["Enter" if member else "Visit",
		Professions.office_name(prof)]
	UiTheme.button_flavor(door, "secondary")
	door.pressed.connect(_open_office.bind(npc, prof))
	box.add_child(door)
	# Teach the door the first time one exists anywhere. Registering the BUTTON
	# (not its box) means the ping frames the door itself, and the lesson only
	# draws once the pilot is actually looking at the tab it lives on.
	Tutor.register("office_door", door)
	# Only teach a door the pilot actually EARNED. A dev-unlocked door is not an
	# invitation, and announcing one at standing 0 reads as a bug to a playtester.
	# ("office" lesson arms itself off `office_open` in the dock context.)
	if not member and Standing.eligible(prof):
		var hint := Label.new()
		hint.text = "They have an offer for you."
		hint.add_theme_font_size_override("font_size", 11)
		hint.add_theme_color_override("font_color", Color(0.55, 0.85, 0.6))
		box.add_child(hint)


func _open_office(npc: String, prof: String) -> void:
	Tutor.retire("office")   # they walked in themselves — lesson unnecessary
	var office := GuildOffice.new(npc, prof, ship,
		func(path: String) -> void: _buy_component(path),
		func(id: String) -> void: _join_commission(id))
	office.tiles_host = self
	office.closed.connect(refresh)
	add_child(office)


## Signing on. Kept on the dock screen (not in the office) so the journal entry,
## the flash and the tutor note all happen the same way they always have.
func _join_commission(id: String) -> void:
	Pilot.join_profession(id)
	Tutor.did("joined_commission")
	Sfx.play("jingle", -8.0)
	_flash("Commission accepted — %s. New skill caps unlocked." % Professions.display_name(id))
	Research.journal.append({"day": Research.day,
		"text": "Accepted the %s commission." % Professions.display_name(id)})
	refresh()


## Is a held contract completable at THIS dock right now?
func _has_turn_in_here() -> bool:
	for m in MissionLog.active:
		if MissionLog.is_complete(m, ship) and MissionLog.venue_ok(m, is_station):
			return true
	return false


## Is someone waiting on this tab — or is there work to close?
func _tab_has_waiting(tab_title: String) -> bool:
	# The mission board wears a pip when something can be handed in. A tutor
	# lesson fires once; this stays true every time it is true.
	if tab_title.begins_with("Mission") and _has_turn_in_here():
		return true
	# Odessa holding a rumor is the same kind of "someone in here has something
	# for you" as a queued talk — that is what the player is scanning the tab
	# strip for, and a rumor she never gets asked for is a dead lead.
	if tab_title == "Ember Row" and Research.rumor_ready():
		return true
	for giver in _held_talks:
		if (_held_talks[giver] as Array).is_empty():
			continue
		if Npcs.home(giver) == tab_title:
			return true
	return false


## Take work off a person's own board (Sella's Union desk).
func _on_accept_person_board(npc: String) -> void:
	_flash_msg = ""
	var lst: ItemList = _person_boards.get(npc)
	if lst == null:
		return
	var sel := lst.get_selected_items()
	if sel.is_empty():
		return
	if not MissionLog.accept(int(lst.get_item_metadata(sel[0]))):
		_flash("Mission log full (max %d active)." % MissionLog.MAX_ACTIVE)
	else:
		Tutor.did("accepted_contract")
	MissionLog.ensure_offers()
	refresh()


## Start the conversation the player chose to have.
func _talk_to(npc: String) -> void:
	var queued: Array = _held_talks.get(npc, [])
	if queued.is_empty():
		return
	Pilot.meet(npc)
	# Drain EVERYTHING this person is holding, in order — you are standing in
	# front of them. When you finish one job Ruel often has the DEBRIEF and the
	# NEXT quest's BRIEFING both waiting; popping one left "Standing With the
	# Board" un-started behind a second click on the same button. Say it all now.
	while not queued.is_empty():
		_talk_queue.append(queued.pop_front())
	_held_talks.erase(npc)
	_show_next_talk()


func _show_next_talk() -> void:
	# Guard on an explicit reference, not tree membership: `closed` fires
	# before queue_free, so a just-closed panel is still a child and would
	# wrongly block the next talk in the chain.
	if _active_talk != null and is_instance_valid(_active_talk):
		return
	if _talk_queue.is_empty():
		return
	var talk: Dictionary = _talk_queue.pop_front()
	var nodes: Dictionary
	if talk.has("nodes"):
		# A full talk-stage conversation, authored in the quest def.
		nodes = talk.nodes
	else:
		# A one-line briefing/debrief; append the reward stamp.
		var reward_line := ""
		if str(talk.get("rewards", "")) != "":
			reward_line = "\n\n[color=#f2b859]▸ %s — %s[/color]" % [talk.quest, talk.rewards]
		# A briefing/debrief IS the important beat — new work handed over, or a
		# job closed out with rewards — so its lone "Understood." is gold: the
		# subtle "this moment matters" hint. (Lore closers like the hermit's
		# "Thank you, old man." stay cyan — good manners, nothing changing.)
		nodes = {"start": {
			"text": str(talk.text) + reward_line,
			"vo": str(talk.get("vo", "")),
			"choices": [{"text": "Understood.", "next": "end", "style": "primary"}]}}
	# Archive it the moment it's shown, so dismissing never loses the comm.
	Comms.post(str(talk.giver), str(talk.get("quest", "Transmission")),
		str(nodes.get("start", {}).get("text", "")))
	var panel := DialoguePanel.new(str(talk.giver), nodes, func(_a: String) -> String:
		return "")
	panel.vo_prefix = str(talk.get("advance", ""))   # talk-stage: <quest>_<node>
	_active_talk = panel
	panel.closed.connect(_on_talk_closed.bind(talk))
	add_child(panel)


func _on_talk_closed(talk: Dictionary) -> void:
	_active_talk = null
	# Finishing a talk-STAGE conversation advances that quest, which may in
	# turn queue a completion debrief — drain those into the chain too.
	if talk.has("advance"):
		Quests.advance_talk(str(talk.advance))
	# Any talk can make the NEXT quest eligible — a talk STAGE completing, or a
	# DEBRIEF closing out the job. Start it HERE, at this venue, so the campaign
	# flows on without a detour to a faraway (or hostile) hub. The hermit
	# (planet) -> rust_shoal (meet Krayt) must NOT route through the Guardians'
	# station: the Shoal is their enemy.
	#
	# This used to run ONLY for talk stages, so handing Ruel a finished job ended
	# the conversation and left his next contract sitting behind a pip — you shut
	# the door, then opened it again to hear "one more thing".
	Quests.check_new_work(is_station, SaveGame.tutorial_done)
	var here := str(talk.get("giver", ""))
	for t in Quests.take_talks(is_station):
		# THE PERSON IN FRONT OF YOU KEEPS TALKING. Their own next item continues
		# this conversation; anybody ELSE still waits behind their pip, because
		# the rule that nobody ambushes you at the ramp has not changed.
		if str(t.get("giver", "")) == here:
			_talk_queue.append(t)
		else:
			if not _held_talks.has(str(t.get("giver", ""))):
				_held_talks[str(t.get("giver", ""))] = []
			_held_talks[str(t.get("giver", ""))].append(t)
	if _talk_queue.is_empty():
		refresh()   # chain done: reflect final quest/journal state once
	else:
		_show_next_talk()


## Present a held Odessa talk-stage the moment the player is actually in Ember
## Row (fired on dock if already there, and on switching to the tab).
func _present_bar_talk_if_shown() -> void:
	if _bar_pending_talk.is_empty() \
			or (_active_talk != null and is_instance_valid(_active_talk)):
		return
	if _tabs.get_current_tab_control() == null \
			or _tabs.get_current_tab_control().name != "Ember Row":
		return
	var talk := _bar_pending_talk
	_bar_pending_talk = {}
	Comms.post(str(talk.giver), "Ember Row",
		str(talk.nodes.get("start", {}).get("text", "")))
	var panel := DialoguePanel.new(str(talk.giver), talk.nodes, func(_a: String) -> String:
		return "")
	panel.vo_prefix = str(talk.get("advance", ""))
	_active_talk = panel
	panel.closed.connect(_on_talk_closed.bind(talk))
	add_child(panel)


## Tab display name -> the one-step lesson that introduces it. Names must match
## the `row.name` each _build_*_tab sets, since that IS the tab's title.
const _TAB_LESSON := {
	"Landing Bay": "tab_intro_bay",
	"Landing Pad": "tab_intro_bay",
	"Armory": "tab_intro_armory",
	"Engineering Bay": "tab_intro_engineering",
	"Market Terminal": "tab_intro_market",
	"Market": "tab_intro_market",
	"Mission Computer": "tab_intro_missions",
	"Mission Uplink": "tab_intro_missions",
	"Shipyard": "tab_intro_shipyard",
	"Research Lab": "tab_intro_research",
	"Ember Row": "tab_intro_bar",
}


## Satisfy any step that just wants a tab OPEN, for the tab that is open NOW.
##
## Steps like "Open the colony MARKET" complete on a tab-CHANGE event. A lesson
## that becomes active while the player is already standing on that tab could
## therefore never advance — the event had already happened. That is how the
## "buy 4 food" step never appeared: its predecessor sat waiting for a click the
## pilot had no reason to make.
## The snapshot the declarative tutor reads at every dock refresh (Tutor.observe /
## Tutor._build_preds). Level state — tab, cargo, standing, quest — plus a
## normalized `tab`; the one-shot events (accepted / bought / turned in / viewed
## commissions / fired) arrive through Tutor.did().
func _dock_context() -> Dictionary:
	var ctrl := _tabs.get_current_tab_control()
	var tab := str(ctrl.name) if ctrl != null else ""
	match tab:
		"Landing Bay", "Landing Pad": tab = "Landing Bay"
		"Market Terminal", "Market": tab = "Market"
		"Mission Computer", "Mission Uplink": tab = "Mission"
	var has_wired := false
	for i in Pilot.GEM_SLOTS:
		var aid := Pilot.gem_at(i)
		if aid != "" and ship._known_abilities.has(aid):
			has_wired = true
			break
	var commission_eligible := false
	for p in Professions.visible():
		if Standing.eligible(str(p.id)):
			commission_eligible = true
			break
	var pip_showing := false
	for giver in _held_talks:
		if not (_held_talks[giver] as Array).is_empty():
			pip_showing = true
			break
	return {
		"flying": false,
		"venue": "station" if is_station else "planet",
		"tab": tab,
		"cargo_circuits": int(ship.commodities.get("circuits", 0)),
		"cargo_food": int(ship.commodities.get("food", 0)),
		"needs_scan": ship._needs_scan_ability(),
		# Safety net (user, 2026-07-24): never march a BROKE pilot to the Armory. The
		# flight-training payout (150c) normally lands first, but gate buy_scanner on
		# actually affording the chip so no path ever strands them there.
		"can_afford_scanner": Wallet.credits >= _comp_buy_price(
			load("res://data/components/chips/survey_scan_chip.tres")),
		"knows_scan": ship._known_abilities.has("scan"),
		"has_wired_ability": has_wired,
		"dirtside_active": Quests.active.has("dirtside_run"),
		"dirtside_done": Quests.completed.has("dirtside_run"),   # first job done — later nudges wake after this
		"tutorial_done": SaveGame.tutorial_done,   # gate secondary onboarding nudges until flight training is done
		# Ruel's briefing is "unheard" while it still waits on his desk. By the time
		# this snapshot is taken (end of refresh) _collect_talks has moved it out of
		# Quests' queue into _held_talks, so THAT is where "still pending" lives.
		"ruel_pending": not (_held_talks.get("ruel", []) as Array).is_empty(),
		"turn_in_here": _has_turn_in_here(),
		"met_sella": Pilot.has_met("sella"),
		"met_dex": Pilot.has_met("lab"),
		"no_profession": Pilot.profession == "",
		"commission_eligible": commission_eligible,
		"pip_showing": pip_showing,
		"office_open": Pilot.profession != "" or commission_eligible,
	}


func _note_open_tab() -> void:
	var ctrl := _tabs.get_current_tab_control()
	if ctrl == null:
		return
	match ctrl.name:
		"Pilot": Tutor.note("tab_pilot")
		"Armory": Tutor.note("tab_armory")
		"Engineering Bay": Tutor.note("tab_engineering")
		"Market Terminal", "Market":
			Tutor.note("tab_market" if is_station else "tab_market_planet")
		"Mission Computer", "Mission Uplink":
			Tutor.note("tab_missions" if is_station else "tab_missions_planet")


func _on_tab_changed(_index: int) -> void:
	# Tutor: reaching the Pilot tab completes the "open PILOT" step, so the ping
	# moves on to the loadout panel rather than still pointing at the tab you're
	# already standing in.
	# Re-evaluate the declarative tutor for the newly-open tab: tab-poll steps
	# (open Armory / Market / …) and the first-visit tab-intro filler both arm off
	# the current tab in the dock context.
	Tutor.observe(_dock_context())
	_present_bar_talk_if_shown()
	# An inspect belongs to the tab you inspected it on (the Armory has its own
	# detail panel). Don't let a stale module readout haunt the Market/Missions.
	_detail = ""
	_refresh_info()


## Owned-ship board strip: a little schematic per hull you own, aboard one
## highlighted. Click to board that ship (right here, without leaving refit).
func _refresh_board_ships() -> void:
	for child in _board_row.get_children():
		child.queue_free()
	for index in SampleBuilds.owned:
		var build := SampleBuilds.get_build(index)
		_board_row.add_child(ShipIcon.new(index, build, index == SampleBuilds.current, self))


func _refresh_shipyard() -> void:
	_yard_list.clear()
	for index in SampleBuilds.count():
		var build := SampleBuilds.get_build(index)
		var owned := SampleBuilds.owned.has(index)
		var label := "OWNED" if owned else "%dc" % build.hull.price
		var i := _yard_list.add_item("%s — %s   —   %s" % [
			build.hull.display_name, build.hull.category, label])
		_yard_list.set_item_metadata(i, index)


func _on_ship_selected(list_index: int, _hangar: bool) -> void:
	var index: int = _yard_list.get_item_metadata(list_index)
	var build := SampleBuilds.get_build(index)
	var s := ShipStats.aggregate(build)
	_detail = "[b]%s[/b] — %s, %s\n%s\nmass %.0f   thrust %.0f   accel %.1f   dps %.1f   shield %.0f   armor %.0f   hold %.0f   sensors %.0f" % [
		build.hull.display_name, build.hull.category,
		HullDef.SizeBand.keys()[build.hull.size_band].capitalize(),
		build.hull.trait_description,
		s.mass, s.thrust, s.accel, s.dps, s.shield_hp, s.armor_hp, s.cargo, s.sensor_range]
	_refresh_info()


## Board an owned ship from the ship-deck strip (clicked ShipIcon).
func _board_ship(index: int) -> void:
	_flash_msg = ""
	if index == SampleBuilds.current:
		_flash("Already aboard the %s." % ship.build.hull.display_name)
	else:
		SampleBuilds.current = index
		ship.apply_build(SampleBuilds.get_build(index))
		_selected_slot = -1
		_eng_selected = []
		Sfx.play("click", -12.0, 1.1)
		_flash("Boarded the %s." % ship.build.hull.display_name)
	refresh()


func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "Really wipe everything? Click again"
		_reset_button.modulate = Color(1.0, 0.35, 0.3)
		return
	SaveGame.reset_all_progress()
	get_tree().reload_current_scene()


func _on_buy_ship() -> void:
	_flash_msg = ""
	var sel := _yard_list.get_selected_items()
	if sel.is_empty():
		return
	var index: int = _yard_list.get_item_metadata(sel[0])
	var build := SampleBuilds.get_build(index)
	if SampleBuilds.owned.has(index):
		_flash("You already own a %s." % build.hull.display_name)
	elif Wallet.credits < build.hull.price:
		_flash("Not enough credits (%dc needed)." % build.hull.price)
	else:
		Wallet.credits -= build.hull.price
		SampleBuilds.owned.append(index)
		Sfx.play("jingle", -8.0, 0.9)
		_flash("The %s is yours. She's in the Hangar." % build.hull.display_name)
	refresh()


func _refresh_overview() -> void:
	var s := ShipStats.aggregate(ship.build)
	var bill_repairs := int(ship.dock_bill.get("repairs", 0))
	var bill_ammo := int(ship.dock_bill.get("ammo", 0))
	var status_line := "repaired and ready."
	if bill_repairs > 0 or bill_ammo > 0:
		status_line = "serviced — repairs [color=#f2b859]-%dc[/color], munitions [color=#f2b859]-%dc[/color]." % [
			bill_repairs, bill_ammo]
	if ship.hull < s.hull_hp - 0.5 or ship.armor < s.armor_hp - 0.5:
		status_line += " [color=#f25a50]YARD BILL EXCEEDED FUNDS — repairs incomplete.[/color]"
	var txt := ""
	# THE CAMPAIGN THROUGH-LINE, first thing on every dock, so a player deep in
	# mining/professions never loses the spine (the ember_word freeze taught us
	# the story can sit invisible for ~46 days). One line, its own step, always
	# on top. Empty when the campaign is idle between beats.
	var beat := Quests.current_step()
	if not beat.is_empty():
		txt += "[b][color=#f2b859]▸ CAMPAIGN · %s[/color][/b]\n[color=#cdd3dd]%s[/color]\n\n" % [
			str(beat.title), str(beat.step)]
	if Pilot.created:
		var bg := Pilot.background_def(Pilot.background)
		txt += "[b][color=#f2b859]%s[/color][/b]" % Pilot.full_name()
		if not bg.is_empty():
			txt += "  [color=#8890a0]— %s[/color]" % bg.name
		if Pilot.bio != "":
			txt += "\n[i][color=#8890a0]%s[/color][/i]" % Pilot.bio
		txt += "\n\n"
	txt += "[b]%s[/b] — %s, %s\n\n" % [
		ship.build.hull.display_name, ship.build.hull.category, status_line]
	txt += "mass %.0f   thrust %.0f   accel %.1f\nload %.0f / %.0f capacity\n" % [
		s.mass, s.thrust, s.accel, s.power_draw, s.power_output]
	txt += "dps %.1f   shield %.0f (+%.1f/s)   armor %.0f\nhold %.0f / %.0f   sensors %.0f\n\n" % [
		s.dps, s.shield_hp, s.shield_regen, s.armor_hp, ship.cargo_used(), s.cargo, s.sensor_range]
	if is_station:
		# Hold the Ember Row rumour nudge until the pilot is PAST their first job — during
		# onboarding it competes with "talk to Ruel" and pulls new pilots to Odessa, whose
		# actual quest is several beats away (user, 2026-07-24).
		if Research.rumor_ready() and Quests.completed.has("dirtside_run"):
			txt += "[color=#73bff2]Dockhands keep glancing toward Ember Row — someone in there wants to talk.[/color]\n\n"
		txt += "[color=#f2b859]DOCKSIDE TALK:[/color] [i][color=#a8b0c2]%s[/color][/i]\n\n" % _dockside_talk()
	else:
		txt += "[color=#f2b859]THE COLONY:[/color] [i][color=#a8b0c2]Elder Imari keeps the fields and cisterns and posts the freight the station won't fly; Cartographer Sella buys sensor readings from anywhere in the Reach. Both have work on the Colony board.[/color][/i]\n\n"
	txt += "[color=#8890a0]Press E to launch. Visit the other decks with the tabs above.[/color]"
	_overview_text.text = txt

	_overview_hold.clear()
	for comp in ship.cargo:
		_overview_hold.add_item("%s  Mk%d %s  (mass %.0f)" % [
			comp.display_name, comp.mark, Grades.display_name(comp.grade), comp.mass])
	for key in ship.commodities:
		_overview_hold.add_item("%s x%d  (mass %.0f)" % [TradeGoods.display_name(key),
			ship.commodities[key], ship.commodities[key] * TradeGoods.unit_mass(key)])
	_placeholder_if_empty(_overview_hold, "— hold empty —")
	if _overview_stash != null:
		_overview_stash.clear()
		for comp in Stash.items:
			_overview_stash.add_item("%s  Mk%d %s" % [
				comp.display_name, comp.mark, Grades.display_name(comp.grade)])
		_placeholder_if_empty(_overview_stash, "— stash empty —")
	_refresh_mend()


## The Counter's mediation (planet only): one row per faction you're in the red
## with, a button to buy a slow word back toward neutral (once per game-day).
func _refresh_mend() -> void:
	if _mend_box == null:
		return
	for c in _mend_box.get_children():
		c.queue_free()
	var any := false
	for pd in Professions.visible():
		var fid := str(pd.id)
		if Standing.get_points(fid) >= 0:
			continue   # only the red needs mending
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_mend_box.add_child(row)
		var lbl := RichTextLabel.new()
		lbl.bbcode_enabled = true
		lbl.fit_content = true
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.text = "[b]%s[/b]\n[color=#f25a50]%s %d[/color]" % [
			str(pd.name), Standing.state(fid).to_upper(), Standing.get_points(fid)]
		row.add_child(lbl)
		var btn := Button.new()
		btn.text = "Mend +%d (%dc)" % [Standing.MEND_STEP, Standing.MEND_COST]
		btn.disabled = not (Standing.can_mend(fid) and Wallet.credits >= Standing.MEND_COST)
		if not Standing.can_mend(fid):
			btn.tooltip_text = "The Counter's already spoken for you today — come back tomorrow."
		var f := fid
		btn.pressed.connect(func() -> void: _on_mend(f))
		row.add_child(btn)
	if not any:
		var none := Label.new()
		none.text = "No fences to mend — you're square with everyone."
		none.add_theme_font_size_override("font_size", 12)
		none.add_theme_color_override("font_color", UiTheme.DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_mend_box.add_child(none)


func _on_mend(fid: String) -> void:
	_flash_msg = ""
	if Wallet.credits < Standing.MEND_COST:
		_flash("Not enough credits (%dc)." % Standing.MEND_COST)
	elif not Standing.can_mend(fid):
		_flash("The Counter can only put in one word per day.")
	else:
		Wallet.credits -= Standing.MEND_COST
		var gained := Standing.mend(fid)
		Sfx.play("jingle", -8.0)
		_flash("The Counter put in a word for you. +%d standing with %s." % [
			gained, Professions.display_name(fid)])
	refresh()


## The world advertises itself: one rotating line of bar talk pointing at
## whatever the player hasn't found yet. Deterministic by calendar day so
## it doesn't reroll every refresh — a new rumor each docking.
func _dockside_talk() -> String:
	var hints := PackedStringArray()
	if not ship.scanner_fitted:
		hints.append("Prospectors with survey scanners pull ore maps out of dead rock — and Scan Data the lab pays Insight for. Armory stocks the Prospector unit.")
	if not PoiMap.is_discovered("rust_shoal"):
		hints.append("Freighter crews swear the raiders nest somewhere in the drift north of the lane. Nobody's charted it and come home bragging.")
	if not PoiMap.is_discovered("haunt"):
		hints.append("Something big sweeps the far dark past the colony. Long-range sensors might find where it roosts.")
	if Research.chain_stage.get("wayfinder_core", 0) == 0:
		hints.append("Old-timers say something pre-collapse still whispers out in the Drift Belt. Old-timers say a lot of things.")
	hints.append("The belt's richer past the far rim, if you can stomach how quiet it gets out there.")
	hints.append("Another hauler's gone quiet past the lane. Third this season. Nobody's found so much as a hull plate.")
	return hints[Research.day % hints.size()]


func _refresh_armory() -> void:
	for c in _shop_grid.get_children():
		c.queue_free()
	for c in _armory_grid.get_children():
		c.queue_free()
	for path in SHOP_STOCK:
		var comp: ComponentDef = load(path)
		if _armory_filter == -1 or comp.slot_type() == _armory_filter:
			_shop_grid.add_child(ArmoryTile.new(comp, "shop", self, path))
	# Faction gear (cloak, Crystalline Array, ...) is NOT open-market — it's sold
	# by each profession's leader in the Pilot-tab QUARTERMASTER, never here.
	for comp in ship.cargo:
		if _armory_filter == -1 or comp.slot_type() == _armory_filter:
			_armory_grid.add_child(ArmoryTile.new(comp, "hold", self))
	for comp in Stash.items:
		if _armory_filter == -1 or comp.slot_type() == _armory_filter:
			_armory_grid.add_child(ArmoryTile.new(comp, "stash", self))
	if _shop_grid.get_child_count() == 0:
		_empty_note(_shop_grid, "— nothing here —")
	if _armory_grid.get_child_count() == 0:
		_empty_note(_armory_grid, "— nothing in this category —")


func _refresh_engineering() -> void:
	_refresh_board_ships()
	_refresh_cargo_stash()
	_refresh_paperdoll()
	_refresh_chips()
	_refresh_eng_stats()
	_refresh_fabricator()


func _refresh_eng_stats() -> void:
	var s := ShipStats.aggregate(ship.build)
	var power_color := "#f25a50" if s.power_draw > s.power_output else "#8890a0"
	# "load X / Y" is the fit budget (draw vs reactor output); ENERGY is its own
	# pair now — Capacity (pool) and Recharge (per second), both from the reactor.
	_eng_stats.text = ("[b]%s[/b] — %s\n" +
		"[color=#8890a0]mass %.0f   thrust %.0f   accel %.1f   dps %.1f[/color]\n" +
		"[color=%s]load %.0f / %.0f[/color]" +
		"[color=#73bff2]   energy %.0f cap · %.1f/s[/color]" +
		"[color=#8890a0]   shield %.0f   armor %.0f   hold %.0f   sensors %.0f[/color]") % [
		ship.build.hull.display_name, ship.build.hull.category,
		s.mass, s.thrust, s.accel, s.dps,
		power_color, s.power_draw, s.power_output,
		s.get("energy_capacity", 0.0), s.get("energy_recharge", 0.0),
		s.shield_hp, s.armor_hp, s.cargo, s.sensor_range]


## Cargo (top) and stash (bottom) each fill their own grid; one shared
## selection group so only one tile is highlighted across both.
func _refresh_cargo_stash() -> void:
	for child in _cargo_grid.get_children():
		child.queue_free()
	for child in _stash_grid.get_children():
		child.queue_free()
	var group := ButtonGroup.new()
	var selected_comp = _eng_selected[0] if not _eng_selected.is_empty() else null
	for comp in ship.cargo:
		_add_tile(_cargo_grid, comp, "hold", group, comp == selected_comp)
	for comp in Stash.items:
		_add_tile(_stash_grid, comp, "stash", group, comp == selected_comp)
	# Materials (mined commodities) ride as stack tiles alongside components.
	for key in ship.commodities:
		if int(ship.commodities[key]) > 0:
			_add_material_tile(_cargo_grid, key, int(ship.commodities[key]), "hold")
	for key in Stash.commodities:
		if int(Stash.commodities[key]) > 0:
			_add_material_tile(_stash_grid, key, int(Stash.commodities[key]), "stash")
	_empty_note(_cargo_grid, "— hold empty —")
	_empty_note(_stash_grid, "— stash empty —")


## Materials (mined commodities) ride as stack tiles in the cargo/stash grids.
func _add_material_tile(grid: GridContainer, key: String, qty: int, source: String) -> void:
	grid.add_child(MaterialTile.new(key, qty, source, self))


## Move a whole material stack between the hold and the safe station stash.
func _drop_material_to_location(key: String, source: String, target: String) -> void:
	if source != target and source in ["hold", "stash"]:
		_move_material(key, source, target)


func _toggle_material_location(key: String, source: String) -> void:
	_move_material(key, source, "stash" if source == "hold" else "hold")


func _move_material(key: String, source: String, target: String) -> void:
	_flash_msg = ""
	if source == "hold" and target == "stash":
		var n: int = ship.commodities.get(key, 0)
		if n <= 0:
			return
		ship.remove_commodity(key, n)
		Stash.store_commodity(key, n)
		_flash("%s ×%d stored — safe in the stash." % [TradeGoods.display_name(key), n])
	elif source == "stash" and target == "hold":
		var have: int = Stash.commodities.get(key, 0)
		if have <= 0:
			return
		var unit := TradeGoods.unit_mass(key)
		var room := have
		if unit > 0.0:
			room = mini(have, int(floor((ship.stats.cargo - ship.cargo_used()) / unit)))
		if room <= 0:
			_flash("Hold full — no room for %s." % TradeGoods.display_name(key))
			refresh()
			return
		var moved := Stash.take_commodity(key, room)
		ship.add_commodity(key, moved)
		var msg := "%s ×%d loaded into the hold." % [TradeGoods.display_name(key), moved]
		if moved < have:
			msg += "  (%d stay — hold full)" % (have - moved)
		_flash(msg)
	else:
		return
	Sfx.play("click", -14.0, 1.1)
	refresh()


## Periodic-style glyph + category tint for a material tile (placeholder until
## real icon art lands — the icon pass replaces these AND the component marks).
func _material_glyph(key: String) -> String:
	match key:
		"ferrite_ore": return "Fe"
		"cobalt_ore": return "Co"
		"aurite_ore": return "Au"
		"scan_data": return "Sc"
		"cinder_fragment": return "Cf"
		"wayfinder_core": return "Wf"
		"circuits": return "Ci"
		"food": return "Fd"
		"water": return "Wa"
		"stolen_goods": return "Sg"
	return TradeGoods.display_name(key).left(2)


func _material_color(key: String) -> Color:
	if key == "aurite_ore":
		return Color(0.95, 0.78, 0.42)
	if key.ends_with("_ore"):
		return Color(0.78, 0.74, 0.62)
	if key == "scan_data":
		return Color(0.5, 0.82, 0.95)
	if key == "cinder_fragment" or key == "wayfinder_core":
		return Color(0.78, 0.55, 0.95)
	return Color(0.85, 0.8, 0.68)


## Drop-in component icon: assets/icons/components/<tres-basename>.png, resolved
## from the item's base_path (affixed drop) or resource_path (clean shop gear),
## so a rolled "Sharpened VK-2 Autocannon" shares the base VK-2 icon. Falls back
## to a fitted overlay_sprite, then (in the tile) to the slot+mark label. Art is
## pure drop-in — no .tres edits, survives data regeneration.
func _component_icon(comp: ComponentDef) -> Texture2D:
	if comp.overlay_sprite != null:
		return comp.overlay_sprite
	for src in [comp.base_path, comp.resource_path]:
		if str(src) != "":
			var p := "res://assets/icons/components/%s.png" % str(src).get_file().get_basename()
			if ResourceLoader.exists(p):
				return load(p)
	# ABILITY-BEARING GEAR wears the face of the ability it grants. Every chip
	# already had art at assets/icons/abilities/<id>.png for the gem bar; without
	# this the entire chip family fell back to a grey "S1" text tile in the
	# Armory, the hold, the stash and the Coupling bag.
	# `get()` returns null on a component that has no `tags` at all (most of
	# them), so this must be nil-checked before it is iterated.
	var tags = comp.get("tags")
	if tags != null:
		for tag in tags:
			var aid := Abilities.id_for_tag(str(tag))
			if aid != "":
				var at := Abilities.icon(aid)
				if at != null:
					return at
	return null


## Drop-in material icon: assets/icons/materials/<commodity-key>.png.
func _material_icon(key: String) -> Texture2D:
	var p := "res://assets/icons/materials/%s.png" % key
	return load(p) if ResourceLoader.exists(p) else null


## Takes any CONTAINER, not just a grid: the Coupling's bag row is an HBox, and
## typing this to GridContainer made passing one a PARSE error — the whole
## script failed to load, so New Game died before it started.
func _empty_note(grid: Container, text: String) -> void:
	if grid.get_child_count() == 0:
		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_color_override("font_color", Color(0.38, 0.41, 0.5))
		grid.add_child(lbl)


func _add_tile(grid: GridContainer, comp: ComponentDef, source: String,
		group: ButtonGroup, selected: bool) -> void:
	var tile := EquipTile.new(comp, source, self)
	tile.button_group = group
	tile.button_pressed = selected
	grid.add_child(tile)


## The hull as a holographic schematic (light-blue line art, additive over
## the UI) with its hardpoints where they actually live. Tight clusters of
## slot squares relax apart; displaced squares keep a connector line back
## to their true anchor on the hull.
func _refresh_paperdoll() -> void:
	for child in _doll.get_children():
		child.queue_free()
	# Actual laid-out size; the minimum stands in on the first pre-layout
	# refresh (centering is stable since drawing is relative to box center).
	var box := _doll.size
	if box.x < 120.0 or box.y < 120.0:
		box = DOLL_MIN
	var center := box / 2.0
	var k := 3.0
	var hull_name := ship.build.hull.display_name.to_snake_case()
	var sprite_path := "res://assets/ships/%s.png" % hull_name
	if ResourceLoader.exists(sprite_path):
		var tex: Texture2D = load(sprite_path)
		# PixelLab canvases carry transparent margin: scale by the art's
		# used rect, not the canvas, or the ship renders postage-stamp small.
		var art := Vector2(tex.get_size())
		var img := tex.get_image()
		if img != null:
			var used := img.get_used_rect()
			if used.size.x > 0:
				art = Vector2(used.size)
		# Nose-up display: art is authored nose +X, the doll rotates it
		# -90° — so the art's width maps to the box's HEIGHT and vice versa.
		k = clampf(floorf(minf((box.x - 90.0) / art.y, (box.y - 90.0) / art.x)),
			1.0, 8.0)
		var tr := TextureRect.new()
		tr.texture = tex
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.size = Vector2(tex.get_size()) * k
		tr.position = center - tr.size / 2.0
		tr.pivot_offset = tr.size / 2.0
		tr.rotation = -PI / 2.0
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/shaders/hologram.gdshader")
		tr.material = mat
		_doll.add_child(tr)
	else:
		var poly := Polygon2D.new()
		poly.polygon = ship.build.hull.silhouette
		poly.color = Color(HOLO_BLUE, 0.35)
		var pmat := CanvasItemMaterial.new()
		pmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		poly.material = pmat
		poly.position = center
		poly.rotation = -PI / 2.0
		poly.scale = Vector2(k, k)
		_doll.add_child(poly)

	# Desired square centers = hardpoint anchors; relax overlapping pairs
	# apart so small hulls don't stack their squares into a pile.
	var anchors: Array[Vector2] = []
	var pos: Array[Vector2] = []
	for i in ship.build.hull.hardpoints.size():
		var p := center + ship.build.hull.hardpoints[i].offset.rotated(-PI / 2.0) * k
		anchors.append(p)
		pos.append(p)
	const SQ := 54.0
	for relax_pass in 10:
		for a in pos.size():
			for b in range(a + 1, pos.size()):
				var d := pos[b] - pos[a]
				if absf(d.x) < SQ and absf(d.y) < SQ:
					var push := d.normalized() if d.length() > 0.5 else Vector2.RIGHT
					var overlap := SQ - maxf(absf(d.x), absf(d.y))
					pos[a] -= push * overlap * 0.5
					pos[b] += push * overlap * 0.5
	for i in pos.size():
		pos[i] = pos[i].clamp(Vector2(26, 26), box - Vector2(26, 26))
		if pos[i].distance_to(anchors[i]) > 8.0:
			var line := Line2D.new()
			line.points = [anchors[i], pos[i]]
			line.width = 2.0
			line.default_color = Color(HOLO_BLUE, 0.4)
			_doll.add_child(line)

	var group := ButtonGroup.new()
	for i in ship.build.hull.hardpoints.size():
		var hp := ship.build.hull.hardpoints[i]
		var sq := SlotSquare.new(i, self)
		sq.button_group = group
		sq.button_pressed = i == _selected_slot
		sq.position = pos[i] - sq.custom_minimum_size / 2.0
		var comp := ship.build.component_at(i)
		var letter: String = HardpointDef.SlotType.keys()[hp.slot_type][0]
		if comp != null:
			var tex := _component_icon(comp)
			if tex != null:
				sq.icon = tex
				sq.expand_icon = true
				sq.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			else:
				sq.text = "%s%d" % [letter, comp.mark]
				sq.add_theme_color_override("font_color", Grades.color(comp.grade))
			# THE SAME HOVER AS EVERY OTHER EQUIPMENT SURFACE. This slot used to
			# describe a part with a bare two-line string while the Armory, the
			# hold and the Coupling all gave the full grade panel — so the one
			# screen where you decide what to FIT told you the least about it.
			sq.comp = comp
			var ability := _ability_line(comp)
			var head := (ability + "\n") if ability != "" else ""
			sq.set_tip(head + DockScreen.effect_lines(comp)
				+ "[color=#73bff2]Fitted: %s (%s Mk%d)[/color]\n" % [
					hp.display_name,
					HardpointDef.SlotType.keys()[hp.slot_type].capitalize(), hp.mark]
				+ "[color=#8890a0]value %dc   mass %.0f[/color]\n" % [comp.value(), comp.mass]
				+ "[color=#8890a0]drag out to move · RIGHT-CLICK to unfit[/color]")
			sq.tooltip_text = comp.display_name
		else:
			sq.text = "%s%d" % [letter, hp.mark]
			sq.add_theme_color_override("font_color", Color(HOLO_BLUE, 0.55))
			sq.tooltip_text = "%s (%s Mk%d) — empty" % [
				hp.display_name, HardpointDef.SlotType.keys()[hp.slot_type].capitalize(), hp.mark]
		_doll.add_child(sq)


## Components from both hold and stash in one list, tagged by source.
## Affixed salvage gets a ◆ and an amber row — treasure should look like it.
func _populate_component_hold(list: ItemList, price_fmt: String) -> void:
	list.clear()
	for comp in ship.cargo:
		var i := list.add_item("%s[hold]  %s  Mk%d %s  (%s)" % [
			"◆ " if not comp.affix_ids.is_empty() else "",
			comp.display_name, comp.mark, Grades.display_name(comp.grade),
			price_fmt % comp.value()])
		list.set_item_metadata(i, [comp, "hold"])
		if not comp.affix_ids.is_empty():
			list.set_item_custom_fg_color(i, UiTheme.AMBER)
		else:
			list.set_item_custom_fg_color(i, Grades.color(comp.grade))
	for comp in Stash.items:
		var i := list.add_item("%s[stash]  %s  Mk%d %s  (%s)" % [
			"◆ " if not comp.affix_ids.is_empty() else "",
			comp.display_name, comp.mark, Grades.display_name(comp.grade),
			price_fmt % comp.value()])
		list.set_item_metadata(i, [comp, "stash"])
		if not comp.affix_ids.is_empty():
			list.set_item_custom_fg_color(i, UiTheme.AMBER)
		else:
			list.set_item_custom_fg_color(i, Grades.color(comp.grade))
	_placeholder_if_empty(list, "— no components —")


func _remove_from_source(comp: ComponentDef, source: String) -> void:
	if source == "hold":
		ship.cargo.erase(comp)
	else:
		Stash.items.erase(comp)


## Prices route through the pilot trade seams (1.0 today; the Trader
## profession fills them). Kept here so the buttons and the handlers agree.
func _buy_price(key: String) -> int:
	return int(round(market.sells[key] * Pilot.trade_buy_mult()))


func _sell_price(key: String) -> int:
	return int(round(market.buys[key] * Pilot.trade_sell_mult()))


func _refresh_market() -> void:
	for child in _commodity_box.get_children():
		child.queue_free()
	# What this dock actually produces; everything else it sells is imported.
	var local: Array = ["circuits"] if is_station else ["food", "water"]
	# Ordered: this dock's own products (exports) first, then what it imports,
	# then sell-only goods (ore the industry buys).
	var keys: Array = []
	for k in local:
		if (market.sells.has(k) or market.buys.has(k)) and not keys.has(k):
			keys.append(k)
	for k in market.sells:
		if not keys.has(k):
			keys.append(k)
	for k in market.buys:
		if not keys.has(k):
			keys.append(k)
	for key in keys:
		_add_market_row(key, key in local)

	_market_hold.clear()
	for key in ship.commodities:
		var note := "sells %dc/u here" % _sell_price(key) if market.buys.has(key) \
			else "no buyer here"
		_market_hold.add_item("%s x%d  (%s)" % [
			TradeGoods.display_name(key), ship.commodities[key], note])
	_placeholder_if_empty(_market_hold, "— no goods aboard —")


const MKT_GREEN := Color(0.42, 0.86, 0.46)   # a good deal for the player
const MKT_RED := Color(0.93, 0.45, 0.42)     # a poor deal for the player


## One left-aligned exchange row: "Name (mass) [import]  ....  [Buy Nc] [Sell Nc]".
## Colour is the signal: buy an export (local, cheap) = green, an import
## (premium) = red; sell to a market that WANTS it = green, dump a local glut
## = red. Missing sides get a fixed gap so the Buy/Sell columns line up.
func _add_market_row(key: String, is_local: bool) -> void:
	var sells: bool = market.sells.has(key)
	var buys: bool = market.buys.has(key)
	var rowbox := HBoxContainer.new()
	rowbox.add_theme_constant_override("separation", 8)
	_commodity_box.add_child(rowbox)
	# Icon + text: read the good at a glance, not off one word. Fixed slot so
	# rows align even for a good whose drop-in icon hasn't landed yet.
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(30, 30)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _material_icon(key)
	rowbox.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = "%s  (mass %.0f)%s" % [
		TradeGoods.display_name(key), TradeGoods.unit_mass(key),
		"  [import]" if sells and not is_local else ""]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color",
		(MKT_GREEN if is_local else MKT_RED) if sells else Color(0.85, 0.8, 0.68))
	rowbox.add_child(name_lbl)
	if sells:
		_market_button(rowbox, "Buy %dc" % _buy_price(key),
			MKT_GREEN if is_local else MKT_RED, _on_buy_commodity.bind(key))
	else:
		_market_gap(rowbox)
	if buys:
		_market_button(rowbox, "Sell %dc" % _sell_price(key),
			MKT_RED if is_local else MKT_GREEN, _on_sell_commodity.bind(key))
	else:
		_market_gap(rowbox)


func _market_button(parent: Node, text: String, col: Color, handler: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(96, 0)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col)
	b.pressed.connect(func() -> void: Sfx.play("click", -16.0))
	b.pressed.connect(handler)
	parent.add_child(b)


func _market_gap(parent: Node) -> void:
	var g := Control.new()
	g.custom_minimum_size = Vector2(96, 0)
	parent.add_child(g)


func _refresh_missions() -> void:
	if _offers_list != null:
		_offers_list.clear()
		for entry in MissionLog.offers_for(is_station):
			var m: Dictionary = entry.m
			var idx := _offers_list.add_item("%s  —  %dc" % [MissionLog.label(m), m.reward])
			# Metadata is the GLOBAL offer index so accept() targets the right
			# one after venue filtering.
			_offers_list.set_item_metadata(idx, int(entry.index))
			var face := Npcs.portrait(str(m.get("giver", "")))
			if face != null:
				_offers_list.set_item_icon(idx, face)
	for child in _active_box.get_children():
		child.queue_free()
	if MissionLog.active.is_empty():
		var lbl := Label.new()
		lbl.text = "No contracts in hand."
		_active_box.add_child(lbl)
	for i in MissionLog.active.size():
		var m: Dictionary = MissionLog.active[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_active_box.add_child(row)
		# The giver's face beside their contract — a standing reminder of
		# whose work this is. Blank until the NPC art is dropped in.
		var face := Npcs.portrait(str(m.get("giver", "")))
		if face != null:
			var pic := TextureRect.new()
			pic.texture = face
			pic.custom_minimum_size = Vector2(40, 40)
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(pic)
		var lbl := Label.new()
		lbl.text = "%s  [%d/%d]" % [MissionLog.label(m), MissionLog.progress(m, ship), m.n]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lbl)
		var b := Button.new()
		b.text = "Turn in (%dc)" % m.reward
		b.disabled = not (MissionLog.is_complete(m, ship) and MissionLog.venue_ok(m, is_station))
		b.pressed.connect(_on_turn_in.bind(i))
		row.add_child(b)
	_quests_active.rebuild()
	_quests_done.rebuild()

	var log_txt := ""
	for i in range(Research.journal.size() - 1, -1, -1):
		var entry: Dictionary = Research.journal[i]
		log_txt += "[color=#f2b859]Day %d[/color]  —  %s\n" % [int(entry.day), entry.text]
	if log_txt == "":
		log_txt = "[color=#8890a0]No entries yet. The Reach keeps its stories close.[/color]"
	_mission_log.text = log_txt


func _refresh_research() -> void:
	_refresh_lab_status()
	_lab_leads.clear()
	for id in Research.recovered:
		var art: Dictionary = Research.ARTIFACTS[id]
		var i := _lab_leads.add_item("✦ %s — +1 Insight / %s, forever" % [
			art.name, _rate_text(art.rate_days)])
		_lab_leads.set_item_custom_fg_color(i, UiTheme.AMBER)
		_lab_leads.set_item_metadata(i, id)
	for id in Research.active_leads():
		var i := _lab_leads.add_item("◈ LEAD:  %s   (click for details)" % Research.journal_line(id, ship))
		_lab_leads.set_item_custom_fg_color(i, UiTheme.AMBER)   # a lead is a big deal — make it read like one
		_lab_leads.set_item_metadata(i, id)
	_placeholder_if_empty(_lab_leads, "— no leads yet — rumors travel on dockhands' lips —")

	_tech_list.clear()
	for tree in Research.TREES:
		var h := _tech_list.add_item("—— %s ——" % str(tree.name).to_upper())
		_tech_list.set_item_disabled(h, true)
		_tech_list.set_item_custom_fg_color(h, UiTheme.ACCENT)
		for node in tree.nodes:
			var i: int
			if Research.is_unlocked(node.id):
				i = _tech_list.add_item("✓ %s — researched" % node.name)
				_tech_list.set_item_custom_fg_color(i, Color(0.45, 0.75, 0.5))
			elif node.requires != "" and not Research.is_unlocked(node.requires):
				i = _tech_list.add_item("%s — %d Insight (requires %s)" % [
					node.name, node.cost, Research.find_node(node.requires).name])
				_tech_list.set_item_custom_fg_color(i, Color(0.38, 0.41, 0.5))
			else:
				i = _tech_list.add_item("%s — %d Insight" % [node.name, node.cost])
				if Research.insight >= node.cost:
					_tech_list.set_item_custom_fg_color(i, UiTheme.AMBER)
			_tech_list.set_item_metadata(i, node.id)


func _refresh_lab_status() -> void:
	var txt := "[b][color=#f2b859]INSIGHT  %d[/color][/b]     [color=#8890a0]day %d — a day passes with each docking[/color]\n" % [
		int(Research.insight), Research.day]
	txt += "[color=#8890a0]collection income +%.2f Insight/day   •   Scan Data aboard: %d[/color]" % [
		Research.income_per_day(), ship.commodities.get("scan_data", 0)]
	_lab_status.text = txt


func _rate_text(days: int) -> String:
	return "day" if days == 1 else "%d days" % days


func _on_lead_selected(index: int) -> void:
	var id = _lab_leads.get_item_metadata(index)
	if id == null:
		return
	if Research.recovered.has(id):
		var art: Dictionary = Research.ARTIFACTS[id]
		_detail = "[b]%s[/b] — yields 1 Insight every %s, forever\n[i][color=#8890a0]%s[/color][/i]" % [
			art.name, _rate_text(art.rate_days), art.desc]
		_show_info_modal("✦ %s" % str(art.name), _detail)
	else:
		_detail = "[b]Expedition lead[/b]\n%s" % Research.journal_line(id, ship)
		_show_info_modal("◈ EXPEDITION LEAD",
			"[color=#f2b859]%s[/color]\n\n[color=#8890a0]Follow it in flight — the chart marks the way, and this lead updates as you make progress.[/color]" \
			% Research.journal_line(id, ship))
	_refresh_info()


## A centered, dismissable info modal — used to give a lead the spotlight it
## deserves (it was buried in the bottom status line before). Generic: title +
## BBCode body + Close. CenterContainer so it never drifts off-centre.
func _show_info_modal(title: String, body: String) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.BG, 0.99)
	style.border_color = UiTheme.AMBER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(26.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	var h := Label.new()
	h.text = title
	h.add_theme_color_override("font_color", UiTheme.AMBER)
	h.add_theme_font_size_override("font_size", 20)
	col.add_child(h)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(500, 0)
	rt.text = body
	col.add_child(rt)
	var close := Button.new()
	close.text = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiTheme.button_flavor(close, "tertiary", 220.0)
	close.pressed.connect(func() -> void:
		Sfx.play("click", -14.0)
		shade.queue_free())
	col.add_child(close)


func _on_trade_scan_data() -> void:
	_flash_msg = ""
	var n: int = ship.commodities.get("scan_data", 0)
	if n <= 0:
		_flash("No Scan Data aboard — survey the system with a scanner and [1].")
	else:
		ship.remove_commodity("scan_data", n)
		Research.insight += n * Research.SCAN_DATA_INSIGHT
		Standing.add("science", maxi(1, n / 2))   # data work earns Dex's respect
		Sfx.play("jingle", -8.0)
		_flash("Archived %d Scan Data — +%d Insight." % [n, n * Research.SCAN_DATA_INSIGHT])
	refresh()


func _on_tech_selected(index: int) -> void:
	var id = _tech_list.get_item_metadata(index)
	if id == null:
		return
	var node := Research.find_node(id)
	if Research.is_unlocked(id):
		_detail = "[b]%s[/b] — RESEARCHED\n[i][color=#8890a0]%s[/color][/i]" % [node.name, node.desc]
	else:
		var req_txt := ""
		if node.requires != "":
			req_txt = "   (requires %s)" % Research.find_node(node.requires).name
		_detail = "[b]%s[/b] — %d Insight%s\n[i][color=#8890a0]%s[/color][/i]" % [
			node.name, node.cost, req_txt, node.desc]
	_refresh_info()


func _on_research_node() -> void:
	_flash_msg = ""
	var sel := _tech_list.get_selected_items()
	if sel.is_empty():
		return
	var id = _tech_list.get_item_metadata(sel[0])
	if id == null:
		return
	var err := Research.unlock(id)
	if err != "":
		_flash(err)
	else:
		Sfx.play("jingle", -8.0, 1.1)
		_flash("%s researched." % Research.find_node(id).name)
	refresh()


func _refresh_fabricator() -> void:
	_fab_list.clear()
	if not Research.is_unlocked("fab_1"):
		var i := _fab_list.add_item("— fabricator offline: commission at the Research Lab —")
		_fab_list.set_item_disabled(i, true)
		_fab_list.set_item_custom_fg_color(i, Color(0.38, 0.41, 0.5))
	# Locked recipes still show, greyed with their gating research — the
	# machine advertises what Insight buys.
	for r in Research.RECIPES:
		if Research.is_unlocked(r.node):
			var i := _fab_list.add_item("%s  —  %s" % [r.name, _materials_text(r)])
			_fab_list.set_item_metadata(i, r)
		else:
			var i := _fab_list.add_item("LOCKED  %s — research %s" % [
				r.name, Research.find_node(r.node).name])
			_fab_list.set_item_disabled(i, true)
			_fab_list.set_item_custom_fg_color(i, Color(0.38, 0.41, 0.5))


func _materials_text(recipe: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in recipe.materials:
		parts.append("%s x%d" % [TradeGoods.display_name(key), recipe.materials[key]])
	return ", ".join(parts)


func _on_recipe_selected(index: int) -> void:
	var recipe = _fab_list.get_item_metadata(index)
	if recipe == null:
		return
	var comp: ComponentDef = load(recipe.output)
	_detail = _describe(comp) + "\n[color=#f2b859]Materials: %s[/color]" % _materials_text(recipe)
	_refresh_info()


func _on_fabricate() -> void:
	_flash_msg = ""
	var sel := _fab_list.get_selected_items()
	if sel.is_empty():
		return
	var recipe = _fab_list.get_item_metadata(sel[0])
	if recipe == null:
		return
	for key in recipe.materials:
		if ship.commodities.get(key, 0) < int(recipe.materials[key]):
			_flash("Missing materials — needs %s." % _materials_text(recipe))
			refresh()
			return
	for key in recipe.materials:
		ship.remove_commodity(key, int(recipe.materials[key]))
	var comp: ComponentDef = load(recipe.output)
	if ship.can_carry(comp):
		ship.add_cargo(comp)
		_flash("%s fabricated — in your hold." % comp.display_name)
	else:
		# The hold just shed ore mass, but a heavy output can still overflow;
		# overflow goes to the stash so fabrication never jams or eats parts.
		Stash.items.append(comp)
		_flash("%s fabricated — hold full, sent to the stash." % comp.display_name)
	Sfx.play("jingle", -8.0, 0.95)
	refresh()


func _describe(comp: ComponentDef) -> String:
	var gc := Grades.color(comp.grade).to_html(false)
	var out := "[b][color=#%s]%s[/color][/b]  —  [color=#%s]Mk %d %s[/color]   mass %.0f   load %.0f   value %dc" % [
		gc, comp.display_name, gc,
		comp.mark, Grades.display_name(comp.grade), comp.mass, comp.power_draw, comp.value()]
	if comp.stat_summary() != "":
		out += "\n" + comp.stat_summary()
	var abil := _ability_line(comp)
	if abil != "":
		out += "\n" + abil
	# Affix lines: gold for gifts, red for the Flotsam curse.
	for id in comp.affix_ids:
		var affix_color := "f25a50" if Affixes.is_drawback(id) else "f2b859"
		out += "\n[color=#%s]◆ %s[/color]" % [affix_color, Affixes.text(id)]
	if comp.description != "":
		out += "\n[i][color=#8890a0]%s[/color][/i]" % comp.description
	return out


## The SPECIAL ABILITY a component grants, as a prominent BBCode block (or "") —
## a mining laser's ore-cutting, or the gem ability a fitted system unlocks. So
## a player never has to guess that the Ferro Cutter mines or the scanner scans.
func _ability_line(comp: ComponentDef) -> String:
	if comp is WeaponDef and (comp as WeaponDef).mining_power > 0.0:
		return "[b][color=#f2b859]⛏ MINING LASER[/color][/b][color=#8fe08f] — cuts ore from asteroids at full yield; ordinary guns only chip rock.[/color]"
	var ab := Abilities.granted_by(comp)
	if not ab.is_empty():
		return "[b][color=#f2b859]▸ GRANTS ABILITY — %s[/color][/b]\n[color=#8fe08f]%s[/color]\n[color=#73bff2]Fit it, then wire it to a [1]–[5] bus slot (Pilot tab).[/color]" % [
			str(ab.name), str(ab.desc)]
	return ""


## A BBCode tooltip whose NAME is grade-coloured (default Button tooltips are
## plain text). The tiles override _make_custom_tooltip to use it. Returns just
## the content — Godot already wraps a custom tooltip in the theme's TooltipPanel,
## so adding our own panel here would double the border.
## WHAT THE PART ACTUALLY DOES, for a tooltip. Tiles used to show name, grade,
## mass and price — everything except the reason to buy it. A cargo pod read as
## "Strapdown Cargo Pod, mass 4, 60c" with no mention that it adds hold space.
## `stat_summary()` is each schema's own effect line, so this stays correct for
## every component type without a lookup table.
static func effect_lines(comp: ComponentDef) -> String:
	var out := ""
	var stats := comp.stat_summary()
	if stats != "":
		out += "[color=#8fe08f]%s[/color]\n" % stats
	if comp.description != "":
		out += "[i][color=#a8b0c2]%s[/color][/i]\n" % comp.description
	return out


## The ability equivalent of grade_tooltip: icon + name, then the body from
## Abilities.tooltip_body. Same visual weight as an equipment hover, because an
## ability IS equipment now — it lives on a chip in the Coupling.
static func ability_tooltip(aid: String, body: String) -> Control:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(260, 0)
	var art := "res://assets/icons/abilities/%s.png" % aid
	var img := "[img=28]%s[/img]  " % art if ResourceLoader.exists(art) else ""
	rt.text = "%s[b][color=#f2b859]%s[/color][/b]
%s" % [
		img, Abilities.display_name(aid), body]
	return rt


## A button that hovers like equipment does. Used by the gem slots and the
## ability book so both explain cost, source and readiness rather than showing a
## bare description string.
class AbilityButton extends Button:
	var aid: String
	var _tip: String

	func _init(p_aid: String, p_tip: String) -> void:
		aid = p_aid
		_tip = p_tip
		tooltip_text = Abilities.display_name(p_aid)

	func _make_custom_tooltip(_for_text: String) -> Object:
		return DockScreen.ability_tooltip(aid, _tip)


## THE HULL EQUIVALENT of grade_tooltip. A hull is gear: it has a quality and a
## level like anything else you fit, and the thing a buyer actually compares is
## its SLOT SET — which types, at which marks. That was previously only visible
## by boarding the ship and reading the paperdoll.
static func hull_tooltip(build: ShipBuild) -> Control:
	var hull := build.hull
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(300, 0)
	var gc := Grades.color(hull.grade).to_html(false)
	var s := ShipStats.aggregate(build)

	# Slot set, counted by TYPE and best mark — the "better slots even though
	# it's smaller" axis the levelling is meant to open up.
	var counts := {}
	var best := {}
	for hp in hull.hardpoints:
		var key: String = HardpointDef.SlotType.keys()[hp.slot_type].capitalize()
		counts[key] = int(counts.get(key, 0)) + 1
		best[key] = maxi(int(best.get(key, 0)), hp.mark)
	var slot_lines := ""
	for key in counts:
		slot_lines += "
  %s ×%d  [color=#8890a0]up to Mk %d[/color]" % [
			key, int(counts[key]), int(best[key])]

	rt.text = "[b][color=#%s]%s[/color][/b]
[color=#%s]%s  ·  Level %d[/color]
[color=#8890a0]%s, %s[/color]

" % [
		gc, hull.display_name, gc, Grades.display_name(hull.grade), hull.level,
		hull.category, HullDef.SizeBand.keys()[hull.size_band].capitalize().replace("_", " ")]
	if str(hull.trait_description) != "":
		rt.text += "[color=#f2b859]%s[/color]

" % hull.trait_description
	rt.text += "[color=#a8b0c2]hull %.0f   armor %.0f   shield %.0f[/color]
" % [
		s.hull_hp, s.armor_hp, s.shield_hp]
	rt.text += "[color=#a8b0c2]accel %.1f   dps %.1f   hold %.0f   mass %.0f[/color]
" % [
		s.accel, s.dps, s.cargo, s.mass]
	rt.text += "
[b]HARDPOINTS[/b]%s" % slot_lines
	return rt


static func grade_tooltip(comp: ComponentDef, body: String) -> Control:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(250, 0)
	var gc := Grades.color(comp.grade).to_html(false)
	var nm := ("◆ " if not comp.affix_ids.is_empty() else "") + comp.display_name
	# Name on its own line, then grade + size on the SECOND line — so the rarity/
	# Mk phrase never wraps mid-word behind the name (the "· " separator is gone
	# now that the line break does that job).
	rt.text = "[b][color=#%s]%s[/color][/b]\n[color=#%s]%s Mk %d[/color]\n%s" % [
		gc, nm, gc, Grades.display_name(comp.grade), comp.mark, body]
	return rt


## Armory tile helpers: prices (via the pilot trade seams) + inspect.
func _comp_buy_price(comp: ComponentDef) -> int:
	return int(comp.value() * BUY_MULT)


func _comp_sell_price(comp: ComponentDef) -> int:
	return int(round(comp.value() * Pilot.sell_mult()))


func _on_armory_tile_selected(comp: ComponentDef) -> void:
	_detail = _describe(comp)
	if _armory_detail != null:
		_armory_detail.text = _detail


func _on_list_selected(index: int, getter: Callable) -> void:
	_detail = _describe(getter.call(index))
	if _armory_detail != null:
		_armory_detail.text = _detail
	_refresh_info()


func _on_tile_selected(comp: ComponentDef, source: String) -> void:
	_eng_selected = [comp, source]
	_detail = _describe(comp) + "\n[color=#8890a0]location: %s[/color]" % source
	_refresh_info()


func _on_slot_square(slot_index: int) -> void:
	_selected_slot = slot_index
	var hp := ship.build.hull.hardpoints[slot_index]
	var comp := ship.build.component_at(slot_index)
	if comp != null:
		_detail = _describe(comp)
	else:
		_detail = "[b]%s[/b] — empty %s hardpoint, fits up to Mk %d%s" % [
			hp.display_name, HardpointDef.SlotType.keys()[hp.slot_type].capitalize(),
			hp.mark, "  (arc %d deg)" % hp.arc_deg if hp.slot_type == HardpointDef.SlotType.WEAPON else ""]
	_refresh_info()


## "" if comp legally fits the slot, else the visible reason.
func _fit_error(comp: ComponentDef, slot_index: int) -> String:
	var hp := ship.build.hull.hardpoints[slot_index]
	# A CHIP is not hardpoint gear — it belongs in the Coupling. Say so, rather
	# than the generic "doesn't fit a Coupling slot", which would read as a bug.
	if comp is AbilityChipDef:
		return "%s is an ability chip — load it into your Universal Coupling." \
			% comp.display_name
	if comp.slot_type() != hp.slot_type:
		return "%s doesn't fit a %s slot." % [comp.display_name,
			HardpointDef.SlotType.keys()[hp.slot_type].capitalize()]
	if comp.mark > hp.mark:
		return "Mk%d is too large for this Mk%d hardpoint." % [comp.mark, hp.mark]
	if comp is SystemDef and not (comp as SystemDef).fittable_by(Pilot.profession):
		return "%s needs the %s commission to fit." % [comp.display_name,
			Professions.display_name((comp as SystemDef).profession_lock)]
	return ""


## The Coupling's bag slots: one square per capacity, filled left to right,
## empty ones drawn as open clips. Right-click a loaded chip to pull it back
## out. Uses the Armory's tile treatment so ship equipment looks like ship
## equipment everywhere.
func _refresh_chips() -> void:
	if _chip_row == null:
		return
	for c in _chip_row.get_children():
		c.queue_free()
	var cap := ship.build.chip_capacity()
	if cap <= 0:
		_empty_note(_chip_row, "— no Coupling fitted —")
		return
	# A Bespoke rack holds 64; drawing 64 clips would swamp the panel, so show
	# what's loaded plus a few free ones and state the true capacity.
	var shown: int = mini(cap, maxi(ship.build.chips.size() + 2, 6))
	for i in shown:
		if i < ship.build.chips.size():
			_chip_row.add_child(ChipTile.new(ship.build.chips[i], i, self))
		else:
			_chip_row.add_child(ChipTile.new(null, i, self))
	var tail := Label.new()
	tail.text = "  %d / %d" % [ship.build.chips.size(), cap]
	tail.add_theme_font_size_override("font_size", 11)
	tail.add_theme_color_override("font_color", UiTheme.DIM)
	_chip_row.add_child(tail)


## Load a chip from the hold or stash into the Coupling.
func _load_chip(chip: AbilityChipDef, source: String) -> void:
	_flash_msg = ""
	var err := _chip_error(chip)
	if err != "":
		_flash(err)
	else:
		_remove_from_source(chip, source)
		ship.build.chips.append(chip)
		ship.apply_build(ship.build)
		Tutor.note("coupling")   # they loaded it themselves
		Sfx.play("click", -14.0, 1.3)
		_flash("%s loaded — the ability is in your library. Wire it to a bus slot on the Pilot tab." \
			% chip.display_name)
	refresh()


## Pull a chip back out. Free (no destructive install — see
## docs/ability_coupling.md); it lands in the hold, or the stash if the hold is
## full, so a chip can never be destroyed by having nowhere to go.
func _unload_chip(index: int) -> void:
	_flash_msg = ""
	if index < 0 or index >= ship.build.chips.size():
		return
	var chip: AbilityChipDef = ship.build.chips[index]
	ship.build.chips.remove_at(index)
	if ship.can_carry(chip):
		ship.add_cargo(chip)
		_flash("%s pulled — it's in your hold." % chip.display_name)
	else:
		Stash.items.append(chip)
		_flash("%s pulled — hold was full, so it's in the stash." % chip.display_name)
	ship.apply_build(ship.build)
	Sfx.play("click", -16.0, 0.9)
	refresh()


## Loading a chip into the Coupling — the bag-slot equivalent of _fit_error.
func _chip_error(chip: AbilityChipDef) -> String:
	var cap := ship.build.chip_capacity()
	if cap <= 0:
		return "No Universal Coupling fitted — nothing to load chips into."
	if ship.build.chips.size() >= cap:
		return "Coupling is full (%d/%d). Pull a chip out first." % [
			ship.build.chips.size(), cap]
	if chip.profession_lock != "" and chip.profession_lock != Pilot.profession:
		return "%s needs the %s commission." % [chip.display_name,
			Professions.display_name(chip.profession_lock)]
	for c in ship.build.chips:
		if c != null and c.tags == chip.tags:
			return "That ability is already loaded."
	return ""


func _fit_from(comp: ComponentDef, source: String, slot_index: int) -> void:
	_flash_msg = ""
	var err := _fit_error(comp, slot_index)
	if err != "":
		_flash(err)
	else:
		# Displaced part goes to the stash, so a refit can never jam.
		var old := ship.build.component_at(slot_index)
		_remove_from_source(comp, source)
		ship.build.slots[slot_index] = comp
		if old != null:
			Stash.items.append(old)
		ship.apply_build(ship.build)
		_eng_selected = []
		Sfx.play("click", -14.0, 1.2)
		_flash("%s fitted to %s." % [comp.display_name,
			ship.build.hull.hardpoints[slot_index].display_name])
		# Fitting it themselves is the last step of the gear lesson. Note it
		# AFTER apply_build, so if the new module grants an ability the
		# "memorize" lesson arms cleanly behind this one.
		Tutor.note("paperdoll")
	refresh()


## Right-click fit: an empty compatible slot first, else the first
## compatible slot (displacing to stash).
func _auto_fit(comp: ComponentDef, source: String) -> void:
	_flash_msg = ""
	# A chip has no hardpoint to auto-fit into — right-clicking one loads it
	# straight into the Coupling, which is the equivalent gesture.
	if comp is AbilityChipDef:
		_load_chip(comp, source)
		return
	var first := -1
	var target := -1
	for i in ship.build.hull.hardpoints.size():
		if _fit_error(comp, i) == "":
			if first < 0:
				first = i
			if ship.build.component_at(i) == null:
				target = i
				break
	if target < 0:
		target = first
	if target < 0:
		_flash("No hardpoint on this hull fits %s (needs a %s slot, Mk%d+)." % [
			comp.display_name,
			HardpointDef.SlotType.keys()[comp.slot_type()].capitalize(), comp.mark])
		refresh()
	else:
		_fit_from(comp, source, target)


## The Armory shows detail in its own right-hand panel, so the shared bottom
## line drops it there instead of doubling up.
func _armory_showing() -> bool:
	return _armory_detail != null and _tabs != null \
		and _tabs.get_current_tab_control() != null \
		and _tabs.get_current_tab_control().name == "Armory"


func _refresh_info() -> void:
	var out := ""
	if _flash_msg != "":
		out += "[color=#eeaa44]%s[/color]\n" % _flash_msg
	if _detail != "" and not _armory_showing():
		out += _detail + "\n"
	var s := ShipStats.aggregate(ship.build)
	out += "[color=#8890a0]hold %.0f/%.0f   load %.0f/%.0f   credits %dc[/color]" % [
		ship.cargo_used(), s.cargo, s.power_draw, s.power_output, Wallet.credits]
	var errors := ShipStats.validate(ship.build)
	if not errors.is_empty():
		out += "\n[color=#ee5544]UNDOCK BLOCKED:[/color]"
		for e in errors:
			out += "\n[color=#ee5544] - %s[/color]" % e
	_info.text = out


func _flash(msg: String) -> void:
	_flash_msg = msg


func _buy_component(path: String) -> void:
	_flash_msg = ""
	var comp: ComponentDef = load(path)
	var price := _comp_buy_price(comp)
	if Wallet.credits < price:
		_flash("Not enough credits (%dc needed)." % price)
	elif not ship.can_carry(comp):
		_flash("Hold can't take %s (mass %.0f)." % [comp.display_name, comp.mass])
	else:
		Wallet.credits -= price
		ship.add_cargo(load(path))
		# A distinct ACQUIRE cue, not the generic UI click — a purchase (incl. a
		# profession module at the quartermaster) should sound like you got something.
		Sfx.play("pickup", -8.0)
		_flash("Bought %s — %dc." % [comp.display_name, price])
		Tutor.did("armory_bought")   # completes the buy_scanner "bought" step
	refresh()


func _sell_component(comp: ComponentDef, source: String) -> void:
	_flash_msg = ""
	var price := _comp_sell_price(comp)
	Wallet.credits += price
	_remove_from_source(comp, source)
	Sfx.play("click", -12.0)
	_flash("Sold %s — %dc." % [comp.display_name, price])
	refresh()


## Advance a market step only once its QUANTITY is satisfied. A step with no
## `need` clears on the first trade, as before.
func _note_market(anchor: String) -> void:
	var step := Tutor.current()
	var need := int(step.get("need", 0))
	var good := str(step.get("good", ""))
	if need > 0 and good != "" and int(ship.commodities.get(good, 0)) < need:
		return
	Tutor.note(anchor)


func _on_buy_commodity(key: String) -> void:
	_flash_msg = ""
	var price := _buy_price(key)
	if Wallet.credits < price:
		_flash("Not enough credits (%dc)." % price)
	elif not ship.can_carry_mass(TradeGoods.unit_mass(key)):
		_flash("Hold full.")
	else:
		Wallet.credits -= price
		ship.add_commodity(key, 1)
		# Buying where a good is MADE — station circuits outbound, colony food
		# on the way home. Venue-tagged so each leg advances its own lesson.
		# A step may demand a QUANTITY ("need"): a 4-crate contract isn't taught
		# by buying one, so the ping holds until the hold actually covers it.
		_note_market("market_goods" if is_station else "market_goods_planet")
	refresh()


func _on_sell_commodity(key: String) -> void:
	_flash_msg = ""
	if ship.commodities.get(key, 0) <= 0:
		_flash("No %s in hold." % TradeGoods.display_name(key))
	elif not market.buys.has(key):
		_flash("No buyer for %s here." % TradeGoods.display_name(key))
	else:
		ship.remove_commodity(key, 1)
		Wallet.credits += _sell_price(key)
		if key.ends_with("_ore"):
			Standing.add("miner", 1)   # ore off your hold = Doug's kind of work
		# Selling where a good is WANTED closes a leg of the route.
		_note_market("market_goods" if is_station else "market_goods_planet")
	refresh()


## Right-click a filled slot square: unfit it to the hold (or the stash if
## the hold can't take the mass). The button-free "equipped -> cargo" move.
func _unfit_slot(slot_index: int) -> void:
	_flash_msg = ""
	var comp := ship.build.component_at(slot_index)
	if comp == null:
		return
	ship.build.slots.erase(slot_index)
	if ship.can_carry(comp):
		ship.add_cargo(comp)
		_flash("%s unfitted to the hold." % comp.display_name)
	else:
		Stash.items.append(comp)
		_flash("%s unfitted — hold full, sent to the stash." % comp.display_name)
	ship.apply_build(ship.build)
	Sfx.play("click", -14.0, 0.9)
	refresh()


## A tile or fitted component was DRAGGED onto an inventory area. `target` is
## "hold" or "stash"; `source` is "hold"/"stash"/"slot". Same moves as the
## right-click shortcuts, reachable by drag.
func _drop_to_location(comp: ComponentDef, source: String, target: String) -> void:
	_flash_msg = ""
	if source == target:
		return
	if source == "slot":
		var key = ship.build.slots.find_key(comp)
		if key == null:
			return
		ship.build.slots.erase(int(key))
		if target == "hold" and ship.can_carry(comp):
			ship.add_cargo(comp)
			_flash("%s unfitted to the hold." % comp.display_name)
		else:
			Stash.items.append(comp)
			_flash("%s unfitted to the stash." % comp.display_name)
		ship.apply_build(ship.build)
	elif source == "hold":   # -> stash
		if not ship.cargo.has(comp):
			return
		ship.cargo.erase(comp)
		Stash.items.append(comp)
		_flash("%s stored in the stash." % comp.display_name)
	else:                    # stash -> hold
		if not Stash.items.has(comp):
			return
		if not ship.can_carry(comp):
			_flash("Hold can't take %s (mass %.0f)." % [comp.display_name, comp.mass])
			refresh()
			return
		Stash.items.erase(comp)
		ship.add_cargo(comp)
		_flash("%s moved to the hold." % comp.display_name)
	_eng_selected = []
	Sfx.play("click", -14.0, 1.1)
	refresh()


## Shift+right-click a tile: move it between cargo and stash. Hold->stash is
## always fine; stash->hold respects the mass budget.
func _toggle_location(comp: ComponentDef, source: String) -> void:
	_flash_msg = ""
	if source == "hold":
		if not ship.cargo.has(comp):
			return
		ship.cargo.erase(comp)
		Stash.items.append(comp)
		_flash("%s stored in the stash." % comp.display_name)
	else:
		if not Stash.items.has(comp):
			return
		if not ship.can_carry(comp):
			_flash("Hold can't take %s (mass %.0f)." % [comp.display_name, comp.mass])
			refresh()
			return
		Stash.items.erase(comp)
		ship.add_cargo(comp)
		_flash("%s moved to the hold." % comp.display_name)
	_eng_selected = []
	Sfx.play("click", -14.0, 1.1)
	refresh()


func _on_accept() -> void:
	_flash_msg = ""
	var sel := _offers_list.get_selected_items()
	if sel.is_empty():
		return
	# The list is venue-filtered; the row's metadata is the global offer index.
	if not MissionLog.accept(int(_offers_list.get_item_metadata(sel[0]))):
		_flash("Mission log full (max %d active)." % MissionLog.MAX_ACTIVE)
	else:
		Tutor.did("accepted_contract")   # they took the contract themselves
	MissionLog.ensure_offers()
	refresh()


func _on_turn_in(index: int) -> void:
	_flash_msg = ""
	# Read the contract before turn_in consumes it, so it can feed standing.
	var m: Dictionary = {}
	if index >= 0 and index < MissionLog.active.size():
		m = MissionLog.active[index]
	if MissionLog.turn_in(index, ship):
		Tutor.did("turned_in")   # the loop closes: work -> cargo -> paid
		Tutor.retire("turn_in")        # they did it; no need to be told how
		# Standing follows the GIVER, not the work type. Sella's Scan Data runs
		# are `delivery` contracts, so a type-only map (delivery->trader) fed her
		# survey work to the Traders and left Scout standing stuck once the map's
		# secrets were all charted. Doing a guild's work builds that guild.
		var fac := MissionLog.faction_for(m)
		if fac != "":
			Standing.add(fac, 2)
		# Turning this in may have COMPLETED a quest (MissionLog.turn_in →
		# Quests.note_contract). Check for the next one so its giver — Voss after
		# Ruel's board work — greets you right here, not after a redock.
		Quests.check_new_work(is_station, SaveGame.tutorial_done)
		Sfx.play("jingle", -8.0)
		_flash("Contract complete. Payment received.")
	refresh()


## One square of equipment in the Engineering hold grid. Click selects,
## right-click auto-fits, dragging carries {comp, source} to a SlotSquare.
## One clip in the Universal Coupling. Loaded clips wear the same grade border,
## pips and icon as every other piece of gear (ship equipment should look like
## ship equipment everywhere); empty clips are a dashed outline you can drop on.
## THE PIP: a pulsing dot in the top-right corner of any tab where someone is
## waiting. Drawn as an overlay over the tab strip rather than as a tab icon,
## because an icon can't breathe — and a still dot on a busy dock screen is just
## more chrome. Reads `get_tab_rect()` the same way the tutor ping does.
##
## Ignores the mouse: the pip points, the TAB is what you click.
class TabPips extends Control:
	var tabs: TabContainer
	var screen: DockScreen
	var _t := 0.0

	func _init(p_tabs: TabContainer, p_screen: DockScreen) -> void:
		tabs = p_tabs
		screen = p_screen
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		z_index = 20

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if tabs == null or not is_instance_valid(tabs):
			return
		var bar: TabBar = tabs.get_tab_bar()
		if bar == null:
			return
		var pulse: float = 0.5 + 0.5 * sin(_t * 4.0)
		for i in bar.tab_count:
			if not screen._tab_has_waiting(bar.get_tab_title(i)):
				continue
			var r := bar.get_tab_rect(i)
			var at := bar.global_position - global_position + r.position \
				+ Vector2(r.size.x - 7.0, 7.0)
			# Dark backing ring so the dot reads on any tab state, then the pip.
			draw_circle(at, 5.5, Color(0.05, 0.06, 0.09, 0.95))
			draw_circle(at, 4.0 + 1.2 * pulse, Color(0.98, 0.72, 0.30,
				0.55 + 0.45 * pulse))


class ChipTile extends Button:
	var chip: AbilityChipDef
	var index: int
	var screen: DockScreen
	var _tip_body: String

	func _init(p_chip: AbilityChipDef, p_index: int, p_screen: DockScreen) -> void:
		chip = p_chip
		index = p_index
		screen = p_screen
		custom_minimum_size = Vector2(46, 46)
		if chip == null:
			text = "+"
			add_theme_font_size_override("font_size", 16)
			add_theme_color_override("font_color", Color(0.38, 0.43, 0.52))
			var eb := StyleBoxFlat.new()
			eb.bg_color = Color(0.10, 0.12, 0.17, 0.55)
			eb.border_color = Color(0.30, 0.35, 0.44)
			eb.set_border_width_all(1)
			eb.set_corner_radius_all(4)
			add_theme_stylebox_override("normal", eb)
			tooltip_text = "Empty clip — drop an ability chip here."
			return

		# The ability's own art, so a loaded clip reads at a glance.
		var ab := Abilities.granted_by(chip)
		var tex: Texture2D = Abilities.icon(str(ab.get("id", ""))) if not ab.is_empty() else null
		if tex != null:
			icon = tex
			expand_icon = true
			icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			text = str(ab.get("name", chip.display_name)).left(4)
			add_theme_font_size_override("font_size", 11)
		var gc := Grades.color(chip.grade)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(gc.r, gc.g, gc.b, 0.14)
		sb.border_color = gc
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		add_theme_stylebox_override("normal", sb)
		var sb_hi: StyleBoxFlat = sb.duplicate()
		sb_hi.bg_color = Color(gc.r, gc.g, gc.b, 0.30)
		add_theme_stylebox_override("hover", sb_hi)
		add_theme_stylebox_override("pressed", sb_hi)
		var pips: int = Grades.INFO[chip.grade]["pips"]
		if pips > 0:
			var pl := Label.new()
			pl.text = "•".repeat(pips)
			pl.add_theme_font_size_override("font_size", 9)
			pl.add_theme_color_override("font_color", gc)
			pl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			pl.add_theme_constant_override("outline_size", 3)
			pl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pl.grow_vertical = Control.GROW_DIRECTION_BEGIN
			pl.offset_bottom = -1
			pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(pl)
		_tip_body = DockScreen.effect_lines(chip) \
			+ "[color=#8890a0]RIGHT-CLICK to pull this chip back to your hold[/color]"
		tooltip_text = chip.display_name

	func _make_custom_tooltip(_for_text: String) -> Object:
		return DockScreen.grade_tooltip(chip, _tip_body) if chip != null else null

	func _gui_input(event: InputEvent) -> void:
		if chip == null:
			return
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_RIGHT:
			screen._unload_chip(index)
			accept_event()

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.get("comp") is AbilityChipDef

	func _drop_data(_at: Vector2, data: Variant) -> void:
		screen._load_chip(data["comp"], str(data.get("source", "hold")))


class EquipTile extends Button:
	var comp: ComponentDef
	var source: String
	var screen: DockScreen
	var _tip_body: String

	func _init(p_comp: ComponentDef, p_source: String, p_screen: DockScreen) -> void:
		comp = p_comp
		source = p_source
		screen = p_screen
		toggle_mode = true
		custom_minimum_size = Vector2(52, 52)
		var tex := screen._component_icon(comp)
		if tex != null:
			icon = tex
			expand_icon = true
			icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			text = "%s%s%d" % ["◆" if not comp.affix_ids.is_empty() else "",
				HardpointDef.SlotType.keys()[comp.slot_type()][0], comp.mark]
			add_theme_font_size_override("font_size", 15)
		add_theme_color_override("font_color", Grades.color(comp.grade))
		# Quality at a glance: a grade-colored border + pips (colour ALWAYS pairs
		# with pips for colourblind safety, per the grades convention).
		var gc := Grades.color(comp.grade)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(gc.r, gc.g, gc.b, 0.14)
		sb.border_color = gc
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		add_theme_stylebox_override("normal", sb)
		var sb_hi: StyleBoxFlat = sb.duplicate()
		sb_hi.bg_color = Color(gc.r, gc.g, gc.b, 0.30)
		add_theme_stylebox_override("hover", sb_hi)
		add_theme_stylebox_override("pressed", sb_hi)
		var pips: int = Grades.INFO[comp.grade]["pips"]
		if pips > 0:
			var pl := Label.new()
			pl.text = "•".repeat(pips)
			pl.add_theme_font_size_override("font_size", 9)
			pl.add_theme_color_override("font_color", gc)
			pl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			pl.add_theme_constant_override("outline_size", 3)
			pl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pl.grow_vertical = Control.GROW_DIRECTION_BEGIN
			pl.offset_bottom = -1
			pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(pl)
		# Stash gear rides dimmer than hold gear — location at a glance.
		if source == "stash":
			modulate = Color(1, 1, 1, 0.68)
		_tip_body = DockScreen.effect_lines(comp) \
			+ "[color=#8890a0]mass %.0f   [%s][/color]\n[color=#8890a0]drag to a slot · right-click auto-fit · shift+right-click %s[/color]" % [
			comp.mass, source, "→ stash" if source == "hold" else "→ hold"]
		tooltip_text = comp.display_name
		pressed.connect(func() -> void: screen._on_tile_selected(comp, source))

	func _make_custom_tooltip(_for_text: String) -> Object:
		return DockScreen.grade_tooltip(comp, _tip_body)

	func _get_drag_data(_at: Vector2) -> Variant:
		var preview := Label.new()
		preview.text = comp.display_name
		preview.add_theme_color_override("font_color", Grades.color(comp.grade))
		set_drag_preview(preview)
		return {"comp": comp, "source": source}

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			if event.shift_pressed:
				screen._toggle_location(comp, source)   # cargo <-> stash
			else:
				screen._auto_fit(comp, source)           # -> a ship slot


## An Armory grid tile: the component's icon with its grade border + pips and a
## price badge. Left-click inspects it (details panel); RIGHT-CLICK buys (shop)
## or sells (your goods) — no faraway button, matching the right-click idiom.
class ArmoryTile extends Button:
	## Emitted after a buy/sell so a borrowing screen can refresh. The dock screen
	## refreshes itself inside _buy_component; this is for everyone else.
	signal traded

	var comp: ComponentDef
	var source: String        # "shop" | "hold" | "stash"
	var path: String          # shop only — the .tres to (re)load on buy
	var screen: DockScreen
	var _tip_body: String

	func _init(p_comp: ComponentDef, p_source: String, p_screen: DockScreen, p_path := "") -> void:
		comp = p_comp
		source = p_source
		path = p_path
		screen = p_screen
		custom_minimum_size = Vector2(66, 66)
		var tex := screen._component_icon(comp)
		if tex != null:
			icon = tex
			expand_icon = true
			icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			text = "%s%d" % [HardpointDef.SlotType.keys()[comp.slot_type()][0], comp.mark]
			add_theme_font_size_override("font_size", 16)
			add_theme_color_override("font_color", Grades.color(comp.grade))
		var gc := Grades.color(comp.grade)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(gc.r, gc.g, gc.b, 0.14)
		sb.border_color = gc
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		add_theme_stylebox_override("normal", sb)
		var sb_hi: StyleBoxFlat = sb.duplicate()
		sb_hi.bg_color = Color(gc.r, gc.g, gc.b, 0.30)
		add_theme_stylebox_override("hover", sb_hi)
		add_theme_stylebox_override("pressed", sb_hi)
		# MARK / SIZE badge (top-left): a boxed roman numeral so it's obvious every
		# part — and every slot it fits — has a SIZE. Mk I–V.
		var roman: String = ["", "I", "II", "III", "IV", "V"][clampi(comp.mark, 1, 5)]
		var mb := Label.new()
		mb.text = roman
		mb.add_theme_font_size_override("font_size", 12)
		mb.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))
		var mbox := StyleBoxFlat.new()
		mbox.bg_color = Color(0.07, 0.09, 0.13, 0.9)
		mbox.set_corner_radius_all(3)
		mbox.content_margin_left = 4
		mbox.content_margin_right = 4
		mbox.content_margin_top = 0
		mbox.content_margin_bottom = 0
		mb.add_theme_stylebox_override("normal", mbox)
		mb.set_anchors_preset(Control.PRESET_TOP_LEFT)
		mb.offset_left = 2
		mb.offset_top = 2
		mb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mb)
		# GRADE pips (top-right): the colour-blind-safe rarity read. Was font 8 —
		# far too small; bumped so it's legible at a glance.
		var pips: int = Grades.INFO[comp.grade]["pips"]
		if pips > 0:
			var pl := Label.new()
			pl.text = "•".repeat(pips)
			pl.add_theme_font_size_override("font_size", 15)
			pl.add_theme_color_override("font_color", gc)
			pl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			pl.add_theme_constant_override("outline_size", 3)
			pl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			pl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			pl.offset_right = -3
			pl.offset_top = 0
			pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(pl)
		var price := screen._comp_buy_price(comp) if source == "shop" else screen._comp_sell_price(comp)
		var pb := Label.new()
		pb.text = "%dc" % price
		pb.add_theme_font_size_override("font_size", 10)
		pb.add_theme_color_override("font_color",
			UiTheme.AMBER if source == "shop" else Color(0.42, 0.86, 0.46))
		pb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		pb.add_theme_constant_override("outline_size", 3)
		pb.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		pb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pb.grow_vertical = Control.GROW_DIRECTION_BEGIN
		pb.offset_bottom = -1
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pb)
		if source == "stash":
			modulate = Color(1, 1, 1, 0.7)   # your stashed gear rides dimmer
		var verb := "buy" if source == "shop" else "sell"
		# Lead with any special ability the part grants, so it's the first thing
		# a hover reveals (mining laser / scan / cloak / bulwark).
		var ability := screen._ability_line(comp)
		var head := (ability + "\n") if ability != "" else ""
		_tip_body = head + DockScreen.effect_lines(comp) \
			+ "[color=#8890a0]value %dc   mass %.0f%s[/color]\n[color=#8890a0]left-click inspect · RIGHT-CLICK to %s (%dc)[/color]" % [
			comp.value(), comp.mass, "" if source == "shop" else "   [%s]" % source, verb, price]
		tooltip_text = comp.display_name
		pressed.connect(func() -> void: screen._on_armory_tile_selected(comp))

	func _make_custom_tooltip(_for_text: String) -> Object:
		return DockScreen.grade_tooltip(comp, _tip_body)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			if source == "shop":
				screen._buy_component(path)
			else:
				screen._sell_component(comp, source)
			traded.emit()


## A stack of a mined commodity, shown as a cargo tile with a ×N badge. Drag it
## onto the cargo/stash panel, or shift+right-click, to move the whole stack.
class MaterialTile extends Button:
	var key: String
	var qty: int
	var source: String
	var screen: DockScreen

	func _init(p_key: String, p_qty: int, p_source: String, p_screen: DockScreen) -> void:
		key = p_key
		qty = p_qty
		source = p_source
		screen = p_screen
		custom_minimum_size = Vector2(52, 52)
		var tex := screen._material_icon(key)
		if tex != null:
			icon = tex
			expand_icon = true
			icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			text = screen._material_glyph(key)
			add_theme_font_size_override("font_size", 15)
			add_theme_color_override("font_color", screen._material_color(key))
		if source == "stash":
			modulate = Color(1, 1, 1, 0.68)   # stash rides dimmer than the hold
		tooltip_text = "%s ×%d\nmaterial   mass %.0f ea   [%s]\ndrag to the other panel · shift+right-click %s" % [
			TradeGoods.display_name(key), qty, TradeGoods.unit_mass(key), source,
			"→ stash" if source == "hold" else "→ hold"]
		var badge := Label.new()
		badge.text = "×%d" % qty
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_color", Color(0.96, 0.96, 0.99))
		badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		badge.add_theme_constant_override("outline_size", 4)
		badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
		badge.offset_right = -3
		badge.offset_bottom = -1
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(badge)

	func _get_drag_data(_at: Vector2) -> Variant:
		var preview := Label.new()
		preview.text = "%s ×%d" % [TradeGoods.display_name(key), qty]
		preview.add_theme_color_override("font_color", screen._material_color(key))
		set_drag_preview(preview)
		return {"material": key, "source": source}

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			if event.shift_pressed:
				screen._toggle_material_location(key, source)   # hold <-> stash


## One hardpoint on the paperdoll. Click selects; accepts EquipTile drops
## when the component legally fits (the cursor shows validity while hovering).
class SlotSquare extends Button:
	var slot_index: int
	var screen: DockScreen
	## The FITTED part, so the hover can say what it actually does. A slot used to
	## show a bare two-line string — the one place equipment was described
	## differently from every other surface in the game.
	var comp: ComponentDef
	var _tip_body := ""

	func _init(p_index: int, p_screen: DockScreen) -> void:
		slot_index = p_index
		screen = p_screen
		toggle_mode = true
		custom_minimum_size = Vector2(48, 48)
		add_theme_font_size_override("font_size", 13)
		pressed.connect(func() -> void: screen._on_slot_square(slot_index))

	func set_tip(body: String) -> void:
		_tip_body = body

	## Same rich hover as the Armory, the hold and the Coupling: grade + mark
	## header, what it GRANTS, its effect lines, value and mass. An empty slot
	## keeps a plain tooltip — there is no part to describe.
	func _make_custom_tooltip(_for_text: String) -> Object:
		if comp == null:
			return null
		return DockScreen.grade_tooltip(comp, _tip_body)

	func _gui_input(event: InputEvent) -> void:
		# Right-click a filled slot to unfit it — the "equipped -> cargo" move.
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			screen._unfit_slot(slot_index)

	## Drag a fitted component OUT of its slot (drop it on cargo/stash).
	func _get_drag_data(_at: Vector2) -> Variant:
		var comp := screen.ship.build.component_at(slot_index)
		if comp == null:
			return null
		var preview := Label.new()
		preview.text = comp.display_name
		preview.add_theme_color_override("font_color", Grades.color(comp.grade))
		set_drag_preview(preview)
		return {"comp": comp, "source": "slot", "slot": slot_index}

	## Only accept inventory tiles (fitting), not other slots — a slot->slot
	## drag would need a swap the source-removal path doesn't do.
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("comp") \
			and str(data.get("source", "")) in ["hold", "stash"] \
			and screen._fit_error(data.comp, slot_index) == ""

	func _drop_data(_at: Vector2, data: Variant) -> void:
		screen._fit_from(data.comp, data.source, slot_index)


## The cargo / stash areas as drop targets: drag a tile or a fitted component
## onto one to move it there. Buttons/scroll/grid in between don't accept
## drops, so the drop bubbles up to this panel.
class InvDropZone extends PanelContainer:
	var target := ""
	var screen: DockScreen

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		if data is not Dictionary or str(data.get("source", "")) == target:
			return false
		return data.has("comp") or data.has("material")

	func _drop_data(_at: Vector2, data: Variant) -> void:
		if data.has("material"):
			screen._drop_material_to_location(str(data.material), str(data.source), target)
		else:
			screen._drop_to_location(data.comp, str(data.source), target)


## A little schematic of an owned ship on the board strip. Click to board it;
## the one you're aboard is amber-ringed.
class ShipIcon extends Button:
	var index: int
	var screen: DockScreen
	var _build: ShipBuild

	func _init(p_index: int, build: ShipBuild, aboard: bool, p_screen: DockScreen) -> void:
		index = p_index
		screen = p_screen
		custom_minimum_size = Vector2(52, 52)
		var hull_name := build.hull.display_name.to_snake_case()
		var path := "res://assets/ships/%s.png" % hull_name
		if ResourceLoader.exists(path):
			icon = load(path)
			expand_icon = true
			icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			text = build.hull.display_name.left(3)
			add_theme_font_size_override("font_size", 12)
		var s := ShipStats.aggregate(build)
		tooltip_text = "%s — %s%s\naccel %.1f  dps %.1f  hold %.0f" % [
			build.hull.display_name, build.hull.category,
			"   (ABOARD)" if aboard else "", s.accel, s.dps, s.cargo]
		if aboard:
			UiTheme.button_flavor(self, "primary", 52.0)
		pressed.connect(func() -> void: screen._board_ship(index))

	func _make_custom_tooltip(_for_text: String) -> Object:
		return DockScreen.hull_tooltip(_build) if _build != null else null
