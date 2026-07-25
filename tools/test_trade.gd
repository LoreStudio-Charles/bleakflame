extends SceneTree
## The TRADE RULES are shared by every storefront — the station's tabbed dock and the
## ground's RPG shop counter both call TradeGoods.buy/sell, so a rule can only be
## written once. This asserts those rules directly (no UI), which is the whole point of
## having extracted them out of DockScreen.
##   <godot> --headless --path . --script res://tools/test_trade.gd
## NOTE --script mode has NO autoloads: TradeGoods/Wallet/Pilot/Standing are all plain
## static classes, which is exactly why the logic was put there and not in a Control.

var _fails := 0


## Minimal stand-in for the player ship — the trade calls duck-type it, so the rules can
## be tested without standing up a whole BuildShip.
class FakeShip:
	var commodities := {}
	var capacity := 100.0

	func cargo_used() -> float:
		var used := 0.0
		for k in commodities:
			used += commodities[k] * TradeGoods.unit_mass(k)
		return used

	func can_carry_mass(mass: float) -> bool:
		return cargo_used() + mass <= capacity

	func add_commodity(key: String, qty: int) -> void:
		commodities[key] = int(commodities.get(key, 0)) + qty

	func remove_commodity(key: String, qty: int) -> void:
		commodities[key] = int(commodities.get(key, 0)) - qty


func _init() -> void:
	var planet := TradeGoods.PLANET_MARKET

	# --- BUY ---
	var ship := FakeShip.new()
	Wallet.credits = 1000
	var r := TradeGoods.buy(ship, planet, "food")
	_chk(r.ok, "buying food at the colony succeeds")
	_chk(int(ship.commodities.get("food", 0)) == 1, "the food is in the hold")
	_chk(Wallet.credits == 1000 - TradeGoods.buy_price(planet, "food"),
		"credits fell by exactly the quoted price")

	# Every rejection must be VISIBLE (project convention) — so each carries a reason.
	Wallet.credits = 0
	r = TradeGoods.buy(ship, planet, "food")
	_chk(not r.ok and str(r.msg) != "", "broke: refused WITH a reason ('%s')" % r.msg)

	Wallet.credits = 1000
	r = TradeGoods.buy(ship, planet, "aurite_ore")
	_chk(not r.ok, "can't buy what this market doesn't sell")

	var full := FakeShip.new()
	full.capacity = 1.0                     # less than one unit of anything
	r = TradeGoods.buy(full, planet, "food")
	_chk(not r.ok and str(r.msg).findn("hold") >= 0, "full hold refused with a hold message")

	# --- SELL ---
	var seller := FakeShip.new()
	seller.commodities["circuits"] = 2
	Wallet.credits = 0
	r = TradeGoods.sell(seller, planet, "circuits")
	_chk(r.ok, "the colony buys circuits (the import it wants)")
	_chk(int(seller.commodities["circuits"]) == 1, "one unit left the hold")
	_chk(Wallet.credits == TradeGoods.sell_price(planet, "circuits"), "paid the quoted price")

	r = TradeGoods.sell(seller, planet, "food")
	_chk(not r.ok, "selling what you don't carry is refused")

	seller.commodities["food"] = 1
	r = TradeGoods.sell(seller, planet, "food")
	_chk(not r.ok and str(r.msg).findn("buyer") >= 0,
		"no buyer here — refused, and says so ('%s')" % r.msg)

	# Ore sales feed Doug's guild standing (the rule rides with the transaction, so it
	# applies in the ground shop too — it used to live in the dock's button handler).
	var miner := FakeShip.new()
	miner.commodities["aurite_ore"] = 1
	var before := Standing.get_points("miner")
	TradeGoods.sell(miner, TradeGoods.STATION_MARKET, "aurite_ore")
	_chk(Standing.get_points("miner") > before, "selling ore still credits Miner standing")

	# --- THE ROUTE ---
	# Each venue names what it MAKES, and that drives deal colouring in both storefronts.
	_chk(TradeGoods.PLANET_MARKET["local"].has("food")
			and TradeGoods.STATION_MARKET["local"].has("circuits"),
		"each market declares its local product")
	_chk(TradeGoods.buy_price(planet, "food") < TradeGoods.buy_price(planet, "circuits"),
		"local food is cheaper than imported circuits — the route still pays")

	print("test_trade: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(1 if _fails > 0 else 0)


func _chk(cond: bool, msg: String) -> void:
	print(("  ok  " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1
