# ADR-045 — The Journal

**Status:** PROPOSED (2026-09-09). Built and probed; two clauses (§3 pause, §6 identity) await the
Summoner's ruling. Supersedes nothing. Amends nothing — it fills a hole the ADR set left open.

**Context.** Caleb delivered the art first: `assets/ui/journal/source_art/journal_sheet_caleb.png`
(1536×1024) — a closed olive cover inked "B.Co 2/42", an open ruled spread with a coffee ring, five
blank index tabs, a pencil stub, a paperclip, a rubber band, a folded 1:50,000 topo, a K-ration
carton scrap, a letter home, and a **DA Form 20**. His brief: *"a journal that the player opens that
has the inventory, quests, mission information, and the log of combat messages… as well as
integrating the map into this. and there would be selectable tabs on the right side of the journal,
as it will appear in the upper left side of the screen when opened."*

The problem underneath it is measured, not aesthetic. **Every player-facing line in this game is
fire-and-forget.** `MissionHUD.show_toast()` (`scripts/ui/mission_hud.gd:362`) builds a Label, holds
it 3.5 s, fades it 1.0 s and frees it. Nothing buffers it. A grep for `event_log`, `hud_message`,
`ring_buffer` and `chatter` across `scripts/` returns zero. In a firefight — which is when almost
every line fires — the player is looking at a treeline, not the top of the screen, and the line is
gone. The toast bus is also **radio-gated**: `_radio_check()` (`field_director.gd:814-821`) returns
"NO RADIO — YOUR RADIO MAN IS DOWN" in place of the fire-support line, so some information is never
generated at all. What DOES get said must therefore survive being said.

---

## 1 · The five tabs are his five, and no sixth

`GEAR · ORDERS · MISSION · LOG · MAP`, top to bottom, five index tabs matching his five blank tabs.
The DA Form 20 is **not** a sixth tab: it is a loose sheet paperclipped onto the left page of
MISSION, which is what a personnel qualification record physically was.

## 2 · THE LOG IS THE POINT

`scripts/ui/field_log.gd` — a 240-entry static ring, stamped `D<day> HHMM` off `SimClock`, with
identical consecutive lines collapsing to `xN` inside a 20 s window.

**The capture point is the RENDERER, not the signal.** `FieldDirector.toast`
(`field_director.gd:7`) carries ~90% of player text, but `player.gd:342 _field_toast()`,
`weapon_holder.gd:1029 _hud_toast()`, `hud.gd:308` and `tree_cover_layer.gd:249` all reach
`MissionHUD.show_toast()` by **group lookup** and never touch the signal. Hooking the signal would
have silently dropped ~45 player call sites including every weapon jam and the downed message.
`show_toast()` is the only total-capture point in the game. *(This is a bug class, not a one-off:
a signal is not a channel when four systems bypass it.)*

The log is a **mission artefact, not a career one** — `FieldLog.clear()` runs in
`MissionHUD.setup()`. It is not saved. A tour-persistent log is a separate decision.

## 3 · IT DOES NOT PAUSE

Ruled by precedent, not by preference. `topo_map.gd:106-109` records the Summoner's 2026-07-28
ruling on the map sheet — *"NO full-screen dim. The world does not pause while the sheet is up… the
sheet is a HELD OBJECT, not a screen"* — and ADR-037 §2 ratified it. The journal is the same class
of object and his own placement says so: **upper-left, partial screen.** A screen that pauses is
centred and fills the frame. One that does not is held off to one side so you can still see the
treeline over the top of it.

**The cost, named:** the mouse is released so the tabs can be thumbed, so while the journal is open
the player cannot aim. That is the price of reading it, and it is a real one — this is a hardcore
game and standing in the weeds reading your notebook should be able to kill you (Pillar 1, Pillar 5).
It follows the topo sheet's exact idiom: save and restore the prior mouse mode, set
`GameManager.is_in_menu` (which is what stops LMB on the page from firing the rifle), and clear that
flag in `_exit_tree()`.

**Open for his ruling:** if he wants it to pause, it is a three-line change and this clause is
struck. He should read it in play first.

## 4 · ONE MAP, AND THE JOURNAL'S COPY IS READ-ONLY

There is a complete, shipped topo map (`scripts/ui/topo_map.gd`, 500 lines, [M], route ordering,
grease pencil, four ink layers, ADR-022 + ADR-037). **The journal does not re-implement it and does
not fork it.** The MAP tab draws Caleb's folded 1:50,000 art as the physical sheet and prints the
**live** `TopoSheet` raster on it as a bordered AO square — the same `ImageTexture` the [M] sheet
draws, fetched through the new accessor `TopoMap.sheet_texture()`. His printed cartography survives
outside that border as the surrounding ground, which is honest: the AO is 512 m of a larger sheet
and the border says where the ground you can walk ends.

**Marking stays on [M].** ADR-037 §3 makes the grease pencil the map's verb; a second marking
surface would fork the annotated layer, which is exactly the mush ADR-022 §"two layers" legislates
against. Opening one puts the other away (`TopoMap.close()`, `journal.gd:155`).

