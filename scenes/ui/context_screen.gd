class_name ContextScreen
extends ContextBase
## THE LIST PRESENTATION of a context — for things that are SENTENCES: contracts,
## campaign beats, expedition leads, research projects, log entries. You read them.
##
## Everything else — the header, the detail panel, the action rule, the mode switcher —
## is ContextBase's, shared with ContextGrid. This is only the left-hand zone: sections,
## rows, and keeping you on the row you were reading across a refresh.
##
## Objects go in a GRID instead (equipment, hulls, commodities): you compare those at a
## glance rather than reading them. "Every shop is a grid. Anything you read is a list."

var list: ItemList


func _init() -> void:
	# EXPLICIT: declaring _init here suppresses the base's, so the shell (header, detail
	# panel, mode row) is never built and every widget call lands on null.
	super()
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(280, 160)
	list.fixed_icon_size = Vector2i(30, 30)
	list.icon_mode = ItemList.ICON_MODE_LEFT
	list.item_selected.connect(_on_row)
	left.add_child(list)


func _clear_items() -> void:
	list.clear()


## ---- list helpers ----

func section(heading: String) -> void:
	var i := list.add_item("—— %s ——" % heading)
	list.set_item_disabled(i, true)
	list.set_item_selectable(i, false)
	list.set_item_custom_fg_color(i, UiTheme.ACCENT)


func empty_row(text: String) -> void:
	var i := list.add_item("   %s" % text)
	list.set_item_disabled(i, true)
	list.set_item_selectable(i, false)
	list.set_item_custom_fg_color(i, Color(0.38, 0.41, 0.5))


## One selectable row. `id` must be STABLE across refreshes — it is how the screen
## keeps you on the row you were reading. `data` is merged into the metadata, so a
## screen carries whatever its detail panel needs.
func row(text: String, id: String, kind: String, data := {},
		tint := UiTheme.TEXT, npc := "") -> void:
	var i := list.add_item(text)
	list.set_item_custom_fg_color(i, tint)
	if npc != "":
		var art := Npcs.portrait(npc)
		if art != null:
			list.set_item_icon(i, art)
	var md := {"id": id, "kind": kind}
	for k in data:
		md[k] = data[k]
	list.set_item_metadata(i, md)


func _restore_selection() -> void:
	var want := _sel
	_sel = ""
	for i in list.item_count:
		var md = list.get_item_metadata(i)
		if md is Dictionary and str((md as Dictionary).get("id", "")) == want:
			list.select(i)
			_sel = want
			return
	for i in list.item_count:
		if not list.is_item_selectable(i):
			continue
		list.select(i)
		_sel = str((list.get_item_metadata(i) as Dictionary).get("id", ""))
		return


func _on_row(index: int) -> void:
	var md = list.get_item_metadata(index)
	_sel = str((md as Dictionary).get("id", "")) if md is Dictionary else ""
	Sfx.play("click", -18.0, 1.1)
	_rebuild_detail()


func selected_meta() -> Dictionary:
	for i in list.item_count:
		var md = list.get_item_metadata(i)
		if md is Dictionary and str((md as Dictionary).get("id", "")) == _sel:
			return md
	return {}
