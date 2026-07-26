class_name OrivelDock
extends CanvasLayer
## ORIVEL ORBITAL OUTPOST — the capital's berth screen. Minimal + bespoke (same
## reasoning as the Speak's Easy / The Dig): DockScreen's is_station flag threads
## through its whole build, and Orivel has no fringe economy or NPCs to show. The
## berth still repairs + tops the bus + checkpoints through ship.dock(); this just
## shows the receipt and which berth you took. Full capital services (a shipyard
## for the super-heavies, quartermaster, commissions) light up in a later pass.

var ship: TestShip
var _body: RichTextLabel


func _init(p_ship: TestShip) -> void:
	ship = p_ship
	layer = 5
	visible = false


func _ready() -> void:
	add_to_group("dock_screens")
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.08, 1.0)   # capital ivory-on-deep-blue
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 26
	panel.offset_top = 26
	panel.offset_right = -26
	panel.offset_bottom = -26
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)

	var head := Label.new()
	head.text = "ORIVEL ORBITAL OUTPOST — Capital Drydock Ring        [E] launch"
	head.add_theme_font_size_override("font_size", 17)
	head.add_theme_color_override("font_color", UiTheme.AMBER)
	root.add_child(head)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_body)


## REFRESHES WHAT IS ALREADY ON SCREEN — it must never be what PUTS it there.
##
## THE BUG (2026-07-26, user): this used to open with `visible = true`, and this
## screen is in group "dock_screens". Every background payout broadcasts
## `call_group("dock_screens", "refresh")` — that is the documented convention —
## so `/cash` from anywhere in the system threw the capital berth screen over the
## cockpit. It could not be dismissed either: [E] only launches you from a berth
## you are actually in, so a pilot in open space was simply trapped.
##
## Visibility is owned by the DOCKED-STATE TICK (flight_test sets
## `orivel_screen.visible` from `_outpost.pads.has(ship.docked_at)` and only then
## calls refresh). So `visible = true` here was redundant on every legitimate path
## and load-bearing only for the bug. Guard exactly like ProspectDeck.refresh.
func refresh() -> void:
	if not visible:
		return
	var berth := ""
	if ship.docked_at is DockingPad:
		berth = (ship.docked_at as DockingPad).berth_label
	var bill: Dictionary = ship.dock_bill if ship.dock_bill != null else {}
	var repairs := int(bill.get("repairs", 0))
	var ammo := int(bill.get("ammo", 0))

	var lines := PackedStringArray()
	lines.append("[color=#cfe6ff]Berthed:[/color]  %s" % (berth if berth != "" else "—"))
	lines.append("")
	if repairs > 0 or ammo > 0:
		lines.append("[color=#9fddc0]The bay serviced your hull.[/color]   Repairs %dc    Ordnance %dc" % [repairs, ammo])
	else:
		lines.append("[color=#9fddc0]Hull nominal — nothing to mend.[/color]")
	lines.append("Reactor bus topped off. Progress checkpointed.")
	lines.append("")
	lines.append("[color=#8aa6bb]The capital's yards stand ready but unstaffed. Shipyard, quartermaster and commissions are coming online.[/color]")
	lines.append("")
	lines.append("[color=#ffd27f]LANDING BAYS[/color] take hulls up to HEAVY (64px).   [color=#ffd27f]DRYDOCKS[/color] cradle only the capital-scale hulls a bay can't hold.")
	lines.append("")
	lines.append("[color=#8aa6bb]Press [E] to launch.[/color]")
	_body.text = "\n".join(lines)
