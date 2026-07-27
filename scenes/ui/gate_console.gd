class_name GateConsole
extends CanvasLayer
## THE WAYGATE CONSOLE (user, 2026-07-23). The finale is not a fly-through: the
## pilot ENTERS THE WAKING SEQUENCE Krayt died to send them — and so the player,
## with their own hands, is the one who opens the ring. The weight of that lands
## later (the gates were the Warden firewall; you broke it). Here the tone is only
## escape and Krayt's gift.
##
## LOOK = WARDEN CRYSTAL, matching the gate (docs/threats_wardens.md): pale ivory
## ceramic + translucent crystal, gold light-veins, gemlike — a cathedral interface,
## not a tech box. Alien "writing" is drawn as procedural RUNES (glowing line glyphs)
## so it always renders and matches the ring's carved veins. Krayt's sequence is
## shown up top; the gemlike keypad below is shuffled, and some keys match his. Tap
## them in order. A wrong key buzzes and clears — you cannot fail, only open it.

signal entered
signal closed

## Runes on a 3x3 grid (indices 0-8, row-major). Each rune is a list of segments.
const RUNES := [
	[[0, 8], [2, 6]],                 # X
	[[1, 7], [3, 5]],                 # +
	[[0, 2], [4, 7]],                 # T
	[[0, 6], [6, 8], [8, 2]],         # bracket
	[[0, 4], [4, 8], [2, 4]],         # Y
	[[6, 1], [1, 8], [8, 6]],         # triangle (was a duplicate "+" of rune 1)
	[[0, 5], [5, 6]],                 # zig
	[[2, 3], [3, 8]],                 # zag
	[[1, 4], [4, 6], [4, 8]],         # fork
	[[0, 8], [3, 5]],                 # slash + bar
	[[0, 2], [1, 7], [6, 8]],         # I-beam
	[[1, 3], [3, 7], [7, 5], [5, 1]], # diamond
]
## THE WAKING SEQUENCE — indices into RUNES, in order. What Krayt sent.
const CODE := [4, 9, 1, 6, 11]

# --- Warden crystal palette ---
const GOLD := Color(0.98, 0.80, 0.38)
const GOLD_DIM := Color(0.56, 0.45, 0.23)
const IVORY := Color(0.92, 0.90, 0.82)
const CRYSTAL := Color(0.07, 0.09, 0.15)
const KEY_BG := Color(0.10, 0.13, 0.20)
const KEY_HI := Color(0.17, 0.23, 0.35)
const DIM := Color(0.50, 0.55, 0.66)

var _entered: Array[int] = []
var _entry_row: HBoxContainer
var _keypad: GridContainer
var _err := 0.0
var _pulse_targets: Array[CanvasItem] = []


static func grid_point(i: int) -> Vector2:
	return Vector2(float(i % 3) / 2.0, float(i / 3) / 2.0)


## Draw a GLOWING rune into `rect` on any CanvasItem — shared by keys and prompt.
## A soft translucent underlay + a crisp line reads as a light-vein on dark crystal.
static func draw_rune(ci: CanvasItem, idx: int, rect: Rect2, color: Color, width: float) -> void:
	if idx < 0 or idx >= RUNES.size():
		return
	for seg in RUNES[idx]:
		var a: Vector2 = rect.position + grid_point(seg[0]) * rect.size
		var b: Vector2 = rect.position + grid_point(seg[1]) * rect.size
		ci.draw_line(a, b, Color(color, 0.22), width * 2.8)   # glow
	for seg in RUNES[idx]:
		var a: Vector2 = rect.position + grid_point(seg[0]) * rect.size
		var b: Vector2 = rect.position + grid_point(seg[1]) * rect.size
		ci.draw_line(a, b, color, width)
		ci.draw_circle(a, width * 0.85, color)
		ci.draw_circle(b, width * 0.85, color)


func _init() -> void:
	layer = 12


