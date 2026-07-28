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

var grid: GridContainer            ## the FIRST shelf — the only one most screens need
var _tile_w := 128.0
var _shelves: HBoxContainer
var _grids: Array[GridContainer] = []
var _notes := {}                   ## grid -> its "nothing here" label (never a tile)
var _by_id := {}                   ## stable id -> metadata, for selection across refreshes
var _nodes := {}                   ## stable id -> the tile drawing it


func _init(tile_width := 128.0) -> void:
	# EXPLICIT: declaring _init here suppresses the base's, so the shell (header, detail
	# panel, mode row) is never built and every widget call lands on null.
	super()
	_tile_w = tile_width
	# THE SHELF IS THE SCREEN. A grid's detail panel is somewhere to READ one thing
	# without holding the mouse still on its tooltip — it is not the main event, and at
	# the list default it took two thirds of a shop and left the goods crammed.
	detail_ratio(0.55)
	_shelves = HBoxContainer.new()
	_shelves.add_theme_constant_override("separation", 16)
	_shelves.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shelves.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_shelves)


## A PILE OF THINGS, with a heading. Most screens have one. The Armory has two — the
## shop's stock and your own gear — and that is NOT the Mission Computer's third column
## in disguise: that column was a DUPLICATE of the one beside it, with the action
## attached to the copy. These are the two ends of one transaction, and buying against
## selling is comparative ("can I sell this to afford that", "do I already own one of
## these"), so collapsing them behind a mode toggle would destroy the comparison the
## screen exists to support.
##
## THE SECOND SHELF IS TEMPORARY, THOUGH (user, 2026-07-28): "when we can walk the
## stations the armory can be only the buy screen and we could sell from the P > Ship
## paperdoll." That is this whole design taken to its end — a merchant's context is
## their STOCK; your own kit is yours, not something you visit a shop to look at. When
## it happens the Armory drops to one shelf, which is deleting a `shelf()` call.
##
## Every shelf shares ONE selection and ONE detail panel, which is what makes the action
## rule work across them: click anything in any pile and the panel offers the verb that
## belongs to where it came from.
func shelf(title := "", hint := "") -> GridContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shelves.add_child(col)
	if title != "":
		var head := Label.new()
		head.text = title
		head.add_theme_color_override("font_color", UiTheme.ACCENT)
		col.add_child(head)
	if hint != "":
		var sub := Label.new()
		sub.text = hint
		sub.add_theme_font_size_override("font_size", 11)
		sub.add_theme_color_override("font_color", UiTheme.DIM)
		col.add_child(sub)
	# THE EMPTY NOTE GOES ABOVE THE SHELF, not below it. The scroll takes the slack, so a
	# note added after it lands at the FOOT of the column — hundreds of pixels from the
	# heading it is explaining, which reads as a stray caption rather than the answer to
	# "why is this empty".
	var note_lbl := Label.new()
	note_lbl.add_theme_color_override("font_color", UiTheme.DIM)
	note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_lbl.visible = false
	col.add_child(note_lbl)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(260, 200)
	col.add_child(scroll)
	var g := GridContainer.new()
	g.add_theme_constant_override("h_separation", GAP)
	g.add_theme_constant_override("v_separation", GAP)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(g)
	scroll.resized.connect(func() -> void: fit_columns(scroll.size.x, g))
	fit_columns(scroll.size.x, g)
	# (The note above is NOT A TILE. Put inside the grid it lands in one tile-wide cell
	# and autowraps to a single character per line — a vertical stack of letters where a
	# sentence should be, which is how it first shipped.)
	_grids.append(g)
	_notes[g] = note_lbl
	if grid == null:
		grid = g
	return g


## How many tiles fit across `width`, floored at one so a narrow window still draws a
## shelf rather than dividing by zero into nothing.
func fit_columns(width: float, g: GridContainer = null) -> void:
	var target := g if g != null else grid
	if target == null:
		return
	target.columns = maxi(1, int(floor((width + float(GAP)) / (_tile_w + float(GAP)))))


func _clear_items() -> void:
	for g in _grids:
		for c in g.get_children():
			g.remove_child(c)
			c.queue_free()
		(_notes[g] as Label).visible = false
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
		on_verb := Callable(), into: GridContainer = null) -> void:
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
	(into if into != null else grid).add_child(node)


## An empty shelf still has to say so. A blank column reads as a screen that failed to
## draw, which is exactly what a shop with nothing in stock is not.
func empty_note(text: String, into: GridContainer = null) -> void:
	var lbl: Label = _notes.get(into if into != null else grid)
	if lbl == null:
		return
	lbl.text = text
	lbl.visible = true


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
