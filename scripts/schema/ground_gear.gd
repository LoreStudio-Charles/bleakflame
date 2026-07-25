class_name GroundGearDef
extends ComponentDef
## PERSONAL equipment — what the CHARACTER wears and carries (docs/ground_combat.md).
## Same loot spine as ship gear (grades, marks, affixes, the forge, the tiles) with the
## 9-slot paperdoll the user set as canon:
##   Head · Chest · Feet · Pants · Hands · Waist · Main · Offhand · Grenade
## The six WORN slots contribute MITIGATION (character armor mitigates, never depletes —
## the one deliberate divergence from ship armor, which ablates). Main/Offhand are the
## weapons; a TWO-HANDED Main occupies Offhand too. Worn gear is stat-only (never drawn);
## weapons are drawn via the hand-anchor system.

enum Slot {HEAD, CHEST, FEET, PANTS, HANDS, WAIST, MAIN, OFFHAND, GRENADE}

const SLOT_NAMES := ["Head", "Chest", "Feet", "Pants", "Hands", "Waist", "Main", "Offhand", "Grenade"]

@export var ground_slot := Slot.CHEST

## ---- worn stats (any slot may carry any of these; most carry one) ----
@export var mitigation := 0.0        # fraction; worn total is clamped by GroundStats
@export var health_bonus := 0.0
@export var barrier := 0.0           # personal energy shield (an emitter somewhere on you)
## The CELL: techniques spend energy. Everyone has a base pool (GroundStats) so the
## universal floor works in rags; worn cells deepen it and recharge it faster.
@export var energy := 0.0
@export var energy_recharge := 0.0

## ---- weapon stats (Main/Offhand) ----
@export var damage := 0.0
@export var attack_range := 0.0
@export var cooldown := 1.0
@export var two_handed := false
@export var melee := false
## Drop-in weapon art key: assets/ground/weapons/<art_key>.png (+ optional _south/_north
## variants), grip pixel inside that art. Empty = nothing drawn (fists, worn gear).
@export var art_key := ""
@export var grip_x := 0
@export var grip_y := 0


func is_weapon() -> bool:
	return ground_slot == Slot.MAIN or ground_slot == Slot.OFFHAND


## The drawable views for GroundCharacter.equip_weapon_views — THE one implementation of
## the art discovery (the /arm dev command mirrors it): <art_key>.png is the required
## side view; _south/_north variants are picked up when they exist. Empty dict = nothing
## to draw (melee shivs and worn gear render no sprite; the swing anim still plays).
func weapon_views() -> Dictionary:
	if art_key == "":
		return {}
	var side := "res://assets/ground/weapons/%s.png" % art_key
	if not ResourceLoader.exists(side):
		return {}
	var grip := Vector2(grip_x, grip_y)
	var views := {"side": {"tex": load(side), "grip": grip}}
	for facing in ["south", "north"]:
		var vp := "res://assets/ground/weapons/%s_%s.png" % [art_key, facing]
		if ResourceLoader.exists(vp):
			views[facing] = {"tex": load(vp), "grip": grip}
	return views


func slot_name() -> String:
	return SLOT_NAMES[ground_slot]


func stat_summary() -> String:
	var parts: Array[String] = []
	if damage > 0.0:
		parts.append("dmg %.0f" % damage)
	if attack_range > 0.0:
		parts.append("range %.0f" % attack_range)
	if damage > 0.0:
		parts.append("every %.1fs" % cooldown)
	if two_handed:
		parts.append("two-handed")
	if mitigation > 0.0:
		parts.append("mitigation +%d%%" % int(round(mitigation * 100)))
	if health_bonus > 0.0:
		parts.append("+%.0f health" % health_bonus)
	if barrier > 0.0:
		parts.append("+%.0f barrier" % barrier)
	if energy > 0.0:
		parts.append("+%.0f energy" % energy)
	if energy_recharge > 0.0:
		parts.append("+%.1f recharge/s" % energy_recharge)
	return "%s · %s" % [slot_name(), " · ".join(parts)] if not parts.is_empty() else slot_name()


## Ground gear never fits a ship hardpoint. It reports SYSTEM only so the shared item
## surfaces (Armory grids, tiles, stash) can carry it as sellable cargo — the paperdoll's
## _fit_error refuses anything that isn't the right ship class, so it can't be fitted.
func slot_type() -> HardpointDef.SlotType:
	return HardpointDef.SlotType.SYSTEM
