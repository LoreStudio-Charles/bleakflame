class_name ContextGrid
extends ContextBase
## THE GRID PRESENTATION of a context — for things that are OBJECTS: equipment, hulls,
## commodities. You look at them, compare them at a glance, and buy them.
##
## "I think all shops should take the grid of icons with tooltips shape" (user,
## 2026-07-27). The Armory arrived at that shape on its own, before the shape had a name;
## this is that shape made portable, so a shop is no longer something only a tab can host.
##
## WHAT IT TOOK TO GET HERE. The list half of the split (ContextScreen) was extracted
## from two screens once both existed; the grid half stayed welded inside dock_screen.gd
## and was the last thing keeping three tabs — Shipyard, Armory, Market — from being
## openable anywhere else. A context that only a tab can mount is a context that cannot
## follow a person into a room.
##
## COLUMNS ARE DERIVED FROM THE SHELF'S ACTUAL WIDTH, never hardcoded. A fixed count
## leaves a third of the shelf empty at one window size and clips at the next, and it is
## wrong again the moment a tile's size changes — which has already happened once.

const GAP := 8
const RING := "SelectionRing"

var grid: GridContainer
var _tile_w := 128.0
var _scroll: ScrollContainer
var _by_id := {}                   ## stable id -> metadata, for selection across refreshes
var _nodes := {}                   ## stable id -> the tile drawing it


func _init(tile_width := 128.0) -> void:
	# EXPLICIT: declaring _init here suppresses the base's, so the shell (header, detail
	# panel, mode row) is never built and every widget call lands on null.
	super()
	_tile_w = tile_width
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(300, 200)
	left.add_child(_scroll)
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(grid)
	_scroll.resized.connect(func() -> void: fit_columns(_scroll.size.x))
	fit_columns(_scroll.size.x)


## How many tiles fit across `width`, floored at one so a narrow window still draws a
## shelf rather than dividing by zero into nothing.
func fit_columns(width: float) -> void:
	if grid == null:
		return
	grid.columns = maxi(1, int(floor((width + float(GAP)) / (_tile_w + float(GAP)))))


func _clear_items() -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	_by_id.clear()
	_nodes.clear()


## PUT A TILE ON THE SHELF. The tile is the SCREEN'S — an ItemTile, a HullTile, whatever
## that shop's goods look like — so a part reads identically here and everywhere else it
## is shown. This owns only what every shelf needs: a stable id for the selection, the
## metadata the detail panel will read, and left-click-inspects.
##
## `id` must be STABLE across refreshes, or buying one thing loses your place on the
## shelf. `on_verb` is the RIGHT-CLICK — buy, sell, fit — the idiom the Armory
## established and every grid keeps.
func tile(node: Control, id: String, kind: String, data := {},
		on_verb := Callable()) -> void:
	var md := {"id": id, "kind": kind}
	for k in data:
		md[k] = data[k]
	_by_id[id] = md
	_nodes[id] = node
	node.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb == null or not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			select(id)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and on_verb.is_valid():
			select(id)
			on_verb.call())
	grid.add_child(node)


## An empty shelf still has to say so. A blank column reads as a screen that failed to
## draw, which is exactly what a shop with nothing in stock is not.
func empty_note(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", UiTheme.DIM)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grid.add_child(lbl)


func select(id: String) -> void:
	if _sel == id:
		return
	_sel = id
	Sfx.play("click", -18.0, 1.1)
	_paint_selection()
	_rebuild_detail()


func _restore_selection() -> void:
	if not _by_id.has(_sel):
		# What you were looking at is gone — bought, sold, or hidden by a filter. Open on
		# the first thing on the shelf rather than leaving the panel blank beside a full
		# one. Dictionaries keep insertion order in GDScript, so this is the top-left tile.
		_sel = ""
		for id in _by_id:
			_sel = str(id)
			break
	# PAINTED AFTER THE SELECTION IS RESOLVED, never during tile(). The restore runs after
	# fill_list, so a ring drawn while filling is a ring drawn against the PREVIOUS
	# selection — right by luck whenever it survived the refresh, and invisible on the
	# first draw of any shelf, when there is nothing selected yet to be right about.
	_paint_selection()


## The selected tile wears a ring, because a grid has no row highlight of its own — and
## a detail panel describing something the player cannot see they picked is the same
## defect as an action floating free of its object.
func _paint_selection() -> void:
	for id in _nodes:
		var node: Control = _nodes[id]
		if not is_instance_valid(node):
			continue
		var ring := node.get_node_or_null(RING)
		if str(id) == _sel and ring == null:
			node.add_child(_ring())
		elif str(id) != _sel and ring != null:
			node.remove_child(ring)
			ring.queue_free()


func _ring() -> Panel:
	var ring := Panel.new()
	ring.name = RING
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = UiTheme.AMBER
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	ring.add_theme_stylebox_override("panel", box)
	return ring


func selected_meta() -> Dictionary:
	return _by_id.get(_sel, {})
