# The Long Lane — Orivel ↔ the Rim

**Designed with the user 2026-07-25. SHIPS BUILT 2026-07-25; the lane itself is next.**

Today the Reach has one trade lane and one hauler class (the Mule). Orivel is ~100k out,
so the capital run is a different kind of voyage from the station↔colony hop, and it
should look and feel like one.

---

## The geography — a legible danger gradient

    RIM (station / Epharon)                                    ORIVEL (capital)
    |----------------|----------------------------|----------------|
      GUARDIAN patrol        THE GAP — pirates          NAVY patrol
      (~first quarter)      (the middle half)          (~last quarter)

- **Guardians** patrol out from the rim to roughly **a quarter** of the distance. Their
  leash already exists (`GuardianShip` lane patrols); this is the same behaviour on a
  much longer route.
- **The Navy** patrols outward from Orivel by roughly the same margin — the fleet built
  2026-07-25 is the seed of this.
- **THE GAP IS THE POINT.** Neither authority reaches the middle half, so cargo crossing
  it is genuinely on its own. That is *why* convoys hire escorts, and it makes escort
  work a real profession rather than flavour: the danger is a PLACE on the map, and the
  player can see where it starts.

This also gives the map three legible bands without a single UI element — you learn the
lane by flying it, the way you learn the Reach's belts.

## The ships

**Mules stay short-haul.** Planet ↔ outpost is a Mule's job. The capital run is heavier
cargo and worth escorting, so nobody sends a Mule down it.

| Class | Role | Notes |
|---|---|---|
| **Medium freighter** | the workhorse of the lane | TURRETED weapons — a hauler that can answer, not a target. Turrets matter: it must defend while holding course, which is exactly what a fixed-arc gun cannot do. |
| **Heavy freighter** | the convoy's reason to exist | Slow, valuable, badly wants an escort. The ship a player will one day fly, and the ship pirates dream about. |
| **Light fighter** (new) | escort + pirate | Fast, cheap, seen in numbers. |
| **Medium fighter** (new) | escort + pirate | The real escort; the dangerous pirate. |

Fighters serve BOTH sides — the same hull flies as a hired escort and as a raider, which
is both cheap to build and true to the setting: out here the difference between an escort
and a pirate is who is paying.

### The hulls as built

| Hull | Band | Level | Role |
|---|---|---|---|
| **Harrier** | LIGHT | 6 | light escort / pirate — cheap, plentiful, two fixed guns |
| **Goshawk** | MEDIUM | 12 | the real escort / the dangerous pirate — twin lances + a PD turret |
| **Dray** | MEDIUM | 8 | the lane workhorse — two turret rings, deep hold |
| **Bellwether** | HEAVY | 15 | the convoy's heart — three turrets and still not enough |

All four are **STANDARD grade** (green), a visible tier above the rim's grey/white salvage:
these are factory hulls owned by capital freight companies and escort outfits, not scrap
the fringe flies out of habit. Killing one in the Gap is how a rim pilot first sees clean
gear, since loot is the victim's actual build. None are for sale yet (`price 0`) — the
Reach station caps berths at MEDIUM and a STANDARD medium would walk straight past the
Dowager, which is deliberately the local ceiling.

`Goshawk` is named for the sparrowhawk's larger cousin on purpose — the ladder is legible
from the name alone. Freight goes **Mule → Dray → Bellwether**.

Note the Bellwether is HEAVY, so the MEDIUM-capped Reach station can never berth her. She
runs Orivel's landing bays and Epharon's surface, which is exactly why the little station
still only ever sees Mules.

### Turret note — CORRECTED 2026-07-25

The first draft of this doc had the rationale backwards. `traverse_speed()` is `360/mark`,
so a **low** mark slews *fast* (Mk1 = 360°/s) and a capital Mk4 crawls at 90°/s.

That derivation is now gone: **traverse is an authored per-weapon stat** (`WeaponDef.traverse`,
0 = fall back to `360/mark`). `mark` says how BIG a gun is; it no longer silently decides
what that gun can hit. The old rule made "big" and "slow" the same word, which forbade the
most obvious weapon in the genre — a large mount built to shred small fast things.

Two weapons came out of that change:

- **Palisade Flak Battery** (Mk4, Advanced) — 420°/s and 340 range, against the Aegis
  Lance's 90°/s and 1000. Proximity-fuzed, low per-shot damage. A fighter inside the wall
  dies; a cruiser outside it is untouched, because the flak simply cannot reach.
- **Drover Defense Turret** (Mk2, Standard) — the civilian freight mount. 240°/s and 7
  damage: it *can* follow a jinking fighter and it *can't* make one leave. This is what
  keeps an armed hauler annoying rather than safe, and it is the balance lever — refit the
  same ring with something meaner and the convoy stops needing an escort.

The pillar the old rule protected is still load-bearing and still true of **artillery**:
long reach and heavy per-shot damage belong on slow mounts, so escorts and point-defense
have a reason to exist. Anything that tracks well gives up range, damage, or both.

### Level bands (user, 2026-07-25)

Ships are meant to be levelled by region, not all sitting at 1:

