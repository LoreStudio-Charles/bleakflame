extends SceneTree
## SAME-COUNTER ARBITRAGE — can a pilot buy a good and immediately sell it back, at the
## same desk, for more than they paid?
##
## TradeGoods says not: "The premium is always ABOVE that market's own buy-back price, so
## there's no same-dock arbitrage." That is true of the LISTED prices. It says nothing
## about what happens once a pilot's trade perk moves both ends — which is exactly the
## boundary the user named (2026-07-28): the trade skill may "chip away at the diff from
## buy and sell without ever making it profitable to buy and sell".
##
##   <godot> --headless --path . --script res://tools/audit_arbitrage.gd


func _init() -> void:
	# THE PERK SCALES WITH LEVEL (Professions.PERK_PER_LEVEL x Pilot.level()), so a
	# profession alone proves nothing — a level-1 trader has a 0.5% edge. The case that
	# matters is the one a real pilot reaches: commissioned and capped.
	for pilot in [["fresh pilot, no commission", "", 0],
			["MAXED TRADER (level 60)", "trader", 9_000_000]]:
		Pilot.profession = str(pilot[1])
		Wallet.xp = int(pilot[2])
		print("\n--- %s  (level %d, buy x%.2f  sell x%.2f) ---" % [
			str(pilot[0]), Pilot.level(), Pilot.trade_buy_mult(), Pilot.trade_sell_mult()])
		print("venue        good          pays   gets   round trip")
		var bad := 0
		for market in [TradeGoods.STATION_MARKET, TradeGoods.PLANET_MARKET,
				TradeGoods.VERGE_MARKET]:
			for key in market["sells"]:
				if not market["buys"].has(key):
					continue      # cannot sell it back here; no round trip exists
				var pays := TradeGoods.buy_price(market, str(key))
				var gets := TradeGoods.sell_price(market, str(key))
				if gets >= pays:
					bad += 1
				print("%-12s %-12s %5d  %5d   %+6d%s" % [
					str(market["name"]), TradeGoods.display_name(str(key)), pays, gets,
					gets - pays, "   <<< FREE MONEY" if gets >= pays else ""])
		if bad > 0:
			printerr("  %d good(s) can be round-tripped at a profit." % bad)
		else:
			print("  No round trip pays. The spread holds.")

		# AND THE ROUTE MUST STILL PAY — better for a trader than for anyone else. Closing
		# the same-desk loop is worthless if it also flattens the gameplay it protects
		# (user: "it's okay to cross ... that's the trader gameplay, buy low here sell
		# high there").
		for leg in [["circuits", TradeGoods.STATION_MARKET, TradeGoods.PLANET_MARKET],
				["food", TradeGoods.PLANET_MARKET, TradeGoods.STATION_MARKET],
				# ORE MUST LOSE BOTH WAYS. Doug pays over the station rate, so a naive
				# "buy cheap at the station, haul it to the premium buyer" is the obvious
				# thing a player will try — and mining has to stay the only way rock pays.
				["ferrite_ore", TradeGoods.STATION_MARKET, TradeGoods.VERGE_MARKET],
				["ferrite_ore", TradeGoods.VERGE_MARKET, TradeGoods.STATION_MARKET],
				["aurite_ore", TradeGoods.STATION_MARKET, TradeGoods.VERGE_MARKET]]:
			var key := str(leg[0])
			var buy_at: Dictionary = leg[1]
			var sell_at: Dictionary = leg[2]
			var paid := TradeGoods.buy_price(buy_at, key)
			var got := TradeGoods.sell_price(sell_at, key)
			print("  ROUTE  %-9s %s %d -> %s %d   %+dc a unit" % [
				TradeGoods.display_name(key), str(buy_at["name"]), paid,
				str(sell_at["name"]), got, got - paid])
	Pilot.profession = ""
	Wallet.xp = 0
	quit()
