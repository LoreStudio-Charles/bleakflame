class_name SampleBuilds
## Dev-time sample loadouts shared by the flight test and the assembly viewer.
## `current` is static so the selection survives scene switches — F1 always
## inspects the ship currently being flown.

static var current := 3  # starter: Rooster (index 3)
## Indices of ships the player owns. Ships are bought at the Shipyard and
## boarded in the Hangar; 1-4 keys only work docked, for owned ships.
static var owned: Array[int] = [3]

## Player builds are cached so refits persist across ship swaps, deaths, and
## scene changes for the whole session. Pirate builds stay fresh per spawn.
static var _player_builds: Dictionary = {}


static func count() -> int:
	return 6


static func get_build(index: int) -> ShipBuild:
	if not _player_builds.has(index):
		_player_builds[index] = _create(index)
	return _player_builds[index]


static func _create(index: int) -> ShipBuild:
	match index:
		0:
			# Mismatched nose guns: the Afterjet's power draw forces the trade.
			return _make("res://data/hulls/sparrowhawk.tres", {
				0: "res://data/components/weapons/twinlance_pulse.tres",
				1: "res://data/components/weapons/vk2_autocannon.tres",
				2: "res://data/components/weapons/vk2_autocannon.tres",
				3: "res://data/components/engines/afterjet_sprint.tres",
				4: "res://data/components/reactors/hearth_fusion.tres",
				5: "res://data/components/defense/bulwark_plating.tres",
				6: "res://data/components/couplings/standard_coupling.tres",
			})
		1:
			return _make("res://data/hulls/kestrel.tres", {
				0: "res://data/components/weapons/vk2_autocannon.tres",
				1: "res://data/components/engines/drifter_ion.tres",
				2: "res://data/components/engines/drifter_ion.tres",
				3: "res://data/components/reactors/hearth_fusion.tres",
				4: "res://data/components/systems/wayfarer_sensors.tres",
				6: "res://data/components/systems/strapdown_cargo_pod.tres",
				7: "res://data/components/couplings/standard_coupling.tres",
			})
		3:
			# The Rooster: a little of everything, a lot of nothing.
			return _make("res://data/hulls/rooster.tres", {
				0: "res://data/components/weapons/vk2_autocannon.tres",
				1: "res://data/components/weapons/vk2_autocannon.tres",
				2: "res://data/components/engines/vectorjet.tres",
				3: "res://data/components/reactors/hearth_fusion.tres",
				4: "res://data/components/defense/veil_shield.tres",
				5: "res://data/components/systems/wayfarer_sensors.tres",
				6: "res://data/components/systems/strapdown_cargo_pod.tres",
				# JUNK HULL, JUNK COUPLING: the Rooster is Flotsam-grade, and its
				# bus is the cheapest thing that works. Upgrading it is one of the
				# first upgrades that visibly changes what you can DO.
				7: "res://data/components/couplings/scrap_coupling.tres",
			})
		4:
			# The Cutlass: fastest thing a player can buy. Twin fixed talons,
			# an oversized drive, and a knife-edge power margin.
			return _make("res://data/hulls/cutlass.tres", {
				0: "res://data/components/weapons/vk2_autocannon.tres",
				1: "res://data/components/weapons/vk2_autocannon.tres",
				2: "res://data/components/engines/afterjet_sprint.tres",
				3: "res://data/components/reactors/hearth_fusion.tres",
				4: "res://data/components/defense/veil_shield.tres",
				5: "res://data/components/systems/wayfarer_sensors.tres",
				6: "res://data/components/couplings/standard_coupling.tres",
			})
		5:
			# The Dowager: first MEDIUM a player can own — a beaten-up smuggler's
			# boat built around ONE big gun. The Mk2 foredeck mount + Mk2 reactor
			# to feed it are the whole pitch; everything else is Mk1 and tired.
			return _make("res://data/hulls/dowager.tres", {
				0: "res://data/components/weapons/heatseeker_missile_pod.tres", # her way out of a scrap (Mk2, homing, low ammo)
				1: "res://data/components/weapons/vk2_autocannon.tres",      # the spite gun for the long haul
				2: "res://data/components/engines/vectorjet.tres",           # a tired drive
				3: "res://data/components/reactors/overdrive_bottle.tres",   # Mk2 reactor
				4: "res://data/components/defense/patchplate_armor.tres",    # patched plate
				5: "res://data/components/systems/falsebottom_hold.tres",    # her upgraded smuggler deck (40 cargo)
				6: "res://data/components/couplings/scrap_coupling.tres",    # junk hull, junk bus
			})
		_:
			# Pure hauler. No decoupler aboard anything: Disconnected flight
			# is shelved until exotic thrusters/hulls bring the tag back.
			return _make("res://data/hulls/mule.tres", {
				0: "res://data/components/weapons/junker_slugthrower.tres",
				1: "res://data/components/engines/vectorjet.tres",
				2: "res://data/components/reactors/hearth_fusion.tres",
				3: "res://data/components/defense/veil_shield.tres",
				4: "res://data/components/defense/patchplate_armor.tres",
				5: "res://data/components/systems/strapdown_cargo_pod.tres",
				6: "res://data/components/couplings/standard_coupling.tres",
			})


