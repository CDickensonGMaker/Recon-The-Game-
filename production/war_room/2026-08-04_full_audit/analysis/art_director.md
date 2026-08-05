# ART-DIRECTOR — Full Audit 2026-08-04 (independent sight, no cross-talk)

Every count below was MEASURED this session (GLB JSON parse + comment-stripped grep over
`scripts/ scenes/ data/ tests/`), not read from a log. Where ART_Track_Log.md disagreed with the
codebase, the codebase won — both directions, twice (see §5, §7).

---

## 1. THE SHARED ANIMATION LIBRARY — 182 clips, 143 wired / 39 orphaned

**Census:** `assets/shared/anim_library.glb` (16.0 MB, mtime 2026-08-03 22:45) parses to exactly
**182 animation clips** (GLB JSON `animations[]`, probe run 8/4). 163 at the 8/2 audit + 19 `chow_*`
= 182. Checks out.

**Wiring measurement:** every clip name grepped against `scripts/`, `scenes/`, `data/`, `tests/`
with `.gd` comment lines stripped (a comment is a tombstone, not a caller — the naive grep
mis-counted 6 clips as wired off comment mentions alone). The 8 `__smg` family clips carry no
literal reference but are constructed at runtime: `sprite_state_map.gd:400-404` appends
`"__" + WEAPON_FAMILY[weapon]` (`WEAPON_FAMILY` at `sprite_state_map.gd:385-392`, ppsh/ppsh41 →
"smg"). They are credited wired.

**RESULT: 143 wired / 39 orphaned.** The 39, by class:

| Class | Clips | Status |
|---|---|---|
| `chow_*` (19) | chow_cook_stir/prep/check, chow_serve_ladle, chow_queue_walk/step, chow_tray_hold/carry_walk/receive/wait/dump, chow_eat_seated/standing, chow_sit_down/stand_up, chow_talk_seated_a/b, chow_carry_walk/step | **Deliberate — half-wired.** Markers mapped in `site_planner.gd:829-835`, schedule live in `civilian_schedules.gd:202-218`, but `civilian.gd:_play_garrison` (:438-503) has NO `mess_hall` branch and names zero chow clips. Queue→serve→sit→eat chain unbuilt, AND the GLB carrying the markers was never re-exported. Dual-blocked: his bench + one code pass. |
| Jump/traversal (6) | jump_up, jump_up_2, jump_down, jump_away, hard_landing, jumping_jacks | **Orphaned BY DECREE** (8/2 synthesis §III): zero `NavigationLink3D` in the repo, no NPC is ever airborne. Traversal is an epic, escalated to the Summoner. Not a defect. |
| cockpit_dead (1) | | **Orphaned by decree** (8/2 synthesis §II) — no pilot damage model. Recorded, correct. |
| Genuine orphans (13) | action_idle_to_standing_idle, cover_reposition, crouched_sneaking_left/right, crouching_turn_90_right, rifle_crouch_idle_to_walk, rifle_turn, salute, signal_move_up, stop_walking_with_rifle, strafe_2, swimming, turn_90_right | No caller, no decree. Note the asymmetries: `turn_90_left` and `crouching_turn_90_left` have callers (gore_dummy.gd:20), their RIGHT twins do not; `cover_reposition` is the one cover clip of five that never got wired (`cover_peek`/`wall_lean` etc. play from `ally_base.gd` / `enemy_base.gd`). `signal_move_up` — a squad-leader beckon in a squad game — has never been played once. |

**Delta vs 8/2 (32/163):** since that audit the litter team (`scripts/world/litter_team.gd`, plays
litter_carry/load front+rear), cockpit_controls + pilot_flips_switches (seat_system), grenade_throw
+ stumble_hit (`enemy_base.gd`) and the mortar trio (`ally_base.gd`) all gained real consumers.
**Caveat:** the 4 `gun_*` MG-crew clips count as "wired" but their ONLY consumer is
`anim_review.gd` — the review bank the 8/2 decree built so he could judge the crew. In the actual
game they play nowhere. Same for a handful of others reachable only through review scaffolding.

