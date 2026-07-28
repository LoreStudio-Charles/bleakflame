class_name MissionComputer
extends ContextScreen
## THE MISSION COMPUTER — the first screen built to docs/person_as_context.md.
##
## It used to be THREE COLUMNS: contracts on offer | contracts in hand | quest log.
## A tester asked "where do I turn this in?" and the honest answer was: in the middle
## column, floating free of the contract it acts on, in a column that was otherwise
## 90% empty AND redundant — the same contract was listed again in the quest log
## beside it. The third column existed because it duplicated the second, and the
## action got buried on the redundant copy.
##
## ContextScreen owns the shape (header = you, one list, the selected thing with its
## action on it). This owns the words: every live objective — campaign beat, side
## contract, expedition lead — is one row of the same list in MissionTracker order,
## so the thing you read and the thing you act on are the same object, and the
## tracker's ★/▲▼ curation sits in the detail panel with it. HISTORY (finished work
## and the ship's log) is a MODE of the same two columns, never a second list beside
## the first.
##
## UI ONLY. Accepting and closing out are the HOST'S business (they move the wallet,
## faction standing and the campaign hand-off): this emits and re-reads. That is why
## a refused turn-in still reports through the host's one shared path.

signal accept_offer(index: int)          ## global MissionLog.offers index
signal turn_in_requested(index: int)     ## MissionLog.active index

var ship: TestShip
## WHERE THIS DESK STANDS — "station" / "planet" / "shoal" / "verge". A venue NAME, not
## the `is_station` bool this used to take: a bool can only say two of the four places
## that have a board, so the Rust Shoal and The Dig each grew their own copy of a
## contract board rather than being able to use this one. Two implementations of "can I
## hand this in here" is how boards drift apart.
var venue: String
## Which board's postings this desk shows. "" = the venue's public board; a name picks a
## PERSON'S board out of it (Vyper's work, Doug's rock).
var board: String


func _init(p_ship: TestShip, p_venue: String, p_board := "") -> void:
	# EXPLICIT: declaring _init here suppresses the base's, so the shell (header, list,
	# detail panel) is never built and every widget call lands on null.
	super()
	ship = p_ship
	venue = p_venue
	board = p_board
	set_modes([["work", "WORK"], ["log", "HISTORY"]])


## The header answers the tester's question before they have clicked anything: how
## many jobs can be closed AT THIS DESK. The rest is what a contract costs you to
## carry — credits and hold.
func header_text() -> String:
	var closeable := 0
	for m in MissionLog.active:
		if MissionLog.is_complete(m, ship) and MissionLog.venue_ok_at(m, venue):
			closeable += 1
	var hand_in := "[color=#%s]nothing to hand in here[/color]" % UiTheme.DIM.to_html(false)
	if closeable > 0:
		hand_in = "[b][color=#%s]%d %s to close here[/color][/b]" % [
			UiTheme.AMBER.to_html(false), closeable,
			"job" if closeable == 1 else "jobs"]
	return "[right]%s     [color=#%s]credits[/color] %dc     [color=#%s]hold[/color] %.0f/%.0f[/right]" % [
		hand_in, UiTheme.DIM.to_html(false), Wallet.credits, UiTheme.DIM.to_html(false),
		ship.cargo_used(), float(ship.stats.get("cargo", 0.0))]


func fill_list() -> void:
	if _mode == "work":
		_fill_work()
	else:
		_fill_history()


