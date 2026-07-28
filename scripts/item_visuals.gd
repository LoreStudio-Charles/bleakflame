class_name ItemVisuals
## HOW AN ITEM LOOKS — the game's shared visual vocabulary for equipment and materials:
## icons, grade colouring, pips, prices, and the tooltip bodies.
##
## WHY THIS EXISTS (2026-07-25): all of this lived as instance methods on DockScreen, so
## the tile widgets took a `screen: DockScreen` just to ask "what icon does this have?"
## — which meant NOTHING outside the station dock could draw a piece of gear. The ground
## needs the same tiles (its shops and inventory are grids of items), and a second
## hand-rolled copy would drift on the details that matter most: a grade border that
## doesn't match, pips that don't pair with colour (the colourblind-safety rule).
##
## Every function here is PURE and static — no instance state, no Control ownership, no
## host. They were only ever methods by accident. Callers: the dock's tiles, the ground's
## shop/inventory grids, and anything else that shows an item.
##
## Drop-in art is resolved here too (assets/icons/components/<tres-basename>.png and
## assets/icons/materials/<key>.png), so new art needs no code anywhere.

## Shop markup over an item's intrinsic value.
const BUY_MULT := 2.0

## Grade tile background alpha (normal / hover), so every item tile breathes alike.
const TILE_BG_A := 0.14
const TILE_BG_HI_A := 0.30


## ---- ICONS ----

## Drop-in component icon: assets/icons/components/<tres-basename>.png, resolved from the
## item's base_path (an affixed drop) or resource_path (clean shop gear), so a rolled
## "Sharpened VK-2 Autocannon" shares the base VK-2 icon. Ability-bearing gear falls back
## to the face of the ability it grants — without that the whole chip family rendered as
## grey "S1" text tiles in the Armory, the hold, the stash and the Coupling.
static func component_icon(comp: ComponentDef) -> Texture2D:
	if comp.overlay_sprite != null:
		return comp.overlay_sprite
	for src in [comp.base_path, comp.resource_path]:
		if str(src) != "":
			var p := "res://assets/icons/components/%s.png" % str(src).get_file().get_basename()
			if ResourceLoader.exists(p):
				return load(p)
	# `get()` returns null on a component with no `tags` at all (most of them), so this
	# must be nil-checked before it is iterated.
	var tags = comp.get("tags")
	if tags != null:
		for tag in tags:
			var aid := Abilities.id_for_tag(str(tag))
			if aid != "":
				var at := Abilities.icon(aid)
				if at != null:
					return at
	return null


static func material_icon(key: String) -> Texture2D:
	var p := "res://assets/icons/materials/%s.png" % key
	return load(p) if ResourceLoader.exists(p) else null


## Two-letter stand-in when a material has no art — periodic-table flavoured.
static func material_glyph(key: String) -> String:
	match key:
		"ferrite_ore": return "Fe"
		"cobalt_ore": return "Co"
		"aurite_ore": return "Au"
		"scan_data": return "Sc"
		"cinder_fragment": return "Cf"
		"wayfinder_core": return "Wf"
		"circuits": return "Ci"
		"food": return "Fd"
		"water": return "Wa"
		"stolen_goods": return "Sg"
	return TradeGoods.display_name(key).left(2)


static func material_color(key: String) -> Color:
	if key == "aurite_ore":
		return Color(0.95, 0.78, 0.42)
	if key.ends_with("_ore"):
		return Color(0.78, 0.74, 0.62)
	if key == "scan_data":
		return Color(0.5, 0.82, 0.95)
	if key == "cinder_fragment" or key == "wayfinder_core":
		return Color(0.78, 0.55, 0.95)
	return Color(0.85, 0.8, 0.68)


## ---- PRICES ----

static func buy_price(comp: ComponentDef) -> int:
	return int(comp.value() * BUY_MULT)


static func sell_price(comp: ComponentDef) -> int:
	return int(round(comp.value() * Pilot.sell_mult()))


## ---- GRADE DRESS ----
##
## Quality at a glance. COLOUR ALWAYS PAIRS WITH PIPS (the colourblind-safety rule from
## the grades convention) — which is exactly why this is one function instead of a
## pattern each tile re-implements and one of them forgets.

## Apply a grade-coloured border + tinted background to any Button-ish control.
## TAKES A GRADE, NOT A COMPONENT (2026-07-28): a HULL is graded gear too, and it is
## not a ComponentDef — so keying this off the item type would have forced the
## shipyard to hand-roll a second copy of the border, which is precisely the drift
## this file exists to prevent (see the header).
static func dress_grade(ctrl: Control, grade: int) -> void:
	var gc := Grades.color(grade)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(gc.r, gc.g, gc.b, TILE_BG_A)
	sb.border_color = gc
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	ctrl.add_theme_stylebox_override("normal", sb)
	var sb_hi: StyleBoxFlat = sb.duplicate()
	sb_hi.bg_color = Color(gc.r, gc.g, gc.b, TILE_BG_HI_A)
	ctrl.add_theme_stylebox_override("hover", sb_hi)
	ctrl.add_theme_stylebox_override("pressed", sb_hi)


