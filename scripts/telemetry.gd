class_name Telemetry
## DEV HEARTBEAT — a live event bus for things worth watching AS YOU PLAY.
##
## The stall log (Tutor.stalls) is post-hoc — you dig it out after a run. This is
## the live half: any system pushes a one-line event here, and the DevVitals
## overlay (scenes/flight/dev_vitals.gd, a debug-only [=] toggle) shows a rolling
## feed that FLASHES the concerning ones in the moment. Catch trouble in the
## seat instead of in a JSON file at midnight.
##
## Debug-only by construction: mark() no-ops in a release export, so there is
## zero cost in a shipped build. Add a source in one line —
##   Telemetry.warn("ai", "%s crashed at the planet" % name)
## and it shows up live and colour-coded. Severities: info / note / warn.

enum Sev { INFO, NOTE, WARN }

const RING := 60          # keep the last N events (a scrolling window)

## ---- FRAME TIMING, KEPT SO IT CAN BE HANDED OVER ----
##
## User, 2026-07-28: "I really wish there was a way to share the output. That seems
## valuable, but maybe you have our own telemetry data instead." Exactly — a profiler
## capture lives and dies inside the editor, and a feeling ("herky-jerky") cannot be
## bisected. This keeps enough to answer the question in a form that survives the
## session: a HISTOGRAM, not an average, because a stutter is one bad frame in sixty and
## an average of the sixty says everything is fine.
##
## Buckets are chosen around the thing being judged: 16.7 ms is a 60 Hz frame, and
## anything past ~33 is a visible hitch.
const FRAME_BUCKETS := [8.0, 16.7, 20.0, 25.0, 33.0, 50.0, 100.0]
static var frame_hist := []            # one counter per bucket, plus an overflow
static var frame_worst := 0.0
static var frame_count := 0
static var frame_total := 0.0

static var events: Array = []          # [{t, sev, cat, msg}] newest last
static var counts := {}                 # "cat:sev" -> running tally, session
static var beat := 0                    # increments every mark — the "pulse"


## The one call sources use. `sev` colours it; `cat` groups it (tutor/ai/player/
## world…); `msg` is one short line. Timestamped with the monotonic clock.
## One frame went by. Cheap enough to call unconditionally; no-ops in a release export
## for the same reason mark() does.
static func note_frame(delta: float) -> void:
	if not OS.is_debug_build():
		return
	if frame_hist.is_empty():
		frame_hist.resize(FRAME_BUCKETS.size() + 1)
		frame_hist.fill(0)
	var ms := delta * 1000.0
	frame_count += 1
	frame_total += ms
	frame_worst = maxf(frame_worst, ms)
	_note_hitch(ms)
	for i in FRAME_BUCKETS.size():
		if ms <= float(FRAME_BUCKETS[i]):
			frame_hist[i] += 1
			return
	frame_hist[FRAME_BUCKETS.size()] += 1


## WHAT WAS HAPPENING DURING THE FRAMES THAT HURT.
##
## A mean is not what anyone feels. This session's work took the mean from 38.5 ms to
## 23.2 and the honest verdict was still "not much better" — which is correct: a steady
## 43 fps feels fine, and a 43 fps AVERAGE punctuated by 130 ms stalls feels broken.
## The average was hiding the thing being complained about, so it is the wrong
## instrument for it.
##
## For each bad frame this records the phases that grew MOST DURING THAT FRAME, diffed
## against the running totals, plus how many nodes appeared — because a spawn burst is
## the classic cause of a stall and shows up as a jump that no phase timer would
## otherwise explain.
const HITCH_MS := 45.0
const HITCHES_KEPT := 10

static var hitches: Array = []
static var _phase_mark := {}
static var _node_mark := 0


static func _note_hitch(ms: float) -> void:
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if ms >= HITCH_MS:
		var grew: Array = []
		for id in phase_us:
			var d: int = int(phase_us[id]) - int(_phase_mark.get(id, 0))
			if d > 0:
				grew.append([id, d])
		grew.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
		hitches.append({"ms": ms, "top": grew.slice(0, 4),
			"nodes": nodes, "spawned": nodes - _node_mark})
		if hitches.size() > HITCHES_KEPT:
			hitches.pop_front()
	# DUPLICATED, not referenced: phase_us keeps being written all frame long, so holding
	# a reference to it would make every diff come out as zero.
	_phase_mark = phase_us.duplicate()
	_node_mark = nodes


static func _hitch_lines() -> String:
	if hitches.is_empty():
		return ""
	var out := "worst frames in this window (>= %.0f ms), and what grew during each:\n" % HITCH_MS
	for h in hitches:
		var parts: Array = []
		for pair in (h.get("top", []) as Array):
			parts.append("%s %.1fms" % [str(pair[0]), float(pair[1]) / 1000.0])
		out += "  %6.1f ms   nodes %+d (%d total)   %s\n" % [
			float(h.get("ms", 0.0)), int(h.get("spawned", 0)), int(h.get("nodes", 0)),
			"  ".join(parts) if not parts.is_empty() else "(nothing instrumented grew)"]
	return out



