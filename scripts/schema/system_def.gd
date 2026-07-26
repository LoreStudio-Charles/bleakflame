class_name SystemDef
extends ComponentDef
## Utility catch-all: computers, sensors, cargo, cloaks. Tags let hulls and
## effects care about kinds without new slot types (e.g. "computer",
## "flight_decoupler" — the tag that unlocks Disconnected flight mode).

@export var tags: PackedStringArray = []
@export var cargo_capacity := 0.0
@export var sensor_range := 0.0
## ROLE IDENTIFICATION (user, 2026-07-25) — how far this suite can read a
## contact's ROLE (a rare AI specialist: mender / warden / binder), 0 = it can't.
##
## A SEPARATE, SHORTER REACH than `sensor_range` on purpose: detecting a ship and
## understanding what it does are different jobs. A contact appears at the edge of
## sensors and stays an unknown quantity until you close — which is the
## interesting state, and it is why this is a range rather than a flag.
##
## THIS IS A CAPABILITY YOU BUY. Ordinary sensors leave it at 0; it arrives at
## ADVANCED (blue) grade and level 10+, on the Augur Sensor Array. Role used to be
## painted on every specialist's hull for free, which both gave it away
## unconditionally and fought with faction livery for the same channel.
@export var role_id_range := 0.0
## A profession id (Professions) that alone may FIT this system, or "" for
## anyone. Signature modules (cloak = "privateer") gate on the commission; the
## Armory refuses to fit it otherwise, visibly. Fitted gear keeps working if you
## later switch commissions — the lock is on FITTING, not on running.
@export var profession_lock := ""
## Loose stats bag for one-off system effects until they earn typed fields.
@export var extra := {}


func has_tag(tag: String) -> bool:
	return tag in tags


## Can `profession_id` fit this? "" lock = anyone; else must match.
func fittable_by(profession_id: String) -> bool:
	return profession_lock == "" or profession_lock == profession_id


func stat_summary() -> String:
	var parts: Array[String] = []
	if cargo_capacity > 0.0:
		parts.append("+%.0f cargo hold" % cargo_capacity)
	if sensor_range > 0.0:
		parts.append("sensor range %.0f" % sensor_range)
	if role_id_range > 0.0:
		parts.append("identifies contact ROLE to %.0f" % role_id_range)
	if has_tag("flight_decoupler"):
		parts.append("unlocks Disconnected flight")
	if not tags.is_empty():
		parts.append("[%s]" % ", ".join(tags))
	return "   ".join(parts)


## SENSORS RIDE THEIR OWN SLOT (2026-07-25, user). Keyed off the existing
## "sensor" tag rather than a new class, so every sensor in the game moved across
## with no .tres surgery and anything tagged later follows automatically.
func slot_type() -> HardpointDef.SlotType:
	return HardpointDef.SlotType.SENSOR if has_tag("sensor") else HardpointDef.SlotType.SYSTEM
