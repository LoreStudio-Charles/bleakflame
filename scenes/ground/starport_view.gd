class_name StarportView
extends CanvasLayer
## The STARPORT counter — the last planetside service to leave the docking panel (user,
## 2026-07-25: "nothing on the ground should use the docking panel anymore"). The
## spatialized dock was the TRANSITION scaffolding that let the ground exist at all; this
## completes the move off it.
##
## Deliberately small, because landing already DID the work: ship.dock() repairs, restocks
## and checkpoints on touchdown. This is the RECEIPT and the ship's state — the part of
## the old Landing Pad overview a walking pilot still needs. Everything else moved:
## trading = the MARKET shop, contracts = the BOARD, talks = the people, launch = your
## ship on the pad, pilot/ship detail = [P].
##
## Same contract as ShopView/BoardView: thin, self-contained, owns Esc, frees itself.

signal closed
signal launch_requested   # the Lift off button — the services desk can send you up

var ship   # duck-typed TestShip: build/hull/armor/shield/stats/dock_bill

var _note: RichTextLabel


func _init(p_ship) -> void:
	ship = p_ship
	layer = 26


func _ready() -> void:
	add_to_group("esc_capture")
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -230
	panel.offset_bottom = 230
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.BG, 0.99)
	style.border_color = UiTheme.AMBER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var head := Label.new()
	head.text = "STARPORT — LANDING SERVICES"
	head.add_theme_font_size_override("font_size", 17)
	head.add_theme_color_override("font_color", UiTheme.AMBER)
	root.add_child(head)

	_note = RichTextLabel.new()
	_note.bbcode_enabled = true
	_note.fit_content = true
	_note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_note)
	_note.text = _sheet()

	# LAUNCH lives here too (user: landing left no way up from the services desk) —
	# same gate as walking to your ship and pressing [E].
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	root.add_child(buttons)
	var lift := Button.new()
	lift.text = "Lift off — return to space"
	UiTheme.button_flavor(lift, "primary")
	lift.pressed.connect(func() -> void: launch_requested.emit())
	buttons.add_child(lift)
	var leave := Button.new()
	leave.text = "Back to the pad   [Esc]"
	UiTheme.button_flavor(leave, "tertiary")
	leave.pressed.connect(close)
	buttons.add_child(leave)


func _sheet() -> String:
	var out := ""
	if ship != null and ship.get("build") != null:
		var hull_name: String = str(ship.build.hull.display_name)
		out += "[b][color=#f2b859]%s[/color][/b] — berthed on the colony pad\n\n" % hull_name
		out += "[color=#8fe08f]Hull %d / %d      Armor %d / %d      Shield %d / %d[/color]\n" % [
			int(ship.hull), int(ship.stats.hull_hp), int(ship.armor), int(ship.stats.armor_hp),
			int(ship.shield), int(ship.stats.shield_hp)]
		out += "[color=#73bff2]Energy topped — the pad feeds the bus while you're down.[/color]\n\n"
		# The landing receipt: what touchdown already billed (ship.dock() pays it).
		var bill: Dictionary = ship.get("dock_bill") if ship.get("dock_bill") != null else {}
		var repairs := int(bill.get("repairs", 0))
		var ammo := int(bill.get("ammo", 0))
		if repairs > 0 or ammo > 0:
			out += "[b]LANDING RECEIPT[/b]\n"
			if repairs > 0:
				out += "  Repairs — [color=#f2b859]%dc[/color]\n" % repairs
			if ammo > 0:
				out += "  Munitions restock — [color=#f2b859]%dc[/color]\n" % ammo
		else:
			out += "[color=#8890a0]No repairs needed — she came down clean.[/color]\n"
		out += "\n[color=#8890a0]credits %dc[/color]\n\n" % Wallet.credits
	out += "[i][color=#a8b0c2]Repairs and restock happen automatically on touchdown. "
	out += "Trade at the MARKET, take work off the CONTRACT BOARD, and your ship "
	out += "waits on the pad — press [E] beside her to lift off.[/color][/i]"
	return out


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == Keys.MENU:
		close()


func close() -> void:
	closed.emit()
	queue_free()
