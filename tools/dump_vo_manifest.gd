extends SceneTree
## One-shot: emit tools/vo_manifest.json = {stem: {voice, text}} for every
## spoken campaign line, matching the DialoguePanel vo-stem scheme:
##   odessa_bar_<node>              (Odessa's bar)
##   <quest>_<node>                 (talk-stage / goto-dialogue conversations)
##   <quest>_briefing / _debrief    (giver hand-out & completion)
## `text` is QUOTED SPEECH ONLY — the stage-direction prose between the
## quotes is stripped, so the voice speaks only the character's words.
## Run: <godot> --headless --path . --script res://tools/dump_vo_manifest.gd

func _init() -> void:
	var m := {}
	for key in Dialogues.ODESSA_BAR:
		m["odessa_bar_" + key] = {"voice": "odessa",
			"text": _spoken(str(Dialogues.ODESSA_BAR[key]["text"]))}
	for q in Quests.QUESTS:
		var qid := str(q["id"])
		var giver := str(q["giver"])
		if q.has("briefing"):
			m[qid + "_briefing"] = {"voice": giver, "text": _spoken(str(q["briefing"]))}
		if q.has("debrief"):
			m[qid + "_debrief"] = {"voice": giver, "text": _spoken(str(q["debrief"]))}
		for st in q["stages"]:
			if st.has("dialogue"):
				var npc := str(st.get("npc", giver))
				for key in st["dialogue"]:
					m[qid + "_" + key] = {"voice": npc,
						"text": _spoken(str(st["dialogue"][key]["text"]))}
	var f := FileAccess.open("res://tools/vo_manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(m, "\t"))
	f.close()
	print("VO manifest: %d lines" % m.size())
	quit()


## Keep only the double-quoted spans (the spoken words); drop the prose.
func _spoken(text: String) -> String:
	var parts := text.split("\"")
	var out := ""
	var i := 1
	while i < parts.size():
		out += parts[i].strip_edges() + " "
		i += 2
	return out.strip_edges()
