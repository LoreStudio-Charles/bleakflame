class_name Comms
## The player's message inbox — every mission-important NPC transmission is
## logged here the moment it's delivered, so dismissing a comm NEVER loses
## it. A mailbox badge shows the unread count; the player can re-read any
## message at any time (scenes/ui/comms_inbox.gd, [C] in flight). Static like
## the other session state; persists via SaveGame under "comms".

## Newest last: {from (npc id), name, title, body, read}.
static var messages: Array[Dictionary] = []


## Log a delivered transmission. `from` is an npc id (for the portrait).
static func post(from: String, title: String, body: String) -> void:
	messages.append({"from": from, "name": Npcs.display_name(from),
		"title": title, "body": body, "read": false})
	# The "comms" lesson arms itself off `comms_any` (any message present) via the
	# declarative tutor — no arm() call needed here.


static func unread() -> int:
	var n := 0
	for m in messages:
		if not m.read:
			n += 1
	return n


static func mark_read(index: int) -> void:
	if index >= 0 and index < messages.size():
		messages[index].read = true


static func mark_all_read() -> void:
	for m in messages:
		m.read = true


static func to_dict() -> Dictionary:
	return {"messages": messages.duplicate(true)}


static func from_dict(data: Dictionary) -> void:
	messages.clear()
	for m in data.get("messages", []):
		messages.append({"from": str(m.get("from", "")), "name": str(m.get("name", "")),
			"title": str(m.get("title", "")), "body": str(m.get("body", "")),
			"read": bool(m.get("read", true))})


static func reset() -> void:
	messages.clear()
