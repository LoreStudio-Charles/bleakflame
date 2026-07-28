extends SceneTree
## WHAT A SHIP IS WORTH, HULL vs FITTED — the arithmetic behind two exploits the user
## named before the Shipyard grew a "hulls owned" panel with a sell verb on it:
##
##   1. buy a hull, STRIP it, sell the parts for more than the hull cost;
##   2. fit a hull with hard-won loot, sell it for the BASE hull price, and be robbed.
##
## Both are the same missing rule: a ship's value is the ASSEMBLY, not the hull. This
## prints the numbers so the decision is made against what the game actually charges
## rather than against an assumption.
##
##   <godot> --headless --path . --script res://tools/audit_hull_value.gd


func _init() -> void:
	print("hull                 price   parts(buy)  parts(sell)   STRIP-AND-SELL")
	print("-------------------------------------------------------------------")
	var worst := 0
	var worst_name := ""
	for i in SampleBuilds.count():
		var build := SampleBuilds.get_build(i)
		var buy := 0
		var sell := 0
		for key in build.slots:
			var comp: ComponentDef = build.slots[key]
			if comp == null:
				continue
			buy += ItemVisuals.buy_price(comp)
			sell += ItemVisuals.sell_price(comp)
		for comp in build.chips:
			if comp == null:
				continue
			buy += ItemVisuals.buy_price(comp)
			sell += ItemVisuals.sell_price(comp)
		var price := int(build.hull.price)
		var profit := sell - price
		if profit > worst:
			worst = profit
			worst_name = build.hull.display_name
		print("%-20s %6d   %8d   %10d   %+8d%s" % [
			build.hull.display_name, price, buy, sell, profit,
			"   <<< PROFITABLE TO STRIP" if profit > 0 else ""])
	print("")
	if worst > 0:
		printerr("LIVE EXPLOIT: buying a %s and selling its parts nets %+dc." % [worst_name, worst])
	else:
		print("No hull is profitable to strip. The spread covers it — today.")
	quit()
