class_name SpeakEasy
extends CanvasLayer
## The Rust Shoal's dock deck — a speakeasy (illicit bar) AND "speak easy" (no
## Board listening). Repairs + save still happen on dock via ship.dock() like any
## berth; this shows the receipt, the FENCE, and Vyper's counter.
##
## ON THE STANDARD VENUE LAYOUT (2026-07-27, docs/venue_layout.md). Everything that
## was identical to Doug's deck — the desk, the board, the hand-ins, the standing
## meter, the trust-gated quartermaster, the office door — is VenueLayout's now, and
## was deleted from here rather than copied. What stays is what makes this place
## worth flying to: the fence, the smoke, and Krayt's table.
##
## The fence (stolen goods → credits + Privateer standing) only opens once you're
## TRUSTED (Standing.shoal_trusted) — a merely-invited pilot can put down and warm a
## stool, but the real business waits on your rep. [E] launches, same as anywhere.

const FENCE_CREDITS := 90
const FENCE_PRIVATEER := 2

## Grey-market markup on Vyper's gear — the Shoal doesn't run a charity. AGAINST THE
## GOING RATE (ItemVisuals.buy_price), which is what makes it a markup: it used to
## multiply the raw `value()`, so this counter quietly sold the same chip for 40% LESS
## than the back room three feet away charged for it.
const QUART_MARKUP := 1.2

## VYPER'S BANNER is what opens her work to you — the middle rung of the Shoal ladder.
## At -50 (Krayt's truce) their guns are off you and you may stand at the bar; you are
## Krayt's guest, not Shoal crew, and nobody hands a guest a job. Her banner sets 0, and
## from there her contracts are the ONLY road to Standing.INVITE_AT and the commission.
const WORK_AT := 0

## THE SHOAL LADDER, in Vyper's words — what the next scrap of standing actually buys.
## The meter sits directly under her board, so the work and its consequence are one
## glance apart. Authored here because these are THIS venue's doors, not generic bands.
const RUNGS := [
	{"at": WORK_AT, "label": "Vyper posts her work to you"},
	{"at": Standing.INVITE_AT, "label": "the back room opens — and her counter"},
	{"at": Standing.FRIENDLY_AT, "label": "the fence takes your stolen goods"},
	{"at": Standing.ALLIED_AT, "label": "the Shoal calls you one of theirs"},
]

var ship: TestShip
var _venue: VenueLayout
var _body: RichTextLabel
var _fence_box: VBoxContainer
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

	_venue = VenueLayout.new({
		"ship": ship, "venue": "shoal", "board": "The Speak's Easy",
		"npc": "vyper", "faction": "shoal", "rungs": RUNGS,
		"board_title": "VYPER'S WORK",
		"board_open": func() -> bool: return Standing.get_points("privateer") >= WORK_AT,
		"board_shut_text": "\"Krayt vouched for you, so drink. Working for us is a different word.\"   (Vyper's banner opens her work)",
		"board_ask": "Anything on the board?",
		"price_of": func(comp: ComponentDef) -> int:
			return int(ItemVisuals.buy_price(comp) * QUART_MARKUP),
	})
	panel.add_child(_venue)
	_venue.build("THE SPEAK'S EASY — Rust Shoal")
	_venue.mount_pings(self)
	_venue.changed.connect(refresh)
	_venue.office_opened.connect(_open_office)
	_venue.ware_bought.connect(_on_buy_install)
	# When the whole chain of talks has played out, redraw once against the final
	# quest/journal state — not after each panel, which would flicker mid-conversation.
	_venue.talks.chain_finished.connect(refresh)

	_body = _venue.body

	# THE FENCE — the Shoal's own business, and the reason a hold full of somebody
	# else's cargo is worth flying out here.
	var fence_head := Label.new()
	fence_head.text = "THE FENCE"
	fence_head.add_theme_color_override("font_color", UiTheme.ACCENT)
	_venue.venue_box.add_child(fence_head)
	_fence_box = VBoxContainer.new()
	_fence_box.add_theme_constant_override("separation", 4)
	_venue.venue_box.add_child(_fence_box)


