# The Cinder Reach Campaign — "The Legend"

**Working title.** This is the **Campaign** for the Cinder Reach system — its own
self-contained story — *not* the Saga. (Vocabulary is canon: the **Saga** is the
whole cross-system story told in **Movements**; a **Campaign** is one system's
local story. See CLAUDE.md → NARRATIVE VOCABULARY.) What ships today as "Nothing
Left Behind" — the beast, the traceless dead, opening the gate — is the **Saga's
Movement I: The Gate**, and lives in `docs/campaign_starter_system.md`. This is the
*other* thread running through the same system and the same cast: a **film noir**
about a hunted legend hiding in a cave on the colony's edge.

Designed with the user 2026-07-24. Source of truth for the Campaign — read before
authoring any Campaign beat.

---

## Logline

Odessa asks you to check in on an old friend — a strange recluse who counts the
dark from a cave. He turns out to be **Conall "Starfall" Phelan**, a war-legend
the whole Reach forgot, hiding because *being found restarts a war*. When you can't
keep him hidden, he stops being a crazy old man and becomes the legend again — one
last time, to lead the enemy away and save the Reach with it.

The Campaign never touches the Convergence. It's about **who Conall is, why he
hides, and what it costs when hiding stops working.**

---

## The world it needs

### Cinder Reach is the capital system (user, 2026-07-23)
Cinder Reach is not a lonely outpost — it is the **Galean capital system**. The
player has been living on its **fringe** (the station + the colony). The layout,
one axis, station at zero:

```
Quarn territory ── Percival ── ORIVEL ─────(~100k)───── STATION ── Epharon ── the gate out
   (enemy)        (spacer      (the Galean            (you, the fringe)  (colony)
                   colony)      capital, the heart)
```

- **Epharon** — the colony planet (Conall's cave). ~10k out (the planet we've
  always had).
- **Orivel — the Capital** — the heart of the Reach, ~10× the fringe distance out
  (`(-84000, -52000)`, a clean −10× the planet), ~3× Epharon's size. **Placed as a
  landmark** (Sprite only, no services yet) and registered SECRET, so it charts
  only if a pilot makes the mad all-legs haul out to it — never a default waypoint.
- **Percival** — a small spacer colony beyond Orivel. Conall's people. *Odessa's*
  people. (Lore for now — a chart marker/POI, not built.)
- **Quarn territory** — the enemy frontier, beyond Percival. (Lore for now.)

### Traversal (user)
Right now it's **all legs** — Orivel is a genuine haul nobody's expected to make.
Tech makes it faster later, maybe a **warp**. (Ties to the planned warp-to-cursor
system.) So Orivel is a *destination in waiting*, not a routine trip.

---

## The factions & names (canon)

- **Galeans** — our civilization. Human by blood, but the word "human" **never**
  appears player-facing; it is always *Galean*. (Internal docs/comments may use
  "human" as plain shorthand — the player never sees it. The player-facing string
  sweep is a branch task.)
