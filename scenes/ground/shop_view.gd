class_name ShopView
extends CanvasLayer
## An RPG SHOP COUNTER — the ground's storefront, opened from an NPC's dialogue
## ("Let me see your wares") instead of a dock tab.
##
## WHY THIS EXISTS (user, 2026-07-25): planetside was reusing the station's tabbed
## DockScreen, raised over the walkable town with its tab strip hidden. That shoehorn
## leaked everywhere — tutor lessons pointed at tabs that weren't on screen, and every
## new ground service meant more special-casing of a menu built for a space station.
## On the ground you walk up to a PERSON; the shop is their counter, not a deck.
##
## DELIBERATELY THIN. Every rule — price, affordability, hold mass, standing — lives in
## TradeGoods.buy/sell, the SAME calls the station dock makes. This file only draws and
## dispatches, so the two storefronts cannot drift apart. Add a service by writing
## another small view like this one, never by widening the dock panel.
##
## Self-contained: builds its own UI in _ready, owns Esc while open (group
## "esc_capture"), and frees itself on close. The host just instances it and connects
## `closed`.

signal closed

const GOOD := Color(0.42, 0.86, 0.46)   # a good deal for the player (matches the dock's MKT_GREEN)
const BAD := Color(0.93, 0.45, 0.42)    # a poor deal (MKT_RED)

var npc_id: String                  # who is serving you (portrait + name)
var market: Dictionary              # a TradeGoods market table (sells/buys)
var ship                            # duck-typed: commodities / can_carry_mass / add_ / remove_
var gear_stock: Array = []          # .tres paths of EQUIPMENT this counter also sells
                                    # (clean factory stock — salvage is where affixes come from)

var _rows: GridContainer      # the shelf
var _hold: InventoryGrid      # your side of the counter
var _purse: Label
var _note: Label
var _note_t := 0.0


func _init(p_npc: String, p_market: Dictionary, p_ship, p_gear: Array = []) -> void:
	npc_id = p_npc
	market = p_market
	ship = p_ship
	gear_stock = p_gear
	layer = 26   # above the town + its prompts, below the pause menu


func _ready() -> void:
	add_to_group("esc_capture")
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -470
	panel.offset_right = 470
	panel.offset_top = -290
	panel.offset_bottom = 290
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.BG, 0.99)
	style.border_color = UiTheme.AMBER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	# The shopkeeper's counter: their face, then the goods. A shop is a PERSON here.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	root.add_child(head)
	var portrait := Npcs.portrait(npc_id)
	if portrait != null:
		var face := TextureRect.new()
		face.texture = portrait
		face.custom_minimum_size = Vector2(64, 64)
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.add_child(face)
	var titles := VBoxContainer.new()
	head.add_child(titles)
	var who := Label.new()
	who.text = "%s — %s" % [Npcs.display_name(npc_id), str(market.get("name", "Trade"))]
	who.add_theme_font_size_override("font_size", 17)
	who.add_theme_color_override("font_color", UiTheme.AMBER)
	titles.add_child(who)
	var sub := Label.new()
	sub.text = "GREEN is a good price here · RED is dear. Buy what's made locally, sell what's wanted."
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", UiTheme.ACCENT)
	titles.add_child(sub)

	# THE SHOP COUNTER, RPG-style (user, 2026-07-25): the shelf is a GRID OF TILES with
	# icon + price on the left, and YOUR OWN inventory on the right — right-click buys on
	# one side, sells on the other. Same gesture as the Armory, same tiles, so a good
	# reads identically wherever it appears.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	var wares_col := VBoxContainer.new()
	wares_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wares_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(wares_col)
	var wh := Label.new()
	wh.text = "WARES"
	wh.add_theme_color_override("font_color", UiTheme.AMBER)
	wares_col.add_child(wh)
	var wscroll := ScrollContainer.new()
	wscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wares_col.add_child(wscroll)
	_rows = GridContainer.new()
	_rows.columns = 5
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wscroll.add_child(_rows)

	# YOUR HOLD is the SHARED InventoryGrid with "sell" bound to right-click — the same
	# widget the character sheet and salvage panel will use, never a bespoke copy.
	_hold = InventoryGrid.new(ship)
	_hold.title = "YOUR HOLD"
	_hold.source = "hold"
	_hold.material_hint = func(key: String) -> String:
		if not market.get("buys", {}).has(key):
			return "no buyer here"
		return "RIGHT-CLICK to sell (%dc)" % TradeGoods.sell_price(market, key)
	_hold.material_price = func(key: String) -> int:
		return TradeGoods.sell_price(market, key) if market.get("buys", {}).has(key) else -1
	_hold.on_material = func(key: String, _s: String) -> void: _on_sell(key)
	# EQUIPMENT sells here too (a counter that stocks gear also buys it) — how a goblin's
	# clutched shiv turns into credits. Same price rule as the station Armory.
	if not gear_stock.is_empty():
		_hold.item_hint = func(c: ComponentDef) -> String:
			return "RIGHT-CLICK to sell (%dc)" % ItemVisuals.sell_price(c)
		_hold.item_price = func(c: ComponentDef) -> int: return ItemVisuals.sell_price(c)
		_hold.on_item = func(c: ComponentDef, _s: String) -> void: _on_sell_gear(c)
	cols.add_child(_hold)

	_purse = Label.new()
	_purse.add_theme_color_override("font_color", UiTheme.AMBER)
	root.add_child(_purse)
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 12)
	_note.visible = false
	root.add_child(_note)

	var leave := Button.new()
	leave.text = "Leave the counter   [Esc]"
	UiTheme.button_flavor(leave, "tertiary")
	leave.pressed.connect(close)
	root.add_child(leave)

	refresh()


