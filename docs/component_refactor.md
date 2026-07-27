# Component refactor — the plan of record

**Designed with the user 2026-07-27, after a five-reviewer audit of the whole
codebase. NOT STARTED.** Read this before touching `dock_screen.gd`.

---

## The thesis (user)

> "Split the nine screens into a single type that could handle any dock tab, then
> create components that each handle specific dock layouts — `dock_tab`,
> `inventory_grid_panel`, `npc_desk_panel`… **That way if there's ever an issue,
> fixing it in one place fixes it everywhere.**"

**The audit proved this empirically.** Every bug the review found was the same
shape: *a rule exists in one place and is needed in two.*

- `_fit_error` gated equip level; `_chip_error` did not; `speak_easy._install_slot`
  did not. Three private copies, one rule, patched three times in two days.
- `MissionLog.complete` exists **so boards don't re-implement turn-in** — and
  ProspectDeck re-implemented it anyway, dropping `Quests.check_new_work`.
- `tick_discovery` honours `ephemeral`; Xenology's chart-everything did not.
- `flight_hud` dedupes the two ally groups; `planetoid` did not (2x gravity),
  and `ship._run_repair` still does not (**2x heal, live**).

None of these were caused by a file being long. Splitting `dock_screen.gd` into
nine tab files would make it prettier and fix **none** of them.

---

## The measured duplication

Counted, not estimated. These are the reasons to do the work.

| ceremony | sites | wrong / drifted |
|---|---|---|
| `for c in X.get_children(): c.queue_free()` then refill | **30** | **24** lack the `remove_child` guard — the exact bug fixed twice on 2026-07-26 |
| Esc capture join/leave | **16** | all hand-rolled; one missed `remove_from_group` kills Esc for the session, silently |
| spawn-then-configure | **11** | **4 different orders**; `spawn_level`-before-`apply_build` is a comment in 3 files and enforced nowhere |
| quest-talk drain | **4** | 3 differ: town skips `Pilot.meet`, ProspectDeck skips `Comms.post` AND `check_new_work` |
| "give the player this item" | **7** | 3 outcomes: stash-fallback / refuse / **silently destroy** (`epharon_town:1311`) |
| approach grading | **3** | ShoalPad overrides wholesale and loses size gate, fault tiers, `docking_taught` |
| ally-group iteration | **5** | 2 don't dedupe |
| salvage reach | **4** | 3 hardcode 650 / 90 / 70 and ignore `interaction_radius()` |

---

## The contract

```gdscript
class_name DockPanel extends Control
var flash: Callable          # the ONE status sink — injected, never owned
var refresh_all: Callable    # ask the conductor; never self-refresh
func build() -> void         # called from _init, NOT _ready
func refresh() -> void
```

**A panel never holds a host reference.** `item_visuals.gd:5` and `item_tile.gd:6`
both record that the last extraction had to break a `screen: DockScreen`
back-pointer. That residue is why statics kept being added to `DockScreen` for
outsiders to call.

**Build in `_init`.** `DockScreen._init` calls `_build_ui()` before the node is in
the tree, and `test_dock_ui._fresh_dock` reads `Tutor._anchors` immediately after
construction. Deferring to `_ready` passes today only by luck of `add_child`
ordering. `NpcDesk` already builds in `_init` — match it.

---

## The panels, ordered by how many places re-implement them

1. **`InventoryGridPanel`** — hold, stash, shop shelf, your-goods, chip rack,
   Landing Bay manifest = **6 uses**. Both deferred-`queue_free` bugs lived in
   grid-refill code; one panel makes that class impossible.
2. **`NpcDeskPanel`** — 5 dock desks + ProspectDeck hand-rolls Doug's + SpeakEasy
   has none. Wraps the existing `NpcDesk` plus talk routing.
3. **`StatusLinePanel`** — 4 dialects, and **OrivelDock still cannot tell the
   player anything at all**.
