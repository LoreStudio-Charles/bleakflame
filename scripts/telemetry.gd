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
	for i in FRAME_BUCKETS.size():
		if ms <= float(FRAME_BUCKETS[i]):
			frame_hist[i] += 1
			return
	frame_hist[FRAME_BUCKETS.size()] += 1


## THE WHOLE PICTURE AS TEXT, so it can be pasted, logged, or read off disk by somebody
## who was not there. Printed (so it lands in user://logs/godot.log, which persists) and
## returned (so a caller can also write it somewhere of its own).
static func report(tree: SceneTree = null) -> String:
	var out := "==== DIAGNOSTIC ====
"
	var hz := DisplayServer.screen_get_refresh_rate()
	out += "display %.0f Hz   physics tick %d   fps now %d
" % [
		hz, Engine.physics_ticks_per_second, Engine.get_frames_per_second()]
	if hz > 0.0 and absf(hz - Engine.physics_ticks_per_second) > 5.0:
		out += "  !! REFRESH/TICK MISMATCH — motion advances in %d steps a second and the
" % Engine.physics_ticks_per_second
		out += "     screen draws %.0f. Expect judder flying straight; that is PRESENTATION,
" % hz
		out += "     not cost, and physics interpolation is the lever.
"
	if frame_count > 0:
		out += "frames %d   mean %.2f ms   worst %.1f ms
" % [
			frame_count, frame_total / float(frame_count), frame_worst]
		var prev := 0.0
		for i in FRAME_BUCKETS.size():
			out += "  <= %6.1f ms  %6d
" % [FRAME_BUCKETS[i], frame_hist[i]]
			prev = float(FRAME_BUCKETS[i])
		out += "  >  %6.1f ms  %6d   <-- hitches
" % [prev, frame_hist[FRAME_BUCKETS.size()]]
	if tree != null:
		out += "ships %d   projectiles %d   asteroids %d
" % [
			tree.get_nodes_in_group("ships").size(),
			tree.get_nodes_in_group("projectiles").size(),
			tree.get_nodes_in_group("asteroids").size()]
	out += "warnings this session: %d
" % warn_total()
	for k in counts:
		out += "  %s = %d
" % [k, counts[k]]
	out += "---- last events ----
"
	for e in events:
		out += "  [%s] %s: %s
" % [str(e.get("sev", "")), str(e.get("cat", "")), str(e.get("msg", ""))]
	out += "==== END ====
"
	print(out)
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
