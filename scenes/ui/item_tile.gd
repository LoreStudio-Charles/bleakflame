class_name ItemTile
extends Button
## ONE ITEM, drawn as a tile — the game's reusable inventory/shop square.
##
## WHY THIS EXISTS (2026-07-25): the tile widgets lived as nested classes inside
## DockScreen and each held a `screen: DockScreen`, so nothing outside the station dock
## could draw a piece of gear. The ground needs the very same tiles (its shop and
## inventory are grids of items), and a hand-rolled second copy would drift on exactly
## the details that matter — the grade border, and pips-always-with-colour.
##
## ONE GESTURE, CONTEXT DECIDES (user, 2026-07-25): **RIGHT-CLICK IS "INTERACT"** — the
## single verb, everywhere, on every screen. What it DOES comes from the context the tile
## sits in, which is the HOST, not the tile:
##     shop shelf -> buy      ·  your hold at a counter -> sell
##     salvage panel -> jettison  ·  Engineering hold -> fit it to the ship
## LEFT-CLICK always and only INSPECTS/SELECTS; it never changes anything, so no screen
## can destroy or spend by accident. SHIFT+RIGHT-CLICK is the one alternate (move between
## cargo and stash) where a place genuinely needs a second verb.
##
## DECOUPLED BY CALLABLES, not by a host type. A tile knows how to LOOK (via ItemVisuals)
## and which gestures exist; it does not know who it belongs to:
##     var t := ItemTile.new(comp, "shop", ItemTile.Style.SHOP)
##     t.on_inspect      = func(c): ...        # left-click  — inspect only
##     t.on_interact     = func(c, src): ...   # right-click — THE verb, host decides
##     t.on_alt_interact = func(c, src): ...   # shift+right-click — cargo <-> stash
## Unbound verbs are simply inert — a shop tile with no shift verb ignores shift.

## How big and how dressed. SHOP tiles are large with a mark badge and price; HOLD tiles
## are small (a dense bag grid). Same vocabulary either way.
enum Style {HOLD, SHOP}

const HOLD_SIZE := Vector2(52, 52)
const SHOP_SIZE := Vector2(66, 66)

var comp: ComponentDef
var source: String                 # "shop" | "hold" | "stash" — where this copy lives
var style: Style

## Host verbs. All optional; an unbound Callable is ignored.
var on_inspect: Callable            # func(comp)          left-click  — inspect only
var on_interact: Callable           # func(comp, source)  right-click — THE verb
var on_alt_interact: Callable       # func(comp, source)  shift+right-click

## Extra tooltip lines the host wants (e.g. "right-click to buy (120c)").
var hint := ""
## Shown as the price badge when >= 0 (SHOP style only).
var price := -1
var price_color := Color(0.95, 0.72, 0.35)

var _tip_body := ""


func _init(p_comp: ComponentDef, p_source: String, p_style: Style = Style.HOLD) -> void:
	comp = p_comp
	source = p_source
	style = p_style


