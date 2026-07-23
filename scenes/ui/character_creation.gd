class_name CharacterCreation
extends CanvasLayer
## Pilot registration, shown once per pilot (fresh game or after New
## Pilot). Name + portrait + background (one minor trait) + optional bio —
## identity only; professions are earned in play. The tutorial waits for
## `confirmed` so a new player isn't taught to fly mid-form.

signal confirmed

const PORTRAIT_DIR := "res://assets/portraits/pilot"

var ship: TestShip
var _callsign_pick: OptionButton
var _name_edit: LineEdit
var _bio_edit: TextEdit
var _bio_count: Label
var _bg_list: ItemList
var _bg_desc: RichTextLabel
var _face: TextureRect
var _face_hint: Label
var _grid: GridContainer
var _grid_group := ButtonGroup.new()
var _dossier: RichTextLabel
## Portraits split by filename prefix (pilot_m_* / pilot_f_*); the toggle
## picks which pool fills the grid. "m"/"f" are art-set labels, not a claim
## about the pilot — the game never reads gender off this choice.
var _pool := {"m": [], "f": []}
var _sex := "m"
var _selected_path := ""


func _init(p_ship: TestShip) -> void:
	ship = p_ship
	layer = 20


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 260
	panel.offset_top = 70
	panel.offset_right = -260
	panel.offset_bottom = -70
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.BG, 0.99)
	style.border_color = Color(0.32, 0.5, 0.66)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(22.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var title := Label.new()
	title.text = "PILOT REGISTRATION — CINDER REACH HARBOR AUTHORITY"
	title.add_theme_color_override("font_color", UiTheme.AMBER)
	title.add_theme_font_size_override("font_size", 15)
	col.add_child(title)

	# Name + portrait row.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	col.add_child(top)
	var face_box := VBoxContainer.new()
	face_box.add_theme_constant_override("separation", 6)
	top.add_child(face_box)
	_face = TextureRect.new()
	_face.custom_minimum_size = Vector2(192, 192)
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face_box.add_child(_face)
	# Male / Female toggle: picks the art set shown in the grid below.
	var sex_row := HBoxContainer.new()
	sex_row.alignment = BoxContainer.ALIGNMENT_CENTER
	face_box.add_child(sex_row)
	var sex_group := ButtonGroup.new()
	for entry in [["Male", "m"], ["Female", "f"]]:
		var b := Button.new()
		b.text = entry[0]
		b.toggle_mode = true
		b.button_group = sex_group
		b.button_pressed = entry[1] == _sex
		b.pressed.connect(_on_sex.bind(entry[1]))
		sex_row.add_child(b)
	_face_hint = Label.new()
	_face_hint.add_theme_font_size_override("font_size", 10)
	_face_hint.add_theme_color_override("font_color", Color(0.38, 0.41, 0.5))
	_face_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face_box.add_child(_face_hint)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_col)
	# Callsign (a pooled handle — what the Reach calls you on the radio) and
	# family name (free text) are separate identities.
	var id_row := HBoxContainer.new()
	id_row.add_theme_constant_override("separation", 14)
	name_col.add_child(id_row)
	var call_col := VBoxContainer.new()
	id_row.add_child(call_col)
	var call_label := Label.new()
	call_label.text = "CALLSIGN"
	call_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	call_col.add_child(call_label)
	_callsign_pick = OptionButton.new()
	for cs in Pilot.CALLSIGNS:
		_callsign_pick.add_item(cs)
	_callsign_pick.item_selected.connect(_on_callsign_picked)
	call_col.add_child(_callsign_pick)
	var fam_col := VBoxContainer.new()
	fam_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_row.add_child(fam_col)
	var name_label := Label.new()
	name_label.text = "FAMILY NAME"
	name_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	fam_col.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.max_length = Pilot.NAME_MAX
	_name_edit.placeholder_text = "e.g. Vex"
	_name_edit.text_changed.connect(_on_name_changed)
	fam_col.add_child(_name_edit)
	var bio_label := Label.new()
	bio_label.text = "BIO — optional, %d characters" % Pilot.BIO_MAX
	bio_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	name_col.add_child(bio_label)
	_bio_edit = TextEdit.new()
	_bio_edit.custom_minimum_size = Vector2(0, 64)
	_bio_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_bio_edit.text_changed.connect(_on_bio_changed)
	name_col.add_child(_bio_edit)
	_bio_count = Label.new()
	_bio_count.add_theme_font_size_override("font_size", 10)
	_bio_count.add_theme_color_override("font_color", Color(0.38, 0.41, 0.5))
	name_col.add_child(_bio_count)

	# Body splits below the name row: the FORM on the left, a live PROVISIONAL
	# RECORD dossier on the right (fills what was dead space, and makes the
	# signature mean something).
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 10)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.size_flags_stretch_ratio = 1.55
	body.add_child(form)

	# Portrait picker: 8-wide so all 16 of a set land in two rows with no
	# scrollbar (the grid grows the row count only if art is added).
	var portrait_label := Label.new()
	portrait_label.text = "PORTRAIT"
	portrait_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	form.add_child(portrait_label)
	_grid = GridContainer.new()
	_grid.columns = 8
	_grid.add_theme_constant_override("h_separation", 5)
	_grid.add_theme_constant_override("v_separation", 5)
	form.add_child(_grid)

	# Background: a basic past, one minor trait.
	var bg_label := Label.new()
	bg_label.text = "BACKGROUND — where you were before the Reach had your name"
	bg_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	form.add_child(bg_label)
	var bg_row := HBoxContainer.new()
	bg_row.add_theme_constant_override("separation", 16)
	bg_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form.add_child(bg_row)
	_bg_list = ItemList.new()
	_bg_list.custom_minimum_size = Vector2(190, 110)
	_bg_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for b in Pilot.BACKGROUNDS:
		_bg_list.add_item(b.name)
	_bg_list.item_selected.connect(_on_bg_selected)
	bg_row.add_child(_bg_list)
	_bg_desc = RichTextLabel.new()
	_bg_desc.bbcode_enabled = true
	_bg_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bg_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bg_row.add_child(_bg_desc)

	# Right column: the live dossier + the signature button beneath it.
	var record := VBoxContainer.new()
	record.add_theme_constant_override("separation", 10)
	record.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	record.size_flags_stretch_ratio = 1.0
	body.add_child(record)
	var record_label := Label.new()
	record_label.text = "PROVISIONAL RECORD"
	record_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	record.add_child(record_label)
	var record_panel := PanelContainer.new()
	record_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rstyle := StyleBoxFlat.new()
	rstyle.bg_color = Color(0.05, 0.06, 0.09, 0.9)
	rstyle.border_color = Color(0.32, 0.5, 0.66)
	rstyle.set_border_width_all(1)
	rstyle.set_corner_radius_all(6)
	rstyle.set_content_margin_all(16.0)
	record_panel.add_theme_stylebox_override("panel", rstyle)
	record.add_child(record_panel)
	_dossier = RichTextLabel.new()
	_dossier.bbcode_enabled = true
	_dossier.size_flags_vertical = Control.SIZE_EXPAND_FILL
	record_panel.add_child(_dossier)

	var confirm := Button.new()
	confirm.text = "Sign the registry"
	confirm.pressed.connect(_on_confirm)
	record.add_child(confirm)

	_bg_list.select(0)
	_on_bg_selected(0)
	_scan_portraits()
	_on_bio_changed()


