extends SceneTree
## Headless smoke test for the Comms inbox:
##   godot --headless --path . --script res://tools/test_comms.gd

func _init() -> void:
	var failures := 0
	Comms.reset()

	if Comms.unread() != 0 or not Comms.messages.is_empty():
		print("FAIL: fresh inbox should be empty")
		failures += 1

	Comms.post("ruel", "Standing With the Board", "Board's got work. Run a couple.")
	Comms.post("voss", "Overdue", "No debris. Pirates leave debris.")
	if Comms.messages.size() != 2 or Comms.unread() != 2:
		print("FAIL: posting did not add unread messages")
		failures += 1

	Comms.mark_read(0)
	if Comms.unread() != 1:
		print("FAIL: mark_read did not drop the unread count")
		failures += 1
	Comms.mark_all_read()
	if Comms.unread() != 0:
		print("FAIL: mark_all_read left unread messages")
		failures += 1

	# Save round-trip preserves order, content, and read state.
	Comms.post("krayt", "Nothing Left Behind", "...wake it and GO.")
	var snap := Comms.to_dict()
	Comms.reset()
	Comms.from_dict(snap)
	if Comms.messages.size() != 3 or Comms.messages[2].from != "krayt" \
			or Comms.unread() != 1 or Comms.messages[0].read != true:
		print("FAIL: comms save round-trip lost state")
		failures += 1
	# Corrupt/empty load is safe.
	Comms.from_dict({})
	if not Comms.messages.is_empty():
		print("FAIL: empty load should clear the inbox")
		failures += 1

	Comms.reset()
	if failures == 0:
		print("test_comms: ALL PASS")
	else:
		print("test_comms: %d FAILURES" % failures)
	quit(failures)