func _ready() -> void:
	custom_minimum_size = SHOP_SIZE if style == Style.SHOP else HOLD_SIZE
	var tex := ItemVisuals.component_icon(comp)
	if tex != null:
		icon = tex
		expand_icon = true
		icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		# No art: slot letter + mark. The ◆ marks an affixed (rolled) item.
		text = ("◆" if style == Style.HOLD and not comp.affix_ids.is_empty() else "") \
			+ ItemVisuals.component_glyph(comp)
		add_theme_font_size_override("font_size", 16 if style == Style.SHOP else 15)
		add_theme_color_override("font_color", Grades.color(comp.grade))
	ItemVisuals.dress_grade(self, comp)

	if style == Style.SHOP:
		_add_mark_badge()
		_add(ItemVisuals.pips_label(comp, 15, Control.PRESET_TOP_RIGHT,
			HORIZONTAL_ALIGNMENT_RIGHT), func(l: Label) -> void:
				l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
				l.offset_right = -3
				l.offset_top = 0)
		_add_level_badge()
		if price >= 0:
			_add_price_badge()
	else:
		_add(ItemVisuals.pips_label(comp, 9, Control.PRESET_BOTTOM_WIDE),
			func(l: Label) -> void:
				l.grow_vertical = Control.GROW_DIRECTION_BEGIN
				l.offset_bottom = -1)

	# Stash gear rides dimmer than hold gear — location at a glance.
	if source == "stash":
		modulate = Color(1, 1, 1, 0.68 if style == Style.HOLD else 0.7)

	# GEAR YOU CANNOT EQUIP YET READS AS OUT OF REACH. Level is a requirement now,
	# not a label, so the shelf should answer "can I use this?" before the pilot
	# clicks anything. Applied MULTIPLICATIVELY so it stacks with the stash dim
	# rather than overwriting it, and kept subtle — the item is still for sale and
	# still worth wanting, it is just not yours yet.
	if int(comp.level) > Pilot.level():
		modulate *= Color(0.72, 0.66, 0.66, 0.82)

	var ability := ItemVisuals.ability_line(comp)
	_tip_body = ((ability + "\n") if ability != "" else "") \
		+ ItemVisuals.effect_lines(comp) \
		+ "[color=#8890a0]value %dc   mass %.0f%s[/color]" % [
			comp.value(), comp.mass, "" if source == "shop" else "   [%s]" % source]
	if hint != "":
		_tip_body += "\n[color=#8890a0]%s[/color]" % hint
	tooltip_text = comp.display_name
	pressed.connect(func() -> void:
		if on_inspect.is_valid():
			on_inspect.call(comp))


func _add(node: Label, tweak: Callable) -> void:
	if node == null:
		return
	tweak.call(node)
	add_child(node)


## MARK / SIZE badge (top-left): a boxed roman numeral, so it's obvious every part —
## and every slot it fits — has a SIZE. Mk I–V.
func _add_mark_badge() -> void:
	var mb := Label.new()
	mb.text = ["", "I", "II", "III", "IV", "V"][clampi(comp.mark, 1, 5)]
	mb.add_theme_font_size_override("font_size", 12)
	mb.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))
	var mbox := StyleBoxFlat.new()
	mbox.bg_color = Color(0.07, 0.09, 0.13, 0.9)
	mbox.set_corner_radius_all(3)
	mbox.content_margin_left = 4
	mbox.content_margin_right = 4
	mbox.content_margin_top = 0
	mbox.content_margin_bottom = 0
	mb.add_theme_stylebox_override("normal", mbox)
	mb.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mb.offset_left = 2
	mb.offset_top = 2
	mb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mb)


## LEVEL badge (bottom-left): the minimum pilot level to EQUIP this part.
##
## Bottom-left because the other three corners are taken — mark top-left, pips
## top-right, price centred along the bottom. Turns DANGER RED when the pilot
## cannot meet it, which is the one thing worth seeing without hovering: a red
## number means "not yet", whatever else the tile says.
func _add_level_badge() -> void:
	var need := int(comp.level)
	var lb := Label.new()
	lb.text = "L%d" % need
	lb.add_theme_font_size_override("font_size", 10)
	lb.add_theme_color_override("font_color",
		Color(0.95, 0.35, 0.31) if need > Pilot.level() else Color(0.62, 0.68, 0.78))
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	lb.add_theme_constant_override("outline_size", 3)
	lb.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lb.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lb.offset_left = 3
	lb.offset_bottom = -1
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lb)


func _add_price_badge() -> void:
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


func _make_custom_tooltip(_for_text: String) -> Object:
	return ItemVisuals.grade_tooltip(comp, _tip_body)


func _get_drag_data(_at: Vector2) -> Variant:
	if source == "shop":
		return null            # you can't drag stock off a shelf
	var preview := Label.new()
	preview.text = comp.display_name
	preview.add_theme_color_override("font_color", Grades.color(comp.grade))
	set_drag_preview(preview)
	return {"comp": comp, "source": source}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		if event.shift_pressed:
			if on_alt_interact.is_valid():
				on_alt_interact.call(comp, source)
		elif on_interact.is_valid():
			on_interact.call(comp, source)