4. **`ContractListPanel`** — dock Missions + BoardView + ProspectDeck = 3
   renderings. Share the *row language* (`BoardView._brief`/`_terms` → MissionLog);
   do **not** unify the widget (BoardView's layout answers its own space budget).
5. **`FilterBarPanel`** — Armory today; the ground shop wants it.

`DockTab` = title + venue + `panels[]` + pip state.

> **A TAB TITLE IS A DATA KEY.** `Npcs.home()` returns literal tab strings and
> `_tab_has_waiting` string-matches them. Rename one and the pip, desk routing and
> notice line go quiet with no error. Same class as a save key.

---

## Cross-cutting components (bigger win than the dock split)

These fix live bugs, not just structure:

- **`ShipFitting.fit_error(build, comp, slot)`** — ends the three-copy level-gate
  saga. Callers: `_auto_fit`, `SlotSquare._can_drop_data`, `_fit_from`,
  `_load_chip`, `SpeakEasy._install_slot`, any future quartermaster.
- **`TalkDrain.present(host, npc_id, on_closed)`** — owns dedupe, `Pilot.meet`,
  reward stamp, `Comms.post`, `advance_talk`, `check_new_work`. Four hosts, one
  loop. **Needs `Quests.take_talks_at(venue: String)` first** (~6 lines; mirrors
  `MissionLog.offers_for`→`offers_at`), because `take_talks(bool)` can never drain
  Krayt/Vyper/Doug.
- **`Commerce.acquire(ship, comp)`** — one hold→stash→refuse policy. Today
  `GuildOffice` takes the purchase action as an injected Callable and therefore
  behaves *differently at two counters*; the injection **is** the coupling.
- **`BuildShip.allies_within(radius)`** — deduped. Fixes the live 2x Repair Field
  heal (`ship.gd:1663`) and the over-reported Bulwark count.
- **`BuildShip.loot_in_reach()`** — makes `interaction_radius()` mean something at
  all four readers instead of one.
- **`UiTheme.clear_children(node)`** — 30 sites, one deferred-free rule.
- **`EscCapture.bind(control)`** — 16 sites; the leave path can no longer be
  forgotten because nobody writes it.
- **`spawn_ship(cls, parent, pos, build, opts)`** — one order, made unrepresentable
  to get wrong. 11 sites, 4 orders today.

---

## God-object clusters worth moving (measured coupling)

| cluster | lines | crossings |
|---|---|---|
| `TownDressing` out of `epharon_town.gd:1544-2206` | 662 | **6** |
| `WorldPopulation` out of `flight_test.gd` (spawn family) | ~480 | **1** — touches `ship` zero times |
| `AbilityRuntime` out of `ship.gd` (9 parallel tables per ability) | ~250 | ~8 |

Adding one ability is **nine** edits today.

---

## Do NOT split

1. **`refresh()`'s order.** "Collect talks FIRST", "`Tutor.observe` LAST" — both are
   scar tissue with comments naming the bug each prevents. Panels expose
   `refresh()`; the conductor keeps the sequence. Never self-refresh off a signal.
2. **`_dock_context()`.** Every predicate reads `c.get(key, default)`, so a fragment
   that fails to merge yields a falsy key and a lesson that silently never arms.
   Assemble the snapshot in one place.
3. **`is_station`.** The venue differences are irregular, not parametric. All three
   bespoke screens independently chose bespoke and their headers say why.
4. **The Engineering move verbs as a set.** Each is remove→place→`apply_build`→
   flash→refresh. Split them and you get "item leaves source, lands nowhere."
   Extract the *rules* (`ShipFitting`); keep the *moves* together.
5. **`flight_hud`'s ten inner classes.** They read `ship` every frame and their
   geometry comes from the JSON cockpit layout. That coupling is the design.
6. **`BuildShip.take_damage`.** Verified single-source: all 11 damage sources route
   through it. Nothing to do.
7. **The two ability buses** (`gems` vs `techniques`). Hardware vs training with
   separate save keys is load-bearing. Share the *mechanism* (`Bus` value type),
   never the data.

---

## Order of work

0. **Delete the proven-dead code first** (~90 lines in `dock_screen` alone:
   `_bar_pending_talk` + `_present_bar_talk_if_shown`, `_note_open_tab`,
   `_populate_component_hold`, `_on_list_selected`, `_material_glyph/_color`).
   `_note_open_tab` has a comment claiming `refresh()` calls it. It does not.
1. Cut the residual static API off `DockScreen` (`hull_tooltip` → `ItemVisuals`,
   `BUY_MULT` → `ItemVisuals`, `AbilityButton` → own file). **Precondition for
   everything else** — an extracted panel still calling `DockScreen.grade_tooltip`
   has not been extracted.
2. Layout vocabulary → `UiTheme` (`_column`, `_grid_in`, `_empty_note`, …). Without
   this every panel copies them and you get four dialects. `shop_view.gd:24`
   already defines `GOOD`/`BAD` with the comment "(matches the dock's MKT_GREEN)" —
   *a comment is not a constant.*
3. `ShipFitting` — highest payoff per line in the file.
4. `InventoryGridPanel` — the first real panel, 6 call sites.
5. `TalkDrain` — three hosts, two wrong today.
6. `DockTab` + migrate tabs one at a time.
7. `EngineeringDeck` last: most layout-sensitive, reused by nobody, needs 2 and 3
   landed first.

**Realistic endpoint: `dock_screen.gd` at ~1,400-1,600 lines.** Driving it lower
means extracting single-host tabs, and this project's record is that every
extraction that stuck was justified by a *second host*, never by size.

---

## Test discipline

`test_dock_ui` builds a REAL `DockScreen` and walks it for buttons (660
assertions). It pokes internals directly — `_held_talks` (7 sites), `_talk_queue`
(6), `_active_talk` (6). Rewrite those to the new owner **in the same commit** as
the move.

> **Then sabotage-verify.** Delete the moved rule inside its new home and confirm
> the matching case goes red. Otherwise you have proved the test still *runs*, not
> that it still *tests the moved code*. Two tests on 2026-07-26 agreed with the
> bug they were written alongside, because assertion and code came from the same
> wrong idea.

A new `class_name` file needs `--import` before anything can reference it, or the
scene test hangs with **empty output**.