func refresh() -> void:
	if not visible:
		return
	_present_krayt_if_due()
	var repairs := int(ship.dock_bill.get("repairs", 0))
	var ammo := int(ship.dock_bill.get("ammo", 0))
	var txt := "[i][color=#a8b0c2]Low light, lower talk. Nobody here asks where your hold came from — only what you're selling.[/color][/i]\n\n"
	if repairs > 0 or ammo > 0:
		txt += "Patched up on the quiet — repairs [color=#f2b859]-%dc[/color], munitions [color=#f2b859]-%dc[/color].\n" % [repairs, ammo]
	txt += "[color=#8890a0]credits %dc[/color]" % Wallet.credits
	_body.text = txt

	_venue.refresh()
	# Vyper speaks when she has something; otherwise the desk still opens on a word.
	_venue.desk.set_news(_venue.talks.has_news("vyper"),
		"She's watching the door, not you.")
	_refresh_fence()


## Locked BELOW the banner too, not merely below trust: a pilot Vyper won't post work
## to certainly isn't buying her silence about a hold full of stolen freight.
func _refresh_fence() -> void:
	for c in _fence_box.get_children():
		c.queue_free()
	if not Standing.shoal_trusted():
		var locked := Label.new()
		locked.text = "\"You're good for a drink, stranger. The rest you earn.\"   (the fence opens at Friendly)"
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
	office.closed.connect(refresh)
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


## A free hardpoint this module can legally take: right slot type, empty, mark
## fits, and the commission lock clears. -1 if none. MODULES ONLY — chips go in the
## Coupling and never touch a hardpoint (see _on_buy_install).
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
		if int(comp.level) > Pilot.level():
			continue
		return i
	return -1


## Vyper's counter INSTALLS IT: the one place a KoS pilot (locked out of the station's
## Engineering bay) can get Privateer gear AND have it fitted. No station refit needed.
##
## A CHIP GOES IN THE COUPLING (fixed 2026-07-27). Everything Vyper stocks is an
## AbilityChipDef, and a chip's slot_type() answers SYSTEM — so this used to hunt for a
## free System HARDPOINT and bolt the chip into it, eating a cargo pod or a sensor mount
## and putting the ability somewhere the Coupling does not read. It went unnoticed
## because `comp is SystemDef` is FALSE for a chip (AbilityChipDef extends ComponentDef
## directly), so the commission lock silently did not apply here either. Both are one
## fix: chips route through ShipBuild.chip_error, the same rule the Engineering bay uses.
func _on_buy_install(path: String) -> void:
	var comp: ComponentDef = load(path)
	var price := int(ItemVisuals.buy_price(comp) * QUART_MARKUP)
	if Wallet.credits < price:
		_venue.flash("Not enough credits (%dc needed)." % price)
		Sfx.play("click", -16.0, 0.6)
		return

	if comp is AbilityChipDef:
		var err := ship.build.chip_error(comp as AbilityChipDef, Pilot.profession, Pilot.level())
		if err != "":
			_venue.flash(err)
			Sfx.play("click", -16.0, 0.6)
			return
		Wallet.credits -= price
		ship.build.chips.append(comp)
		ship.apply_build(ship.build)
		Sfx.play("jingle", -6.0)
		_venue.flash("The Shoal's crew slots it into your Coupling — %s is in your library." \
			% comp.display_name)
		refresh()
		return

	var slot := _install_slot(comp)
	if slot < 0:
		_venue.flash("No free System berth — unfit something first, then come back.")
		Sfx.play("click", -16.0, 0.6)
		return
	Wallet.credits -= price
	ship.build.slots[slot] = comp
	ship.apply_build(ship.build)
	Sfx.play("jingle", -6.0)
	_venue.flash("The Shoal's crew bolts it on — %s installed." % comp.display_name)
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
			_venue.flash(note)
		refresh())
	add_child(panel)
