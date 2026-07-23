class_name SpeakEasy
extends CanvasLayer
## The Rust Shoal's dock deck — a speakeasy (illicit bar) AND "speak easy" (no
## Board listening). Bespoke + minimal on purpose: the station DockScreen's
## is_station flag is woven through construction and every refresh, so a lawless
## den isn't worth shoehorning into it. Repairs + save still happen on dock via
## ship.dock() like any berth; this just shows the receipt and the FENCE.
## The fence (stolen goods → credits + Privateer standing) only opens once you're
## TRUSTED (Standing.shoal_trusted) — a merely-invited pilot can put down and
## warm a stool, but the real business waits on your rep. [E] launches (the
## shared LaunchWindow via flight_test), same as anywhere.

const FENCE_CREDITS := 90
const FENCE_PRIVATEER := 2

## Grey-market markup on Vyper's gear — the Shoal doesn't run a charity.
const QUART_MARKUP := 1.2

var ship: TestShip
var _body: RichTextLabel
var _fence_box: VBoxContainer
var _quart_box: VBoxContainer
var _active_talk: DialoguePanel


func _init(p_ship: TestShip) -> void:
	ship = p_ship
	layer = 5
	visible = false


func _ready() -> void:
	add_to_group("dock_screens")
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.02, 1.0)   # smoky, rust-dark
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 26
	panel.offset_top = 26
	panel.offset_right = -26
	panel.offset_bottom = -26
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var head := Label.new()
	head.text = "THE SPEAK'S EASY — Rust Shoal        [E] launch"
	head.add_theme_color_override("font_color", UiTheme.AMBER)
	head.add_theme_font_size_override("font_size", 22)
	col.add_child(head)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_body)

	var fence_head := Label.new()
	fence_head.text = "THE FENCE"
	fence_head.add_theme_color_override("font_color", UiTheme.ACCENT)
	col.add_child(fence_head)
	_fence_box = VBoxContainer.new()
	_fence_box.add_theme_constant_override("separation", 4)
	col.add_child(_fence_box)

	# Vyper's QUARTERMASTER: the ONE place a KoS pilot (locked out of the station's
	# Engineering bay) can get Privateer gear AND have it installed. Buying here
	# bolts the module straight into a free System slot — no station refit needed;
	# Going Dark handles the gem memorize in flight. The Shoal is your home now.
	var quart_head := Label.new()
	quart_head.text = "VYPER'S QUARTERMASTER"
	quart_head.add_theme_color_override("font_color", UiTheme.ACCENT)
	col.add_child(quart_head)
	_quart_box = VBoxContainer.new()
	_quart_box.add_theme_constant_override("separation", 4)
	col.add_child(_quart_box)


func refresh() -> void:
	if not visible:
		return
	_present_krayt_if_due()
	var repairs := int(ship.dock_bill.get("repairs", 0))
	var ammo := int(ship.dock_bill.get("ammo", 0))
	var txt := "[i][color=#a8b0c2]Low light, lower talk. Nobody here asks where your hold came from — only what you're selling.[/color][/i]\n\n"
	if repairs > 0 or ammo > 0:
		txt += "Patched up on the quiet — repairs [color=#f2b859]-%dc[/color], munitions [color=#f2b859]-%dc[/color].\n" % [repairs, ammo]
	txt += "[color=#8890a0]credits %dc    Privateer standing %d[/color]" % [
		Wallet.credits, Standing.get_points("privateer")]
	_body.text = txt
	_refresh_quartermaster()

	for c in _fence_box.get_children():
		c.queue_free()
	if not Standing.shoal_trusted():
		var locked := Label.new()
		locked.text = "\"You're good for a drink, stranger. The rest you earn.\"   (the fence opens at Privateer — Friendly)"
		locked.add_theme_font_size_override("font_size", 12)
		locked.add_theme_color_override("font_color", UiTheme.DIM)
		locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_fence_box.add_child(locked)
		return
	var n := int(ship.commodities.get("stolen_goods", 0))
	if n <= 0:
		var none := Label.new()
		none.text = "\"Come back when your hold's heavier.\""
		none.add_theme_font_size_override("font_size", 12)
		none.add_theme_color_override("font_color", UiTheme.DIM)
		_fence_box.add_child(none)
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_fence_box.add_child(row)
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text = "[b]Stolen Goods x%d[/b]  [color=#8890a0]→ %dc   +%d Privateer standing[/color]" % [
		n, n * FENCE_CREDITS, n * FENCE_PRIVATEER]
	row.add_child(lbl)
	var btn := Button.new()
	btn.text = "Fence it all"
	UiTheme.button_flavor(btn, "secondary")
	btn.pressed.connect(_on_fence)
	row.add_child(btn)


