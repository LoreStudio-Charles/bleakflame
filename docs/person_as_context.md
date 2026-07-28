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

## A context has TWO presentations (user, 2026-07-27)

> "I think the Shipyard should take the shape of the Armory. It's a shop, and I think all
> shops should take the grid of icons with tooltips shape. Market should behave like the
> Armory as well."

So the left-hand zone comes in two forms, chosen by what the items ARE:

- **LIST** — for things that are *sentences*: contracts, campaign beats, expedition
  leads, research projects, log entries. You read them. `ContextScreen`.
- **GRID** — for things that are *objects*: equipment, hulls, commodities. You look at
  them, compare them at a glance, and buy them. The **Armory already is this** —
  icon + grade border + mark pips + price badge, right-click to buy, details panel on
  the right. It arrived at the shape before the shape had a name.

Both are the same context: header = you, left = what's here, right = what's selected
with its action on it. Only the presentation of "what's here" differs. **Every shop is
a grid.** Anything you read is a list.

That means the Armory does not get converted — it gets *joined*, and what the two share
(header, detail panel, selection, the `action(text, blocked, on_press)` rule) is what a
future `ContextGrid` lifts out of `ContextScreen`.

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
   **BUILT 2026-07-28** — `scenes/ui/addressee.gd`. Pressing any NPC desk opens that
   person's ranked offer list instead of branching by hand between "held talks",
   "a bare idle line" and "the office door standing off to one side".
4. `SpeakEasy` / `ProspectDeck` swap their `VenueLayout` columns for an addressee. The
   shell keeps the header, the venue's own trade (`venue_box`) and the launch line.

### What step 3 actually settled

- **Rank is a property of the list, not a habit.** `Addressee.ranked()` buckets by
  `Kind` (QUEST / SERVICE / DOOR), so quest business is first *by construction*.
  `DockScreen._addressee_offers` deliberately lists the durable stuff FIRST and today's
  campaign talk LAST — the opposite of how it presents — so that "the campaign comes
  first" can never quietly become true because of where a line sits in the host.
- **The commission door moved inside**, from a button under the portrait to a line the
  person says. It is gold only when an invitation is earned and unanswered — a decision
  waiting, which is what gold means everywhere else. The `office_door` tutor anchor now
  points at the PERSON, which is what the lesson was asking for anyway.
- **`DialoguePanel` gained two things**: a `subtitle` (where you stand with whoever they
  speak for) and `"close": true` on a choice, so an offer can HAND OFF to the screen it
  opens instead of parking the conversation underneath it.
- **A screen must not contradict itself.** The desk outside and the greeting inside are
  now one `_has_news()`. They were written separately and immediately disagreed — the
  desk lit for a waiting invitation, the greeting said "board's quiet". Both halves were
  individually correct, which is exactly why no assertion caught it; a screenshot did.
- **ODESSA IS STILL BESPOKE, on purpose.** She is the only face with an authored
  dialogue tree, and she is already quest-first — she is not the bug, she is the merge
  that has to be done properly: folding `Dialogues.ODESSA_BAR`'s own choices into the
  offer list rather than hanging the whole tree behind one more click.
- **The walkable town is the next venue, not a parallel.** `epharon_town.gd` still
  splits quest talks from idle ones by hand — the exact shape the addressee replaced.

## The shops (user, 2026-07-27) — and one collision to resolve first

**Shipyard → grid.** Needs `assets/icons/hulls/<hull>.png` and a hull tooltip; the
tooltip already exists (`DockScreen.hull_tooltip` — quality, level, trait, pools, the
slot set by type and best mark). Structure can land before any art does: components
already fall back to a slot+mark label when an icon is missing, and hulls can do the
same, so the screen is right on the day the art arrives.

**The user's art idea:** *"now that we have tintable art we could make unique designs
per level and grant different classes and qualities of the same hull at different
levels. The tint can say something about quality. Cooler tint jobs apply to better
hulls."* Unique art per level is straightforwardly good — it makes a level band
something you SEE.

**Resolved 2026-07-27 (user).** I flagged a collision with *"HULL COLOUR MEANS FACTION,
EXCLUSIVELY"* — the user scoped it instead:

> "This is a rule for NPC ships where players need to identify who they are shooting.
> Player ships should bear markings of pride and not be like wearing a uniform. […]
> Hue can vary for players though, because players need to look special. They are the
> heroes."

So the faction rule is a TARGET-READ rule: it binds the ships you are reading, not the
one you are flying. And what makes player paint safe is the same 2026-07-25 decision
that raised the flag — once role moved off paint onto a sensor read, colour stopped
being load-bearing for identification at all, so it is free to carry pride. Identity
comes from `Ship.classify`, the target bracket and the friendlies roster; never pixels.

**The ladder:** fidelity rises by **GRADE primarily, LEVEL secondarily** — more
elaborate, more obviously expensive art. "Cooler" is a fidelity axis, not a hue code,
so the Grade palette (grey / white / green / blue / purple / gold / red + pips, always
paired for colourblind safety) keeps carrying quality on every tile in every shop, and
the shipyard grid teaches the same vocabulary as the Armory beside it. **Player hue is
free on top of that** — the grade border says what it is worth, the paint says whose
it is.

**Market → grid, plus a real economy question. DEFERRED 2026-07-27 (user): "agreed
on the market. another place we just haven't had time to create the feature."** Scarcity vs abundance ("is the player
pushing their luck trading here") is NOT a UI feature: today's green/red only compares a
good against a venue's fixed import/export list, so the fifth identical run pays exactly
what the first did. Showing saturation means TradeGoods gains LOCAL STOCK that a sale
depletes and time replenishes — at which point the tile can show a depth bar and the
price can decay per unit, and hauling becomes a decision instead of a lookup table.
That is the same "living world, not gauntlet" pillar as generating contracts from world
state (below), and the two share a source of truth. Worth doing; worth designing first.

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
