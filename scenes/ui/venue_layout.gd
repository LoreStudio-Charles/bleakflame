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
##   │ ── STANDING ── + next rung │                                 │
##   └─────────────────────────────────────────────────────────────┘
##            │
##            └── the addressee ──┬── the board   (MissionComputer, this venue)
##                                ├── the shelf   (quartermaster, trust-gated)
##                                ├── the door    (GuildOffice)
##                                └── quest business — always first, always gold
##
## PERSON AS CONTEXT, STEP 4 (2026-07-28, docs/person_as_context.md). The board, the
## hand-ins, the shelf and the office door were COLUMNS here until this pass — better
## organised than the scatter they replaced, and still a room full of information. They
## are OFFERS now: one ranked list behind the person who owns them, each opening a
## single context that returns to the conversation rather than to the venue.
##
## THE ROOM KEEPS WHAT IS THE ROOM. The fence, the ore buyer, the flavour, the standing
## meter — the reason to fly here — stay on screen in `venue_box` and `body`. The rest
## was always business you transact with a PERSON, and it reads like it now.
##
## THE DESK SITS DIRECTLY ABOVE THE METER. Contracts used to, for a stated reason: work
## and its consequence one glance apart, where the Pilot tab put them a screen apart.
## The work moved one click behind the desk, so the desk inherited the adjacency —
## you ask for the job from a person standing on top of the meter it moves.

signal talk_pressed(npc: String)
signal office_opened(prof: String)
signal ware_bought(path: String)
signal changed                      ## something here altered the world; host should redraw
## A HOST'S OWN OFFER was chosen — anything this shell knows nothing about. Doug's
## mining lesson is the first: an authored dialogue tree that must stay a tree, folded
## into his list as one line rather than being replaced by the addressee wholesale.
signal offer_chosen(id: String)

## How wide a room reads. The design base is 1920 (CLAUDE.md) and a venue is now a desk,
## some flavour, a meter and the local trade — content that does not want a nineteen-
## hundred-pixel measure. The slack goes to the margins instead of between the columns.
const ROOM_W := 1180

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
## HOW THE PLAYER ASKS FOR WORK, in their own voice — the addressee's offer line. The
## old `board_title` was a COLUMN HEADING ("VYPER'S WORK"); a spoken list needs a
## question, and flattening every venue to one generic phrasing is what cost them their
## voice the first time this was extracted. Doug's board is about rock and says so.
var board_ask := "Anything on the board?"

## THE HOST'S OWN OFFERS, evaluated each time the list is drawn. Returns an Array of
## Addressee.offer dicts; the ids come back on `offer_chosen`. This is how an authored
## conversation survives the migration — Doug's mining lesson is a real dialogue TREE
## and must not be flattened into a one-line reply, so it becomes an offer that opens it.
var extra_offers: Callable = func() -> Array: return []

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
var _meter: RichTextLabel
var _shut_note: Label
## Where CanvasLayer children go — a context, a conversation, a ping. A VBoxContainer
## would lay a full-rect overlay out as a row, so none of them can be parented here.
var _canvas: Node


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
	board_ask = str(cfg.get("board_ask", "Anything on the board?"))
	if cfg.has("offers"):
		extra_offers = cfg.offers
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
	# CENTRED, NOT STRETCHED. With the board and the shelf moved behind the desk, the
	# room is genuinely short — and pinned to the top it read as a screen that had
	# forgotten to finish drawing, which is the exact complaint the old tall board list
	# was sized to answer. A sparse room is the design; a sparse room hanging off the
	# ceiling is a bug. Taking its natural height and sitting in the middle of the panel
	# reads as composed, and it stays right as venues gain their own business.
	cols.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# AND CAPPED, NOT STRETCHED ACROSS 1920. Two columns holding a desk and a meter,
	# spread over the full design width, put ~1200px of nothing between them and read as
	# two unrelated fragments rather than one room. Held to a readable measure and
	# centred, they read as a place with space in it.
	cols.custom_minimum_size = Vector2(ROOM_W, 0)
	cols.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var lead := Control.new()
	lead.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(lead)
	add_child(cols)
	var trail := Control.new()
	trail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(trail)

	cols.add_child(_build_left())
	cols.add_child(_build_right())
	if _meter != null:
		Tutor.register("venue_standing", _meter)