func _on_fence() -> void:
	var n := int(ship.commodities.get("stolen_goods", 0))
	if n <= 0:
		return
	ship.remove_commodity("stolen_goods", n)
	Wallet.credits += n * FENCE_CREDITS
	Standing.add("privateer", n * FENCE_PRIVATEER)
	Sfx.play("jingle", -8.0)
	refresh()


## Vyper's stock, buy-and-install. Only a commissioned Privateer can fit her
## gear (the profession lock), so the shop shows only to them; anyone else gets
## pointed at the commission.
func _refresh_quartermaster() -> void:
	for c in _quart_box.get_children():
		c.queue_free()
	if Pilot.profession != "privateer":
		var note := Label.new()
		note.text = "\"Shoal gear's for Shoal crew. Take the colors first.\"   (commission with Vyper to requisition)"
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", UiTheme.DIM)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_quart_box.add_child(note)
		return
	var stock: Array = Professions.wares("privateer")
	if stock.is_empty():
		return
	for path in stock:
		var sp := str(path)
		if not ResourceLoader.exists(sp):
			continue
		var comp: ComponentDef = load(sp)
		var price := int(comp.value() * QUART_MARKUP)
		var owned: bool = _already_fitted(sp)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_quart_box.add_child(row)
		var lbl := RichTextLabel.new()
		lbl.bbcode_enabled = true
		lbl.fit_content = true
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.text = "[b]%s[/b]\n[color=#8890a0]%s[/color]" % [comp.display_name, comp.description]
		row.add_child(lbl)
		var btn := Button.new()
		btn.text = "FITTED" if owned else "Buy & install — %dc" % price
		btn.disabled = owned
		UiTheme.button_flavor(btn, "primary")
		if not owned:
			btn.pressed.connect(_on_buy_install.bind(sp))
		row.add_child(btn)


func _already_fitted(path: String) -> bool:
	for comp in ship.build.slots.values():
		if comp != null and comp.resource_path == path:
			return true
	return false


## A free hardpoint this module can legally take: right slot type, empty, mark
## fits, and the commission lock clears. -1 if none.
func _install_slot(comp: ComponentDef) -> int:
	var hull := ship.build.hull
	for i in hull.hardpoints.size():
		var hp: HardpointDef = hull.hardpoints[i]
		if hp.slot_type != comp.slot_type() or ship.build.slots.has(i):
			continue
		if comp.mark > hp.mark:
			continue
		if comp is SystemDef and not (comp as SystemDef).fittable_by(Pilot.profession):
			continue
		return i
	return -1


func _on_buy_install(path: String) -> void:
	var comp: ComponentDef = load(path)
	var price := int(comp.value() * QUART_MARKUP)
	if Wallet.credits < price:
		ship._flash_note("Not enough credits (%dc needed)." % price)
		Sfx.play("click", -16.0, 0.6)
		return
	var slot := _install_slot(comp)
	if slot < 0:
		ship._flash_note("No free System berth — unfit something first, then come back.")
		Sfx.play("click", -16.0, 0.6)
		return
	Wallet.credits -= price
	ship.build.slots[slot] = comp
	ship.apply_build(ship.build)
	Sfx.play("jingle", -6.0)
	ship._flash_note("The Shoal's crew bolts it on — %s installed. Going Dark wires it to a bus slot." % comp.display_name)
	refresh()


## An IN-PERSON campaign beat (Krayt at the Shoal) presents HERE, on dock, at his
## own table — not a fly-by comm. Finishing it advances the quest exactly like the
## old proximity hail did; the next beat still opens on your next dock home.
func _present_krayt_if_due() -> void:
	if _active_talk != null and is_instance_valid(_active_talk):
		return
	var site := Quests.goto_dialogue_site()
	if site.is_empty() or not bool(site.get("in_person", false)):
		return
	var qid := str(site.quest)
	Comms.post(str(site.npc), Quests.quest_def(qid).get("title", "Transmission"),
		str(site.nodes.get("start", {}).get("text", "")))
	var panel := DialoguePanel.new(str(site.npc), site.nodes,
		func(_a: String) -> String: return "")
	panel.vo_prefix = qid
	_active_talk = panel
	panel.closed.connect(func() -> void:
		_active_talk = null
		Quests.advance_goto_dialogue(qid)
		for note in Quests.take_notes():
			ship._flash_note(note)
		refresh())
	add_child(panel)
