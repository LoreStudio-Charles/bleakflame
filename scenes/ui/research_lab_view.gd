class_name ResearchLabView
extends ContextScreen
## THE RESEARCH LAB — Dex's room, second screen built to docs/person_as_context.md.
##
## It was the Mission Computer's bug with different nouns: two ItemLists side by side
## (collection + leads | tech trees) and TWO detached buttons under them, "Research
## selected" and "Trade in all Scan Data". Selecting a lead opened a whole MODAL to
## show one paragraph, because there was nowhere on the screen for a paragraph to live.
##
## ContextScreen owns the shape; this owns the words. A row goes AMBER when it is
## researchable RIGHT NOW, so "what can I buy" reads at a glance instead of being
## arithmetic across two columns.
##
## THE SCAN DATA ARCHIVE IS A ROW, not a button. Filing readings is an action on the
## readings, so they are a thing you select and read about — which is also the only
## place the cargo-to-Insight loop was ever explained.
##
## WHY A PROJECT IS OUT OF REACH IS STATED BEFORE THE CLICK: `Research.blocker()` is
## the query behind `Research.unlock()`, so the sentence under a greyed button is the
## one a refused click would have produced.
##
## UI ONLY. Spending Insight and archiving cargo are the HOST'S business.

signal research_requested(id: String)
signal archive_requested()

var ship: TestShip


func _init(p_ship: TestShip) -> void:
	super()      # builds the shell — declaring _init here suppresses the base's
	ship = p_ship


func header_text() -> String:
	var income := Research.income_per_day()
	var earning := "[color=#%s]nothing is earning yet[/color]" % UiTheme.DIM.to_html(false)
	if income > 0.0:
		earning = "[color=#%s]collection earns[/color] +%.2f / day" % [
			UiTheme.DIM.to_html(false), income]
	return "[right][b][color=#%s]INSIGHT %d[/color][/b]     %s     [color=#%s]%s — %s[/color][/right]" % [
		UiTheme.AMBER.to_html(false), int(Research.insight), earning,
		UiTheme.DIM.to_html(false), GameClock.label(), GameClock.cadence_text()]


func fill_list() -> void:
	section("YOUR COLLECTION")
	if Research.recovered.is_empty():
		empty_row("— nothing recovered yet — artifacts are found, never bought —")
	for id in Research.recovered:
		var art: Dictionary = Research.ARTIFACTS[id]
		row("   ✦ %s" % short(str(art.name)), "a:" + str(id), "artifact",
			{"art": art}, UiTheme.AMBER)

	# The archive: a THING, so its action has something to sit on.
	var aboard := int(ship.commodities.get("scan_data", 0))
	row("   ▤ Scan Data archive   %d aboard" % aboard, "archive", "archive", {},
		UiTheme.ACCENT if aboard > 0 else UiTheme.DIM)

	section("EXPEDITION LEADS")
	var leads: Array = Research.log_entries(ship)
	if leads.is_empty():
		empty_row("— no leads — rumours travel on dockhands' lips —")
	for e in leads:
		row("   ◈ %s" % short(str(e.title)), "r:" + str(e.id), "lead",
			{"entry": e, "key": MissionTracker.lead_key(str(e.id))}, UiTheme.ACCENT)

	for tree in Research.TREES:
		section(str(tree.name).to_upper())
		for node in tree.nodes:
			var id := str(node.id)
			var researched := Research.is_unlocked(id)
			var txt := "   ✓ %s" % short(str(node.name)) if researched \
				else "   %s   %d Insight" % [short(str(node.name)), int(node.cost)]
			var tint := UiTheme.DIM
			if researched:
				tint = Color(0.45, 0.75, 0.5)
			elif Research.blocker(id) == "":
				tint = UiTheme.AMBER          # researchable RIGHT NOW
			row(txt, "t:" + id, "node", {"node": node, "tree": str(tree.name)}, tint)


func render_detail(md: Dictionary) -> void:
	match str(md.get("kind", "")):
		"artifact": _detail_artifact(md.art)
		"archive": _detail_archive()
		"lead": _detail_lead(md)
		"node": _detail_node(md)


func _detail_artifact(art: Dictionary) -> void:
	title("✦ %s" % str(art.name), UiTheme.AMBER)
	note(str(art.desc), true)
	stat("Yields", "1 Insight every %s, forever" % _rate_text(int(art.rate_days)))
	note("Installed in the lab. Nothing to do — it simply pays, every day you dock.")


## Scan Data: the cargo-to-Insight loop, with the trade-in ON the readings. An empty
## hold is the teaching state, not an error — the row says what filing would do.
func _detail_archive() -> void:
	var aboard := int(ship.commodities.get("scan_data", 0))
	title("Scan Data archive")
	note("Readings filed with the lab. Dex pays in Insight; Cartographer Sella pays in credits for the same data — your call which you need more.", true)
	stat("Aboard", "%d" % aboard)
	stat("Rate", "+%d Insight each" % Research.SCAN_DATA_INSIGHT)
	var stop := "" if aboard > 0 \
		else "Nothing to file — survey something with a scanner fitted and [1]."
	action("Archive %d — +%d Insight" % [aboard, aboard * Research.SCAN_DATA_INSIGHT],
		stop, func() -> void: archive_requested.emit())


func _detail_lead(md: Dictionary) -> void:
	var e: Dictionary = md.entry
	title("◈ %s" % str(e.title), UiTheme.ACCENT)
	who(str(e.get("giver_id", "")), str(e.get("giver", "")).to_upper())
	if str(e.get("body", "")) != "":
		note(str(e.body), true)
	for s in e.get("done", []):
		step_line(str(s), true)
	if str(e.get("current", "")) != "":
		step_line(str(e.current))
	if str(e.get("rewards", "")) != "":
		stat("Reward", str(e.rewards))
	note("Followed in flight — the chart marks the way, and this updates as you go.")
	# No ▲▼ here: ordering objectives against each other is a job for the screen that
	# lists them all. On its own page a lead is read, not ranked.
	curation(str(md.get("key", "")), false)


func _detail_node(md: Dictionary) -> void:
	var node: Dictionary = md.node
	var id := str(node.id)
	var researched := Research.is_unlocked(id)
	title(str(node.name), UiTheme.AMBER if not researched else Color(0.45, 0.75, 0.5))
	note(str(node.desc), true)
	stat("Tree", str(md.get("tree", "")))
	if researched:
		stat("Status", "researched")
		return
	stat("Cost", "%d Insight" % int(node.cost))
	if str(node.requires) != "":
		stat("Requires", str(Research.find_node(str(node.requires)).get("name", node.requires)))
	action("Research — %d Insight" % int(node.cost), Research.blocker(id),
		func() -> void: research_requested.emit(id))


static func _rate_text(days: int) -> String:
	return "day" if days == 1 else "%d days" % days
