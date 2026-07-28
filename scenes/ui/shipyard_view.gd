class_name ShipyardView
extends ContextGrid
## THE SHIPYARD — hulls on a shelf, and the first shop built as a portable context.
##
## It was already the right SHAPE (a grid of tiles beside a details panel); what it was
## not was a THING. It lived inside dock_screen.gd as a tab, which meant the one screen
## in the game for buying a ship could only ever be reached by a tab strip. Now it is a
## `ContextGrid` like any other, so a shipwright in a room can hand you the same shelf.
##
## THE FACE IS THE SHIP'S OWN SPRITE (HullTile), so this needed no new art — and it
## inherits the quality paint ladder (docs/quality_paint.md) the day those decals land.
##
## UI ONLY. Buying moves the wallet and the owned list, which is the HOST'S business:
## this emits and re-reads, the same contract MissionComputer keeps.

signal buy_requested(index: int)
signal board_requested(index: int)

var ship: TestShip

var _stock: GridContainer
var _fleet: GridContainer


func _init(p_ship: TestShip) -> void:
	# EXPLICIT: a subclass _init suppresses the base's, and the tile width IS the column
	# fit — passing the tile's own constant is what keeps the shelf right when it changes.
	super(HullTile.TILE.x)
	ship = p_ship
	# TWO INVENTORIES, like every shop: what is for sale, and what is yours. No details
	# column — every tile hovers the full hull tooltip already, and a column restating it
	# beside them is the duplicate this design exists to remove (user, 2026-07-28).
	hide_detail()
	_stock = shelf("HULLS FOR SALE — flight-ready with standard loadout",
		"right-click to buy")
	# THE VERB HERE IS BOARD, NOT SELL. Selling a ship is a pricing decision nobody has
	# taken yet (see ShipValue for the two ways it goes wrong), and shipping a sell button
	# ahead of the rule is how the first of those becomes real. Boarding is the verb this
	# shelf can offer today — and it is the one the details panel used to send you to
	# another tab for ("board her in the Engineering Bay").
	_fleet = shelf("YOUR HULLS", "right-click to board")


func header_text() -> String:
	return "[right][color=#%s]hulls owned[/color] %d of %d     [color=#%s]credits[/color] %dc[/right]" % [
		UiTheme.DIM.to_html(false), SampleBuilds.owned.size(), SampleBuilds.count(),
		UiTheme.DIM.to_html(false), Wallet.credits]


func fill_list() -> void:
	for index in SampleBuilds.count():
		var build := SampleBuilds.get_build(index)
		var owned: bool = SampleBuilds.owned.has(index)
		# HullTile's own on_inspect/on_interact are left UNSET on purpose: the grid owns
		# click routing now, and two paths into the same gesture is how a left-click
		# starts meaning two things.
		if not owned:
			var t := HullTile.new(build, index)
			t.price = int(build.hull.price)
			tile(t, "h:%d" % index, "hull", {"index": index, "build": build},
				func() -> void: buy_requested.emit(index), _stock)
			continue
		var mine := HullTile.new(build, index)
		mine.owned = true
		# WHAT SHE IS WORTH AS SHE STANDS — hull and everything bolted to it, through the
		# one function that will price a sale the day selling exists. Shown now because a
		# pilot deciding what to fly should see what each ship represents, and because a
		# number the player has already been reading is much harder to quietly get wrong
		# later than one invented at the moment of the first sale.
		mine.price = ShipValue.sell(build)
		mine.price_color = Color(0.42, 0.86, 0.46)
		tile(mine, "h:%d" % index, "hull", {"index": index, "build": build},
			func() -> void: board_requested.emit(index), _fleet)
	if SampleBuilds.owned.is_empty():
		empty_note("— you own nothing yet —", _fleet)
