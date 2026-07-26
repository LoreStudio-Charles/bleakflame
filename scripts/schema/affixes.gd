class_name Affixes
## The loot layer: dropped components roll affixes — the shop sells clean
## factory gear, salvage is where the weird treasures come from.
##
## Affixes have FIXED magnitudes: an item is fully determined by its base
## .tres plus its affix id list, so saves store {base, affixes} and forge()
## rebuilds the identical item. Variance comes from WHICH affixes rolled,
## not from magnitude ranges (those arrive with a future crafting layer).
##
## Grade drives the roll (the day-one grade table, finally implemented):
## Flotsam carries a DRAWBACK, Experimental drips with power.

const POOL := {
	# --- weapons ---
	"sharpened": {"prefix": "Sharpened", "line": "+18% damage", "drawback": false},
	"rapid": {"prefix": "Rapid", "line": "+14% fire rate", "drawback": false},
	"longbore": {"prefix": "Longbore", "line": "+22% range", "drawback": false},
	"swift": {"prefix": "Swift", "line": "+30% projectile speed", "drawback": false},
	"tracking": {"prefix": "Tracking", "line": "+60% turret traverse", "drawback": false},
	"deeprack": {"prefix": "Deep-Rack", "line": "+50% magazine", "drawback": false},
	# --- engines ---
	"overtuned": {"prefix": "Overtuned", "line": "+15% thrust", "drawback": false},
	# --- reactors ---
	"surging": {"prefix": "Surging", "line": "+12% capacity", "drawback": false},
	# --- defense ---
	"dense": {"prefix": "Dense-Plated", "line": "+20% armor", "drawback": false},
	"reinforced": {"prefix": "Reinforced", "line": "+15% shield", "drawback": false},
	"harmonic": {"prefix": "Harmonic", "line": "+35% shield regen", "drawback": false},
	# --- systems ---
	"farsight": {"prefix": "Farsight", "line": "+25% sensor range", "drawback": false},
	"capacious": {"prefix": "Capacious", "line": "+30% cargo space", "drawback": false},
	# --- any slot ---
	"featherlight": {"prefix": "Featherlight", "line": "-28% mass", "drawback": false},
	"efficient": {"prefix": "Efficient", "line": "-25% load", "drawback": false},
	# --- drawbacks (Flotsam's curse) ---
	"ballast": {"prefix": "Ballast-Fouled", "line": "+45% mass", "drawback": true},
	# --- GROUND gear (GroundGearDef: personal weapons + worn kit) ---
	"keen": {"prefix": "Keen", "line": "+18% damage", "drawback": false},
	"quickdraw": {"prefix": "Quickdraw", "line": "-12% cooldown", "drawback": false},
	"farshot": {"prefix": "Farshot", "line": "+20% reach", "drawback": false},
	"hardened": {"prefix": "Hardened", "line": "+25% mitigation", "drawback": false},
	"warding": {"prefix": "Warding", "line": "+12 barrier", "drawback": false},
	"hungry": {"prefix": "Power-Hungry", "line": "+40% load", "drawback": true},
}


static func is_drawback(id: String) -> bool:
	return POOL.has(id) and POOL[id]["drawback"]


static func text(id: String) -> String:
	if not POOL.has(id):
		return id
	return "%s — %s" % [POOL[id]["prefix"], POOL[id]["line"]]


## Positive affixes this component could roll.
static func eligible(comp: ComponentDef) -> Array[String]:
	# Ground gear rolls its OWN pool (its stats live on different properties).
	if comp is GroundGearDef:
		var g: Array[String] = ["featherlight"]
		if (comp as GroundGearDef).is_weapon():
			g.append_array(["keen", "quickdraw", "farshot"])
		if comp.mitigation > 0.0:
			g.append("hardened")
		if comp.barrier > 0.0 or (comp as GroundGearDef).ground_slot == GroundGearDef.Slot.WAIST:
			g.append("warding")
		return g
	var out: Array[String] = ["featherlight"]
	if comp.power_draw > 0.0:
		out.append("efficient")
	if comp is WeaponDef:
		out.append_array(["sharpened", "rapid", "longbore", "swift", "tracking"])
		if comp.magazine > 0:
			out.append("deeprack")
	elif comp is EngineDef:
		out.append("overtuned")
	elif comp is ReactorDef:
		out.append("surging")
	elif comp is DefenseDef:
		if comp.armor_hp > 0.0:
			out.append("dense")
		if comp.shield_hp > 0.0:
			out.append_array(["reinforced", "harmonic"])
	elif comp is SystemDef:
		if comp.sensor_range > 0.0:
			out.append("farsight")
		if comp.cargo_capacity > 0.0:
			out.append("capacious")
	return out


