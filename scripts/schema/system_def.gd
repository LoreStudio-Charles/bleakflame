class_name SystemDef
extends ComponentDef
## Utility catch-all: computers, sensors, cargo, cloaks. Tags let hulls and
## effects care about kinds without new slot types (e.g. "computer",
## "flight_decoupler" — the tag that unlocks Disconnected flight mode).

@export var tags: PackedStringArray = []
@export var cargo_capacity := 0.0
@export var sensor_range := 0.0
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
	if has_tag("flight_decoupler"):
		parts.append("unlocks Disconnected flight")
	if not tags.is_empty():
		parts.append("[%s]" % ", ".join(tags))
	return "   ".join(parts)


func slot_type() -> HardpointDef.SlotType:
	return HardpointDef.SlotType.SYSTEM