func _fill_work() -> void:
	var rich := _rich_entries()
	var tracked: Array = MissionTracker.trackables(ship)
	var spines: Array = Quests.dormant_spines()
	section("YOUR WORK")
	if tracked.is_empty() and spines.is_empty():
		empty_row("— nothing in hand — take something from the board —")
	var current_key := ""
	for t in tracked:
		if not t.hidden:
			current_key = str(t.key)
			break
	for t in tracked:
		_track_row(t, rich, str(t.key) == current_key)
	for s in spines:
		row("   %s %s" % [QuestLogView.GLYPH.get("saga", "◆"), short(str(s.title))],
			str(s.id), "entry", {"entry": s}, UiTheme.DIM)

	section("ON OFFER HERE")
	var offers := MissionLog.offers_at(venue, board)
	if offers.is_empty():
		empty_row("— the board is bare — check back after a run —")
	for e in offers:
		var m: Dictionary = e.m
		row("   %s   %dc" % [short(str(m.get("desc", "Contract"))), int(m.get("reward", 0))],
			"o:%s" % str(m.get("desc", "")), "offer",
			{"index": int(e.index), "m": m}, UiTheme.TEXT, str(m.get("giver", "")))


## One objective row. A contract that can be CLOSED HERE wears a ✓ and goes amber —
## the same signal the header counts, at the row you have to click.
func _track_row(t: Dictionary, rich: Dictionary, is_current: bool) -> void:
	var key := str(t.key)
	var kind := str(t.kind)
	var txt := "%s %s" % [str(QuestLogView.GLYPH.get(kind, "•")), short(str(t.label))]
	if t.has("count"):
		var c: Vector2i = t.count
		txt += "   %d/%d" % [c.x, c.y]
	var tint: Color = QuestLogView.TINT.get(kind, UiTheme.TEXT)
	var ci := _contract_index(key)
	var closeable := false
	if ci >= 0:
		var m: Dictionary = MissionLog.active[ci]
		closeable = MissionLog.is_complete(m, ship) and MissionLog.venue_ok_at(m, venue)
	if closeable:
		txt = "✓ " + txt
		tint = UiTheme.AMBER
	else:
		txt = ("▶ " if is_current else "   ") + txt
	var giver_id := ""
	if ci >= 0:
		giver_id = str(MissionLog.active[ci].get("giver", ""))
	elif rich.has(key):
		giver_id = str((rich[key] as Dictionary).get("giver_id", ""))
	var data := {"key": key, "track": t}
	if rich.has(key):
		data["entry"] = rich[key]
	row(txt, key, "contract" if ci >= 0 else "entry", data,
		tint if not t.hidden else tint.darkened(0.35), giver_id)


## Finished work, then the ship's log. Same two columns, different mode — the log is
## never a third list sitting beside the one you are working in.
func _fill_history() -> void:
	section("COMPLETED")
	var done: Array = Quests.completed_entries() + Research.completed_entries()
	if done.is_empty():
		empty_row("— no finished business yet —")
	for e in done:
		row("   %s" % short(str(e.title)), "c:%s" % str(e.id), "entry", {"entry": e},
			Color(0.55, 0.75, 0.6), str(e.get("giver_id", "")))

	section("SHIP'S LOG")
	if Research.journal.is_empty():
		empty_row("— no entries yet — the Reach keeps its stories close —")
	for j in range(Research.journal.size() - 1, -1, -1):
		var entry: Dictionary = Research.journal[j]
		row("   %s  %s" % [GameClock.label(int(entry.day)),
			short(str(entry.text), ROW_CHARS - 10)],
			"j:%d" % j, "journal", {"entry": entry}, UiTheme.DIM)


func render_detail(md: Dictionary) -> void:
	match str(md.get("kind", "")):
		"offer": _detail_offer(md)
		"contract": _detail_contract(md)
		"journal": _detail_journal(md)
		_: _detail_entry(md.get("entry", {}), str(md.get("key", "")))


func _detail_offer(md: Dictionary) -> void:
	var m: Dictionary = md.m
	title(str(m.get("desc", "Contract")))
	who(str(m.get("giver", "")), "OFFERED HERE")
	note("%s work. Closes at %s." % [str(m.get("type", "")).capitalize(),
		venue_word(str(m.get("turn_in", "station")))])
	stat("Pays", "%dc" % int(m.get("reward", 0)))
	var full := ""
	if MissionLog.active.size() >= MissionLog.MAX_ACTIVE:
		full = "Your log is full — %d of %d contracts in hand. Close one first." % [
			MissionLog.active.size(), MissionLog.MAX_ACTIVE]
	action("Accept contract", full, func() -> void: accept_offer.emit(_offer_index(md)))


