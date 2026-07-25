# SPEC — THE PLAYER FIELD-MARKING LAYER (the intel verb)

**Session:** 2026-07-24 · Arbiter: recon-overseer · Under the PATROL CONTRACT decree. Status: PROPOSED —
awaits Summoner. Folds into the route-pencil work (Phase 2, one shared map-annotation layer).

## Council verdicts (full analyses in ./analysis/field_mark_*.md)
- **UX:** the placement split IS the reconcile — ROUTE = M-map click (map-open, plan, no LOS); FIELD MARKS =
  world aim-and-press (map-closed, LOS-gated). One `_draw_overlay:132` pass, three inks (green plan / red CO
  circle / grease-black stamps); no mode switch — the inputs can't collide. 5 glyphs, hand-drawn wobble;
  marks never update (`topo_map.gd:136` law). CONTACT = report verb (stamp + net call). **Risk: glyph
  legibility at 8px through the low-res buffer — prototype glyphs through the HUD Phase-0 seam; color before form.**
- **Game:** CONDITIONAL YES (4 pillars). This is **ADR-022's already-blessed annotated layer getting its
  verb** — wrong-map (`ADR-022:49`) and persistence are existing canon, not new. Stably-wrong = good but needs
  a **FINDABILITY FLOOR** (clamp error so a mark never crosses a legible terrain edge — navigable-to, never
  precise). Eyes-on = a real recon loop; the TUNNEL come-back-hook is the feature's best argument. Persist YES
  but Phase-2, **aggregate/decay never score/complete**. **6 nouns, every symbol a NOUN never a status.**
- **Systems:** NO new node. Reuse `_cas_ground_target():688` as the aim (no third path), leave the RTO-gated
  fire path untouched. Add `mark_field(kind, world_pos)` + `_aim_world_target()` on FieldDirector; marks on
  `MissionState.field_marks` (Array[Dictionary]); topo_map renders them like `patrol_location:138`.
  Reset-per-patrol is FREE (`_bank_patrol:1088` already news the state). **FOSSIL: a binocular-marking system
  ALREADY LIVES at `player.gd:154-182` (set_meta + floating Label3D over enemies) — the new verb must ABSORB
  and DELETE it (ADR-023), not run beside it.**
