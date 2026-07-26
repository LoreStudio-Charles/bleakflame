extends SceneTree
## NO CONVERSATION EVER REPLAYS ITSELF — for EVERY talk stage of EVERY quest.
##   godot --headless --path . --script res://tools/test_talk_loops.gd
##
## THE BUG CLASS (playtest 2026-07-25): the Counter said "Thirty years..." twice on the
## ground and Odessa repeated a line at the dock. Both surfaces drain queued talks in a
## loop — finish one, ask "what else does this person have for me", show the next — and
## `check_new_work` re-queues an ACTIVE talk stage's conversation. So a stage that fails
## to advance hands the SAME talk straight back to the loop, forever.
##
## Two people found it in play, in two different systems, on the same day. That is the
## signature of a class rather than a bug, so this walks the whole campaign and replays
## the exact sequence both loops perform, for every talk stage that exists.
##
## Model layer only: quests.gd is deliberately SaveGame- and UI-free, so this runs under
## --script with no autoloads.

func _init() -> void:
	var failures := 0
	var checked := 0

	for q in Quests.QUESTS:
		var qid := str(q.get("id", ""))
		var stages: Array = q.get("stages", [])
		for i in stages.size():
			var st: Dictionary = stages[i]
			if str(st.get("kind", "")) != "talk":
				continue
			var npc := str(st.get("npc", ""))
			var is_station: bool = str(st.get("venue", "station")) == "station"

			# Stand the quest up ON this talk stage, exactly as play would leave it.
			Quests.reset()
			Quests.active[qid] = {"stage": i, "count": 0}
			Quests.pending_talks.clear()
			Quests.on_dock(is_station, null, true)

			var queued: Array = Quests.talks_for(npc)
			if queued.is_empty():
				continue      # nothing queues here (a stage may present another way)
			checked += 1
			var shown: Dictionary = queued[0]

			# --- the exact sequence both drains perform ---
			Quests.take_talk(npc)                       # present it
			if shown.has("advance"):
				Quests.advance_talk(str(shown.advance))  # player finished it
			Quests.on_dock(is_station, null, true)       # "anything else?" — the real drain

			for again in Quests.talks_for(npc):
				if _same(again, shown):
					print("FAIL: %s stage %d (%s) REPLAYS after being finished" % [qid, i, npc])
					failures += 1
					break

			# The stage must also have MOVED. A stage that silently refuses to advance is
			# the root cause the replay guard only papers over — catch it here too.
			if shown.has("advance") and Quests.active.has(qid) \
					and int(Quests.active[qid].get("stage", i)) == i:
				print("FAIL: %s stage %d (%s) did not advance when its talk finished" % [qid, i, npc])
				failures += 1

	Quests.reset()
	print("talk stages exercised: %d" % checked)
	if checked == 0:
		print("FAIL: no talk stage was exercised — this suite is VACUOUS and proves nothing")
		failures += 1
	if failures == 0:
		print("test_talk_loops: ALL PASS")
		quit(0)
	else:
		print("test_talk_loops: %d FAILURE(S)" % failures)
		quit(1)


## Same conversation? Compared on quest + opening line, not identity — the talk
## dictionary is rebuilt each time it is queued.
func _same(a: Dictionary, b: Dictionary) -> bool:
	if str(a.get("quest", "")) != str(b.get("quest", "")):
		return false
	var at := str(a.get("text", "")) + str(a.get("nodes", {}).get("start", {}).get("text", ""))
	var bt := str(b.get("text", "")) + str(b.get("nodes", {}).get("start", {}).get("text", ""))
	return at == bt
