# Professions — reference sheet

**Purpose.** One page holding the *gist* of each of the six professions as they
exist today, so the full design (including the two specialization trees each)
can be written against real numbers instead of memory.

**Scope.** This is a SNAPSHOT of what is decided and built. The long-form design
history, faction/piracy system, and open questions live in
`docs/progression_professions.md` — that file stays the source of truth for the
*model*; this one is the per-profession cheat sheet.

Code: `scripts/professions.gd`, `scripts/skills.gd`, `scripts/pilot.gd`,
`scripts/standing.gd`, `scripts/abilities.gd`, `data/components/systems/*.tres`.

---

## The shared chassis (everything below rides on this)

**Levels** come from banked `Wallet.xp`, retroactively — cap **60**, curve
`50 * (L-1)^1.6`. No profession grants levels.

**Skill points**: 1 per 4 levels → **15 at cap**. Enough to differentiate, not
enough to buy a whole profession.

**Attributes per level.** A profession sets a single COMBAT TIER that scales
four stats identically — there are no separate per-stat curves today:

| Stat | Formula | Source |
|---|---|---|
| Hull | `× (1 + level × tier)` | `Pilot.hull_mult()` |
| Armor | `× (1 + level × tier)` | `Pilot.armor_mult()` |
| Shield HP | `× (1 + level × tier)` | `Pilot.shield_hp_mult()` |
| Damage | `× (1 + level × tier)` | `Pilot.damage_mult()` |

| Tier | Value | At level 60 | Who |
|---|---|---|---|
| Combat | 0.02 | **+120%** | Guardian, Privateer |
| Field | 0.015 | +90% | Miner, Scout |
| Support | 0.01 | +60% | Trader, Science |
| *(none)* | 0.01 | +60% | uncommissioned baseline |

Applied **player-only**, in `ship.gd.apply_build` — AI never runs the override.

**Perk per level** (non-combat only): `PERK_PER_LEVEL = 0.005` → **+30% at 60**,
in exactly one dimension. Combat professions spend their tier on raw combat and
get no perk. One dial each, deliberately.

**The 7 skills** (`Skills.LIST`) — base cap **2** for everyone; a profession
raises caps on its favoured skills to 4–5. Points come from levels, caps come
from the commission; that mingling *is* the specialization gate.

**Cap shape (settled 2026-07-21):** every profession favours **three** skills.
Combat tier buys depth (Privateer 5/5/5, Guardian 5/5/4/4); the field and support
tiers run 5/4/4 or 5/5/4. Science and Trader each gained a third — a survival
skill, so a support hull that gets focused can answer for itself.

| Skill | Per rank | Effect |
|---|---|---|
| Gunnery | +8% | wider firing arcs, faster turret traverse |
| Piloting | +5% | sharper turn rate |
| Evasion | +5% | smaller hit **profile** (deterministic, capped 0.60 — not RNG dodge) |
| Hull Discipline | +8% | more cargo from the same hull |
| Shield Tuning | +10% | faster shield recharge |
| Prospecting | +10% | richer mining + survey-scan yield |
| Salvage | +8% | better wreck drops |

**Commission flow.** Standing accrues from the playstyle that *is* the
profession → at `Standing.INVITE_AT = 10` the leader offers → accept
(`Pilot.join_profession`) → their QUARTERMASTER stocks the signature module →
buy → fit in a **System slot** (`SystemDef.profession_lock` refuses otherwise,
visibly) → the ability BOOK knows it (module tag) → memorize onto one of the
**5 gem slots** → fire on [1]–[5]. Loadout changes are dock-only, or in flight
via **Going Dark** ([K]).

Standing thresholds: `INVITE_AT 10 · FRIENDLY_AT 100 · ALLIED_AT 500 ·
HOSTILE_AT -100 · KOS_AT -500`.

**Grade ladder (decided, no code needed).** A higher-grade module carries
MULTIPLE tags → grants several abilities from one slot. With ~20 abilities and 5
gem slots, module grade becomes the loadout tension.

