class_name ArmoryView
extends ContextGrid
## THE ARMORY — buy and sell ship modules. The second shop through ContextGrid, and the
## one that decided the grid needed to hold more than one shelf.
##
## TWO SHELVES ARE NOT A RULE VIOLATION. I very nearly collapsed them behind a mode
## toggle on the grounds that "everything wanting a third column is one of the three
## zones in disguise" — user, correctly: "Armory is a place to buy and sell ship
## modules. What is the third thing?" There isn't one. The details panel IS the right
## zone; the two grids are both the LEFT zone. The Mission Computer's third column was a
## violation because it DUPLICATED the second with the action on the copy; a shop's
## stock and your own gear are the two ends of one transaction, and comparing them is
## the point ("can I sell this to afford that").
##
## THE SECOND SHELF IS STILL TEMPORARY (user, 2026-07-28): once stations are walkable,
## the Armory becomes the BUY screen and selling moves to the ship paperdoll — a
## merchant's context is their stock, and your kit is yours. That is one `shelf()` call
## to delete when it happens.
##
## UI ONLY. Buying and selling move the wallet, the hold and the stash, which stays the
## HOST's business — this emits and re-reads, the same contract every other context keeps.

signal buy_requested(path: String)
signal sell_requested(comp: ComponentDef, source: String)

const FILTER_CHIPS := -2

var ship: TestShip
var shop_of: Callable = func() -> Array: return []   ## paths this counter stocks

var _shop: GridContainer
var _yours: GridContainer
var _filter := -1                  ## -1 = all; FILTER_CHIPS; else a HardpointDef.SlotType
var _lvl_min := 1
var _lvl_max := Pilot.MAX_LEVEL
var _lvl_min_spin: SpinBox
var _lvl_max_spin: SpinBox


func _init(p_ship: TestShip) -> void:
	# EXPLICIT: a subclass _init suppresses the base's, so the shell is never built.
	super(ItemTile.SHOP_SIZE.x)
	ship = p_ship
	_build_filters()
	_shop = shelf("EQUIPMENT FOR SALE", "right-click to buy")
	_yours = shelf("YOUR COMPONENTS", "right-click to sell")


func header_text() -> String:
	return "[right][color=#%s]credits[/color] %dc     [color=#%s]hold[/color] %.0f/%.0f[/right]" % [
		UiTheme.DIM.to_html(false), Wallet.credits, UiTheme.DIM.to_html(false),
		ship.cargo_used(), float(ship.stats.get("cargo", 0.0))]


func fill_list() -> void:
	var shown_shop := 0
	for path in shop_of.call():
		var comp: ComponentDef = load(str(path))
		if comp == null or not passes(comp):
			continue
		shown_shop += 1
		var t := ItemTile.new(comp, "shop", ItemTile.Style.SHOP)
		t.price = ItemVisuals.buy_price(comp)
		t.hint = "left-click inspect · RIGHT-CLICK to buy (%dc)" % t.price
		tile(t, "s:%s" % str(path), "shop", {"comp": comp, "path": str(path)},
			func() -> void: buy_requested.emit(str(path)), _shop)
	var shown_yours := 0
	# YOUR HOLD, THEN THE STASH — both sellable here, and the tile says which is which
	# through its `source`, because selling out of the wrong one is not recoverable.
	for src in [["hold", ship.cargo], ["stash", Stash.items]]:
		var source := str(src[0])
		for i in (src[1] as Array).size():
			var comp: ComponentDef = (src[1] as Array)[i]
			if comp == null or not passes(comp):
				continue
			shown_yours += 1
			var t := ItemTile.new(comp, source, ItemTile.Style.SHOP)
			t.price = ItemVisuals.sell_price(comp)
			t.price_color = Color(0.42, 0.86, 0.46)
			t.hint = "left-click inspect · RIGHT-CLICK to sell (%dc)" % t.price
			# The id carries the SOURCE and the position, so two identical modules —
			# one in the hold, one in the stash — are different things to the selection.
			tile(t, "y:%s:%d" % [source, i], source, {"comp": comp, "source": source},
				func() -> void: sell_requested.emit(comp, source), _yours)

	# SAY WHICH FILTER EMPTIED THE SHELF. "Nothing here" under a level range set three
	# clicks ago reads as a broken shop; naming the band makes the cause the first thing
	# you see. Every rejection must be visible.
	var band := ""
	if _lvl_min > 1 or _lvl_max < Pilot.MAX_LEVEL:
		band = " for level %d–%d" % [_lvl_min, _lvl_max]
	if shown_shop == 0:
		empty_note("— nothing here%s —" % band, _shop)
	if shown_yours == 0:
		empty_note("— nothing in this category%s —" % band, _yours)


