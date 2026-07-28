class_name VenueLayout
extends VBoxContainer
## THE STANDARD VENUE LAYOUT — the shape every dockable place shares.
## Design of record: docs/venue_layout.md (decided with user 2026-07-27).
##
## Every place you can put down assembles the same five things — TALK, CONTRACTS,
## STANDING, VENDOR, OFFICE DOOR — and until now each assembled them by hand. That
## is why Vyper's board needed new code at all: Doug's deck had already solved it,
## in a form nothing else could reach. NpcDesk was the first rung of this ladder
## (user: "a single NPC tab object that controls the layout"); this is the venue.
##
##   ┌ header ─────────────────────────────────────────────────────┐
##   │ <NpcDesk> · flavour        │  <venue_box>  — the local trade │
##   │ CONTRACTS                  │  QUARTERMASTER (trust-gated)    │
##   │   board · take · hand in   │    shelf, each row's price      │
##   │ ── STANDING ──             │  <office door>                  │
##   └─────────────────────────────────────────────────────────────┘
##
## CONTRACTS SIT DIRECTLY ABOVE THE METER THEY MOVE. Standing lives on the Pilot
## tab today, a screen away from the board that changes it, so a player cannot see
## the work and its consequence at once. The adjacency is the point.
##
## THE HOST KEEPS WHAT IS ITS OWN. The fence, the ore buyer, the flavour text —
## anything that is the REASON to fly here — goes in `venue_box` and `body`. This
## owns only the parts that were identical everywhere.

signal talk_pressed(npc: String)
signal office_opened(prof: String)
signal ware_bought(path: String)
signal changed                      ## something here altered the world; host should redraw

## The board is sized to a BOARD, not to the screen. A venue posts three or four
## contracts; letting the list take the slack overshoots into hundreds of pixels of
## empty list under three rows, and pinning it short hides the third behind a
## scrollbar. The spacer below takes the leftover instead.
const BOARD_H := 200

## THE ANCHORS EVERY VENUE OFFERS, so a lesson can point at the board or the meter at
## ANY faction quarter without knowing which one it is standing in. The shell registers
## the widgets and mounts the ping overlays; a venue that adopts the shell gets both for
## free, which is the difference between a lesson that draws and one that silently jams.
const ANCHORS := ["venue_board", "venue_standing", "office_door"]

var ship: TestShip
var venue: String                   ## MissionLog venue key + Tutor.venue ("shoal"/"verge")
var board: String                   ## board name this venue's postings carry
var npc: String                     ## whose desk stands here
var faction: String                 ## Factions id for the meter ("" = no meter)
var prof: String                    ## commission administered here ("" = none)

var desk: NpcDesk
var body: RichTextLabel             ## host writes the venue's own flavour here
var venue_box: VBoxContainer        ## host's own business — the fence, the ore buyer

## Can this pilot see the shelf AT ALL? Below it there is no quartermaster section:
## not greyed, not captioned — ABSENT. See THE TRUST RULE below.
var trust: Callable

## Will this venue post work to this pilot yet? Separate from `trust` because they are
## separate rungs — the Shoal hands out jobs long before it lets you near the shelf.
## When shut, the board is replaced by `board_shut_text` in the venue's own voice: a
## board you are not yet trusted with is a fact about your standing, which the meter
## right below it is already explaining, so this one says WHY out loud.
var board_open: Callable
var board_shut_text := ""
var board_title := "CONTRACTS"

## What this venue charges. Defaults to the going rate; a host that marks up or
## discounts sets this, and it is the SAME callable the buy button prints and the
## host's purchase handler must charge — one price, one place.
var price_of: Callable = func(comp: ComponentDef) -> int: return ItemVisuals.buy_price(comp)

## What the next rung of standing opens, in the venue's own words. `{at, label}`,
## authored by the host; the meter shows the first one above your current points.
var rungs: Array = []

