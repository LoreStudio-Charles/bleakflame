class_name GroundStats
## THE CHARACTER'S DERIVED STAT BLOCK (docs/ground_combat.md — NO attribute sheet, ever):
## stats derive from the WORN GEAR + weapon + (seams for) skills and profession tier,
## exactly the way a ship's derive from its fit. One function, called wherever the
## character's numbers are needed; nothing else may invent character stats.

const BASE_HEALTH := 100.0
const MITIGATION_CAP := 0.6          # worn plating alone can't make you unkillable
## The bare character's CELL. Techniques spend energy, and the universal floor set must
## work in rags — so the pool starts non-zero and worn cells deepen it from there.
const BASE_ENERGY := 60.0
const BASE_RECHARGE := 1.4
## Bare knuckles — the floor spec so an unarmed character can still scrap.
const UNARMED := {"damage": 4.0, "range": 36.0, "cooldown": 0.8, "melee": true}


## gear = {slot_name: GroundGearDef} (Pilot.ground_gear_items()). Returns the block:
##   {max_health, mitigation, barrier, attack (spec dict), weapon (GroundGearDef|null)}
static func derive(gear: Dictionary) -> Dictionary:
	var health := BASE_HEALTH
	var mit := 0.0
	var barrier := 0.0
	var energy := BASE_ENERGY
	var recharge := BASE_RECHARGE
	var weapon: GroundGearDef = null
	for slot in gear:
		var g: GroundGearDef = gear[slot]
		if g == null:
			continue
		health += g.health_bonus
		mit += g.mitigation
		barrier += g.barrier
		energy += g.energy
		recharge += g.energy_recharge
		if str(slot) == "Main":
			weapon = g
	# Profession combat tier scales the PLAYER's pool with level — the same seam ships
	# use (player-only there too). Pilot.hull_mult carries tier x level.
	health *= Pilot.hull_mult()
	var attack := UNARMED.duplicate()
	if weapon != null and weapon.damage > 0.0:
		attack = {"damage": weapon.damage * Pilot.damage_mult(), "range": weapon.attack_range,
			"cooldown": weapon.cooldown, "melee": weapon.melee}
	return {
		"max_health": health,
		"mitigation": clampf(mit, 0.0, MITIGATION_CAP),
		"barrier": barrier,
		"max_energy": energy,
		"energy_recharge": recharge,
		"attack": attack,
		"weapon": weapon,
	}
