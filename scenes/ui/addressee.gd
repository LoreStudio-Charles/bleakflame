class_name Addressee
extends RefCounted
## THE FRONT DOOR TO A PERSON (docs/person_as_context.md, step 3).
##
## ONE RANKED LIST of everything someone will do with you, with QUEST BUSINESS AT
## THE TOP, IN GOLD. It replaces the arrangement where a pending campaign talk was
## a PIP competing with a BUTTON for the same glance.
##
## THAT COMPETITION IS THE ODESSA FAILURE. A bespoke "Talk to Odessa" opened the bar
## chat and never looked at her queued campaign talk, so `ember_word` sat behind a
## second, redundant button for ~46 game-days of a real save. The fix at the time was
## to teach that one button to check first — correct, and only as good as the next
## author remembering to do the same. Under one ranked list it cannot recur: there is
## nowhere else for a talk to be, and rank is a property of the list, not a habit of
## whoever wired the button.
##
## THE SPLIT (the same one NpcDesk uses): this owns the RANK and the STYLE; the HOST
## owns the CONTENT — which offers exist, and what pressing one does. A host adds a
## service by appending an offer; it can never accidentally out-rank the campaign.
##
## LOCKED OFFERS ARE ABSENT, NOT GREYED — rule 5, the trust rule (docs/venue_layout.md).
## So there is deliberately no `blocked` here, unlike ContextScreen.action(): inside a
## context the thing is already in front of you and silence would be a mystery, but at
## the front door, advertising what you have not earned is the mystery. If an offer is
## not on the table, it is not on the list.

## The bands, in the order they are presented. QUEST is first BY CONSTRUCTION — it is
## the first enum value and `ranked()` walks the enum, so a new band can only ever be
## added around the spine, never above it.
enum Kind {QUEST, SERVICE, DOOR}


## One thing this person will do with you.
##   `gold`   — a decision or an update is waiting here (the DialoguePanel gold rule).
##              QUEST ignores it and is always gold: story business always qualifies.
##   `closes` — pressing it HANDS OFF to another screen, so the addressee steps aside
##              instead of sitting behind the thing it just opened.
static func offer(id: String, text: String, kind: int, gold := false,
		closes := false) -> Dictionary:
	return {"id": id, "text": text, "kind": kind, "gold": gold, "closes": closes}


## Offers in presentation order, ties broken by the order the host listed them.
##
## BUCKETED, NOT SORTED, on purpose: Array.sort_custom is NOT a stable sort, so equal
## ranks could swap and a person's offers would shuffle between two visits to the same
## desk. Walking the enum keeps siblings in the host's order and makes "quest first"
## true by structure rather than by comparator.
static func ranked(offers: Array) -> Array:
	var out: Array = []
	for kind in [Kind.QUEST, Kind.SERVICE, Kind.DOOR]:
		for o in offers:
			if int(o.get("kind", Kind.SERVICE)) == kind:
				out.append(o)
	return out


## Gold reads "pay attention, something is about to change" — never guessed from
## structure (scenes/ui/dialogue_panel.gd). Story business always earns it; a service
## earns it only when the host says a decision is genuinely waiting there.
static func style_of(o: Dictionary) -> String:
	if int(o.get("kind", Kind.SERVICE)) == Kind.QUEST:
		return "primary"
	return "primary" if bool(o.get("gold", false)) else "secondary"


## The DialoguePanel node dict for this person: their line, then the ranked offers,
## then the way out. The closer is always cyan — leaving changes nothing.
static func nodes(greeting: String, offers: Array,
		closer := "Nothing right now.") -> Dictionary:
	return merge({}, greeting, offers, closer)


## FOLD OFFERS INTO AN AUTHORED TREE, rather than replacing it.
##
## Some people are not a menu. Odessa's bar chat and Doug's mining lesson are real
## branching conversations with sub-nodes, written in a voice — flattening either into a
## ranked list would delete the writing, and "the addressee replaced the conversation"
## is a worse outcome than the competing-button bug it was built to fix.
##
## So the offers are PREPENDED to the tree's opening choices and the author keeps
## everything else: their own text, their own ordering, their own sub-nodes. The one
## thing the component still insists on is the rank — story business sits above whatever
## a person does for a living, in their tree exactly as in a generated one. That is the
## whole ember_word fix, applied to the conversation it originally broke.
##
## An empty tree gets the plain closer, which is what `nodes()` is.
static func merge(tree: Dictionary, greeting: String, offers: Array,
		closer := "Nothing right now.") -> Dictionary:
	var out: Dictionary = tree.duplicate(true)
	if not out.has("start"):
		out["start"] = {"vo_once": true,
			"choices": [{"text": closer, "next": "end"}]}
	var start: Dictionary = out["start"]
	# An authored opener STAYS. greet_line exists for people who have none, and
	# overwriting Odessa's "Sit anywhere that holds you" with a generic line would be
	# this pass deleting the thing it is meant to protect.
	if greeting != "":
		start["text"] = greeting
	var lead: Array = []
	for o in ranked(offers):
		lead.append({
			"text": str(o.get("text", "")),
			"action": str(o.get("id", "")),
			"style": style_of(o),
			"close": bool(o.get("closes", false)),
		})
	start["choices"] = lead + (start.get("choices", []) as Array)
	out["start"] = start
	return out


## WHERE YOU STAND WITH THEM, under their name — the addressee's third job after
## identity and offers. Empty for anyone who speaks for nobody, and for a commission
## that is still a SECRET: the Privateers are fully built and deliberately unadvertised,
## and a standing meter under Vyper's portrait would announce them as loudly as a tab.
static func standing_line(npc: String) -> String:
	var faction := Professions.led_by(npc)
	if faction == "" or Professions.hidden(faction):
		return ""
	return "%s · %s · %d" % [Professions.display_name(faction),
		rank_word(faction), Standing.get_points(faction)]


## THE WORD FOR A STANDING NUMBER, and the ONLY one — the venue's meter reads this too.
## They were computed separately for one build and immediately disagreed: at 10 points
## the Shoal's meter said NEUTRAL while Vyper's own line said TRUSTED, because
## Standing.state has no name for the invitation rung and this does.
##
## TRUSTED is the INVITE_AT step — "trusted enough to be offered a commission" — the one
## crossing inside the neutral band that changes what a person will do with you, so it
## earns a name. That is exactly why it cannot live only here: a rung the meter can't
## say is a rung the player watches themselves fail to reach.
static func rank_word(faction: String) -> String:
	match Standing.state(faction):
		"kos":
			return "HUNTED"
		"hostile":
			return "HOSTILE"
		"allied":
			return "ALLIED"
		"friendly":
			return "FRIENDLY"
	return "TRUSTED" if Standing.eligible(faction) else "NEUTRAL"


## The colour that word wears. Beside rank_word on purpose: a word and its colour are one
## piece of information, and splitting them across two files is how they drift.
static func rank_color(faction: String) -> String:
	match rank_word(faction):
		"ALLIED": return "#6de08f"
		"FRIENDLY": return "#8fe08f"
		"TRUSTED": return "#9fd8a8"
		"NEUTRAL": return "#73bff2"
		"HOSTILE": return "#f2a24a"
		"HUNTED": return "#f25a50"
	return "#8890a0"