## Ping overlays go on the HOST canvas, never in this VBox: a TutorPing is a full-rect
## Control and a container would lay it out as a row. The host calls this once.
##
## IT ALSO REMEMBERS THE CANVAS, which is what lets this open its own conversations and
## contexts. The alternative — a signal per context for the host to answer by building
## the same modal each time — is the copied-per-venue shape this class exists to end.
func mount_pings(canvas: Node) -> void:
	_canvas = canvas
	for a in ANCHORS:
		var ping := TutorPing.new()
		ping.anchor = str(a)
		canvas.add_child(ping)


func _build_left() -> Control:
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	desk = NpcDesk.new(npc)
	desk.talk_pressed.connect(func(who: String) -> void:
		talk_pressed.emit(who)
		open_addressee())
	left.add_child(desk)
	# THE BOARD AND THE DOOR ARE REACHED THROUGH THE PERSON NOW, so a lesson pointing at
	# either points at them. The anchors keep their names because what they MEAN — where
	# the work is, where the commission is signed — has not changed, only where it lives.
	Tutor.register("venue_board", desk)
	Tutor.register("office_door", desk)

	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(body)

	# WHY THE BOARD IS SHUT, in the venue's own voice, kept BESIDE THE METER rather than
	# hidden with the offer. The trust rule (absent, not greyed) is about advertising an
	# inventory you have not earned; this is a fact about YOUR STANDING, which the meter
	# directly below is already explaining — so it says the quiet part out loud instead
	# of leaving a pilot to wonder why nobody here has work for them.
	_shut_note = Label.new()
	_shut_note.add_theme_font_size_override("font_size", 12)
	_shut_note.add_theme_color_override("font_color", UiTheme.DIM)
	_shut_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shut_note.visible = false
	left.add_child(_shut_note)

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

	venue_box = VBoxContainer.new()
	venue_box.add_theme_constant_override("separation", 6)
	right.add_child(venue_box)

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
	var open: bool = board_open.call()
	_shut_note.visible = not open and board_shut_text != ""
	_shut_note.text = board_shut_text
	_refresh_meter()
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


## ---- THE ADDRESSEE (docs/person_as_context.md step 4) ------------------------
##
## The board, the shelf and the office door used to be COLUMNS on this screen — the
## room-full-of-information the design is undoing. They are OFFERS now: one ranked list
## behind the person who owns them, quest business first, and each opens a single
## context that returns here rather than to the venue.
##
## The venue keeps what makes it worth flying to — the fence, the ore counter, the
## flavour, the standing meter. Those are the ROOM. The rest was always business you
## transact with a person.
func open_addressee() -> void:
	if _canvas == null:
		return
	Pilot.meet(npc)
	var panel := DialoguePanel.new(npc,
		Addressee.nodes(Npcs.greet_line(npc, talks.has_news(npc)), _offers_for_npc()),
		func(a: String) -> String: return _on_offer(a))
	panel.subtitle = Addressee.standing_line(npc)
	panel.closed.connect(func() -> void: changed.emit())
	_canvas.add_child(panel)


## LISTED STANDING-FIRST, TODAY'S-BUSINESS-LAST — deliberately the opposite of how
## Addressee presents them, so "the campaign comes first" can never quietly become true
## because of the order these lines happen to sit in.
func _offers_for_npc() -> Array:
	var offers: Array = []
	# THE BOARD, or the work you already agreed to. Its presence is NOT simply
	# `board_open`: hand-ins are never gated (a job you took must always have somewhere
	# to be closed), so a pilot whose standing has since slipped below the posting line
	# can still reach the desk that closes it. Only the WORDS change.
	var open: bool = board_open.call()
	if open or _has_work_here():
		offers.append(Addressee.offer("work",
			board_ask if open else "I've got work to close out.",
			Addressee.Kind.SERVICE, _has_turn_in_here(), true))
	# THE SHELF — absent, not greyed, below trust (docs/venue_layout.md's trust rule).
	if prof != "" and trust.call():
		offers.append(Addressee.offer("shelf", "Show me what's on the shelf.",
			Addressee.Kind.SERVICE, false, true))
	if prof != "" and Professions.office_open(prof):
		var member: bool = Pilot.profession == prof
		offers.append(Addressee.offer("office",
			"Let me into the %s." % Professions.office_name(prof) if member
				else "About the commission.",
			Addressee.Kind.DOOR,
			not member and _standing_key() != "" and Standing.eligible(_standing_key()),
			true))
	# THE HOST'S OWN BUSINESS, ranked with everything else rather than around it.
	for o in (extra_offers.call() as Array):
		offers.append(o)
	if talks.has_news(npc):
		var held := talks.held_for(npc)
		var label := "About %s." % str((held[0] as Dictionary).get("quest", "the job")) \
			if not held.is_empty() else "You wanted a word."
		if held.size() > 1:
			label += "   (+%d more)" % (held.size() - 1)
		offers.append(Addressee.offer("quest", label, Addressee.Kind.QUEST, false, true))
	return offers


