# Armor as Mitigation — and the weapons that answer it

**Designed with the user 2026-07-26. SPEC COMPLETE; NOT BUILT.**

**Revised 2026-07-26 (second pass): ARMOR IS DR ONLY.** It is no longer a hit-point pool
that also mitigates. The ablative feel returns as an armor *type* you can choose, not as
the default behaviour of all plate.

---

## The problem it solves

Today **armor is only extra HP**. `BuildShip.take_damage` is a flat cascade — shields
absorb, then armor, then hull — so a point of armor and a point of hull are worth exactly
the same, and "armored" is just "bigger". Nothing about a weapon cares what layer it is
chewing through, so there is no such thing as a good anti-armor gun.

---

## 1. The model

**Armor has no pool. Armor is a percentage.**

```
1.  shields absorb first, UNREDUCED — they are energy, plating does not help them
2.  whatever passes the shields is reduced by ARMOR DR
3.  the remainder hits the HULL
```

So armor **protects the hull** and never touches shields. Two pools (shield, hull) and one
modifier (armor), instead of three pools pretending to be different from each other.

**Why DR-only rather than pool-and-DR:** a pool that also mitigates is two systems doing
one job, and it makes armor scale on two axes at once while everything else scales on one
(see `combat_space.md` §9.9 — armor would quietly become the only layer worth fitting).
DR-only is simpler, and it makes armor *reliable*: it is still working in minute three.

### The DR curve

Both level and grade feed one rating, which flattens toward a hard cap so armor can never
run away:

```
rating = level + grade_tier × 10 + mark × 5
dr     = DR_CAP × rating / (rating + K)          DR_CAP 0.40,  K 40
```

≈5% at level 1 in Flotsam, ≈31% at level 60 in Exotic Mk V, hard-capped at 40%. Numbers
and the full table in `docs/progression_table.md`.

---

## 2. ABLATIVE PLATE — the type that trades permanence for strength

**+10% DR fresh, sliding to −5% spent** (user, 2026-07-26). It starts stronger than
standard plate and fails as it protects.

```
ABLATIVE_FRESH = +0.10
ABLATIVE_SPENT = -0.05

effective_dr = base_dr + lerp(ABLATIVE_SPENT, ABLATIVE_FRESH, integrity)
```

Spent plate is **slightly worse than bare standard plate** — a spent shell still hanging on
the hull, adding nothing and costing a little. Not a catastrophe: since base DR runs
~5%–31%, a spent plate almost never goes net negative (only the absolute floor, L1 Flotsam
Mk1 at 5.2% base, lands near zero), and a maxed suit barely notices (L60 Exotic Mk5:
31.4% → **26.4%**).

> **THE CROSSOVER IS AT 33% INTEGRITY.** Ablative beats standard plate while
> `lerp(−0.05, +0.10, t) > 0`, i.e. `t > 0.05/0.15` = **0.333** — so it is the better plate
> for the **first two thirds of its capacity** and only falls behind in the last third.
>
> That is the number to judge it by in playtest, and it is a genuinely favourable trade:
> you get the +10% for most of a fight and pay for it at the repair counter rather than in
> the fight itself. **The repair bill is therefore doing most of the balancing work here** —
> if ablative feels strictly better than standard plate, raise the integrity price before
> touching these two constants.
>
> An earlier draft used −25%, which put the crossover at 71% and made ablative worse for
> most of its life — a trap rather than a trade. Rejected for that reason. Note the knobs
> are non-obvious: changing `ablative_capacity` moves how long the window lasts in *seconds*
> and never moves the crossover.

### It wears out BECAUSE it worked

**Integrity depletes in proportion to the damage it PREVENTED**, not the damage you took.
A plate that saved you 400 damage has spent 400 of its capacity; a plate that was never
shot at is untouched.

That is causally satisfying in a way a generic durability counter is not — the plate is
literally ablating away in proportion to how much it did for you. It also means the
degradation curve needs no special shaping: heavy fights eat it fast, light ones barely
mark it.

`ablative_capacity` (how much *prevented* damage it holds) scales on both axes like any
pool — see `progression_table.md`.

### Who wants it

This is the counterpart to the **mitigation affinities** in `combat_space.md` §9.9:

| | wants | because |
|---|---|---|
| **Marine** (stacking DR) | **standard plate** | permanence — still there in minute three, which is the whole identity |
| **A strike pilot** | **ablative** | alpha protection for a short decisive fight |

Same slot, two philosophies, and the choice reads off the pilot rather than off a
spreadsheet.

### It costs more to repair — deliberately

**Ablative plate is a RUNNING COST.** Restoring integrity is dearer than any other repair
in the game, priced per point of integrity restored and scaled by the plate's grade and
mark.

That gives the economy something it currently lacks: **a defensive consumable.** Ordnance
is the only sink today — guns cost nothing to run and defence costs nothing at all. This
makes protection something you pay for every time it saves you, and it gives docking a job
beyond being a save point (repair bills at 1c/pt hull and 0.5c/pt armor are currently
background noise nobody notices).

It also characterises the fitting economically: **ablative suits a pilot who wins fast, or
one who is rich.** Grind out a long fight in it and you feel it at the counter.