var talks: TalkChain                ## drain-all / check_new_work / no-replay / pip routing

var _msg := ""                      ## said once, then cleared — never goes stale
var _msg_label: RichTextLabel
var _offers: ItemList
var _take_btn: Button
var _active_box: VBoxContainer
var _meter: RichTextLabel
var _quart_head: Label
var _quart_box: VBoxContainer
var _door_box: HBoxContainer


func _init(cfg: Dictionary) -> void:
	ship = cfg.get("ship")
	venue = str(cfg.get("venue", ""))
	board = str(cfg.get("board", ""))
	npc = str(cfg.get("npc", ""))
	faction = str(cfg.get("faction", ""))
	prof = str(cfg.get("prof", Professions.led_by(npc)))
	rungs = cfg.get("rungs", [])
	# DEFAULT TRUST IS THE PROJECT'S OWN DEFINITION OF IT. Standing.INVITE_AT is
	# documented as "trusted enough to be offered a commission" — the same rung that
	# opens the door opens the shelf, so the back room and what is on its counter
	# appear together rather than one teasing the other.
	trust = cfg.get("trust", func() -> bool: return _standing_key() != "" \
		and Standing.eligible(_standing_key()))
	board_open = cfg.get("board_open", func() -> bool: return true)
	board_shut_text = str(cfg.get("board_shut_text", ""))
	board_title = str(cfg.get("board_title", "CONTRACTS"))
	talks = TalkChain.new(self, venue)
	if cfg.has("price_of"):
		price_of = cfg.price_of
	add_theme_constant_override("separation", 12)


## Built on demand rather than in _ready so a host can mount and populate in one
## breath without waiting a frame for the tree.
func build(title: String) -> void:
	var head := Label.new()
	head.text = "%s        [E] launch" % title
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", UiTheme.AMBER)
	add_child(head)

	# EVERY REFUSAL MUST BE VISIBLE (project rule), and at a dock venue that CANNOT be
	# ship._flash_note: flight_hud hides `_center_note` whenever the ship is docked
	# (`_center_note.visible = flying`), so the Speak's Easy was writing every "Not
	# enough credits", every "Mission log full", every turn-in result and every quest
	# note from Krayt's table into a hidden label. The screen had no voice at all.
	# The Verge deck had already solved this with its own `_msg`; the shell owns it now.
	_msg_label = RichTextLabel.new()
	_msg_label.bbcode_enabled = true
	_msg_label.fit_content = true
	_msg_label.visible = false
	add_child(_msg_label)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(cols)

	cols.add_child(_build_left())
	cols.add_child(_build_right())
	Tutor.register("venue_board", _offers)
	if _meter != null:
		Tutor.register("venue_standing", _meter)


## Ping overlays go on the HOST canvas, never in this VBox: a TutorPing is a full-rect
## Control and a container would lay it out as a row. The host calls this once.
func mount_pings(canvas: Node) -> void:
	for a in ANCHORS:
		var ping := TutorPing.new()
		ping.anchor = str(a)
		canvas.add_child(ping)


