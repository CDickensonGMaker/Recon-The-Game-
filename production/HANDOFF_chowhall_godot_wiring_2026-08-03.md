# HANDOFF — WIRE THE CHOW HALL INTO GODOT (for a coding window)

**Written 2026-08-03 by the Blender window. No Godot code was written here — that is this
handoff's whole job.** Caleb's instruction: *"if theres coding to be done give me a hand off
to another window of just what to target."*

**Convene the War Room before building any of this** (`recon-overseer` heads it — canon is
`production/GAME_GUIDE.md` + `production/adr/`). Nothing below is a decree; it is the state
of the art assets and the questions the code has to answer.

---

## WHAT IS ALREADY DONE — do not redo it

| thing | state | pointer |
|---|---|---|
| 19 chow clips authored | DONE | `assets/shared/anim_library.blend` |
| clips in the shared library GLB | **DONE 2026-08-03 22:45** | `assets/shared/anim_library.glb`, 182 animations, 15.28 MB — all 19 `chow_*` verified present in the GLB's JSON chunk |
| chow hall built, tented, sited in the firebase | DONE | `firebase_v3.1_RECOVERED_medical.blend`, root `WB_chowhall` at **(−20.51, 40.83, 3.00), yaw 44.2°** |
| the animated men REMOVED from the firebase | DONE | the scene ships the room + markers only; Godot brings its own soldiers |

**The firebase .blend has NOT been re-exported to a game GLB.** See the blocker below.

## THE 19 CLIPS (exact names in `anim_library.glb`)

`chow_carry_step` · `chow_carry_walk` · `chow_cook_check` · `chow_cook_prep` ·
`chow_cook_stir` · `chow_eat_seated` · `chow_eat_standing` · `chow_queue_step` ·
`chow_queue_walk` · `chow_serve_ladle` · `chow_sit_down` · `chow_stand_up` ·
`chow_talk_seated_a` · `chow_talk_seated_b` · `chow_tray_carry_walk` · `chow_tray_dump` ·
`chow_tray_hold` · `chow_tray_receive` · `chow_tray_wait`

Every clip is **bone-only** — zero object-level location channels, and root motion
(Hips X/Z) is stripped on export. **The engine drives all translation.** A clip plays in
place; the NPC's own locomotion walks him to the marker.

## THE MARKERS — this is the contract surface

136 objects in `WORKBENCH_chowhall`: **39 meshes + 97 markers, zero armatures.**
Local coords are relative to `WB_chowhall`; world coords are with the hall at its sited
position. **Read the markers from the scene — do not hardcode world coordinates**, or
moving the building silently breaks the schedule.

| marker | count | what it is | clip it implies |
|---|---|---|---|
| `work_queue`, `.001`, `.002` | 3 | the line, back to front | `chow_queue_walk` / `chow_queue_step` |
| `line_start`, `line_step_1..4`, `line_exit` | 6 | the shuffle along the servery counter | `chow_queue_step` |
| `food_stop` | 1 | **the trigger.** local (−0.50, −0.60), world (−20.45, 40.05) | man waits the full 100-frame ladle here |
| `work_serve` ×4 | 4 | diner side of the counter | `chow_tray_hold` / `chow_tray_wait` |
| `work_server` ×4 + `work_server_line` | 5 | server's side | `chow_serve_ladle`, fired only while someone is on `food_stop` |
| `work_cook.004/.005`, `work_cook_range` | 3 | the range | `chow_cook_stir` / `_prep` / `_check` |
| `work_eat` | **24** | seats, in 4 tables × 6 | `chow_sit_down` → `chow_eat_seated` → `chow_stand_up` |
| `prop_seat` | 10 | bench/chair anchors | — |
| `work_trayhandoff`, `work_traycollector`, `work_trayreturn` | 3 | the tray return | `chow_tray_receive` (collector), `chow_tray_dump` (diner) |
| `work_wash.010`, `prop_wash`, `prop_washdrum` | 3 | wash point | — |
| `chow_exit` | 1 | walk-away point, local (−2.95, −3.90) | `chow_carry_walk` empty-handed |
| `prop_tray` ×5, `prop_traypile`, `prop_traystack_clean`, `prop_ladle_*`, `prop_pot_*`, `prop_cook` ×6, `prop_storage` ×8, `prop_furniture` ×7 | 36 | prop anchors, incl. where a tray/ladle should spawn | — |