func _ready() -> void:
	add_to_group("esc_capture")
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.035, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.add_theme_stylebox_override("panel", _crystal_box())
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	# --- Header: sigil + title ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(head)
	head.add_child(_sigil())
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	head.add_child(titles)
	var title := Label.new()
	title.text = "THE WAYGATE"
	title.add_theme_color_override("font_color", IVORY)
	title.add_theme_font_size_override("font_size", 22)
	titles.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "waking-sequence lock"
	subtitle.add_theme_color_override("font_color", GOLD)
	subtitle.add_theme_font_size_override("font_size", 12)
	titles.add_child(subtitle)

	col.add_child(_Vein.new())

	var prompt_lbl := Label.new()
	prompt_lbl.text = "THE SEQUENCE KRAYT SENT"
	prompt_lbl.add_theme_color_override("font_color", GOLD)
	prompt_lbl.add_theme_font_size_override("font_size", 12)
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(prompt_lbl)

	# Krayt's sequence, drawn as glowing gemlike runes (the target).
	var prompt := _SequenceView.new(CODE)
	prompt.custom_minimum_size = Vector2(CODE.size() * 60, 60)
	_pulse_targets.append(prompt)
	col.add_child(prompt)

	col.add_child(_Vein.new())

	# The pilot's entry, filling slot by slot.
	_entry_row = HBoxContainer.new()
	_entry_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_entry_row.add_theme_constant_override("separation", 10)
	col.add_child(_entry_row)
	_rebuild_entry()

	# The keypad — all runes, shuffled; some are Krayt's.
	_keypad = GridContainer.new()
	_keypad.columns = 6
	_keypad.add_theme_constant_override("h_separation", 10)
	_keypad.add_theme_constant_override("v_separation", 10)
	col.add_child(_keypad)
	var order: Array[int] = []
	for i in RUNES.size():
		order.append(i)
	order.shuffle()
	for idx in order:
		var key := _RuneKey.new(idx)
		key.pressed_rune.connect(_on_key)
		_keypad.add_child(key)

	var hint := Label.new()
	hint.text = "tap the sequence in order   ·   [Esc] step back"
	hint.add_theme_color_override("font_color", DIM)
	hint.add_theme_font_size_override("font_size", 11)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)


func _crystal_box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(CRYSTAL, 0.97)
	s.border_color = GOLD
	s.set_border_width_all(2)
	s.set_corner_radius_all(5)
	s.set_content_margin_all(26.0)
	s.shadow_color = Color(GOLD, 0.12)     # a faint gold aura around the panel
	s.shadow_size = 10
	return s


## A drop-in Warden sigil (assets/ui/waygate_sigil.png) or a procedural gold gem.
func _sigil() -> Control:
	var path := "res://assets/ui/waygate_sigil.png"
	if ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		t.custom_minimum_size = Vector2(52, 52)
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return t
	return _Gem.new()


func _on_key(idx: int) -> void:
	# THE SEQUENCE IS ALREADY IN. _finish() is reached through an `await` of ~0.35s
	# and the keypad stays live through it, so one more tap indexed CODE[5] on a
	# 5-element array -- an out-of-range read that fell through to the WRONG-KEY
	# branch and flashed the entry row red at the exact moment the gate opens.
	if _entered.size() >= CODE.size():
		return
	if idx == CODE[_entered.size()]:
		_entered.append(idx)
		Sfx.play("click", -6.0, 1.5)
		_rebuild_entry()
		if _entered.size() == CODE.size():
			Sfx.play("dock", -4.0, 0.7)
			await get_tree().create_timer(0.35).timeout
			entered.emit()
			_finish()
	else:
		# Wrong — buzz and clear. You cannot fail, only start the line again.
		Sfx.play("scrape", -6.0, 0.8)
		_entered.clear()
		_err = 0.4
		_rebuild_entry()


func _rebuild_entry() -> void:
	for c in _entry_row.get_children():
		c.queue_free()
	for slot in CODE.size():
		var v := _SlotView.new(_entered[slot] if slot < _entered.size() else -1,
			GOLD if _err <= 0.0 else UiTheme.DANGER)
		_entry_row.add_child(v)


func _process(delta: float) -> void:
	if _err > 0.0:
		_err = maxf(0.0, _err - delta)
		if _err == 0.0:
			_rebuild_entry()
	# A slow gemlike breathing on the prompt runes.
	var t: float = 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.0022)
	for c in _pulse_targets:
		if is_instance_valid(c):
			c.modulate = Color(1, 1, 1, t)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		closed.emit()
		_finish()