func _build_left() -> Control:
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL

	desk = NpcDesk.new(npc)
	desk.talk_pressed.connect(func(who: String) -> void: talk_pressed.emit(who))
	left.add_child(desk)

	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(body)

	# THE SHELL OWNS THE SHAPE, THE VENUE OWNS THE WORDS. "CONTRACTS" is the honest
	# default for a board several people post to; a single-giver board says whose it is
	# ("VYPER'S WORK", "DIG WORK — all of it involves rock"), and flattening those into
	# one generic word cost the venues their voice the first time this was extracted.
	var work_head := Label.new()
	work_head.text = board_title
	work_head.add_theme_color_override("font_color", UiTheme.ACCENT)
	left.add_child(work_head)

	_offers = ItemList.new()
	# THE BOARD TAKES THE COLUMN. Sized to a minimum so it never collapses, and allowed
	# to grow so the left column has no void in it: an ItemList draws its own panel, so
	# a tall one reads as a NOTICE BOARD with room on it, where the same emptiness as
	# bare background read as a screen that forgot to finish. This is the third sizing
	# this list has had — 96px hid the third posting behind a scrollbar, an unpinned
	# expand left ~700px of blank list ABOVE nothing, and the difference now is that the
	# meter below anchors the bottom, so the list is framed instead of dangling.
	_offers.custom_minimum_size = Vector2(0, BOARD_H)
	_offers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offers.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_offers.fixed_icon_size = Vector2i(32, 32)
	_offers.icon_mode = ItemList.ICON_MODE_LEFT
	_offers.item_activated.connect(func(_i: int) -> void: take_selected())
	left.add_child(_offers)

	# Buttons sit in a row so they keep their own width. A Button parented straight
	# to a VBoxContainer stretches to fill it, which made "Take the job" a 1900px bar.
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	left.add_child(btn_row)
	_take_btn = Button.new()
	_take_btn.text = "Take the job"
	UiTheme.button_flavor(_take_btn, "secondary")
	_take_btn.pressed.connect(take_selected)
	btn_row.add_child(_take_btn)

	_active_box = VBoxContainer.new()
	_active_box.add_theme_constant_override("separation", 4)
	left.add_child(_active_box)

	if _standing_key() != "":
		var st_head := Label.new()
		st_head.text = "STANDING"
		st_head.add_theme_color_override("font_color", UiTheme.ACCENT)
		left.add_child(st_head)
		_meter = RichTextLabel.new()
		_meter.bbcode_enabled = true
		_meter.fit_content = true
		_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_child(_meter)
	return left


func _build_right() -> Control:
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL

	venue_box = VBoxContainer.new()
	venue_box.add_theme_constant_override("separation", 6)
	right.add_child(venue_box)

	_quart_head = Label.new()
	_quart_head.add_theme_color_override("font_color", UiTheme.ACCENT)
	right.add_child(_quart_head)
	_quart_box = VBoxContainer.new()
	_quart_box.add_theme_constant_override("separation", 6)
	right.add_child(_quart_box)

	# THE DOOR FOLLOWS THE COUNTER. Pushed to the foot of the column by a spacer it hung
	# alone in several hundred pixels of nothing, reading as a stray button rather than
	# the way out of the room — and the counter it belongs to was up at the ceiling.
	# One continuous block; the slack falls below all of it.
	_door_box = HBoxContainer.new()
	right.add_child(_door_box)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	return right


## THE ONE CALL A HOST MAKES. Publishes the tutor context, then redraws every part
## this layout owns; the host redraws `body` and `venue_box` around it.
func refresh() -> void:
	# THE TUTOR CONTEXT, PUBLISHED BY THE SHELL. DockScreen and ProspectDeck each
	# asserted these; the Speak's Easy never did, so a pilot standing in a pirate bar
	# carried FLIGHT's `safe` — false if anything had been hunting them — and dwell
	# timers only run while safe. That is precisely the starvation the DockScreen was
	# hardened against in 2026-07-22, still live at the newest venue. A venue cannot
	# forget this any more, because it no longer does it.
	Tutor.safe = true
	Tutor.context = "dock"
	Tutor.venue = venue
	_msg_label.visible = _msg != ""
	_msg_label.text = "[color=#f2b859]%s[/color]" % _msg
	_msg = ""
	_refresh_board()
	_refresh_meter()
	_refresh_quartermaster()
	_refresh_door()
	# LAST, so the snapshot sees the finished screen (the same ordering rule
	# DockScreen's _dock_context follows — a context built mid-refresh describes a
	# half-drawn room).
	Tutor.observe(context())


