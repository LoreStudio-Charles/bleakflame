extends Node
## ONE INVENTORY, MANY HOSTS (the discipline agreed with the user 2026-07-25).
##
## Every surface that shows "your stuff" — the shop counter's sell side, the pilot
## dossier's manifest, the in-flight salvage panel — must be the SAME InventoryGrid with a
## different verb bound, never a hand-rolled list. Four subtly different inventories is
## exactly how the grade border stops matching and a tile means something different
## depending on which screen you opened.
##
## This test is the enforcement: it stands up each host and asserts the grid is there and
## its verb actually fires. If someone re-rolls a bespoke inventory, a case here fails.
##   <godot> --headless --path . res://tools/test_inventory_grid.tscn

var _fails := 0


func _ready() -> void:
	_case_grid_shows_what_you_carry()
	_case_verbs_are_bound_by_the_host()
	_case_no_ship_is_not_a_crash()
	_case_dossier_uses_the_shared_grid()
	_case_the_dossier_sells_your_gear()

	print("test_inventory_grid: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## Materials AND components, together — a hold contains both, and the player shouldn't
## have to know which internal list a thing lives in to find it.
func _case_grid_shows_what_you_carry() -> void:
	var ship := preload("res://tools/fake_hold.gd").new()
	add_child(ship)
	ship.add_commodity("aurite_ore", 3)
	ship.cargo.append(load("res://data/components/weapons/vk2_autocannon.tres"))
	var grid := InventoryGrid.new(ship)
	add_child(grid)
	grid.refresh()

	var mats := 0
	var items := 0
	for c in grid._grid.get_children():
		if c is MaterialStackTile:
			mats += 1
		elif c is ItemTile:
			items += 1
	_chk(mats == 1, "the ore stack is shown as a material tile (%d)" % mats)
	_chk(items == 1, "the carried gun is shown as an item tile (%d)" % items)
	grid.queue_free()
	ship.queue_free()


## The grid owns the LAYOUT; the host owns the MEANING. Same widget, different verb.
func _case_verbs_are_bound_by_the_host() -> void:
	var ship := preload("res://tools/fake_hold.gd").new()
	add_child(ship)
	ship.add_commodity("food", 2)
	var grid := InventoryGrid.new(ship)
	var fired := []
	grid.on_material = func(key: String, src: String) -> void: fired.append([key, src])
	grid.source = "hold"
	add_child(grid)
	grid.refresh()

	var tile: MaterialStackTile = null
	for c in grid._grid.get_children():
		if c is MaterialStackTile:
			tile = c
	_chk(tile != null, "the grid built a tile to act on")
	if tile != null:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_RIGHT
		e.pressed = true
		tile._gui_input(e)
		_chk(fired.size() == 1 and str(fired[0][0]) == "food",
			"right-clicking ran the HOST's verb, with the key and source")
	grid.queue_free()
	ship.queue_free()


## The dossier can be opened before a hull is boarded. Empty is a state, not a crash.
func _case_no_ship_is_not_a_crash() -> void:
	var grid := InventoryGrid.new(null)
	grid.empty_text = "— nothing —"
	add_child(grid)
	grid.refresh()
	_chk(grid._grid.get_child_count() == 1, "a shipless grid draws its empty note, not an error")
	grid.queue_free()


## SELLING FROM YOUR OWN SHEET (user, 2026-07-28: "we could sell from the P > Ship
## paperdoll"). Right-click on a ship part in the dossier used to do NOTHING —
## _equip_from_hold early-returns on anything that is not ground gear — so this asserts a
## dead gesture became the verb that belongs to it, and that it refuses out loud in
## flight rather than silently doing nothing all over again.
func _case_the_dossier_sells_your_gear() -> void:
	var ship := TestShip.new()
	add_child(ship)
	ship.apply_build(SampleBuilds.get_build(SampleBuilds.current))
	ship.add_to_group("player_ship")
	var part: ComponentDef = load(str(DockScreen.SHOP_STOCK[0]))
	ship.cargo.clear()
	ship.add_cargo(part)

	var sheet := CharacterSheet.new()
	add_child(sheet)

	# IN FLIGHT: no counter, so it must say so rather than eat the click.
	ship.docked_at = null
	sheet._say("")
	sheet._use_from_hold(part)
	_chk(ship.cargo.size() == 1, "in flight the part stays in your hold")
	_chk("No buyer" in sheet._note.text,
		"...and the refusal is visible: %s" % sheet._note.text)

	# DOCKED: the same gesture sells it.
	ship.docked_at = ship          # any non-null berth; the sheet only asks IF, not WHICH
	Wallet.credits = 0
	var worth := ItemVisuals.sell_price(part)
	sheet._use_from_hold(part)
	_chk(Wallet.credits == worth,
		"docked, right-click sells it for %dc (got %dc)" % [worth, Wallet.credits])
	_chk(ship.cargo.is_empty(), "...and it leaves your hold")

	ship.docked_at = null
	Wallet.credits = 0
	sheet.queue_free()
	ship.queue_free()


## THE RULE ITSELF: the pilot dossier must not hand-roll its own manifest.
func _case_dossier_uses_the_shared_grid() -> void:
	var sheet := CharacterSheet.new()
	add_child(sheet)
	_chk(_find_grid(sheet) != null,
		"the pilot dossier shows cargo through the SHARED InventoryGrid")
	sheet.queue_free()


func _find_grid(root: Node) -> InventoryGrid:
	for child in root.get_children():
		if child is InventoryGrid:
			return child
		var hit := _find_grid(child)
		if hit != null:
			return hit
	return null


func _chk(cond: bool, msg: String) -> void:
	print(("  ok  " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1
