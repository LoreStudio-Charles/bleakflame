class_name Keys
## EVERY BINDING IN THE GAME, in one place.
##
## WHY (user, 2026-07-25): bindings were raw `KEY_*` literals scattered across ~15 files,
## so a hotkey pass meant hunting every site and a rebinding screen was impossible. They
## are still checked as raw InputEvents at the call sites — deliberately, because an open
## editor clobbers InputMap additions to project.godot (long-standing project rule) — but
## the VALUES live here. Change a key once; every screen follows.
##
## THE SCHEME (user, 2026-07-25). Two modes, ONE muscle memory: a key does the analogous
## thing in space and on the ground.
##
##   MOUSE
##     LMB  SELECT. Always, everywhere — in menus, on inventory tiles, AND out in the
##          world, where it targets whatever you click (hostile, ally, rock) WITHOUT
##          arming anything. It never fires, spends or destroys. That is why there is no
##          ally-cycle key: you just click the ally.
##     RMB  SOFT INTERACT — **TARGET-AWARE**: it acts on the THING you clicked, and what
##          it does follows from what that thing is. Examine scenery, TARGET+ENGAGE a
##          hostile, buy/sell/jettison an item in a panel. One gesture, read off the noun.
##   THE TWO ANSWERS
##     E    **CONTEXT-AWARE**: activate the place you are STANDING AT — dock, door,
##          terminal, the NPC you walked up to. Also yes/confirm in menus.
##          (So: RMB asks "what is that?", E asks "what am I at?")
##     Q    No / cancel / dismiss — and in the world, the WEAPONS-FREE toggle.
##   COMBAT (see the combat overhaul: guns are a STATE, ordnance is a VERB)
##     Q    toggle weapons-free (energy guns; costs no ammo)
##     R    launch ordnance (consumes ammo). A second ordnance slot is planned later.
##     TAB  cycle foe (allies need no cycle key — LMB targets them directly)
##     1-5  abilities (a distinct set per mode)
##   SHARED VERBS (space | ground)
##     SHIFT  boost | sprint          SPACE  brake | kneel-cover
##
## Space/ground differences are the HOST's business, not this table's: the same key is
## listed once and each mode does its own thing with it.

# ---- MOUSE ----
const SELECT := MOUSE_BUTTON_LEFT
const INTERACT_AT_CURSOR := MOUSE_BUTTON_RIGHT

# ---- THE TWO ANSWERS ----
const CONFIRM := KEY_E          # yes / accept / interact with what you're at
const CANCEL := KEY_Q           # no / dismiss — doubles as weapons-free in the world

# ---- COMBAT ----
const WEAPONS_FREE := KEY_Q     # toggle auto-fire (same key as CANCEL; context decides)
const ORDNANCE := KEY_R         # launch ordnance / throw grenade
## TAB cycles hostiles — the MMO idiom, and it freed T.
const CYCLE_FOE := KEY_TAB
## NO ALLY-CYCLE KEY (user, 2026-07-25). Y is retired because LEFT-CLICK targets anything,
## ally included — that IS the answer, not a workaround. LMB never arms, so clicking a
## friendly to Mend them can't open fire. Also reachable: a row in the friendlies roster
## (top-right) and F1-F4 for the party.
## Ability bus. Index = keycode - ABILITY_1.
const ABILITY_1 := KEY_1
const ABILITY_COUNT := 5

# ---- MOVEMENT (shared verbs, different meaning per mode) ----
const BOOST := KEY_SHIFT        # boost | sprint
const BRAKE := KEY_SPACE        # brake | kneel-cover

# ---- TARGET FRAMES ----
## Self, then party members 2-4. F-KEYS ARE A KNOWN HAZARD while debugging (the editor
## owns several), which is why dev tools were moved OFF them — these are PLAYER binds and
## ship in the export, so they stay, but never put a dev action back on an F-key.
const TARGET_SELF := KEY_F1
const TARGET_PARTY_2 := KEY_F2
const TARGET_PARTY_3 := KEY_F3
const TARGET_PARTY_4 := KEY_F4

