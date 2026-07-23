class_name Skills
## Pilot skills — the XP-bought half of progression. PILOT abilities (handling,
## arcs, efficiency, luck), deliberately NOT gear/tech-tree passives (those are
## Insight, Research Lab). Ranks are bought with skill points (Pilot: 1 per
## POINTS_PER_LEVELS levels). Everyone can rank a skill to its BASE_CAP; a
## PROFESSION raises the cap on its favoured skills (see Professions), so
## specialisation is gated by your commission, not by points.

const BASE_CAP := 2   # anyone can dabble this far without a profession

const LIST := [
	{"id": "gunnery", "name": "Gunnery", "per_rank": 0.08,
		"desc": "Wider weapon firing arcs and faster turret traverse."},
	{"id": "piloting", "name": "Piloting", "per_rank": 0.05,
		"desc": "Sharper ship turn rate."},
	{"id": "evasion", "name": "Evasion", "per_rank": 0.05,
		"desc": "A smaller hit profile — enemy fire needs to be truer to land."},
	{"id": "hull_discipline", "name": "Hull Discipline", "per_rank": 0.08,
		"desc": "More cargo hold from the same hull."},
	{"id": "shield_tuning", "name": "Shield Tuning", "per_rank": 0.10,
		"desc": "Faster shield recharge."},
	{"id": "prospecting", "name": "Prospecting", "per_rank": 0.10,
		"desc": "Richer mining and survey-scan yield."},
	{"id": "salvage", "name": "Salvage", "per_rank": 0.08,
		"desc": "Better luck on what wrecks drop."},
]


static func def(id: String) -> Dictionary:
	for s in LIST:
		if s.id == id:
			return s
	return {}


static func per_rank(id: String) -> float:
	return float(def(id).get("per_rank", 0.0))


static func display_name(id: String) -> String:
	return str(def(id).get("name", id))


static func ids() -> Array:
	var out := []
	for s in LIST:
		out.append(s.id)
	return out