**Parity rule.** Every profession module ships an AI-usable version where it
makes sense — telegraphed and counterable. Meeting an ability foreshadows a
commission you could take.

---

## Guardian

> Lawful muscle. The blue-and-white-stripe guard wing already flying the
> station's patrol band is the fiction; you join the people who hold the lane.

- **Leader / quartermaster:** Harbormaster **Ruel**
- **Roles:** Defense / Damage
- **Standing verb:** kills (+1, `_grant_kill_xp`) · bounty & recovery contracts (+2)
- **Combat tier:** 0.02 — **+120% hull/armor/shield/damage at 60**. No perk.
- **Skill caps:** Gunnery 5 · Piloting 5 · Shield Tuning 4 · Evasion 4
- **Signature (BUILT):** **Bulwark Projector** — Grade 3, mass 5, power 9.
  5s damage-reduction field on self + allies in a 420 radius, 18s cooldown.
  Blue field marks the zone and fades as it expires (that fade is the telegraph).
  Pure mitigation, zero offense — a boss-burst / coop cooldown.
- **Second signature (BUILT 2026-07-21) — the DAMAGE role:**
  **Hyper-Conductive Lance** — Grade 3, mass 6, power 11.
  A charged javelin of energy: **120 damage**, speed 1450, range 1500,
  **40°/s of bend** toward your selected mark, **6s cooldown**.
  It is *not* a seeker — the tracking only forgives a near miss, so a
  hard-jinking target still slips it and aiming stays flying. Built on the
  existing homing-projectile engine (a `WeaponDef` assembled from the module's
  `extra`), tag `lance`.
  - *Opposite shape to Bulwark:* Bulwark is a long-cooldown team commitment;
    the Lance is a short-cooldown personal punch. Soak vs strike.
  - **Energy seam:** `lance_energy = 8.0` is carried in the .tres but nothing
    consumes it — there is no energy/mana system yet. When one lands, the "minor
    energy cost" is already data.
- **Planned line:** Point-Defense · Taunt Beacon · Hyperslide+ (tighter drift) ·
  Escort ping
- **AI counterpart:** "anchor" brutes pop a bulwark
- **Spec-tree seam:** its two roles already split cleanly — a *protector* tree
  (mitigation, allies, taunt/peel) vs a *lawman* tree (gunnery, arcs, pursuit).
  Guardian is the only profession with 5-caps in both an offensive and a
  defensive skill, so both halves have real points to spend.

## Privateer

> The outlaw fork. Krayt dies at the system-1 finale and the commission passes to
> **Vyper**, who inherits the leaderless Rust Shoal crew — the player's on-ramp
> is grief and legacy, because you were on-comm when he was eaten.

- **Leader / quartermaster:** **Vyper** at the Speak's Easy (the *only* vendor
  that both sells AND installs — a KoS pilot locked out of station Engineering
  can still gear up)
- **Roles:** Control / DoT
- **Standing verb:** robbing neutral traders — **NOT BUILT**; the piracy loop is
  the next content feature. Recoveries / salvage / grey work in the meantime.
