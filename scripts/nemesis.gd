class_name Nemesis
## THE GRUDGE — the ship that killed you, and the fact that the game remembers.
##
## A player pushing for Orivel early meets something far above the lane's band and
## dies to it. That is a wall in most games. Here it is the START of something: the
## killer has a NAME, the log records what it did, and it is still out there. Come
## back when you are harder and settle it.
##
## WHY IT IS BUILT GENERAL rather than one-off for Recluse: a nemesis is only
## meaningful if it is YOURS. Any named hunter can take you, and whichever one did
## is the one your log names — so two pilots tell different stories about the same
## lane. Recluse is simply the first one placed.
##
## A grudge is keyed by CALLSIGN, not by node: the ship that killed you is long
## freed by the time you come back, and the pair that share a callsign share the
## grudge (kill either Recluse and the debt is paid — they hunt as one animal).
##
## UI-free and SaveGame-free ON PURPOSE, like quests.gd: it holds the model, the
## caller writes the log line. That keeps it loadable under --script with no
## autoloads, which is how it gets tested.

## callsign -> {name, level, deaths, day, avenged, avenged_day}
static var grudges: Dictionary = {}


static func reset() -> void:
	grudges.clear()


## You died to `callsign`. Repeat deaths to the same hunter deepen the grudge
## rather than replacing it — the count is the story.
static func record_defeat(callsign: String, display_name: String, level: int, day: int) -> void:
	if callsign == "":
		return
	var g: Dictionary = grudges.get(callsign, {})
	g["name"] = display_name if display_name != "" else callsign
	# Keep the HIGHEST level seen. Meeting it again when it is weaker should not
	# quietly downgrade what it did to you the first time.
	g["level"] = maxi(int(g.get("level", 0)), level)
	g["deaths"] = int(g.get("deaths", 0)) + 1
	g["day"] = day
	# A fresh kill re-opens a settled grudge: it came back, so the debt is live.
	g["avenged"] = false
	g.erase("avenged_day")
	grudges[callsign] = g


## You killed it. Returns true only if there was a real debt — so the caller can
## stay quiet about a hunter you happened to shoot before it ever touched you.
static func avenge(callsign: String, day: int) -> bool:
	if callsign == "" or not grudges.has(callsign):
		return false
	var g: Dictionary = grudges[callsign]
	if bool(g.get("avenged", false)):
		return false
	g["avenged"] = true
	g["avenged_day"] = day
	grudges[callsign] = g
	return true


static func has_grudge(callsign: String) -> bool:
	return callsign != "" and grudges.has(callsign) \
		and not bool(grudges[callsign].get("avenged", false))


## Every unsettled grudge, worst first (most deaths, then highest level) — the
## one that has hurt you most is the one worth naming.
static func active() -> Array:
	var out: Array = []
	for callsign in grudges:
		var g: Dictionary = grudges[callsign]
		if not bool(g.get("avenged", false)):
			out.append({"callsign": callsign, "name": str(g.get("name", callsign)),
				"level": int(g.get("level", 0)), "deaths": int(g.get("deaths", 0)),
				"day": int(g.get("day", 0))})
	out.sort_custom(func(a, b):
		if a.deaths != b.deaths:
			return a.deaths > b.deaths
		return a.level > b.level)
	return out


## The log line for a defeat. Second and later deaths read differently — being
## killed twice by the same thing is a different feeling from being killed once.
static func defeat_line(callsign: String) -> String:
	var g: Dictionary = grudges.get(callsign, {})
	var name := str(g.get("name", callsign))
	var deaths := int(g.get("deaths", 1))
	if deaths <= 1:
		return "%s took me apart out on the capital road. It never said a word. I did not see it coming and I will not forget the mark on its hull." % name
	if deaths == 2:
		return "%s again. It knew the road better than I did. Twice now." % name
	return "%s. That is %d times. This stops being bad luck somewhere." % [name, deaths]


static func avenged_line(callsign: String) -> String:
	var g: Dictionary = grudges.get(callsign, {})
	var name := str(g.get("name", callsign))
	var deaths := int(g.get("deaths", 0))
	if deaths >= 2:
		return "%s is scrap. It took me %d tries and a better ship. The road is quieter and I am not sorry." % [name, deaths]
	return "%s is scrap. It never raised comms, not even at the end. Debt paid." % name


static func to_dict() -> Dictionary:
	return {"grudges": grudges.duplicate(true)}


static func from_dict(data: Dictionary) -> void:
	grudges.clear()
	var raw: Dictionary = data.get("grudges", {})
	for callsign in raw:
		var g: Dictionary = raw[callsign]
		grudges[str(callsign)] = {
			"name": str(g.get("name", callsign)),
			"level": int(g.get("level", 0)),
			"deaths": int(g.get("deaths", 0)),
			"day": int(g.get("day", 0)),
			"avenged": bool(g.get("avenged", false)),
			"avenged_day": int(g.get("avenged_day", 0)),
		}
