class_name UiTheme
## Code-built Theme shared by all Bleakflame UI. One palette, one place:
## deep space navy, cyan accent (information), amber accent (money/warning).
## The dock screens pick this up wholesale via Control.theme propagation;
## pixel-art trim comes from the bleakflame_panel nine-patch overlay.

const BG := Color(0.055, 0.065, 0.095)
const PANEL := Color(0.08, 0.095, 0.13)
const ACCENT := Color(0.45, 0.75, 0.95)
const AMBER := Color(0.95, 0.72, 0.35)
const TEXT := Color(0.82, 0.86, 0.95)
const DIM := Color(0.5, 0.55, 0.66)
const DANGER := Color(0.95, 0.4, 0.35)

const FRAME_ART := "res://assets/ui/bleakflame_panel.png"
## Instrument bezels cropped from the dashboard art itself — widgets sit in
## housings made of the same material as the console around them.
const BEZEL_ART := "res://assets/ui/bezel.png"
const BEZEL_ACTIVE_ART := "res://assets/ui/bezel_active.png"

static var _theme: Theme
static var _bezels := {}


## Small instrument housing (glass center drawn). active = cyan-rimmed.
static func bezel(active := false) -> StyleBoxTexture:
	return _bezel_box("c" + str(active), active, true)


## Border-only variant for large rects — stretching the glass sheen across
## a wide panel smears; draw your own flat fill underneath instead.
static func bezel_frame(active := false) -> StyleBoxTexture:
	return _bezel_box("f" + str(active), active, false)


static func _bezel_box(key: String, active: bool, center: bool) -> StyleBoxTexture:
	if _bezels.has(key):
		return _bezels[key]
	var path := BEZEL_ACTIVE_ART if active else BEZEL_ART
	if not ResourceLoader.exists(path):
		return null
	var box := StyleBoxTexture.new()
	box.texture = load(path)
	box.set_texture_margin_all(6)
	box.draw_center = center
	_bezels[key] = box
	return box


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 13

	t.set_stylebox("normal", "Button", _box(Color(0.11, 0.13, 0.19), Color(0.3, 0.36, 0.48)))
	t.set_stylebox("hover", "Button", _box(Color(0.14, 0.17, 0.24), ACCENT))
	t.set_stylebox("pressed", "Button", _box(Color(0.09, 0.1, 0.15), AMBER))
	t.set_stylebox("disabled", "Button", _box(Color(0.09, 0.1, 0.13), Color(0.2, 0.22, 0.28)))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(0.95, 0.98, 1.0))
	t.set_color("font_pressed_color", "Button", AMBER)
	t.set_color("font_disabled_color", "Button", DIM)

	t.set_stylebox("panel", "ItemList", _box(BG, Color(0.22, 0.26, 0.36)))
	t.set_stylebox("selected", "ItemList", _flat(Color(0.16, 0.28, 0.4)))
	t.set_stylebox("selected_focus", "ItemList", _flat(Color(0.19, 0.33, 0.47)))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", Color(0.96, 0.99, 1.0))
	t.set_color("guide_color", "ItemList", Color(0.16, 0.19, 0.27))

	t.set_stylebox("panel", "TabContainer", _box(PANEL, Color(0.26, 0.3, 0.42)))
	t.set_stylebox("tab_selected", "TabContainer", _tab(Color(0.13, 0.17, 0.25), ACCENT))
	t.set_stylebox("tab_unselected", "TabContainer", _tab(Color(0.075, 0.085, 0.12), Color(0.18, 0.21, 0.3)))
	t.set_stylebox("tab_hovered", "TabContainer", _tab(Color(0.1, 0.13, 0.19), Color(0.32, 0.42, 0.58)))
	t.set_color("font_selected_color", "TabContainer", ACCENT)
	t.set_color("font_unselected_color", "TabContainer", DIM)
	t.set_color("font_hovered_color", "TabContainer", TEXT)

	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)

	# Tooltips: solid opaque card, or the text drowns in whatever it hovers
	# over (the holographic paperdoll made this vivid).
	var tip := _box(Color(0.05, 0.06, 0.09, 0.98), Color(0.32, 0.5, 0.66))
	tip.content_margin_top = 6.0
	tip.content_margin_bottom = 6.0
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)

	_theme = t
	return t


## Pixel-art trim overlaid on a panel region. Pure decoration: ignores mouse.
static func add_frame(parent: Node, left: float, top: float,
		right: float, bottom: float) -> void:
	if not ResourceLoader.exists(FRAME_ART):
		return
	var frame := NinePatchRect.new()
	frame.texture = load(FRAME_ART)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = left
	frame.offset_top = top
	frame.offset_right = right
	frame.offset_bottom = bottom
	# Margins pushed way out: ALL the plate detail lives in the four corners
	# (drawn 1:1, never repeated or stretched); only the plain mid-rail strip
	# stretches, which is invisible. Tiling repeated the plates (clutter);
	# stretching small margins smeared them — big corners is the answer.
	frame.patch_margin_left = 100
	frame.patch_margin_top = 100
	frame.patch_margin_right = 100
	frame.patch_margin_bottom = 100
	frame.draw_center = false
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)


## Button flavor system (user spec 2026-07-20). Three roles, consistent
## width, so choice weight reads at a glance:
##   PRIMARY   (gold)  — THE action: Understood / Accept / Confirm.
##   SECONDARY (green) — a meaningful but non-committal choice: investigate,
##                       ask, learn a clue. NEVER sets a flag or locks a
##                       branch (the caller enforces that; the color signals
##                       it). This is the default for dialogue options.
##   TERTIARY  (cyan)  — the minor / back-out choice: Leave / Cancel / Back.
const BTN_PRIMARY := AMBER
const BTN_SECONDARY := Color(0.55, 0.82, 0.62)
const BTN_TERTIARY := ACCENT
const BTN_WIDTH := 168.0


static func button_flavor(b: Button, flavor := "secondary", min_width := BTN_WIDTH) -> void:
	var col := _flavor_color(flavor)
	b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, min_width)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", Color(0.97, 0.99, 1.0))
	b.add_theme_color_override("font_pressed_color", col)
	# Primary carries a faint filled tint so it visibly leads; the others are
	# outline-only, dimmer border at rest, full color on hover.
	var rest_bg := Color(0.16, 0.14, 0.09) if flavor == "primary" else Color(0.1, 0.12, 0.17)
	b.add_theme_stylebox_override("normal", _box(rest_bg, col.darkened(0.35)))
	b.add_theme_stylebox_override("hover", _box(Color(0.14, 0.18, 0.25), col))
	b.add_theme_stylebox_override("pressed", _box(Color(0.09, 0.1, 0.15), col))


static func _flavor_color(flavor: String) -> Color:
	match flavor:
		"primary":
			return BTN_PRIMARY
		"tertiary":
			return BTN_TERTIARY
		_:
			return BTN_SECONDARY


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 10.0
	s.content_margin_right = 10.0
	s.content_margin_top = 5.0
	s.content_margin_bottom = 5.0
	return s


static func _flat(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(2)
	return s


## Tab: flat body, bright top edge on the active one (the underline flipped).
static func _tab(bg: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.border_width_top = 2
	s.content_margin_left = 12.0
	s.content_margin_right = 12.0
	s.content_margin_top = 4.0
	s.content_margin_bottom = 4.0
	return s