- **Starting area (the Reach rim): 1–5.** Rooster/Wasp 1, Mule/Kestrel 2,
  Sparrowhawk/Cutlass 3, Dowager 4, Vulture 5 (the rim's mini-boss ceiling).
- **The Long Lane: 6–15.** Harrier 6, Dray 8, Goshawk 12, Bellwether 15.
- **The Navy: 35–40.** Supercruiser 35.

**The DATA is set; the CURVE is not.** `HullDef.level` is still a display seam — nothing
scales off it yet, which is why every ship currently fights as though it were level 1.
Deciding what a level is *worth* (hull/damage per level, and whether components carry
levels too) is the open balance decision. See "power levels" in the next-steps list.

## The V-SHRIKE — new canon (user, 2026-07-25)

The Gap's owners, and a deliberate contrast with everything the Reach has met so far.

> **They do not raise comms. They hit, take, and destroy. No prisoners. No survivors.
> Only ash.**

- **Bloodthirsty. Heartless killers.** Not privateers with a code, not Krayt's Shoal, not
  Vyper's banner-of-truce pragmatists. There is nothing to negotiate with.
- **THE SILENCE IS THE HORROR.** Every other faction in the game talks — Krayt jokes,
  Vyper grieves, traders squawk distress, even ordinary pirates hail. The V-Shrike simply
  arrive. The game already has the vocabulary to make that land: comms exist, hails
  exist, and their absence will be *noticed* precisely because everything else speaks.
- **They finish what they start.** They kill the ship AND the crew AND leave the wreck —
  which distinguishes them from Cinderweb, whose horror is that it leaves NOTHING. Ash
  versus absence. Both are terrifying; they are not the same terror, and the campaign
  already taught the player to read debris as evidence.
- **Vyper's pirates share the Gap** and are the counterweight: they hail, they take
  cargo, they can be bought or truced. A player learns the difference by who answers the
  comm — and learns to dread the ones who don't.

## Build order

1. ~~**Hulls first**~~ — DONE. Four `HullDef` .tres via `tools/generate_sample_data.gd`
   (the seed generator; hand edits get overwritten, so they went THERE). Silhouettes
   render until art lands, as the Dowager already does.
2. ~~**Turret fit** on the freighters~~ — DONE, via authored traverse rather than low
   marks. `SampleBuilds.lane_builds()` holds all six NPC fits.
3. **The lane** — waypoint route between the rim and Orivel, haulers running it.
4. **The three bands** — Guardian leash from the rim, Navy leash from Orivel, and
   nothing in the middle.
5. **The V-Shrike** as an AI variant that never hails, over the existing pirate
   behaviours. The FITS already say it — see below.

### The widow livery (user, 2026-07-25)

The V-Shrike are **black widow spiders**: hulls are near-**black** carrying a **single
point of red** — the widow's hourglass, set aft on the deck where the abdomen would be.
One mark, nothing else. No chevron, no stripes, no random skin.

It reads because everything else in this sky is coloured — the Reach's rusty oranges,
Guardian blue, Galean ivory, the Shoal's scavenged mismatch. A black hull is a *hole* in
that, and the red is the only thing you get to recognise before it fires. Same job the
silence does on the comm channel: everyone else announces themselves.

`scenes/flight/vshrike_ship.gd` (`VShrikeShip extends AIShip`). Dev-summon a pair with
**`/vshrike`**. Test: `tools/test_vshrike.tscn`.

Two things that had to be got right, both sabotage-verified:

- **The mark works on an ART-LESS hull.** Every other livery in the codebase gives up
  when there is no sprite (`BuildShip.apply_livery` returns early on a null texture) —
  and none of the four Long Lane hulls have art yet. So the mark scales off the sprite
  when there is one and off the authored **silhouette** when there isn't. Written to the
  usual pattern it would have been correct, committed, and invisible on exactly the ships
  it was drawn for.
- **A rare AI SPECIALIST is still black.** `AIShip._roll_specialty` used to repaint the
  hull (mender green / warden blue / binder amber), and it ran *after* setup applied the
  faction tint — roughly one V-Shrike in eight spawned out of its own livery. **That was
  fixed at the root** rather than papered over here: role is sensor data now, so nothing
  repaints a hull to announce a role and hull colour means faction, exclusively. See
  below.

### Role is sensor data, not paint (user, 2026-07-25)

Advertising a specialist by hull colour was wrong twice: it collided with faction
livery over the same channel, and it handed the read out for free.

A contact's ROLE is now read by the **targeting computer** — `TARGET: Goshawk [MENDER]`,
plus a classification ring inside the target bracket in the role's colour (the exact
shades the hull used to wear: same information, new channel).

It is a **capability you buy**: a suite that publishes `SystemDef.role_id_range`, which
arrives at **ADVANCED (blue) grade, level 10+** — today the **Augur Sensor Array**. It
*sees* 2400 and *understands* 1800, because detecting a ship and knowing what it does are
different jobs; a contact at the rim of sensors stays an unknown quantity until you close
on it. When it can't tell, the HUD says nothing — an unclassified contact must never read
as a confirmed ordinary one.

This also gave `ComponentDef` a **`level`** field (all items should carry one and
eventually scale like hulls; the field is real where a capability gates on it, the stat
scaling is not applied yet).

### The V-Shrike fits say it before any dialogue does

`vshrike_harrier` and `vshrike_goshawk` carry **no shields and no sensors**. Every slot
that could have gone to surviving a fight or seeing one coming went to guns instead. They
do not plan to be shot at, because they do not plan to leave anyone able to shoot. The
escort versions of the same two hulls carry both — flown by people who intend to go home.

That contrast is the whole faction, expressed in data, before a line of writing exists.

Escort CONTRACTS (fly cover for a convoy across the Gap) fall out of this almost free
once the lane exists, and are the obvious first use of it.
