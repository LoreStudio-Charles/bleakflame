# Threats of the Cinder Reach and Beyond

Design doc for the game's antagonist factions. System 1 (the Reach) ships with
two; this file records the **alien threat** designed next, and banks the one
after it. Decided with the user 2026-07-22.

## The threat triangle — three ways to be "beyond human"

Every antagonist demands a different player response. Keep them distinct:

| Threat | Nature | Player verb |
|---|---|---|
| **Human pirates** | mundane, greedy, out-flyable | **outgrow** them |
| **Cosmic horror** (Cinderweb / leviathans) | unknowable, unkillable in open play, dread | **flee** it |
| **The Wardens** (elder aliens) | ancient, precise, killable-but-hard | **outplay** them |

The Cinderweb owns "unknowable dread." The Wardens are the OTHER beyond-human:
**order and intent** instead of chaos and hunger. You can understand them. You
just can't out-fly them.

---

## THE WARDENS OF THE FOLD (Wraithlight)

The alien antagonist. Working species name TBD — candidates: **the Vael · the
Sidereal · the Wane · the Threnody · the Silvine · the Pale Choir**. ("Eldar"
is the *vibe reference* — graceful, ancient, impossibly superior, space-folding.
The Wardens are an ORIGINAL species, not a copy of anyone's IP.)

### Fiction — masters of folding space
The unifying idea that ties them to what the game already has: **the elders are
the space-folders.** Gates, teleportation, blink — all THEIRS, done natively and
perfectly, where humanity fumbles with scavenged fragments. The WayGate ("The
Ancient Gate") is their road. The Scout's Micro-Warp is a crude reverse-engineered
scrap of their art. Cross a gate and you are not just in a new system — you are
trespassing on *their highway*.

### Intent — GATE-WARDENS (user's call)
Not evil. Not mindless. **You are the transgressor.** They tend the gate-network;
using their gates, taking their tech, entering forbidden space marks you as an
intrusion to be CORRECTED. Hostility is a response, not a nature — so every fight
carries the texture of *you being the aggressor in their ancient domain*. They
regard humanity roughly the way we regard silverfish on library shelves.

### Debut — FORESHADOW THEN CONTACT (user's call)
Rare, silent **probes** begin appearing in the Reach AFTER the player first uses
a gate — watching, never engaging, blinking away when approached. A breadcrumb of
dread and mystery. Full first contact comes a system or two later, when the
player already remembers "the thing that watched." (Placement of true contact:
System 2-3 band; not System 1.)

### The look — WRAITHLIGHT, CRYSTALLINE (LOCKED 2026-07-22)
Design principle: **made of light and grace, not metal and aggression.** A human
ship looks *built* (plates, rivets, bolted guns); a Warden ship looks *grown* or
**SUNG FROM CRYSTAL** — no seams, no visible weapons until they fire. The player
is a caveman looking at a cathedral.

**LOCKED after concept passes:** the CRYSTALLINE versions won — pale ceramic AND
translucent crystal, so the gold light-veins glow *inside* the material rather
than on its surface. That "sung from mineral" quality is what sells "grown, not
built." Reference art (drop-in when the faction is built):
`docs/concepts/wardens/warden_{warship,interceptor,probe}_crystal.png`. The
interceptor is the cleanest family member; the warship's final silhouette should
keep the crystalline *material* but favour the asymmetric organic blade over
perfect ceremonial symmetry (alive, not manufactured). PixelLab prompt spine:
"sung from pale ivory ceramic and translucent crystal, seamless slick smooth
curved hull with subtle crystalline facets, glowing golden light veins deep
within the translucent crystal, gemlike inner glow, no bolted guns."

- Hulls grown from **pale ceramic-bone** — smooth as tusk, seamless as a nautilus
  shell. Veins of **living gold light** run under the surface and pulse when they
  act.
- A **holo-field** wraps the hull — you see them through a heat-shimmer of bent
  light, half-there.
- Silhouettes: crescents, blades, **heron-necked swept prows**. Asymmetric,
  serene, lethal.
- Pilots (glimpsed rarely): tall, elongated, smooth featureless masks. Grace with
  no face. NOTE they must stay KNOWABLE, not faceless-dread — that lane belongs
  to the Cinderweb.
- With a touch of **Iris** menace grafted on (from the runner-up direction): a
  mirror-cold killing edge under the grace — they can reflect your own ship back
  at you a half-second before they fire.
- Palette: bone-white / pearl / **gold light-veins** / cold white lance-fire.

### Mechanics — the "outplay" enemy
The signature is **BLINK**, and it exists specifically to break the game's
existing positional AI (ORBIT / BOOM_ZOOM are beaten by flying better; blink
can't be):
- You can't kite them — they blink TO you.
- You can't corner them — they blink AWAY.
- They blink out of your alpha strike, disengage, regen shields, blink back.
- **Both offensive (flank) and defensive (dodge)** — it's the whole identity.

The counter is therefore **timing and burst, not flying**: catch them mid-cooldown
and alpha through the elder shield in the one window before they phase. This is
what "outplay" means and why they feel unlike pirates.

- **Weapons:** clean energy — *lasers* (fast, precise, steady, low per-hit) and
  *plasma* (slow, heavy, dodgeable). Deliberate contrast to human ballistic *pew*
  and horror bio. Weapons EMERGE from the hull; nothing is bolted on.
- **Defense:** strong regenerating shields (the blink lets them disengage to
  regen) — attritional unless you burst them down in one window.
- **Killable**, unlike leviathans — they are elite, not apex. This is the whole
  reward loop (below).
- Build seam: a new `AIShip.Tactic.BLINK` (or a Warden subclass) with a blink
  cooldown + a "should I blink?" trigger (took damage / player reached optimal
  range / been static too long) + an instant reposition with a shimmer telegraph.
  The `is_dark` / signature machinery and Projectile system already exist to build
  on.

### Reward loop — XCOM-STYLE CROSS-FACTION RESEARCH (user's call — the best part)
Alien tech is NOT a straight loot drop. You recover **artifacts** from downed
Wardens, and turning them into usable gear is a **research + reverse-engineering
project** run through the Research Lab — needing the SCOUTS' data, the lab's
Insight, and eventually the coordination of the OTHER profession masters, **even
the pirates and the guardians.** À la XCOM.

Why this is load-bearing: nothing else in the game forces Ruel (guardian) and
Krayt (privateer) to cooperate. **A shared enemy from beyond the gate does.** The
Warden research tree is the mid-game's connective tissue — the thing that turns
six rival commissions into a reluctant alliance. Payoffs: human-forged plasma and
laser weapons, elder shield tech, and eventually a personal **BLINK module** (the
player earns the enemy's signature — and it feeds the Scout/"sniper that plays
like a wizard" fantasy: blink is the wizard's teleport).

Design the Warden research as its own tree that consumes recovered artifacts +
Scan Data + Insight and gates each unlock behind a named master's contribution.

---

## BANKED — SYSTEM 3: THE THRESHERS (the "space bugs", named 2026-07-22)
The runner-up look direction (the Chitin Choir aesthetic), saved as the NEXT
threat after the Wardens. A **living** fleet answering the Wardens' **sung** one.

> **"If you hear the Threshers, it is too late."** — the creed. The sound is not
> a warning, it is the END of the warning; by the time it reaches you the flail
> is already falling. (Loading-screen / codex / a pirate's last words line.)

**NAME — THE THRESHERS.** They don't hunt, they REAP. The word carries the sound
(threshing = a dry rhythmic mechanical rasp = stridulation, the flail) AND the
death (beating the harvest apart) in one motion. Imagery: a belt is a FIELD, a
convoy a ROW, the player is GRAIN. The horror is that it's CASUAL — the Cinderweb
wants *you* (a predator); the Threshers don't want you, you're just what was in
the field this season. That cold indifference keeps them distinct from the cosmic
horror's personal hunger. Locust-plague in the bones without saying "locust."

**SOUND.** The Rattle→Keening escalation (explored during naming) becomes the
TEXTURE of the Threshing: a dry static rasp (the approach — reuse the existing
`static` Sfx) that tightens and climbs into a shriek as the flail comes down (the
kill). When the comms band fills with dry hiss, the player has seconds.

**THE SHIPS ARE ALIVE — LIVING ASTEROIDS** (refined 2026-07-22). Not built, not
grown-and-flown — LIVING CREATURES with no cockpit and no pilot; the ship *is* the
animal. NOT sleek iridescent bugs (rejected — too colourful, and WINGS DON'T WORK
IN SPACE, they read as atmospheric-flight). Instead: **rough craggy ROCKY
carapace** like dark cratered stone — a Thresher at rest is indistinguishable from
an asteroid. The shell is covered in **swollen blisters and gaping PORES** that
eject their offspring into the abyss; dim sickly amber glow leaks from the cracks
(the biomass within). **PROPULSION IS VENTED GAS** — they don't fly, they DRIFT,
slow and silent and inexorable among the stars. No wings, no engine-flare to spot
them by. Dark, muted, ancient.

TEMPO CONSEQUENCE: this makes the Threshers a SLOW cosmic dread, not agile
fighters. You don't dodge a Thresher tide — you see it coming and you leave the
field. And it weds them to the game's MINING/ASTEROID systems: the belts aren't
all rocks. A survey that wakes the wrong "asteroid" is how a run ends.

**THE HORROR IS CONVERSION, NOT DEATH.** Thresher hulls are covered in breathing
PORES that launch living PROBES — barbed spore-organisms that fall on a world and
INFEST it, seeding a parasite subspecies of Threshers that ABSORBS THE POPULACE
into biomass and new swarm. A world the Threshers reach does not die; it becomes a
NURSERY, and its people become the next generation. This is why "if you hear the
Threshers, it is too late": not just your death — your world turned hive, your
species turned swarm. Distinct from every other threat: Cinderweb eats individuals
traceless (personal hunger); the Wardens execute cleanly (judgment); the Threshers
CONVERT — the loss is of SELF and SPECIES, not just life.

**Ship roles** (concept art: docs/concepts/threshers/ — living-rock pass locked:
dark cratered stone, glowing ember pore-craters, gas-drift, dark muted palette):
- **Drones / spore-pods** (small) — compact rocky mines and seed-eggs ejected
  from the pores. The swarm. Small enough that PixelLab's compact rock-pods nail
  them (thresher_spore_rock = a spiky rock-mine; thresher_seeder_rock = a glowing
  spore-egg). They attack, and they PLANT.
- **The GREAT THRESHER** (boss / leviathan-scale) — NOT just a big drone. At scale
  it becomes a PLACE: a drifting living moonlet / reef of cracked stone riddled
  with glowing pore-craters (thresher_great.png = a living moon that breathes).
  You mistake it for a passing asteroid until the craters open. Its KIT:
  - **SPAWNER** — vents DRONES and ejects PODS to swarm you. A priority-puzzle
    fight, not a duel (burn the adds, burst the mother before the next wave). The
    game's FIRST add-spawning boss.
  - **ACID SPRAY** — a corrosive cloud/spray that DISSOLVES ships. Area denial you
    cannot sit in front of; lingers as a hazard. See damage-flavour note below.
  - **WORLD BIRTHING** — births its young DOWN onto a world, parasitizing it. A
    Great Thresher that reaches an inhabited planet SEEDS it and the world is
    LOST — its people become swarm. STRATEGIC/campaign menace: a race to intercept
    the slow drift before it reaches the colony, or the colony goes dark and
    becomes a nursery. Feeds the convergence arc (worlds falling = a front closing).

**DAMAGE-FLAVOUR WHEEL** (keep the four threats mechanically distinct):
human = BALLISTIC (VK autocannon *pew*); Warden = clean ENERGY (laser/plasma);
Cinderweb = bio-DEVOUR (bite/snare/swallow); **Thresher = CORRODE** (acid: melts
armour, lingers as a hazard zone). A new damage type to build.
