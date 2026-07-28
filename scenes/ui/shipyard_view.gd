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
	shelf()      # one pile; the Armory beside it is the screen that needs two
	# WHAT THIS SHELF IS, kept from the column heading the tab used to carry. "Flight-
	# ready with standard loadout" is the one fact about buying a hull here that is not
	# visible on any tile, and dropping it in the move would have been the migration
	# quietly costing the screen a sentence.
	var cap := Label.new()
	cap.text = "SHIPYARD — flight-ready hulls, standard loadout"
	cap.add_theme_color_override("font_color", UiTheme.ACCENT)
	header_left.add_child(cap)


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


func render_detail(md: Dictionary) -> void:
	var build: ShipBuild = md.build
	var index := int(md.index)
	var owned: bool = SampleBuilds.owned.has(index)
	title(build.hull.display_name, UiTheme.AMBER)
	# THE SAME TOOLTIP THE TILE HOVERS, given a permanent home — comparing two hulls
	# should not mean holding the mouse still. Reused rather than restated: a second
	# description of a hull is a second thing to keep in step with HullDef.
	var tip := DockScreen.hull_tooltip(build)
	if tip != null:
		tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_box().add_child(tip)
	if owned:
		# Not a blocked BUY — there is nothing to buy. Boarding is the Engineering Bay's
		# verb, and a greyed "Buy" over a ship you own would be a refusal invented to
		# have something to grey out.
		note("[color=#6de08f]OWNED — board her in the Engineering Bay.[/color]")
		return
	var price := int(build.hull.price)
	var stop := ""
	if Wallet.credits < price:
		stop = "Short %dc — you have %dc." % [price - Wallet.credits, Wallet.credits]
	action("Buy — %dc" % price, stop, func() -> void: buy_requested.emit(index))
