# Multiplayer readiness — de-static-ing player state

**Started 2026-07-27.** The user's brief: *"Let's get it coop friendly now. That
would remove subtle bugs, make forward progress easier and more reliable, and pave
the way for any form of multiplayer."*

> **THE ROAD ITSELF IS NOT CHOSEN YET.** The user owns a working Elixir/OTP MMORPG
> server framework, proven against UE 5.7, so "multiplayer" may mean an MMO rather
> than 1–4 coop. **That discussion happens before any netcode** — they deferred it
> explicitly. Everything in this document is the part both roads need.

---

## WOULD THE SERVER HAVE FIXED THE 2026-07-28 FRAME BOG? (mostly yes)

The first concrete data point in the coop-vs-MMO fork, and worth recording because I
got the general claim wrong first.

**What happened.** The game bogged with four or five pirates on screen. Measurement
(`tools/bench_avoidance.gd`) found it was not ship count at all: every projectile
re-ran `engageable()` — a two-group scan with two container allocations — **every
physics frame**, twice for a blast weapon. Eighty bolts cost 22.8% of a 60fps frame
before anything was drawn. Fixed client-side by caching one scan per shooter per frame
(`af395e3`).

**I said a server could not have helped, "because a server can't fix a client that's
slow before it draws." That was wrong** — it conflated rendering cost with simulation
cost, and what I had just measured was simulation. The user's correction stands: *"If
those checks are moved to the server and the client only handles moving the objects,
collecting input, and showing the explosions, we wouldn't be doing all those hit scans
on the client, correct?"* Correct.

**And the split is unusually favourable here**, which is the part worth keeping:

- **Moves cleanly to the server** — hit resolution, AI prey selection, faction
  arbitration, damage application, standing. All authoritative, none of it needs to be
  local, and *all* of it is the O(bolts × targets) work. That is the expensive half.
- **Cannot move** — your own hull's motion under your own input. Waiting on a round
  trip to learn where your nose is pointing is unplayable in a twitch game, so
  client-side prediction stays whatever the topology. But that is **O(1): one ship**.

So the costly part is exactly the part that leaves, and the part that must stay is
cheap. That is a genuine argument for the MMO road, not merely a neutral one.

**The caveat to test rather than assume.** The proven figure is 1200 players and 8000
NPC entities at a 100 ms refresh — that is *entity state*, a different workload from
projectile hit resolution. A 900 u/s bolt covers 90 units per 100 ms tick, which is
coarse against small fast hulls. Landing this needs one of: a higher combat tick, server
-side path sweeping (rewind/lag compensation), or client-reported hits the server
validates. The user anticipated this — *"could probably do well even if we bumped up the
response rates"* — and it should be measured against **bolts**, not against the
entity-count benchmark.

**What none of this changes.** The fix was ~15 lines and an afternoon, and it makes
single-player and coop good *today*, on the road we are actually on. If the MMO lands,
that code moves or dies at no loss. The measurement harness is the durable part: it is
what you would want in hand to check whether the server actually helps, rather than
assuming it does.

---

## The mechanism

`PlayerState` (RefCounted) holds one pilot's data. `PlayerState.local` is *me*.
The existing modules keep their exact public API and become **forwarding facades**:

```gdscript
static var credits: int:
	get:
		return PlayerState.local.credits
	set(value):
		PlayerState.local.credits = value
```

GDScript 4.7 supports custom `get`/`set` on `static var`, and reassigning `local`
changes what every existing reader sees. **Verified in an isolated project before
committing to the approach** — the whole strategy collapses without it, and the
fallback (rewriting every call site per module) is a far worse plan.

**So the rule is: move the DATA, leave the NAME alone.** `Wallet.credits += 100`
still compiles and still works. A call site only needs touching when it must name
*which* pilot — which is exactly the set of places multiplayer has to visit anyway.

Getters hand back collections **by reference**, because every existing site mutates
in place (`.append`, `.assign`, `.clear`). A copying getter would swallow all of it
silently; `test_player_state` asserts against that specifically.

---

## The sorting rule

**If two pilots in one session could legitimately disagree about a field's value,
it is player state.**

