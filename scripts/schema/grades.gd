class_name Grades
## Component quality axis (the loot axis). Size is a separate axis: Mark I-V.

enum Grade { FLOTSAM, SALVAGE, STANDARD, ADVANCED, EXPERIMENTAL, BESPOKE, EXOTIC }

const INFO := {
	Grade.FLOTSAM: {
		"name": "Flotsam",
		"color": Color(0.55, 0.55, 0.55),
		"affixes": 0,
		"drawback": true,  # Flotsam always carries a drawback affix
		"pips": 0,
		"value": 5,
	},
	Grade.SALVAGE: {
		# RENAMED TO "ROUGH" 2026-07-28 (user). "Salvage" had become the most overloaded
		# word in the project — the [B] SALVAGE panel, Salvage All, BuildShip's salvage
		# radius, the Salvaged Coupling, the SALVAGE SKILL and the affix pillar ("salvage
		# is where treasure comes from") all meant different things by it — and it sat too
		# close to STANDARD, one rung above.
		#
		# ROUGH OVER "JUNK" for two reasons. (1) THE MECHANICS: Flotsam is the compromised
		# tier — it ALWAYS carries a drawback affix. This one carries none. Its defining
		# property is that it WORKS and simply isn't special, so naming it after rubbish
		# described the rung below it. (2) GENRE LITERACY (user): "Rough sits close to
		# Rusty, which is a common RPG [tier], and I think that familiarity earns its
		# place." A player has read this word on a loot tier before. (Junk also collided
		# with the level-1 JUNKER SLUGTHROWER, which is this very grade.)
		#
		# THE ENUM IDENTIFIER AND ITS ORDINAL DO NOT MOVE. Grade values are serialized in
		# every .tres on disk (same hazard class as SlotType), so this is a display string
		# and nothing else — the same rule that keeps the save directory named Bleakflame.
		"name": "Rough",
		"color": Color(0.92, 0.92, 0.92),
		"affixes": 0,
		"drawback": false,
		"pips": 1,
		"value": 12,
	},
	Grade.STANDARD: {
		"name": "Standard",
		"color": Color(0.30, 0.80, 0.35),
		"affixes": 1,
		"drawback": false,
		"pips": 2,
		"value": 30,
	},
	Grade.ADVANCED: {
		"name": "Advanced",
		"color": Color(0.30, 0.55, 0.95),
		"affixes": 2,
		"drawback": false,
		"pips": 3,
		"value": 75,
	},
	Grade.EXPERIMENTAL: {
		"name": "Experimental",
		"color": Color(0.65, 0.35, 0.90),
		"affixes": 3,
		"drawback": false,
		"pips": 4,
		"value": 180,
	},
	Grade.BESPOKE: {
		"name": "Bespoke",
		"color": Color(0.95, 0.78, 0.25),
		"affixes": 0,  # hand-authored uniques: fixed mechanics, not rolled affixes
		"drawback": false,
		"pips": 5,
		"value": 500,
	},
	Grade.EXOTIC: {
		"name": "Exotic",
		"color": Color(0.90, 0.22, 0.20),
		"affixes": 0,  # rule-breakers; always paired with a hazard
		"drawback": false,
		"pips": 6,
		"value": 1200,
	},
}


static func display_name(grade: Grade) -> String:
	return INFO[grade]["name"]


static func color(grade: Grade) -> Color:
	return INFO[grade]["color"]
