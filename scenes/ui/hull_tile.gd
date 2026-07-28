class_name HullTile
extends Button
## ONE HULL, drawn as a tile — the Shipyard's square, sibling to ItemTile.
##
## A HULL IS GRADED GEAR (CLAUDE.md: HullDef carries `grade` and `level` like anything
## else you buy), so it wears the SAME quality vocabulary as every other shop tile:
## grade-coloured border, pips, price badge. That vocabulary lives in ItemVisuals and
## is shared, not re-implemented — `dress_grade` and `pips_label` were generalised off
## ComponentDef onto a plain grade for exactly this, because a hull is not a
## ComponentDef and a hand-rolled second border is how two shops start disagreeing
## about what blue means.
##
## THE FACE IS THE SHIP'S OWN SPRITE. No icon set to draw or keep in sync, and when the
## quality paint decals land (docs/quality_paint.md) this tile shows the painted hull
## for free. A hull with no PNG falls back to its `silhouette` polygon, so it is never
## a blank square.
##
## Gestures follow the one-verb rule (ItemTile's header): LEFT-CLICK inspects, RIGHT-
## CLICK is THE verb and the host decides what it means (here: buy, or board what you
## already own).

## WIDE, because ships are long where components are chunky — and TALL ENOUGH FOR ITS
## OWN FOOTER. At 96 the price badge sat on top of the name plate (both anchored to the
## bottom), which on the Cutlass rendered "Cutlass" and "3800c" as one smear. The extra
## 16px is a footer strip: name on the last line, price on the line above it.
const TILE := Vector2(132, 112)

var build: ShipBuild
var index: int                      # SampleBuilds index — what the host acts on
var owned := false
var price := -1

var on_inspect: Callable            # func(index)
var on_interact: Callable           # func(index)  right-click — buy / board

var _tip_body := ""


func _init(p_build: ShipBuild, p_index: int) -> void:
	build = p_build
	index = p_index


func _ready() -> void:
	custom_minimum_size = TILE
	var tex := ItemVisuals.hull_icon(build.hull)
	if tex != null:
		icon = tex
		expand_icon = true
		icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		# No sprite: the hull's own outline, drawn small. Better than a letter — the
		# silhouette is what the player recognises in flight.
		add_child(SilhouetteFace.new(build.hull))
	ItemVisuals.dress_grade(self, build.hull.grade)

	_add(ItemVisuals.pips_label(build.hull.grade, 15, Control.PRESET_TOP_RIGHT,
		HORIZONTAL_ALIGNMENT_RIGHT), func(l: Label) -> void:
			l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			l.offset_right = -3
			l.offset_top = 0)
	_name_plate()
	_corner("L%d" % int(build.hull.level), Control.PRESET_TOP_LEFT,
		Color(0.62, 0.66, 0.75), HORIZONTAL_ALIGNMENT_LEFT)
	if owned:
		_corner("OWNED", Control.PRESET_BOTTOM_RIGHT, Color(0.45, 0.82, 0.55),
			HORIZONTAL_ALIGNMENT_RIGHT)
	elif price >= 0:
		_corner("%dc" % price, Control.PRESET_BOTTOM_RIGHT,
			Color(0.95, 0.72, 0.35) if Wallet.credits >= price else Color(0.85, 0.4, 0.36),
			HORIZONTAL_ALIGNMENT_RIGHT)
	# CANNOT AFFORD READS AS OUT OF REACH — same treatment ItemTile gives gear you
	# cannot equip: still for sale, still inspectable, visibly not yours yet.
	if not owned and price >= 0 and Wallet.credits < price:
		modulate *= Color(1, 1, 1, 0.72)


func _gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton or not (event as InputEventMouseButton).pressed:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and on_inspect.is_valid():
		on_inspect.call(index)
	elif mb.button_index == MOUSE_BUTTON_RIGHT and on_interact.is_valid():
		on_interact.call(index)
		accept_event()


func _make_custom_tooltip(_for_text: String) -> Object:
	return DockScreen.hull_tooltip(build)


## The name along the bottom. A hull is bought by NAME as much as by silhouette —
## "the Dowager" is a thing a player says — so unlike a component tile this one
## always spells it out rather than relying on the hover.
func _name_plate() -> void:
	var lbl := Label.new()
	lbl.text = build.hull.display_name
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Grades.color(build.hull.grade))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lbl.offset_bottom = -2
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)


func _corner(text: String, preset: int, col: Color, align: int) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.set_anchors_preset(preset)
	lbl.horizontal_alignment = align
	if preset == Control.PRESET_BOTTOM_RIGHT:
		lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
		lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		lbl.offset_bottom = -17      # the line above the name plate
		lbl.offset_right = -3
	elif preset == Control.PRESET_TOP_LEFT:
		lbl.offset_left = 3
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)


func _add(lbl: Label, tweak: Callable) -> void:
	if lbl == null:
		return
	tweak.call(lbl)
	add_child(lbl)


## The hull's outline, for a ship with no sprite yet. Same polygon the flight scene
## draws as its placeholder, scaled to the tile.
class SilhouetteFace:
	extends Control

	var hull: HullDef

	func _init(p_hull: HullDef) -> void:
		hull = p_hull
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var pts: PackedVector2Array = hull.silhouette
		if pts.size() < 3:
			return
		var lo := pts[0]
		var hi := pts[0]
		for p in pts:
			lo = lo.min(p)
			hi = hi.max(p)
		var span := (hi - lo).max(Vector2.ONE)
		var scale := minf(size.x * 0.7 / span.x, size.y * 0.7 / span.y)
		var out := PackedVector2Array()
		for p in pts:
			out.append((p - (lo + hi) * 0.5) * scale + size * 0.5)
		draw_colored_polygon(out, Color(0.62, 0.66, 0.75, 0.55))
