extends Node
## The ground's RPG SHOP COUNTER (ShopView) — planetside trade WITHOUT the station's
## tabbed dock panel. This is the first slice of moving planetside services onto
## ground-native views (user, 2026-07-25), so it asserts the two things that matter:
##   1. walking up to the market and pressing [E] opens a shop, not a dock panel;
##   2. the shop is a SKIN — buying through it moves the same cargo/credits the shared
##      TradeGoods rules do (no second implementation to drift).
## Run as a SCENE (needs autoloads — ShopView uses Sfx):
##   <godot> --headless --path . res://tools/test_ground_shop.tscn

var _fails := 0


func _ready() -> void:
	var town: Node = load("res://scenes/ground/epharon_town.tscn").instantiate()
	add_child(town)
	for _i in 6:
		await get_tree().physics_frame

	# A stand-in player ship, in the group the town looks up.
	var ship := preload("res://tools/fake_hold.gd").new()
	ship.add_to_group("player_ship")
	add_child(ship)

	# 1) The MARKET building's [E] action is the ground shop, NOT a dock tab.
	var spots: Array = town.get("_spots")
	var market_action := ""
	for s in spots:
		if str(s.get("prompt", "")).findn("market") >= 0:
			market_action = str(s.get("action", ""))
	_chk(market_action == "enter:MARKET",
		"the colony market is an ENTERABLE location (action '%s')" % market_action)

	# 2) Inside, BRAM runs the counter — [E] on him raises the ShopView and FREEZES the
	#    town (same contract as a panel).
	town.call("_do_action", "shop:bram")
	await get_tree().process_frame
	var shop: ShopView = null
	for c in town.get_children():
		if c is ShopView:
			shop = c
	_chk(shop != null, "pressing [E] at the market opened a ShopView")
	_chk(town.get("_active") == false, "the town freezes while the counter is up")

	if shop != null:
		# 3) It's a SKIN over the shared rules: buying moves cargo + credits identically.
		Wallet.credits = 500
		var before := Wallet.credits
		shop._on_buy("food")
		_chk(int(ship.commodities.get("food", 0)) == 1, "buying at the counter filled the hold")
		_chk(Wallet.credits == before - TradeGoods.buy_price(TradeGoods.PLANET_MARKET, "food"),
			"the counter charged exactly the shared price")

		# 4) A refusal is VISIBLE (project convention), never a silent no-op.
		Wallet.credits = 0
		shop._on_buy("food")
		_chk(shop._note.visible and str(shop._note.text) != "",
			"a refused purchase says why on screen ('%s')" % shop._note.text)
		_chk(int(ship.commodities.get("food", 0)) == 1, "the refused purchase changed nothing")

		# 4b) RPG SHOP SHAPE (user's design): the shelf is a GRID OF TILES with icon +
		#     price, and your own inventory sits beside it — right-click buys on one side,
		#     sells on the other. Same tile vocabulary as the Armory, no bespoke rows.
		Wallet.credits = 500
		shop.refresh()
		var tiles := 0
		for c in shop._rows.get_children():
			if c is MaterialStackTile:
				tiles += 1
				_chk(c.price >= 0, "the shelf tile for '%s' quotes a price" % c.key)
		_chk(tiles > 0, "the shelf renders as ITEM TILES, not text rows (%d)" % tiles)
		_chk(shop._hold is InventoryGrid,
			"your side of the counter is the SHARED InventoryGrid, not a bespoke list")
		# Selling happens from YOUR INVENTORY, right-click — so a carried good that this
		# market buys must wear a sell price in the hold grid.
		ship.add_commodity("circuits", 1)
		shop.refresh()
		var priced := false
		for c in shop._hold._grid.get_children():
			if c is MaterialStackTile and c.key == "circuits":
				priced = c.price == TradeGoods.sell_price(TradeGoods.PLANET_MARKET, "circuits")
		_chk(priced, "a sellable good in your hold shows what this counter pays")

		# 4c) THE GESTURE ITSELF. Everything above drives the handlers directly, which
		#     would still pass if right-click were never WIRED to them. Dispatch a real
		#     InputEventMouseButton through the tile so the idiom is actually covered.
		Wallet.credits = 500
		var before_food := int(ship.commodities.get("food", 0))
		var shelf_tile: MaterialStackTile = null
		for c in shop._rows.get_children():
			if c is MaterialStackTile and c.key == "food":
				shelf_tile = c
		_chk(shelf_tile != null, "the shelf has a food tile to right-click")
		if shelf_tile != null:
			shelf_tile._gui_input(_rmb())
			_chk(int(ship.commodities.get("food", 0)) == before_food + 1,
				"RIGHT-CLICKING a shelf tile actually buys it")
		# And right-click on the hold side sells.
		ship.add_commodity("circuits", 1)
		shop.refresh()
		var held_tile: MaterialStackTile = null
		for c in shop._hold._grid.get_children():
			if c is MaterialStackTile and c.key == "circuits":
				held_tile = c
		if held_tile != null:
			var before_circ := int(ship.commodities.get("circuits", 0))
			held_tile._gui_input(_rmb())
			_chk(int(ship.commodities.get("circuits", 0)) == before_circ - 1,
				"RIGHT-CLICKING a hold tile actually sells it")

		# 5) Closing hands control back to the town.
		shop.close()
		await get_tree().process_frame
		_chk(town.get("_active") == true, "leaving the counter thaws the town")

	# ---- THE CONTRACT BOARD (second ground-native slice) ----
	# 6) The board building opens a ground BoardView, not the dock's Mission Uplink tab.
	var board_action := ""
	for s in town.get("_spots"):
		if str(s.get("prompt", "")).findn("contract board") >= 0:
			board_action = str(s.get("action", ""))
	_chk(board_action.begins_with("board:"),
		"the colony board opens a ground BOARD, not a dock panel (action '%s')" % board_action)

	town.call("_do_action", board_action)
	await get_tree().process_frame
	var board: BoardView = null
	for c in town.get_children():
		if c is BoardView:
			board = c
	_chk(board != null, "pressing [E] at the board opened a BoardView")

	if board != null:
		# 7) It's a SKIN: taking work goes through the shared MissionLog rules.
		MissionLog.ensure_offers()
		var posted: Array = MissionLog.offers_at("planet", "")
		if not posted.is_empty():
			var held := MissionLog.active.size()
			board._on_take(int(posted[0]["index"]))
			_chk(MissionLog.active.size() == held + 1,
				"taking a posting off the ground board put it in hand")

		# 8) A refusal is VISIBLE, never a silent no-op — here, an unfinished contract.
		if not MissionLog.active.is_empty():
			board._on_turn_in(0)
			_chk(board._note.visible and str(board._note.text) != "",
				"an unfinished turn-in says why ('%s')" % board._note.text)

		board.close()
		await get_tree().process_frame
		_chk(town.get("_active") == true, "stepping away from the board thaws the town")

	# ---- THE STARPORT (the LAST service off the docking panel) ----
	# 9) Nothing on the ground routes through the dock any more: the starport is a
	#    ground-native receipt view, and no spot carries a `svc:` action at all.
	for s in town.get("_spots"):
		_chk(not str(s.get("action", "")).begins_with("svc:"),
			"no town spot opens a dock panel ('%s')" % s.get("action", ""))
	town.call("_do_action", "starport")
	await get_tree().process_frame
	var port: StarportView = null
	for c in town.get_children():
		if c is StarportView:
			port = c
	_chk(port != null, "the STARPORT opens a ground-native services view")
	if port != null:
		port.close()
		await get_tree().process_frame
		_chk(town.get("_active") == true, "leaving the starport thaws the town")

	print("test_ground_shop: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## A real right-click, so tests cover the GESTURE and not just the handler behind it.
func _rmb(shift := false) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	e.shift_pressed = shift
	return e


func _chk(cond: bool, msg: String) -> void:
	print(("  ok  " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1
