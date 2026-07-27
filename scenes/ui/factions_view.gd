class_name FactionsView
extends CanvasLayer
## The FACTIONS & PEACE screen, toggled with [U] (Keys.FACTIONS) — open docked OR in flight
## (declaring war on the wing behind you is legal and inadvisable). Shows each
## combat faction's standing, its derived STATE, and the PEACE toggle: at peace
## a faction is a friendly you can't target; declare war and its ships become
## fair game. The toggle is LOCKED while KoS — mend standing off the floor first.
## First home of the "Pilot menu" that will grow to hold the sheet + skills.

## The factions that field SHIPS — only these get a peace/war toggle. The
## economic guilds show standing (it still gates commissions + prices) but have
## no fleet to declare war on.
const WAR_FACTIONS := ["guardian", "trader", "privateer"]

var ship: TestShip
var _rows: VBoxContainer


func _init(p_ship: TestShip) -> void:
	ship = p_ship
	layer = 13
	visible = false


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.BG, 0.99)
	style.border_color = Color(0.4, 0.62, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(28.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(620, 0)
	panel.add_child(col)

	var title := Label.new()
	title.text = "FACTIONS & PEACE"
	title.add_theme_color_override("font_color", UiTheme.AMBER)
	title.add_theme_font_size_override("font_size", 22)
	col.add_child(title)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	col.add_child(_rows)

	var note := Label.new()
	note.text = "Declaring war makes a faction's ships targetable — and their allies remember it. Peace is locked while they'll kill you on sight. [I]/[Esc] to close."
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", UiTheme.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(note)


func _refresh() -> void:
	if _rows == null:
		return
	for c in _rows.get_children():
		c.queue_free()
	for pd in Professions.visible():
		_rows.add_child(_faction_row(str(pd.id)))
	# The PIRATE faction reputation stays on the menu even though the Privateer
	# COMMISSION is hidden (user, 2026-07-23): a faction and a profession are
	# different things — you can hold standing (and eventually declare war) with the
	# Rust Shoal without the secret commission ever being advertised. This row reads
	# the "privateer" standing but is presented purely as the pirate FACTION and
	# never prints the word "Privateer".
	_rows.add_child(_pirate_row())


func _faction_row(fid: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var pd := Professions.def(fid)
	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := Standing.state(fid)
	var p := Standing.get_points(fid)
	var commission := "   [color=#f2b859]◆ your commission[/color]" if Pilot.profession == fid else ""
	info.text = "[b]%s[/b]  [color=#8890a0]— %s[/color]%s\n[color=%s]%s[/color]   [color=#8890a0]standing %d[/color]   %s" % [
		str(pd.get("name", fid)), Npcs.display_name(str(pd.get("leader", ""))), commission,
		_state_color(st), st.to_upper(), p, _bar(p)]
	row.add_child(info)

	if fid in WAR_FACTIONS:
		var toggle := CheckButton.new()
		toggle.text = "At Peace" if Standing.at_peace(fid) else "At War"
		toggle.button_pressed = Standing.at_peace(fid)
		# THE NAMED PREDICATE, not a second spelling of it. Standing.can_make_peace is
		# what set_peace() enforces; re-deriving it here as is_hostile() made a third
		# copy of one rule, and left can_make_peace looking like dead code.
		toggle.disabled = not Standing.can_make_peace(fid)
		toggle.tooltip_text = "They're hostile — mend standing first" if Standing.is_hostile(fid) \
			else "On = friendly & untargetable · Off = declare war"
		toggle.toggled.connect(func(on: bool) -> void:
			Standing.set_peace(fid, on)
			Sfx.play("click", -10.0, 1.2 if on else 0.7)
			_sync_faction(fid)
			_refresh())
		row.add_child(toggle)
	else:
		var civ := Label.new()
		civ.text = "guild — no fleet"
		civ.add_theme_color_override("font_color", UiTheme.DIM)
		civ.add_theme_font_size_override("font_size", 11)
		row.add_child(civ)
	return row


## The pirate faction's reputation row (standing id "privateer", but presented as
## the Rust Shoal, never the hidden commission). The war toggle self-gates: while
## the pirates are hostile it's disabled ("mend standing first"), so it only
## becomes usable once you're at peace with them — i.e. after the Shoal truce.
func _pirate_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := Standing.state("privateer")
	var p := Standing.get_points("privateer")
	info.text = "[b]The Rust Shoal[/b]  [color=#8890a0]— pirates of the Reach[/color]\n[color=%s]%s[/color]   [color=#8890a0]standing %d[/color]   %s" % [
		_state_color(st), st.to_upper(), p, _bar(p)]
	row.add_child(info)

	var toggle := CheckButton.new()
	toggle.text = "At Peace" if Standing.at_peace("privateer") else "At War"
	toggle.button_pressed = Standing.at_peace("privateer")
	toggle.disabled = Standing.is_hostile("privateer")
	toggle.tooltip_text = "They're hostile — mend standing first" if Standing.is_hostile("privateer") \
		else "On = the truce holds · Off = declare war on the Shoal"
	toggle.toggled.connect(func(on: bool) -> void:
		Standing.set_peace("privateer", on)
		Sfx.play("click", -10.0, 1.2 if on else 0.7)
		_sync_faction("privateer")
		_refresh())
	row.add_child(toggle)
	return row


## Signed reputation bar: a center bar with fill toward the sign.
func _bar(value: int) -> String:
	var half := 9
	var reach := int(round(clampf(float(value) / float(Standing.MAX), -1.0, 1.0) * half))
	var s := ""
	for i in range(-half, half + 1):
		if i == 0:
			s += "|"
		elif reach > 0 and i > 0 and i <= reach:
			s += "▰"
		elif reach < 0 and i < 0 and i >= reach:
			s += "▰"
		else:
			s += "▱"
	var col := "#6de08f" if value > 0 else ("#f25a50" if value < 0 else "#8890a0")
	return "[color=%s]%s[/color]" % [col, s]


func _state_color(state: String) -> String:
	match state:
		"allied": return "#6de08f"
		"friendly": return "#8fe08f"
		"neutral": return "#73bff2"
		"hostile": return "#f2a24a"
		"kos": return "#f25a50"
	return "#8890a0"


## Apply a peace change to the world: traders join/leave the targetable set.
func _sync_faction(fid: String) -> void:
	if fid == "trader":
		for t in get_tree().get_nodes_in_group("traders"):
			if t.has_method("refresh_hostility"):
				t.refresh_hostility()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == Keys.FACTIONS and not ship.dead:
		visible = not visible
		if visible:
			_refresh()
			add_to_group("esc_capture")
		else:
			remove_from_group("esc_capture")
		Sfx.play("click", -10.0, 1.3 if visible else 0.9)
	elif event.keycode == Keys.MENU and visible:
		visible = false
		remove_from_group("esc_capture")
		Sfx.play("click", -10.0, 0.9)