## Neutral lane hauler: the Mule stripped of its gun and packed with cargo — a
## civilian that CAN'T really fight back, which is exactly what makes robbing one
## a moral choice with teeth. Shield + armor so it's a chase, not a one-shot.
static func trader_mule() -> ShipBuild:
	return _make("res://data/hulls/mule.tres", {
		1: "res://data/components/engines/vectorjet.tres",
		2: "res://data/components/reactors/hearth_fusion.tres",
		3: "res://data/components/defense/veil_shield.tres",
		4: "res://data/components/defense/patchplate_armor.tres",
		5: "res://data/components/systems/strapdown_cargo_pod.tres",
	})


## Pirate loadouts — enemy variety is just other builds over the same data.
## Raider: stripped Kestrel, fast and fragile. Brawler: budget Sparrowhawk
## with scavenged armor.
static func pirate_raider() -> ShipBuild:
	return _make("res://data/hulls/kestrel.tres", {
		0: "res://data/components/weapons/junker_slugthrower.tres",
		1: "res://data/components/engines/drifter_ion.tres",
		2: "res://data/components/engines/drifter_ion.tres",
		3: "res://data/components/reactors/scrap_cell_pile.tres",
	})


static func pirate_brawler() -> ShipBuild:
	return _make("res://data/hulls/sparrowhawk.tres", {
		0: "res://data/components/weapons/vk2_autocannon.tres",
		1: "res://data/components/weapons/vk2_autocannon.tres",
		3: "res://data/components/engines/vectorjet.tres",
		4: "res://data/components/reactors/scrap_cell_pile.tres",
		5: "res://data/components/defense/patchplate_armor.tres",
	})


static func pirate_wasp() -> ShipBuild:
	return _make("res://data/hulls/wasp.tres", {
		0: "res://data/components/weapons/vk2_autocannon.tres",
		1: "res://data/components/engines/vectorjet.tres",
		2: "res://data/components/reactors/scrap_cell_pile.tres",
	})


## Mini-boss: flies gear the shop doesn't sell — killing it is the only way
## to see Experimental drops this early.
static func pirate_vulture() -> ShipBuild:
	return _make("res://data/hulls/vulture.tres", {
		0: "res://data/components/weapons/twinlance_pulse.tres",
		1: "res://data/components/weapons/vk2_autocannon.tres",
		2: "res://data/components/engines/afterjet_sprint.tres",
		3: "res://data/components/reactors/overdrive_bottle.tres",
		4: "res://data/components/defense/aegis_composite.tres",
		5: "res://data/components/defense/bulwark_plating.tres",
	})


