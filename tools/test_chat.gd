extends SceneTree
## Chat command routing + the DEV-COMMAND GATE.
## The load-bearing guarantee: dev commands are reachable ONLY when a debug build
## registered Chat.dev_command. With no hook (a release export), /cash must fall
## through to "unknown command" — the cheats can never slip into a shipping build.
## --script safe: the paths exercised here never touch an autoload (the dev stub
## returns true, so _say/Pilot is never reached; channel talk is not tested here).

var _seen: Array = []
var _fails := 0


func _init() -> void:
	_no_hook_means_unknown()
	_hook_routes_dev_commands()
	_help_lists_dev_summary_only_with_hook()
	_channel_switch_still_works()
	if _fails == 0:
		print("test_chat OK")
	quit(1 if _fails > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		print("FAIL: " + msg)


func _last_notice() -> String:
	# notice() posts a line with an empty speaker.
	for i in range(Chat.lines.size() - 1, -1, -1):
		if str(Chat.lines[i].get("from", "")).is_empty():
			return str(Chat.lines[i].get("text", ""))
	return ""


# RELEASE BEHAVIOUR: no hook => dev commands are unknown.
func _no_hook_means_unknown() -> void:
	Chat.reset()
	Chat.dev_command = Callable()
	Chat.dev_help = ""
	Chat.submit("/cash 500")
	_check(_last_notice().contains("Unknown command"),
		"no dev hook: /cash must be an unknown command (release safety)")


# DEBUG BEHAVIOUR: a registered hook receives (cmd, rest) and suppresses "unknown".
func _hook_routes_dev_commands() -> void:
	Chat.reset()
	_seen.clear()
	Chat.dev_command = func(cmd: String, rest: String) -> bool:
		_seen.append([cmd, rest])
		return cmd == "cash"
	Chat.submit("/cash 500")
	_check(_seen.size() == 1 and _seen[0][0] == "cash" and _seen[0][1] == "500",
		"hook must receive parsed (cmd, rest): got %s" % str(_seen))
	_check(not _last_notice().contains("Unknown command"),
		"handled dev command must not print 'unknown'")
	# A command the handler declines (returns false) still falls through to unknown.
	Chat.submit("/nope")
	_check(_last_notice().contains("Unknown command"),
		"declined dev command must fall through to 'unknown'")
	Chat.dev_command = Callable()


func _help_lists_dev_summary_only_with_hook() -> void:
	Chat.reset()
	Chat.dev_help = ""
	Chat.submit("/help")
	var without := ""
	for l in Chat.lines:
		without += str(l.get("text", "")) + "\n"
	_check(not without.contains("[dev]"), "/help must not show dev summary with no hook")

	Chat.reset()
	Chat.dev_help = "[dev] /cash [n] /warp <x> <y>"
	Chat.submit("/help")
	var with_hook := ""
	for l in Chat.lines:
		with_hook += str(l.get("text", "")) + "\n"
	_check(with_hook.contains("[dev]"), "/help must show dev summary when hook is live")
	Chat.dev_help = ""


# A dev command name must never shadow a real channel switch.
func _channel_switch_still_works() -> void:
	Chat.reset()
	Chat.dev_command = func(_c: String, _r: String) -> bool: return true  # greedy stub
	Chat.submit("/g")
	_check(Chat.channel == "g",
		"a channel switch must win over the dev hook (channels checked first)")
	Chat.dev_command = Callable()
	Chat.channel = Chat.DEFAULT_CHANNEL
