class_name Dialogues
## Conversation data for the DialoguePanel. A conversation is a dict of
## nodes; each node = {text, choices[]}; each choice = {text, next} OR
## {text, action} — actions are resolved by the host's handler (see
## dock_screen._odessa_action), which returns the NPC's reply line. "end"
## closes the panel. Campaign conversations (the hermit, Krayt's comms,
## the Cinderheart finale) are authored in this same shape.

## DOUG DIGGS aboard The Dig. He is the game's MINING TEACHER: nothing else
## explains that a gun chips a rock but a cutter opens it, or that a rock has to
## be surveyed before you know whether it is worth cutting. Always talkable,
## like Odessa — a person you can go and ask, not a quest dispenser.
const DOUG_DECK := {
	"start": {
		"text": "Doug doesn't get up. He's got a socket wrench in one hand and a cup of something grey in the other, and the whole deck smells like hot metal.

\"Didn't hear you knock.\" He nods at the viewport, where the Verge turns slowly. \"Well. You found the rocks, or the rocks found you. Either way — I buy.\"",
		"vo_once": true,
		"choices": [
			{"text": "How do I actually mine a rock?", "next": "how", "style": "primary"},
			{"text": "What's worth cutting out here?", "next": "worth"},
			{"text": "Why park all the way out here?", "next": "why"},
			{"text": "Who are you, exactly?", "next": "who"},
			{"text": "Just selling. Thanks, Doug.", "next": "end"},
		]},
	"how": {
		"text": "\"Shoot a rock with a gun and you'll chip it. Chip it long enough and you'll get a handful of dust and a bill for the ammunition.\" He sets the cup down. \"You want a CUTTER. Ferro Cutter Beam, mining rig, whatever the Armory's calling it this year. That's the difference between hitting a rock and OPENING one.\"

\"And SURVEY the thing first. Your scan tells you what's inside before you waste an hour on a lump of nothing. Rock looks the same from outside whether it's ferrite or aurite or slag.\"",
		"choices": [
			{"text": "What's worth cutting?", "next": "worth"},
			{"text": "Understood.", "next": "end", "style": "primary"},
		]},
	"worth": {
		"text": "\"Ferrite's everywhere and pays like it. Cobalt's decent. Aurite —\" he taps the cup, \"aurite's why people fly out past the lane and don't always come back. The Verge is thick with it and nobody shoots at you here, which makes this the politest money in the Reach.\"

\"And bring it to ME, not the station. They'll pay you the number on the board. I'll pay you more, because you carried it out here and I didn't have to.\"",
		"choices": [
			{"text": "Why does that matter to you?", "next": "why"},
			{"text": "Good to know.", "next": "end", "style": "primary"},
		]},
	"why": {
		"text": "\"Because she doesn't fly any more.\" He pats the bulkhead, almost fond. \"Forty years hauling somebody else's freight, then a drive coupling went and the yard quoted me more than she's worth. So I cut the holds open, welded a berth on her flank, and parked her where the ore is.\"

A shrug. \"Station's a long way from the rocks. Somebody had to be close.\"",
		"choices": [
			{"text": "And the guild?", "next": "who"},
			{"text": "Fair enough.", "next": "end", "style": "primary"},
		]},
	"who": {
		"text": "\"Prospector Guild, out here. Which is me, mostly, and a list of names who bring me rock.\" He looks at you properly for the first time. \"Sell me enough of it and you go on that list. People on that list get gear the station's never heard of, and work that pays better than hauling circuits to farmers.\"

\"No paperwork. Just rock.\"",
		"choices": [{"text": "I'll keep that in mind.", "next": "end", "style": "primary"}]},
}

const ODESSA_BAR := {
	"start": {
		"text": "\"Sit anywhere that holds you. First one's watered, same as everyone's.\" She keeps polishing the same glass, eyes on the room.",
		"vo_once": true,   # her greeting speaks once per docking session, not every time you return here
		"choices": [
			{"text": "What's the word around the docks?", "action": "rumor", "style": "primary"},
			{"text": "Tell me about this place.", "next": "place"},
			{"text": "Who should I know on this station?", "next": "who"},
			{"text": "Just here for the quiet.", "next": "end"},
		]},
	"place": {
		"text": "\"Ember Row. Only warm light on the deck. Dock crews drink here, miners lie about seams here, and everything worth knowing gets said one table too loud.\" A shrug. \"I just pour.\"",
		"choices": [
			{"text": "Back.", "next": "start"},
			{"text": "Leave.", "next": "end"},
		]},
	"who": {
		"text": "\"Ruel runs the board — come back alive twice and he'll learn your callsign. Voss pays for bad news, poor woman. And the lab annex pays for anything the Reach shouldn't contain.\" She sets the glass down. \"Me, I take stories.\"",
		"choices": [
			{"text": "Back.", "next": "start"},
			{"text": "Leave.", "next": "end"},
		]},
}