The 24 seats, local Y grouped: two rows per table facing each other (yaw 134.2° / −45.8°),
tables at local Y −4.73/−3.67 and −7.13/−6.07, columns at local X ±0.95, ±1.55, ±2.15.

## THE LOOP TO REPRODUCE (verified in Blender, one man, end to end)

queue slot → walk to the servery → **stop at `food_stop` and wait the full ladle** →
sidestep along the counter, tray fills → walk to a scheduled seat → sit → eat with the tray
**on the table** → stand → walk to the tray return → hand the tray to the collector →
**walk away empty-handed to `chow_exit`**.

Stationed men (cook, server, collector) are **trigger-driven, not looping**: the server
ladles only while somebody stands on `food_stop`; the collector receives only on arrival.
Both idle arms-down on stock `idle_unarmed` between times, **each started at its own phase**
so they are not in step — Caleb's note: *"all the men in idle are in the same time frame
loop."* Reproduce the stagger in the engine.

## WHAT TO TARGET

1. **`scripts/world/site_planner.gd` maps no chow marker.** It has to learn the families
   above so the firebase stamp exposes them as usable AI nodes.
2. **A chow schedule for the grunts.** `scripts/ai/civilian_schedules.gd` is the nearest
   existing shape (its only "chow" hit is a comment on `:113`) — a War Room call whether
   grunts get their own scheduler or extend that one. Feed off the SimClock
   (see `recon-operations-decree`), and the seat scheduler must hold a seat for the whole
   sit→eat→stand window or two men take one bench.
3. **Stopping a patrol to go eat** — Caleb's explicit ask, and it is Godot-side.
4. **Re-export the firebase to a game GLB — ~~BLOCKED~~ NOT BLOCKED (corrected 2026-08-03).**
   This item said `tools/gen_firebase_v3.py:912`'s default `firebase_v3.1.blend` was stale and
   had to be repointed at `firebase_v3.1_RECOVERED_medical.blend`. **That is no longer true, and
   repointing it now would be a change made against a dead fact.** The Blender window re-saved
   `firebase_v3.1.blend` at 22:45, fifteen minutes after this handoff's own truth source (22:30).
   Measured by decompressing both .blend files and counting object names in the raw data — both
   now carry an identical payload: `WB_chowhall` ×3 · `work_eat` ×24 · `food_stop` ×1 ·
   `work_serve` ×9 · `WB_medical` ×1 · `bwire_card_ring` ×2.
   **The default path is correct. Export as-is.** (Caveat: the two files differ by 122 bytes, so
   this proves the chow hall and medical complex are present in the default — not that the files
   are equivalent in every respect.)

## OPEN RULINGS — Caleb has to answer these before the names are load-bearing

- ~~Marker names are still PROVISIONAL.~~ **LOCKED by Caleb 2026-08-03.** The convention is
  `work_<building>_<role>` / `prop_<building>_<thing>`, and four families were renamed before
  any Godot code read them. **Use the NEW names; the table above shows the old ones:**
  `work_serve*` → **`work_chow_diner*`** (diner side) · `work_server*` → **`work_chow_server*`**
  (server side) · `work_server_line` → `work_chow_server_line` · `food_stop` →
  **`work_chow_trigger`** · `chow_exit` → **`work_chow_exit`**. `work_eat` ×24, `prop_seat` ×10,
  `work_queue` ×3 and `line_step_*` were already clear and are UNCHANGED.
  Renamed by `tools/rename_chow_markers.py` (idempotent, longest-prefix-first — renaming
  `work_serve` before `work_server` would merge the two sides of the counter). `work_serve`
  vs `work_server` had already cost code once: `tools/mark_chowhall.py:126` carried a
  `not startswith("work_server")` guard to keep them apart.
- **Cook/server/collector: scheduled soldiers, or fixtures?** In Blender they are staged
  men. In the game, does a grunt get assigned "cook" on a roster, or is the station always
  manned?
- **How many men eat at once?** `build(n=5)` has never been run in Blender, so the queue
  spacing is proven at n=1 only. The engine's answer does not have to match Blender's, but
  somebody has to pick a number.

## NOT FOR THE CODING WINDOW

The medical tent animations (wounded men, tending doctors) are the Blender window's next
job, same method as the chow hall. Nothing there is ready for wiring yet.
