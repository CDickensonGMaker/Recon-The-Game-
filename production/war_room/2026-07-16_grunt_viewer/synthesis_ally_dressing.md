# DECREE — Identity dressing through the real spawn path (bead 37mj, 2026-07-16)

**Query (Summoner):** in-game grunts get randomized faces/loadouts via the real spawn path;
ONE randomization core shared by bench and game; skin/face law holds in-game; seeds reproducible.
Summoner also blessed the grunt_dresser.gd FACE_MATERIALS fix (599b7d3) by ordering this work.

**Council:** game-designer + devil's advocate (independent, code-first).
Analyses: `analysis/game_designer_ally_dressing.md`, `analysis/devils_advocate_ally_dressing.md`.

## The rulings

1. **A named man's face IS his identity (Pillar 4).** `SquadRoster.generate_member` stamps
   `face` (0–69) + `helmet` (real variant id) into the member dict at generation; `ensure_roster`
   back-fills older saves by name-hash ONCE, then the record owns it (established back-fill idiom —
   no save migration). Stored beats derived: no engine `hash()` change or atlas re-cut can ever
   change a veteran's face. Helmet is identity-stable too — at PSX resolution the graffiti is the
   long-range recognition token. **Gear (ruck/radio) stays per-mission: kit is the mission, skin
   and paint are the man.**
2. **One core:** `GruntRandomizer` moved to `scripts/visuals/` (new file beside the dresser — the
   eq6n territory warning covers editing GruntDresser/ModelActor, not adding a sibling).
   `dress_actor()` is the single shared entry — grunt_viewer's `spawn()` and the game's
   `AllyBase.dress_visual()` both land there. Once-per-actor guard (`dressed` meta).
3. **Hook shape:** dressing is deferred from `_setup_visual` (SquadSystem assigns `member` after
   `_ready`, so end-of-frame the man wears HIS face) plus an explicit `ally.dress_visual()` in
   `SquadSystem.setup()` after `set_sprite` (covers the default-body early-return the designer
   confirmed; the meta guard makes double-calls no-ops). No force-rebuild — the DA showed
   `set_sprite` already carries a stale-hitzone bug that force would widen (beaded bhu9).
4. **Capability-gated, never list-gated:** helmet swap only where `helmet_shell_worn` exists;
   legacy bodies (m14/m60/m79) dress face-only and keep the welded pot; pilots excluded.
   (Designer's "v3 not dressable" flag was stale — v3 measured stock_helmet=true, fully dressable.)
5. **VC/NVA excluded** until the Summoner maps which atlas cells are Vietnamese (6yc3) — a US face
   on a guerilla is a Pillar 2 wound. Civilians excluded (own models).
6. **Reproducibility:** memberless allies (benches, POWs, arena) draw a serial-seeded bench
   sequence; `MissionScope.reset()` rewinds it (ADR-010).

## Landmines beaded, not buried

- bhu9 (P1): set_sprite never rebuilds hitzones — pre-existing, hits every specialist today.
- 2whe (P1): gib spawn clones the Mesh and DROPS override materials — a popped head loses the
  dressed face. Pairing law breaks exactly where the player stares.
- 6yc3 (P2): VC cell map from the Summoner.
- Named risk accepted: helmet GLBs `load()` per man (ResourceLoader-cached after first use;
  squad spawns pre-mission). Arena has no FPS gate to see the material-duplication cost — the
  perf ledger (t5mo) owns that instrument.

## Proof

- `tests/test_ally_dressing.tscn` — **PASS**: memberless bench dress (9 surfaces, one offset);
  same roster record twice → identical cell-17 face; rookie stamped face=4 helmet=m1_veteran;
  exactly one HelmetSocket after explicit+deferred both ran; VC + pilot gate.
- `tests/test_grunt_dresser.tscn` — **PASS** incl. new legacy face-only case (m60 keeps welded pot).
- Guardrails: headless boot 0 script errors; `test_ally_cover_roll` PASS; `test_ai_stress_arena`
  PASS (arena allies now spawn dressed).
