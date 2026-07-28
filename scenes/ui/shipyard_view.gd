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

var ship: TestShip


func _init(p_ship: TestShip) -> void:
	# EXPLICIT: a subclass _init suppresses the base's, and the tile width IS the column
	# fit — passing the tile's own constant is what keeps the shelf right when it changes.
	super(HullTile.TILE.x)
	ship = p_ship
	# ONE INVENTORY — you buy hulls here, you do not sell them back — so one shelf, and
	# no details column: every tile hovers the full hull tooltip already, and a column
	# restating it beside it is the duplicate this design exists to remove (user,
	# 2026-07-28). The verb is the right-click, as on every other shelf in the game.
	hide_detail()
	shelf("HULLS FOR SALE — flight-ready with standard loadout", "right-click to buy")


func header_text() -> String:
	return "[right][color=#%s]hulls owned[/color] %d of %d     [color=#%s]credits[/color] %dc[/right]" % [
		UiTheme.DIM.to_html(false), SampleBuilds.owned.size(), SampleBuilds.count(),
		UiTheme.DIM.to_html(false), Wallet.credits]


func fill_list() -> void:
	for index in SampleBuilds.count():
		var build := SampleBuilds.get_build(index)
		var t := HullTile.new(build, index)
		t.owned = SampleBuilds.owned.has(index)
		t.price = int(build.hull.price)
		# HullTile's own on_inspect/on_interact are left UNSET on purpose: the grid owns
		# click routing now, and two paths into the same gesture is how a left-click
		# starts meaning two things.
		tile(t, "h:%d" % index, "hull", {"index": index, "build": build},
			func() -> void: buy_requested.emit(index))
