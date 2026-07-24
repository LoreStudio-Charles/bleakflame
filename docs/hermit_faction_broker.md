# The Hermit as Faction Broker — decline the truce, prove yourself instead

**Status: DESIGNED, DEFERRED (2026-07-23, user).** The `-100` truce-break
penalty ships now (committed). The decline option + the hermit-broker questline
below are a *coupled* feature — decline dead-ends Shoal/Privateer content unless
the hermit recovery exists — so they are built together, as their own focused
pass, never half-shipped into the demo.

## The shape

Two roads to the Rust Shoal's good graces, and a way back from either faction:

1. **Accept Vyper's banner** (the current path). After Krayt dies, Vyper offers
   the truce, *warns of her fury if it's broken*, and — on accept — the Shoal is
   permanently OFF LIMITS (`Pilot.shoal_invited = true`, `+20` privateer). This
   is the "heal on the ending."
2. **Decline it** ("Keep your banner. I walk my own road."). You refuse the
   gift and earn your place instead — or don't. A prouder, harder path.

The **hermit is the broker for road 2**: an old war hero (the Counter) with
*sway over BOTH sides* — the Shoal/Privateer underworld AND the Guardians. He
offers quests that grant real standing with EITHER faction, so a player can:
- prove themselves to the Shoal without Vyper's charity (reach privateer
  standing and the door opens on merit), and/or
- cross the OTHER way — a pirate-leaning pilot earning Guardian trust, or vice
  versa. Faction mobility, brokered by the one man both sides still respect.

## Mechanics (what to wire)

- **Decline branch in `VYPER_TRUCE`** (flight_test.gd): add a second choice at
  the `truce` node. On decline, in a new apply-path:
  - `Pilot.shoal_invited = false` — **the invitation LAPSES** (user's call,
    2026-07-23). Krayt is dead and you refused Vyper, so the campaign's
    `grants_shoal` invitation (from `rust_shoal`) dies with him. The Shoal goes
    NEUTRAL, *not* hostile (privateer standing untouched, ~0) — they just don't
    vouch for you any more. `shoal_open()` becomes false.
  - `Pilot.shoal_declined = true` — a new persisted flag (mirror `shoal_invited`
    in pilot.gd to_dict/from_dict/reset). The hermit reads it to open his path.
  - Vyper gives a cool-but-respectful sign-off (points you at the old man on the
    rock — "or don't; your funeral"). No `+20`. Beat still completes
    (`_fall_done`).
- **The existing two-tier `shoal_open()` already supports the earned road**:
  `Pilot.shoal_invited or get_points("privateer") >= FRIENDLY_AT (100)`. So the
  broker quests just need to grant POSITIVE privateer standing (the redemption
  `mend` system only lifts *burned* standing toward 0 — the broker gives real
  favour beyond that cap).
- **The broker questline** (quests.gd, `giver: "hermit"`): several quests that
  pay faction standing (privateer and/or guardian) via the existing
  `Standing.add` reward path. Enough privateer-side work → `privateer >= 100` →
  `shoal_open()` true on merit → the Speak's Easy and the (secret) Privateer
  commission unlock the earned way. The Privateer profession is `hidden` and
  revealed by the Shoal's story; the broker path is a second reveal trigger
  (alongside Vyper's banner).
- **Guardian cross-over**: the mirror — the hermit can also lift a pirate-tainted
  pilot toward Guardian standing, or a Guardian toward the Shoal. He is the hinge
  between the two fronts.

## Hazard to remember

Do NOT ship the decline choice without the broker recovery. A decliner with no
hermit path loses Shoal/Privateer access permanently — a soft dead-end. The two
land together.

## Ties

- The Counter / war-hero framing is Conall "Starfall" Phelan's territory on the
  `the-legend` branch (docs/cinder_reach_campaign.md). On `main` the hermit is
  the campaign's planet-talk NPC; this broker role is the seam where the two
  eventually meet. Keep it compatible.
- Standing map: contract turn-ins credit the giver's guild
  (`MissionLog.faction_for` / `Professions.led_by`), so hermit quests crediting
  privateer/guardian slot straight into the existing plumbing.
