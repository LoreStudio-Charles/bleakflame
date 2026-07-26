# Planet districts — landing regions per world

**Canon (user, 2026-07-25).** A planet is NOT one landing site and never a dock screen
(see [[ground-mode-mvp]] / docs on the ground pass). Each world gets **1–4 DISTRICTS**:
separate, large landmasses you set down on and walk around, each its own Epharon-style
walkable region with its own look, residents and services.

**The districts are read off the PIXEL ART.** The planet sprite already shows its
biomes, so the regions are not invented — they are the map the player can see from
orbit. Landing picks a district; the district is the region scene.

Status: **NOTED, NOT BUILT.** Epharon remains the only built region (one district, the
colony). This is the plan of record for when the region work resumes.

---

## Orivel — the Galean capital (4 districts)

Ocean-world with a domed megacity; `assets/world/orivel.png`. Currently
`landable = false` — a gravity well and a surface collider you can feel but not touch.
Becoming landable means giving it districts, not a dock.

| Quadrant | District | Notes |
|---|---|---|
| **SE** | **The Megacity** | The domed capital itself — the Galean seat. The institutional district: the fleet, the Navy, the machinery of a civilization. Almost certainly where the **Marine** commission lives (see [[marine-profession-banked]]). |
| **NE** | **Tundra** | |
| **NW** | **Desert** | |
| **SW** | **Swamp** | |

Orivel's **orbital outpost** is separate and stays a small bespoke screen
(`scenes/ui/orivel_dock.gd`) — a station berth is not a place you walk.

## Percival — Quarn frontier (3 districts)

The system beyond Cinder Reach; Conall's history is here (he splashed a Quarn cruiser
above it to save it, which is the crime he is hiding from).

| Quadrant | District | Notes |
|---|---|---|
| **SE** | **The Quarn Wastes** | **The Quarn CONVERGED this region to make it a BATTERY WORLD before being driven away.** Industrial atrocity as terrain: whatever converting a landmass into a power source does to it, this is the scar. The most story-loaded ground in either system, and the physical evidence of what the war was. |
| **NE** | **Crystalline Desert** | |
| **W** | **Forest and town** | The living half — people, a settlement, somewhere to stand that isn't a wound. |

**Why the Wastes matter to the Campaign:** Conall's whole secret is that being found
restarts the Quarn war. Percival's SE quadrant is what that war LOOKS like when the
Quarn win a region. Walking it is the argument for why keeping one old man buried is
worth what it costs — shown, not told.

---

## Open, to settle when regions resume

- How landing chooses a district: an orbital selection (pick a quadrant on approach) vs
  the landing minigame per site. Orbital selection is likely — it makes the sprite the
  menu, which is the whole appeal.
- Whether every district needs services, or some are pure exploration (the Wastes almost
  certainly have no services and no people at all — that IS the point).
- Fast travel between a world's own districts, or fly up and back down.
