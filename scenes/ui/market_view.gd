class_name MarketView
extends ContextGrid
## THE EXCHANGE — the last shop to leave dock_screen.gd, and the one that had to wait.
##
## "Market should behave like the Armory as well, but since it's commodities instead of
## items it might have some information on scarcity vs abundance that indicates if a
## player is pushing their luck on trading here?" (user, 2026-07-27). I deferred it then
## and said why: the grid was never the missing part, the ECONOMY was. A row that only
## compares a good against a venue's fixed import/export list pays the fifth identical
## run exactly what it paid the first, so "scarcity" would have been a label on a
## constant.
##
## Local demand landed (TradeGoods, 2026-07-28), so a venue now genuinely runs short and
## genuinely gluts. This screen is where that becomes visible: every tile carries its
## price AND why the price is what it is.
##
## TWO INVENTORIES, like every shop — what they stock, and what is in your hold. Buying
## and selling are the two ends of one transaction and comparing them is the point.
##
## UI ONLY: the transactions move the wallet and the hold, so they stay the host's, on
## the shared TradeGoods paths the walkable town's counter also calls.

signal buy_requested(key: String)
signal sell_requested(key: String)

const MKT_GREEN := Color(0.42, 0.86, 0.46)   # a good deal for the player
const MKT_RED := Color(0.93, 0.45, 0.42)     # a poor deal for the player

var ship: TestShip
var market: Dictionary

var _shelf: GridContainer
var _hold: GridContainer


func _init(p_ship: TestShip, p_market: Dictionary) -> void:
	# EXPLICIT: a subclass _init suppresses the base's, so the shell is never built.
	super(MaterialStackTile.SHOP_SIZE.x)
	ship = p_ship
	market = p_market
	hide_detail()
	_shelf = shelf("%s EXCHANGE" % str(market.get("name", "Market")).to_upper(),
		"right-click to buy")
	_hold = shelf("YOUR GOODS", "right-click to sell")


func header_text() -> String:
	return "[right][color=#%s]credits[/color] %dc     [color=#%s]hold[/color] %.0f/%.0f[/right]" % [
		UiTheme.DIM.to_html(false), Wallet.credits, UiTheme.DIM.to_html(false),
		ship.cargo_used(), float(ship.stats.get("cargo", 0.0))]


func fill_list() -> void:
	var local: Array = market.get("local", [])
	var shown := 0
	for key in market.get("sells", {}):
		shown += 1
		var k := str(key)
		var is_local: bool = k in local
		var t := MaterialStackTile.new(k, 1, "shop")
		t.show_qty = false
		t.show_name = true
		t.price = TradeGoods.buy_price(market, k)
		# THE DEAL COLOUR IS UNCHANGED: buying a venue's OWN product is a good deal
		# (green), buying its import is a bad one (red). Demand shifts the number; it
		# does not change which side of the trade you are on.
		t.price_color = MKT_GREEN if is_local else MKT_RED
		t.hint = _hint(k, true)
		tile(t, "s:%s" % k, "shop", {"key": k},
			func() -> void: buy_requested.emit(k), _shelf)
	if shown == 0:
		empty_note("— this counter sells nothing —", _shelf)

	var carried := 0
	for key in ship.commodities:
		var k := str(key)
		var qty := int(ship.commodities[k])
		if qty <= 0:
			continue
		carried += 1
		var t := MaterialStackTile.new(k, qty, "hold")
		t.show_name = true
		var buys: bool = (market.get("buys", {}) as Dictionary).has(k)
		# A GOOD WITH NO BUYER STILL SHOWS. It is in your hold and you can see it there
		# — hiding it would read as cargo having gone missing, and campaign evidence
		# (the drone) is deliberately unsellable everywhere.
		t.price = TradeGoods.sell_price(market, k) if buys else -1
		t.price_color = MKT_RED if k in local else MKT_GREEN
		t.hint = _hint(k, false)
		if buys:
			tile(t, "h:%s" % k, "hold", {"key": k},
				func() -> void: sell_requested.emit(k), _hold)
		else:
			tile(t, "h:%s" % k, "hold", {"key": k}, Callable(), _hold)
	if carried == 0:
		empty_note("— no goods aboard —", _hold)


## WHY THE PRICE IS WHAT IT IS. The tooltip carries the verb, the rate, and — when the
## venue is off its baseline — the reason. A number that moved for an invisible cause
## reads as a bug rather than as a market responding to the player, which is the whole
## point of it responding.
func _hint(key: String, buying: bool) -> String:
	var lines: Array[String] = []
	if buying:
		lines.append("RIGHT-CLICK to buy — %dc" % TradeGoods.buy_price(market, key))
	elif (market.get("buys", {}) as Dictionary).has(key):
		lines.append("RIGHT-CLICK to sell — %dc" % TradeGoods.sell_price(market, key))
	else:
		lines.append("no buyer here")
	var mood := TradeGoods.demand_word(market, key)
	if mood == "SHORT":
		lines.append("SHORT here — they are paying up, and charging up")
	elif mood == "GLUTTED":
		lines.append("GLUTTED here — largely thanks to you; give it a few days")
	lines.append("mass %.0f each" % TradeGoods.unit_mass(key))
	return "\n".join(lines)
