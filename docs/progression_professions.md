# Progression — Professions & Factions

User design 2026-07-19, with proposals marked [P]. This is the pilot
progression system: consumes the XP that has banked in Wallet.xp since
the early builds.

## LOCKED MODEL (2026-07-20) — foundation built + tested

Refined with user; skill points and professions are deliberately MINGLED.

- **Levels** derive from banked `Wallet.xp` (retroactive), cap **60**. Curve
  `Pilot.xp_for_level(L) = 50 * (L-1)^1.6` (tunable).
- **Skill points**: 1 per **4 levels** → **15** at cap. "Enough to differentiate,
  not to buy a whole profession."
- **Per-level combat growth** (hull/armor/shield/damage) scaled by the
  profession's COMBAT TIER: 2% Guardian/Privateer, 1.5% Miner/Scout, 1%
  Trader/Science; **1% baseline before any commission** (+120% for a combat pro
  at 60 — the long-game power curve).
- **Non-combat professions** get an exclusive **per-level perk** (0.5%/level,
  **30% at cap**): Trader = buy/sell discount, Scout = scan value, Miner =
  mining yield, Science = Insight. Combat pros spend their tier on raw combat.
- **7 skills**: Gunnery/Piloting/Evasion/Hull Discipline/Shield Tuning/
  Prospecting/Salvage. **Base cap 2** for all; a **profession raises the caps**
  on its favoured skills (4–5) — the specialisation gate.
- **Evasion = smaller hit PROFILE** (deterministic; incoming fire × effective
  hit_radius by 1−evasion), NOT RNG dodge — fits aim-by-flying.
- **Faction bones**: standing → INVITATION → accept (`Pilot.join_profession`).
  Minimal — just enough to be offered and take a commission. Full rep later.
- **Signature actives** per profession on the [1]–[5] Bus — v1 BUILT 2026-07-21
  (six module actives; see the QUARTERMASTER section below). Higher-tier
  abilities, profession weapons/shields, and the multi-tag grade ladder: future.

Leaders (built cast): Guardian=Ruel, Science=Dex(lab), Scout=Sella,
Trader=Imari, Miner=Doug, Privateer=Krayt(post-campaign).

CODE (built; `tools/test_progression.gd` ALL PASS): `scripts/skills.gd`,
`scripts/professions.gd`, `Pilot.*` (level / skill / cap / combat mults / perks
/ save-load). NEXT: wire combat mults into ShipStats (PLAYER ship only, not AI)
+ evasion into Projectile + skills into their seams; a Progression UI to spend
points; standing tracking + the Guardian invitation beat.


## PROFESSION MODULE PALETTE + ROLE MATRIX (2026-07-20, user-designed)

Activatable modules live on the [1]–[5] ABILITY GEMS (scripts/abilities.gd,
Pilot.gems — memorize at dock). A profession-locked SystemDef (`profession_lock`
field) gates its signature; the Armory refuses to fit it without the commission
(visibly, via `_fit_error`). Adding one = a `.tres` + an `Abilities.LIST` entry
+ a dispatch arm in `ship._activate_gem()` + (where sensible) an AI trigger.