- **Combat tier:** 0.02 — **+120% at 60**. No perk.
- **Skill caps:** Gunnery 5 · Evasion 5 · Salvage 5 *(the only triple-5)*
- **Signature (BUILT 2026-07-22) — the DEFENSE role:**
  **JINX Evasion Protocol** — Grade 3, mass 5, power 9.
  Every ally within **420** flies a smaller profile for **6s**;
  22s cooldown. `scenes/flight/jinx_field.gd`, tag `jinx`.
  - *The outlaw counterpart to Bulwark:* Bulwark **soaks** the spike, JINX makes
    it **miss**. Same job, opposite method — which is why the game's two tanks
    don't feel the same.
  - **The buff is `max(base × 2, 0.30)`, capped 0.75 — not a plain doubling.**
    `evasion` is 0.0 on every AI ship (only the player's Evasion skill sets it),
    so doubling alone would be 2 × 0 = **nothing** for a wing — the exact case
    the ability exists to cover. The floor is what makes it work.
  - The field **owns the restore**: it captures each ship's true base on entry
    and puts it back on exit (including if freed early), refcounting through
    metadata so two Privateers in coop can't corrupt each other's baseline.
  - *Snapshot, not an aura* — it buffs who is in range at cast. Flying in late
    doesn't retroactively save you.
- *(Decoy Flare moved to Trader in the same swap.)*
- **Also built, gated to SYSTEM 2:** **Umbral Cloak Field** — Grade 3, mass 4,
  power 8. 6s untargetable, 14s cooldown. The framework is done and verified;
  it simply isn't system-1 content. Cloaked raiders are system-2 enemies.
- **Second signature (BUILT 2026-07-21) — the DoT role:**
  **Withering Timbers** — Grade 3, mass 4, power 7.
  A blight of a thousand nanobot privateers that takes a hull apart at the
  molecular level: **30 damage every 6s for 30s** (5 bites, 150 total),
  cast range 900, 20s cooldown. It CLINGS — nothing aboard can shoot it off,
  and it keeps working after you have broken away, which is exactly why it
  pairs with Decoy Flare (drop the lock, let the blight finish the job).
  Re-casting on an infected hull **refreshes** rather than stacks.
  `scenes/flight/blight.gd`, tag `blight`.
  - *Opposite shape to Decoy Flare:* Decoy is instant misdirection; the blight
    is patient and inevitable. Vanish vs commit.
  - *Deliberate mirror of the Trader's Tender Drone* — same 30-second window,
    opposite sign. The guild mends over time; the outlaw rots over time.
  - **Kill credit:** every bite passes the owner as damage source, so a ship
    that dies to the blight still counts as the player's kill (XP, loot,
    standing). If the owner is gone the damage lands anonymously rather than
    handing a freed object to a typed parameter.
  - **Energy seam:** `blight_energy = 6.0` carried in the .tres, unconsumed
    until an energy system exists.
- **Planned line:** Ambush Burst · Grapnel / Plunder · contraband & fencing
- **AI counterpart:** pirate ambushers decoy, then cloak-pounce
- **Spec-tree seam:** *raider* (ambush burst, cloak, alpha) vs *corsair*
  (plunder, salvage, evasion, escape). Triple 5-caps means Privateer can go
  deepest on skills — worth deciding whether the trees are meant to be as greedy.

## Miner

> Industry with teeth. Doug worked out the crystal lattice himself, which is why
> the Crystalline Array is his to sell and nobody else's.

- **Leader / quartermaster:** **Doug** (cast addition for the guild)
- **Roles:** Defense / DoT + Control
- **Standing verb:** sell ore at market (+1 per unit, `_on_sell_commodity` on `*_ore`)
- **Combat tier:** 0.015 — +90% at 60
- **Perk:** **mining yield**, +0.5%/level → **+30% at 60** (stacks with Prospecting)
- **Skill caps:** Prospecting 5 · Hull Discipline 5 · Salvage 4
- **Signature (BUILT):** **Tangle Projector** — Grade 3, mass 4, power 7.
  Clinging charge on your target: drag + thrust cut for 3.5s at up to 900 range,
  12s cooldown. A rock-cutter turned net. Peels, holds a target off allies,
  pulls aggro.
- **Planned line:** **Crystalline Defense Array** (mining laser refracted into a
  point-defense screen — destroys ALL incoming missiles/ordnance in range, can't
  harm a hull; *denies a damage type*, where Guardian soaks it) · Blast Mining ·
  corrosive DoT tool
- **AI counterpart:** a "driller" that lobs charges / nets
- **Spec-tree seam:** *prospector* (yield, hold, survey, endurance) vs
  *industrial defense* (the Array, denial, DoT). Note the Array is arguably the
  more distinctive signature and is still unbuilt — worth deciding whether it
  becomes a tree capstone rather than a Mk-I.

## Scout

> Reach and repositioning. Sella's cartography seeds this — she already buys
> Scan Data for credits and charts what you find.