func _scan_portraits() -> void:
	_pool = {"m": [], "f": []}
	var dir := DirAccess.open(PORTRAIT_DIR)
	if dir != null:
		for f in dir.get_files():
			# get_files() lists both "x.png" and its "x.png.import" sidecar;
			# trimming .import collapses them, so dedup or every face doubles.
			var fn := f.trim_suffix(".import")
			if not fn.ends_with(".png"):
				continue
			var path := "%s/%s" % [PORTRAIT_DIR, fn]
			if not ResourceLoader.exists(path):
				continue
			# Prefix decides the pool; anything unprefixed shows under both.
			if fn.begins_with("pilot_f_"):
				if not _pool.f.has(path):
					_pool.f.append(path)
			elif fn.begins_with("pilot_m_"):
				if not _pool.m.has(path):
					_pool.m.append(path)
			else:
				if not _pool.m.has(path):
					_pool.m.append(path)
				if not _pool.f.has(path):
					_pool.f.append(path)
	_pool.m.sort()
	_pool.f.sort()
	# Land on the sex that actually has art (in case one set is empty).
	if _pool[_sex].is_empty() and not _pool[_other_sex()].is_empty():
		_sex = _other_sex()
	_rebuild_grid()


func _other_sex() -> String:
	return "f" if _sex == "m" else "m"


