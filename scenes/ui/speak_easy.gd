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

## VYPER'S BANNER is what opens her work to you — the middle rung of the Shoal ladder.
## At -50 (Krayt's truce) their guns are off you and you may stand at the bar; you are
## Krayt's guest, not Shoal crew, and nobody hands a guest a job. Her banner sets 0, and
## from there her contracts are the ONLY road to Standing.INVITE_AT and the commission.
const WORK_AT := 0

var ship: TestShip
var _body: RichTextLabel
var _fence_box: VBoxContainer
var _quart_box: VBoxContainer
var _work_box: VBoxContainer
var _offers: ItemList
var _take_btn: Button
var _door_box: HBoxContainer
var _active_box: VBoxContainer
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

	# VYPER'S WORK — the rung between her banner and the commission. Posted here and
	# turned in here: Shoal work does not get filed with the Board.
	var work_head := Label.new()
	work_head.text = "VYPER'S WORK"
	work_head.add_theme_color_override("font_color", UiTheme.ACCENT)
	col.add_child(work_head)
	_work_box = VBoxContainer.new()
	_work_box.add_theme_constant_override("separation", 4)
	# THE BOARD TAKES THE SLACK. Everything else on this screen is a couple of lines, so
	# without this the whole bar crams into the top third and two thirds of the panel is
	# dead space with a 96px scroller in it — three contracts behind a scrollbar on a
	# 1080-tall screen. The board is the reason to stand here; it gets the room.
	_work_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_work_box)
	_offers = ItemList.new()
	# SIZED TO THE BOARD, not to the screen. Letting the list take all the slack fixed the
	# 96px scroller by overshooting into ~700px of empty list under three rows; a venue
	# posts three or four contracts, so this holds them all with a little room and the
	# SPACER below takes the leftover instead.
	_offers.custom_minimum_size = Vector2(0, 200)
	_offers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offers.item_activated.connect(func(_i: int) -> void: _on_accept())
	_work_box.add_child(_offers)
	# Buttons sit in a row so they keep their own width. A Button parented straight to a
	# VBoxContainer stretches to fill it, which made "Take the job" a 1900px bar.
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	_work_box.add_child(btn_row)
	_take_btn = Button.new()
	_take_btn.text = "Take the job"
	UiTheme.button_flavor(_take_btn, "secondary")
	_take_btn.pressed.connect(_on_accept)
	btn_row.add_child(_take_btn)
	_door_box = HBoxContainer.new()
	btn_row.add_child(_door_box)
	_active_box = VBoxContainer.new()
	_active_box.add_theme_constant_override("separation", 4)
	_work_box.add_child(_active_box)
	# The slack lands HERE, so the fence and the quartermaster sit at the foot of the
	# panel instead of being crowded into the top third with dead space beneath them.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_work_box.add_child(spacer)

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
	_refresh_work()
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