func _on_offer(action: String) -> String:
	match action:
		"work": _open_work()
		"shelf": _open_shelf()
		"office": office_opened.emit(prof)
		"quest": talks.drain(npc)
		# NOT OURS — the host offered it, the host answers it.
		_: offer_chosen.emit(action)
	return ""


## Is there anything of this venue's to do at the board at all — work in hand that
## closes here, finished or not?
func _has_work_here() -> bool:
	for m in MissionLog.active:
		if MissionLog.venue_ok_at(m, venue):
			return true
	return false


## THE BOARD IS THE MISSION COMPUTER. Not a lookalike of it: the Shoal and The Dig each
## grew a private board with its own take/hand-in tail, which is precisely how two
## boards drift apart — and the station's had already been rebuilt to the context shape
## after a tester asked "where do I turn this in?". One screen, told which venue it is
## standing at, answers that question the same way everywhere.
func _open_work() -> void:
	var mc := MissionComputer.new(ship, venue, board)
	var modal := _open_context(mc)
	mc.accept_offer.connect(func(i: int) -> void:
		take(i)
		modal.refresh())
	mc.turn_in_requested.connect(func(i: int) -> void:
		turn_in(i)
		modal.refresh())


func _open_shelf() -> void:
	_open_context(_build_shelf())


## ONE CONTEXT AT A TIME (rule 1), AND IT RETURNS TO THE ADDRESSEE (rule 6). The offer
## closed the conversation on its way here, so nothing is stacked; closing this reopens
## it, rebuilt — which is also how the offer list stays honest after you have just
## accepted a contract or spent your last credits at the shelf.
##
## Not merely cosmetic: DialoguePanel sits on layer 25 and a modal on 20, so an
## addressee left open would draw straight over the context it had just opened.
func _open_context(content: Control) -> ContextModal:
	var modal := ContextModal.new(content, Npcs.display_name(npc))
	modal.closed.connect(func() -> void:
		changed.emit()
		open_addressee())
	_canvas.add_child(modal)
	return modal


## The meter, and THE NEXT RUNG — what more standing would actually open, in this
## venue's words. A bar that only counts is a number; a bar that says what it buys is
## a reason to take the contract sitting directly above it.
func _refresh_meter() -> void:
	if _meter == null:
		return
	var key := _standing_key()
	var p := Standing.get_points(key)
	# THROUGH Addressee, which is where the word for a standing number lives now — this
	# used to call Standing.state directly and print NEUTRAL at 10 points while the
	# person standing beside it called you TRUSTED.
	var txt := "[b]%s[/b]\n[color=%s]%s[/color]   [color=#8890a0]standing %d[/color]" % [
		faction_label(faction), Addressee.rank_color(key), Addressee.rank_word(key), p]
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
## Only ever built when the offer to see it was on the list, so there is no locked
## state to draw here — asking for it IS the trust check.
func _build_shelf() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var head := Label.new()
	head.text = "QUARTERMASTER — %s" % Npcs.display_name(npc)
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", UiTheme.AMBER)
	col.add_child(head)
	var stock: Array = Professions.wares(prof)
	var shown := 0
	for path in stock:
		var sp := str(path)
		if not ResourceLoader.exists(sp):
			continue
		shown += 1
		col.add_child(_ware_row(load(sp), sp))
	if shown == 0:
		var soon := Label.new()
		soon.text = "Nothing on the shelf yet — modules land here as they are forged."
		soon.add_theme_color_override("font_color", UiTheme.DIM)
		col.add_child(soon)
	return col


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

	var req := requirement(comp, _standing_key())
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
static func requirement(comp: ComponentDef, standing_key: String) -> Dictionary:
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


## THROUGH take(), never accept(): take() reports WHY a refusal happened (a full log
## answered a bare accept() with a click and nothing else) and calls ensure_offers.
func take(index: int) -> void:
	var r := MissionLog.take(index)
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

