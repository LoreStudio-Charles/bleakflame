class_name ShipHails
## WHAT A STRANGER SAYS WHEN YOU HAIL THEM ON THE ROAD.
##
## Built for THE LONELINESS (docs/cinder_reach_campaign.md, beat 4), whose instrument is
## the friendlies roster: "a list of people who are RIGHT THERE and not with you, filling
## and emptying as you pass." The doc names the missing half exactly —
##
##   "Traffic needs names and one-line hails that answer politely and fly on — without
##    that, 'together but alone' reads as 'some ships went past.'"
##
## Ships already had names (ShipNames registry marks). Every hail answered with ONE
## canned line, for everybody, forever, so hailing twice told you it was a system.
##
## THE LINES ANSWER AND CLOSE. That is the whole design brief. Nobody here is rude and
## nobody here is available: each reply is courteous, complete, and about an errand you
## are not part of. A line that invites a follow-up would make the road sociable, which
## is the opposite of the beat.
##
## THE SAME SHIP ALWAYS SAYS THE SAME THING. Picked by hashing its registry mark, not at
## random: a hauler that answers differently every time you raise it is a slot machine,
## and the beat needs it to be a person you passed. Re-hail and you get the same tired
## voice — which is itself the point, because you are not going to get any further with
## them either.
##
## ROLE COMES FROM THE MARK. ShipNames.PREFIX already stamps it (GCT hauler, GEU
## guardian, GCN navy), so nothing new has to be stored or kept in step; an unregistered
## hull has no prefix and gets the wary set, which is correct for exactly the reason it
## is unregistered.

const LINES := {
	"hauler": [
		"\"Reading you. Nothing aboard worth stopping for. Safe lanes.\"",
		"\"Hey. Yeah, still moving. Eleven hours to the ring, give or take.\"",
		"\"All good here, Captain. Don't let the quiet fool you out this far.\"",
		"\"Copy. Been on this run so long I could fly it asleep. Sometimes do.\"",
		"\"Loud and clear. Tell the Reach I'm coming, if anyone asks. Nobody asks.\"",
	],
	"guardian": [
		"\"Guardian wing, holding the band. Lane's clear as far as I can see it.\"",
		"\"Reading you. Stay off the rim and we'll both have a boring shift.\"",
		"\"Copy that. Nothing on the scope. Keeping it that way.\"",
		"\"You're on my board, Captain. That's all it means. Fly safe.\"",
	],
	# VITALITY INSURED TRANSPORT — live cargo, and the PREMIUM tier of it (user: "these
	# are luxury liners, the fancy ships carrying passengers"). "Very Important Things"
	# is what folk say when their family ships out, so the warmth is real; the register
	# is unhurried and gracious, a ship with nothing to prove and a schedule it keeps.
	#
	"liner": [
		"\"Reading you clearly, Captain. All quiet aboard. A pleasant crossing to you.\"",
		"\"Thank you, no. Two hundred and six souls, every one of them accounted for.\"",
		"\"Signal received. We are carrying very important things, and we know it.\"",
		"\"Acknowledged, and courteous of you to ask. Few do this far out.\"",
	],
	# GCVT — COMMON VITAL TRANSPORT, the cheap crossing (user, 2026-07-28). These were
	# the liner lines until the tier was settled, and they were wrong for a GVIT and
	# exactly right here: cold coffee, homesickness, a long way to go. The pairing does
	# the work — a GVIT answers gracious and unhurried two hundred metres away, and the
	# difference between the two replies IS the class system.
	"common_liner": [
		"\"Reading you. Two hundred and six souls and a lot of cold coffee. All well.\"",
		"\"Clear signal, Captain. We're carrying very important things. Aren't we all.\"",
		"\"Copy. Half of them asleep, half of them homesick. Standard crossing.\"",
		"\"Received, and thank you for asking. Not many do out here.\"",
	],
	"navy": [
		"\"Confederacy vessel. Acknowledged. Maintain your heading.\"",
		"\"Received. We are not stopping. Nothing personal, Captain.\"",
		"\"Logged. Keep your distance from the formation and there's no issue.\"",
	],
	"": [
		"\"...\" A carrier tone, and nothing on it. They heard you.\"",
		"\"Don't. Whatever it is. Don't.\" The channel closes.",
		"\"Wrong frequency, friend.\" It isn't.",
	],
}


## Which set this hull answers from, read off its registry mark. "" = unregistered.
static func role_of(ship_name: String) -> String:
	for role in ShipNames.PREFIX:
		if ship_name.begins_with(str(ShipNames.PREFIX[role])):
			return str(role)
	return ""


## One line, STABLE for this ship. `ship_name` is the seed as well as the address, so a
## hull keeps its voice for as long as it exists.
static func line(ship_name: String) -> String:
	var set: Array = LINES.get(role_of(ship_name), LINES[""])
	if set.is_empty():
		return "\"Copy.\""
	return str(set[absi(ship_name.hash()) % set.size()])


## The whole reply, addressed. An unregistered hull is named as what it is rather than
## having its noise printed at the player — the same courtesy ShipNames.is_registered
## exists for.
static func reply(ship_name: String, fallback := "contact") -> String:
	var who := ship_name if ship_name != "" else fallback
	if ship_name != "" and role_of(ship_name) == "":
		who = "%s (unregistered)" % ship_name
	return "%s: %s" % [who, line(ship_name)]
