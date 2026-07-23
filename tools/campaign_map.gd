extends SceneTree
## CAMPAIGN MAP — the boxes-and-arrows view of the story graph (user, 2026-07-23).
##
## The companion to test_campaign.gd: the validator SAYS a beat is sound, this
## SHOWS you the whole chain so a gap is obvious at a glance — beats as boxes,
## `requires` as arrows, each box stamped with WHO hands it to you and WHERE.
## Built from the live Quests.QUESTS, so it can never drift from the real chain.
##
## Emits a Mermaid flowchart (paste into any Mermaid renderer, a Markdown file,
## or a Bleakflame artifact) plus a plain-text spine for the terminal. Run:
##   <godot> --headless --path . --script res://tools/campaign_map.gd
## Mermaid-only (redirect to a .md/.mmd):
##   <godot> --headless --path . --script res://tools/campaign_map.gd -- --mermaid

const VENUE_ICON := {
	"station": "🛰", "planet": "🪐", "shoal": "☠", "verge": "⛏",
}


func _init() -> void:
	var mermaid_only := "--mermaid" in OS.get_cmdline_user_args()
	var quests: Array = Quests.QUESTS
	var ids := {}
	for q in quests:
		ids[str(q.id)] = q

	if not mermaid_only:
		_print_spine(quests, ids)
		print("")
	_print_mermaid(quests, ids)
	quit(0)


func _venue(npc: String) -> String:
	return str(Npcs.CAST.get(npc, {}).get("venue", ""))


## Where the beat sends you — the first stage that names a place (the breadcrumb
## destination), else the giver's own venue (a here-at-the-dock beat).
func _destination(q: Dictionary) -> String:
	for st in q.get("stages", []):
		var v := str(st.get("venue", ""))
		if v != "":
			return v
		if st.has("pos"):
			return "open space"
	return _venue(str(q.get("giver", "")))


func _print_spine(quests: Array, ids: Dictionary) -> void:
	print("═══ CAMPAIGN SPINE ═══  (giver @ venue  →  sends you to)")
	# print in requires-depth order so the through-line reads top to bottom
	var ordered := _in_order(quests, ids)
	for q in ordered:
		var giver := str(q.get("giver", ""))
		var venue := _venue(giver)
		var tag := ""
		if q.get("manual_start", false):
			tag = "  [manual — script-sprung]"
		elif not Npcs.is_dockside(giver):
			tag = "  [relay — starts anywhere]"
		print("  ● %-22s  %s@%-8s → %s%s" % [
			str(q.get("title", q.id)), giver, venue, _destination(q), tag])


## Beats sorted by how deep their requires-chain runs (roots first).
func _in_order(quests: Array, ids: Dictionary) -> Array:
	var depth := {}
	for q in quests:
		var d := 0
		var cur := str(q.get("requires", ""))
		var guard := 0
		while cur != "" and ids.has(cur) and guard < 64:
			d += 1
			cur = str(ids[cur].get("requires", ""))
			guard += 1
		depth[str(q.id)] = d
	var out: Array = quests.duplicate()
	out.sort_custom(func(a, b): return depth[str(a.id)] < depth[str(b.id)])
	return out


func _print_mermaid(quests: Array, ids: Dictionary) -> void:
	print("```mermaid")
	print("flowchart TD")
	for q in quests:
		var id := str(q.id)
		var giver := str(q.get("giver", ""))
		var venue := _venue(giver)
		var icon := str(VENUE_ICON.get(venue, "•"))
		var label := "%s<br/>%s %s@%s → %s" % [
			str(q.get("title", id)), icon, giver, venue, _destination(q)]
		print("  %s[\"%s\"]" % [id, label])
	print("")
	for q in quests:
		var id := str(q.id)
		var req := str(q.get("requires", ""))
		if req != "" and ids.has(req):
			# solid arrow = auto hand-off; dotted = a venue change the player must
			# be led across (the shape the hermit gap hid in).
			var a_v := _venue(str(ids[req].get("giver", "")))
			var b_v := _venue(str(q.get("giver", "")))
			var dockside := Npcs.is_dockside(str(q.get("giver", "")))
			if dockside and a_v != "" and b_v != "" and a_v != b_v:
				print("  %s -. venue change .-> %s" % [req, id])
			else:
				print("  %s --> %s" % [req, id])
		elif q.get("manual_start", false):
			print("  START_EVENT[\"⚡ script event\"] -.-> %s" % id)
	# roots (no requires) hang off a single START so the entry is obvious
	print("  START([▶ tutorial done]) --> %s" % _first_root(quests))
	print("```")


func _first_root(quests: Array) -> String:
	for q in quests:
		if str(q.get("requires", "")) == "" and not q.get("manual_start", false):
			return str(q.id)
	return str(quests[0].id)
