class_name TalkChain
extends RefCounted
## THE CONVERSATION MACHINERY, in one place (2026-07-27).
##
## Talking to a quest giver looks like one line of code and is not. DockScreen learned
## that over four separate playtest bugs and now carries all four fixes; the Speak's
## Easy and the Verge deck were written later, in the simpler shape, and got NONE of
## them. Each was a "pop the first talk, show it, advance" — which is exactly what
## DockScreen used to do.
##
## THE FOUR THINGS THIS DOES THAT THE SIMPLE SHAPE DOES NOT:
##
##  1. DRAINS EVERYTHING THEY HOLD. You are standing in front of them. When you finish
##     a job the giver often holds the DEBRIEF and the next quest's BRIEFING at once;
##     popping one left "Standing With the Board" un-started behind a second click on
##     the same button — shut the door, open it again to hear "one more thing".
##  2. RUNS check_new_work AFTER ANY TALK, not only a talk STAGE. A debrief closing out
##     a job can make the next quest eligible, and it must become eligible HERE. This
##     matters most at the Rust Shoal: the campaign must not require a detour through
##     the Guardians' station, which is the Shoal's enemy.
##  3. NEVER REPLAYS THE TALK JUST FINISHED. check_new_work re-queues an ACTIVE talk
##     stage's conversation, so a stage that did not advance comes straight back and
##     the drain replays it (playtest: Odessa spoke a line twice; the Counter did the
##     same on the ground). A conversation ends when the player ends it.
##  4. ROUTES EVERYONE ELSE TO THEIR OWN PIP. The person in front of you keeps talking;
##     anybody else waits behind their news dot, because nobody ambushes you at the ramp.
##
## VENUE-AWARE. `venue` names where the conversation is happening, and is passed
## straight through to check_new_work — see the note there about the station/planet
## bool reading every other dock in the system as the colony.
##
## DockScreen still runs its own copy: it is the most-tested screen in the project and
## its version is entangled with `is_station`, the tab pips and _announce_waiting. The
## two agree today; migrating it is the follow-up, and this API is shaped to accept it.

signal chain_finished

var host: Node                       ## where DialoguePanels are parented
var venue: String                    ## "shoal" / "verge" / "station" / "planet"

var _queue: Array = []
var _held: Dictionary = {}           ## npc -> Array of talks waiting behind their pip
var _active: DialoguePanel = null


func _init(p_host: Node, p_venue: String) -> void:
	host = p_host
	venue = p_venue


## Is this person holding something? Drives the desk's news dot.
func has_news(npc: String) -> bool:
	return not held_for(npc).is_empty()


## What this person is holding — their own pending talks, plus anything routed to them
## by an earlier conversation. Read from Quests each call so a talk queued since the
## last refresh is never missed.
func held_for(npc: String) -> Array:
	var out: Array = []
	out.append_array(_held.get(npc, []))
	for t in Quests.talks_for(npc):
		if not _contains(out, t):
			out.append(t)
	return out


## THE ONE ENTRY POINT. Drains everything this person holds into the chain and starts
## it. Returns false if they had nothing, so the host can fall through to idle chat and
## the always-visible talk button is never a dead click.
func drain(npc: String) -> bool:
	var queued := held_for(npc)
	if queued.is_empty():
		return false
	Pilot.meet(npc)
	for t in queued:
		_queue.append(t)
		# Take it out of the global pending list so a second click cannot serve it again.
		if _contains(Quests.talks_for(npc), t):
			Quests.take_talk(npc)
	_held.erase(npc)
	_show_next()
	return true


func _show_next() -> void:
	# Guard on an explicit reference, not tree membership: `closed` fires BEFORE
	# queue_free, so a just-closed panel is still a child and would wrongly block the
	# next talk in the chain.
	if _active != null and is_instance_valid(_active):
		return
	if _queue.is_empty():
		chain_finished.emit()
		return
	var talk: Dictionary = _queue.pop_front()
	var nodes: Dictionary
	if talk.has("nodes"):
		nodes = talk.nodes            # a full talk-stage conversation, authored in the quest
	else:
		# A one-line briefing/debrief; append the reward stamp. A briefing/debrief IS
		# the important beat, so its lone "Understood." is gold — the "this moment
		# matters" hint. (Lore closers stay cyan; see the DialoguePanel GOLD RULE.)
		var reward_line := ""
		if str(talk.get("rewards", "")) != "":
			reward_line = "\n\n[color=#f2b859]▸ %s — %s[/color]" % [talk.quest, talk.rewards]
		nodes = {"start": {
			"text": str(talk.get("text", "")) + reward_line,
			"vo": str(talk.get("vo", "")),
			"choices": [{"text": "Understood.", "next": "end", "style": "primary"}]}}
	var panel := DialoguePanel.new(str(talk.get("giver", "")), nodes,
		func(_a: String) -> String: return "")
	panel.vo_prefix = str(talk.get("vo", ""))
	_active = panel
	panel.closed.connect(_on_closed.bind(talk))
	host.add_child(panel)


func _on_closed(talk: Dictionary) -> void:
	_active = null
	if talk.has("advance"):
		Quests.advance_talk(str(talk.advance))
	Quests.check_new_work(venue == "station", SaveGame.tutorial_done, venue)
	var here := str(talk.get("giver", ""))
	for t in Quests.talks_for(here):
		if _same(t, talk):
			continue                  # never replay the conversation just finished
		_queue.append(t)
		Quests.take_talk(here)
	_show_next()


## Same conversation? Compared by CONTENT, not identity — check_new_work rebuilds the
## dictionary each time, so `==` on the object would never match the repeat it exists
## to drop.
static func _same(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("giver", "")) == str(b.get("giver", "")) \
		and str(a.get("quest", "")) == str(b.get("quest", "")) \
		and str(a.get("advance", "")) == str(b.get("advance", "")) \
		and str(a.get("text", "")) == str(b.get("text", ""))


static func _contains(list: Array, talk: Dictionary) -> bool:
	for t in list:
		if _same(t, talk):
			return true
	return false
