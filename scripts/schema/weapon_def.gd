class_name WeaponDef
extends ComponentDef

@export var damage := 5.0
@export var fire_interval := 0.3         # seconds between shots
@export var projectile_speed := 900.0
@export var weapon_range := 700.0
## Turret traverse in deg/s. 0 = use the size formula: big guns track slowly,
## which is what lets small ships dance inside a capital ship's arcs.
@export var traverse_override := 0.0
## Ore extracted per bolt from mineable asteroids. Mining lasers are weapons
## (weapon slot, weapon rules) that trade combat damage for yield — combat
## guns chip rock at a fraction of their damage instead.
@export var mining_power := 0.0
## Bolt identity: every weapon family has a color and a size. Rendered with
## additive blending — the gl_compatibility-safe fake emissive.
@export var bolt_color := Color(1.0, 0.85, 0.5)
@export var bolt_scale := 1.0
## Beam weapons fire a continuous ray (instant hit along the barrel line,
## damage per fire_interval tick) instead of spawning projectiles. Lasers
## are beams; cannons and slugthrowers stay ballistic.
@export var beam := false
## PULSE lasers: > 0 gives the projectile a beam tail of this length. The
## light-front races out generating the beam behind it, then the tail
## collapses forward into the impact point — beam on, beam off, recharge.
@export var beam_tail := 0.0
## ORDNANCE: magazine > 0 makes this an ammo weapon — rounds run dry in
## flight and restock at dock for ammo_price credits each (the economy
## sink guns don't have; guns stay energy/ammoless).
@export var magazine := 0
@export var ammo_price := 0
## Extra effective target radius for this weapon's shots — fat warheads
## connect where a bolt would graze past. Stacks with player shot grace.
@export var hit_bonus := 0.0
## Proximity-fuzed ordnance: > 0 = the shot DETONATES when a target comes
## near (AA-style) and splash-damages everything inside this radius, with
## falloff toward the rim. The splash is what kills — near enough IS a hit.
@export var blast_radius := 0.0
## HOMING: > 0 = the shot STEERS toward a target, this many degrees/sec of turn
## (0 = a straight bolt). Missiles track; guns don't. Also the ON-SWITCH: >0
## means "this homes" even when `homing_by_band` supplies the actual turn rate,
## and it's the fallback deg/second rate against a size-less mark (station, rock).
@export var homing := 0.0
## Seeker type (homing only): true = HEAT, fire-and-forget, re-acquires the
## nearest target every frame (hard to lose). false = RADIO, locks the shooter's
## SELECTED target at launch and commits to it (precise, but dumb if it's lost).
@export var seek_nearest := false
## PER-SIZE homing table (homing only): bend in DEGREES PER 10 UNITS TRAVELLED,
## indexed by the TARGET's size band [LIGHT, MEDIUM, HEAVY, SUPER_HEAVY,
## SUPER_HEAVY_PLUS]. Per-DISTANCE, not per-second, so it's speed-independent and
## easy to tune (a fast bolt and a slow one bend the same over the same ground).
## Empty = flat deg/second `homing` for everyone. This is how one weapon tracks the
## small nimble hulls harder (a lance) while another tracks only the big ones (a
## proton torpedo: ~0 vs a fighter, high vs a capital — "murder on a cruiser,
## dodged by a swarm"). Needs exactly 5 entries; a non-ship mark falls back to `homing`.
@export var homing_by_band: PackedFloat32Array = PackedFloat32Array()


func traverse_speed() -> float:
	return traverse_override if traverse_override > 0.0 else 360.0 / mark


func stat_summary() -> String:
	var out := "dmg %.0f / %.2fs  (%.1f dps)   range %.0f   traverse %.0f deg/s" % [
		damage, fire_interval, damage / fire_interval, weapon_range, traverse_speed()]
	if magazine > 0:
		out += "   mag %d (%dc/rd)" % [magazine, ammo_price]
	if blast_radius > 0.0:
		out += "   blast %.0f" % blast_radius
	return out


func slot_type() -> HardpointDef.SlotType:
	return HardpointDef.SlotType.WEAPON