## THE VENUE'S TUTOR SNAPSHOT. Without one, the declarative engine cannot arm or
## complete a single lesson here: predicates poll this dictionary, and a venue that
## publishes nothing is a venue where the tutor is simply switched off. Doug's deck
## published three keys; the Speak's Easy published none.
##
## STANDING IS IN IT (user, 2026-07-27): "the tutor should trigger off pirate faction
## >= 0." A venue's lessons should arm off your standing with the faction that owns the
## room — that is the modern way to say "you are welcome here", and the Tutor.safe /
## venue machinery predates factions entirely.
func context() -> Dictionary:
	var key := _standing_key()
	return {
		"flying": false,
		"venue": venue,
		"faction": faction,
		"standing": Standing.get_points(key) if key != "" else 0,
		"board_open": board_open.call(),
		"trusted": prof != "" and trust.call(),
		"office_open": prof != "" and Professions.office_open(prof),
		"no_profession": Pilot.profession == "",
		"commission_eligible": key != "" and Standing.eligible(key),
		"pip_showing": talks.has_news(npc),
		"turn_in_here": _has_turn_in_here(),
	}


## Is there work here you could hand in right now? The pip that says so, which the
## station's Missions tab has worn since 2026-07-22 and no bespoke venue ever did.
func _has_turn_in_here() -> bool:
	for m in MissionLog.active:
		if MissionLog.venue_ok_at(m, venue) and MissionLog.is_complete(m, ship):
			return true
	return false


## SAY IT, then redraw. Anything that can be refused has to be able to explain itself,
## and at a dock the flight HUD is not listening.
func flash(text: String) -> void:
	_msg = text
	changed.emit()


