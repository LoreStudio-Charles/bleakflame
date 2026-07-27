# Multiplayer readiness — de-static-ing player state

**Started 2026-07-27.** The user's brief: *"Let's get it coop friendly now. That
would remove subtle bugs, make forward progress easier and more reliable, and pave
the way for any form of multiplayer."*

> **THE ROAD ITSELF IS NOT CHOSEN YET.** The user owns a working Elixir/OTP MMORPG
> server framework, proven against UE 5.7, so "multiplayer" may mean an MMO rather
> than 1–4 coop. **That discussion happens before any netcode** — they deferred it
> explicitly. Everything in this document is the part both roads need.

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
| `Tutor` | seen/step/_progress/_did | last — needs splitting from the engine tables |
| `PoiMap` | `_discovered` only | last — the module straddles player/world |

`PlayerState.wipe()` resets **from a fresh instance**, not from a hand-written
field list, so adding a field cannot leave a stale value alive across New Game —
the exact shape of the Nemesis-grudge and `Pilot.met` leaks fixed on 2026-07-26.
`test_player_state` asserts that property over every declared field.
