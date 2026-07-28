extends SceneTree
## WHAT A SHIP IS WORTH, hull vs assembly — the arithmetic behind two exploits the user
## named before the Shipyard grew a sell verb:
##
##   1. buy a hull, STRIP it, sell the parts for more than the hull cost;
##   2. fit a hull with hard-won loot, sell it for the BASE hull price, and be robbed.
##
## THE MODEL (user, 2026-07-28): the asking price already contains the loadout —
## `orig_creds = hull_base + Σ(included_components)` — so the bare hull is worth the
## sticker minus what the yard threw in, and a sale credits the hull once and whatever is
## fitted once. See scripts/ship_value.gd.
##
## The column to read is STRIP vs WHOLE: they must be equal. Higher is exploit 1, lower
## is exploit 2, and both are the same missing rule.
##
##   <godot> --headless --path . --script res://tools/audit_hull_value.gd


func _init() -> void:
	print("hull                 asking    base   included    WHOLE    STRIP   delta")
	print("----------------------------------------------------------------------")
	var broken := 0
	for i in SampleBuilds.count():
		var stock := SampleBuilds.stock(i)
		var included := 0
		var loose := 0
		for part in ShipValue.fitted(stock):
			included += ItemVisuals.buy_price(part)
			loose += ItemVisuals.sell_price(part)
		var bare := ShipBuild.new()
		bare.hull = stock.hull
		var whole := ShipValue.sell(stock)
		var strip := ShipValue.sell(bare) + loose
		if strip != whole:
			broken += 1
		print("%-20s %6d  %6d   %8d %8d %8d %7d%s" % [
			stock.hull.display_name, int(stock.hull.price),
			ShipValue.hull_base(stock.hull), included, whole, strip, strip - whole,
			"   <<< MISMATCH" if strip != whole else ""])
	print("")
	if broken > 0:
		printerr("%d hull(s) pay differently for stripping than for selling whole." % broken)
	else:
		print("Strip and whole agree on every hull — neither exploit has anywhere to live.")
	quit()