## 5 · WHAT THE OTHER TABS HONESTLY ARE

The tab names are his. Two of the four systems behind them **do not exist**, and the pages say what
is really there rather than pretending:

| Tab | What exists in code today |
|---|---|
| **GEAR** | **No inventory system.** `grep -i inventory` over `scripts/` = 0 hits. There is a fixed 5-slot equipment wheel (`equipment_manager.gd:8-11`) plus ~12 loose scalar counters on the Player. The page enumerates the counters — the same manifest `SaveData.PlayerSection` (`save_data.gd:92-105`) already serialises. It is a **kit list**, not an inventory, and nothing here can be moved, dropped or arranged. |
| **ORDERS** | **No quest system.** `grep -i quest` over `scripts/` = 0 real hits, and `mission_state.gd:52-53` forbids ever adding "a completed flag, no objective id, ever" (ADR-029 §4). The page shows **what the CO said** (`director.patrol_location` + kind, the line `rebark_patrol()` speaks) and **what the player wrote down** (`state.pencil_marks` with their free text). No completion state, no counter — legal under ADR-022's grease-pencil law and ADR-029. |
| **MISSION** | Real: operation name, day/time, threat, patrols out, live squad roster with condition. |
| **LOG** | §2. |
| **MAP** | §4. |

## 6 · THE DA FORM 20 CAN ONLY SAY WHAT THE GAME KNOWS

The form carries **GRADE** (`CampaignState.title()`), **MOS** (`player_data["mos"]`, always
RIFLEMAN), **TOURS** (`missions_played`), **CONFIRMED** (summed from `mission_log`), **SQUAD KIA**,
and **ORGANIZATION** — which comes off *his own cover art*: `CO B 2D BN 42D INF`, from the ink
"B.Co 2/42".

It shows **no number for reputation or XP**. ADR-032 forbids it; ADR-018 killed player stats outright
(*"No player progression may touch accuracy, recoil, sway, handling, health, or stamina. Ever."*).
That is why a character sheet in this game is a short document, and it should stay short.

**The NAME and SERIAL blocks are ruled lines with nothing in them, because the player has no name.**
`grep player_name|serial_number` over `scripts/` = 0 hits; `CampaignState.player_data` is a
one-key dictionary. **FOR THE SUMMONER:** invent one, let him type one at campaign start, or leave
the blocks blank as a deliberate everyman. Blank is what ships until he rules.

## 7 · INPUT

New action `journal` on **J** (`project.godot`). J was the only unbound letter left in his seven
candidates. The debug-only siege lens moved **J → F8** (`game_flow.gd:75`) with its doc comment,
`DEV_SIEGE_STRENGTH`'s comment and `DEMO_PLAYTEST_SCRIPT.md:71` corrected in the same change
(ADR-012 §6: the manual is part of the input system — `PLAYER_MANUAL.md:32-33` updated).

**Tabs are clicked, never keyed.** 1–4 are weapon slots, C/H/X/N are squad orders and permanently
dual-bound (ADR-012 §4), Q/E are lean, TAB is the pencil-ink cycle inside the map sheet. The mouse
is already free while the journal is open, and the tabs are the visible affordance the r4bk law
requires.

## 8 · THE ART IS THE WHOLE LOOK

Slices are cut from his master by `tools/gen_journal_slices.py` into `assets/ui/journal/*.png` —
the `tools/gen_cursors.py` precedent (offline slicing + regenerate from the sheet, no runtime
`AtlasTexture`, which this project has never used). **The master is never written to.** Largest
slice is `map_topo.png` at 995 KB, under the 1 MB texture law. No icons, no glow, no modern type:
the font is Courier New first (a DA Form 20 and a company journal were typed, not set), text
baselines sit **on his printed rules** (first rule 59 px, pitch 23 px, 15 per page, measured), and
his pencil, paperclip and rubber band are drawn as loose kit lying on the page.

**Not a 640×480 buffer.** ADR-030 is PROPOSED and explicitly deferred by Caleb (2026-07-25) as
non-blocking. When it is built, this surface folds into it like the other two HUD layers.

## 9 · WHAT IS SACRIFICED

- **A second thing competes for [M]'s job.** Mitigated by sharing one raster and one marking verb,
  but two doors onto the same map is a real cost and a fossil risk if either drifts.
- **`cover.png` ships unused** — there is no closed-journal state. Ship it or cut it later.
- **The log dies at the mission boundary.** A man's notebook would not.
- **Reading it can kill you.** Deliberate (§3), and the most likely thing he pushes back on.
- **Two tab names promise systems that do not exist.** The pages are honest, but GEAR and ORDERS
  will read as thinner than the other three until an inventory and a tasking layer exist — if they
  ever should.

## 10 · PROOF

`tests/probe_journal.tscn` — capture, blank-line rejection, repeat collapse, ring cap, five tabs,
every art slice loads, the notebook stays upper-left, the tab column clears the right page's text
column, every page builder survives a null world, and a line pushed through the HUD comes back out
on the LOG page.