## The contract you are HOLDING — and the one screen in the game where the turn-in
## button belongs, sitting under the contract it closes rather than floating in a
## column of its own.
func _detail_contract(md: Dictionary) -> void:
	var i := _contract_index(str(md.key))
	if i < 0:
		note("That contract is no longer in hand.")
		return
	var m: Dictionary = MissionLog.active[i]
	title(str(m.get("desc", "Contract")))
	who(str(m.get("giver", "")), "IN HAND · %s" % str(m.get("type", "")).to_upper())
	var have := MissionLog.progress(m, ship)
	var need := int(m.get("n", 1))
	stat("Progress", "%d of %d" % [have, need])
	stat("Reward", "%dc" % int(m.get("reward", 0)))
	stat("Closes at", venue_word(str(m.get("turn_in", "station"))))
	# THE REASON IS ITS OWN SENTENCE, never a second printing of the stat block above.
	# "Closes at the colony" twice in one panel is the redundancy this screen exists
	# to end — and a reason that only echoes a stat cannot be told apart from one.
	var stop := ""
	if not MissionLog.is_complete(m, ship):
		stop = "Not finished yet — %d of %d." % [have, need]
	elif not MissionLog.venue_ok_at(m, venue):
		stop = "Finished — but not at this desk."
	action("Turn in — %dc" % int(m.get("reward", 0)), stop,
		func() -> void: turn_in_requested.emit(_contract_index(str(md.key))))
	curation(str(md.key))


func _detail_entry(e: Dictionary, key: String) -> void:
	if e.is_empty():
		note("Nothing more is known about this yet.")
		curation(key)
		return
	title(str(e.get("title", "")), UiTheme.AMBER)
	who(str(e.get("giver_id", "")), str(e.get("giver", "")).to_upper())
	if str(e.get("body", "")) != "":
		note(str(e.body), true)
	for s in e.get("done", []):
		step_line(str(s), true)
	if not bool(e.get("done_quest", false)) and str(e.get("current", "")) != "":
		step_line(str(e.current))
	if str(e.get("rewards", "")) != "":
		stat("Reward", str(e.rewards))
	curation(key)


func _detail_journal(md: Dictionary) -> void:
	var e: Dictionary = md.entry
	title(GameClock.label(int(e.day)), UiTheme.AMBER)
	note(str(e.text))


# ---- helpers --------------------------------------------------------------

## Where a contract closes, in words a pilot uses. The raw venue keys are data.
static func venue_word(v: String) -> String:
	match v:
		"station": return "the station"
		"planet": return "the colony"
		"verge": return "The Dig"
		"shoal": return "the Rust Shoal"
		"either": return "either desk"
	return v


## Index into MissionLog.active for a tracker key, or -1 if it isn't a contract.
func _contract_index(key: String) -> int:
	if not key.begins_with("m:"):
		return -1
	var uid := int(key.substr(2))
	for i in MissionLog.active.size():
		if MissionLog.uid_of(MissionLog.active[i]) == uid:
			return i
	return -1


## The GLOBAL offers index for a row, re-derived at click time: the board restocks on
## every accept and turn-in, so a stale index would take the wrong contract.
func _offer_index(md: Dictionary) -> int:
	var m: Dictionary = md.m
	var i := int(md.get("index", -1))
	if i >= 0 and i < MissionLog.offers.size() and MissionLog.offers[i] == m:
		return i
	return MissionLog.offers.find(m)


## Campaign and expedition entries keyed by tracker key — the authored text behind an
## objective row (contracts have none; they get their own detail).
func _rich_entries() -> Dictionary:
	var rich := {}
	for e in Quests.log_entries(ship):
		rich["q:" + str(e.id)] = e
	for e in Research.log_entries(ship):
		rich["r:" + str(e.id)] = e
	return rich