## THE WHOLE PICTURE AS TEXT, so it can be pasted, logged, or read off disk by somebody
## who was not there. Printed (so it lands in user://logs/godot.log, which persists) and
## returned (so a caller can also write it somewhere of its own).
##
## IT CLEARS THE FRAME HISTOGRAM ON ITS WAY OUT, and that is the point rather than
## housekeeping. The first sample of a session is dominated by the load hitch — shaders,
## textures and eighty-odd ships all arriving at once — so a report that accumulates from
## scene start describes the WARM-UP, not the flying. Read it once and throw it away, fly
## for a while, read it again: the second one contains only steady-state play. The window
## it covers is printed, so nobody has to remember which of the two they are holding.
static func report(tree: SceneTree = null) -> String:
	var out := "==== DIAGNOSTIC ====\n"
	var hz := DisplayServer.screen_get_refresh_rate()
	out += "display %.0f Hz   physics tick %d   fps now %d\n" % [
		hz, Engine.physics_ticks_per_second, Engine.get_frames_per_second()]
	if hz > 0.0 and absf(hz - Engine.physics_ticks_per_second) > 5.0:
		out += "  !! REFRESH/TICK MISMATCH — motion advances in %d steps a second\n" \
			% Engine.physics_ticks_per_second
		out += "     while the screen draws %.0f. Expect judder flying straight; that\n" % hz
		out += "     is PRESENTATION, not cost — physics interpolation is the lever.\n"
	if frame_count > 0:
		var mean := frame_total / float(frame_count)
		out += "window %.1f s   frames %d   mean %.2f ms (%.0f fps)   worst %.1f ms\n" % [
			frame_total / 1000.0, frame_count, mean, 1000.0 / maxf(0.001, mean), frame_worst]
		var prev := 0.0
		for i in FRAME_BUCKETS.size():
			out += "  <= %6.1f ms  %6d\n" % [FRAME_BUCKETS[i], frame_hist[i]]
			prev = float(FRAME_BUCKETS[i])
		out += "  >  %6.1f ms  %6d   <-- hitches\n" % [
			prev, frame_hist[FRAME_BUCKETS.size()]]
	out += _hitch_lines()
	out += _phase_lines()
	# THE ENGINE'S OWN SPLIT, printed beside our phases so the GAP is visible instead of
	# inferred. Twice now I have reasoned about "the unaccounted milliseconds" and been
	# wrong about where they were -- first calling them the renderer, then calling them
	# presentation. The profiler settled it and this puts the same numbers in the text
	# report, where they can be read without a screenshot.
	#
	# If the phases above sum to far less than `process`, the cost is in _process
	# callbacks nobody has instrumented yet -- that subtraction is the whole point.
	out += "engine: process %.2f ms   physics %.2f ms   objects %d   nodes %d
" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]
	out += "  draw calls %d   video mem %.0f MB
" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0]
	if tree != null:
		out += _world_lines(tree)
	out += "warnings this session: %d\n" % warn_total()
	for k in counts:
		out += "  %s = %d\n" % [k, counts[k]]
	out += "---- last events ----\n"
	for e in events:
		out += "  [%s] %s: %s\n" % [str(e.get("sev", "")), str(e.get("cat", "")),
			str(e.get("msg", ""))]
	out += "==== END ==== (frame window cleared — fly a while, then run it again)\n"
	print(out)
	reset_frames()
	return out


## WHERE THE FRAME ACTUALLY GOES. Added because the frame histogram says a frame costs
## 26 ms and says nothing about WHY, and this problem has now defeated two confident
## guesses in a row -- first "it is separation", then "it is refresh/tick judder", both
## wrong and both expensive. A phase tally cannot be argued with.
##
## Usage is two lines at the site:
##     var t0 := Telemetry.now_us()
##     ... the work ...
##     Telemetry.phase("ai.think", t0)
##
## Costs one clock read per call and no-ops in a release export, same as everything else
## here. Cleared with the frame window, so a phase table always describes the same window
## as the histogram printed beside it.
static var phase_us := {}
static var phase_calls := {}


## The clock, wrapped so a call site does not have to know which one -- and so the whole
## mechanism disappears with one edit if it ever needs to.
static func now_us() -> int:
	return Time.get_ticks_usec()


static func phase(id: String, started_us: int) -> void:
	if not OS.is_debug_build():
		return
	phase_us[id] = int(phase_us.get(id, 0)) + (Time.get_ticks_usec() - started_us)
	phase_calls[id] = int(phase_calls.get(id, 0)) + 1


## NESTED PHASES DOUBLE-COUNT ON PURPOSE. "move" contains "separation", so the two
## columns are meant to be read as a breakdown, not summed to 100%. Saying so in the
## output is cheaper than a call tree, and a call tree is not what this question needs.
static func _phase_lines() -> String:
	if phase_us.is_empty() or frame_count == 0:
		return ""
	var ids := phase_us.keys()
	ids.sort_custom(func(a, b): return int(phase_us[a]) > int(phase_us[b]))
	var out := "where the frame goes (nested phases overlap -- a breakdown, not a sum):
