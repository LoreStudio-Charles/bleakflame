# Capital Defenses — Homeworld Weapon Platforms (PLAN)

Planned with the user 2026-07-23. Capital-grade armament for **Orivel** — the
Galean homeworld — mounted on the **Orivel Orbital Outpost** and on **defense
platform satellites**. "Good tech for the homeworld": these sit a full tier above
anything the fringe sells. Three weapon families: **laser batteries**,
**radar-guided missiles**, **proton torpedoes**.

Not built yet — this is the design + build checklist.

---

## The key finding: the weapons are DATA, the hosts are the work

`WeaponDef` + `Projectile` already implement everything these three need — nothing
in the weapons themselves requires new engine code:

- **Laser** → `beam = true` (instant hit-scan; `beam_tail` for a pulse-lance look).
  Already used by the Ferro Cutter (mining) and the Twinlance pulse.
- **Radar-guided missile** → `homing > 0` with `seek_nearest = false` — the
  **RADIO seeker**: locks the shooter's *selected* target at launch and commits.
  This IS "radar-guided". Already shipped small: the **Radio-Guided Missile Rack**
  (homing 150, grade 3). The capital version is just an up-tier.
- **Proton torpedo** → `magazine > 0` (ordnance, restocked at dock) + big
  `blast_radius` + a slow heavy `projectile_speed`, optionally a little `homing`.
  The **Bombard Rocket Pod** is the fringe seed (blast 48); the torpedo is its
  capital sibling — far bigger, far slower, a ship-killer.

So the **weapons ship as `.tres` files** (schema + generate_sample_data seed). The
real build is the **firing hosts** — the station emplacements and the autonomous
satellite — which today only exist as *hostile* dressing (the pirate den). See
"What needs building" below.

---

## The three weapons (proposed stat blocks)

Anchored to the existing families, scaled to capital grade (Advanced→Bespoke,
Mark 4–5). All are big, slow-tracking guns — the traverse rule (`360 / mark`
deg/s) is load-bearing: Mark 5 = 72°/s, so capital guns **cannot track a
fighter**. That is the whole reason strike craft still matter over the homeworld,
and why the capital wants a screen of escorts (→ the fleet: Supercruiser/Carrier).

### 1. Aegis Lance Battery — LASER
The capital's medium defensive laser: a sustained energy lance, instant on target,
punishing to anything that lingers in the open.
```
beam = true,  beam_tail ≈ 40      # a lance, not a mining dribble
damage ≈ 7 / 0.10s  (~70 dps)     # hit-scan, so every tick lands
weapon_range ≈ 1000               # capital reach, outranges fringe guns
mark = 4,  grade = Advanced
bolt_color = pale gold / ivory    # Galean capital livery (matches Orivel)
```
Role: the workhorse. Mounted many, everywhere. Melts light hulls, chips heavies,
zero travel time so it's the reliable answer to anything close.

### 2. Sentinel Radar Battery — RADAR-GUIDED MISSILE
Up-tier of the Radio Missile Rack: command-guided heavy warheads that ride the
capital's targeting radar to whatever the platform has locked.
```
homing ≈ 120,  seek_nearest = false   # RADIO: locks the selected target, commits
damage ≈ 90,  blast_radius ≈ 34
projectile_speed ≈ 640,  weapon_range ≈ 1200
magazine ≈ 6,  ammo_price (capital, dear)
mark = 4,  grade = Experimental
```
Role: reach-out-and-touch. Long range, guided, area blast — the platform's answer
to a heavy that's standing off. Goes dumb if the lock is broken (the RADIO
weakness), so evasion + LOS still matter.

### 3. Graviton Proton Torpedo — PROTON TORPEDO
The homeworld's ship-killer. A slow, heavy, telegraphed warhead with a huge blast
— murder on a Supercruiser, trivially dodged by a fighter that sees it coming.
```
magazine ≈ 4,  ammo_price (very dear),  blast_radius ≈ 90
damage ≈ 220,  projectile_speed ≈ 340   # slow enough to READ and dodge
homing ≈ 25 (barely — drifts toward the lock, not a chaser)
weapon_range ≈ 1400,  mark = 5,  grade = Bespoke
bolt_color = deep violet-white, fat bolt + a bright launch flash
```
Role: anti-capital siege. The scariest thing over Orivel — but only lands on
something big and slow, or something pinned. Fits the "capital vs capital" tier.

---

## The two host platforms

### Orivel Orbital Outpost — emplacement ring
The drydock ring (already placed, `OrivelOutpost`) gets **WeaponMount
emplacements**: Aegis lances studding the core + landing arms (point defense), a
few Sentinel batteries on the corners, and 2–4 Proton Torpedo launchers as the
heavy teeth. Uses the existing `WeaponMount` (arc + traverse + `sprite_path` mount
art), the same fire-control the pirate den's hostile emplacements use — just on a
friendly, targeting hostiles.

### Defense Platform satellite — the picket ring
The accepted `defense_platform.png` (clean white/blue satellite) becomes an
**autonomous single-weapon turret**: a small static node that acquires and fires
on hostiles in range, then a *ring* of them is scattered to guard Orivel and the
orbital (a minefield of guns, not one big fort). Most carry an Aegis Lance; a few
carry a Sentinel battery. This is the visible "the capital is defended" read and
the reason pirates/Quarn can't just walk in.

---

## Player-facing: homeworld reward tier

"Good tech for the homeworld" = the **reward tier**, gated behind the capital:
- **NOT fringe shop stock.** The Reach station tops out at Mark ~2 salvage.
- Earned by reaching Orivel and/or capital/Guardian standing — a capital
  quartermaster, or salvage off destroyed capital-grade hulls later.
- Ties to the campaign's "bigger port gates heavies" rule (STATION SIZE CAP): the
  homeworld is that bigger port. Mounting these needs the hulls the capital sells
  (Supercruiser/Carrier), so the weapon tier and the ship tier unlock together.

---

## What needs building (in order)

1. **The three `.tres` weapons** — data only, add to generate_sample_data.gd so a
   regen re-seeds them. Icons drop-in (`assets/icons/components/`). *No engine
   code.*
2. **A friendly emplacement host** — the pirate den already mounts hostile
   `WeaponMount`s; generalize that into a reusable turret host the Orbital and the
   defense satellite both use (acquire nearest hostile, respect arc + traverse,
   fire). This is the main new code.
3. **DefenseSatellite node** — the `defense_platform.png` + a turret host + an
   `avoid_radius`; scatter a ring around Orivel/orbital in flight_test.
4. **Arm the Orbital** — add emplacement WeaponMounts to `OrivelOutpost`.
5. **Gating** — where the player can obtain them (capital quartermaster / capital
   salvage). Balance pass with the fleet.

## Open questions
- Do the platforms actually *fight* now (need hostiles out at Orivel — none live
  there yet), or are they dressing until the capital gets its own encounters?
- Are these player-fittable at all in the demo, or capital-flavour only for now?
- Torpedo vs player: fun as a dodge-the-slow-death moment, or reserved for the
  capital-ship tier so a fighter never eats one unfairly?