func _refresh_board() -> void:
	_offers.clear()
	for c in _active_box.get_children():
		c.queue_free()
	# THE BOARD KEEPS ITS SHAPE WHEN IT IS SHUT. Hiding the list collapsed the left
	# column to a few lines against a whole empty screen, which reads as a venue that
	# has not been built — when in fact it is a venue you have not been let into yet.
	# The refusal belongs ON the board, where the postings would be.
	var open: bool = board_open.call()
	_take_btn.visible = open
	if not open:
		if board_shut_text != "":
			_offers.add_item(board_shut_text)
			_offers.set_item_disabled(0, true)
	else:
		for entry in MissionLog.offers_at(venue, board):
			var m: Dictionary = entry.m
			var idx := _offers.add_item("%s  —  %dc" % [_row_text(m), m.reward])
			_offers.set_item_metadata(idx, int(entry.index))
			var face := Npcs.portrait(str(m.get("giver", npc)))
			if face != null:
				_offers.set_item_icon(idx, face)
		if _offers.item_count == 0:
			_offers.add_item("— the board's bare. Come back when the lane's been busy —")
			_offers.set_item_disabled(0, true)
		_take_btn.disabled = _offers.item_count == 1 and _offers.is_item_disabled(0)

	# HAND-INS ARE NEVER GATED. The old board returned early when it was shut, so work
	# you had ALREADY TAKEN became unturnable-in the moment your standing slipped below
	# the posting line — the job stayed in your log with nowhere on the map to close it.
	# You can always finish what you agreed to.
	for i in MissionLog.active.size():
		var m: Dictionary = MissionLog.active[i]
		if not MissionLog.venue_ok_at(m, venue):
			continue
		var done: bool = MissionLog.is_complete(m, ship)
		var b := Button.new()
		b.text = "%s  —  %s" % [_row_text(m),
			"HAND IN (%dc)" % m.reward if done else "in progress"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not done
		if done:
			UiTheme.button_flavor(b, "primary")
		b.pressed.connect(turn_in.bind(i))
		_active_box.add_child(b)


## `desc` on a single-giver board, `label` where several people post. MissionLog.label
## appends the giver, which is right on a shared board and pure noise on a personal
## one — every row at the Speak's Easy read "… — Vyper" under a heading saying
## VYPER'S WORK. Derived per row rather than configured, so it cannot go stale.
func _row_text(m: Dictionary) -> String:
	return str(m.desc) if str(m.get("giver", "")) == npc else MissionLog.label(m)


## The meter, and THE NEXT RUNG — what more standing would actually open, in this
## venue's words. A bar that only counts is a number; a bar that says what it buys is
## a reason to take the contract sitting directly above it.
func _refresh_meter() -> void:
	if _meter == null:
		return
	var key := _standing_key()
	var p := Standing.get_points(key)
	var st := Standing.state(key)
	var txt := "[b]%s[/b]\n[color=%s]%s[/color]   [color=#8890a0]standing %d[/color]" % [
		faction_label(faction), _state_color(st), st.to_upper(), p]
	var climb := climb_to_next(rungs, p)
	if climb.is_empty():
		txt += "\n%s\n[color=#8890a0]top of their ladder — there is nothing left to prove[/color]" % _bar(1.0)
	else:
		txt += "\n%s  [color=#8890a0]%d / %d[/color]\n[color=#f2b859]next:[/color] [color=#8890a0]%s[/color]" % [
			_bar(float(climb.frac)), p, int(climb.to), str(climb.label)]
	_meter.text = txt


## WHERE YOU ARE BETWEEN THE RUNG YOU PASSED AND THE ONE AHEAD — {to, frac, label}, or
## {} at the top of the ladder.
##
## THE BAR HAS TO MEASURE THE CLIMB YOU ARE ACTUALLY ON. Scaled to Standing.MAX (1000)
## it did not visibly move ANYWHERE on the Shoal's ladder — every rung that matters
## sits between -100 and 100, so a pilot grinding Vyper's contracts from 0 to 100
## watched a bar that stayed empty the whole way. A meter that cannot show the progress
## it exists to show is worse than no meter: it teaches the player the work does
## nothing. Measured rung-to-rung it fills across exactly the span being climbed.
##
## Pure + static: the ladder is assertable without building a screen.
static func climb_to_next(ladder: Array, points: int) -> Dictionary:
	var next := {}
	var floor_at := Standing.HOSTILE_AT     # where a faction that has written you off sits
	for r in ladder:
		var at := int((r as Dictionary).get("at", 0))
		if at <= points:
			floor_at = maxi(floor_at, at)
		elif next.is_empty() or at < int(next.at):
			next = r
	if next.is_empty():
		return {}
	var to := int(next.at)
	var span := maxf(1.0, float(to - floor_at))
	return {"to": to, "label": str(next.get("label", "")),
		"frac": clampf(float(points - floor_at) / span, 0.0, 1.0)}


## THE TRUST RULE (user, 2026-07-27): "hide the entire tab to someone the
## quartermaster doesn't trust enough to see the shop. Once you can enter the faction
## area show the panel and show the faction required to purchase the item."
##
## HIDDEN MEANS ABSENT — no heading, no "take the colors first" caption. A caption is
## still a shop you cannot use, which is the DEMO POLISH RULE inverted, and it
## advertises a faction's inventory as a reward before the player has any reason to
## want it. This generalises `Professions.office_open` ("no invitation, no door") one
## level up: no trust, no shelf.
##
## Above the line the shelf shows in full and EVERY ROW STATES ITS OWN PRICE OF ENTRY,
## so nothing is ever a silent refusal.
func _refresh_quartermaster() -> void:
	for c in _quart_box.get_children():
		c.queue_free()
	var trusted: bool = prof != "" and trust.call()
	_quart_head.visible = trusted
	_quart_box.visible = trusted
	if not trusted:
		return
	_quart_head.text = "QUARTERMASTER — %s" % Npcs.display_name(npc)
	var stock: Array = Professions.wares(prof)
	var shown := 0
	for path in stock:
		var sp := str(path)
		if not ResourceLoader.exists(sp):
			continue
		shown += 1
		_quart_box.add_child(_ware_row(load(sp), sp))
	if shown == 0:
		var soon := Label.new()
		soon.text = "Nothing on the shelf yet — modules land here as they are forged."
		soon.add_theme_color_override("font_color", UiTheme.DIM)
		_quart_box.add_child(soon)


## One row: the real ItemTile (same grade border, mark badge and pips as the Armory —
## a part reads identically on every screen), the price NAMED WITH ITS CURRENCY, and
## the requirement spelled out when it is not met.
func _ware_row(comp: ComponentDef, path: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)

	var tile := ItemTile.new(comp, "shop", ItemTile.Style.SHOP)
	tile.price = int(price_of.call(comp))
	row.add_child(tile)

	var req := requirement(comp, prof, _standing_key())
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text = "[b]%s[/b]\n[color=#8890a0]%s[/color]" % [comp.display_name, comp.description]
	row.add_child(lbl)

	var btn := Button.new()
	# THE CURRENCY IS NAMED, not assumed. Faction-earned scrip does not exist yet —
	# credits and Insight are all there is — and this must not invent it as a side
	# effect of a layout pass (docs/venue_layout.md). The row asks the item what it
	# costs and prints that, so the day scrip lands nothing here needs rewriting.
	btn.text = "Buy — %s" % price_text(int(price_of.call(comp)))
	btn.disabled = not bool(req.met)
	UiTheme.button_flavor(btn, "primary")
	if not btn.disabled:
		btn.pressed.connect(func() -> void: ware_bought.emit(path))
	row.add_child(btn)

	if not bool(req.met):
		var why := Label.new()
		why.text = "requires %s" % str(req.text)
		why.add_theme_font_size_override("font_size", 11)
		why.add_theme_color_override("font_color", UiTheme.DIM)
		col.add_child(why)
	return col


## WHAT THIS COSTS, CURRENCY NAMED. Today everything is priced in credits — credits
## and Insight are the only two that exist — and FACTION SCRIP DOES NOT (see
## docs/venue_layout.md: it must not be invented as a side effect of a layout pass).
## This function is the one place a price is spelled out, so the day a second currency
## lands it learns about it here and every shelf in the game follows.
static func price_text(amount: int, currency := "credits") -> String:
	match currency:
		"insight": return "%d Insight" % amount
		_: return "%dc" % amount


## CAN THIS PILOT BUY IT, and if not, what in plain words is missing. Pure + static:
## the rule a shelf enforces should be assertable without building a shelf.
static func requirement(comp: ComponentDef, prof_id: String, standing_key: String) -> Dictionary:
	# READ THE LOCK, DON'T ASK THE CLASS. `comp is SystemDef` is FALSE for every ability
	# chip — AbilityChipDef extends ComponentDef directly and declares its own
	# profession_lock — so a type test silently skipped the commission gate on exactly
	# the items a quartermaster stocks. Both classes carry the field, so read the field;
	# it is also the rule ShipBuild.chip_error enforces, which is what makes the counter
	# and the coupling agree. Caught by sabotage: deleting this branch changed nothing,
	# because the level gate was refusing everything anyway and hiding it.
	var lock := str(comp.get("profession_lock")) if comp.get("profession_lock") != null else ""
	if lock != "" and lock != Pilot.profession:
		return {"met": false,
			"text": "the %s commission" % Professions.display_name(lock)}
	if int(comp.level) > Pilot.level():
		return {"met": false, "text": "pilot level %d" % int(comp.level)}
	# STANDING BANDS, NAMED not numbered — the fence already does this correctly
	# ("the fence opens at Privateer — Friendly"). No ware carries a band today; the
	# branch is here so the first one that does needs no new code.
	var band := int(comp.get("standing_req") if comp.get("standing_req") != null else 0)
	if band > 0 and standing_key != "" and Standing.get_points(standing_key) < band:
		return {"met": false, "text": "%s standing" % band_name(band)}
	return {"met": true, "text": ""}


## WHOSE ROOM THIS IS, named the way the player knows them. NOT EVERY VENUE'S OWNER IS
## A COMBAT FACTION: the Rust Shoal is in Factions.LIST, the Prospector Guild and the
## Explorer's Union are COMMISSIONS and are not. Factions.display_name falls back to the
## raw id, so the Verge's meter would have been headed "miner" in lower case. Ask both
## registries, in the order that gets the better name.
static func faction_label(id: String) -> String:
	if Factions.LIST.has(id):
		return Factions.display_name(id)
	if not Professions.def(id).is_empty():
		return Professions.display_name(id)
	return id.capitalize()


static func band_name(points: int) -> String:
	if points >= Standing.ALLIED_AT:
		return "Allied"
	if points >= Standing.FRIENDLY_AT:
		return "Friendly"
	if points >= Standing.INVITE_AT:
		return "Trusted"
	return "Neutral"


## The commission's door, when its leader stands here and has opened it. Same
## GuildOffice every other leader uses — a commission is administered where its
## leader stands, whether that is a station counter or a bar in a pirate den.
func _refresh_door() -> void:
	for c in _door_box.get_children():
		c.queue_free()
	if prof == "" or not Professions.office_open(prof):
		return
	var door := Button.new()
	door.text = "%s  →  %s" % [
		"Enter" if Pilot.profession == prof else "Visit",
		Professions.office_name(prof)]
	UiTheme.button_flavor(door, "primary")
	door.pressed.connect(func() -> void: office_opened.emit(prof))
	_door_box.add_child(door)
	Tutor.register("office_door", door)


## THROUGH take(), never accept(): take() reports WHY a refusal happened (a full log
## answered a bare accept() with a click and nothing else) and calls ensure_offers.
func take_selected() -> void:
	var sel := _offers.get_selected_items()
	if sel.is_empty() or _offers.is_item_disabled(sel[0]):
		return
	var r := MissionLog.take(int(_offers.get_item_metadata(sel[0])))
	if r.ok:
		Tutor.did("accepted_contract")
	else:
		Sfx.play("click", -16.0, 0.6)
	flash(str(r.msg))


## THROUGH MissionLog.complete(), which carries the standing credit, Quests.
## check_new_work and the turn-in tutor signals. Re-implementing the tail at each
## board is how boards drift apart — this is the last copy of it.
func turn_in(index: int) -> void:
	var r := MissionLog.complete(index, ship, venue, SaveGame.tutorial_done)
	if r.ok:
		Tutor.did("turned_in")
		Tutor.retire("turn_in")
		Sfx.play("jingle", -8.0)
	# UNCONDITIONALLY, and as the FIRST statement out of the ok-branch: a refusal must
	# never be silent, and the structural check in test_dock_ui reads exactly this shape
	# so the next board cannot quietly nest it back inside `if r.ok:`.
	flash(_with_notes(str(r.msg)))


## Quest notes raised by a turn-in (a beat completed, new work opened) are said HERE
## too — they used to go to the flight note, which is hidden while docked, and vanish.
func _with_notes(msg: String) -> String:
	var said := msg
	for note in Quests.take_notes():
		said += "\n%s" % str(note)
	return said


func _standing_key() -> String:
	return Factions.standing_key(faction) if faction != "" else ""


## A filled fraction of the climb, in the same glyphs FactionsView uses so one number
## never has two looks. Unsigned on purpose: this bar answers "how far to the next
## door", not "do they like me" — the state word above it already says that.
func _bar(frac: float) -> String:
	const CELLS := 24
	var lit := int(round(clampf(frac, 0.0, 1.0) * CELLS))
	return "[color=#6de08f]%s[/color][color=#39414f]%s[/color]" % [
		"▰".repeat(lit), "▱".repeat(CELLS - lit)]


func _state_color(state: String) -> String:
	match state:
		"allied": return "#6de08f"
		"friendly": return "#8fe08f"
		"neutral": return "#73bff2"
		"hostile": return "#f2a24a"
		"kos": return "#f25a50"
	return "#8890a0"
