# The standard venue layout

**Decided with user 2026-07-27. BUILT the same day** — `scenes/ui/venue_layout.gd`,
with the Speak's Easy moved onto it (commit `5ad5754`). This stays the design of
record; the notes below are what shipped and what is still owed.

## Status

- **The shell exists.** `VenueLayout` owns the header, the `NpcDesk`, the contract
  board + take + hand-ins, the standing meter, the trust-gated quartermaster and the
  office door. A host supplies `body` (its flavour) and `venue_box` (its own trade),
  and connects five signals. Config is a Dictionary: `venue`, `board`, `npc`,
  `faction`, `rungs`, plus overridable `trust` / `board_open` / `price_of`.
- **The Speak's Easy is on it.** Everything duplicated between it and the Verge deck
  was deleted rather than copied.
- **Still owed:** Doug's deck, Sella's desk. The station DockScreen last / never.

Two things learned in the build, worth keeping:

- **The shell owns the SHAPE, the venue owns the WORDS.** The first pass flattened
  "VYPER'S WORK" into a generic "CONTRACTS" heading and the venues lost their voice —
  a test caught it. Headings, refusals and rung labels are all venue-authored
  (`board_title`, `board_shut_text`, `rungs`).
- **A meter must measure the climb the player is actually on.** Scaled to
  `Standing.MAX` the bar did not visibly move anywhere on the Shoal's ladder, whose
  every rung sits between -100 and 100. `climb_to_next()` measures from the rung you
  passed to the one ahead, and the meter names what that next rung opens.

Every place you can dock has been built separately, and they are the same screen four
times over. This is the shape they should share.

## Why

The Speak's Easy, the Verge deck (Doug), the Explorer's Union (Sella) and the station's
Landing Bay each assemble some subset of the same five things — *talk, contracts,
standing, vendor, office door* — and each assembled it by hand. That is why adding
Vyper's board needed new code at all: Doug's deck had already solved it, in a form
nothing else could reach.

`NpcDesk` (2026-07-23) was the first rung of this ladder, for exactly this reason —
user: *"a single NPC tab object that controls the layout — every tab was almost
identical."* This is the next rung: not just the person, the whole venue.

The immediate trigger was a screenshot. The Speak's Easy had its content crammed into
the top third with two thirds of a 1080-tall panel empty, and the fix is structural
rather than cosmetic — two columns consume the width, and the meter and the vendor give
the lower half a job. Padding one screen with decoration would not have transferred.

## The shape

Two columns under the venue header and the NPC desk:

```
  <venue header>                                    [E] launch
  <NpcDesk — portrait, name/role, "Talk to X", news dot>

  CONTRACTS                      |   QUARTERMASTER
    posted here, turned in here  |     stocked gear
    ...                          |     ...
                                 |
  ────────────────────────────   |
  FACTION METER                  |   <office door>
    standing, band, next rung    |
```

**Contracts sit directly above the meter they move.** Standing currently lives on the
Pilot tab, a screen away from the board that changes it, so a player cannot see the work
and its consequence at once. Adjacency is the whole point — it matters most at the Rust
Shoal, where standing *is* the gate to the commission.

## THE TRUST RULE (user, 2026-07-27)

> "I think we should hide the entire tab to someone the quartermaster doesn't trust
> enough to see the shop. Once you can enter the faction area show the panel."

**Hide the WHOLE TAB, not the column.** The first proposal was to collapse an empty
vendor column; the user's rule is stronger and more consistent with what the project
already does. `Professions.office_open` is *no invitation, no door* — a leader with
nothing for you is a person at a counter, not a locked room you can see. Generalised one
level up that is **no trust, no tab**.

Anything else shows a player a shop they cannot use, which is the DEMO POLISH RULE
inverted — *"polish things we plan to show rather than demo things that add questions"* —
and, worse, advertises a faction's inventory as a reward before they have any reason to
want it.

- The gate is **can you enter the faction's area at all**, which each venue already
  answers: `Standing.shoal_open()` / `shoal_trusted()`, `Professions.office_open()`.
- **Once inside, the panel shows.** Visible-but-empty is fine here; hidden-until-earned
  is what the tab does.
- At bespoke screens with no tab bar (the Speak's Easy, the Verge deck) "hide the tab"
  means hide the SECTION — same rule, different container. Do not add a tab bar to a
  one-screen venue just to have something to hide.

## What a stocked row must say

> "show the faction required to purchase the item and the currency required if it uses a
> faction earned currency."

Every row states its own price of entry, so nothing is a silent refusal:

1. **The standing required**, named in bands rather than numbers where a band exists
   (*Friendly*, *Allied*) — the fence already does this correctly: *"the fence opens at
   Privateer — Friendly"*.
2. **The currency**, when it is not credits.

**FACTION-EARNED CURRENCIES DO NOT EXIST YET.** Today there are credits (`Wallet`) and
Insight (`Research`). The user's phrasing anticipates per-faction scrip, and the row
should be built to name whatever currency an item costs rather than assuming credits —
but the currency itself is a separate design decision and must not be invented as a side
effect of a layout pass. Until it exists, every row says credits.

## Order of work

1. Extract the venue shell (header + desk + the two columns) with the trust gate on the
   vendor side. One host, many venues — the `InventoryGrid` pattern.
2. Move the Speak's Easy onto it. It is the newest and least entangled, and it is the
   screen whose emptiness prompted this.
3. Then Doug's deck and Sella's desk.
4. The station DockScreen LAST, and possibly never: its `is_station` flag is woven
   through construction and every refresh, and it is the one venue whose nine tabs are
   genuinely different from each other.

**Do not extract against one implementation.** The Epharon interiors were deliberately
left alone for this reason (see `docs/handoff_2026_07_27_pm.md`) — abstracting from a
single caller bakes its accidents in as rules. There are three real venues to generalise
from here, which is enough; there was only ever one interior.
