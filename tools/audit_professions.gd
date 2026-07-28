extends SceneTree
## PROFESSION ↔ FACTION ↔ QUARTER AUDIT (user, 2026-07-27: "verify that every
## profession has a profession quarter and faction associated").
##
## Every commission should be THREE things that agree with each other:
##   · a PROFESSION  — the player's commission (Professions.LIST)
##   · a FACTION     — the body that holds the ledger and can have opinions (Factions.LIST)
##   · a QUARTER     — the room its leader stands in, on the venue shell
##
## They drifted apart because each was added for its own reason: professions came
## with progression, factions came with the hostility matrix, and quarters came with
## the bespoke screens. This prints the join so the gaps are MEASURED rather than
## remembered — the same reason campaign_map.gd exists next door.
##
##   <godot> --headless --path . --script res://tools/audit_professions.gd

## Which venue each leader holds court in, and whether that venue is a VenueLayout
## quarter or a tab on the shared dock screen. Read from the cast where possible.
const QUARTER_SCREENS := {
	"shoal": "SpeakEasy (venue shell)",
	"verge": "ProspectDeck (venue shell)",
}


func _init() -> void:
	var gaps := 0
	print("\n=== PROFESSION / FACTION / QUARTER ===\n")
	print("%-12s %-18s %-14s %-24s %s" % ["COMMISSION", "LEADER", "STANDING KEY",
		"FACTION", "QUARTER"])
	print("-".repeat(104))

	for p in Professions.LIST:
		var pid := str(p.id)
		var leader := str(p.get("leader", ""))
		var venue := Npcs.venue_of(leader)
		var quarter: String = QUARTER_SCREENS.get(venue, "%s tab (DockScreen)" % venue)

		# Which faction keeps this commission's ledger? A faction declares the key it
		# uses, so search back from the key the profession is filed under.
		var fac := ""
		for fid in Factions.LIST:
			if Factions.standing_key(str(fid)) == pid:
				fac = str(fid)
				break
		var fac_txt: String = "%s (%s)" % [fac, Factions.display_name(fac)] if fac != "" \
			else "— none —"
		if fac == "":
			gaps += 1
		print("%-12s %-18s %-14s %-24s %s" % [pid, Npcs.display_name(leader), pid,
			fac_txt, quarter])

	print("\n=== FACTIONS WITH NO COMMISSION ===")
	for fid in Factions.LIST:
		var key := Factions.standing_key(str(fid))
		var owned := false
		for p in Professions.LIST:
			if str(p.id) == key:
				owned = true
		if not owned:
			print("  %-10s %-30s (%s)" % [fid, Factions.display_name(str(fid)),
				"no player commission — world faction"])

	print("\n=== ATTITUDE ROWS ===")
	for fid in Factions.LIST:
		var row: Dictionary = Factions.BASE.get(str(fid), {})
		print("  %-10s %s" % [fid, "neutral to everyone" if row.is_empty() \
			else "%d opinion(s)" % row.size()])

	print("\n%d commission(s) with no faction.\n" % gaps)
	quit(0)
