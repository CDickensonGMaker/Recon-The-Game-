# Talking heads — cutscene lip-sync rig (2026-09-11, production pass 2026-09-12)

Decree: `production/war_room/talking_heads_2026-09-11.md`. This folder is the CAPABILITY (rigged heads whose
mouths speak recorded lines), not a cutscene. Game asset files were only appended from; nothing here is exported
to Godot (ADR-024 prerendered FMV). `.gdignore` keeps Godot from importing the renders.

| file | what |
|---|---|
| `talking_heads.blend` | the one file. Four rigs in a row at x = 0 / 1.5 / 3.0 / 4.5 (Michael, Gus, sniper, zombie) |
| `lines.json` | which recorded line each head speaks in the shipped proof (head -> wav + spoken text) |
| `lipsync/<head>_<wav>.json` | the raw Rhubarb mouth cues for that line (+ the `.txt` dialog hint given to it) |
| `build_report.json` | every gate number from the last build, plus the `lipsync` block (cue checks, mouth-vs-audio) |
| `textures/` | generated 256² zombie skull atlas (sampled off Caleb's sheets; ivory tooth patch at x 2-14, y 188-212), clubs card, 64x32 mouth cavity (teeth/tongue). The sniper uses `assets/nva_vc/characters/cow_sniper_sheet_1024.png` directly |
| `renders/<head>_visemes.png` | the 9 Rhubarb shapes side by side (humans: shape keys; skulls: jaw angles), mouth close-up |
| `renders/sniper_match.png` | his game portrait (`production/renders_conquest_of_worms/sniper_portrait_front.png`) beside the cutscene head, front-on |
| `renders/<head>_eyes.png` | blink / blink_L / blink_R / brow_up / brow_down (humans) |
| `renders/<head>_line.mp4` | the keyed line, MGS-style close-up, Eevee 640x480 24 fps, audio muxed |
| `renders/<head>_line_f<N>_<cue>.png` | two labelled spot-check frames per line: the loudest open cue and a silent cue |
| `tools/th_textures.py` → `th_build.py` (→ `th_skulls.py`) → `th_lipsync.py` → `th_render.py` | re-runnable pipeline, empty scene to mp4. `th_skulls.py` also runs standalone on the saved .blend (teeth + the sniper head only; the humans are not rebuilt) |

## What an animator gets

- `cs_head_michael`, `cs_head_gus` (130 v / 224 tris each, under `PSXRig_michael` / `PSXRig_gus`). The 4 front quads
  of the game head are rebuilt as a face patch whose rows sit on the PAINTED features of each man's cell (mouth line,
  lip corners, nostrils, pupils, eyebrows — measured, and read back through the UVs: lips 0.0 mm, pupils 1.0 mm off the
  paint). Mouth: lip edge + 2 concentric loops (vermilion border, outer loop under the nose wings), a dark cavity with an
  upper and a lower teeth strip, a 2-quad tongue, and a back wall. Neck ring vert-identical to the game head so it
  swaps onto the cast body; one Gus head serves both Gus states (their game heads measure identical to 0.001 px).
  Ears sit on the rear-side polys at 58-60% of head depth, behind the jaw (Caleb's 2026-09-12 ruling; the
  projection tool gates it), with cheek skin on the side quads.