- **Leader / quartermaster:** Cartographer **Sella**
- **Roles:** Control / Damage
- **Standing verb:** chart a SECRET POI in flight (+3 — the largest single grant)
- **Combat tier:** 0.015 — +90% at 60
- **Perk:** **scan value**, +0.5%/level → **+30% at 60**
- **Skill caps:** Piloting 5 · Evasion 5 · Prospecting 4
- **Signature (BUILT):** **Micro-Warp Drive** — Grade 3, mass 4, power 8.
  Short controlled blink toward your selected target, up to 900 units,
  10s cooldown (the shortest in the set).
- **Second signature (BUILT 2026-07-22) — the DAMAGE role:**
  **Killshot / "Longsight Coilgun"** — Grade 3, mass 7, power 12.
  **200 damage that CANNOT MISS**, but only inside a **30° forward cone**,
  between **700 and 2400** units, and **halved while the mark's shields are
  live**. 14s cooldown. `tag killshot`, `scenes/flight/killshot_beam.gd`.
  - *Reach turned into damage* — exactly the shape the role gap called for,
    and it can't be confused with a plain gun: it is the only ability in the
    game with a MINIMUM range.
  - *Opposite shape to Micro-Warp:* the blink closes distance, the coilgun
    demands it. The Scout's two modules pull against each other on purpose —
    you cannot blink in and snipe in the same breath.
  - **The module carries its own optics** (`sensor_range = 2600`), because
    targeting reach is `max(600, sensor_range)`: without a scope you could not
    hold a mark past 600 and the ability's 700 minimum would make it unusable.
    Fitting the gun grants the sight — no new machinery, `ship_stats` already
    maxes `sensor_range` across components.
  - **Shield rule as built:** *while any shield holds*, the shot does half.
    Simple and teachable ("strip it, then take the shot"). The precise
    alternative — shields absorbing at half efficiency with the remainder
    carrying through — needs an extra parameter on `take_damage`, which has
    **eight overrides**; not worth the churn unless the simple rule reads badly.
  - **Coop combo:** Science's planned **Overload Pulse** knocks shields
    OFFLINE, which sets up a full-damage Killshot. First real cross-profession
    combo in the game — worth protecting when those trees get designed.