# ---- OVERLAYS ----
const MAP := KEY_M              # ground -> system -> galaxy -> universe (RMB out, click in)
const HOLD := KEY_H             # the SHIP's cargo hold
const BAGS := KEY_B             # the PILOT's personal bags
const DOSSIER := KEY_P          # pilot + ship sheet
## SOCIAL IS [O]. FACTIONS IS [U]. NOTHING IS ON [I].
##
## Settled 2026-07-28 by the user, after this line had been rewritten wrongly three
## times: "Social should be O. That one never was I. Factions were U, then I, then back
## to U. Nothing should be I yet."
##
## SO [I] IS DELIBERATELY UNBOUND — that is the fact worth keeping, because every wrong
## version of this comment reached for it as a free letter and then invented a reason.
## A phone autocorrect started it; two later "corrections" each moved the wrong one of
## the pair. If a future screen wants a key, [I] is available and its emptiness is
## intentional, not an oversight to be tidied up.
const SOCIAL := KEY_O           # reserved — not built yet
const FACTIONS := KEY_U
const DARK := KEY_K             # going dark | meditate
const LOG := KEY_L              # captain's log: quests + objectives
const COMMS := KEY_C            # archive of past transmissions

# ---- SYSTEM ----
const COMM_TERMINAL := KEY_ENTER
const COMM_TERMINAL_ALT := KEY_KP_ENTER
const COMMAND := KEY_SLASH
const MENU := KEY_ESCAPE
const SCREENSHOT := KEY_F12


## Is this ability keycode one of the bus slots? Returns its INDEX, or -1.
static func ability_index(keycode: int) -> int:
	var i := keycode - ABILITY_1
	return i if i >= 0 and i < ABILITY_COUNT else -1


## The inverse — which key fires bus slot `i`. The ground POLLS its input (so it works
## identically inside flight_test's SubViewport, where raw event routing is unreliable),
## and a poll needs the keycode, not the index.
static func ability_key(i: int) -> int:
	return ABILITY_1 + i if i >= 0 and i < ABILITY_COUNT else 0


## Party-frame index for a target key (0 = self), or -1.
static func party_index(keycode: int) -> int:
	match keycode:
		TARGET_SELF: return 0
		TARGET_PARTY_2: return 1
		TARGET_PARTY_3: return 2
		TARGET_PARTY_4: return 3
	return -1


## Human-readable name, for HUD prompts and the tutor — so copy never hardcodes a letter
## that a rebind would make a lie.
## ---- COPY THAT CANNOT GO STALE ----
##
## Player-facing text NEVER hardcodes a letter (user, 2026-07-25). Tutorial copy writes
## a TOKEN — "press {DOSSIER}" — and `expand()` turns it into "press [P]" using the
## binding that is actually live. Rebind the key and every lesson, prompt and caption
## re-words itself; hardcoded letters would quietly become lies the day a rebind UI
## ships, and there is no way to grep for a lie.
##
## Add a binding here the moment you add it above, or the token renders as itself —
## visible nonsense, which is the failure mode we want (loud, not silent).
const TOKENS := {
	"CONFIRM": CONFIRM, "CANCEL": CANCEL, "WEAPONS_FREE": WEAPONS_FREE,
	"ORDNANCE": ORDNANCE, "CYCLE_FOE": CYCLE_FOE, "BOOST": BOOST, "BRAKE": BRAKE,
	"MAP": MAP, "HOLD": HOLD, "BAGS": BAGS, "DOSSIER": DOSSIER, "FACTIONS": FACTIONS,
	"SOCIAL": SOCIAL, "DARK": DARK, "LOG": LOG, "COMMS": COMMS,
	"COMM_TERMINAL": COMM_TERMINAL, "COMMAND": COMMAND, "MENU": MENU,
	"SCREENSHOT": SCREENSHOT, "TARGET_SELF": TARGET_SELF,
}


## "[P]" for a token, ready to drop into a sentence. Unknown token -> "" so the caller
## can notice; expand() leaves the raw token in place instead, which shows up on screen.
static func label(token: String) -> String:
	if TOKENS.has(token):
		return "[%s]" % name_of(int(TOKENS[token]))
	match token:
		"SELECT": return "LEFT-CLICK"
		"INTERACT": return "RIGHT-CLICK"
		"ABILITIES": return "[%s]-[%s]" % [name_of(ABILITY_1), name_of(ABILITY_1 + ABILITY_COUNT - 1)]
		"MOVE": return "[WASD]"
	return ""


## Replace every {TOKEN} in `text` with its live binding.
static func expand(text: String) -> String:
	if not text.contains("{"):
		return text
	var out := text
	for token in TOKENS:
		out = out.replace("{%s}" % token, label(token))
	for token in ["SELECT", "INTERACT", "ABILITIES", "MOVE"]:
		out = out.replace("{%s}" % token, label(token))
	return out


static func name_of(keycode: int) -> String:
	match keycode:
		KEY_ENTER, KEY_KP_ENTER: return "ENTER"
		KEY_ESCAPE: return "Esc"
		KEY_SHIFT: return "SHIFT"
		KEY_SPACE: return "SPACE"
		KEY_SLASH: return "/"
	return OS.get_keycode_string(keycode)