func _on_sex(sex: String) -> void:
	if sex == _sex:
		return
	_sex = sex
	_rebuild_grid()


func _rebuild_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var faces: Array = _pool[_sex]
	if faces.is_empty():
		_face_hint.text = "no portraits yet — drop art in\nassets/portraits/pilot/"
		_face.texture = null
		_selected_path = ""
		return
	_face_hint.text = ""
	# Keep the current pick if it belongs to this set, else take the first.
	if not faces.has(_selected_path):
		_select_face(faces[0])
	for path in faces:
		var tex: Texture2D = load(path)
		var tile := Button.new()
		tile.toggle_mode = true
		tile.button_group = _grid_group
		tile.custom_minimum_size = Vector2(92, 92)
		tile.icon = tex
		tile.expand_icon = true
		tile.button_pressed = path == _selected_path
		tile.pressed.connect(_select_face.bind(path))
		_grid.add_child(tile)


func _select_face(path: String) -> void:
	_selected_path = path
	_face.texture = load(path)
	_update_dossier()


func _on_name_changed(_t: String) -> void:
	_update_dossier()


## Picking a callsign previews its voice line (silent until clips exist) —
## the immediate payoff of a pooled handle.
func _on_callsign_picked(index: int) -> void:
	Sfx.play_voice("callsign/" + str(Pilot.CALLSIGNS[index]).to_lower())
	_update_dossier()


func _on_bg_selected(index: int) -> void:
	var b: Dictionary = Pilot.BACKGROUNDS[index]
	_bg_desc.text = "[b]%s[/b]\n[i][color=#a8b0c2]%s[/color][/i]\n\n[color=#f2b859]%s[/color]" % [
		b.name, b.desc, b.trait]
	_update_dossier()


func _on_bio_changed() -> void:
	_bio_count.text = "%d / %d" % [_bio_edit.text.strip_edges().length(), Pilot.BIO_MAX]
	_update_dossier()


## The live record on the right: it fills as you choose, so "Sign the
## registry" reads as endorsing something real.
func _update_dossier() -> void:
	if _dossier == null:
		return
	var callsign: String = Pilot.CALLSIGNS[_callsign_pick.selected] \
		if _callsign_pick.selected >= 0 else Pilot.CALLSIGNS[0]
	var fam := _name_edit.text.strip_edges()
	var name_line := "‘%s’ %s" % [callsign, fam] if fam != "" \
		else "‘%s’ [color=#6a7080]— family name unsigned —[/color]" % callsign
	var sel := _bg_list.get_selected_items()
	var bg: Dictionary = Pilot.BACKGROUNDS[sel[0] if not sel.is_empty() else 0]
	var bio_str := _bio_edit.text.strip_edges()
	var bio_line := bio_str if bio_str != "" \
		else "[i][color=#6a7080]No statement given.[/color][/i]"
	_dossier.text = ("[color=#8890a0]CINDER REACH HARBOR AUTHORITY[/color]\n" +
		"[color=#8890a0]Provisional pilot record[/color]\n\n" +
		"[color=#8890a0]REGISTERED AS[/color]\n[b][color=#f2b859]%s[/color][/b]\n\n" +
		"[color=#8890a0]ORIGIN[/color]\n%s\n[color=#f2b859]%s[/color]\n\n" +
		"[color=#8890a0]STATEMENT[/color]\n%s\n\n" +
		"[i][color=#6a7080]On the radio you are just ‘%s’. Rank and profession " +
		"are earned in the black, not assigned at a desk. Sign, and the Reach " +
		"begins learning your name.[/color][/i]") % [
			name_line, bg.name, bg.trait, bio_line, callsign]


func _on_confirm() -> void:
	Pilot.callsign = Pilot.CALLSIGNS[maxi(_callsign_pick.selected, 0)]
	Pilot.family_name = Pilot.sanitize_name(_name_edit.text)
	Pilot.bio = Pilot.sanitize_bio(_bio_edit.text)
	var sel := _bg_list.get_selected_items()
	Pilot.background = Pilot.BACKGROUNDS[sel[0] if not sel.is_empty() else 0].id
	Pilot.portrait_path = _selected_path
	Pilot.created = true
	Wallet.credits += Pilot.starting_credits()
	# The registry is a real signature: checkpoint immediately, so a death
	# before the first dock doesn't ask anyone to introduce themselves twice.
	SaveGame.save_game(ship)
	Sfx.play("jingle", -8.0)
	confirmed.emit()
	queue_free()
