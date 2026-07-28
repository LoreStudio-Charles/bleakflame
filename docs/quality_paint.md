# The quality paint ladder

**Decided with user 2026-07-27/28. NOT BUILT — this is the spec the art hits.**
Companion to the shop-grid plan in `docs/person_as_context.md`; the grade table itself
lives in `scripts/schema/grades.gd`.

## What this is

Grade is visible **on the hull**, not just on a shop tile — so a ship looks like what it
cost. The rule from the shops discussion holds: **fidelity rises by GRADE primarily and
LEVEL secondarily**, and *"cooler" is a fidelity axis, not a hue code*. The Grade palette
(grey / white / green / blue / purple / gold / red + pips) keeps carrying the ranking on
every tile in every shop, so **the paint never has to be read precisely** — it is flavour,
the border is the code. That is what frees the paint to be interesting.

## Overlays, not new sprites (user)

> "Instead of generating new hull art for the icons, we use the existing hulls and apply
> paint jobs to them. Maybe I'll just hand paint in the 'stuff' for each of the qualities
> and we overlay the `rooster_<quality>` layer with a color to make it look special."

**The machinery already exists.** Livery decals are children of the hull sprite clipped by
a `clip_children` stencil, and `set_hull_tint` writes `self_modulate` (NOT `modulate`) so a
hull tint never cascades into its decals — a rule paid for in blood when the Widows' red
hourglass times their black hull rendered as effectively black, and guarded by
`test_widows`. A quality layer is that system with a new input.

**GENERIC FIRST, PER-HULL ONLY WHERE IT EARNS IT.** `rooster_<quality>` per hull is 9 hulls
× 7 grades = 63 hand-painted layers, and it has to be re-paid for every hull ever added.
The stencil means a mark drawn on a plain bounding box is **cut to each hull's silhouette
automatically**, so the generic set is ~6 assets that work on every hull forever, including
the banked ones. Hand-painted per-hull overrides then drop in exactly like
`variants/<hull>/` skins, for the hulls that deserve them (the Bleakflame, the Dowager).
Start generic; upgrade the heroes.

## The ladder

The user's first pass separated the bottom four by SATURATION only. Four saturation steps
of an arbitrary hue are not rankable without a reference tile beside them, and saturation
is the worst case for colourblindness — which is why this project pairs every colour with
pips. Both halves are therefore **shape**, so every step reads alone:

| Grade | Paint | Reads as |
|---|---|---|
| **Flotsam** | heavy rust, pitting, mismatched panels | found floating, no provenance |
| **Rough** | scuffed, patched, one replaced panel | used, unglamorous, and it works |
| **Standard** | clean | factory |
| **Advanced** | clean + polished trim | cared for |
| **Experimental** | + a stripe | marked |
| **Bespoke** | + an authored insignia (see below) | *someone made this, for someone* |
| **Exotic** | + an ALIEN insignia (see below) | not ours |

Cheap ships are beaten up; expensive ships are decorated. The ladder tells a story rather
than encoding a number twice.

## Bespoke: a family, not a mark (user)

> "Maybe the Bespoke can have several variants, a line of diamonds down each side, an
> ornament, a Chevron, etc."

Right, and the data already says so: Bespoke carries `affixes: 0` because these are
**hand-authored uniques with fixed mechanics, not rolled loot**. A one-off should not wear
the same badge as every other one-off. So a Bespoke item names its own insignia.

## Exotic: whose technology this is (user)

> "Exotic can always have an alien element to them. Maybe always a paw or lightning for the
> wardens or a long, vulture beak or talon for the Dhakar. Something that identifies which
> alien species we learned the technology from."

**This is the strongest idea in the ladder, because it turns decoration into information —
and then into liability.**

One glyph per species, so every Exotic item from the same source shares a mark and the
player learns to read provenance at a glance. The asset count is bounded by the number of
species, not the number of items.