- **The Quarn** — the enemy: an alien power the Galeans fought to a brittle
  ceasefire. This is the **geopolitical-war tier** of alien — a mundane military
  enemy, **NOT** the cosmic tier. Only **mildly braided** with the Wardens at
  most, **never connected** (keep them clearly their own thing so the Campaign and
  the Saga don't blur).

---

## The cast

### Conall "Starfall" Phelan — "The Counter"
A legend: tactically brilliant, fast, deadly with a gun and keen on a stick. He
**splashed a Quarn fast-attack cruiser** bound to wipe out **Percival**, buying the
Guardians time to set their fleet. A hero — and, for it, a **hunted man**.

He is *far more powerful than anyone will admit — especially himself.* The engine
of the character is that last part: **he isn't hiding from his power; he's hiding
from being the man who had it.** And the reason he MUST stay buried is the killer
twist — **his continued existence is a casus belli.** Finding him = war. He's a
loaded gun that has to pretend it's rusted shut. The cruellest knot: the one thing
that could save the day (the legend, back in a cockpit) is the exact thing he can't
do without lighting the fuse.

> His **Saga role** (Movement I) — counting Cinderweb's breathing — stays the
> Saga's business. His **Campaign** is *why he fled to the cave in the first place*.
> Same man, two threads; they do not touch until the very end (see The Braid).

### Odessa — the client
From **Percival.** She **sheltered Conall** when he first made it out to the Reach —
he saved her people, and he saved *her home*. She is the one soul who knew him
*before*. She's the noir client: not a dame with a case, an old friend with a fear —
*"He hasn't come down in a month. Go up there. Tell me he's still him."* And in
noir the client always holds the back half of the truth: hers is the debt.

**Odessa stays.** Her place is Ember Row, no matter how much she loves him. That
ache — she does not follow him into the gate — is the emotional key of the ending.

### The bounty hunters — the antagonist force
On the prowl, and they've picked up a trail. The wrong questions are being asked in
**Ember Row**, and Odessa overheard. (A named, memorable lead hunter is TODO.)

---

## Structure

The Campaign is **independent of the Saga for its whole length** — the noir, the
hiding, the hunt are pure Cinder Reach — and **braids into the Saga only at the
climax** (see The Braid).

1. **The check-in.** Odessa sends you to look in on her old friend. You meet a
   strange recluse who is plainly *more* than he seems.
2. **The thread — THE EMPTY CAVE (user, 2026-07-25).** You come back and he is
   **gone**, and the place has been **turned over**.

   The horror is in what it *isn't*:
   - **The hunters do not know it is him.** They know something is off about a man
     hiding out here, and for the Ooshu that is enough to warrant a search. They are
     not closing on a target; they are *eliminating a discrepancy*. That is worse.
   - **Nothing is taken.** It is obviously searched and obviously not robbed. No
     words, no threat left behind — the wreck IS the message, and it is addressed to
     nobody in particular.
   - **He knew they were coming.** He is brilliant and permanently alert; a landing is
     all the warning he needs, and he was gone before they were down. THE TALLY WALL
     PAYS THIS OFF: the short marks by the door — "ships that come in slow and don't
     land" — were never eccentricity. They were an early-warning system, and beat 1
     let the player read it without understanding it.
   - **THE CLUE IS AN ABSENCE.** The furniture is wrecked at random; the WALL is wiped
     *clean* — thirty years of counting scoured off deliberately, edge to edge. The
     hunters had no reason to do that. He did, and doing it took time he chose to
     spend. So: no body, no blood, and a man who left tidy. He is ALIVE and he is a
     professional, and the player deduces both from what is missing rather than what
     is there.

   **THE SCENE IS STILL WARM (user, 2026-07-25) — the detail that makes it frightening
   instead of sad.** You do not find an old crime. You find one you *just* missed:
   - **Smoke still hanging** in the cave air, layered flat in the still cold where
     nothing has stirred it.
   - **The stink of ozone**, sharp and recent — a discharge smell that fades in minutes.
   - **Blaster scoring on the rock**, and this is where the beat turns: the marks are
     NOT random spite. They are **grouped tight, at chest height, in the sleeping
     alcove and across the doorway** — the two places a man would be. They did not come
     to question a discrepancy. **They came to erase one**, and they shot the places
     before they knew whether anyone was in them.

   So the arithmetic the player does standing there is: *he beat them out by minutes,
   and if he had been slower there would be a body.* And because the smoke has not
   settled, the hunters are not a story Odessa tells any more — they are **present
   tense**, possibly still in the sky overhead. The player never sees a face (that is
   held for later); the threat is entirely made of what it left behind.

   The player leaves knowing more than either of the people who care about him, which
   is the engine the rest of the Campaign runs on. Odessa's reaction is the beat's
   real payoff — she hears "gone, not taken" and it does not comfort her at all.

   IMPLEMENTATION SHAPE (not built): the cave interior needs a **wrecked state**
   (`epharon_town.INTERIORS["?"]` gains a variant — flavour text, scattered props, the
   hermit actor absent, the wall drawn bare), flipped by a quest flag. The stage is a
   `goto`/enter rather than a `talk`, since the point is that there is nobody to talk
   to; the report back to Odessa is the following stage.
   The warm-scene layer is cheap and carries most of the horror: a low **CPUParticles2D
   haze** drifting in the room (the town already builds one for the sandstorm — same
   pattern, slower and flatter), **scorch decals** drawn on the alcove and door rock,
   and the ozone as a **flavour line on entry**, since smell is the one sense the game
   can only ever narrate. Sound sells the near-miss harder than either: the cave should
   be *too quiet*, and a single distant engine note fading out would tell the whole
   story without a word — worth trying, and worth cutting if it reads as a cheap sting.

3. **Who is asking.** Pulling the thread: who the hunters are, why an old man on a
   dust ball is worth Ooshu attention, and how much Odessa has been sitting on.
4. **The reveal.** Who Conall is, what he did at Percival, and the stakes of his
   being found: not one old man's life — a **new war.**
5. **The job: keep him buried.** Divert the hunters, muddy the trail, protect the
   cave, root out the leak. (Exact beats TODO — see Open questions.)
6. **It fails.** You can't keep him hidden.
7. **The heavy decision.** Conall stops hiding. He becomes the legend, and draws
   the Quarn **into the gate** — pulling the whole hunt out of Cinder Reach and
   **saving the Reach by pulling the Quarn in.** The Campaign's climax is a man
   deciding to be who he is, at the cost of everything.

**Where the Cinder Reach Campaign ends:** on Conall's departure — the Reach saved,
the legend gone into the black. His *further* payoff belongs to the Saga (below).

---

## The Braid (the one point Campaign and Saga touch)

The Campaign is thematically independent (the Quarn war, not the Convergence), but
its **climax shares the Saga's Movement-I gate-finale** — same gate, same moment:

- *You* open the gate (the Saga's inciting incident).
- Conall uses that opening to drag the Quarn through it (the Campaign's climax).
- **One set-piece, two payoffs.**

And Conall then becomes a **Saga-spanning thread**: he *heard what you did and
follows* — through the gate, into the Movements beyond. He rises for good far later,
shows up at a **final confrontation**, ends the Quarn capital-ship fleet, and **goes
down with it.** So the Cinder Reach Campaign is really the **first movement of a
longer Conall arc**; his death is a Saga-later beat.

> Design note: this is a deliberate braid, not a drift. The rule "the Campaign has
> nothing to do with the gate/Saga" holds for its *length*; the gate is a *place*
> the Campaign uses at the end, not the Convergence it's *about*.

---

## Open questions (resolve while authoring)

- **The player's beats.** What, concretely, is "keep him buried"? (Feed the hunters
  a false trail? Hunt the hunters? Root out the Ember Row leak? Move him? A
  temptation to sell him?) Needs stage kinds on the Quests framework.
- **The lead hunter** — a named noir antagonist / foil worth the reveal.
- **The failure beat** — how "you can't keep him hidden" lands so the heavy
  decision feels forced, not chosen lightly.
- **Traversal for the finale** — the gate braid assumes the player is at the gate
  for the Saga finale; how the Campaign's clock syncs to that moment.
- **Player-facing Galean sweep** (game strings → never "human") — branch task.
- **Percival / Quarn territory** — chart markers now; buildable later.
