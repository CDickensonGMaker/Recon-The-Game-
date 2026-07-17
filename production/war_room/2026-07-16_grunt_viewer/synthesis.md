# DECREE — Grunt Viewer bench + the face-material drift (2026-07-16)

**Query (Summoner):** a grunt model-viewer test tool — orbit camera, animation dropdown,
role lock, RANDOMIZE button; skin tone + face must stay a matched pair, everything else random.

**Council:** lead-programmer + devil's advocate (independent, code-first).
Analyses: `analysis/programmer_grunt_viewer.md`, `analysis/devils_advocate_grunt_viewer.md`.
Bead: RECONgame-bdn3.

## What the probe caught before the tool ever ran

`GruntDresser._set_face` matched material `grunt_face_skin` — **a name that exists in ZERO
exported GLBs**. Every export carries `face_atlas_mat`. Face randomize was a silent no-op on
every unit on disk. `tools/merge_face_skin_material.py` proves the skin patch (hands/forearms/
neck) already lives in the same atlas cell and was already folded into the face material —
the exports just never took the planned rename. The merge script's own NOTE says
"match EITHER name"; the dresser didn't.

## The decree

1. **Dresser fix (5 lines, `scripts/visuals/grunt_dresser.gd`):** `FACE_MATERIAL` →
   `FACE_MATERIALS = ["grunt_face_skin", "face_atlas"]` + `_is_face_material()`.
   ⚠ eq6n notes scripts/visuals/ as another window's; file was git-clean, fix is
   evidence-backed and probe-guarded. **Flagged for the Summoner's blessing.**
2. **Roles** (dropdown + randomizer pool): the six v3 grunts + us_medic + us_rto.
   Excluded: us_grunt_v2/v3 (base rigs), m14/m60/m79 (no `helmet_shell_worn` — legacy
   exports), pilots (own skin materials, flight helmet).
3. **Radio randomize is dead everywhere** — no rifleman/pointman GLB carries a PRC-25
   despite ModelActor's promotion contract. Randomizer checks mesh presence dynamically
   (honest no-op); the export gap is beaded.
4. **Base_Human double body renders raw in the viewer** — a bench that hides bugs is a
   lying instrument. eq6n owns the fix.
5. **Uniform variants do not exist**; the space is face(70) × helmet(15) × ruck × radio.
   No invented dimensions.
6. **dress() is not re-entrant** (HelmetSocket stacks) — the viewer respawns a fresh
   ModelActor per RANDOMIZE; the probe asserts exactly one socket.
7. **Wiring debt named:** dress() still has zero game call sites — the bench must not
   immunize an unwired system (beaded).

**Sacrificed:** a session on an instrument while P0s stay open (GATE-exempt as
evidence-gathering — and it did gather: it found the face no-op and the PRC-25 gap).

## Proof

`tests/test_grunt_dresser.tscn` — PASS: 8 roles, 9 face surfaces each sliding as one
(live body + gib head + 7 head frags — a popped head keeps the man's face), per-instance
material isolation, role lock, radio law, single helmet socket, seed determinism.
Headless boot: clean. Fossil probe: zero new symbols from this work (the 19 red are j3ke's).
