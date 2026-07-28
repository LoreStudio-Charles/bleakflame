class_name ProspectDeck
extends CanvasLayer
## THE DIG — Doug Diggs' deck aboard his freighter in the Verge.
##
## ON THE STANDARD VENUE LAYOUT (2026-07-27, docs/venue_layout.md). The desk, the
## board, the hand-ins, the standing meter, the trust-gated quartermaster and the
## office door are VenueLayout's; what stays here is what makes the trip worth it.
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

## THE MINERS' LADDER, in Doug's words. Ore sold across his scale is the verb that
## moves it, and the meter sits directly under the board that pays it.
const RUNGS := [
	{"at": Standing.INVITE_AT, "label": "the Assay Office opens — and his counter"},
	{"at": Standing.FRIENDLY_AT, "label": "he cuts you in on the good seams"},
	{"at": Standing.ALLIED_AT, "label": "the Guild calls the Verge your yard"},
]

var ship: TestShip
var _venue: VenueLayout
var _body: RichTextLabel
var _ore_box: VBoxContainer
var _active_talk: DialoguePanel


func _init(p_ship: TestShip) -> void:
	ship = p_ship
	layer = 5
	visible = false


func _ready() -> void:
	add_to_group("dock_screens")
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

	_venue = VenueLayout.new({
		"ship": ship, "venue": "verge", "board": "The Dig",
		"npc": "doug", "faction": "miner", "rungs": RUNGS,
		"board_title": "DIG WORK — all of it involves rock",
		"board_ask": "Anything that needs digging?",
		# HIS LESSON IS AN OFFER, NOT THE CONVERSATION. Doug is the game's mining
		# teacher and DOUG_DECK is a real authored TREE — folding it into a one-line
		# reply would delete it. It becomes one line in his list instead, ranked with
		# everything else, and still opens the whole tree when taken.
		"offers": func() -> Array: return [Addressee.offer(
			"rock", "Tell me about the rock.", Addressee.Kind.SERVICE, false, true)],
	})
	panel.add_child(_venue)
	_venue.build("THE DIG — Doug Diggs, Prospector Guild")
	_venue.mount_pings(self)
	_venue.changed.connect(refresh)
	_venue.offer_chosen.connect(_on_offer)
	_venue.office_opened.connect(_open_office)
	_venue.ware_bought.connect(_buy_ware)
	_venue.talks.chain_finished.connect(refresh)

	_body = _venue.body

	# HIS ORE COUNTER — the reason the Verge has a door.
	var ore_head := Label.new()
	ore_head.text = "ORE BUYER — pays over station rate"
	ore_head.add_theme_color_override("font_color", UiTheme.ACCENT)
	_venue.venue_box.add_child(ore_head)
	_ore_box = VBoxContainer.new()
	_ore_box.add_theme_constant_override("separation", 4)
	_venue.venue_box.add_child(_ore_box)


func show_deck() -> void:
	visible = true
	refresh()


func refresh() -> void:
	if not visible:
		return
	var bill := int(ship.dock_bill.get("repairs", 0))
	var txt := "[i][color=#a8b0c2]%s[/color][/i]\n\n" % Npcs.flavor("doug")
	txt += "Her engines have been cold for a decade. Doug cut the holds open into "
	txt += "hoppers and welded a berth on the flank, and now the Verge has a door.\n\n"
	if bill > 0:
		txt += "[color=#8890a0]He patched you up on the way in — %dc.[/color]\n\n" % bill
	txt += "[color=#8fe08f]He pays %d%% over station rate for ore.[/color] "
	txt += "\"You hauled it out here. That's worth something, and I'd rather pay it than fetch it.\""
	_body.text = txt % int(round((ORE_PREMIUM - 1.0) * 100.0))

	_venue.refresh()
	# Doug is ALWAYS talkable — he is the game's mining teacher, and a player who wants
	# to ask how any of this works should never find a person with nothing to say.
	_venue.desk.set_news(_venue.talks.has_news("doug"),
		"Ask him about rock any time.")
	_refresh_ore()


func _refresh_ore() -> void:
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


## THROUGH THE SHARED TalkChain — drains everything he holds, runs check_new_work
## here, and never replays the line just spoken. This used to pop one talk and stop.
## Doug's own offer: the mining lesson nothing else in the game teaches.
func _on_offer(id: String) -> void:
	if id != "rock":
		return
	var chat := DialoguePanel.new("doug", Dialogues.DOUG_DECK,
		func(_a: String) -> String: return "")
	chat.vo_prefix = "doug_deck"
	chat.closed.connect(refresh)
	_active_talk = chat
	add_child(chat)


func _open_office(prof: String) -> void:
	Tutor.retire("office")   # they walked in themselves — lesson unnecessary
	var office := GuildOffice.new("doug", prof, ship,
		func(path: String) -> void: _buy_ware(path),
		func(id: String) -> void:
			Pilot.join_profession(id)
			Sfx.play("jingle", -8.0)
			Research.journal.append({"day": GameClock.now(),
				"text": "Accepted the %s commission." % Professions.display_name(id)}))
	office.closed.connect(refresh)
	add_child(office)


## Quartermaster purchase, Doug's counter. Lands in the hold like any buy — unlike
## Vyper, who bolts it on, because a pilot at the Verge can still fly home to refit.
func _buy_ware(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var comp: ComponentDef = load(path)
	var price := int(_venue.price_of.call(comp))
	if Wallet.credits < price:
		# Every rejection must be VISIBLE (project rule) -- and NOT through
		# ship._flash_note, which writes to a label the flight HUD hides while docked.
		_venue.flash("Not enough credits — %s costs %dc." % [comp.display_name, price])
		Sfx.play("click", -16.0, 0.6)
		return
	# INTO YOUR HOLD, like every other counter. This appended to the STATION STASH,
	# so a chip bought at The Dig was not in the hold when you opened the Coupling
	# three feet away -- it was back at Cinder Reach, and nothing said so. Falls back
	# to the stash only when the hold genuinely cannot take it, and SAYS which.
	Wallet.credits -= price
	if ship.can_carry(comp):
		ship.add_cargo(comp)
		_venue.flash("Bought %s — %dc" % [comp.display_name, price])
	else:
		Stash.items.append(comp)
		_venue.flash("Bought %s — %dc  ·  HOLD FULL, sent to the station stash" % [
			comp.display_name, price])
	Sfx.play("jingle", -10.0)