**VENDOR RULE (2026-07-20, user):** profession modules are NOT open-market —
you buy them from the LEADER who invented/mastered the trick, not the station
Armory. Doug sells the Crystalline Array (he worked out the crystal lattice),
Vyper sells cloak, Ruel sells Bulwark, etc. Each leader = the QUARTERMASTER for
their profession's gear (a per-faction shop, reached via that NPC once
commissioned). BUILT (2026-07-21): the Quartermaster lives in the Pilot dock tab
— when you hold a commission it stocks `Professions.wares(Pilot.profession)` with
buy buttons (`_buy_component` → hold); fitting is gated by `SystemDef.profession_lock`
(dock `_fit_error` refuses otherwise, visibly). Full loop: earn standing → Accept
the commission → Quartermaster buy → fit in a System slot → book knows it (module
tag) → memorize onto a [1]-[5] gem → fire. v1 signatures (system-1): Guardian
Bulwark, Privateer Decoy Flare, Science Repair Field, Miner Tangle Shot, Scout
Micro-Warp, Trader Blackout (data/components/systems/*.tres). GRADE LADDER: a
higher-grade module carries MULTIPLE tags → knows multiple abilities from one
slot (20 known vs 5 Bus slots = the loadout tension; no new code).

**PARITY RULE:** every profession module ships with an AI-usable version where
it makes sense — the palette arms BOTH sides. Enemy uses must be TELEGRAPHED and
counterable (a cloaker shimmers + briefly decloaks when it fires). Encountering
an ability foreshadows a commission you could take.

**SYSTEM TIERING (2026-07-20, user):** CLOAK + CLOAKED RAIDERS are **SYSTEM 2**
content, NOT system 1 (Krayt dies at the system-1 finale; the Privateer path via
Vyper opens after the gate). In SYSTEM 1 the Privateer signature is **Decoy
Flare** (drop aggro + decoy soaks fire). The cloak *framework* is already built
(profession_lock + active-ability runtime + is_hidden/set_veil + effect, all
verified) — it's reusable groundwork; it just doesn't surface as system-1
content. Decoy Flare is the system-1 module still to build.

Each profession has **two role affinities** (flex identity + coop synergy).
Roles: Defense / Damage / Control / DoT / Healing. DoT counts as damage, so
effective damage dealers = Guardian+Scout (burst) and Privateer+Miner (DoT).

| Profession | Roles | Signature (Mk I) | Grows into | AI counterpart |
|---|---|---|---|---|
| **Guardian** (Ruel) | Defense / Damage | **Bulwark Projector** — 5s damage-reduction field to self + all allies in radius; a blue field marks the zone and fades as it expires (the telegraph). Boss-burst / coop cooldown, no offense. | Point-Defense, Taunt Beacon | "anchor" brute pops a bulwark |
| **Privateer** (Vyper) | Control / DoT | **Decoy Flare** — drop aggro + launch a decoy that eats enemy fire briefly (misdirection). | **Cloak** (untargetable + drops locks; decloaks a beat on firing), Grapnel/Plunder, Ambush Burst | pirate ambushers decoy + cloak-pounce |
| **Miner** (Doug) | Defense / DoT+Control | **Crystalline Defense Array** — mining laser refracted through a crystal lattice into a point-defense screen: destroys ALL incoming missiles/ordnance in range, can't harm a hull. Cooldown active. DENIES a damage type (vs Guardian's soak). | Tangle Shot (snare+slow, holds a target off allies + pulls aggro = peel), corrosive DoT tool | a "driller" that lobs charges / nets |
| **Scout** (Sella) | Control / Damage | **Disruptor Ping** — jam ONE target's WEAPONS briefly (precise EW; distinct from Science's shield-EMP). | Slipstream (sustained boost), Blink/Warp-to-cursor, passives: attack-range, GROUP move-speed aura (coop) | scout jams your guns / lights you up for a pack |
| **Trader** (Imari) | Healing / Defense | **Blackout** — brief untargetable panic-vanish on a cooldown (no decoy, no offense; distinct from cloak). | Bribe Jettison (dump cheap cargo to peel pursuers), Emergency Thrust, defensive gear | escorts/haulers pop flares |
| **Science** (Dex) | Healing / Control | **Repair Field** (hull/armor regen to self/allies — HEALING is Science's, Guardian only mitigates) + **Overload Pulse** (EMP knocks SHIELDS offline). | Weak-Point Analyzer (scan → bonus damage vs it), Stasis Tractor | tech enemy EMPs your shields before a pounce |

**Krayt DIES** (devoured by Cinderweb on-comm at the campaign climax — the beat
that opens the gate). Privateer commission passes to his second, **Vyper**, who
inherits the leaderless Rust Shoal crew; the player's on-ramp is grief/legacy
(you were on-comm when Krayt was eaten). Vyper confirmed clear of the callsign
pool. `Privateer=Vyper` supersedes `Krayt(post-campaign)` above.

**Framework needed (cloak forces both):** (1) a generic ACTIVE-ABILITY RUNTIME
— cooldown + optional duration + gem-HUD state (charging/active/CD); (2)
`profession_lock` on SystemDef + an Armory fit-gate. After cloak, each module ≈
data + dispatch arm + AI trigger. BUILD ORDER: cloak end-to-end → Bulwark →
Overload Pulse (stretch the runtime most: ally-target + enemy-debuff) → rest.


## STANDING VERBS — how each commission is earned (2026-07-20, user + built)

Your PLAYSTYLE earns your commission: standing accrues from the activity that
IS that profession. Wired (each is a `Standing.add(faction, n)` at the verb's
natural site; INVITE_AT = 10):

| Faction | Verb | Site (built) |
|---|---|---|
| Guardian | kills + bounty/recovery contracts | flight_test._grant_kill_xp (+1); _on_turn_in bounty/recovery (+2) |
| Trader | delivery / commodity runs | _on_turn_in delivery (+2) |
| Science | turn in Scan Data to Dex | _on_trade_scan_data (+n/2) |
| Scout | chart a SECRET POI in flight | flight_test discovery (+3) |
| Miner | sell ore at market | _on_sell_commodity `*_ore` (+1/unit) |
| Privateer | ROB neutral NPC traders | NOT BUILT — the piracy loop (below) |

**PRIVATEER = the piracy fork (design, NOT built).** New NEUTRAL trader AIShips
patrol authored lanes (planet↔station, station↔gate; world-anchored like the
pirate patrols). They're DUAL-PURPOSE: DEFEND them from pirates → Guardian rep;
ROB them → Privateer rep. Robbing one should COST Guardian standing and flip the
guard-wing hostile to you (the lawful/outlaw fork has teeth). Plunder = their
actual cargo commodities + a contraband turn-in token; fence at the Shoal or
turn in for Privateer standing. Privateer stays a SYSTEM-2 commission (Vyper,
post-Krayt) but the rep can build in system 1. This is the next content feature.

Contracts should carry a `standing: {faction, n}` reward field (data-driven) as
they grow; new templates to add: Miner "recover N \<ore\>", Science "data run",
Scout "survey X". The passive verb hooks above already light up the invites with
existing gameplay.


## GOING DARK (2026-07-21, user-designed) — in-space gem-swap + future "meditate"

The answer to "can you change your gem loadout in space?" — YES, but only by
GOING DARK: cut everything and sit vulnerable. It's a real tactical decision,
never free.

While dark:
- **All systems offline.** Engines cut (drift only), SHIELDS OFFLINE, sensors
  offline. The screen goes BLACK except the UI — you see nothing (no radar, no
  world). You're blind; you'll know you're being hit (damage/alert) but little
  else.
- **Less visible, NOT cloaked.** Your sensor signature drops so AI acquires you
  later / at shorter range — but anything within SIGHT range still sees you.
- **You can change your GEMS** (re-memorize abilities) — the whole point.
- **Systems recharge faster** ("meditation"). When an ENERGY/mana system lands
  later, Going Dark is the emergency regen, and a Science/monk-style MEDITATE
  skill grows from this exact mechanic.
- **Reboot takes a few seconds** — you can't instantly un-dark, so bailing out
  of dark mid-fight is slow. Going dark in combat is only wise with allies
  covering you and a REAL need (swap to a critical ability, or emergency regen).

So gem loadout is gated to **docked OR Going Dark** (never freely mid-flight).
BUILT v1 (2026-07-21, [K] in flight, scenes/ui/going_dark.gd + ship.gd dark
state): black-screen blind (overlay covers HUD/world), engines cut → drift,
shields offline (no absorb), sensors off (target drops), the Bus re-flash panel
(slot + ability book), hull/armor emergency mend (DARK_REGEN 14/s), signature
drop (AIShip._prey_valid reach ×0.4 for is_dark ships — distant hunters lose you,
close ones don't), and a REBOOT_TIME 2.6s lockout on exit. Ties to the ABILITY
GEMS ([[progression-system-next]]). Future polish: energy/mana regen when that
system lands (the "meditate" seam), and folding the Bus panel into the [U] menu.


## FACTION REPUTATION SYSTEM (2026-07-21, user-designed — the piracy backbone)

Being built as the spine of the piracy features. Combat-relevant factions carry
a STANDING (scripts/standing.gd) + a PEACE state; the economic guilds still use
standing for commissions.

**Combat/peace factions:** GUARDIANS (lawful, Ruel), RUST SHOAL / PRIVATEERS
(outlaw, Vyper post-Krayt), TRADERS (Trader guild, Imari — see below).

**TRADERS are the Trader guild's civilians (decided 2026-07-21), NOT anonymous
neutrals.** They fly Imari's haulers on the lanes (scenes/flight/trader_ship.gd,
group "traders", faction id "trader"). Reasons: the profession/economic factions
come ALIVE in the world; it plugs straight into the peace toggle; and robbing
them makes the right web of consequences. A Trader-commissioned player has allied
haulers on the lane. NOT their own war — they're protected CIVILIANS; the combat
axis is Guardian(lawful) vs Privateer(outlaw), and traders ride the lawful peace.

**PEACE TOGGLE (per faction, user's key idea):** a checkbox per faction. Peace
ON = that faction's ships are friendly and UNTARGETABLE; peace OFF = you can
target/attack them. This is HOW piracy is declared — flipping peace-off with
Traders moves their haulers into your targetable set (solves the group-targeting
problem cleanly; no per-shot fat-fingering into outlaw). You CANNOT enable peace
while KoS to a faction (they shoot regardless); once they'll no longer kill you,
the toggle unlocks. Faction-wide, not per-target — piracy is a lifestyle, not a
one-off mugging.

**Consequence web of robbing a trader:** Trader standing ↓ (betrayed Imari —
bars the Trader commission), Guardian standing ↓ (lawful enforcement — they
protect the lanes; witnesses turn the guard-wing on you), Privateer standing ↑.
DEFENDING a trader from pirates raises Guardian + Trader standing (the
dual-purpose — one entity feeds both sides).

**OUTLAW LOCKOUT:** deep enough Guardian-standing loss → KoS with Guardians →
**station docking DENIED** (they hold it); you must dock at the RUST SHOAL
instead (the outlaw haven — make the den dockable). Redeem to regain the station.

**ASYMMETRIC REDEMPTION:** mending burned standing is SLOWER than losing it, so
you can NEVER be fully allied with both Guardians and Privateers at once — the
fork always holds. Redemption happens via a MEDIATOR at a neutral hub: the
HERMIT (planet-side) will help you mend fences with either faction for
credits / tasks, slowly.

**CAMPAIGN-DYNAMIC PIRATE HOSTILITY:** after Krayt dies (campaign end), the Rust
Shoal pirates go NEUTRAL toward you under Vyper (ambient attacks stop) — UNLESS
you keep taking anti-pirate missions, which flips them hostile again (and lowers
Privateer standing). Pirate hostility is standing/campaign-driven, not hardcoded.
Also: the SHOAL MOVES FARTHER OUT (a real journey; it's the outlaw home base).

**Faction STATE = f(standing, peace):** Allied (peace on, high) → Neutral (peace
on, mid) → At-war/Hostile (peace off, or low standing they attack) → KoS
(rock-bottom: attack on sight, peace locked, docking denied). The peace toggle
flips group membership (into/out of the player's targetable set).

**VYPER'S TRUCE — the neutral path (2026-07-21, user; supersedes the earlier
"menu pact"):** NOT a choice the player clicks — it JUST HAPPENS when Krayt
dies. Because of how the player carried him (the parley, his last words), Vyper
extends a grief-and-respect banner: she tells her gang the player is OFF LIMITS.
Ambient pirate aggression toward the player switches OFF at Krayt's death (the
same "post-Krayt pirates go neutral" beat). It is CONDITIONAL ON HONOR:
  • HONOR it (leave the pirates be) and she holds it — you stay neutral with the
    Shoal indefinitely; pair that with not pirating traders and you're the free
    economic/explorer pilot, at uneasy truce with BOTH sides, never KoS to
    either. This is the "neutral path" — you simply never pursue Guardian or
    Privateer.
  • BREAK it (attack the pirates / the Shoal — "soak it in her blood") and she
    revokes it: the Shoal turns hostile again and hunts you (the Guardian/lawman
    war path). Likewise, pirating traders is the Privateer path.
So the three post-Krayt doors are EMERGENT from behavior, not a menu: honor the
truce (neutral) · hunt the pirates (Guardian) · rob the lane (Privateer).
Vyper's comm at the death (draft, user-seeded): a THANKS + a MEMORIAL to Krayt,
then the banner —
  "He— we're not bad people. Not really." A breath. "There's just... nobody out
  here to look out for us. So we look out for each other, and we do what we have
  to, to survive." Her voice thins. "I'll miss him. Every day. Closest thing to
  family this crew had." A pause — steadier, harder. "You could've left him to
  it. You didn't. My gang knows your colors now: you're off our guns, long as
  you keep us off yours. Honor that, and I'll hold it. Soak it in his blood and
  I'll shed yours. ...Thank you, pilot." MECHANISM: a post-Krayt `truce` state
(reuses the parley/`_prey_valid` player-exclusion + the peace/standing system) —
pirates skip the player as prey while the truce holds; the player attacking a
pirate breaks it. NOT built yet — it's a POST-KRAYT / continued-play feature
(the current demo ends at the gate right after his death), so it lands with
system 2 / persistent post-gate play.

BUILD PHASING: Phase 1 = neutral trader traffic (DONE — trader_ship.gd + lane
spawns). Phase 2 = the faction-state machine + peace toggle + robbing
consequences (this section's core). Phase 3 = outlaw lockout + Shoal-as-dock +
hermit redemption + campaign-dynamic pirate neutrality + move the Shoal.


## THE RUST SHOAL AS OUTLAW HAVEN — the "SPEAK'S EASY" (2026-07-21, user)

The Shoal becomes a DOCKABLE haven — the outlaw's home when the station is closed
to them. Its social deck is the **SPEAK'S EASY** (a speakeasy AND "speak easy" —
the Shoal's answer to Ember Row: grey-market talk, the FENCE, and later Vyper's
Privateer gear + repairs). But a hostile den can't be docked while its guns
blaze, so access is TWO-TIERED:

**ACCESS (can dock + safe passage — pirates hold fire):**
- FIRST reached via KRAYT'S INVITATION, handed to you by the HERMIT (the_hermit
  quest reward). The campaign puts you there — you don't grind for the door.
- The rust_shoal beat then becomes LAND-AND-TALK at the Shoal (you dock and meet
  Krayt IN PERSON, not a comm-hail) — so his death right after (nothing_left_
  behind) is personal: you'd shaken his hand at his own table.
- Later also opened by: high Privateer standing (you've proven yourself), the
  post-Krayt Vyper truce, or a Privateer commission. Reuses the parley/
  `_prey_valid` player-exclusion, gated on invitation/standing/truce.

**SERVICES (what the Shoal actually DOES for you) — gated on Privateer standing:**
- At 0 faction (just invited): safe landing + the Krayt meeting, and not much
  else. Non-contraband shopping is pointless (station/planet already sell it),
  so skip it — the Shoal only matters once you're TRUSTED.
- As Privateer standing climbs (Friendly → Allied): the Speak's Easy opens — the
  FENCE (stolen_goods → credits + Privateer standing), contraband, and Vyper's
  Privateer-locked gear (cloak, etc. — the faction quartermaster).

Timing elegance: a committed pirate crosses into Privateer-Friendly right about
when they hit KoS-Guardian (rob = +8 Privateer / -50 Guardian) — so the station
slams shut exactly as the Shoal opens up. The fork's endgame.

BUILT 2026-07-21 (import + both tests + boot clean): ShoalPad (scenes/flight/
shoal_pad.gd, extends DockingPad, gate = Standing.shoal_open() instead of the
station's KoS-guardian lockout) on PirateDen.pad; SpeakEasy deck (scenes/ui/
speak_easy.gd, bespoke minimal CanvasLayer — repairs+save ride ship.dock() free;
FENCE stolen_goods→credits+Privateer gated on Standing.shoal_trusted()); Pilot.
shoal_invited (persisted) granted when rust_shoal starts (quest "grants_shoal");
Standing.shoal_open()=access (invited OR privateer≥FRIENDLY_AT) / shoal_trusted()
=services (privateer≥FRIENDLY_AT); SAFE PASSAGE (AIShip._prey_valid + den turrets
skip the player when shoal_open — the den's player_team guns only, station guns
still shoot outlaws); ship.dock skips Research/Quests.on_dock for a ShoalPad
(lawless — no calendar/board); flight_test captures `shoal`, adds `shoal_screen`,
exact-instance `== station.pad`/`== shoal.pad` toggles (ShoalPad IS a DockingPad),
E-dock elif. LAND-AND-MEET-KRAYT DONE 2026-07-21: rust_shoal goto has `in_person:true` →
flight_test._tick_goto_dialogue skips the proximity comm (still sets the truce),
and SpeakEasy._present_krayt_if_due presents Krayt's dialogue ON DOCK at his own
table (advance_goto_dialogue on close, same flow — next beat opens on the next
dock home). His death (nothing_left_behind) still comes as his last comm, but now
you'd MET him. VYPER'S QUARTERMASTER BUILT (2026-07-21, speak_easy.gd
_refresh_quartermaster/_on_buy_install): the Shoal SELLS AND INSTALLS Privateer
wares (Professions.wares("privateer")) — the one place a KoS pilot, locked out
of the station's Engineering, can get gear AND have it fitted (buy → bolted into
a free System slot, mark + profession_lock enforced; Going Dark memorizes it to
a gem in flight). Shown only to a commissioned Privateer, else pointed at the
commission. Closes the outlaw gear loop self-contained at the Shoal. STILL TODO
(drop-in): art for the den/pad.


## Core (user-decided)

- **No pick at start.** Professions are EARNED by building trust with NPC
  faction leaders, who serve as trainer / mission giver / respect agent /
  quartermaster.
- At a faction's trust threshold, they INVITE you to become one of:
  **Guardian / Science Officer / Scout / Trader / Miner / Privateer**.
- Joining opens PROFESSION LEVELS, which unlock:
  - **Skill bonuses** — small, raw, fun, QoL: gunnery (better arcs with a
    weapon type), piloting (turn rate), hull efficiency (storage), shield
    efficiency (recharge), etc.
  - **Trait lines** — spec trees, points spent per level: ACTIVE
    abilities, special maneuvers, and major bonuses you must spec into.
- Each profession has unique abilities, ships, gear, and missions.

## Faction leaders (mapped to the existing cast)

| Profession | Leader / agent | Trust verbs (ALREADY TRACKED) |
|---|---|---|
| Guardian | Harbormaster Ruel | lane/bounty kills, defense contracts |
| Science Officer | Research Lab | scan data turned in, artifacts, surveys |
| Scout | The Counter [P] | POIs discovered, distance flown dark |
| Trader | Odessa [P] | deliveries, trade profit, route runs |
| Miner | prospector guild (new face needed) | ore sold, rocks surveyed |
| Privateer | Krayt / post-campaign Shoal [P] | recoveries, salvage, grey work |

Post-campaign Shoal as Privateer HQ = long-game hook: a profession the
campaign has to UNLOCK. The guard wing (blue, white stripe) is the
Guardian fiction already flying.

## Proposals [P] — confirm before build

- **One ACTIVE COMMISSION at a time**, switched at dock. Earned passive
  skills persist across commissions forever; the active commission gates
  trait actives, profession missions, and quartermaster stock.
- **Actives live on the systems-engagement keys [1]-[5]** — same grammar
  as the scanner: select target (where relevant), press key. Hardware
  modules and trained abilities compete for the same five buttons; "what
  are my five keys" becomes the loadout question.
- **Retroactive standing**: compute initial trust from stats the game has
  been tracking (kills, scan data, ore, deliveries, discoveries) — the
  Wallet.xp trick again. Veterans dock into respect.
- **Standing is visible pre-invitation** ("Ruel is watching — 6/10") so
  progression is felt from hour one. The INVITATION is a celebrated beat:
  letter at dock, journal entry, full-screen portrait moment.
- **Bespoke grade (gold) = commission gear.** Quartermasters sell
  profession-locked Bespoke hulls/components. Shop sells clean, salvage
  rolls hot, Bespoke is EARNED — the grade ladder finally uses its gold
  rung.
- **Domain split vs Research**: Insight/tech trees = station KNOWLEDGE
  (recipes, charting, lab passives). Profession skills = PILOT ability
  (handling, arcs, efficiency). Traits = ACTIVES. No double-granting.
- **Profession missions ride the Quests framework** (stage kinds mostly
  exist; add kinds per need).

## Build phasing [P]

1. Faction standing tracking (+ retroactive seed) + visible meters +
   GUARDIAN end-to-end: invitation quest, small skill line, first trait
   active, a few defense missions, quartermaster stub.
2. Miner + Science Officer (trust verbs fully tracked already).
3. Trader, Scout, Privateer (Privateer waits on campaign beat 7).

## Open questions

- Level curve + points per level; respec policy (recommend: cheap respec
  of TRAIT points at the trainer, skills permanent).
- Does death touch progression? (Recommend: never — death already costs
  cargo.)
- Profession-unique SHIPS: quartermaster-sold hulls vs livery variants of
  existing hulls first (cheaper: guardian Kestrel skin exists).
- Miner guild + Scout need named faces (cast additions).

## SCHEDULED PASS — Trader profession + dynamic economy (2026-07-20)

Deferred from demo polish on purpose: fixed prices are more legible for the
friends-and-family demo, and this depth pays off with the Trader profession
(Elder Imari's guild seed) and multiple markets/systems. Verdict from the
design chat: GOOD design (Elite/X/EVE-proven), do it — but with guardrails.

Do a LIGHT, self-correcting version, NOT a full commodity sim:
- **Keep the production baseline.** Current fixed prices (TradeGoods, incl.
  the 2026-07-20 import premiums: station sells food 24/water 16, colony
  sells circuits 40) become the BASELINES that supply/demand modulate
  around. Do NOT go fully fungible — the buy-where-made/sell-where-wanted
  route fiction must survive.
- **Supply drives price**: as a good's local stock drops, its price rises;
  buying heavily in a region drives prices up (player can move markets).
- **Guardrails (the whole difference between depth and a trap):**
  - price BANDS (min/max) so nothing spirals;
  - DIMINISHING RETURNS per trade (each unit nudges price; big trades move
    it more) — kills infinite single-route arbitrage, self-corrects;
  - SLOW RECOVERY toward baseline over game-days/docks (markets heal — vital
    for coop so one player can't permanently wreck the economy);
  - RARE goods = small stock, slow replenish.
- **Legibility**: show stock counts + a visibly-moving price (trend arrow).
- **Skill seam ALREADY IN CODE**: Pilot.trade_buy_mult()/trade_sell_mult()
  (return 1.0 today) — the Trader profession fills these; market prices in
  dock_screen already route through them. "Small degree" per user.
- **Coop**: market state must be HOST-AUTHORITATIVE (WorldState) — one
  player's trades affect the shared economy; recovery prevents griefing.

Sequence: with the Trader profession (phase 3), not before the demo.