## Station guard wing: same hulls the Reach flies, kept in navy trim.
## Better-fed than pirates — factory reactors and real shields, because the
## harbor pays its defenders.
static func guardian_kestrel() -> ShipBuild:
	return _make("res://data/hulls/kestrel.tres", {
		0: "res://data/components/weapons/vk2_autocannon.tres",
		1: "res://data/components/engines/vectorjet.tres",
		2: "res://data/components/engines/vectorjet.tres",
		3: "res://data/components/reactors/hearth_fusion.tres",
	})


static func guardian_sparrowhawk() -> ShipBuild:
	return _make("res://data/hulls/sparrowhawk.tres", {
		0: "res://data/components/weapons/vk2_autocannon.tres",
		1: "res://data/components/weapons/twinlance_pulse.tres",
		3: "res://data/components/engines/vectorjet.tres",
		4: "res://data/components/reactors/hearth_fusion.tres",
		5: "res://data/components/defense/veil_shield.tres",
	})


static func guardian_vulture() -> ShipBuild:
	return _make("res://data/hulls/vulture.tres", {
		0: "res://data/components/weapons/twinlance_pulse.tres",
		1: "res://data/components/weapons/vk2_autocannon.tres",
		2: "res://data/components/engines/afterjet_sprint.tres",
		3: "res://data/components/reactors/hearth_fusion.tres",
		4: "res://data/components/defense/veil_shield.tres",
		5: "res://data/components/defense/bulwark_plating.tres",
	})


## Galean Navy line-of-battle capital ship — the first Mk4 SUPER_HEAVY, the fleet
## that makes the Orivel drydocks matter. Armed with the NAVY set (not fringe
## junk): Mk4 Aegis Lance lasers on the mains + spinal, a Mk3 Naval Autocannon
## secondary, skeet arrays on the Mk1 point-defense mounts (traverse 360/mark =
## fast) to swat the fighters the slow lances can't track. NPC fleet.
static func galean_supercruiser() -> ShipBuild:
	return _make("res://data/hulls/supercruiser.tres", {
		0: "res://data/components/weapons/aegis_lance_battery.tres",   # Spinal Lance
		1: "res://data/components/weapons/aegis_lance_battery.tres",   # Dorsal Main
		2: "res://data/components/weapons/aegis_lance_battery.tres",   # Ventral Main
		3: "res://data/components/weapons/skeet_pd_array.tres",        # Port PD
		4: "res://data/components/weapons/skeet_pd_array.tres",        # Starboard PD
		5: "res://data/components/weapons/naval_autocannon.tres",      # Secondary
		6: "res://data/components/engines/afterjet_sprint.tres",       # Main Drive
		7: "res://data/components/engines/afterjet_sprint.tres",       # Aux Drive
		8: "res://data/components/reactors/overdrive_bottle.tres",     # Capital Reactor
		9: "res://data/components/defense/bulwark_plating.tres",       # Armor Belt Port
		10: "res://data/components/defense/aegis_composite.tres",      # Armor Belt Starboard
		11: "res://data/components/systems/wayfarer_sensors.tres",     # Command Deck
		12: "res://data/components/couplings/standard_coupling.tres",  # Coupling
	})


## Elite variant: the base line ship with the EXPERIMENTAL (purple) Sentinel Radar
## Battery swapped onto a main mount — the reach-and-blast piece the fleet only
## hands to its best crews. The "one or two purple weapons on variants" (user).
static func galean_supercruiser_elite() -> ShipBuild:
	var b := galean_supercruiser()
	b.slots[1] = load("res://data/components/weapons/sentinel_radar_battery.tres")
	return b


static func _make(hull_path: String, fits: Dictionary) -> ShipBuild:
	var b := ShipBuild.new()
	b.hull = load(hull_path)
	for index in fits:
		b.slots[index] = load(fits[index])
	return b