**Family gap unchanged:** `mg`, `bolt`, `launcher`, `pistol` have ZERO family clips in the library
(`model_actor.gd:872-885` logs the gap once per family). The RPD gunner, the RPG man and every
Mosin carrier hold their weapons like an M16. ART_Track_Log §3 priority order (mg → launcher →
bolt → pistol) still stands and is still the biggest silhouette lie in combat. [FULL GAME, partially
DEMO — VC attackers at night carry RPD/RPG/Mosin]

## 2. VIEWMODEL PIPELINE — healthy core of 9, a stale fringe of 4, 3 guns with nothing

Manifest `tools/viewmodel_manifest.json`: 14 guns + 5 items, blend
`assets/player/arms/fp_arms_rifle.blend`, output `assets/player/viewmodels/`. Pipeline files all
present: `tools/export_all_viewmodels.py` (7/30), `tools/validate_viewmodel_glb.py` (7/30),
`tests/test_viewmodel_contract.tscn` (7/26), plus sync-contract and poses probes.

Measured per-GLB clip contents (GLB JSON parse, 8/4):

| State | Guns | Evidence |
|---|---|---|
| **Through the v2 pipeline, full 6-clip contract** | m16, ak, m14, m60, m70, m79, mosin, colt45 (+ ppsh at its sanctioned 5 — no charge_handle) | GLBs dated 7/28–7/31, each carries rifle_idle/reload/reload_empty/charge_handle/fire/jam per manifest |
| **STALE fossil-exporter output, 1 clip (rifle_idle only)** | ithaca, rpd, rpg2, flashlight | GLBs dated **7/11**, predate the whole v2 contract (bleed-hole law, contact markers, lens). `shotgun.tres` → ithaca scene, `rpg2.tres` → rpg2 scene: both LIVE in-game on idle-only stubs. Waived 7/31 — waiver still honest. |
| **No viewmodel at all** (`model_path = ""`) | m72_law, rpg7, car15 | measured in `data/weapons/*.tres`; `weapon_holder.gd:967-968` skips load on empty path — equipping renders NOTHING in the hands. m72_law and rpg7 sit in the manifest with parts mapped but have never had a clip staged (ART log 7/26 authoring-gap list, still true: no `*_fp.glb` on disk). |
| **Items** | handset (2 clips), knife (3), bandage (3), m26 (4 incl. throw), claymore in manifest but **no claymore_fp.glb on disk** | measured |

The stale four cannot jam, cannot reload visibly, cannot be validated by the v2 gates, and predate
the chandle-bleed fix — the bug class fixed 7/27 for the core guns is still latent in them.
[DEMO impact: the demo player kit is M16/M79/M26/M60-adjacent — core guns are fine. FULL GAME:
enemy-weapon pickup (Vietcong fantasy, capture-and-use) hands you a 7/11 stub or nothing.]

## 3. PSX TROOP IMPORTS — 31/31 characters resolve; one deliberate fallback

`model_actor.gd:22-29 model_path()` is the sole sanctioned resolver over three faction dirs
(`:13-17`). Measured against disk:
- **US (9):** us_grunt_{v3,rifleman,pointman,rto,mg,marksman,grenadier} + 2 pilots — all present.
- **NVA/VC (12):** nva_{regular,rifleman,mg,marksman,officer,medic} + vc_guerilla{,_mosin,_ppsh,_rpd,_rpg} + vc_medic — all present.
- **Civilians (10):** all present, heights in `UNIT_HEIGHT_M` (:51-59).

Every `sprite_unit` in `data/enemies/*.tres` resolves to a GLB **except `nva_rpg.tres`**
(`sprite_unit = "nva_rpg"`, no such GLB) which lands on its declared fallback `vc_guerilla_rpg` —
an NVA RPG man in black pajamas. Working as designed (ART-AHEAD wiring), but it is the one body
still owed from the 7/29 roster expansion. us_base_v3.blend lineage intact: it is the LINEUP
source in `tools/export_us_squad.py:27` and process reference across the toolchain.

## 4. THE FIREBASE KIT — one 8-day-stale GLB, with wired code idling behind it