**And the lore makes the mark dangerous.** `docs/economy_and_contraband.md`:

| | What it is | What holding it says |
|---|---|---|
| **Warden relic** | the jailers' work | evidence of **the crime** |
| **Dhakar relic** | the enemy's work | evidence of **COLLABORATION** |

The Wardens execute humanity *because they assume we are Dhakar collaborators* — the
genocide is a case of mistaken identity on exactly this point. So a hull wearing a Dhakar
talon is not flair; it is **the murder weapon, worn in public**. Anything that can read the
mark should react to it, and the contraband doc's annihilation tier already exists for
precisely this.

### THE SPOILER RULE — the mark ships now, the NAME does not

The Saga's whole structure is that the late reveal cannot be stated early: the game's own
TITLE encodes the ending in a language the player cannot yet read, and `test_quests` guards
against ever printing "Warden" / "Prison" / "The Convergence" in the log.

An **unreadable alien glyph is that trick applied to loot.** It ships from day one and says
nothing; the player collects marks they cannot interpret; and at the reveal their whole
inventory recontextualises — the same gut-punch as learning the gate was a lock.

So the glyph is always drawn, and the NAME resolves only once earned:

- **before**: *"An alien mark. Nobody at this station can read it."*
- **after**: *"Warden."* / *"Dhakar."* — and the second one should feel like being handed
  a loaded gun.

Identification is a capability you earn, exactly as it is for `Ship.classify` (role is
sensor data, not paint) and for POI fog of discovery. This is also the natural home for the
Scan Data codex idea: cataloguing an alien mark IS a discovery.

## Implementation shape (not built)

**ONE FIELD, TWO POLICIES.** An `insignia` decal id on the item:

- **Bespoke** — authored PER ITEM (diamonds, chevron, ornament).
- **Exotic** — derived from PROVENANCE, so all gear from one species shares a mark.

Same renderer, same clipped-decal path, two ways of filling one field.

**Particles (Bespoke + Exotic, in flight).** Bespoke gets the proud one. Exotic gets the
UNEASY one — Exotic already "carries hazard risk" in canon, so an unstable shimmer or leak
makes the drawback visible instead of reading as expensive sparkle.

**One collision to avoid: NOT violet smoke.** Cinderweb has sole ownership of dread — the
reason pirate terror was deliberately kept mundane (reputation, not the supernatural). An
Exotic hull trailing violet would spend the beast's signature on a paint job. Dhakar cold
violet is a LATE-Saga reveal and belongs to that moment, not to a shop item.

## Also done

**SALVAGE grade renamed to "ROUGH"** (user). The word was overloaded — the `[B]` salvage
panel, Salvage All, `salvage_reach`, the Salvaged Coupling, the SALVAGE SKILL and the affix
pillar all meant different things by it — and it sat too close to STANDARD one rung above.
Display string only: `Grades.INFO[Grade.SALVAGE].name`. **The enum identifier and its
ordinal do not move** — grade values are serialized in every `.tres` on disk.

**Why Rough and not Junk** (the first candidate, briefly committed):

1. **The mechanics.** Flotsam is the compromised tier — it ALWAYS carries a drawback
   affix. This one carries none; its defining property is that it *works* and simply
   isn't special. Naming it after rubbish described the rung below it, and left the
   bottom two tiers as near-synonyms that taught nothing about their own order.
2. **Genre literacy** (user): *"Rough sits close to Rusty, which is a common RPG [tier],
   and I think that familiarity earns its place."* A player has read this word on a loot
   tier before — the ladder gets a free rung of comprehension.
3. It also collided with the **Junker Slugthrower**, the level-1 weapon that *is* this
   grade.

Alternates considered and rejected: **Refit** (perfect nautical fit, but "refit" is
already the verb the Engineering Bay runs on — the exact trap Salvage fell into),
**Workaday**, **Knockabout**, **Tramp**, and anything starting with S.
