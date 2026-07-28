class_name GuildOffice
extends CanvasLayer
## A COMMISSION LEADER'S OFFICE — the room behind the counter.
##
## THEIR space, which you are visiting. Not a "profession lounge": the framing,
## the greeting and the terms all belong to the person whose door this is, and
## you are a guest in it whether or not you have taken their commission.
##
## WHY A MODAL AND NOT A TAB (2026-07-22, decided with user). An ability tree
## needs a page, and the three leaders who lack a room — Ruel behind the Landing
## Bay counter, Imari on the Landing Pad, Voss at the Mission Computer — could
## never host one in a column. Six new tabs would have taken the station from 9
## to 11, most of them empty for any given pilot. A full-screen view opened by a
## door costs no tab budget, makes visiting an ACT (the argument that earned the
## Counter his Cave), and — the deciding reason — WORKS ON EVERY SCREEN. Doug's
## office opens from the ProspectDeck at the Verge and Vyper's from the Speak's
## Easy at the Shoal; those are separate bespoke screens, and a tab-based design
## would have had to be built three times.
##
## TWO STATES, one room:
##   VISITING — you have earned an invitation but not accepted. The full tree is
##     shown but greyed: you can read exactly what the commission grants before
##     committing, which is the whole reason the prospectus exists.
##   MEMBER   — you hold this commission. The tree lights up and the
##     quartermaster's counter opens (VENDOR RULE: signature modules are sold
##     HERE by their leader, never in the open Armory).
## Before eligibility there is no door at all — they are just a person at their
## counter, and the commission is something you have not been offered.

signal closed

const NODE_W := 210.0
const NODE_H := 78.0

var npc: String
var prof: String
var ship: TestShip

var _on_buy: Callable          # host handles the purchase (prices/wallet/refresh)
var _on_join: Callable
var _body: VBoxContainer
var _scroll: ScrollContainer


func _init(p_npc: String, p_prof: String, p_ship: TestShip,
		p_on_buy: Callable, p_on_join: Callable) -> void:
	npc = p_npc
	prof = p_prof
	ship = p_ship
	_on_buy = p_on_buy
	_on_join = p_on_join
	layer = 12


func _ready() -> void:
	# Overlays that own Escape join this group so the pause menu defers to them.
	add_to_group("esc_capture")
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.04, 0.88)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 60
	panel.offset_top = 50
	panel.offset_right = -60
	panel.offset_bottom = -50
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	_scroll.add_child(_body)

	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(foot)
	var leave := Button.new()
	leave.text = "Leave"
	UiTheme.button_flavor(leave, "tertiary")
	leave.pressed.connect(close)
	foot.add_child(leave)

	refresh()


func is_member() -> bool:
	return Pilot.profession == prof


func refresh() -> void:
	for c in _body.get_children():
		c.queue_free()
	_build_header()
	_build_grants()
	_build_tree()
	if is_member():
		_build_quartermaster()
	else:
		_build_accept()


## Their name on the door, their portrait, their greeting. The room is described
## in their terms — a pilot should be able to tell whose office they are in with
## the labels covered up.
func _build_header() -> void:
	var head := Label.new()
	head.text = "%s        %s" % [Professions.office_name(prof).to_upper(),
		"MEMBER" if is_member() else "VISITING"]
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", UiTheme.AMBER)
	_body.add_child(head)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_body.add_child(row)
	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(128, 128)
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture = Npcs.portrait(npc)
	row.add_child(face)

	var txt := RichTextLabel.new()
	txt.bbcode_enabled = true
	txt.fit_content = true
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.text = "[i][color=#a8b0c2]%s[/color][/i]\n\n[b]%s[/b] — [color=#8890a0]%s[/color]\n\n\"%s\"" % [
		Professions.office_desc(prof), Npcs.display_name(npc), Npcs.role(npc),
		Professions.pitch(prof, is_member())]
	row.add_child(txt)