func refresh() -> void:
	# remove_child BEFORE queue_free: queue_free is DEFERRED, so a second refresh in the
	# same frame would count (and briefly draw) the old tiles on top of the new ones.
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	# THE SHELF — only what this counter actually SELLS. (What it buys is read off your
	# own hold, where the price badge is: you sell from your inventory, RPG-style.)
	# Equipment first (the eye-catchers), then the produce.
	for path in gear_stock:
		if ResourceLoader.exists(str(path)):
			_rows.add_child(_gear_tile(str(path)))
	for key in market.get("sells", {}):
		_rows.add_child(_ware_tile(str(key)))
	if _rows.get_child_count() == 0:
		var none := Label.new()
		none.text = "— the shelf is bare —"
		none.add_theme_color_override("font_color", Color(0.5, 0.55, 0.62))
		_rows.add_child(none)

	_hold.refresh()
	_purse.text = "credits %dc      hold %.0f / %.0f" % [
		Wallet.credits, ship.cargo_used(), ship.stats.cargo]


## One good on the shelf. RIGHT-CLICK BUYS — no button, matching the Armory idiom.
## Deal colouring mirrors the dock's rule so the lesson transfers between venues: a LOCAL
## product is cheap (green), an import carries a premium (red).
func _ware_tile(key: String) -> MaterialStackTile:
	var local: bool = key in market.get("local", [])
	var t := MaterialStackTile.new(key, 0, "shop")
	t.show_qty = false            # a shelf sells by the unit; it has no stack
	t.draggable = false
	t.price = TradeGoods.buy_price(market, key)
	t.price_color = GOOD if local else BAD
	t.hint = "%s · RIGHT-CLICK to buy (%dc)" % [
		"local produce" if local else "imported — priced accordingly", t.price]
	t.on_interact = func(k: String, _s: String) -> void: _on_buy(k)
	return t


## A piece of EQUIPMENT on the shelf — the same ItemTile the Armory and dossier use, so
## gear reads identically wherever it appears. Shop stock is CLEAN (no affixes) by the
## affix convention: the shop sells factory gear, salvage is where treasure comes from.
func _gear_tile(path: String) -> ItemTile:
	var comp: ComponentDef = load(path)
	var t := ItemTile.new(comp, "shop", ItemTile.Style.SHOP)
	t.price = ItemVisuals.buy_price(comp)
	t.hint = "RIGHT-CLICK to buy (%dc) — equip it in your dossier [P]" % t.price
	t.on_interact = func(_c: ComponentDef, _s: String) -> void: _on_buy_gear(path)
	return t


func _on_buy(key: String) -> void:
	_report(TradeGoods.buy(ship, market, key))


func _on_sell(key: String) -> void:
	_report(TradeGoods.sell(ship, market, key))


## Mirrors the station Armory's buy rule (credits, then hold mass, every refusal
## visible) — load(path) hands over a FRESH resource so shop stock is never shared.
func _on_buy_gear(path: String) -> void:
	var comp: ComponentDef = load(path)
	var price := ItemVisuals.buy_price(comp)
	if Wallet.credits < price:
		_report({"ok": false, "msg": "Not enough credits (%dc needed)." % price})
		return
	if not ship.can_carry(comp):
		_report({"ok": false, "msg": "Hold can't take %s (mass %.0f)." % [comp.display_name, comp.mass]})
		return
	Wallet.credits -= price
	ship.add_cargo(load(path))
	Sfx.play("pickup", -8.0)   # the ACQUIRE cue, same as the Armory — you got something
	_report({"ok": true, "msg": "Bought %s — %dc. Equip it in your dossier [P]." % [comp.display_name, price]})


func _on_sell_gear(comp: ComponentDef) -> void:
	var price := ItemVisuals.sell_price(comp)
	ship.cargo.erase(comp)
	Wallet.credits += price
	_report({"ok": true, "msg": "Sold %s — %dc." % [comp.display_name, price]})


## Every rejection is VISIBLE (project convention) — the shared call already says why.
func _report(r: Dictionary) -> void:
	Sfx.play("click", -16.0)
	_note.text = str(r.get("msg", ""))
	_note.add_theme_color_override("font_color",
		GOOD if bool(r.get("ok", false)) else UiTheme.DANGER)
	_note.visible = true
	_note_t = 2.4
	refresh()


func _process(delta: float) -> void:
	if _note_t > 0.0:
		_note_t -= delta
		if _note_t <= 0.0:
			_note.visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		close()


func close() -> void:
	closed.emit()
	queue_free()
