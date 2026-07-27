# The Saga in Cinder Reach — Movement I

> **NAMING, corrected 2026-07-26 (user).** This document was titled *Starter System
> Campaign — "Nothing Left Behind"*, which conflated two things. **"Nothing Left
> Behind" is the title of the FINALE QUEST** of this chain (`nothing_left_behind`,
> given by Krayt, the reach-the-gate beat) — a beat name that drifted upward into
> being read as the name of a Campaign.
>
> Under the locked vocabulary this chain is the **SAGA's first movement**, not a
> Campaign. **Cinder Reach's Campaign is "The Legend"**
> (`docs/cinder_reach_campaign.md`). The quest keeps its title; only the framing was
> wrong.
>
> **EVERY SPINE IS "THE &lt;SOMETHING&gt;"** — The Gate, The Legend, and whatever
> follows. The rhythm is deliberate (user).
>
> The log titles the Saga by its **current MOVEMENT** (`Quests.SAGA_MOVEMENTS`),
> not by its own name: the Convergence is a late reveal, so printing it from hour
> one would name the threat decades before the story does. **"The Gate" is visible
> from the first hour and is the obvious goal, so it spoils nothing** — and the
> title turns over on its own as Movement II lands. A test asserts the Saga's log
> title never contains the reveal.

Working title. Cinder Reach's Campaign (its system story within the Saga), from
first missing ship to the gate out of the system. Premise and beat structure authored by the user
2026-07-19; connective tissue drafted for reaction. CANON RULES and the
BEAT SPINE are fixed; everything else is adjustable.

## Canon rules (from the user — do not drift)

1. Pirate raids leave EVIDENCE: debris, wreckage, distress calls, survivors.
2. The Cinderweb leaves NOTHING. A last blip, a final comm, silence. It
   absorbs its prey into its nightmare existence.
3. NO ONE has survived an encounter — until the player does.
4. Only rumors, nightmares, and ancient folktales give the threat shape.
5. The Cinderweb CANNOT be confronted in this system. Discovering it — not
   defeating it — is the climax, and it points to the next system: a race
   to find a way to end the threat before it consumes the station itself.

## Decided (2026-07-19)

- **Retreat, not death**: at 0 HP the leviathan folds into the dark,
  disgorges its hoard, and returns next orbit. The fight and loot stay;
  "nothing of this world can end it" is proven in play.
- **Simulated hunger**: the Cinderweb really devours lane AI ships in-sim
  (leaving nothing; the living world launches replacements from home).
  Missing-ship reports can cite actual losses.
- **Travel**: the way out is an ANCIENT GATE at the system's rim. Gates are
  the only travel until much later, when a System-slot module (jump drive)
  unlocks opening a gate from anywhere. Force gate use until then.