- **Devil:** two dangers — (1) **the §4 probe guards the wrong door:** it firewalls the in-field/command path
  but leaves the DEBRIEF open — the moment `_bank_patrol`/ground-covered tallies marks by kind ("3 camps
  found") that IS the deferred tracker §4 bans (`ADR-029:30`); and CONTACT marks feeding `raise_crisis` =
  route-as-authority creep. **The probe MUST forbid the scorer/AAR/selector from reading marks.** (2) "One
  verb" is really three differently-gated verbs (net/LOS/binocular) and the keyboard is full. **MVP: P2's
  tail, not P1; patrol-local, no imprecision, place-where-you-look until a playtest earns the model.**

## ARBITER RESOLUTIONS

### FM1 — Placement: the split holds (UX, load-bearing)
ROUTE = map-open click-to-place (the plan, no LOS). FIELD MARKS = **world-space aim-and-press only** (the
eyes-on cost; reuses `_cas_ground_target:688`). One shared render layer (`topo_map._overlay`), three inks.
No mode switch. A free M-map click to drop an intel pin is REJECTED — it would void the LOS cost.

### FM2 — One verb, world-inferred noun (the unifying mechanic)
A SINGLE "mark/report" bind (exact key = an ADR-012 implementation detail; find one free bind, do NOT overload
fire/order). On press, the symbol is **inferred from the highest-priority markable thing under the reticle
within LOS** — enemy → CONTACT (+ net call, the report verb); trail → TRAIL; tunnel mouth → TUNNEL; structure
glassed through binos → CAMP; cache/bunker → CACHE; hazard → DANGER. Nothing markable → no-op. The vocabulary
is the WORLD's, not a player menu (no radial, no list — period intent). The game infers the noun; it never
SUGGESTS a mark (game-designer).

### FM3 — Imprecision model (Caleb's non-negotiable lever; deterministic ADR-010; findability-floored)
Build it in P2 (NOT place-where-you-look — that discards the explicit design intent), but as a TUNABLE so a
playtest can dial or zero it without a rewrite. Systems' formula, game's floor:
`error_radius = clampf(BASE + K*range, 0, CAP)` (systems: BASE 3.0, K 0.08, CAP 60 → CONTACT ~5m, CAMP@300m
~13.5m; K/CAP tunable). **Halved when glassing** (binoculars raised). Offset drawn ONCE at placement,
`rng.seed = hash(Vector2i(true_pos)) ^ state.seed_value`, then FROZEN in the mark dict — stably wrong, never
jitters. **FINDABILITY FLOOR (game):** clamp the offset so the mark never crosses a legible terrain edge
(ridge/stream/treeline) — always navigable-to, never precise. Sacrifice named: at extreme range a CAMP mark
can send the player to the wrong side of a clearing — that is the fog-of-war, capped so it is never useless.

### FM4 — Cost/friction (the period lever)
LOS raycast clear to the thing; **ranged marks (beyond ~50m) require the binocular optic raised**; the player
must be roughly stationary (not sprinting). LOS+stillness gated, **never nagged** (no "can't mark" spam —
r4bk affordance is the reticle state, not a scold).

### FM5 — The §4 probe: FOUR clauses, and it must guard the DEBRIEF door (devil's critical catch)
Extends the route's four clauses. A structural probe asserts:
1. A mark is pure `{kind, map_pos, placed_at}` — **NO `completed`/`objective_id`/`cleared`/`found` field.**
2. **The tasking/selector NEVER reads player marks** (`raise_crisis`, `_pick_patrol_location` must not import
   `field_marks`) — a CONTACT mark does not feed a crisis (route-as-authority creep).
3. **The scorer/AAR NEVER tallies marks by kind** (`_bank_patrol`, `compute_score`, ground-covered must not
   read `field_marks`). Ground-covered's "features checked" is measured by PROXIMITY to world features
   (sectors swept), never by counting player marks. ("3 camps found" is the deferred tracker, banned.)
4. **No on-screen mark counter and no floating world marker** for a mark (fairness/§4) — marks live ONLY on
   the modal M-map as grease-pencil.

### FM6 — Fossil-law action (systems' critical catch)
The existing binocular-marking system at `player.gd:154-182` (set_meta + floating Label3D over enemies) is
ABSORBED and DELETED by the new verb (ADR-023) — it is also arguably the "floating objective marker" §4
forbids, so its deletion serves §4 too. Verify the exact behavior at implementation; no parallel marking path survives.

### FM7 — Editing & persistence
Editing: **erase (grease-pencil rub-out) on the M-map** — yes; move = erase + re-mark. Marks never
auto-update (stale = intended fog, ADR-022). Persistence is a **SCOPE CALL for the Summoner** — see open
decisions. Store marks as pure serializable dicts on `MissionState.field_marks` so the MVP is one step from
persistence (bank to a CampaignState AO map at `_bank_patrol`), never a fossil.

## PHASE SLOTTING (the coordinator's explicit question)
**Field marking is PHASE 2, folded with the route pencil as one map-annotation deliverable — NOT Phase 1.**
The report-verb/CONTACT-over-net comes in P2 with the pencil, not in the zero-UI spine (all four architects;
devil explicit). Within P2: route pencil first, then the mark verb + glyphs. **Cross-dependency:** glyph
legibility is gated on the HUD Phase-0 blit seam (glyphs must be prototyped through the real low-res buffer,
UX) — so P2 marking cannot fully land until the HUD buffer decision is unparked. Note this dependency; it does
not block P1.

## ADR (deliverable)
**ADR-022 Amendment A — The Intel Verb & the two player layers:** canonize PLAN (route waypoints, map-click)
vs INTEL (field marks, world aim-press); the report-verb marking mechanic (world-inferred noun); the
imprecision model (FM3, deterministic + findability-floored); the eyes-on/LOS/optic cost; the 6-noun
vocabulary; the four §4 clauses (FM5); and the fossil deletion (FM6). PROPOSED; ratified on Caleb's blessing.
Confirm against ADR-022's existing persistence language when drafting (the game-designer reads `:35-70` as
canonizing forever-persistence — if so, the MVP's reset-per-patrol is an interim owed-persistence step, not
final, and must be labeled as such per ADR-014, not silently shipped as canon).

## TRADEOFFS NAMED
Imprecision can send the player to empty jungle (capped by the findability floor) · the "one verb" is three
differently-gated verbs sharing one bind — input-doctrine care needed (ADR-012) · patrol-local MVP contradicts
ADR-022's persistence canon and must be flagged as interim · glyphs at 8px risk mush — color-code carries the
read · persistence, if blessed, imports a slice of ADR-017 (save-schema + decay).

## WYRM'S AUTONOMOUS SESSION CALLS (2026-07-24, PENDING CALEB'S REVIEW — NOT OWNER-BLESSED)
Caleb granted overnight session autonomy and asked these recorded for his morning review. They are the
Overseer's provisional calls, flagged so a later session never mistakes them for the Summoner's rulings
(same discipline as the false-done-claim hazard). Field marking is still Phase 2 SPEC — NOT built this session.
1. **Imprecision — BUILD the tunable model** (Caleb named it non-negotiable). Deterministic, frozen-at-
   placement, findability-floor clamp per FM3. NOT the devil's place-where-you-look MVP.
2. **Persistence — patrol-local MVP first; bank-to-firebase-AO-map (aggregate/decay, NEVER score) is the
   blessed end-state.** When drafting ADR-022 Amendment A, CONFIRM against ADR-022's actual text — if it
   canonizes forever-persistence, LABEL the MVP as interim/owed-persistence per ADR-014; do not ship it as canon.
3. **Vocabulary — 6 nouns as target** (CONTACT/TRAIL/TUNNEL/CAMP/CACHE/DANGER); resolve down to 5 at the P2
   glyph prototype if DANGER won't read at 8px through the buffer.
ADR-022 Amendment A stays **PROPOSED** — Caleb ratifies.

## STILL OPEN FOR THE SUMMONER (Wyrm did not decide these)
- Whether to accept calls 1–3 above (his review).
- **(Noted, not blocking)** field marking is P2 and its glyphs depend on the still-parked HUD buffer
  resolution decision — it lands after the spine + the HUD Phase-0 seam, not before.