## The rarity pips. `preset`/alignment let a small hold tile put them along the bottom
## and a big shop tile put them top-right, without duplicating the styling.
static func pips_label(grade: int, font_size: int, preset: int,
		align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var pips: int = Grades.INFO[grade]["pips"]
	if pips <= 0:
		return null
	var pl := Label.new()
	pl.text = "•".repeat(pips)
	pl.add_theme_font_size_override("font_size", font_size)
	pl.add_theme_color_override("font_color", Grades.color(grade))
	pl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	pl.add_theme_constant_override("outline_size", 3)
	pl.set_anchors_preset(preset)
	pl.horizontal_alignment = align
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pl


## A HULL'S FACE IS ITS OWN SPRITE — no separate icon set (user, 2026-07-28: "do we
## need art to do the Shipyard if we are using the existing hull for the art?"). All
## 13 shipped hulls already have one, resolved exactly as the flight scene resolves
## it: `art_path` first (the faction-folder convention), else the snake-cased name.
##
## THREE REASONS this beats drawing icons, even with art budget to spend: one
## pipeline, so a shop can never show a ship you don't fly; the tile inherits the
## QUALITY PAINT LADDER for free once those decals land (docs/quality_paint.md),
## where an icon set would need re-painting 7x per hull; and a hull with no PNG still
## has `HullDef.silhouette` to fall back on, so it is never a blank square.
static func hull_icon(hull: HullDef) -> Texture2D:
	var path: String = hull.art_path if hull.art_path != "" \
		else "res://assets/ships/%s.png" % hull.display_name.to_snake_case()
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## The fallback face when a component has no icon: slot letter + mark ("W2").
static func component_glyph(comp: ComponentDef) -> String:
	return "%s%d" % [HardpointDef.SlotType.keys()[comp.slot_type()][0], comp.mark]


## ---- TOOLTIP BODIES ----

## What the part actually DOES — stat summary + flavour.
static func effect_lines(comp: ComponentDef) -> String:
	var out := ""
	var stats := comp.stat_summary()
	if stats != "":
		out += "[color=#8fe08f]%s[/color]\n" % stats
	if comp.description != "":
		out += "[i][color=#a8b0c2]%s[/color][/i]\n" % comp.description
	return out


## Lead line for gear that grants a special ability, so a hover reveals it first.
static func ability_line(comp: ComponentDef) -> String:
	if comp is WeaponDef and (comp as WeaponDef).mining_power > 0.0:
		return "[b][color=#f2b859]⛏ MINING LASER[/color][/b][color=#8fe08f] — cuts ore from asteroids at full yield; ordinary guns only chip rock.[/color]"
	var ab := Abilities.granted_by(comp)
	if not ab.is_empty():
		return "[b][color=#f2b859]▸ GRANTS ABILITY — %s[/color][/b]\n[color=#8fe08f]%s[/color]\n[color=#73bff2]Fit it, then wire it to a [1]–[5] bus slot (Pilot tab).[/color]" % [
			str(ab.name), str(ab.desc)]
	return ""


## A BBCode tooltip whose NAME is grade-coloured (default Button tooltips are plain
## text). Tiles override _make_custom_tooltip to use it. Returns just the content —
## Godot already wraps a custom tooltip in the theme's TooltipPanel, so adding a panel
## here would double the border.
static func grade_tooltip(comp: ComponentDef, body: String) -> Control:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(250, 0)
	var gc := Grades.color(comp.grade).to_html(false)
	var nm := ("◆ " if not comp.affix_ids.is_empty() else "") + comp.display_name
	# Name on its own line, then grade + size on the SECOND line — so the rarity/Mk
	# phrase never wraps mid-word behind the name.
	#
	# LEVEL RIDES THE SAME LINE as grade and mark, because the three are one thought:
	# quality, size, and what it takes to use. It is a REQUIREMENT TO EQUIP, so it
	# says so — and when the pilot cannot meet it, it turns DANGER RED and states
	# the shortfall outright. A requirement the player can't see is a rejection they
	# can only discover by being refused.
	rt.text = "[b][color=#%s]%s[/color][/b]\n[color=#%s]%s Mk %d[/color]   %s\n%s" % [
		gc, nm, gc, Grades.display_name(comp.grade), comp.mark, level_line(comp), body]
	return rt


## "Requires level N", coloured by whether this pilot actually meets it.
## Shared so the hover, the details panel and the paperdoll can never disagree
## about what a part demands.
static func level_line(comp: ComponentDef) -> String:
	var need := int(comp.level)
	if need <= Pilot.level():
		return "[color=#8890a0]Requires level %d[/color]" % need
	return "[color=#f25a50]Requires level %d — you are %d[/color]" % [need, Pilot.level()]


## The ability equivalent of grade_tooltip: icon + name, then the body from
## Abilities.tooltip_body. Same visual weight as an equipment hover, because an ability
## IS equipment now — it lives on a chip in the Coupling.
static func ability_tooltip(aid: String, body: String) -> Control:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(260, 0)
	var art := "res://assets/icons/abilities/%s.png" % aid
	var img := "[img=28]%s[/img]  " % art if ResourceLoader.exists(art) else ""
	rt.text = "%s[b][color=#f2b859]%s[/color][/b]\n%s" % [
		img, Abilities.display_name(aid), body]
	return rt