## What the commission actually GRANTS, in numbers. This is the page the player
## reads before spending a decision they cannot easily unspend.
func _build_grants() -> void:
	var pd := Professions.def(prof)
	var head := Label.new()
	head.text = "WHAT THE COMMISSION GRANTS"
	head.add_theme_color_override("font_color", UiTheme.ACCENT)
	_body.add_child(head)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	_body.add_child(cols)

	var growth := RichTextLabel.new()
	growth.bbcode_enabled = true
	growth.fit_content = true
	growth.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var perk := Professions.perk(prof)
	growth.text = "[b]Per level[/b]\n[color=#8fe08f]+%.1f%%[/color] hull, armor, shield & damage\n[color=#8890a0](no commission: +%.1f%%)[/color]\n\n[b]Energy[/b]\n[color=#8fe08f]×%.2f[/color] recharge rate%s" % [
		Professions.combat_tier(prof) * 100.0, Professions.BASE_COMBAT_TIER * 100.0,
		Professions.energy_regen(prof),
		"" if perk == "" else "\n\n[b]Exclusive perk[/b]\n[color=#8fe08f]%s[/color] +%.1f%%/level" % [
			perk.capitalize(), Professions.PERK_PER_LEVEL * 100.0]]
	cols.add_child(growth)

	var caps := RichTextLabel.new()
	caps.bbcode_enabled = true
	caps.fit_content = true
	caps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ct := "[b]Skill caps raised[/b]\n[color=#8890a0]Points come from your levels; the caps come from here.[/color]\n"
	for sid in Skills.ids():
		var cap := Professions.cap_for(prof, sid)
		if cap <= Skills.BASE_CAP:
			continue
		ct += "\n%s  [color=#f2b859]%s[/color][color=#333a4a]%s[/color]  [color=#8890a0](base %d)[/color]" % [
			Skills.def(sid).name, "●".repeat(cap), "○".repeat(0), Skills.BASE_CAP]
	ct += "\n\n[b]Earned by[/b]\n[color=#8890a0]%s[/color]" % str(pd.get("verb", ""))
	caps.text = ct
	cols.add_child(caps)


## THE ABILITY TREE. Branch columns, tier rows. Nodes the player can actually
## use today are lit; designed-but-unbuilt ones are dimmed and say so, because a
## tree that quietly lists vapour teaches the player to distrust the whole page.
func _build_tree() -> void:
	var head := Label.new()
	# CALL IT WHAT IT IS RIGHT NOW. With work-in-progress nodes withheld, four of
	# the five reachable commissions show ONE node per branch — labelling two
	# abilities an "ABILITY TREE" invites "so where's the tree?", which is the
	# same question withholding them was meant to avoid. The branch columns still
	# do their real job: they name the two ROLES the commission specialises into.
	head.text = "ABILITY TREE" if Professions.SHOW_UNBUILT else "COMMISSION ABILITIES"
	head.add_theme_color_override("font_color", UiTheme.ACCENT)
	_body.add_child(head)

	var branches: Array = Professions.branches(prof)
	if branches.is_empty():
		var none := Label.new()
		none.text = "— this commission's tree is still being drawn up —"
		none.add_theme_color_override("font_color", UiTheme.DIM)
		_body.add_child(none)
		return

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(cols)

	for b in branches:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(col)

		var bh := RichTextLabel.new()
		bh.bbcode_enabled = true
		bh.fit_content = true
		bh.text = "[b][color=#f2b859]%s[/color][/b]\n[color=#8890a0]%s[/color]" % [
			str(b.get("name", "")), str(b.get("role", ""))]
		col.add_child(bh)

		var nodes: Array = b.get("nodes", [])
		for i in nodes.size():
			var n: Dictionary = nodes[i]
			col.add_child(_tree_node(n))
			if i < nodes.size() - 1:
				var stem := Label.new()
				stem.text = "│"
				stem.add_theme_color_override("font_color", UiTheme.DIM)
				col.add_child(stem)


func _tree_node(n: Dictionary) -> Control:
	var built := bool(n.get("built", false))
	var lit := built and is_member()
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(NODE_W, NODE_H)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.13, 0.18) if lit else Color(0.07, 0.08, 0.10)
	style.border_color = UiTheme.AMBER if lit else Color(0.24, 0.27, 0.33)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(8)
	box.add_theme_stylebox_override("panel", style)

	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	var name_col := "#f2f2f2" if lit else "#6d7686"
	var tail := ""
	if not built:
		tail = "\n[color=#6d7686][i]not yet built[/i][/color]"
	elif not is_member():
		tail = "\n[color=#6d7686][i]requires the commission[/i][/color]"
	lbl.text = "[b][color=%s]T%d · %s[/color][/b]\n[color=#8890a0]%s[/color]%s" % [
		name_col, int(n.get("tier", 1)), str(n.get("name", "")),
		str(n.get("desc", "")), tail]
	box.add_child(lbl)
	return box


