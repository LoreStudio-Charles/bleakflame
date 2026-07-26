# The Long Lane — Orivel ↔ the Rim

**Designed with the user 2026-07-25. Spec complete; NOT built.**

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

Turret note: `WeaponMount` traverse is 360/mark deg/s, so a freighter's turret should be
LOW mark — it swats a fighter that sits still, not one that jinks. That is the balance
lever if armed haulers turn out to be too safe.

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

## Build order (when it resumes)

1. **Hulls first** — 4 `HullDef` .tres via `tools/generate_sample_data.gd` (it is the
   seed generator; hand edits get overwritten, so add them THERE), plus `SampleBuilds`
   entries. Silhouettes render until art lands, as the Dowager already does.
2. **Turret fit** on the freighters — wide-arc mounts, low mark.
3. **The lane** — waypoint route between the rim and Orivel, haulers running it.
4. **The three bands** — Guardian leash from the rim, Navy leash from Orivel, and
   nothing in the middle.
5. **The V-Shrike** as an AI variant that never hails, over the existing pirate
   behaviours.

Escort CONTRACTS (fly cover for a convoy across the Gap) fall out of this almost free
once the lane exists, and are the obvious first use of it.
