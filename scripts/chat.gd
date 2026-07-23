class_name Chat
## The comm net — the seam multiplayer chat will plug into, built single-player
## first so the terminal, channels and command parsing all exist and are usable
## before there is a second pilot to talk to.
##
## Everything here is LOCAL today: `post()` appends to a ring buffer the cockpit
## terminal draws. When netcode lands, the host becomes the authority — remote
## lines arrive by calling post() exactly as local ones do, and `send()` is the
## one function that grows a network path. Nothing else needs to change.
##
## COOP NOTE: history is deliberately per-session and NOT saved. Chat is
## conversation, not progress, and persisting it would make the save file grow
## without bound.

const MAX_LINES := 60

## Channels a pilot can talk on. `cmd` is what they type; `tag` is the prefix
## drawn in the log; `color` tints the whole line so a channel is recognisable
## before it is read.
const CHANNELS := [
	{"cmd": "sys", "tag": "SYS", "name": "System Space",
		"color": Color(0.42, 0.98, 0.55), "desc": "everyone in the system"},
	{"cmd": "g", "tag": "GRP", "name": "Group",
		"color": Color(0.55, 0.80, 1.00), "desc": "your wing"},
]

const DEFAULT_CHANNEL := "sys"

## TRUE while the pilot is typing. The ship polls Input.is_action_pressed every
## physics frame, which a focused LineEdit does NOT suppress — without this gate
## typing "w" would fire the thrusters. Every control read checks it.
static var typing := false

static var lines: Array[Dictionary] = []
static var channel := DEFAULT_CHANNEL


static func channel_def(cmd: String) -> Dictionary:
	for c in CHANNELS:
		if c.cmd == cmd:
			return c
	return {}


static func is_channel(cmd: String) -> bool:
	return not channel_def(cmd).is_empty()


## Append a line to the log. Remote pilots will arrive through here untouched.
static func post(text: String, from := "", chan := "") -> void:
	var c: String = chan if is_channel(chan) else channel
	lines.append({"chan": c, "from": from, "text": text})
	while lines.size() > MAX_LINES:
		lines.pop_front()


## System notice — no speaker, used for command feedback and errors.
static func notice(text: String) -> void:
	lines.append({"chan": "", "from": "", "text": text})
	while lines.size() > MAX_LINES:
		lines.pop_front()


## Handle one line of pilot input. A leading slash is a COMMAND: either a
## channel switch ("/g"), or a channel switch plus a message in one go
## ("/g forming up"), which is how chat has worked since IRC and is what a
## player's hands already expect. Anything else is talk on the current channel.
static func submit(raw: String) -> void:
	var text := raw.strip_edges()
	if text.is_empty():
		return
	if not text.begins_with("/"):
		_say(text)
		return

	var body := text.substr(1)
	var space := body.find(" ")
	var cmd := body if space < 0 else body.substr(0, space)
	var rest := "" if space < 0 else body.substr(space + 1).strip_edges()
	cmd = cmd.to_lower()

	if cmd == "help" or cmd == "?":
		var parts := PackedStringArray()
		for c in CHANNELS:
			parts.append("/%s (%s)" % [c.cmd, c.desc])
		notice("Channels: " + ", ".join(parts))
		return
	if is_channel(cmd):
		channel = cmd
		if rest.is_empty():
			notice("Now speaking on %s." % str(channel_def(cmd).name))
		else:
			_say(rest)
		return
	notice("Unknown command \"/%s\" — try /help." % cmd)


static func _say(text: String) -> void:
	# Single-player: your own voice comes straight back, so the loop is testable
	# now. Networked, this is where the message goes to the host instead.
	post(text, Pilot.handle(), channel)


static func reset() -> void:
	lines.clear()
	channel = DEFAULT_CHANNEL
	typing = false
