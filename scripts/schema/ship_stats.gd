class_name ShipStats
## Aggregation and validation for a ShipBuild.
## Stacking rule (set once, here, forever): flat stats ADD. Percentage
## modifiers (affixes, later) MULTIPLY. No component does its own math.


static func aggregate(build: ShipBuild) -> Dictionary:
	var s := {
		"mass": build.hull.mass,
		"hull_hp": build.hull.hull_hp,
		"cargo": build.hull.cargo_base,
		"thrust": 0.0,
		"power_output": 0.0,
		"power_draw": 0.0,
		"energy_capacity": 0.0,
		"energy_recharge": 0.0,
		"shield_hp": 0.0,
		"shield_regen": 0.0,
		"armor_hp": 0.0,
		"dps": 0.0,
		"sensor_range": 0.0,
		# How far a contact's ROLE can be read (a rare AI specialist). A SHORTER
		# reach than sensor_range: seeing a ship and knowing what it does are
		# different jobs. 0 = you cannot; it arrives on ADVANCED, level-10+ sensors.
		"role_id_range": 0.0,
		# How far the ship can PULL salvage. A MAX, not a sum -- two scoops do not
		# reach twice as far. 0 here still leaves the hull's own baseline.
		"interaction_range": 0.0,
		# Miner sensor: range at which mineable rock paints the radar. 0 by default;
		# the Miner commission grants it (ship.apply_build), and gear may add later.
		"ore_sense": 0.0,
	}
	for comp: ComponentDef in build.slots.values():
		s.mass += comp.mass
		s.power_draw += comp.power_draw
		if comp is WeaponDef:
			s.dps += comp.damage / comp.fire_interval
		elif comp is EngineDef:
			s.thrust += comp.thrust
		elif comp is ReactorDef:
			s.power_output += comp.power_output
			s.energy_capacity += comp.energy_capacity
			s.energy_recharge += comp.energy_recharge
		elif comp is DefenseDef:
			s.shield_hp += comp.shield_hp
			s.shield_regen += comp.shield_regen
			s.armor_hp += comp.armor_hp
		elif comp is CouplingDef:
			# Stat-stick seam: a fine Coupling is worth fitting for more than room.
			s.shield_hp += comp.bonus_shield_hp
			s.armor_hp += comp.bonus_armor_hp
			s.cargo += comp.bonus_cargo
		elif comp is SystemDef:
			s.cargo += comp.cargo_capacity
			s.sensor_range = maxf(s.sensor_range, comp.sensor_range)
			s.role_id_range = maxf(s.role_id_range, comp.role_id_range)
			s.interaction_range = maxf(s.interaction_range, comp.interaction_range)
	# CHIPS in the Coupling carry their own mass and may ship hardware of their
	# own (the Killshot coilgun's optics), so they aggregate too.
	for chip in build.chips:
		if chip == null:
			continue
		s.mass += chip.mass
		s.power_draw += chip.power_draw
		s.sensor_range = maxf(s.sensor_range, chip.sensor_range)
		# No role_id_range from chips: that stat lives on SystemDef (the sensor
		# suite), and a chip is an AbilityChipDef. If a chip should ever grant
		# role identification, give AbilityChipDef the field first.
	s["accel"] = s.thrust / s.mass if s.mass > 0.0 else 0.0
	s["power_margin"] = s.power_output - s.power_draw
	return s


## MVP fit rules — power is a HARD constraint (soft/runtime power management
## is planned post-MVP; the data already models draw vs output for it).
static func validate(build: ShipBuild) -> Array[String]:
	var errors: Array[String] = []
	if build.hull == null:
		return ["build has no hull"]

	for index in build.slots:
		if index < 0 or index >= build.hull.hardpoints.size():
			errors.append("slot %d does not exist on %s" % [index, build.hull.display_name])
			continue
		var hp := build.hull.hardpoints[index]
		var comp: ComponentDef = build.slots[index]
		if comp.slot_type() != hp.slot_type:
			errors.append("%s cannot fit %s (%s slot)" % [
				comp.display_name, hp.display_name,
				HardpointDef.SlotType.keys()[hp.slot_type]])
		if comp.mark > hp.mark:
			errors.append("%s is Mark %d but %s only fits up to Mark %d" % [
				comp.display_name, comp.mark, hp.display_name, hp.mark])

	if not build.hull.fits_art_budget():
		errors.append("%s exceeds its %s art budget (%d px canvas)" % [
			build.hull.display_name,
			HullDef.SizeBand.keys()[build.hull.size_band].capitalize(),
			HullDef.ART_PX[build.hull.size_band]])

	var s := aggregate(build)
	if s.power_draw > s.power_output:
		errors.append("LOAD exceeds CAPACITY: %.0f load vs %.0f capacity" % [s.power_draw, s.power_output])
	if s.power_output <= 0.0:
		errors.append("no reactor fitted")
	if s.thrust <= 0.0:
		errors.append("no engine fitted")
	return errors
