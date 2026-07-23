extends SceneTree
## CAMPAIGN VALIDATOR — idiot-proofs the quest chain (user, 2026-07-23).
##
## The class of bug this exists to kill: ember_word froze the campaign for ~46
## game-days, and the_hermit was a dead-end (its giver stood at the destination,
## so the quest that says "go to the planet" couldn't start until you were
## already there). Both were invisible until a real playthrough. This encodes
## the rules so the next bad beat fails HERE, at author time.
##
## --script safe (quests.gd / npcs.gd pull in no autoloads). Run:
##   <godot> --headless --path . --script res://tools/test_campaign.gd

var fails: Array[String] = []


func _init() -> void:
	var quests: Array = Quests.QUESTS
	var ids := {}
	for q in quests:
		ids[str(q.id)] = q

	for q in quests:
		_check_quest(q, ids)

	_check_reachable(quests, ids)

	if fails.is_empty():
		print("test_campaign: ALL PASS (%d beats)" % quests.size())
	else:
		for f in fails:
			printerr("  FAIL: " + f)
		printerr("test_campaign: %d FAILURES" % fails.size())
	quit(0 if fails.is_empty() else 1)


func _venue(npc: String) -> String:
	return str(Npcs.CAST.get(npc, {}).get("venue", ""))


func _check_quest(q: Dictionary, ids: Dictionary) -> void:
	var id := str(q.id)
	var giver := str(q.get("giver", ""))

	# --- Identity & requires integrity ---
	if not Npcs.CAST.has(giver):
		_fail("%s: giver '%s' is not a real NPC" % [id, giver])
	var req := str(q.get("requires", ""))
	if req != "" and not ids.has(req):
		_fail("%s: requires unknown quest '%s'" % [id, req])

	# --- Stages are well-formed & point somewhere real ---
	var stages: Array = q.get("stages", [])
	if stages.is_empty() and not q.get("manual_start", false):
		_fail("%s: has no stages" % id)
	for i in stages.size():
		var st: Dictionary = stages[i]
		var kind := str(st.get("kind", ""))
		if str(st.get("step", "")) == "":
			_fail("%s stage %d: no `step` text (the through-line shows this)" % [id, i])
		match kind:
			"talk", "report":
				if kind == "talk" and not Npcs.CAST.has(str(st.get("npc", ""))):
					_fail("%s stage %d: talk npc '%s' is not real" % [id, i, str(st.get("npc", ""))])
				var v := str(st.get("venue", ""))
				if v != "" and v not in ["station", "planet", "shoal", "verge"]:
					_fail("%s stage %d: illegal venue '%s'" % [id, i, v])
			"goto", "survive_event", "scan_target":
				if not st.has("pos"):
					_fail("%s stage %d (%s): needs a `pos` to fly to" % [id, i, kind])
			"contracts", "reach_gate":
				pass
			_:
				if kind == "":
					_fail("%s stage %d: no `kind`" % [id, i])

	# --- THE BREADCRUMB RULE (the ember_word/hermit class) ---
	# A quest is HANDED to you at its giver's venue. So when quest B requires A,
	# B must be able to start where A leaves you — i.e. B's giver stands at the
	# same venue as A's giver (seamless hand-off at that dock). If B's giver is
	# NOT dockside (a relay giver like Krayt at the Shoal), it starts anywhere and
	# is fine. Manual-start quests are sprung by script, not a dock.
	if req == "" or q.get("manual_start", false):
		return
	if not Npcs.is_dockside(giver):
		return
	var a: Dictionary = ids.get(req, {})
	var a_venue := _venue(str(a.get("giver", "")))
	var b_venue := _venue(giver)
	if a_venue != "" and b_venue != "" and a_venue != b_venue:
		_fail(("%s: BREADCRUMB GAP — giver %s stands at the %s, but its prereq " +
			"'%s' completes at the %s. It can never auto-start where you finish " +
			"'%s', so nothing sends you on. Make the giver whoever HANDS the lead " +
			"at the %s (the talk npc can still be at the %s).") % [
			id, giver, b_venue, req, a_venue, req, a_venue, b_venue])


## Every non-start quest must trace back to a requires="" root (no orphan behind
## a broken chain), and no cycles.
func _check_reachable(quests: Array, ids: Dictionary) -> void:
	for q in quests:
		var seen := {}
		var cur := str(q.get("requires", ""))
		var ok := cur == ""
		while cur != "":
			if seen.has(cur):
				_fail("%s: requires CYCLE through '%s'" % [str(q.id), cur])
				break
			seen[cur] = true
			if not ids.has(cur):
				break     # already reported as unknown-requires
			var nxt := str(ids[cur].get("requires", ""))
			if nxt == "":
				ok = true
				break
			cur = nxt
		if not ok and not q.get("manual_start", false):
			_fail("%s: not reachable from a start quest (requires chain is broken)" % str(q.id))


func _fail(msg: String) -> void:
	fails.append(msg)