| | |
|---|---|
| **Player** | Wallet, Stash, Pilot, SampleBuilds ownership, Standing, Research, Quests, `MissionLog.active`, Comms, Tutor's `seen`/`step`/`_progress`/`_did` |
| **World** | `PoiMap.pois`, `Research.day` (the calendar), `MissionLog.offers` (the board's postings) |
| **Engine/config** | Tutor's `_anchors`/`_arm_pred`/`_done_pred`, `MissionLog._templates`, `Professions.dev_unlock_offices` |

`PoiMap` splits across the line: `pois` is world, but `_discovered` (fog of
discovery) is personal — you have not found the Rust Shoal yet, your friend has.

---

## CAMPAIGN FLAGS: PRESENCE, THEN ORDER

**User's rule, 2026-07-27** — and it **supersedes** the "Toggle Progress Updates"
idea from 2026-07-20, which needed a setting and left the semantics ambiguous:

> *"The guiding factor for flags should be presence. Was I there for this? If I am
> present the flag is set. Otherwise it isn't. Maybe we still allow participation
> with friends, but ordered sequences will remain locked and flags must be set in
> order so you'll have to do something again if YOUR prerequisites are not met when
> you help a friend."*

Two conditions, both required, to set a campaign flag for a pilot:

1. **Presence** — that pilot was actually there. No credit for being docked
   elsewhere while a friend flies the beat.
2. **Order** — that pilot's own `requires` chain is already satisfied. Helping a
   friend with a later beat does **not** grant it out of sequence; you will do it
   again when your own prerequisites are met.

Why this is better than a toggle: it needs no UI, it cannot be set wrong, and it
makes helping a friend always *safe* — you can never skip your own story by being
generous with someone else's. It also preserves every authored beat's meaning for
each pilot individually, which matters enormously for the Saga's late reveal.

**Not built yet** — the *logic* needs a notion of who is present, which arrives
with the net layer. The *data* migration LANDED 2026-07-27: `Quests` and `Research`
are per-pilot, so the rule now has somewhere to live. `test_player_state` asserts
two pilots run their own campaign and keep their own catalogue — the comparison
"is MY chain satisfied" is expressible for the first time.

---

## Progress

| module | fields | status |
|---|---|---|
| `Wallet` | credits, xp | **done** (`8d599e1`) |
| `Stash` | items, commodities | **done** (`8d599e1`) |
| `Pilot` | 16 — identity, commission, skills, gems, ground kit | **done** |
| `SampleBuilds` | current, owned, cached builds | **done** |
| `Standing` | points, peace, mend_day, _seeded | **done** |
| `Comms` | messages | **done** |
| `MissionLog` | active, total_kills, next_uid | **done** (`offers` stays world) |
| `Research` | 10 — insight, catalogued, journal, chains, rumour state | **done** (`day` stays world) |
| `Quests` | 5 — active, completed, completed_day, pending notes + talks | **done** |
| `Tutor` | 12 — seen, active, step, pending, progress, did, ctx, safe, context, venue, watchdog | **done** (engine tables + the stall log stay shared) |
| `PoiMap` | 3 — `_discovered`, `waypoint_id`, `waypoint_manual` (`pois` stays world) | **done** |

`PlayerState.wipe()` resets **from a fresh instance**, not from a hand-written
field list, so adding a field cannot leave a stale value alive across New Game —
the exact shape of the Nemesis-grudge and `Pilot.met` leaks fixed on 2026-07-26.
`test_player_state` asserts that property over every declared field.

---

## THE MIGRATION IS COMPLETE (2026-07-27)

All ten modules. **61 fields** in `PlayerState`, and not one of the ~137 original call
sites had to change — the modules kept their public API and became forwarding facades,
which is the whole reason this was affordable in a day.

**What deliberately did NOT move**, because over-migrating is its own bug:

| stays shared | why |
|---|---|
| `PoiMap.pois` | the Rust Shoal is where it is for everyone |
| `GameClock` | two pilots cannot disagree about the date — and it is now its own component |
| `MissionLog.offers` | the board's postings are the board's |
| `Tutor._anchors` | a property of the SCREEN that is built, not of who looks at it |
| `Tutor._arm_pred` / `_done_pred` | authored engine tables, identical for everyone |
| `Tutor.stalls` | the game's own bug list across every playtester; scoping it per-pilot would throw it away on New Game |
| `Professions.dev_unlock_offices` | config |

`test_player_state` asserts the split in **both** directions — that two pilots hold
separate wallets, stashes, identities, ships, standing, contracts, campaigns,
catalogues, onboarding and fog; **and** that the predicate registry and the stall log
are still shared. A test that only checked the first direction would pass just as well
on a codebase that had wrongly copied the engine tables per pilot.

**Next, when the net layer lands:** `PlayerState.local` stays "me"; coop adds a lookup
by peer id alongside it. The flag rule (presence + order) now has per-pilot campaign
state to be written against — see the section above.