**The single hardest fact in this dimension:** `fsb_main_v3.glb` mtime **2026-07-26 22:27**; the
truth-source `firebase_v3.1.blend` mtime **2026-08-03 23:01** (chow hall merged back). Eight days
of Blender work — the medical complex, the chow hall, the recovered 21 collections — exist in NO
running game. `gen_firebase_v3.py:912` (`blend or os.path.join(gf.KIT_DIR, "firebase_v3.1.blend")`)
is CORRECT per briefing — do not repoint; the stale save at `:1104` (`firebase_v3.blend`) is in the
parapet `main()`, a different path.

What the re-export must carry, and the consumer already waiting on each (all verified live code):

| Cargo | Waiting consumer (file:line) | State |
|---|---|---|
| **Medical `work_medic` markers** | `site_planner.gd:973-999` — aid station seeds medic + patient, litter team (3 men) gated on `CampaignState.ward_wounded` | Fully coded. `by_type["medic"]` is EMPTY on the Jul-26 GLB — **the aid station, patient and litter team have never once fired in game.** |
| **Chow markers** (`work_chow_server`, `chow_diner`, `eat`, `queue`, …) | `site_planner.gd:829-835` occupation map + `:848-855` priority + `civilian_schedules.gd:202-218` three-sitting meal | Coded and waiting — but see the NAME RISK below and M-1. The clip chain (§1) is the remaining code half. |
| **Second helipad** | `scripts/ai/air_traffic.gd:54-64` — pads matched by prefix `PSPHelipad`/`fb_helipad`, `PAD_DISTINCT_M = 12.0` de-dupes co-located markers ("a second real pad is Blender work, not code", drift-corrected 8/3) | A second pad ≥12 m away becomes a second LZ automatically. Gates the M-5 gunship-launch beat. |
| **Wire split** | `siege_director.gd:63-66, 282-284` — "the barbwire is one merged ring that cannot be broken at all"; `sapper_charge.gd:66` puts "wire" FIRST in TARGET_PRIORITY | Sappers already target wire; the mesh being one ring means a breach can never open. NOTE the code sacrifice: `nav_baker.gd:16-18` re-bakes nothing on destroy — splitting the wire gives destructible SPECTACLE, a walkable breach is a separate code task. |
| **Bunker firing slits** | None. `fb_bunker_mg`/`fb_bunker_fighting` are COL_TRIMESH (`gen_firebase_v3.py:841-868` — holes stay holes) but no code occupies a bunker; only `MGEmplacement` has man-this-position logic. Slit recipe: `production/blender/FIREBASE_BLENDER_HANDOFF.md` §2/§2b/§2.5 | Art-only value until an occupancy consumer exists. Lowest priority of the five. |

Down-facing trimesh hazard (measured 8/2) has a code guard: `site_planner.gd:1254-1263` forces
`backface_collision` on concave shapes at load.

## 5. BLENDER BENCH — truly blocked vs falsely believed blocked

**Falsely believed blocked (7/31 finding RE-VERIFIED TRUE on 8/4):** the 21 firebase interior
props (`assets/us/props/interior/fb_*.glb` — cot, field_desk, map_board, radio_prc25, litter,
medical_chest, wash_drum… exactly 21 GLBs counted) are ON DISK with textures. Consumers in the
entire repo: `field_cache.gd:31` and `mortar_pit.tscn:6`, both using only fb_ammo_crate_stack.
`_furnish_interior` (`site_planner.gd:526`) runs only in the VILLAGE path (:301) and
`SiteLayouts.INTERIOR_PROPS` (`site_layouts.gd:94-103`) maps only village prop classes.
**20 of 21 props have never been placed by code. This is a half-day CODE task wearing a Blender
costume, and it has now survived two audits unclaimed.**

**Truly blocked on his bench:** the firebase re-export itself (§4) — nothing else. The chow CLIPS
are already merged (182 measured in the GLB); the viewmodel core is exported; the troops resolve.

**ART_Track_Log convicted twice this session (POINTER LAW, both directions):** (a) its 8/3 entry
says the five chow station clips are "not yet merged into anim_library" — the .glb parse shows all
19 chow clips IN the shipped library (merge happened 8/3 22:45, log never updated); (b) its 8/3
entry says "site_planner.gd maps only mess/cook" — `site_planner.gd:829-835` maps seven chow
types (wired 8/4, commit 1795b519 era). The log is a claims document; it trails the tree by days.

