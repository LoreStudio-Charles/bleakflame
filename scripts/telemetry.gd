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

static var events: Array = []          # [{t, sev, cat, msg}] newest last
static var counts := {}                 # "cat:sev" -> running tally, session
static var beat := 0                    # increments every mark — the "pulse"


## The one call sources use. `sev` colours it; `cat` groups it (tutor/ai/player/
## world…); `msg` is one short line. Timestamped with the monotonic clock.
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
