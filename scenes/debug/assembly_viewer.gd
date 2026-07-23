extends Node2D
## Debug assembly viewer: renders a hull's hardpoint layout with firing arcs,
## the fitted components, aggregate stats, and fit validation.
## Keys: 1/2/3 switch sample builds, F1 returns to the flight test.

const DRAW_CENTER := Vector2(420, 390)
const DRAW_SCALE := 7.0
const ARC_RADIUS := 64.0

const TYPE_COLORS := {
	HardpointDef.SlotType.WEAPON: Color(0.95, 0.55, 0.25),
	HardpointDef.SlotType.ENGINE: Color(0.35, 0.80, 0.90),
	HardpointDef.SlotType.REACTOR: Color(0.95, 0.85, 0.35),
	HardpointDef.SlotType.DEFENSE: Color(0.45, 0.60, 0.95),
	HardpointDef.SlotType.SYSTEM: Color(0.45, 0.90, 0.55),
}

var builds: Array[ShipBuild] = []
var current := 0

@onready var panel: RichTextLabel = $UI/Panel


func _ready() -> void:
	for i in SampleBuilds.count():
		builds.append(SampleBuilds.get_build(i))
	current = SampleBuilds.current
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				# Viewer selection is local — boarding a ship you don't own
				# happens in the Hangar, not a debug screen.
				if event.keycode - KEY_1 < builds.size():
					current = event.keycode - KEY_1
					_refresh()
			KEY_F1:
				get_tree().change_scene_to_file("res://scenes/flight/flight_test.tscn")


func _refresh() -> void:
	panel.text = _describe(builds[current])
	queue_redraw()


func _draw() -> void:
	var build := builds[current]
	var hull := build.hull

	var points := PackedVector2Array()
	for p in hull.silhouette:
		points.append(DRAW_CENTER + p * DRAW_SCALE)
	if points.size() >= 3:
		draw_colored_polygon(points, Color(0.28, 0.31, 0.38))
		points.append(points[0])
		draw_polyline(points, Color(0.55, 0.60, 0.70), 2.0)

	var font := ThemeDB.fallback_font
	for i in hull.hardpoints.size():
		var hp := hull.hardpoints[i]
		var pos := DRAW_CENTER + hp.offset * DRAW_SCALE
		var color: Color = TYPE_COLORS[hp.slot_type]

		if hp.slot_type == HardpointDef.SlotType.WEAPON:
			var facing := deg_to_rad(hp.facing_deg)
			var half := deg_to_rad(hp.arc_deg) * 0.5
			var faded := Color(color, 0.35)
			draw_line(pos, pos + Vector2.RIGHT.rotated(facing - half) * ARC_RADIUS, faded, 1.5)
			draw_line(pos, pos + Vector2.RIGHT.rotated(facing + half) * ARC_RADIUS, faded, 1.5)
			draw_arc(pos, ARC_RADIUS, facing - half, facing + half, 24, faded, 1.5)

		var filled := build.component_at(i) != null
		draw_circle(pos, 9.0, Color(color, 0.9) if filled else Color(color, 0.25))
		draw_circle(pos, 9.0, color, false, 1.5)  # ring
		draw_string(font, pos + Vector2(-4, 5), str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK if filled else color)


func _describe(build: ShipBuild) -> String:
	var hull := build.hull
	var out := "[b]%s[/b]  —  %s, %s\n%s\n\n" % [
		hull.display_name, hull.category,
		HullDef.SizeBand.keys()[hull.size_band].capitalize(),
		hull.trait_description]

	for i in hull.hardpoints.size():
		var hp := hull.hardpoints[i]
		var type_name: String = HardpointDef.SlotType.keys()[hp.slot_type].capitalize()
		var arc := "  %d°" % hp.arc_deg if hp.slot_type == HardpointDef.SlotType.WEAPON else ""
		out += "[%d] %s  (%s Mk %d%s)\n" % [i + 1, hp.display_name, type_name, hp.mark, arc]
		var comp := build.component_at(i)
		if comp == null:
			out += "      [color=#666677]— empty —[/color]\n"
		else:
			out += "      [color=#%s]%s[/color]  Mk %d %s\n" % [
				Grades.color(comp.grade).to_html(false), comp.display_name,
				comp.mark, Grades.display_name(comp.grade)]

	var s := ShipStats.aggregate(build)
	out += "\n[b]Stats[/b]\n"
	out += "mass %.0f   thrust %.0f   accel %.1f\n" % [s.mass, s.thrust, s.accel]
	out += "power %.0f / %.0f  (margin %.0f)\n" % [s.power_draw, s.power_output, s.power_margin]
	out += "dps %.1f   shield %.0f (+%.1f/s)   armor %.0f\n" % [s.dps, s.shield_hp, s.shield_regen, s.armor_hp]
	out += "cargo %.0f   sensors %.0f\n" % [s.cargo, s.sensor_range]

	var errors := ShipStats.validate(build)
	if errors.is_empty():
		out += "\n[color=#55cc66]FIT VALID[/color]"
	else:
		out += "\n[color=#ee5544]FIT ERRORS[/color]\n"
		for e in errors:
			out += "[color=#ee5544] - %s[/color]\n" % e
	out += "\n\n[color=#666677]1/2/3 switch hull (also swaps the flown ship)   F1 flight test[/color]"
	return out