func render_detail(md: Dictionary) -> void:
	var comp: ComponentDef = md.comp
	title(comp.display_name, UiTheme.AMBER)
	var body := DockScreen.describe_component(comp)
	if body != "":
		note(body)
	if str(md.kind) == "shop":
		var price := ItemVisuals.buy_price(comp)
		var stop := ""
		if Wallet.credits < price:
			stop = "Short %dc — you have %dc." % [price - Wallet.credits, Wallet.credits]
		elif not ship.can_carry(comp):
			stop = "Your hold can't take it — mass %.0f, and you are carrying %.0f of %.0f." % [
				comp.mass, ship.cargo_used(), float(ship.stats.get("cargo", 0.0))]
		action("Buy — %dc" % price, stop,
			func() -> void: buy_requested.emit(str(md.path)))
		return
	var source := str(md.source)
	stat("Held in", "your hold" if source == "hold" else "the station stash")
	action("Sell — %dc" % ItemVisuals.sell_price(comp), "",
		func() -> void: sell_requested.emit(comp, source))


## THE FILTER, as a rule rather than a widget — so what a shelf shows is assertable
## without building a shelf.
func passes(comp: ComponentDef) -> bool:
	if comp == null:
		return false
	var lvl := int(comp.level)
	if lvl < _lvl_min or lvl > _lvl_max:
		return false
	if _filter == -1:
		return true
	if _filter == FILTER_CHIPS:
		return comp is AbilityChipDef
	# A chip reports SYSTEM, so an unfiltered "System" shelf would be half chips. Slot
	# filters mean "what fits this socket"; the chip rack is its own filter.
	if _filter == HardpointDef.SlotType.SYSTEM and comp is AbilityChipDef:
		return false
	return comp.slot_type() == _filter


func set_filter(type: int) -> void:
	_filter = type
	refresh()


## ---- the filter bar ----

## ON THE MODE BAR, beside the switcher rather than under it: what you are looking at
## and how it is narrowed are one decision, and a second bar below the first is a third
## zone appearing by accident.
func _build_filters() -> void:
	var bar := mode_bar()
	var group := ButtonGroup.new()
	_filter_button(bar, "All", -1, group)
	# SENSOR is listed even though it is last in the enum (new types append there, never
	# insert — the values are serialized in hull .tres files). Without a filter of its own
	# a sensor is unfindable except under "All", which for the one component a ship cannot
	# fly without is the wrong place to hide it.
	for t in [HardpointDef.SlotType.WEAPON, HardpointDef.SlotType.ENGINE,
			HardpointDef.SlotType.REACTOR, HardpointDef.SlotType.DEFENSE,
			HardpointDef.SlotType.SENSOR, HardpointDef.SlotType.SYSTEM]:
		_filter_button(bar, HardpointDef.SlotType.keys()[t].capitalize(), t, group)
	_filter_button(bar, "Chips", FILTER_CHIPS, group)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(14, 0)
	bar.add_child(spacer)
	var tag := Label.new()
	tag.text = "LEVEL"
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", UiTheme.AMBER)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(tag)
	_lvl_min_spin = _level_spin(bar, _lvl_min)
	var dash := Label.new()
	dash.text = "–"
	dash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(dash)
	_lvl_max_spin = _level_spin(bar, _lvl_max)

	# THE TWO ENDS CANNOT CROSS. Without this a pilot can set min 40 / max 5 and get a
	# permanently empty shop with no visible reason why — the failure looks like a broken
	# store, not a bad filter. Each end shoves the other rather than refusing the edit, so
	# there is no rejected input to explain.
	_lvl_min_spin.value_changed.connect(func(v: float) -> void:
		_lvl_min = int(v)
		if _lvl_min > _lvl_max:
			_lvl_max = _lvl_min
			_lvl_max_spin.set_value_no_signal(_lvl_max)
		refresh())
	_lvl_max_spin.value_changed.connect(func(v: float) -> void:
		_lvl_max = int(v)
		if _lvl_max < _lvl_min:
			_lvl_min = _lvl_max
			_lvl_min_spin.set_value_no_signal(_lvl_min)
		refresh())


func _filter_button(bar: HBoxContainer, label: String, type: int,
		group: ButtonGroup) -> void:
	var b := Button.new()
	b.text = label
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = _filter == type
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(func() -> void:
		Sfx.play("click", -16.0)
		set_filter(type))
	bar.add_child(b)


func _level_spin(bar: HBoxContainer, start: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = 1
	s.max_value = Pilot.MAX_LEVEL
	s.value = start
	s.custom_minimum_size = Vector2(64, 0)
	bar.add_child(s)
	return s
