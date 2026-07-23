class_name Anomaly
extends StaticBody2D
## A quest-placed reading that shouldn't be there — the only footprint a
## devouring leaves. Scannable (RMB-select, [1] to survey) like a rock, but
## it yields no ore and no Scan Data: surveying it advances a `scan_target`
## quest stage and reveals the wrongness. A violet smear that reads as
## matter which is ABSENT. Not destructible; despawns once read.

const R := 46.0

var quest_id := ""
## "residue" = a cold violet smear, the footprint of a devouring (beat 2).
## "tendril" = a piece of the web itself, broken off and lingering — the
## first time you scan the CREATURE's own matter, not just its trace (beat 4).
var kind := "residue"
var scanned := false
var hit_radius := R
var _t := 0.0
var _core: Polygon2D
var _ring: Line2D
var _tendrils: Array[Line2D] = []


static func create(pos: Vector2, p_quest_id: String, p_kind := "residue") -> Anomaly:
	var a := Anomaly.new()
	a.position = pos
	a.quest_id = p_quest_id
	a.kind = p_kind
	return a


func _ready() -> void:
	add_to_group("scannable")
	add_to_group("anomaly")
	if kind == "tendril":
		hit_radius = R * 1.4   # a bigger, darker thing than a smear
	var shape := CircleShape2D.new()
	shape.radius = hit_radius
	var col := CollisionShape2D.new()
	col.shape = shape
	# No solid blocking — bolts pass through; it is a reading, not a body.
	col.disabled = true
	add_child(col)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var core_col := Color(0.28, 0.1, 0.42, 0.6) if kind == "tendril" \
		else Color(0.5, 0.2, 0.75, 0.5)
	var ring_col := Color(0.55, 0.25, 0.9, 0.75) if kind == "tendril" \
		else Color(0.7, 0.4, 1.0, 0.7)
	_core = Polygon2D.new()
	_core.polygon = _disc(hit_radius * 0.6, 20)
	_core.color = core_col
	_core.material = mat
	add_child(_core)
	_ring = Line2D.new()
	_ring.points = _disc(hit_radius * 0.85, 28)
	_ring.closed = true
	_ring.width = 2.0
	_ring.default_color = ring_col
	_ring.material = mat
	add_child(_ring)
	# A tendril reaches: a few dark barbs writhing off the core.
	if kind == "tendril":
		for i in 5:
			var t := Line2D.new()
			var a := TAU * float(i) / 5.0 + randf() * 0.4
			var reach := hit_radius * randf_range(1.0, 1.7)
			t.points = PackedVector2Array([Vector2.ZERO,
				Vector2.RIGHT.rotated(a) * reach * 0.5,
				Vector2.RIGHT.rotated(a + 0.5) * reach])
			t.width = 3.0
			t.default_color = Color(0.4, 0.16, 0.6, 0.8)
			t.material = mat
			add_child(t)
			_tendrils.append(t)


func _process(delta: float) -> void:
	_t += delta
	# A slow, wrong breathing — never quite still.
	var pulse := 0.85 + 0.15 * sin(_t * 1.6)
	_core.scale = Vector2.ONE * pulse
	_ring.rotation = _t * 0.3
	_core.color.a = 0.35 + 0.2 * sin(_t * 2.1)
	for i in _tendrils.size():
		_tendrils[i].rotation = sin(_t * 0.7 + i) * 0.3   # writhing


func survey_text() -> String:
	if kind == "tendril":
		return "a severed piece of the WEB — living shadow, and it is watching back"
	return "cold violet residue — matter reads as ABSENT"


## Called by the ship when the survey completes on this anomaly.
func on_scanned() -> void:
	if scanned:
		return
	scanned = true
	var fx := CPUParticles2D.new()
	fx.position = global_position
	fx.one_shot = true
	fx.emitting = true
	fx.amount = 20
	fx.lifetime = 0.7
	fx.explosiveness = 1.0
	fx.spread = 180.0
	fx.initial_velocity_min = 20.0
	fx.initial_velocity_max = 90.0
	fx.color = Color(0.7, 0.4, 1.0)
	get_parent().add_child(fx)
	fx.finished.connect(fx.queue_free)
	queue_free()


func _disc(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / segments
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
