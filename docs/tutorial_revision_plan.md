# Tutorial Revision Plan — the full audit

**Status: PLANNED, deliberately NOT built (user, 2026-07-25).** The Epharon ground
experience is still growing; authoring lessons against a moving target means authoring
them twice. This doc banks the audit and the plan so the final lesson pass starts from
facts, not archaeology. **Trigger to execute: when the Epharon build-out settles** —
new surfaces will have surfaced their own lessons by then (the user's point).

The engine itself needs NO work: lessons are data (`Tutor.LESSONS` + predicates in
`_build_preds`), the ground context ("where": "ground", `target`, town caption + chevron)
already runs `ground_intro`, and the watchdog/venue/filler hardening all stands. This is
an AUTHORING pass.

---

## 1) Audit of the 30 existing lessons

### KEEP AS-IS (current and correct)
| lesson | teaches | note |
|---|---|---|
| `flight_training` | W/S, A/D, SHIFT/SPACE, drones, dock | **User: "how to fly still works."** Drones step already updated to target-and-engage (RMB engage, [Q] hold fire). AUDIT ITEM: re-play it once — the removal of hold-LMB-to-fire changes the *feel* of the drone step even though the copy is right. |
| `vitals` | effigy = hull/shield/armor/energy | dwell blurb, sound |
| `buy_scanner` | Armory → buy chip → Engineering → coupling | station loop, unchanged |
| `memorize` | fire the wired ability [1]-[5] | |
| `chart` | [M] map | copy updated to [M] |
| `running_dark` | [K], recharge + re-flash | |
| `comms` | [C] archive | |
| `launch` | [E] go / [Q] scrub | already E/Q = confirm/cancel |
| `log` | [L] captain's log | |
| `salvage` | [H] when hold full | copy updated to [H] |
| `ordnance` | [R] launches, rounds finite | rewritten for launch-not-hold; event `fired_ordnance` |
| `targeting` | LMB select / RMB engage / TAB cycle | rewritten this session |
| `turn_in`, `pips`, `office`, `commission`, `meet_ruel`, `meet_dex`, `meet_doug` | dock social flow | station-side, fine |
| 8 × `tab_intro_*` | station tab blurbs | station keeps its tabbed dock — fine |
| `ground_intro` | walk, meet Imari, market, launch | already ground-native |

### STALE — the 5 steps that point at planet dock tabs a walking player never sees
| lesson | stale steps | fix shape |
|---|---|---|
| `trade` | last 2 ("Open the Mission Uplink", turn-in) | tail becomes ground steps: `target: "CONTRACTS"` (the board building) |
| `trade_return` | first 2 ("Open the colony MARKET", buy 4 food) | `target: "MARKET"`, done-pred stays `cargo_food >= 4` (the shop fires `used_market`) |
| `meet_sella` | 1 ("Open the Explorer's Union") | `target: "EXPLORERS GUILD"` or her person; she posts survey work on the ground board now |

These are the LAST consumers of the shoehorn scaffolding. Converting them deletes:
`epharon_town._tutor_dirtside` + `TUTOR_BUILDING`, `TutorPing._tab_hidden`, the
`TabPips.tabs_visible` guard, and (once no `svc:` action remains) `flight_test._on_town_service`.

---

## 2) Coverage audit — what a new player must know vs what is taught

### Keys: taught ✓
W/A/S/D · SHIFT · SPACE · E · Q (scrub + weapons-free) · R · TAB · LMB/RMB · 1-5 ·
[M] [L] [C] [H] [K] · Esc (self-evident)

### Keys: NEVER taught — gaps to fill in the revision
| key | what | proposed teaching moment |
|---|---|---|
| **[P] dossier** | pilot/ship/inventory sheet | first level-up or first standing gain ("someone's keeping score — press [P]") |
| **[I] factions** | standing/war/peace | first standing CHANGE the player causes (first pirate kill) |
| **[G] ground guide** | *(nothing — G is free now)* | — |
| **F1-F4 party frames** | target self/party | DEFER until multiplayer/party exists; teaching a solo player F2-F4 is noise. F1 (self) could teach with self-cast abilities (Bulwark) |
| **Enter comm terminal** | chat + /commands | it's also the dev gate; a "comms chatter" beat could teach it late, low priority |
| **[B] bags / [U] social** | reserved, unbuilt | teach when they exist |
| **[E] vs RMB split** | context vs target interact | fold one line into `targeting` or ground_intro; the two-verbs idea is THE input lesson |

### Panels: taught ✓
Station: all 8 tabs (tab_intro_*) + offices. Flight: chart, log, comms, salvage, going-dark.

### Panels: NEVER taught — gaps
| surface | gap |
|---|---|
| **Ground ShopView** | `used_market` fires, but nothing teaches the RPG idiom itself (shelf = buy right-click, your hold = sell right-click). One caption when the first shop opens. |
| **Ground BoardView** | same — postings expand, turn-in lights where valid |
| ~~**Character sheet [P]**~~ | TAUGHT 2026-07-25 — the `dossier` lesson arms the first time a SKILL POINT is waiting (unpinned, in flight, where kills earn it) |
| **StarMap levels** | `chart` teaches [M] but not RMB-zoom-out / click-in — one line of copy when first opened ON THE GROUND (where SURFACE→SYSTEM is visible) |
| **Weapons-free state** | `targeting` implies it; nothing teaches [Q] as the deliberate toggle when you want guns hot WITHOUT a target (e.g. mining rocks chip with any gun) |
| **The cave / hermit** | quest-driven (fine) — but ground_intro could name "places worth walking to" |

### Ground verbs — TAUGHT as of 2026-07-25 (ground combat landed)
Three lessons, each armed by the SITUATION rather than by landing, because a caption
about killing things is noise to someone who came down to sell food:
- **`ground_fight`** — arms on `hostile_near`. RMB targets AND fires, TAB cycles, LMB
  only looks; then [Q] by hand, the auto stand-down on a kill, and [SPACE] cover.
- **`techniques`** — arms on `has_technique`. [1]-[5], then WHERE they come from
  (training, prepared at [P]) — taught apart from the fight lesson on purpose, since
  "how to shoot" and "where abilities live" are different ideas.
- **`meditate`** — arms on a cell below half. Answers a question the player is already
  asking.
ALL THREE ALSO REQUIRE `tutorial_done`: that is their own precondition (a licensed
pilot), not chaining off another lesson. Without it they armed during FLIGHT TRAINING
and took the slot the colony onboarding needed — caught by test_ground_tutor.
Still unbuilt, still untaught: grenade [R], sprint [SHIFT].

---

## 3) Structural notes for the final pass (hardening)

- **The engine hardening stands** — watchdog, venue gates, filler rules, auto-skip. Do
  not touch. New lessons must follow the established rules: arm on OWN preconditions
  (never chain off another lesson completing), venue-tag single-venue steps, dwell only
  on filler, ctx keys read with `c.get(key, default)`.
- **Ground lessons complete by POLL or by `did()` events** the town already fires:
  `ground_moved`, `met_<npc>`, `used_market`, `used_mission_uplink`, `launched`,
  `chart_opened`, plus combat's `weapons_free`/`fired_ordnance`. New surfaces should
  fire `did()` events in the same style (one unconditional set at the action site).
- **test_dock_ui's authoring validator** exempts `where:"ground"` steps from anchors;
  ground steps need `text` (+ optional `target`). Keep the validator in lockstep when
  the lesson set changes — it is the thing that catches a typo'd lesson before a player.
- **Copy rule — DONE 2026-07-25.** Lesson copy writes `{TOKEN}`s (`{DOSSIER}`,
  `{CANCEL}`, `{ABILITIES}`, `{MOVE}`…) and `Keys.expand()` resolves them against the
  LIVE binding at render time, in both surfaces (TutorPing captions and the town's
  ground caption). Rebind a key and every lesson re-words itself. `Keys.TOKENS` is the
  registry; add a binding there the same moment you add the const, or the token renders
  as itself — visible nonsense, which is the failure mode we want.
  GUARDED by test_keys `_check_lesson_copy`: it scans every step of every lesson for a
  bracketed literal Keys owns and fails the build. `[W]/[A]/[S]/[D]` stay literal on
  purpose (raw polled movement, no binding to go stale) and are the allow-list to
  shorten the day movement becomes rebindable.
- **The "launch" lesson stays imperative** (transient countdown modal) — the one
  sanctioned exception.

## 4) Proposed teaching arc (draft — REVISIT after Epharon settles)

1. **Flight training** (as-is): fly, fight drones, dock.
2. **Station loop** (as-is): Ruel → contracts → Armory/Engineering → scanner → abilities.
3. **First trade run** (revised): accept contract + buy circuits at station (as-is) →
   land → **ground-native**: walk to Imari (crate), walk to MARKET (shop idiom teaches
   itself here: sell circuits, buy food), CONTRACTS board, launch.
4. **Colony life** (new, mostly quest-driven): the cave, Sella's postings, the guide
   chevron, [P]/[I] when they first matter.
5. **Combat depth** (event-driven, as-is + gaps): weapons-free without a target,
   ordnance, going dark, salvage.
6. **Ground combat** (future): when the verbs exist.

---

*Related memory: [[ground-services-architecture]] (scaffolding deletions),
[[input-scheme]] (the key/verb model these lessons teach).*
