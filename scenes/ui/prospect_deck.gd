class_name ProspectDeck
extends CanvasLayer
## THE DIG — Doug Diggs' deck aboard his freighter in the Verge.
##
## Bespoke + minimal, same reasoning as the Speak's Easy: DockScreen's
## is_station flag runs through its whole construction, so a third venue isn't
## worth shoehorning into it. Repairs and the save still ride ship.dock() like
## any berth; this shows the receipt and what Doug is actually for.
##
## WHAT MAKES THE TRIP WORTH IT — he pays a PREMIUM on ore, because you hauled
## it to him instead of making him fetch it. That is the whole economic argument
## for the Verge existing: the rocks are the same everywhere, the buyer isn't.
##
## He is also the Miner commission's front door and the game's mining teacher —
## the first person who explains that a gun chips a rock but a cutter opens it.

## What Doug pays over the station's price. He is closer to the rock and further
## from everything else; the premium is the trip.
const ORE_PREMIUM := 1.35

var ship: TestShip
var _body: RichTextLabel
var _ore_box: VBoxContainer
var _talk_box: VBoxContainer
var _offers: ItemList
var _active_box: VBoxContainer
var _active_talk: DialoguePanel


func _init(p_ship: TestShip) -> void:
	ship = p_ship
	layer = 5
	visible = false


func _ready() -> void:
	add_to_group("dock_screens")
	var ping := TutorPing.new()
	ping.anchor = "office_door"
	add_child(ping)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.04, 0.03, 1.0)   # dust and worklight
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

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	var head := Label.new()
	head.text = "THE DIG — Doug Diggs, Prospector Guild        [E] launch"
	head.add_theme_font_size_override("font_size", 17)
	head.add_theme_color_override("font_color", UiTheme.AMBER)
	root.add_child(head)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(128, 128)
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture = Npcs.portrait("doug")
	left.add_child(face)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_body)
	_talk_box = VBoxContainer.new()
	left.add_child(_talk_box)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var ore_head := Label.new()
	ore_head.text = "ORE BUYER — pays over station rate"
	ore_head.add_theme_color_override("font_color", UiTheme.ACCENT)
	right.add_child(ore_head)
	_ore_box = VBoxContainer.new()
	right.add_child(_ore_box)

	# HIS BOARD. Every job Doug posts is mining: rock he wants cut and hauled,
	# or guns cleared off the field so his customers can work it.
	var work_head := Label.new()
	work_head.text = "DIG WORK — all of it involves rock"
	work_head.add_theme_color_override("font_color", UiTheme.ACCENT)
	right.add_child(work_head)
	_offers = ItemList.new()
	_offers.custom_minimum_size = Vector2(0, 130)
	_offers.fixed_icon_size = Vector2i(32, 32)
	_offers.icon_mode = ItemList.ICON_MODE_LEFT
	right.add_child(_offers)
	var accept := Button.new()
	accept.text = "Accept selected"
	accept.pressed.connect(_accept_selected)
	right.add_child(accept)
	_active_box = VBoxContainer.new()
	right.add_child(_active_box)


func show_deck() -> void:
	visible = true
	refresh()


func refresh() -> void:
	if not visible:
		return
	Tutor.safe = true
	Tutor.context = "dock"
	Tutor.venue = "verge"
	var bill := int(ship.dock_bill.get("repairs", 0))
	var txt := "[i][color=#a8b0c2]%s[/color][/i]\n\n" % Npcs.flavor("doug")
	txt += "Her engines have been cold for a decade. Doug cut the holds open into "
	txt += "hoppers and welded a berth on the flank, and now the Verge has a door.\n\n"
	if bill > 0:
		txt += "[color=#8890a0]He patched you up on the way in — %dc.[/color]\n\n" % bill
	txt += "[color=#8fe08f]He pays %d%% over station rate for ore.[/color] "
	txt += "\"You hauled it out here. That's worth something, and I'd rather pay it than fetch it.\""
	_body.text = txt % int(round((ORE_PREMIUM - 1.0) * 100.0))

	for c in _ore_box.get_children():
		c.queue_free()
	var any := false
	for key in ship.commodities:
		if not str(key).ends_with("_ore") or int(ship.commodities[key]) <= 0:
			continue
		any = true
		var n: int = ship.commodities[key]
		var price := _ore_price(str(key))
		var b := Button.new()
		b.text = "Sell %s ×%d   %dc each" % [TradeGoods.display_name(str(key)), n, price]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", Color(0.42, 0.86, 0.46))
		b.pressed.connect(_sell_ore.bind(str(key)))
		_ore_box.add_child(b)
	if not any:
		var none := Label.new()
		none.text = "— no ore aboard. The Verge is right outside. —"
		none.add_theme_font_size_override("font_size", 11)
		none.add_theme_color_override("font_color", UiTheme.DIM)
		_ore_box.add_child(none)

	_refresh_work()
	_refresh_talk()