- **The Shoal is ALTERED, not destroyed** (beat 7 aftermath): the Cinderweb
  takes the ships and the exposed — Krayt among them — and leaves the rust
  standing: hatches open to vacuum, no wreckage, no bodies (traceless,
  per canon). The survivors keep the den LIT like a bonfire afterward —
  the folktale says the sky-web shuns a bright-burning hearth, and the
  Shoal's old darkness was an invitation. Gameplay: post-beat-7 the den
  stops being sensor-gated and becomes a far-visible landmark; patrols
  thin for a while (the sim replacement pipeline was gutted); an umbral
  residue anomaly (beat 2's type — a bookend) hangs in the den; pirates
  come back humbled and more willing to talk to the one who survived it.

## The beat spine (user-authored order)

1. **Last position** — a contract to seek out a lost ship's last known
   position. The sweep finds nothing at all — except one strange reading
   nearby that shouldn't be there.
2. **The anomaly** — scan the strange anomaly (needs a survey scanner):
   a cold violet residue, matter that reads as ABSENT. The lab has no
   category for it. (This is a devouring's only footprint.)
3. **The ambush** — a scripted Cinderweb ambush. This is exactly what
   on-player spawning is reserved for: investigating a second loss site,
   the dark arrives. Barely a shape — dread sting, comms shredded, the
   violet bearing. Objective: SURVIVE. Run for the station's light.
   Nobody fully believes what the player reports.
4. **First contact** — deliberate, prepared, knowing: return to where it
   must pass and face it long enough to SEE it whole (and scan it — the
   existing gaze-range scan, "exactly the terrible idea it sounds like").
   The player becomes the first to survive an encounter — on purpose.
   Station mood turns from worried to afraid.
5. **The hermit** — an old hermit on the planet (ex-spacer, decades dirtside
   because of what he saw) has been counting the thing's breathing for
   thirty years. His "ravings" are data: a rhythm (the orbit), and the old
   colony tale of the sky-web that drinks lanterns but will not come near
   a hearth that burns bright enough (why station light is sanctuary —
   for now).
6. **The pirate** — a pirate hiding out in the Rust Shoal. Pirates have
   been losing ships too — he's the only one who ran instead of doubting.
   He knows things nobody civilized does: where the losses REALLY cluster,
   and what sits at the system's rim (the gate). Reaching him means
   entering the den under some arrangement (fight, pay, or truce — his
   protection racket inverted: HE needs the player).
7. **The final communication** — staged as a WITNESS set-piece, not a
   told-in-a-box death (implemented 2026-07-21, flight_test `_tick_shoal_fall`
   / `_run_shoal_fall`):
   - The meeting at the Shoal (beat 6, in person at Speak's Easy) ends CALM,
     on the DEAL — Krayt trades the gate's key for the player flying cover to
     the rim. No attack in the dialogue (the old version narrated the attack
     while the player sat safely docked — spatially confusing; fixed).
   - The player launches. Once undocked and still near the Shoal, the dark
     takes it: the Shoal goes dark (`PirateDen.go_dark`), Cinderweb tears out
     on a scripted flee vector (`Cinderweb.spawn_pursuit` — pure decoration,
     never sees or touches the player), and Krayt's ship (`FleeingShip`)
     burns out AWAY from the player, DRAWING the beast off. Both far too fast
     to follow — you can only watch him buy your escape. The ambient orbiter
     is suspended for the beat; the truce holds fire the whole time.
   - A held breath later (in flight, never while docked/dead), Krayt's final
     transmission comes through on-mic — devoured live, transmitting the
     gate's waking sequence. Closing it BEGINS the finale (`nothing_left_behind`
     is `manual_start`; `Quests.begin_manual` charts the gate).
   - Then **Vyper** hails (beat 7 coda): Krayt's successor, who watched him
     die drawing it off. Grief + a brief memorial + a banner of truce — the
     Shoal declares the player OFF LIMITS (honor it and no raider burns you;
     break it and she sheds your blood). This heals the ending's rough edge:
     horror → grief → truce → departure, one full turn. Standing +privateer; the
     Shoal's peace goes permanent (`Pilot.shoal_invited`).
   - The gate opens (reach_gate). The campaign ends with passage to the next
     system and the Reach on the clock.

## Cast (draft names — rename freely)

- **Harbormaster Ruel** (station, Landing Bay) — pragmatic contract-giver;
  tracks the losses; arcs from dismissive to scared.
- **Underwriter Voss** (station) — insurance agent whose missing-ship
  contracts open the campaign; the paperwork face of the body count.
- **Odessa** (station bar, "Ember Row") — rumor conduit; her stories point
  the player at the hermit and, later, the pirate.
- **The Hermit** (planet colony's edge) — beat 5. Unnamed by everyone;
  the colony calls him "the Counter."
- **Krayt** (Rust Shoal) — beat 6/7. Pirate quartermaster gone to ground;
  swaggering fiction over genuine terror; dies drawing the beast off so the
  rest can run (witness set-piece, not an off-screen report).
- **Vyper** (Rust Shoal) — beat 7 coda. Krayt's successor; hails after his
  death with the memorial + the banner of truce that makes the Shoal neutral
  to the player. Portrait `assets/portraits/vyper.png`; voice in vo_casting.md.

## Framework work this campaign demands (build order)

1. **StoryLog** — generalize Research.CHAINS: stages with kinds (talk,
   goto/search, scan_target, survive_event, dock_at), rewards
   (credits/xp/items), world flags (station mood). Persisted in SaveGame.
2. **Dialogue panel** — portrait + text + choices in the dock-screen style;
   NPCs as data. Doubles as the Cinderheart text-adventure engine and the
   comm window for Krayt's transmissions in flight.
3. **Scripted encounters** — quest-keyed spawns: search sites, the anomaly,
   the ambush trigger, Krayt's hideout, the gate. Generalizes the dig-site
   spawner pattern.
4. **Sim hunger** — Cinderweb devours AI lane ships it catches (no loot, no
   wreck, a last radio squawk if the player is in comm range); the loss
   feeds Voss's contract board. Living world already handles replacements.
5. **Leviathan retreat** — replace `_die()` with fold-into-the-dark +
   hoard disgorge + return next orbit.
6. **The gate** — new rim POI + activation sequence; system-transition
   stub (scene swap target can be a placeholder until system 2 exists).

## Canon joins with existing content

- **Cinderheart chain**: cinder fragments are what the Cinderweb cannot
  digest — its leavings in aurite rock. The artifact chain and campaign
  point at the same off-chart world. The campaign does not require the
  chain, but references it when present.
- **Rust Shoal**: Krayt's presence explains why the den holds despite the
  losses — and beat 7 ends that illusion. The den survives ALTERED (see
  Decided): lit, humbled, permanently changed on the map.
- **Station sanctuary radius**: retroactively lore-grounded by the
  lantern folktale (beat 5).

## Still open (minor)

- All cast names are placeholders.
- Whether beat 4 (first contact) requires the scanner fitted or lends the
  player a quest-issued one (a broke player must not be soft-locked).
- Gate wake-up mechanics: instant vs a short defense/attunement sequence.