func _finish() -> void:
	remove_from_group("esc_capture")
	queue_free()


## A thin gold light-vein divider with a gem at its heart.
class _Vein:
	extends Control
	func _init() -> void:
		custom_minimum_size = Vector2(0, 10)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _draw() -> void:
		var y := size.y * 0.5
		var mid := size.x * 0.5
		draw_line(Vector2(8, y), Vector2(mid - 10, y), Color(GateConsole.GOLD, 0.5), 1.0)
		draw_line(Vector2(mid + 10, y), Vector2(size.x - 8, y), Color(GateConsole.GOLD, 0.5), 1.0)
		var d := 4.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(mid, y - d), Vector2(mid + d, y), Vector2(mid, y + d), Vector2(mid - d, y)]),
			GateConsole.GOLD)


## A procedural gold gem, fallback for the header sigil.
class _Gem:
	extends Control
	func _init() -> void:
		custom_minimum_size = Vector2(46, 46)
	func _draw() -> void:
		var c := size * 0.5
		var r := 18.0
		draw_circle(c, r + 3.0, Color(GateConsole.GOLD, 0.18))
		var facets := PackedVector2Array([
			c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		draw_colored_polygon(facets, Color(0.22, 0.20, 0.14))
		draw_polyline(PackedVector2Array([facets[0], facets[1], facets[2], facets[3], facets[0]]),
			GateConsole.GOLD, 1.5)
		draw_circle(c, 4.5, GateConsole.GOLD)


## A row of glowing runes (Krayt's sequence) in gemlike crystal cells.
class _SequenceView:
	extends Control
	var _codes: Array
	func _init(codes: Array) -> void:
		_codes = codes
	func _draw() -> void:
		var cw := size.x / maxf(_codes.size(), 1)
		var cell := minf(size.y, cw) - 12.0
		for i in _codes.size():
			var org := Vector2(i * cw + (cw - cell) * 0.5, (size.y - cell) * 0.5)
			# gemlike recessed cell
			draw_rect(Rect2(org - Vector2(4, 4), Vector2(cell + 8, cell + 8)),
				Color(GateConsole.KEY_BG, 0.9))
			draw_rect(Rect2(org - Vector2(4, 4), Vector2(cell + 8, cell + 8)),
				Color(GateConsole.GOLD, 0.55), false, 1.0)
			GateConsole.draw_rune(self, int(_codes[i]), Rect2(org, Vector2(cell, cell)),
				GateConsole.GOLD, 2.6)


## One entry slot — a framed crystal cell, filled once its rune is tapped.
class _SlotView:
	extends Control
	var _idx: int
	var _frame: Color
	func _init(idx: int, frame: Color) -> void:
		_idx = idx
		_frame = frame
		custom_minimum_size = Vector2(48, 48)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(GateConsole.KEY_BG, 0.7))
		draw_rect(Rect2(Vector2.ZERO, size), Color(_frame, 0.55), false, 1.5)
		if _idx >= 0:
			GateConsole.draw_rune(self, _idx, Rect2(Vector2(9, 9), size - Vector2(18, 18)),
				_frame, 2.6)


## A clickable gemlike keypad rune.
class _RuneKey:
	extends Control
	signal pressed_rune(idx: int)
	var _idx: int
	var _hover := false
	func _init(idx: int) -> void:
		_idx = idx
		custom_minimum_size = Vector2(58, 58)
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			pressed_rune.emit(_idx)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER:
			_hover = true; queue_redraw()
		elif what == NOTIFICATION_MOUSE_EXIT:
			_hover = false; queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, GateConsole.KEY_HI if _hover else GateConsole.KEY_BG)
		draw_rect(r, GateConsole.GOLD if _hover else Color(GateConsole.GOLD, 0.4),
			false, 1.5 if _hover else 1.0)
		var col := GateConsole.GOLD if _hover else GateConsole.GOLD_DIM
		GateConsole.draw_rune(self, _idx, Rect2(Vector2(13, 13), size - Vector2(26, 26)),
			col, 2.6)