- **Shape keys = Rhubarb's 9 visemes, named exactly `A B C D E F G H X`:** A closed lips (P/B/M, pressed) · B slightly
  open, teeth together · C open (EH/AE) · D wide open (AA: lower lip drops 19 mm, chin 10 mm) · E slightly rounded ·
  F puckered (mouth width 0.61-0.64 of rest, lips 4.5 mm forward) · G upper teeth on the lower lip · H tongue up
  (tip rises 10 mm between the teeth) · X rest. Plus `blink`, `blink_L`, `blink_R` (the CHARACTER's own left/right),
  `brow_up`, `brow_down`. Drive one viseme at 1.0 at a time; they are whole-mouth poses, not additive sliders.
- `cs_skull_zombie` + `cs_mandible_zombie` (288 v / 510 tris + 152 v / 236 tris): the bare CDmir cage skull with REAL
  dental arches (`tools/th_skulls.py`, 2026-09-12): 11 upper tooth blocks hung from the measured alveolar margin and
  11 lower stood on the measured crest (6 per side: I1 I2 C PM1 PM2 merged-M; one upper lateral and one lower premolar
  missing, one canine snapped), lower row 2.5 mm inside the upper with a 1.5 mm overbite. Every tooth face carries the
  int face attribute `th_tooth` (= 1 + its spec index; 0 = bone). Nothing tooth-shaped is painted on the atlas any more.
- `cs_skull_sniper` + `cs_mandible_sniper` (169 v / 252 tris + 90 v / 120 tris, ONE material = his own sheet): NOT a
  skull. His shipped game head (the head polys of `vc_guerilla_joined`, his weights, his UVs) split on the painted mouth
  slit: an 11 mm tooth band is cut out between the corners (53 mm mouth), everything under it in front of the cheeks is a
  chin block on the `jaw` bone, 8 upper teeth hang from the upper skin edge, 8 lower stand on the block, dark cavity
  behind (roof/back/side walls on the head, floor/back/side walls rising into the head on the block). Tooth texels are
  his own painted teeth patch on the sheet. `renders/sniper_match.png` = his game portrait beside it, front-on.
- Both mandibles are skinned 100% to a `jaw` bone under `mixamorig:Head` (hinge at the condyle, axis = the rig's
  `jaw_axis` property). Cue -> angle: X/A 0° · G 2° · B 4° · F 5° · E 7° · H 8° · C 11° · D 18° (25° is the clearance
  gate, a yell). Gates at 25° (`build_report.json` `jaw_gate_*`): lower incisors clear the upper teeth by 32.5 mm
  (zombie) / 39.8 mm (sniper), molars 25.9 / 41.4, chin travel 48.4 / 48.3 mm, 0 mandible verts inside the zombie cage.
- Actions: `anim_<head>` on each rig (keyed identity pose at frame 0; the skulls' jaw keys live here), `line_<head>` on
  the human heads' shape keys. Each rig carries a `th_line` property (wav, text, frame count, cues) and its wav sits
  muted on its own VSE channel (1-4) — unmute the one you are scrubbing.

## Sync a new line (the animator's loop)

1. Put the wav anywhere (48 kHz 16-bit mono is what the squad VO is). Rhubarb lives in `tools/rhubarb/` (gitignored,
   156 MB; if it is missing, unzip `Rhubarb-Lip-Sync-1.14.0-Windows.zip` from
   github.com/DanielSWolf/rhubarb-lip-sync/releases into that folder).
2. From the repo root:
   ```
   "C:/Program Files/Blender Foundation/Blender 5.0/blender.exe" -b production/cinematics/talking_heads/talking_heads.blend ^
     --python production/cinematics/talking_heads/tools/th_lipsync.py -- --head gus --wav assets/audio/vo/john/squad_man_down.wav --text "man down"
   ```
   `--head` is michael / gus / sniper / zombie. `--text` is the spoken words (Rhubarb's `-d` hint; on two-word barks it
   changes nothing, but give it). Add `--no-save` to only write the cue JSON. `-- --all` re-syncs every entry in
   `lines.json`. Rhubarb runs `-f json -r pocketSphinx`; each cue becomes a one-hot key (its shape 1.0, the other eight
   0.0) with a 1-frame linear ramp at 24 fps; X covers silence; one blink is keyed near 45% of the line; brows are yours.
3. Read the `verify` line it prints: every cue's first and mid frame is evaluated (the cue's shape must be the only one
   at 1.0 / the jaw at its table angle), and the loudest quarter of the frames must be more open than the quietest.
   It WARNS when the mouth is shut on more than a quarter of the loud frames — that is Rhubarb mis-reading the take
   (measured on `ryan/squad_fall_back.wav`: 7 of 16 loud frames shut, the "aw" of "fall" read as a closed-lip A by both
   recognisers). Pick another take or hand-fix those cues in the graph editor.
4. Render: `... -b --factory-startup --python production/cinematics/talking_heads/tools/th_render.py [-- --lines] [-- --head gus]`
   writes `renders/<head>_line.mp4` (ffmpeg muxes the wav) and the two spot-check stills. `-- --visemes` remakes the
   contact sheets; `-- --match` remakes `sniper_match.png`. `TH_BLEND` / `TH_RENDERS` env vars point th_render.py and
   th_skulls.py at a scratch copy for dry runs.

Rebuild from nothing: `python tools/th_textures.py` (if atlases changed), then
`"C:/Program Files/Blender Foundation/Blender 5.0/blender.exe" -b --factory-startup --python tools/th_build.py`
(gates: neck ring 0.0 m, lips/pupils within 2 mm of the paint, tris <= 450, no n-gons, every key >= 2 mm, D >= 14 mm,
F width <= 0.70, B shows both tooth rows, cavity >= 4 mm behind the local face surface; then th_skulls: no tooth hull
overlaps at rest, +tris <= 260 per skull, incisors >= 30 mm / molars >= 20 mm clear at 25°, 0 mandible verts inside the
zombie cage, sniper head+block <= 450 tris, every block vert 100% jaw), then `th_lipsync.py -- --all`, then `th_render.py`.
Skull-only re-pass on the saved file: `... -b talking_heads.blend --python tools/th_skulls.py`. `talking_heads.blend` is written in place with no `.blend1`.
