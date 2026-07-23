class_name Npcs
## The campaign cast. One registry, consumed everywhere a name appears:
## quest givers, contract flavor, the quest log, and (future) the dialogue
## panel. PORTRAITS ARE DROP-IN ART: assets/portraits/<id>.png — generate
## with PixelLab and drop the file; no code changes. Missing art = no
## portrait shown, never a crash (same convention as ship sprites/audio).

## `venue` is WHERE THIS PERSON PHYSICALLY IS — "station", "planet" or "shoal".
## A quest may only greet you where its giver actually stands: Ruel was handing
## out station work over the colony's landing pad, which reads as him following
## you around the system.
const CAST := {
	"ruel": {"home": "Landing Bay", "venue": "station", "name": "Harbormaster Ruel", "role": "Station Harbormaster",
		"flavor": "Runs the Landing Bay ledger and the contract board. Tracks every loss on a physical chart because screens can be argued with.",
		"idle": "Board's quiet for you right now, pilot. Keep your nose clean and she'll fly."},
	"voss": {"home": "Mission Computer", "venue": "station", "name": "Underwriter Voss", "role": "Insurance Underwriter",
		"flavor": "Files the claims when ships stop coming home. The paperwork face of the body count, and lately the paperwork is winning.",
		"idle": "No claims with your name on them today. Let's keep it that way."},
	"odessa": {"home": "Ember Row", "venue": "station", "name": "Odessa", "role": "Keeper of the Ember Row bar",
		"flavor": "Sells nothing, trades in stories. If it was whispered on this station, it reached her first."},
	"lab": {"home": "Research Lab", "venue": "station", "name": "Dex", "role": "Research Lab Technician",
		"flavor": "Runs the station's two study bays alone — quick, wired, and quietly terrified of what the instruments keep telling him. Would take numbers over sleep every time.",
		"idle": "Instruments are quiet. I don't trust quiet — but there's nothing for you yet."},
	"hermit": {"home": "Cave", "venue": "planet", "name": "The Counter", "role": "Hermit of the colony's edge",
		"flavor": "Ex-spacer, decades dirtside. Been counting something's breathing for thirty years. The colony stopped listening; the numbers didn't stop."},
	"krayt": {"home": "Speak's Easy", "venue": "shoal", "name": "Krayt", "role": "Rust Shoal quartermaster",
		"flavor": "Pirate quartermaster gone to ground. Swagger stretched thin over genuine terror."},
	"vyper": {"home": "Speak's Easy", "venue": "shoal", "name": "Vyper", "role": "Rust Shoal, Krayt's successor",
		"flavor": "Krayt's second, who was on the channel when the dark took him. Inherited a leaderless crew and a grudge with teeth. The Privateer guild's word now — and the one who worked out how to bend light around a hull."},
	"imari": {"home": "Landing Pad", "venue": "planet", "name": "Elder Imari", "role": "Steward of the Planet Colony",
		"flavor": "Keeps the colony's fields, cisterns, and manifests. The Reach eats her freighters too, and she has started to notice which pilots come back. A Trader-guild contact when the guilds land.",
		"idle": "Fields are in, cisterns full. Nothing pressing, pilot — but it's good to see a ship come home."},
	# He owns the clunker now: THE DIG, his freighter parked in the Verge.
	# "verge" is a venue of its own, so his work is never handed to you by
	# someone else at a desk he has never sat behind.
	"doug": {"home": "The Dig", "venue": "verge", "name": "Doug Diggs",
		"role": "Prospector Guild, the Verge",
		"flavor": "Old rock-hound who's chewed more vacuum than most pilots have flown. Haggard, gruff, honest about the work — the Reach's ore doesn't come easy, and neither does he. The Miner guild's first and last word."},
	"sella": {"home": "Explorer's Union", "venue": "planet", "name": "Cartographer Sella", "role": "Colony Survey Office",
		"flavor": "Runs the colony's dusty little map room and pays hard credits for sensor readings from anywhere in the Reach. Says the charts are 'embarrassingly incomplete.' The seed of the Scout / Explorer guild — she's already keeping a list of who brings her the far dark.",
		"idle": "No new survey work posted. Bring me the far dark whenever you find it."},
}


static func display_name(id: String) -> String:
	return CAST[id]["name"] if CAST.has(id) else id


static func role(id: String) -> String:
	return str(CAST.get(id, {}).get("role", ""))


static func flavor(id: String) -> String:
	return str(CAST.get(id, {}).get("flavor", ""))


## A short SPOKEN one-liner for when the always-visible talk button is pressed but
## this person has nothing queued — so saying hello is never a dead click.
static func idle_line(id: String) -> String:
	return str(CAST.get(id, {}).get("idle",
		"Nothing new right now. Fly safe out there."))


## Portrait texture or null. Drop-in: assets/portraits/<id>.png.
static func portrait(id: String) -> Texture2D:
	var path := "res://assets/portraits/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null


## WHICH TAB this person keeps. Talks wait on their home tab behind a "Talk to
## X" button, announced by a pip, instead of ambushing you the moment you dock
## (docs/npc_homes.md). "" = no home yet — Doug Diggs until his freighter exists.
static func home(id: String) -> String:
	return str(CAST.get(id, {}).get("home", ""))


## Is this NPC standing at the dock the player is currently on?
static func at_venue(id: String, is_station: bool) -> bool:
	var v := str(CAST.get(id, {}).get("venue", "station"))
	return v == ("station" if is_station else "planet")


## Does this NPC hold court at a DOCK at all? Krayt and Vyper live at the Rust
## Shoal, which is neither station nor planet — their work is relayed to you
## (the hermit points you at Krayt), and the conversation itself happens where
## they actually are. So they never block a quest from starting, and their talks
## never present at a dock they aren't standing on.
static func is_dockside(id: String) -> bool:
	var v := str(CAST.get(id, {}).get("venue", "station"))
	return v == "station" or v == "planet"
