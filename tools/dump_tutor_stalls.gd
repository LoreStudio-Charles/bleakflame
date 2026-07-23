extends SceneTree
## REVIEW THE TUTOR'S OWN BUG LIST.
##
## The watchdog retires any lesson that jams and records WHERE it stuck into the
## save (Tutor.stalls). This prints that log as a ranked table — the tutor
## telling you, from real playthroughs, which lessons failed and where.
##
## Reads the save JSON DIRECTLY rather than through SaveGame, so it needs no
## autoloads and cannot be broken by the Sfx-dependency that keeps other classes
## out of `--script` mode:
##   <godot> --headless --path . --script res://tools/dump_tutor_stalls.gd
##
## A row here is a to-do: high `count` = players hit it often, so fix it first.
## After fixing, the row simply stops growing; clear the log by wiping the save.

const SAVE := "user://bleakflame_save.json"


func _init() -> void:
	if not FileAccess.file_exists(SAVE):
		print("No save yet (%s) — nothing to review." % SAVE)
		quit()
		return
	var f := FileAccess.open(SAVE, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		print("Save is not readable JSON.")
		quit()
		return

	var rows: Array = data.get("tutor_stalls", [])
	if rows.is_empty():
		print("No tutor stalls recorded. The tutor has never had to abandon a lesson. 🎉")
		quit()
		return

	# Worst offenders first.
	rows.sort_custom(func(a, b): return int(a.get("count", 0)) > int(b.get("count", 0)))

	print("\n  TUTOR STALL LOG — lessons the watchdog had to abandon")
	print("  (each row is a lesson that could not complete for a real player)\n")
	print("  %-18s %-4s %-22s %-8s %-6s %s" % [
		"LESSON", "STEP", "ANCHOR", "VENUE", "COUNT", "LAST DAY"])
	print("  " + "-".repeat(76))
	var total := 0
	for r in rows:
		total += int(r.get("count", 0))
		print("  %-18s %-4d %-22s %-8s %-6d day %d" % [
			str(r.get("lesson", "?")), int(r.get("step", 0)),
			str(r.get("anchor", "?")), str(r.get("venue", "any")),
			int(r.get("count", 0)), int(r.get("last_day", 0))])
	print("\n  %d distinct stall sites, %d total abandonments.\n" % [rows.size(), total])
	quit()