static func eligible_drawbacks(comp: ComponentDef) -> Array[String]:
	var out: Array[String] = ["ballast"]
	if comp.power_draw > 0.0:
		out.append("hungry")
	return out


## Roll at drop time. Returns the original (shared) resource when nothing
## rolls — only affixed items pay the duplicate cost.
static func roll_for_drop(comp: ComponentDef) -> ComponentDef:
	var positives := 0
	var drawbacks := 0
	match comp.grade:
		Grades.Grade.FLOTSAM:
			drawbacks = 1
			positives = 1 if randf() < 0.4 else 0
		Grades.Grade.SALVAGE:
			positives = 1 if randf() < 0.4 else 0
		Grades.Grade.STANDARD:
			positives = 1 if randf() < 0.6 else 0
		Grades.Grade.ADVANCED:
			positives = randi_range(1, 2)
		_:
			positives = randi_range(2, 3)   # Experimental and above
	if positives == 0 and drawbacks == 0:
		return comp
	var ids: Array[String] = []
	var candidates := eligible(comp)
	candidates.shuffle()
	for i in mini(positives, candidates.size()):
		ids.append(candidates[i])
	if drawbacks > 0:
		var bad := eligible_drawbacks(comp)
		bad.shuffle()
		for i in mini(drawbacks, bad.size()):
			ids.append(bad[i])
	if ids.is_empty():
		return comp
	return forge(comp, ids)


## Deterministic: base + ids -> the exact same item, every time. Also the
## save-load path.
static func forge(base: ComponentDef, ids: Array) -> ComponentDef:
	var comp: ComponentDef = base.duplicate()
	comp.base_path = base.base_path if base.base_path != "" else base.resource_path
	comp.affix_ids = PackedStringArray(ids)
	for id in ids:
		_mutate(comp, str(id))
	var prefix_id := str(ids[0])
	for id in ids:
		if not is_drawback(str(id)):
			prefix_id = str(id)
			break
	comp.display_name = "%s %s" % [POOL[prefix_id]["prefix"], base.display_name]
	return comp


static func rebuild(base_path: String, ids: Array) -> ComponentDef:
	if not ResourceLoader.exists(base_path):
		return null
	var base: ComponentDef = load(base_path)
	if ids.is_empty():
		return base
	return forge(base, ids)


static func _mutate(comp: ComponentDef, id: String) -> void:
	match id:
		"sharpened":
			comp.damage *= 1.18
		"rapid":
			comp.fire_interval *= 0.88
		"longbore":
			comp.weapon_range *= 1.22
		"swift":
			comp.projectile_speed *= 1.3
		"tracking":
			# Reads the CURRENT speed first, so this lifts an authored traverse
			# as happily as a mark-derived one.
			comp.traverse = comp.traverse_speed() * 1.6
		"deeprack":
			comp.magazine = int(comp.magazine * 1.5)
		"keen":
			comp.damage *= 1.18
		"quickdraw":
			comp.cooldown *= 0.88
		"farshot":
			comp.attack_range *= 1.2
		"hardened":
			comp.mitigation *= 1.25
		"warding":
			comp.barrier += 12.0
		"overtuned":
			comp.thrust *= 1.15
		"surging":
			comp.power_output *= 1.12
		"dense":
			comp.armor_hp *= 1.2
		"reinforced":
			comp.shield_hp *= 1.15
		"harmonic":
			comp.shield_regen *= 1.35
		"farsight":
			comp.sensor_range *= 1.25
		"capacious":
			comp.cargo_capacity *= 1.3
		"featherlight":
			comp.mass *= 0.72
		"efficient":
			comp.power_draw *= 0.75
		"ballast":
			comp.mass *= 1.45
		"hungry":
			comp.power_draw *= 1.4