## Doug's postings, and anything of his you can hand in right now.
func _refresh_work() -> void:
	_offers.clear()
	for entry in MissionLog.offers_at("verge", "The Dig"):
		var m: Dictionary = entry.m
		var idx := _offers.add_item("%s  —  %dc" % [MissionLog.label(m), m.reward])
		_offers.set_item_metadata(idx, int(entry.index))
		var face := Npcs.portrait("doug")
		if face != null:
			_offers.set_item_icon(idx, face)
	if _offers.item_count == 0:
		_offers.add_item("— nothing posted; he's between buyers —")
		_offers.set_item_disabled(0, true)

	for c in _active_box.get_children():
		c.queue_free()
	for i in MissionLog.active.size():
		var m: Dictionary = MissionLog.active[i]
		if not MissionLog.venue_ok_at(m, "verge"):
			continue
		var done: bool = MissionLog.is_complete(m, ship)
		var b := Button.new()
		b.text = "%s  —  %s" % [MissionLog.label(m),
			"HAND IN (%dc)" % m.reward if done else "in progress"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not done
		if done:
			UiTheme.button_flavor(b, "primary")
		b.pressed.connect(_turn_in.bind(i))
		_active_box.add_child(b)


func _accept_selected() -> void:
	var sel := _offers.get_selected_items()
	if sel.is_empty() or _offers.is_item_disabled(sel[0]):
		return
	if not MissionLog.accept(int(_offers.get_item_metadata(sel[0]))):
		Sfx.play("click", -16.0, 0.6)
	MissionLog.ensure_offers()
	refresh()


func _turn_in(index: int) -> void:
	var m: Dictionary = MissionLog.active[index] if index < MissionLog.active.size() else {}
	if MissionLog.turn_in(index, ship):
		var fac := MissionLog.faction_for(m)   # Doug's board is mining, but credit the giver
		if fac != "":
			Standing.add(fac, 2)
		Sfx.play("jingle", -8.0)
	refresh()


## Derived from the STATION's standing price, so Doug's premium is always
## visibly "more than they'd give you back home" even if that table moves.
func _ore_price(key: String) -> int:
	var base: int = int(TradeGoods.STATION_MARKET["buys"].get(key, 0))
	return int(round(base * ORE_PREMIUM * Pilot.trade_sell_mult()))


## One unit per press, same as the market — deliberate, so a big haul is a
## visible stack of payments rather than one anonymous number.
func _sell_ore(key: String) -> void:
	if int(ship.commodities.get(key, 0)) <= 0:
		return
	ship.remove_commodity(key, 1)
	Wallet.credits += _ore_price(key)
	Standing.add("miner", 1)   # ore off your hold is Doug's kind of work
	Sfx.play("click", -14.0)
	refresh()


## Doug uses the same home/pip rule as everyone else: he speaks when you choose.
## Doug is ALWAYS talkable, like Odessa — he is the game's mining teacher, and a
## player who wants to ask how any of this works should never find a person with
## nothing to say. Quest business, when he has some, comes first.
func _refresh_talk() -> void:
	for c in _talk_box.get_children():
		c.queue_free()
	var b := Button.new()
	var waiting := Quests.talks_for("doug")
	b.text = "Talk to Doug Diggs" + ("  ●" if not waiting.is_empty() else "")
	UiTheme.button_flavor(b, "primary" if not waiting.is_empty() else "secondary")
	b.pressed.connect(_talk)
	_talk_box.add_child(b)

	# The Assay Office is a door off this deck — the same GuildOffice the station
	# leaders use. A Miner's commission is administered at the Verge, which is
	# exactly the point: your commission decides where home is.
	var prof := Professions.led_by("doug")
	if prof != "" and Professions.office_open(prof):
		var door := Button.new()
		door.text = "%s  →  %s" % [
			"Enter" if Pilot.profession == prof else "Visit",
			Professions.office_name(prof)]
		UiTheme.button_flavor(door, "secondary")
		door.pressed.connect(_open_office.bind(prof))
		_talk_box.add_child(door)
		Tutor.register("office_door", door)
	# The "office" lesson arms itself off `office_open` in the deck context below.
	Tutor.observe({
		"flying": false,
		"venue": "verge",
		"office_open": prof != "" and Professions.office_open(prof),
	})


func _open_office(prof: String) -> void:
	Tutor.retire("office")   # they walked in themselves — lesson unnecessary
	var office := GuildOffice.new("doug", prof, ship,
		func(path: String) -> void: _buy_ware(path),
		func(id: String) -> void:
			Pilot.join_profession(id)
			Sfx.play("jingle", -8.0)
			Research.journal.append({"day": Research.day,
				"text": "Accepted the %s commission." % Professions.display_name(id)}))
	office.closed.connect(refresh)
	add_child(office)


## Quartermaster purchase, Doug's counter. Lands in the hold like any buy.
func _buy_ware(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var comp: ComponentDef = load(path)
	var price := int(comp.value() * DockScreen.BUY_MULT)
	if Wallet.credits < price:
		Sfx.play("click", -16.0, 0.6)
		return
	Wallet.credits -= price
	Stash.items.append(comp)
	Sfx.play("jingle", -10.0)


func _talk() -> void:
	Pilot.meet("doug")
	var waiting := Quests.talks_for("doug")
	if waiting.is_empty():
		# No business — just Doug, and the mining lesson nothing else teaches.
		var chat := DialoguePanel.new("doug", Dialogues.DOUG_DECK,
			func(_a: String) -> String: return "")
		chat.vo_prefix = "doug_deck"
		chat.closed.connect(refresh)
		_active_talk = chat
		add_child(chat)
		return
	var talk: Dictionary = waiting[0]
	Quests.take_talk("doug")
	var panel := DialoguePanel.new("doug", talk.get("nodes", {}),
		func(_a: String) -> String: return "")
	if talk.has("text"):
		panel = DialoguePanel.new("doug",
			{"start": {"text": str(talk.text),
				"choices": [{"text": "Understood.", "next": "end", "style": "primary"}]}},
			func(_a: String) -> String: return "")
	panel.vo_prefix = str(talk.get("vo", ""))
	panel.closed.connect(func() -> void:
		if talk.has("advance"):
			Quests.advance_talk(str(talk.advance))
		refresh())
	_active_talk = panel
	add_child(panel)