> **KEEP THE EXISTING GUARD.** `CLAUDE.md`: *"partial repairs if broke — never refused."*
> That matters more here than anywhere else. Without it a broke pilot with spent plate
> flies worse, takes more damage and earns less — and with DR-only armor a spent plate
> means the mitigation is **gone**, not merely thinner.

---

## 3. The weapons that answer armor

Three answers, and under the new model they divide cleanly into **two general and one
specialist**.

### Heat (`#`) — the sustained-fire answer

Weapons with Heat apply **stacks** on hit; each strips **10% of armor DR**, capped at
**80%** reduction. Armor sheds one point of Heat every `heat_dissipation` seconds — so
**lower is better armor**, and the usual 3 means a point every three seconds.

It is a **ramp, not a cliff**: break off and the wall cools gradually, so the pressure is
to stay on target. Stacks cap at **8**, and the per-stack magnitude is a *weapon* stat — a
weak emitter tops out far short of the ceiling and simply cannot strip good plate.

**Works against both armor types.** Heat is the answer to *mitigation itself*.

### Penetration (`#`) — the flat answer

**The first `#` damage ignores DR entirely and lands on the hull.** The remainder is
reduced normally.

Strongest against *heavily-mitigating* armor and unmoved by how good the plate is, which
makes it the answer to armor you cannot out-damage. It scales badly against big hull pools,
which stops it being universally correct.

**Works against both armor types.**

### HESH (`##%`) — the anti-ABLATIVE specialist

**HESH strips INTEGRITY**, at `##%` (usually 30%) above the rate ordinary damage would.

Against **ablative plate** it is devastating: it collapses the thing that plate depends on,
and a HESH loadout can strip a fresh ablative fit in a fraction of the fight it should have
survived. Against **standard DR-only plate** it does nothing special — there is no
integrity to attack.

**That is deliberate.** HESH is a *counter-pick*, not a general upgrade: it beats a
specific choice, and it is dead weight against the other. In a game where loadouts are
visible, having a weapon that punishes a known fitting is better design than a third
generic damage bonus — and it means ablative plate carries a real, learnable weakness
rather than being strictly-better-when-fresh.

---

## 4. Reporting integrity is a GEAR TIER

Whether you can *see* your remaining integrity depends on the armor:

| armor | what it tells you |
|---|---|
| crappy | **nothing.** It does not report. |
| good | feeds your computer a readout |
| great | adds a **hazard flash** and an **audible ping** as it nears failure |

And the **computer may limit what any module can surface at all** — a great suit on a cheap
computer still cannot tell you much.

**This is where that tier stops being a nice-to-have.** Not knowing how much ablative plate
you have left is genuine tension: cheap plate leaves you guessing whether you can take one
more pass, and finding out costs you the pass. Good plate turns that into information you
bought.

Same principle as sensor-gated role identification — information is a capability, not a
free HUD element — and it generalises past armor to every module that produces data.

---

## 5. Where it attaches

- **`BuildShip.take_damage`** — the cascade. Shields absorb unreduced; the remainder is
  scaled by armor DR; the rest hits hull. `armor` as a pool goes away.
- **`DefenseDef`** — gains `damage_reduction`, `heat_dissipation` (seconds per point, lower
  is better), `ablative` (bool), `ablative_capacity`, and a `reporting` tier. `Kind.ARMOR`
  and `Kind.COMPOSITE` use them — **which finally makes `DefenseDef.kind` a live stat**;
  it is read by nothing today.
- **`ShipStats`** — must keep armor as a *rating and a type*, not a summed pool.
- **`WeaponDef`** — gains `heat`, `heat_per_stack`, `penetration`, `hesh_bonus`, all
  defaulting to 0 so every existing weapon is unchanged and the system is opt-in per gun.
- **Integrity** is per-ship state that decays only on use — no tick needed, unlike Heat.
- **Dock repair** — a new, dearer line item for integrity.

---

## 6. Consequences elsewhere

**The ship/ground contrast inverts.** Both combat docs currently headline *"ship armor
ABLATES, character armor MITIGATES."* Under this model **both mitigate**, and the honest
framing becomes: *everything mitigates; ships can opt into ablative plate that trades
permanence for strength.* The ground's **barrier** remains the pure ablating pool on that
side.

**`ShipStats` armor aggregation changes shape** — the per-plate rule (*you get the LOWEST
DR of all fitted plates, because Murphy's Law says that is where the shot lands*) still
holds, and still needs per-plate data rather than one summed number.

---

## 7. Open

1. ~~Does spent ablative fall to zero DR, or to some floor?~~ **ANSWERED 2026-07-26: to
   −5%** — a spent shell is slightly worse than bare plate, not a liability. Crossover at
   33% integrity, so it is the better plate for two thirds of its life. See §2.
2. **Repair pricing.** Dearer than everything else, scaled by grade and mark — the actual
   numbers want setting alongside the rest of the economy.
3. **Does anything restore integrity in the field?** A Science or Trader ability is the
   obvious candidate, and it would give the support commissions a defensive job.
4. **Heat vs ablative** — Heat strips DR, and ablative DR is already scaled by integrity.
   The two multiply, so a hot *and* spent plate is worth almost nothing. That is probably
   correct, but it is the harshest interaction in the system and wants watching.