## 6. M-1 RESTATED, IN ART TERMS

`site_planner.gd:914-918` (the parser; the briefing's 905-909 window is the walk above it): a
work marker's type is `name.trim_prefix("work_")`, then a trailing `_<int>` is stripped ONLY if
the substring after the last `_` `is_valid_int()`. Blender authors duplicates as `work_dig.001`.
IF Godot's importer delivers `work_dig_001`, the parser yields `dig` → occupation map hit. IF the
DOT survives into the node name (`work_dig.001`), `rfind("_")` finds nothing strippable —
`wt = "dig.001"` — no map entry — **off_duty**. One import-time character decides whether ~185 of
198 authored markers are jobs or junk, whether the aid station has ever been able to seed, and
whether every chow marker about to be exported will land. **In art terms: M-1 decides whether a
month of marker authoring is load-bearing or decoration, and it gates the entire §4 export.**
Probe: `tests/test_firebase_garrison.tscn` + occupation histogram from `fsb_garrison_plan`.
Minutes to run. Run it BEFORE the bench session, because a FAIL changes the export (rename pass).

**ADJACENT NAME RISK (specify, don't guess):** ART log 8/3 lists authored marker names
`work_serve`, `work_trayreturn`; `site_planner.gd:829-835` maps `chow_server`, `chow_server_line`,
`chow_diner`, `chow_trigger`, `chow_exit` (comment: "names locked by Caleb 2026-08-03",
convention `work_<building>_<role>`). If the .blend still carries the OLD names, every one falls
through to off_duty — silently, because that fall-through is by design (:840). MEASUREMENT: dump
all `work_*` empty names from `firebase_v3.1.blend` (bpy one-liner) and diff against the
`FSB_WORK_OCCUPATION` keys before exporting. Two minutes at the bench, prevents a silent
40-statue chow hall.

---

## STRONGEST (verified working)

1. **The shared-library architecture itself** [DEMO+FULL] — one 16 MB GLB, 182 clips, merged
   per-unit at load (`model_actor.gd:280-310`), PSXRig track-path contract guarded (:287), loop
   modes re-applied (:364), phase-preserving crossfade (:917-925), family fallback with one-shot
   gap logging (:879-885). 143/182 clips have real consumers. This is a professional pipeline.
2. **Character roster resolution** [DEMO+FULL] — 31/31 GLBs resolve through the one sanctioned
   resolver; every enemy .tres lands on a real body; heights, gib contract, donor-hide nets and
   self-auditing warnings (`_report_second_body`, `_report_untextured`) all live.
3. **Viewmodel core** [DEMO] — 9 guns through the v2 strict pipeline with full clip contracts,
   contact-marker FAKED-IN-AIR detection, per-clip channel law, lens (ADR-034), and three suite
   probes. The demo's player-facing guns are the healthiest art in the project.

## WEAKEST (would embarrass us / block ship)

1. **The 8-day-stale firebase GLB** [DEMO] — the demo IS one day at this firebase, and the
   version on screen has no medical complex, no chow hall, one pad, an unbreakable wire ring.
   Three fully-wired systems (aid station, litter team, chow schedule) have literally never
   executed. Single hardest blocker in the art dimension.
2. **Weapon-family clip gap** [DEMO night attack + FULL] — every VC/NVA RPD, RPG and Mosin
   carrier rifle-holds their weapon (`model_actor.gd:879` fires every session). At bayonet range
   inside the wire, a stranger sees it.
3. **The stale/empty viewmodel fringe** [FULL, edge-DEMO] — shotgun and RPG-2 live on 7/11
   idle-only stubs that predate every pipeline law; m72_law/rpg7/car15 render NOTHING in hand
   (`model_path = ""`). Weapon pickup — the genre's signature move — is where the demo can hand a
   stranger an empty pair of arms.

## IMPROVE (value-per-effort, priced)

1. **Run M-1** [DEMO] — minutes; may invalidate or validate a month of markers and re-scopes the
   bench session. Infinite value-per-effort; nothing in this report should be built before it.
2. **The bench re-export session (manifest below)** [DEMO] — one Blender session lights up three
   already-paid-for systems (aid station + litter + chow markers) and the second pad. Highest
   art payoff available; the code side is already sitting at 100%.
3. **Place the 21 interior props** [DEMO] — half-day of CODE (extend `_furnish_interior` coverage
   to the firebase path with an fb_* pool keyed off structure class). Turns every shell building
   in the compound into a set. Third audit in a row this has been the best unclaimed
   payoff-per-hour. No bench time at all.
4. **Chow clip chain** [DEMO] — one code pass in `civilian.gd:_play_garrison` (+ `mess_hall`
   branch mapping ACTION_WORK at chow markers to the chow_* clips). Unlocks 19 orphans at once —
   the largest single orphan-count reduction available. Blocked behind M-1 + re-export.
5. **mg family 8-clip set** [DEMO+FULL] — his posing queue, ART log §3 order confirmed correct
   by measurement (RPD carriers are in the demo's assault waves; pistol family still has zero
   carriers — keep it last).
6. **Retire the 13 decree-less orphans** [FULL] — wire the cheap ones (turn_90_right beside its
   wired twin; cover_reposition into the cover set; signal_move_up on squad move orders — a
   free squad-feel win) and delete or decree the rest (swimming, salute, jumping_jacks). ADR-023:
   an orphan without a decree is a fossil in waiting.

**Sacrifices named (Law 2):** prioritizing the re-export spends his only bench session on export
mechanics, not on new art (no SKS/M79 FP push this week — the capture fantasy stays broken a while
longer). Placing interior props costs a half-day of code that does not advance the 30-minute arc.
Wiring the wire split buys spectacle only — a walkable breach still needs nav work the demo does
not have time for, and saying otherwise would be selling a lie. The chow chain adds ~24 animated
men to the pre-siege compound: if frame cost shows up, the three-sitting split
(`civilian_schedules.gd:196-198`) is already the mitigation.

## SINGLE-SESSION BENCH MANIFEST (the re-export, in order)

Truth source: `firebase_v3.1.blend` (kit dir, 2026-08-03 23:01 — chow already merged).
`gen_firebase_v3.py:912` default is correct; do NOT repoint. `:1104` writes a stale
`firebase_v3.blend` name in the parapet main — ignore, different path.

0. **BEFORE OPENING BLENDER: run M-1** (`tests/test_firebase_garrison.tscn`, histogram). If FAIL,
   add a marker-rename pass (dots → underscores) to step 2.
1. Copy `firebase_v3.1.blend` aside first (the .blend1 is ROLLING — the 7/31 export ate the
   medical complex once already; `firebase-export-ate-the-medical-complex` is the scar).
2. Dump every `work_*` empty name; diff against `FSB_WORK_OCCUPATION` keys
   (`site_planner.gd:823-842`). Rename any `work_serve`/`work_trayreturn` stragglers to the
   locked `work_chow_*` convention. Confirm chow marker facing is +X (measured 8/3).
3. Duplicate the helipad ≥12 m from the original (`air_traffic.gd:59 PAD_DISTINCT_M`), keep the
   `fb_helipad`/`PSPHelipad` name prefix (:64).
4. Split the barbwire ring into gate-sized segments named to match the destructible manifest
   convention (sapper TARGET_PRIORITY expects "wire", `sapper_charge.gd:66`).
5. Bunker slits ONLY if time remains — recipe `FIREBASE_BLENDER_HANDOFF.md` §2/§2b/§2.5; no code
   consumer exists yet, so this cargo can slip a session at zero systemic cost.
6. Export via `gen_firebase_v3.export_firebase()` (writes GLB + mound manifest together — the
   manifest MUST regenerate, `site_planner.gd:694` errors without it).
7. In Godot: run `tools/diag_fsb_seat.gd` (re-asserts the AABB consts at
   `site_planner.gd:661-664` — remeasure on every re-export, per :642), then
   `test_firebase_garrison` again for the occupation histogram, then eyes on the compound.
