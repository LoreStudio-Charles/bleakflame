class_name TechniqueBar
extends Control
## The character's [1]-[5] BUS, drawn bottom-centre on foot, plus the cell gauge above it.
##
## The ground mirror of the ship's gem bar — same reading (a numbered slot, its face, a
## cooldown sweep, a ✕ when it can't fire), because it is the same gesture in a different
## body. Deliberately a separate widget from the flight HUD's bar: this one reads
## Pilot.techniques and a character's cell, and the two must be free to diverge.
##
## Purely a READOUT. It never decides whether a technique fires — the town's
## _use_technique owns that, so what you see and what happens cannot drift apart.

const SLOT := 46.0
const GAP := 8.0
const AMBER := Color(0.95, 0.78, 0.35)
const DIM := Color(0.55, 0.58, 0.66)

var walker: GroundCharacter          # whose cell + state we're reading
var cooldowns: Dictionary = {}       # technique id -> seconds left (the town's live dict)

var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if walker == null or not is_instance_valid(walker):
		return
	var n := Techniques.BUS_SLOTS
	var w := n * SLOT + (n - 1) * GAP
	var bounds := get_viewport_rect().size
	var x0 := (bounds.x - w) * 0.5
	var y := bounds.y - SLOT - 54.0

	# THE CELL — techniques spend it, so it sits directly over the keys that spend it.
	if walker.max_energy > 0.0:
		var frac: float = clampf(walker.energy / walker.max_energy, 0.0, 1.0)
		var bar := Rect2(x0, y - 16.0, w, 7.0)
		draw_rect(bar, Color(0.06, 0.07, 0.10, 0.85))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)),
			Color(0.45, 0.78, 0.95) if not walker.meditating else Color(0.62, 0.9, 1.0))
		draw_rect(bar, Color(AMBER, 0.35), false, 1.0)
		draw_string(_font, Vector2(x0 + w + 8.0, y - 9.0),
			"%d" % int(walker.energy), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.72, 0.84, 0.95))

	for i in n:
		var r := Rect2(x0 + i * (SLOT + GAP), y, SLOT, SLOT)
		var tid := Pilot.technique_at(i)
		draw_rect(r, Color(0.05, 0.06, 0.09, 0.86))
		draw_rect(r, Color(AMBER, 0.75 if tid != "" else 0.28), false, 2.0)
		draw_string(_font, r.position + Vector2(4, 13), str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(AMBER, 0.9))
		if tid == "":
			continue
		var icon := Techniques.icon(tid)
		if icon != null:
			draw_texture_rect(icon, r.grow(-7.0), false)
		else:
			# No art yet — the name's initials, same fallback idea as material glyphs.
			var nm := Techniques.display_name(tid)
			var glyph := ""
			for word in nm.split(" "):
				if word != "":
					glyph += word[0]
			draw_string(_font, r.position + Vector2(0, SLOT * 0.68), glyph.left(3),
				HORIZONTAL_ALIGNMENT_CENTER, SLOT, 17, Color(0.92, 0.9, 0.84))
		# COOLDOWN: a dark curtain falling over the slot + the seconds left.
		var left := float(cooldowns.get(tid, 0.0))
		if left > 0.0:
			var total: float = maxf(0.01, float(Techniques.def(tid).get("cooldown", 1.0)))
			var frac: float = clampf(left / total, 0.0, 1.0)
			draw_rect(Rect2(r.position, Vector2(SLOT, SLOT * frac)), Color(0.02, 0.03, 0.05, 0.7))
			draw_string(_font, r.position + Vector2(0, SLOT * 0.62), "%.0f" % ceilf(left),
				HORIZONTAL_ALIGNMENT_CENTER, SLOT, 18, Color(1, 0.86, 0.6))
		# ✕ when the cell can't pay for it — the same "can't fire" tell the ship bar uses,
		# so you learn it once. (Every other refusal is situational and says so out loud.)
		elif walker.energy < float(Techniques.def(tid).get("energy", 0.0)):
			draw_string(_font, r.position + Vector2(0, SLOT * 0.72), "✕",
				HORIZONTAL_ALIGNMENT_CENTER, SLOT, 22, Color(0.93, 0.35, 0.32, 0.9))
