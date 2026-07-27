extends Node
## THE SAVE GUARD — a test must never overwrite the pilot somebody is playing.
##
## FOUND 2026-07-27 by checksumming the save file around every suite: FOUR tests were
## quietly writing it (test_ground_landing, test_lane_traffic, test_prompt_onscreen and
## test_ranks_in_world), because all four boot the REAL flight scene and the real flight
## scene checkpoints — on touchdown, and when the tutorial pays out its licence. Every one
## of them had carefully avoided calling ship.dock() and was caught by a path it never
## called directly. test_ground_landing's own header says it skips dock() "because that
## would write the save", and it wrote the save.
##
## The guard lives at the single door every write goes through, so the FIFTH test to be
## written is protected by default rather than by remembering. This asserts the door is
## still shut.
##
##   <godot> --headless --path . res://tools/test_save_guard.tscn --quit-after 300

var _fails: Array[String] = []
var _checks := 0


func _ready() -> void:
	var path := "user://bleakflame_save.json"
	var before := _stamp(path)

	SaveGame.read_only = true
	var blocked_before: int = SaveGame._blocked
	# A null ship is fine BECAUSE the guard returns before anything touches it — which is
	# itself part of the claim. If the early return ever moves below the first `ship` read
	# this call starts erroring instead of passing quietly.
	SaveGame.save_game(null)
	SaveGame.save_game(null)
	_ok(SaveGame._blocked >= blocked_before + 2,
		"read_only intercepts the write (blocked %d -> %d)"
			% [blocked_before, SaveGame._blocked])
	_ok(_stamp(path) == before, "...and the save file on disk is untouched")

	# It must be the DOOR that is shut, not the callers that are polite: the flight scene
	# saves from three different places (dock, character creation, the tutorial payout).
	SaveGame.read_only = false
	_ok(not SaveGame.read_only, "the guard can be lifted again for the real game")

	if _fails.is_empty():
		print("test_save_guard: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_save_guard: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


## Size + modified time — enough to catch a rewrite without reading the pilot's contents
## into a test's memory. Returns "" when there is no save yet, which is a fine baseline.
func _stamp(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return "%d:%d" % [FileAccess.get_modified_time(path),
		FileAccess.open(path, FileAccess.READ).get_length()]


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)
