class_name MaterialStackTile
extends Button
## A STACK OF A COMMODITY, drawn as a cargo tile with a ×N badge — ore, food, scan data.
##
## The material counterpart to [ItemTile], extracted from DockScreen for the same reason
## (see that file): the ground's hold/shop grids need to draw materials too, and a second
## copy would drift. Materials have no grade, so they wear their own colour/glyph from
## ItemVisuals rather than a grade border.
##
## Same gesture contract as [ItemTile]: RIGHT-CLICK IS "INTERACT" and the host decides what
## that means here (sell / jettison / stash); left-click only ever inspects.
##     var t := MaterialStackTile.new("aurite_ore", 6, "hold")
##     t.on_interact     = func(key, src): ...   # right-click — THE verb
##     t.on_alt_interact = func(key, src): ...   # shift+right-click: hold <-> stash

var key: String
var qty: int
var source: String                 # "hold" | "stash" | "shop"

var on_inspect: Callable            # func(key)          left-click  — inspect only
var on_interact: Callable           # func(key, source)  right-click — THE verb
var on_alt_interact: Callable       # func(key, source)  shift+right-click

## Extra tooltip line the host wants ("right-click to sell (60c)").
var hint := ""
var draggable := true
## Shown as a price badge when >= 0 — a shop shelf quotes, a plain hold doesn't.
var price := -1
var price_color := Color(0.95, 0.72, 0.35)
## Hide the ×N badge (a shop shelf sells by the unit; it has no stack).
var show_qty := true


func _init(p_key: String, p_qty: int, p_source: String) -> void:
	key = p_key
	qty = p_qty
	source = p_source


func _ready() -> void:
	custom_minimum_size = Vector2(52, 52)
	var tex := ItemVisuals.material_icon(key)
	if tex != null:
		icon = tex
		expand_icon = true
		icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		text = ItemVisuals.material_glyph(key)
		add_theme_font_size_override("font_size", 15)
		add_theme_color_override("font_color", ItemVisuals.material_color(key))
	if source == "stash":
		modulate = Color(1, 1, 1, 0.68)   # stash rides dimmer than the hold
	tooltip_text = "%s ×%d\nmaterial   mass %.0f ea   [%s]%s" % [
		TradeGoods.display_name(key), qty, TradeGoods.unit_mass(key), source,
		("\n" + hint) if hint != "" else ""]

	if show_qty:
		var badge := Label.new()
		badge.text = "×%d" % qty
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_color", Color(0.96, 0.96, 0.99))
		badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		badge.add_theme_constant_override("outline_size", 4)
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT if price >= 0
			else Control.PRESET_BOTTOM_RIGHT)
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		badge.grow_vertical = Control.GROW_DIRECTION_END if price >= 0 \
			else Control.GROW_DIRECTION_BEGIN
		badge.offset_right = -3
		badge.offset_bottom = -1
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(badge)

	# Price rides along the bottom, exactly where ItemTile puts it, so a shelf reads the
	# same whether it's stocked with gear or with grain.
	if price >= 0:
		var pb := Label.new()
		pb.text = "%dc" % price
		pb.add_theme_font_size_override("font_size", 10)
		pb.add_theme_color_override("font_color", price_color)
		pb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		pb.add_theme_constant_override("outline_size", 3)
		pb.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		pb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pb.grow_vertical = Control.GROW_DIRECTION_BEGIN
		pb.offset_bottom = -1
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pb)

	pressed.connect(func() -> void:
		if on_inspect.is_valid():
			on_inspect.call(key))


func _get_drag_data(_at: Vector2) -> Variant:
	if not draggable:
		return null
	var preview := Label.new()
	preview.text = "%s ×%d" % [TradeGoods.display_name(key), qty]
	preview.add_theme_color_override("font_color", ItemVisuals.material_color(key))
	set_drag_preview(preview)
	return {"material": key, "source": source}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		if event.shift_pressed:
			if on_alt_interact.is_valid():
				on_alt_interact.call(key, source)
		elif on_interact.is_valid():
			on_interact.call(key, source)
