# NPC homes, tab pips, and going to find people

Designed with user 2026-07-22. **Not built** — parked while playtesting.

## The change

Today a quest briefing AMBUSHES you: dock, and a modal opens whether or not you
were thinking about that person. Odessa is the exception — she lives on Ember
Row and you choose to ask her for the word, which is the interaction everyone
prefers.

So: **every NPC gets a HOME**, and talks wait there.

1. An NPC with something to say puts a **bold pulsing pip** on the top-right
   corner of their home tab.
2. You go to that tab and find a **"Talk to <name>"** button.
3. It opens the same `DialoguePanel` that used to ambush you.

Same content, but you walked to it. Docking becomes noticing rather than being
shown, and every venue gets a reason to be visited.

A tab can host several people — one pip, buttons stacked.

## Homes

| NPC | Home | Notes |
|---|---|---|
| Odessa | Ember Row | already works this way; the model for all of it |
| Dex | Research Lab | already has a tab |
| Ruel | Landing Bay | his desk and ledger — and the screen you always arrive on, so the campaign's main giver has the most visible pip |
| Voss | Mission Computer | claims and contracts are literally her job |
| Imari | Landing Pad | she meets you at the ramp |
| The Counter | **Cave** (new planet tab) | a recluse with his own room. Visiting him becomes an act, not a menu stop |
| Sella | **Explorer's Union** (new planet tab) | |
| Krayt / Vyper | Speak's Easy | already a land-and-talk beat |
| Doug Diggs | **his own freighter at the Verge** | homeless until it exists — no tab, no pip |

NOTE: placement follows FICTION, not avoidance. The old worry — "don't put them
where I land or I'll be hit up on arrival" — is dissolved by the pip: nobody
speaks until you choose to talk.

## Sella's scan contracts

She offers scan work that COMPETES with the lab: the same Scan Data is credits
from Sella or Insight from Dex, and now contracts too — a real standing fork
between Scout and Science Officer.

**Turn in at EITHER venue.** `MissionLog` templates already carry `turn_in`;
it just needs to accept `"either"`, with `venue_ok()` true at both. One word,
and scan contracts become the first work a pilot can close wherever they are —
exactly right for a Scout who is, by definition, somewhere else.

## Doug Diggs' freighter (the Verge)

An old clunker the size of a small station, dockable, parked in the Verge.
Worth building because **the Verge currently has no reason to exist** — nothing
out there rewards the trip but rocks. The freighter gives:

- a destination that teaches mining,
- the Miner commission a home,
- an ore buyer who pays better than the station *because you hauled it to him*,
- and a third dockable silhouette in a game that has two. Variety of PLACE is
  what makes a system feel inhabited.

Needs: new art, a services screen, a POI, and a fourth `venue` value.

"Doug Diggs" (renamed 2026-07-22) — makes the Dig Dug pun findable.

## Risk

A player who ignores pips stalls their campaign, where today a briefing is
impossible to miss. Mitigations: the quest log already lists the step, and the
amber notice line on arrival should say "Ruel wants a word." — which makes the
pip a convenience rather than a single point of failure.

## Introductions — nobody should stay a stranger

The campaign personally introduces Ruel, Voss, Dex, Imari, the Counter and
Krayt. It never introduces **Sella** or **Doug Diggs** at all — a player can
finish the whole starter arc without learning that the Explorer's Union or the
Prospector Guild have faces, which quietly hides two professions. (Vyper is
introduced by the finale, so she is fine.)

Once homes and pips exist this is nearly free: an INTRODUCTION is just another
reason for a pip. A once-ever tutor lesson can pip an unmet NPC's home the first
time the player docks at that venue —

> "You haven't met the colony's cartographer. Explorer's Union."

— using the same dot, the same button, the same conversation. No new mechanism,
and it uses the venue the player is already standing in rather than sending
them somewhere.

Worth distinguishing the two pip meanings visually (someone WANTS you vs someone
you have NOT MET), or the player learns to read a pip as "story here" and is
puzzled when it is only a handshake.

## Order

1. Homes, pips, talk buttons (uses existing tabs).
2. Cave + Explorer's Union tabs.
3. Scan contracts with `turn_in: "either"`.
4. Doug's freighter — its own project, with art.
5. INTRODUCTION pips for anyone the campaign never presents (Sella, Doug).
