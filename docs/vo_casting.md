# Voice / VO casting reference

How Bleakflame's spoken audio is generated. ElevenLabs is wired in as an MCP
server (`elevenlabs` in `~/.claude.json`, key in that config's env). Claude
generates VO on request; every clip bills the user's ElevenLabs account.

## Model + house style
- **Model:** `eleven_v3` (markedly better than v2 for these lines).
- **Pauses/emotion:** use v3 **audio tags** inline — `[sighs] [tired]
  [whispers] [laughs] [nervous] [exhales] [sarcastic] [gasps] [shouts]` all
  perform correctly on the TTS model. (The voice-*design* preview tool speaks
  tags literally — that is NOT the TTS model. Don't judge tags from previews.)
- Bare punctuation-only lines can occasionally glitch on v3; a tag or two
  stabilizes delivery. Tags go in the AUDIO only, never the on-screen text.
- VO = **quoted speech only**: stage-direction prose between the quotes is
  stripped (see `tools/dump_vo_manifest.gd`).

## File convention
- Drop-in at `res://audio/vo/<name>.(ogg|wav|mp3)` (`Sfx._find_audio`, mp3 OK).
- Callsigns: `audio/vo/callsign/<word>.mp3` (24, Chuck Miller).
- Campaign lines: `audio/vo/<stem>.mp3` where the DialoguePanel plays
  `<vo_prefix>_<nodekey>` (talk stages/bar) or an explicit node `vo`
  (`<quest>_briefing` / `<quest>_debrief`). Regenerate the manifest with
  `<godot> --headless --path . --script res://tools/dump_vo_manifest.gd`.

## Cast — permanent library voice IDs
| Role | Voice (library name) | voice_id |
|---|---|---|
| Comms / tutorial / callsigns | Chuck Miller | `HIGUfNOdjuWQwwapnTRW` |
| Ruel (Harbormaster) | Bleakflame — Ruel | `yVcyEVlQ79BQFNXUJOw1` |
| Voss (Underwriter) | Bleakflame — Voss | `mda2Jh9PZfrDwWUXu1Ih` |
| Odessa (Barkeep) | Bleakflame — Odessa | `HviFWoqOZWhmom64pHKb` |
| Lab Tech | Bleakflame — Lab Tech | `tkdie61JCSrCWTVQXfui` |
| The Counter (Hermit) | Bleakflame — The Counter | `GOcOeoGEFwcLOYegWNKH` |
| Krayt (Pirate) | Bleakflame — Krayt | `RFTOHxHDx0iW5zifjiaN` |
| Vyper (Krayt's successor) | Vyper | `Dn7kKIhWpyzsRO4seY5g` |
| Imari (Colony Elder) | Bleakflame — Imari | `75PBiQIpSB7d8JSNr8Un` |
| Doug Diggs (Prospector) | Bleakflame — Doug Diggs | `CjUJRqqdMPoyBzlAkM5U` |

Vyper's grief-comm memorial line is written (docs/progression_professions.md,
"Vyper's Truce") but the beat is POST-KRAYT / system-2 — generate her VO when
that content is built. Portrait: assets/portraits/vyper.png (drop-in; pending
frame pick). Imari CAST 2026-07-22 (colony elder; warm and weathered, sharp in an emergency)
once the landing content gave her lines to say.

## Approach VO (2026-07-22)
Docking and landing had no VO at all — these are the lines a new pilot hears
when they get it wrong, so they matter more than most:
| Cue file | Speaker | When |
|---|---|---|
| `dock_scrape_start` | Ruel | first scraped berth, ever |
| `dock_crash_start` | Ruel | first wreck, before the crash beat |
| `landing_brief_start` | Imari | approaching the planet, first time |
| `land_hard_start` | Imari | first hard set-down |
| `land_crater_start` | Imari | first crater, before the descent beat |

Each records only the INVARIANT text. The fault sentence ("coming in too hot" /
"crooked to the lane") is chosen at runtime from the actual mistake, so voicing
it would need one take per fault AND could contradict the words on screen.

TUTOR PINGS ARE DELIBERATELY SILENT (they keep their chime). They are
impersonal UI text with no speaker — "press [B] to manage cargo" is not
something a character says, and voicing it would either miscast an NPC or
invent a narrator this game does not have.

## Doug Diggs — The Dig (2026-07-22)
Cast when his freighter gave him lines. He is the game's MINING TEACHER, so
leaving him silent would have muted the only explanation of cutters and surveys.
Five nodes, all recorded: `doug_deck_start` / `_how` / `_worth` / `_why` / `_who`.

## Pipeline to make a bespoke NPC voice
1. `text_to_voice(voice_description, text=<signature line>)` → 3 preview
   variations (generated_voice_ids).
2. User picks one → `create_voice_from_preview(generated_voice_id, name,
   description)` → permanent library voice_id (record it above).
3. Generate lines with `text_to_speech(text, voice_id, model_id="eleven_v3")`.
