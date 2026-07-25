# War Room Addendum — THE PLAYER FIELD-MARKING LAYER (folds into the route-pencil pass)

**Convened:** 2026-07-24 · Arbiter: recon-overseer · Under the PATROL CONTRACT decree (`synthesis.md`).
Caleb blessed the spine + all four resolutions; HUD buffer resolution DEFERRED (do not raise). Planning gate.

## New scope (Caleb, blessed intent — design it, stress-test the model)
A PLAYER FIELD-MARKING LAYER on the M-map, folded into the route-pencil work (same annotation layer).

**TWO DISTINCT LAYERS — keep them separate:**
1. **ROUTE WAYPOINTS = the PLAN** (numbered 1–5, green polyline, "where I intend to walk"). Already decreed.
2. **FIELD MARKS = the INTEL** (typed grease-pencil icons dropped while exploring: TRAIL, TUNNEL, CAMP + a
   small council-chosen set — bunker/cache/danger/casualty). NEW.

**UNIFYING MECHANIC = pull the parked "overloaded report verb" INTO THIS PASS.** Aim at something + press →
it lands on the map with the correct symbol: enemy → CONTACT (mark + called over the net, the original report
verb); a trail → TRAIL; a tunnel mouth → TUNNEL ("come back and go inside"); a camp glassed through binos →
CAMP at ESTIMATED position/range. One verb, whole vocabulary. This dissolves the parked "report verb" polish
item into core (note it in the HUD reconciliation).

## Period levers (non-negotiable design intent, from the FPS research)
- **MARKS ARE GREASE-PENCIL ESTIMATES, NOT GPS PINS.** Ranged marks (the glassed camp) land APPROXIMATELY
  where the player thinks; imprecision scales with range. Map-as-object-with-cost made real (ADR-022). Design
  the imprecision model.
- **MARKING HAS A COST** — requires eyes/LOS on the thing (binoculars for distant marks), not a free minimap
  ping. Define the friction (LOS-gated; maybe must-be-still — you decide).

## THE HARD GUARDRAIL (§4 safety, same family as the route's four clauses)
FIELD MARKS STAY ON THE PLAYER GREASE-PENCIL LAYER — they NEVER become checkable objectives, command pins, or
progress trackers. A TUNNEL mark is the player's note-to-self, not "OBJECTIVE: CLEAR TUNNEL." Enforce with a
structural probe. Keeps ADR-029 §4 intact.

## Design questions to RESOLVE (name tensions, recommend)
- **Placement:** world-space aim-and-press (report verb) vs in-M-map click-to-place vs both? (Caleb's
  binocular example implies world-space ranged marking is REQUIRED.)
- **Icon vocabulary:** how many types; can they render in the bitmap/period grease-pencil aesthetic (ties to
  researched-identifiers)? Small MILITARY grease-pencil set, not modern game icons.
- **Persistence:** do marks survive the patrol and feed the firebase's ACCUMULATED map at the wire-AAR (a
  multi-patrol AO-knowledge progression hook, ties ADR-017 persistent province), or reset each patrol? SCOPE
  CALL for Caleb — recommend.
- **Editing:** can the player erase/move a mark (grease-pencil erase)? Does a stale mark (camp moved) mislead
  — and is that GOOD (fog-of-war honesty, ADR-022 "the map is your memory")?
- **Reconcile with the route pencil** on the same M-map (mode switch? one pencil, multiple stamps?).

## What exists (READ IT — reuse, don't invent)
- `scripts/ui/topo_map.gd` — the annotation layer. `_draw_overlay:132` draws the CO's grease circle (never
  checks off, `:136`) + player arrow; `_world_to_map:127`; M-toggle `_unhandled_input:159`. Route pencil +
  field marks render HERE.
- `scripts/missions/field_director.gd` — the aim-and-press REPORT VERB already exists as the fire-mission
  grammar: `arm_fire_mission:276`/`commit_fire_mission:301` → `_cas_ground_target:688` (camera ray-march to
  ground, RTO-gated via `_radio_check:512`). The systems council RULED: keep `_cas_ground_target` (RTO-gated,
  fire) and a new direct aim path SEPARATE — but do NOT create a THIRD aim path; reuse the ray-march.
- The two decrees: `synthesis.md` (patrol contract) + `../2026-07-24_period_hud/synthesis.md` (HUD).
- ADR-022 (the map is your memory — two layers), ADR-029 §4 (no mission tracking), ADR-017 (persistent
  province), ADR-010 (determinism), ADR-005 (witness/fairness), ADR-023 (fossil).

## Deliverables the Arbiter needs from you
The field-marking spec, its §4 probe, Phase-1-vs-2 slotting (does report-verb marking come with the spine or
the pencil?), and any ADR-022 amendment. **BE FAST:** read only the files above for your lens; ≤150-word verdict.
