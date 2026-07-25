class_name InventoryGrid
extends VBoxContainer
## WHAT A SHIP IS CARRYING, as a grid of tiles — the game's ONE inventory surface.
##
## THE RULE THIS EXISTS TO ENFORCE (agreed with user, 2026-07-25): **one grid widget, one
## tile vocabulary, many hosts.** The shop's sell side, the character sheet, the salvage
## panel and (later) Engineering's cargo/stash all show "your stuff"; hand-rolling each
## one is how four subtly different inventories appear and the grade border stops matching.
## If a new inventory surface can't be expressed as "this grid + a different verb bound to
## right-click", that's the signal something is being duplicated.
##
## The HOST binds the verb; the grid owns the layout and the tiles:
##     var inv := InventoryGrid.new(ship)
##     inv.title = "YOUR HOLD"
##     inv.item_hint  = func(c): return "RIGHT-CLICK to sell (%dc)" % ...
##     inv.on_item    = func(comp, source): ...     # right-click a component
##     inv.on_material= func(key, source): ...      # right-click a material stack
##     inv.refresh()
##
## Shows MATERIALS (commodity stacks) and COMPONENTS (salvaged gear) together, because
## that is what a hold actually contains — a player looking for "my stuff" should not have
## to know which internal list a thing lives in.

## Emitted after any host verb runs, so a parent can refresh its own totals.
signal changed

var ship
var title := "CARGO HOLD"
var source := "hold"                   # tagged onto every tile; hosts key off it
var empty_text := "— hold empty —"
var columns := 6

## Host verbs (all optional; unbound = inert).
var on_item: Callable                  # func(comp: ComponentDef, source: String)
var on_material: Callable              # func(key: String, source: String)
var on_inspect_item: Callable          # func(comp)  — left-click
var on_inspect_material: Callable      # func(key)   — left-click

## Per-entry tooltip hints, so the host can quote its own price.
var item_hint: Callable                # func(comp) -> String
var material_hint: Callable            # func(key)  -> String
## Per-entry price badge; return -1 for none.
var item_price: Callable               # func(comp) -> int
var material_price: Callable           # func(key)  -> int

var _grid: GridContainer
var _head: Label


func _init(p_ship) -> void:
	ship = p_ship


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_head = Label.new()
	_head.add_theme_color_override("font_color", UiTheme.AMBER)
	add_child(_head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = columns
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	refresh()


func refresh() -> void:
	if _grid == null:
		return   # not built yet; _ready() calls refresh() itself
	_head.text = title
	# remove_child BEFORE queue_free (deferred), so a same-frame refresh can't stack tiles.
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()

	# NO SHIP is a legitimate state, not a bug: the dossier can be opened before one is
	# boarded (and it re-finds the hull each refresh, since you can board another).
	if ship == null:
		var none := Label.new()
		none.text = empty_text
		none.add_theme_color_override("font_color", Color(0.5, 0.55, 0.62))
		_grid.add_child(none)
		return

	# Materials first — the bulk of a working hold is usually ore and freight.
	for key in ship.commodities:
		var qty := int(ship.commodities[key])
		if qty <= 0:
			continue
		_grid.add_child(_material_tile(str(key), qty))

	# Then components (salvage, spare parts).
	var carried = ship.get("cargo")
	if carried != null:
		for comp in carried:
			_grid.add_child(_item_tile(comp))

	if _grid.get_child_count() == 0:
		var lbl := Label.new()
		lbl.text = empty_text
		lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.62))
		_grid.add_child(lbl)


func _material_tile(key: String, qty: int) -> MaterialStackTile:
	var t := MaterialStackTile.new(key, qty, source)
	if material_hint.is_valid():
		t.hint = str(material_hint.call(key))
	if material_price.is_valid():
		t.price = int(material_price.call(key))
		t.price_color = Color(0.42, 0.86, 0.46)   # what YOU get paid reads green
	t.draggable = false
	if on_inspect_material.is_valid():
		t.on_inspect = on_inspect_material
	if on_material.is_valid():
		t.on_interact = func(k: String, s: String) -> void:
			on_material.call(k, s)
			changed.emit()
	return t


func _item_tile(comp: ComponentDef) -> ItemTile:
	var t := ItemTile.new(comp, source, ItemTile.Style.SHOP)
	if item_hint.is_valid():
		t.hint = str(item_hint.call(comp))
	if item_price.is_valid():
		t.price = int(item_price.call(comp))
		t.price_color = Color(0.42, 0.86, 0.46)
	if on_inspect_item.is_valid():
		t.on_inspect = on_inspect_item
	if on_item.is_valid():
		t.on_interact = func(c: ComponentDef, s: String) -> void:
			on_item.call(c, s)
			changed.emit()
	return t
