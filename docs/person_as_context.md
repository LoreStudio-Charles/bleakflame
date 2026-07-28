# Person as context

**Decided with user 2026-07-27. NOT BUILT — this is the design of record.**
Supersedes the two-column quarter in `docs/venue_layout.md` (which is built, and stays
the *host*; this changes what goes inside it).

## What was discovered

Epharon's walkable town produced something the tabbed dock never did — user:

> "The nice thing that fell out of planets as walkable regions is context became
> conversations instead of locations. Instead of tabs, I spoke with Imari and a dialog
> opened. I spoke with Bram and his shop opened. Not a clustered tab with a room full of
> information. A single context, not a full room of visual clutter."

So the principle is **ONE CONTEXT AT A TIME**, and it is not the same question as
walkable-vs-tabbed. A tab fails because it tries to be a whole room at once.

**The venue quarter as first built violates this.** Desk + board + meter + shelf + door in
two columns is better organised than the scatter it replaced and still a room full of
information. It fixed the scatter and kept the clutter.

## The two objects

**ADDRESSEE** — someone (or something) you speak to. A hub. Shows identity, your
relationship, and a ranked list of what they will do with you.

**CONTEXT** — one single-purpose screen opened from an addressee. Always the same shape:
*a list, a detail, an action.* Returns to the addressee, not to the venue.

Every service in the game is a context; every venue is a set of addressees.

### The addressee IS a DialoguePanel

```
[portrait]  VYPER
            Rust Shoal, Krayt's successor
            The Rust Shoal · TRUSTED · 140

  "You again. What."

  ▸ About the Meridian.          ← gold: quest business, always first
  ▸ Anything on the board?       → CONTRACTS
  ▸ I need gear.                 → SHELF
  ▸ About the commission.        → BACK ROOM (GuildOffice)
  ▸ Nothing.
```

This is `scenes/ui/dialogue_panel.gd`, already built: portrait, name/role, text, and
choices that fire an `action` and return a reply line. Person-as-context is mostly
*routing services through the thing already used for conversations*.

**It kills a whole bug class.** A pending quest talk stops being a pip competing with a
button — it is the top line, in gold. The Odessa failure (a bespoke "Talk to X" button
that ignored a queued campaign talk, so the beat froze for ~46 game-days) becomes
structurally impossible: there is only one list, and quest business sorts to the top of it.

### The context

```
VYPER'S WORK              credits 230c   hold 0/44      ← header = YOU
──────────────────────────┬─────────────────────────────
 Stolen goods run    260c │ Bring back 3 crates of
 Thin the competition     │ Stolen Goods — off a wreck,
 Circuits, no manifest    │ off a hold, not our business.
                          │
 ← SHORT TITLES           │ Progress  3/3
                          │ Reward    260c
                          │
                          │   [ Turn in — 260c ]        ← action ON the thing
──────────────────────────┴─────────────────────────────
                                       [ Back to Vyper ]
```

One component covers contracts, the quartermaster's shelf, the market and the hangar —
they differ only in content.

## The rules

1. **One context at a time.** Never two lists on screen.
2. **Three zones, two columns.** Header = *you*; left = what's here; right = what's
   selected. Everything that wants a third column is one of those three in disguise.
3. **The action lives in the detail panel**, on the thing it acts on. Nothing floats.
4. **Short titles left, full text right.** Fixes truncation without shrinking the font.
5. **Locked offers are absent, not greyed** (the trust rule, `docs/venue_layout.md`).
6. **Contexts return to the addressee**, so a visit chains: check the board, buy a chip,
   leave — without re-navigating.
7. **A terminal is an addressee too.** The Mission Computer is literally a computer; it
   has identity and an offer list like anyone else. That is how services with no NPC fit
   without inventing staff.

## THE BUG THAT PROVES RULE 2

Playtest, 2026-07-27 — user relaying the tester: **"Where do I turn this in?"**

The Mission Computer has three columns: *contracts on offer* | *contracts in hand* |
*quest log*. `Turn in (150c)` floats in the middle one, detached from the row it acts on,
in a column that is otherwise 90% empty.

And the middle column is **redundant**: "Suppression contract: destroy 3 pirates —
Harbormaster Ruel" appears in it *and* in the Quest Log beside it. The third column exists
because it duplicates the second. That is why the action got buried — it was attached to
the redundant copy.

The Quest Log needs no column here at all: it is already the tracker, on `[L]` and its own
tab (`MissionTracker`, `QuestLogView`).

## Decisions taken (do not re-litigate)

- **Quarters are TABS at multi-faction venues**, and **zero new tabs are needed** —
  every tab-bound leader already has a home tab holding their desk.
- **The Guardians get their own tab.** The Landing Bay stays a neutral venue overview
  (repairs, hold, stash, launch) rather than doubling as one faction's room. Station goes
  9 → 10; the same argument takes the colony 6 → 7 for Imari.
- **Engineering stays a room** (OPEN, but the lean is strong). It is the one genuinely
  spatial screen — paperdoll, cargo, stash and fabricator in view at once — and forcing
  it into list/detail would make refitting worse. Exempt it out loud rather than let it
  quietly break the rule.

## What decides walk vs. tab, later

The number of quarters a venue has:

- **1 quarter** → the venue *is* the room, no navigation (Shoal, Verge — already true).
- **2–3** → a hub with doors.
- **4+** → a town you walk.

So the UI gets more spatial as places get more important, which is a progression the
player feels rather than an inconsistency they notice. It also says exactly when a venue
has earned walking.

**The concourse** is the cheap middle step: one hand-drawn station interior with clickable
doors. No navmesh, no character controller — a point-and-click hub. Reads as a *place* for
one piece of art, and the doors stay put if walking is added later.

**Why a tab is not a place** (the narrative argument, user): *"there's no way to make a
hasty escape off a tab under blaster fire while being chased by assassins."* A tab is
**outside time** — nothing can happen while you are in one, which is why docking currently
reads as pausing the game. A place is in time: being followed, being recognised, someone
waiting at your berth. The Ghosts are already hired contractors in canon.

**This decision does not need making now.** If the addressee is the unit, the host is only
a way to reach a person — tab strip, door, or walking up to them — and the contexts behind
them are identical either way. Adopting person-as-context IS the migration, done
incrementally while tabs still work.

## Order of work

1. **The Mission Computer**, alone. It has the reported bug, it is one function
   (`_build_missions_tab`), and it demonstrates every rule.
2. Extract the context component (list / detail / action) from it.
3. Move the four tab-bound leaders onto addressees: Ruel, Dex, Imari, Sella.
4. `SpeakEasy` / `ProspectDeck` swap their `VenueLayout` columns for an addressee. The
   shell keeps the header, the venue's own trade (`venue_box`) and the launch line.

## Also recorded

- **Contract duplicates are a CONTENT gap, not a bug** (user). The pool is small and
  regenerates in order, so drawing one leaves duplicates behind. Small fix: bigger pool +
  shuffle. Real fix, much later: generate contracts from WORLD STATE — the lane's actual
  pirate population, a colony genuinely short of circuits, a wreck that genuinely exists —
  at which point duplicates are impossible by construction and the board reports the world
  instead of decorating it. That is the "living world, not gauntlet" pillar applied to the
  one system that never got it.
- **Turn-in discoverability is not only layout.** `_has_turn_in_here()` already exists; the
  flight dock prompt could read *"CINDER REACH STATION — 2 jobs to close"* before the
  player has even landed.