## THE QUARTERMASTER'S COUNTER — members only, and the only place these modules
## can be bought (VENDOR RULE). Same iconography as the Armory so equipment
## always reads the same way wherever it is shown.
func _build_quartermaster() -> void:
	var head := Label.new()
	head.text = "QUARTERMASTER — %s" % Npcs.display_name(npc)
	head.add_theme_color_override("font_color", UiTheme.AMBER)
	_body.add_child(head)

	var note := Label.new()
	note.text = "Right-click to buy — the same as the Armory."
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", UiTheme.DIM)
	_body.add_child(note)

	# SAME TILES AS THE ARMORY (user's rule): equipment is shown with its grade border,
	# mark badge, quality pips and price wherever it appears, so a part reads identically
	# on every screen. This used to need a `tiles_host` DockScreen to LEND us tiles, and
	# fell back to plain labelled buttons where there wasn't one (Doug's deck, the Speak's
	# Easy) — so the quartermaster's shelf looked different depending on who was standing
	# behind it. ItemTile is host-free now: every counter gets the real thing.
	var stock := Professions.wares(prof)
	var shown := 0
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_body.add_child(grid)
	for path in stock:
		var sp := str(path)
		if not ResourceLoader.exists(sp):
			continue
		shown += 1
		var comp: ComponentDef = load(sp)
		var tile := ItemTile.new(comp, "shop", ItemTile.Style.SHOP)
		tile.price = ItemVisuals.buy_price(comp)
		tile.hint = "RIGHT-CLICK to buy (%dc)" % tile.price
		tile.on_interact = func(_c: ComponentDef, _s: String) -> void:
			_on_buy.call(sp)
			refresh()
		grid.add_child(tile)
	if shown == 0:
		var soon := Label.new()
		soon.text = "Nothing on the shelf yet — modules land here as they are forged."
		soon.add_theme_color_override("font_color", UiTheme.DIM)
		_body.add_child(soon)


## The offer. Only reachable with an invitation in hand, so this is a decision
## point and gets the gold button.
##
## IT IS A COMMITMENT (2026-07-22, user). Taking a commission is meant to be a
## choice you live with, so it never happens on one click: the button swaps into
## an explicit warning and a confirm. The warning is shown in TESTING TOO, so the
## moment reads exactly as it will when shipped — only the LOCK changes with the
## build (Professions.commission_final), and in a debug build a dev line says the
## choice is still swappable rather than the warning quietly lying.
func _build_accept() -> void:
	var held := Pilot.profession != ""
	if held and not Professions.can_switch():
		var taken := RichTextLabel.new()
		taken.bbcode_enabled = true
		taken.fit_content = true
		taken.text = "[color=#c98b8b]You hold the %s commission.[/color] [color=#8890a0]%s knows it. These things are for life, and nobody here is in the business of poaching.[/color]" % [
			Professions.display_name(Pilot.profession), Npcs.display_name(npc)]
		_body.add_child(taken)
		return

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_body.add_child(row)
	var note := RichTextLabel.new()
	note.bbcode_enabled = true
	note.fit_content = true
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.text = "[color=#8fe08f]The offer is open.[/color] [color=#8890a0]It sets your per-level growth, raises these skill caps and opens this counter.[/color]"
	if held:
		note.text += "\n[color=#c98b8b]You would be leaving the %s commission behind.[/color]" % Professions.display_name(Pilot.profession)
	row.add_child(note)

	var acc := Button.new()
	acc.text = "Accept the commission"
	UiTheme.button_flavor(acc, "primary")
	acc.pressed.connect(func() -> void: _confirm_join(row))
	row.add_child(acc)


## Second beat: say plainly that it cannot be undone, then make them press again.
func _confirm_join(row: HBoxContainer) -> void:
	for c in row.get_children():
		c.queue_free()
	var warn := RichTextLabel.new()
	warn.bbcode_enabled = true
	warn.fit_content = true
	warn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	warn.text = "[b][color=#f2b859]This is permanent.[/color][/b] [color=#8890a0]A pilot takes one commission and keeps it. You will not be able to change it later.[/color]"
	if Professions.can_switch():
		warn.text += "\n[color=#6d7686][i](dev build: commissions can still be swapped while we test)[/i][/color]"
	row.add_child(warn)

	var yes := Button.new()
	yes.text = "Sign on — %s" % Professions.display_name(prof)
	UiTheme.button_flavor(yes, "primary")
	yes.pressed.connect(func() -> void:
		_on_join.call(prof)
		refresh())
	row.add_child(yes)

	var no := Button.new()
	no.text = "Not yet"
	UiTheme.button_flavor(no, "tertiary")
	no.pressed.connect(refresh)
	row.add_child(no)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()
