extends Node
## Declarative tutor engine (Tutor.observe + predicates). The whole point of the
## engine is robustness, so this pins the mechanics that the old imperative path
## kept getting wrong: a lesson ARMS when its condition holds, COMPLETES when a
## poll goes true, never re-arms once seen, and (for a resumed lesson) AUTO-SKIPS
## steps already satisfied. Run AS A SCENE (Tutor reaches Sfx, so it needs autoloads).

var _fails := 0


func _ready() -> void:
	_arm_and_complete_by_condition()
	_no_rearm_once_seen()
	_auto_skip_satisfied_steps()
	_multistep_advances_past_satisfied_middle_step()
	if _fails == 0:
		print("test_tutor: ALL PASS")
	get_tree().quit(1 if _fails > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		print("FAIL: " + msg)


func _fresh() -> void:
	Tutor.reset()
	Tutor.seen.clear()
	Tutor.safe = true
	Tutor.context = "flight"
	Tutor.venue = ""


# A lesson arms when its predicate is true, and completes when a POLLED condition
# flips — no note() call anywhere.
func _arm_and_complete_by_condition() -> void:
	_fresh()
	# 'targeting' arms on a far contact with nothing locked (vitals needs "flying",
	# which we withhold, so only targeting is eligible).
	Tutor.observe({"contact_far": true, "has_target": false})
	_check(Tutor.active == "targeting" or Tutor.pending.has("targeting"),
		"targeting arms on its condition (active=%s)" % Tutor.active)
	# Locking a target satisfies its done predicate — the lesson completes itself.
	Tutor.observe({"contact_far": true, "has_target": true})
	_check(Tutor.seen.has("targeting"), "targeting completes when a target is locked (poll)")


# Once seen, no context ever re-arms it — the source of the "restart every time"
# class of bug.
func _no_rearm_once_seen() -> void:
	_fresh()
	Tutor.seen.append("targeting")
	Tutor.observe({"contact_far": true, "has_target": false})
	_check(Tutor.active != "targeting" and not Tutor.pending.has("targeting"),
		"a seen lesson never re-arms")


# The robustness win: a lesson whose EARLY steps are already satisfied resumes on
# the correct step instead of restarting or jamming. We simulate with 'targeting'
# by pre-satisfying its (only) step's poll: it must retire immediately, not stick.
func _auto_skip_satisfied_steps() -> void:
	_fresh()
	# Force targeting active, but the world already shows a locked target — its
	# done predicate is already true, so observe must complete it at once.
	Tutor.active = "targeting"
	Tutor.step = 0
	Tutor.observe({"has_target": true})
	_check(Tutor.active == "" and Tutor.seen.has("targeting"),
		"an active step whose poll is already true completes instantly (auto-skip)")


# A MULTI-STEP lesson advances past a satisfied middle step and stops at the first
# UN-satisfied one — the cross-step version of the resume that fixes the old
# starve/restart class. buy_scanner step 1 ("bought") is satisfied by knowing scan;
# step 2 ("open Engineering") is a tab poll we don't satisfy, so it must halt there.
func _multistep_advances_past_satisfied_middle_step() -> void:
	_fresh()
	Tutor.context = "dock"
	Tutor.venue = "station"
	Tutor.active = "buy_scanner"
	Tutor.step = 1
	Tutor.observe({"knows_scan": true})
	_check(Tutor.active == "buy_scanner" and Tutor.step == 2,
		"a satisfied middle step auto-advances; an unsatisfied one halts (got step %d)" % Tutor.step)
