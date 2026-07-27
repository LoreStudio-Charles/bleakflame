# Engineering principles

Decided with the user 2026-07-27, after a session where the same few bug shapes
turned up again. This is the source of truth for *how* we build; CLAUDE.md carries
a one-line pointer at it. Add to it when a rule earns its place by catching
something real — not because a principle is famous.

---

## 1. Command/Query Separation (ADOPTED)

**A method either changes state or answers a question. Never both.**

- A **command** mutates and returns nothing (or a bare success/failure).
- A **query** returns data and mutates *nothing* — you can call it twice, in any
  order, from a test or a draw loop, and nothing moves.

**The bug this would have caught.** `Scrit.loot()` was both: it answered "what is
this body holding?" *and* cleared the fields, dropped the corpse out of its group,
and tweened it away. With a full hold it handed back what it could and freed the
rest — the only one of seven give-the-player-an-item paths in the codebase that
silently **destroyed** an affixed drop that `Affixes.roll_for_drop` had just
generated. Split as `peek_haul()` / `take_haul(what)`, that outcome is not
expressible.

Watch for the tell: a function whose name is a **noun or a question** but whose
body assigns to a field. `loot()`, `stats()`, `offers_for()`, `take_talks()`.
Some of these are fine and deliberate — `take_*` announces its mutation — but the
name has to admit it.

**Where a query is allowed to write:** memoisation that is invisible from outside
(`GroundScenery.collider_points` caching a parsed polygon; `Nameplate.viewer()`
caching its lookup). The rule is about *observable* state.

## 2. CQRS — NOT in the client. Possibly at the server boundary. (DEFERRED)

Full CQRS — separate write and read models, projections, eventual consistency —
solves read/write asymmetry **across a distributed boundary**. The Godot client
has no such boundary: the write model and the read model are the same node being
drawn this frame. A projection lag between "ship took damage" and "the HUD shows
it" would manufacture the exact defect the nameplate design avoids (a marker
trailing its owner by a frame reads worse than no marker at all).

If multiplayer becomes **MMO on the Elixir/OTP server** rather than 1–4 coop, the
server *is* a distributed system and command/event separation is idiomatic there.
That is a decision to make **with** the server, not ahead of it — see
docs/multiplayer_readiness.md.

**What helps on either road, and is worth doing now:** make mutations *explicit
and serializable*. That is the command half of CQRS without the read-model
machinery, and it is what the PlayerState migration is already doing. A field
written from forty places cannot become a message; a named operation can.

## 3. SOLID — take SRP, DIP and LSP. Skip OCP and ISP.

**SRP — yes.** Split by *axis of change*. `GroundScenery` (machinery, reused by
every planet) vs `epharon_town` (contents, true of one place) is the shape. The
test is: "when X changes, how many files do I open?"

**DIP — yes, selectively.** Depend on values handed in, not concretions reached
for. `GroundScenery.Scatter` is *told* its keep-outs rather than reading
`BUILDINGS` itself, which is what made it reusable at all. The sun is a value a
scene sets, not a `const` on a character class.

**LSP — yes, and there is a live violation.** The Galean Navy borrows
`GuardianShip` for its patrol behaviour, then **un-sets** its hull tint and its
rank afterwards. Two "undo what the base class did" lines is a subtype standing
where it is not substitutable. Tolerable today, flagged in code; the honest fix
is a Galean Confederacy faction with its own team, colours and standing rather
than a costume worn over the Guardians.

**OCP — no.** Open-for-extension usually buys indirection paid for on every read.
This project already has a *better* extension mechanism: **data**. `.tres`
resources, drop-in art resolved by filename, JSON cockpit layouts, authored
`rank`, ability tags. Adding class hierarchies on top would be a worse OCP than
the one we have.

**ISP — not applicable.** GDScript has no interfaces, and duck-typed `get()` on a
duck-typed node is how the engine already crosses those seams.

## 4. The uncomfortable part: most of our bugs are not architecture bugs

Sorting the recurring failures honestly, only one of them is fixed by
architecture:

| Bug shape | What actually fixes it |
|---|---|
| **One-sided logic** — a rule living where written and not where also needed | Single-sourcing. Already the house style. |
| **A correct helper nobody calls** | Tests that boot the real thing. |
| **Derived where it should be authored** | Measurement, then a design call. |
| **Unearned grants** — a free floor/default nobody bought | A design rule, enforced by test. |
| **Tests that assert nothing** | Coverage floors near the real total; sabotage. |
| **Shared mutable static read at the wrong time** | **Architecture — PlayerState.** |
| **One structure conflating two meanings** | Naming and modelling discipline. |

So: adopt the rules above, but do not expect a pattern to substitute for the two
things actually carrying quality here.

## 5. The two that actually carry quality

**Single-source the rule, never the copy.** Every one-sided-logic bug we have paid
for was a rule that existed in one place and was needed in two. When fixing one,
ask where *else* it is needed and move it, rather than patching the copy.
`Nameplate.attach` lives in `GroundCharacter.setup()` — the one place every ground
character is built — precisely so the next spawn site added cannot be the one that
silently has no plate.

**Test through the real thing, and prove the test can fail.**

- A helper that is correct and uncalled is a failure this project has already paid
  for more than once. `test_ranks_in_world` boots the actual flight scene and
  reads `rank` off the ships that are really out there, because "the helper is
  correct" and "the world got it" are different claims. It caught a wrong
  assumption on its first run.
- **Sabotage-verify every assertion, and assert the anchor matches exactly once.**
  A sabotage that lands in the wrong function proves nothing and reports ALL PASS.
- **A hand-maintained coverage floor is decoration unless it is near the real
  total.** `test_dock_ui` sat at `MIN_CHECKS = 90` while running 670, so a run that
  died four-fifths through still printed ALL PASS — and one did, at 139.
- **Look at it.** Twenty passing checks said the nameplates were fine; the
  screenshot showed four overlapping plates rendering "Scritt", a foot ring that
  read as a spiral, and two identical blue bars. None of that is expressible as an
  assertion you would think to write.