## Vyper's postings, anything of hers you can hand in right now, and the door to The Back
## Room. All three appear together the moment her banner does, and not one moment before.
func _refresh_work() -> void:
	# BOTH ledgers cleared up front, before the locked early-return below. The door lives
	# in the button row now, so clearing it only on the open path would leave a stale
	# Back Room door standing on a screen that has just re-locked.
	for c in _active_box.get_children():
		c.queue_free()
	for c in _door_box.get_children():
		c.queue_free()
	_offers.clear()
	var open := Standing.get_points("privateer") >= WORK_AT
	_offers.visible = open
	_take_btn.visible = open
	if not open:
		var locked := Label.new()
		locked.text = "\"Krayt vouched for you, so drink. Working for us is a different word.\"   (Vyper's banner opens her work)"
		locked.add_theme_font_size_override("font_size", 12)
		locked.add_theme_color_override("font_color", UiTheme.DIM)
		locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_active_box.add_child(locked)
		return

	for entry in MissionLog.offers_at("shoal", "The Speak's Easy"):
		var m: Dictionary = entry.m
		# `desc`, not MissionLog.label() — label appends the giver, which is right on a
		# board carrying several people's postings and pure noise on a single-giver one.
		# Every row read "... — Vyper" directly under a heading saying VYPER'S WORK.
		var idx := _offers.add_item("%s  —  %dc" % [str(m.desc), m.reward])
		_offers.set_item_metadata(idx, int(entry.index))
		var face := Npcs.portrait("vyper")
		if face != null:
			_offers.set_item_icon(idx, face)
	if _offers.item_count == 0:
		_offers.add_item("— the board's bare. Come back when the lane's been busy —")
		_offers.set_item_disabled(0, true)

	for i in MissionLog.active.size():
		var m: Dictionary = MissionLog.active[i]
		if not MissionLog.venue_ok_at(m, "shoal"):
			continue
		var done: bool = MissionLog.is_complete(m, ship)
		var b := Button.new()
		b.text = "%s  —  %s" % [str(m.desc),
			"HAND IN (%dc)" % m.reward if done else "in progress"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not done
		if done:
			UiTheme.button_flavor(b, "primary")
		b.pressed.connect(_turn_in.bind(i))
		_active_box.add_child(b)

	# THE BACK ROOM. The same GuildOffice every other leader uses — a commission is
	# administered where its leader stands, and Vyper's counter is a bar in a pirate den.
	var prof := Professions.led_by("vyper")
	if prof != "" and Professions.office_open(prof):
		var door := Button.new()
		door.text = "%s  →  %s" % [
			"Enter" if Pilot.profession == prof else "Visit",
			Professions.office_name(prof)]
		UiTheme.button_flavor(door, "primary")
		door.pressed.connect(_open_office.bind(prof))
		_door_box.add_child(door)


## THROUGH take(), never accept(): take() reports WHY a refusal happened (a full log
## answered a bare accept() with a click and nothing else) and calls ensure_offers itself.
func _on_accept() -> void:
	var sel := _offers.get_selected_items()
	if sel.is_empty() or _offers.is_item_disabled(sel[0]):
		return
	var r := MissionLog.take(int(_offers.get_item_metadata(sel[0])))
	if r.ok:
		Tutor.did("accepted_contract")
	else:
		Sfx.play("click", -16.0, 0.6)
	ship._flash_note(str(r.msg))
	refresh()


## THROUGH MissionLog.complete(), which carries the standing credit (faction_for ->
## privateer, the whole reason this board exists), Quests.check_new_work and the turn-in
## tutor signals. Re-implementing the tail here is how boards drift apart.
func _turn_in(index: int) -> void:
	var r := MissionLog.complete(index, ship, "shoal", SaveGame.tutorial_done)
	if r.ok:
		Tutor.did("turned_in")
		Tutor.retire("turn_in")
		Sfx.play("jingle", -8.0)
	ship._flash_note(str(r.msg))
	refresh()


func _open_office(prof: String) -> void:
	Tutor.retire("office")
	var office := GuildOffice.new("vyper", prof, ship,
		func(path: String) -> void: _on_buy_install(path),
		func(id: String) -> void:
			Pilot.join_profession(id)
			Sfx.play("jingle", -8.0)
			Research.journal.append({"day": GameClock.now(),
				"text": "Took the Shoal's colors — the %s commission." % Professions.display_name(id)})
			refresh())
	add_child(office)


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
		# LEVEL GATES VYPER'S COUNTER TOO (2026-07-27). This is a hand-rolled copy of
		# the Engineering bay's fit rules that checks slot type, occupancy, mark and
		# profession lock -- everything _fit_error checked BEFORE the level
		# requirement was added, and nothing since. So the Shoal would bolt a
		# level-gated module onto a level-2 hull that the dock would refuse.
		# THE THIRD COPY OF THIS RULE to need the same patch in two days (the
		# Coupling's _chip_error was the second). The real fix is one shared
		# ShipFitting.fit_error; until that lands, this keeps the counters honest.
		if int(comp.level) > Pilot.level():
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