- **Planned line:** **Disruptor Ping** (jam ONE target's weapons briefly —
  precise EW, distinct from Science's shield EMP) · Slipstream (sustained boost) ·
  Deep Sensor Sweep · passives: attack range, **group move-speed aura** (coop)
- **AI counterpart:** a scout jams your guns / lights you up for a pack
- **Spec-tree seam:** *pathfinder* (range, discovery, speed, the group aura — the
  coop-facing half) vs *interdictor* (EW, jamming, burst). Scout is the profession
  whose group aura most directly serves the 4-player north star.

## Trader

> The guild's own. Imari's haulers already fly the lanes as protected civilians —
> a commissioned Trader has allies on the road, and robbing them has a whole
> consequence web.

- **Leader / quartermaster:** Elder **Imari**
- **Roles:** Healing / Defense
- **Standing verb:** delivery / commodity runs (+2, `_on_turn_in` delivery)
- **Combat tier:** 0.01 — +60% at 60 (lowest, tied)
- **Perk:** **buy/sell discount**, +0.5%/level → **+30% at 60**. Seams already in
  code: `Pilot.trade_buy_mult()` / `trade_sell_mult()`, called by market prices.
- **Skill caps:** Hull Discipline 5 · Piloting 4 · Evasion 4
- **Signature (BUILT 2026-07-21):** **Tender Drone** — Grade 3, mass 4, power 6.
  Launches a miniature tender at your selected ALLY; it circles them and mends
  **14 hull+armor every 3s for 30s** (10 ticks, 140 total), cast range 900,
  36s cooldown. Fire-and-forget — it works while you fly. No ally selected
  patches *you*, so the key is never wasted.
  `scenes/flight/repair_drone.gd`, tag `repair_drone`.
  - *Contrast with Science's Repair Field:* that one is a big channelled burst
    (20/s for 4s) on everyone in a radius while you sit still. This is a small
    trickle that follows ONE ship anywhere. Same role, opposite shape.
- **Second signature — the CONTROL role: Decoy Flare** (moved from Privateer
  2026-07-22). Grade 3, mass 3, power 6. Breaks every hostile lock and ejects a
  decoy that eats fire for 4s, 16s cooldown. The convoy countermeasure, and the
  reason most haulers get home.
- **Blackout Transponder → TIER 3, under HEALING** (2026-07-21/22). Grade 3,
  mass 3, power 5; 3s untargetable, 16s cooldown. Not a Control tool and not the
  Mk-I: it is the healer's **aggro dump** — how a support pilot stays alive long
  enough to keep healing, earned once the heals themselves pull attention.
  Stays in `wares` until the trees exist to gate it; built content should never
  be unreachable.
- **Planned line:** a **second healing module** (T2, undesigned) · Bribe
  Jettison (dump cheap cargo to peel pursuers) · Emergency Thrust ·
  Convoy Beacon
- **AI counterpart:** escorts and haulers pop flares
- **Spec-tree seam:** *merchant* (economy, hold, routes, market depth) vs
  *convoy master* (the coop half — beacons, escort buffs, group defense).
  The healing tree now has its opener. Shape agreed 2026-07-21:
  **T1 Tender Drone → T2 second healing module → T3 Blackout**, so the survival
  tool arrives *after* the healing that makes you a target. Evasion (cap 4)
  is the passive half of the same idea.
  The dynamic-economy pass is explicitly scheduled to land *with* this profession.

## Science Officer

> Knowledge as a weapon. The lab already trades Insight for Scan Data; the
> commission turns that into field work.

- **Leader / quartermaster:** **Dex** (the Research Lab)
- **Roles:** Healing / Control
- **Standing verb:** turn in Scan Data to Dex (+n/2, `_on_trade_scan_data`)
- **Combat tier:** 0.01 — +60% at 60
- **Perk:** **Insight**, +0.5%/level → **+30% at 60** (feeds the tech trees)
- **Skill caps:** Prospecting 5 · Shield Tuning 4 · Piloting 4
- **Signature (BUILT):** **Repair Field** — Grade 3, mass 5, power 9.
  Channels 4s, mends hull + armor at 20/s on self and allies within 380,
  20s cooldown (the longest). **Healing belongs to Science** — Guardian only
  mitigates.
- **Second signature (BUILT 2026-07-22) — the CONTROL role:**
  **Overload Pulse** — Grade 3, mass 5, power 10.
  **Instant cast** (no channel), range 900, 18s cooldown: collapses the target's
  shields for **3s**, then they **blink back at exactly the strength they held**.
  `scenes/flight/shield_overload.gd`, tag `overload`.
  - **The restore is the design.** Damage dealt during the window does NOT eat
    into the returned shields — so the pulse can never be chained to grind a
    tank down. It buys a burst window and nothing else. *An opening, not damage.*
  - **Single-TARGET on purpose** — the only module in the game aimed at an
    enemy, which is what stops Science becoming a second team-aura profession.
  - *Opposite shape to Repair Field:* that one is a channelled team heal you
    stand still for; this is instant, offensive, and aimed at one hull.
  - **Suppression is active, not a one-off zeroing:** `_upkeep` regenerates
    shields every frame, so the node pins them at 0 and holds the regen delay
    down for the duration, then releases. Re-pulsing a suppressed hull is
    refused — a second seize would store a shield of 0 and *permanently delete*
    the victim's shields on release.
  - **Coop combo:** sets up a full-damage Scout **Killshot** (halved by live
    shields). The game's first real cross-profession combo.
- **Planned line:** Weak-Point Analyzer (scan → bonus damage vs that target) ·
  Stasis Tractor
- **AI counterpart:** a tech enemy EMPs your shields before a pounce
- **Spec-tree seam:** *medic* (healing, shields, sustain — the clearest coop
  support role in the game) vs *researcher* (EMP, analyzer, Insight, debuffs).
  Piloting (added 2026-07-21) is deliberate self-defense: when the enemy peels
  off the front line to crush the healer, Science can turn and keep distance
  rather than simply die.
  Also the natural home of the **"meditate"** skill that Going Dark's regen was
  designed to grow into, once an energy system exists.

---

## ROLE SWAP (2026-07-22, user): Privateer ⇄ Trader

Privateer traded **Control → DEFENSE**; Trader traded **Defense → CONTROL**.
Rationale: Privateer is the other 0.02-combat-tier profession, so it is the
natural **second tank** — the attribute growth already backs it.

Consequences, all built:
- **Decoy Flare moved to Trader** (`profession_lock` privateer → trader) as
  their Control module — reflavoured from "the Shoal's oldest trick" to a
  convoy countermeasure. Sold by Imari now, not Vyper.
- **JINX Evasion Protocol** is Privateer's new Defense module (below).
- **Blackout stays Trader, under HEALING, at T3** — it is not a Control tool.
  It is the healer's **aggro dump**: the way a support pilot survives long
  enough to keep healing. Not a main ability; a life-line.

## ROLE COVERAGE (2026-07-21/22, user)

Every profession has **two** role affinities, but most have a module for only
ONE of them. Each needs a signature for its second role too, or half its
identity is just a label. Status:

| Profession | Role A | covered by | Role B | covered by |
|---|---|---|---|---|
| Guardian | Defense | Bulwark Projector ✅ | Damage | Hyper-Conductive Lance ✅ |
| Privateer | **Defense** | JINX Evasion Protocol ✅ | DoT | Withering Timbers ✅ |
| Miner | DoT + Control | Tangle Projector ✅ | Defense | Crystalline Array ✅ |
| Scout | Control | Micro-Warp ✅ *(mobility)* | Damage | Killshot ✅ |
| Trader | Healing | Tender Drone ✅ *(+Blackout T3)* | **Control** | Decoy Flare ✅ |
| Science | Healing | Repair Field ✅ | Control | Overload Pulse ✅ |

**ALL SIX have a tier-1 module for BOTH roles, and ALL TWELVE ARE BUILT**
(2026-07-22) — a complete baseline, passing `test_abilities`, expected to be
adjusted in play.

The template each pair follows: two modules of genuinely different shape, tiered
so the second answers a problem the first creates.

- **Miner / Defense — Crystalline Defense Array (BUILT 2026-07-22).**
  Grade 3, mass 6, power 10. Mining laser refracted through a crystal lattice
  into a point-defense screen. `scenes/flight/crystal_screen.gd`, tag `crystal`.
  *Denies* a damage type where Guardian *soaks* one.
  - **DEPLOYED, NOT CENTRED ON YOU** (2026-07-22): it is **placed at the mouse
    cursor** on activation and STAYS there. This is the fix for tier-1
    homogenization — four professions already have a "bubble centred on me"
    aura, and this makes the Miner the only one who *puts an object in the
    world*. It also enables the play the ability wants: screening an **ally**,
    or covering a lane you are not standing in.
  - **Consistent with the aiming pillar, not a violation of it.** The mouse
    never aims weapons — but the documented "freed mouse" systems-engagement
    scheme explicitly reserves it for exactly this (its examples already include
    *warp-to-cursor*). The Array is the first ability to actually use that seam,
    so it sets the precedent: **cursor = where a SYSTEM goes, never where a gun
    points.**
  - **SETTLED 2026-07-22 (starting values, expect to tune):**
    placement range **1000** (cursor beyond that clamps to the limit — visibly,
    never a silent misfire); screen lasts **7s**; **re-placeable** whenever
    cooldown and energy allow, so an alert Miner can keep a lane covered at real
    cost rather than being locked to one deployment.
  - **Blocks EVERYTHING** in range, not just shots that would have connected —
    simpler, and far easier to read as a player.
  - **Screen radius 128 — i.e. 256 world units across** (2026-07-22). Sized off
    a **128px art canvas**, which is the natural size for the field sprite when
    it gets art. Scale reference: 1 art px = 2 world units
    (`HullDef.ART_SCALE`), so hull widths are light 32 / medium 64 / heavy 128 /
    super-heavy 256 world units — the screen spans a super-heavy hull.
  - Still much tighter than the other team abilities (Bulwark, JINX and Repair
    Field all use 380–420), so it stays a **precise screen, not a bubble** —
    about 1/3 the radius, 1/10 the area. But it now covers a ship *plus its
    manoeuvring room*, so an ally drifting a little isn't instantly uncovered.
    This is the value the drift analysis pointed at.
  - **ORDNANCE ONLY — gunfire passes through.** "Blocks everything" means every
    warhead in range regardless of where it was headed, NOT every projectile: a
    screen that ate bullets too would be a 7-second invulnerability bubble, and
    "denies a damage TYPE" is the whole identity. Implemented via a new
    `Projectile.ordnance` flag set from `def.magazine > 0` — the game's own
    definition of ordnance, so it tracks the ammo economy automatically.
  - Interception is by `target_group`, so a Miner's own rockets fly out through
    their own screen untouched; only fire aimed at your side is cut.
  - A cursor beyond 1000 **clamps and still deploys** ("ARRAY DEPLOYED — AT MAX
    RANGE") rather than refusing the press — every rejection stays visible, but
    a mis-aimed cursor shouldn't eat the cooldown for nothing.
  - Code note: vars are `_crystal_*`, never `_array_*` — `array_enabled` is the
    weapon-group toggle and the collision would be nasty.
Nothing is left undesigned. (Science's Overload Pulse — the other former gap —
was built 2026-07-22; see its entry above.)

DESIGN RULE emerging from the Trader pair: a profession's two modules should
have **opposite shapes** (burst vs trickle, soak vs deny, escape vs commit) —
not two flavours of the same verb.

SECOND RULE (2026-07-22, from reviewing the finished baseline): the *shapes*
should also differ **between** professions. At tier 1 four of six converged on
"radius aura centred on me, a few seconds, ~400 units" — mechanically distinct
(soak / miss / heal / deny) but identical to fly. Accepted as a baseline, since
roles need a floor before they can grow apart, with two corrections in flight:
- **Crystalline Array becomes cursor-DEPLOYED**, so Miner places objects in the
  world instead of wearing another bubble.
- **Overload Pulse stays single-TARGET**, keeping Science the one profession
  whose second module points at an enemy.
Scout (blink + snipe) and Trader (drone + decoy) already read differently. The
thing to watch as trees grow: not "does each profession have two roles", but
"does each profession *fly* differently".

## Cross-cutting notes for the tree design

- **Every profession now favours three skills** (Guardian four). No commission
  can absorb meaningfully fewer points than another — the earlier 2-vs-3
  asymmetry is closed.
- **Roles are already two per profession** (Defense / Damage / Control / DoT /
  Healing) and were chosen to give each one a flex identity plus a coop synergy.
  They are the most natural axis for the two trees — but nothing forces it.
- **Effective damage dealers:** Guardian + Scout (burst), Privateer + Miner (DoT).
  Healing is Science, then Trader. Guardian mitigates but never heals.
- **Every profession has exactly one built Mk-I signature**; everything in the
  "planned line" rows is unclaimed and could be tree content rather than
  quartermaster stock. Deciding that split is probably the first tree decision.
- **ENERGY is coming** (`docs/energy_system.md`, spec'd 2026-07-22, unbuilt).
  A mana pool: slow regen in flight, ×4 while Going Dark, full on docking.
  Capacity comes from the reactor; regen comes from your unused LOAD headroom.
  All eleven abilities are costed (Survey Scan is FREE); every one is
  individually sustainable, so energy gates using them *together*, not at all.
  **Science and Trader regen 1.35× / Miner and Scout 1.15× / combat 1.00×** —
  the support tier's compensation for weak hull growth, and a second dial for
  those two professions. Design trees assuming actives are metered.
- **Cost of a new ability is small:** one `.tres` + one `Abilities.LIST` entry +
  a dispatch arm in `ship._activate_gem()` + (where sensible) an AI trigger.
  Ability art is drop-in at `assets/icons/abilities/<id>.png` and falls back to
  text, so trees can be designed ahead of art.
- **Five gem slots, meant to grow.** If trees hand out actives freely, slot
  pressure is the balancing lever already in place (plus the grade ladder).
- **Open questions still unanswered** (from the long doc): respec policy
  (recommendation on record: cheap TRAIT respec at the trainer, skills
  permanent), whether death touches progression (recommendation: never), and
  profession-unique hulls vs livery variants.
- **Coop:** commission state is per-pilot; standing and market state need to be
  host-authoritative when netcode lands. Worth keeping in view while designing
  anything that grants world-affecting bonuses.

---

## Tree identity: the paladin / shadow-knight mirror (decided 2026-07-22)

Guardian and Privateer are the **same chassis with opposite economies**. Both are
frontline hybrids; one sustains by RESTORING, the other by TAKING. Keeping that
symmetry explicit is what stops the two combat professions from collapsing into
"the one with more hit points" and "the one with more damage".

### Guardian — paladin
Shield-focused, damage **reflection**, enemy weapon **disable**, and **self**-healing.

- **Self-heal is SELF-ONLY.** Non-negotiable. Guardian healing that reaches
  allies destroys the reason Science (Repair Field) and Trader (Tender Drone)
  exist. EQ drew the same line: the paladin keeps *itself* standing, the cleric
  keeps the *group* standing.
- **Reflection is cheap to build.** `BuildShip.take_damage(amount, source)`
  already carries the attacker and stores `_last_attacker` — reflect is a few
  lines at the existing damage seam, not a new system.
- **Weapon disable** is DEFENSIVE control (reduce incoming), which is what keeps
  it distinct from Science's Overload Pulse (drops shields, offensive) and the
  Miner's Tangle Shot (movement).
- Social mirror: a Guardian's presence **steadies allies** where the Privateer's
  breaks enemies.

### Privateer — shadow knight
Drone **pets**, energy and health **drains**, **terror**, slow unrelenting damage.

- **TERROR IS MUNDANE, NOT SUPERNATURAL** (user, 2026-07-22). Pirates stalk the
  lanes hunting traders; their reputation precedes them. Crews break because of
  WHO YOU ARE, not because of what you are made of. This matters beyond flavour:
  **Cinderweb keeps sole ownership of the supernatural dread**, and the beast
  stays singular. Deliver terror through COMMS — transponder squawk, surrender
  broadcast, the existing `static` Sfx — and keep violet smoke well away from it.
- **Fear should SCALE OFF PRIVATEER STANDING.** This is the hook nothing else
  uses: reputation stops being a one-time gate and becomes a stat you carry. The
  more of the lane you have taken, the harder crews break.
- **Fear reuses AI that already exists.** `AIShip` break-and-run (`_break_timer`)
  is the substrate — a frightened ship turns tail and weaves today. Terror drives
  that state rather than adding new behaviour. `TraderShip` already squawks
  ("Mayday! We're being ROBBED!") inside `SQUAWK_RANGE`: terror is the same crew,
  more frightened, sooner.
- **Susceptibility differs by target:** haulers break easily, Guardians are
  trained and mostly resist, **Cinderweb never breaks** — it fears nothing, which
  is the whole point of it.
- **DRAINS MUST STEAL, NOT DEPLETE.** AI ships do not spend energy (their
  abilities run off cooldowns), so "drain their energy" would do nothing to an
  enemy. Convert instead: their hull into your hull, their energy into yours.
  Works regardless of the target's economy, and it is the more SK reading anyway.
- **Pets are the one EXPENSIVE item** in either kit — persistent allied AI needs
  positioning, targeting, retargeting, death, and host-authoritative sync when
  coop lands. Everything else here is an effect on a seam that already exists.
  Sequence pets LAST, or scope v1 to a timed drone (like Tender Drone) rather
  than a true persistent pet.