"
	out += "  %-18s %9s %9s %8s %9s
" % ["phase", "ms/frame", "% frame", "calls/f", "us/call"]
	var mean_ms := frame_total / float(frame_count)
	for id in ids:
		var total_us := float(phase_us[id])
		var calls := float(phase_calls[id])
		var per_frame_ms := total_us / 1000.0 / float(frame_count)
		out += "  %-18s %9.2f %8.1f%% %8.1f %9.1f
" % [
			id, per_frame_ms, 100.0 * per_frame_ms / maxf(0.001, mean_ms),
			calls / float(frame_count), total_us / maxf(1.0, calls)]
	return out



## Start a fresh measurement window. Nothing else is cleared: the event log and the
## warning tallies are the session's history and are worth keeping across samples.
static func reset_frames() -> void:
	hitches.clear()
	_phase_mark.clear()
	phase_us.clear()
	phase_calls.clear()
	frame_hist.clear()
	frame_worst = 0.0
	frame_count = 0
	frame_total = 0.0


## WHAT IS ACTUALLY IN THE WORLD — and, the part that decides whether culling is worth
## building, HOW FAR AWAY IT IS. The Long Lane is roughly 91,000 units end to end and a
## 1920-wide screen sees about 1,900 of it, so a population figure on its own says nothing
## about how much of that population the player could ever perceive. Banded against the
## nearest pilot, it does.
const DIAG_BANDS := [2000.0, 5000.0, 10000.0, 25000.0]

static func _world_lines(tree: SceneTree) -> String:
	var ships := tree.get_nodes_in_group("ships")
	var out := "ships %d   projectiles %d   asteroids %d\n" % [
		ships.size(), tree.get_nodes_in_group("projectiles").size(),
		tree.get_nodes_in_group("asteroids").size()]

	# BY CLASS, because "86 ships" does not say which spawner to go and look at.
	var by_class := {}
	for s in ships:
		# A diagnostic must never be the thing that brings down the session it measures.
		if not is_instance_valid(s):
			continue
		var k: String = s.get_class() if s.get_script() == null \
			else str(s.get_script().resource_path).get_file().get_basename()
		by_class[k] = int(by_class.get(k, 0)) + 1
	var names := by_class.keys()
	names.sort()
	for k in names:
		out += "  %-22s %4d\n" % [k, by_class[k]]

	var pilots := tree.get_nodes_in_group("player_ship")
	if pilots.is_empty() or ships.is_empty():
		return out
	var here: Vector2 = (pilots[0] as Node2D).global_position
	var bands := []
	bands.resize(DIAG_BANDS.size() + 1)
	bands.fill(0)
	for s in ships:
		var n2 := s as Node2D
		if n2 == null or not is_instance_valid(n2):
			continue
		var d := here.distance_to(n2.global_position)
		var placed := false
		for i in DIAG_BANDS.size():
			if d <= float(DIAG_BANDS[i]):
				bands[i] += 1
				placed = true
				break
		if not placed:
			bands[DIAG_BANDS.size()] += 1
	out += "ships by distance from the pilot:\n"
	var prev := 0.0
	for i in DIAG_BANDS.size():
		out += "  %6.0f - %6.0f u  %4d\n" % [prev, DIAG_BANDS[i], bands[i]]
		prev = float(DIAG_BANDS[i])
	out += "  beyond %6.0f u  %4d   <-- simulated, never perceived\n" % [
		prev, bands[DIAG_BANDS.size()]]
	return out


static func mark(sev: int, cat: String, msg: String) -> void:
	if not OS.is_debug_build():
		return
	beat += 1
	var row := {"t": Time.get_ticks_msec(), "sev": sev, "cat": cat, "msg": msg}
	events.append(row)
	if events.size() > RING:
		events.remove_at(0)
	var key := "%s:%d" % [cat, sev]
	counts[key] = int(counts.get(key, 0)) + 1
	# WARN also prints a clean log line so it survives with the overlay off and
	# can be grepped after a run. A plain print (not push_warning) — push_warning
	# spams a GDScript backtrace after every line, which is pure noise here.
	if sev == Sev.WARN:
		print("[telemetry WARN] %s: %s" % [cat, msg])


static func info(cat: String, msg: String) -> void: mark(Sev.INFO, cat, msg)
static func note(cat: String, msg: String) -> void: mark(Sev.NOTE, cat, msg)
static func warn(cat: String, msg: String) -> void: mark(Sev.WARN, cat, msg)


## How many WARN-level events this session (the number a playtester glances at —
## nonzero means "something wanted your attention").
static func warn_total() -> int:
	var n := 0
	for k in counts:
		if str(k).ends_with(":%d" % Sev.WARN):
			n += int(counts[k])
	return n


static func reset() -> void:
	events.clear()
	counts.clear()
	beat = 0
