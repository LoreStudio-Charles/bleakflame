class_name DevVitals
extends CanvasLayer
## DEV HEARTBEAT MONITOR (debug only, [=] toggle in flight_test).
##
## A live corner readout of the things that quietly go wrong during a run — the
## other half of the stall log (Telemetry). A rolling event feed, colour-coded by
## severity, with the concerning ones (WARN) in red, plus a pulse that ticks
## every event so you can see the game "breathing" at a glance. Glance mid-fight,
## catch trouble in the seat.
##
## Reads Telemetry statics + a couple of live gauges (ship/energy). No game state
## of its own; drawing only. Off by default; never shipped (release strips it).

const W := 340.0
const PAD := 10.0
const SHOWN := 14         # feed rows visible

var ship: Node2D
var _panel: Control
var _t := 0.0
var _last_beat := -1
var _flash := 0.0          # white pulse when a new event lands


func _init(p_ship: Node2D) -> void:
	ship = p_ship
	layer = 60
	visible = false


func _ready() -> void:
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	add_child(_panel)
	_panel.draw.connect(_draw_panel)


## The worst frame in the last WORST_WINDOW seconds, and when that window resets.
## A ROLLING PEAK, not an average: a stutter is one bad frame among sixty good ones, and
## an average of the sixty says everything is fine. Held for a couple of seconds so the
## number is readable by a human who just felt the hitch, rather than gone before they
## can look down.
const WORST_WINDOW := 2.0
var _worst_ms := 0.0
var _worst_age := 0.0


func _process(delta: float) -> void:
	# MEASURED EVEN WHILE HIDDEN. A peak that only exists while the overlay is up cannot
	# answer "was it already stuttering before I opened this?"
	var ms := delta * 1000.0
	_worst_age += delta
	if ms > _worst_ms or _worst_age >= WORST_WINDOW:
		if _worst_age >= WORST_WINDOW:
			_worst_age = 0.0
			_worst_ms = ms
		else:
			_worst_ms = ms
	if not visible:
		return
	_t += delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	if Telemetry.beat != _last_beat:
		_last_beat = Telemetry.beat
		_flash = 1.0            # a new event just landed — pulse
	_panel.queue_redraw()


func _draw_panel() -> void:
	var f := ThemeDB.fallback_font
	var vw: float = get_viewport().get_visible_rect().size.x
	var x := vw - W - PAD
	var y := PAD
	var rows: int = mini(SHOWN, Telemetry.events.size())
	var h := 64.0 + rows * 15.0

	# Backing.
	_rect(Rect2(x, y, W, h), Color(0.03, 0.05, 0.07, 0.88))
	_rect(Rect2(x, y, W, h), Color(0.3, 0.85, 0.6, 0.5), false)

	# Header + heartbeat pulse.
	var pulse := 0.35 + 0.65 * (sin(_t * TAU * 1.1) * 0.5 + 0.5)
	var warns: int = Telemetry.warn_total()
	var head_col := Color(0.95, 0.4, 0.35) if warns > 0 else Color(0.4, 0.9, 0.6)
	_dot(Vector2(x + 14, y + 15), 4.0 + 1.5 * pulse, Color(head_col, 0.5 + 0.5 * pulse))
	_text(f, Vector2(x + 26, y + 20), "DEV HEARTBEAT", 13, Color(0.75, 0.82, 0.9))
	_text(f, Vector2(x + W - 96, y + 20), "WARN %d" % warns, 13, head_col)

	# Two live gauges: player energy + ship counts.
	var line2 := "energy %s   ships %d" % [
		_energy_str(),
		get_tree().get_nodes_in_group("ships").size()]
	_text(f, Vector2(x + 14, y + 40), line2, 11, Color(0.6, 0.66, 0.74))

	# FRAME TIME, AND THE WORST ONE RECENTLY — because "it feels herky-jerky" has two
	# completely different causes and they need opposite fixes. A steady 16.7 with the
	# motion still stuttering is a BEHAVIOUR bug (something oscillating frame to frame);
	# a flat average with a fat WORST is a SPIKE, and spikes are what actually read as
	# jerk. An average alone hides them entirely, which is why the peak is the number
	# that matters and the one this leads with.
	var proc := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var spike_col := Color(0.6, 0.66, 0.74)
	if _worst_ms > 33.0:
		spike_col = Color(0.95, 0.4, 0.35)      # dropped below 30fps at least once
	elif _worst_ms > 20.0:
		spike_col = Color(0.95, 0.75, 0.35)
	_text(f, Vector2(x + 14, y + 54),
		"fps %d   frame %.1f   phys %.1f   WORST %.1f ms" % [
			Engine.get_frames_per_second(), proc + phys, phys, _worst_ms],
		11, spike_col)
	_line(Vector2(x + 10, y + 64), Vector2(x + W - 10, y + 64), Color(0.3, 0.85, 0.6, 0.25))

	# Event feed — newest at top, colour by severity.
	var fy := y + 80.0
	var ev: Array = Telemetry.events
	for i in range(ev.size() - 1, maxi(-1, ev.size() - 1 - SHOWN), -1):
		var e: Dictionary = ev[i]
		var age := (Time.get_ticks_msec() - int(e.t)) / 1000.0
		var col := _sev_col(int(e.sev))
		# Freshest row gets the flash.
		if i == ev.size() - 1 and _flash > 0.0:
			col = col.lerp(Color(1, 1, 1), _flash * 0.6)
		var tag: String = ["·", "▹", "▸"][int(e.sev)]
		var txt := "%s %-6s %s" % [tag, str(e.cat), str(e.msg)]
		_text(f, Vector2(x + 12, fy), _clip(txt, 46), 11, col)
		_text(f, Vector2(x + W - 40, fy), "%3ds" % int(age), 10, Color(0.4, 0.45, 0.52))
		fy += 15.0
	if ev.is_empty():
		_text(f, Vector2(x + 12, fy), "— all quiet —", 11, Color(0.4, 0.55, 0.5))


func _energy_str() -> String:
	if ship == null or not is_instance_valid(ship) or ship.get("energy_max") == null \
			or float(ship.get("energy_max")) <= 0.0:
		return "—"
	return "%d%%" % int(round(100.0 * float(ship.energy) / float(ship.energy_max)))


func _sev_col(sev: int) -> Color:
	match sev:
		Telemetry.Sev.WARN: return Color(0.95, 0.42, 0.36)
		Telemetry.Sev.NOTE: return Color(0.95, 0.78, 0.4)
	return Color(0.55, 0.62, 0.7)


func _clip(s: String, n: int) -> String:
	return s if s.length() <= n else s.substr(0, n - 1) + "…"


# --- tiny draw helpers ---
func _rect(r: Rect2, c: Color, fill := true) -> void:
	if fill: _panel.draw_rect(r, c)
	else: _panel.draw_rect(r, c, false, 1.0)
func _line(a: Vector2, b: Vector2, c: Color) -> void: _panel.draw_line(a, b, c, 1.0)
func _dot(p: Vector2, rad: float, c: Color) -> void: _panel.draw_circle(p, rad, c)
func _text(f: Font, p: Vector2, s: String, size: int, c: Color) -> void:
	_panel.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
