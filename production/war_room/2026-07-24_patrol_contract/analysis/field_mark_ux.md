# UX-DESIGNER — The Player Field-Marking Layer

**Lens:** the player-facing surface of typed grease-pencil intel marks and how they reconcile with the
route-pencil on the SAME M-map (`scripts/ui/topo_map.gd`).

All citations verified against `topo_map.gd` (read in full) and the two decrees.

---

## The one insight that resolves everything: the placement split IS the reconcile

The map already renders three inks by world-position through one function (`_world_to_map:127`) inside
one paint pass (`_draw_overlay:132`): roads (`_draw_roads:115`, contour ink), the CO's red sweep circle
(`:138-144`, `Color(0.62,0.15,0.12)`), the player's green arrow (`:146-156`, `Color(0.2,0.8,0.25)`).
Route and field marks are the fourth and fifth things drawn in that same pass. **One render layer,
already exists.** The question is only INPUT and VOCABULARY.

---

## 1. PLACEMENT — the clean split HOLDS, and it is load-bearing, not cosmetic

**ROUTE (the PLAN, no LOS) = M-map click-to-place.** Authored map-OPEN, in the pencil mode R3 already
decreed (LMB place / Backspace undo / Delete clear on `topo_map._overlay`). The plan is a paper act; the
map is the paper.

**FIELD MARKS (INTEL, LOS-gated) = world-space aim-and-press ONLY.** Authored map-CLOSED, reusing the
FieldDirector ray-march (`_cas_ground_target:688`, per briefing) — **never a third aim path** (systems
ruling). Aim at the thing, press, the ray-march hit `Vector3` is stored, `_draw_overlay` renders it next
frame via `_world_to_map:127`.

**Does it hold? YES — and it is the CLEANEST possible enforcement of the period "eyes-on cost" lever.**
You physically cannot drop a CONTACT from the map, because the map is not a targeting device — it is
memory (ADR-022). To mark a thing you must be looking at it down the world. The friction is not a rule
bolted on; it falls out of *where the input lives*. No "must-be-still" gate needed for MVP — LOS +
aim-and-press is already the cost. (Add stillness later only if binocular marks feel too cheap.)

**Two input methods, by construction never colliding:** map-open you click the map; map-closed you aim
the world. You are never doing both at once, so route-clicks and mark-presses never contend for the same
button or the same cursor. **The split placement resolves Q4 (reconcile) for free.**

**Imprecision model (the ranged-mark lever):** store the mark at the ray-march hit, but offset it by a
range-scaled jitter seeded deterministically from the op seed + mark index (ADR-010-clean). Point-blank
CONTACT lands true; a camp glassed at 400m lands ~15–30m off. Render distant marks with a **dashed ghost
ring** around the glyph = "estimated position." The map lies a little, on purpose, and tells you it is
lying.

---

## 2. ICON VOCABULARY — FIVE glyphs, hand-drawn grease, not game icons

Keep it SMALL. **CONTACT · TRAIL · TUNNEL · CAMP · CACHE.** (Drop bunker/danger/casualty for MVP —
bunker folds into CAMP, danger is what CONTACT means, casualty is a HUD event not a map note. Five is the
legibility ceiling in the low-res buffer, see §risk.)

Every glyph is drawn with the **two-pass offset-wobble trick the sweep circle already uses** (`:141-142`
draws the arc twice, second pass offset `Vector2(1.5,1.0)` at lighter weight, to read as a shaky hand).
All in a **distinct player grease ink** — dark chinagraph `Color(0.15,0.13,0.10,0.85)` — so the map holds
THREE vocabularies at a glance: **green = plan, red = the CO's order, grease-black = your intel.** Each
carries a scrawled 3-letter label via `draw_string` exactly like "SWEEP" (`:144`).

| Glyph | Grease-pencil form (draw primitives) | Label |
|-------|--------------------------------------|-------|
| CONTACT | scratchy double-stroke arrowhead / jagged X (`draw_polyline`, wobble pass) | "EN" |
| TRAIL | row of short cross-ticks along heading (`draw_line` ×3) | "TRL" |
| TUNNEL | small "O" with a downward stab-tick (`draw_arc` + `draw_line`) | "TUN" |
| CAMP | scrawled triangle / tent (`draw_polyline` closed, wobble) | "CMP" |
| CACHE | box with a slash (`draw_polyline` + `draw_line`) | "CCH" |

~10–13px, no fills, no anti-aliased curves — pencil strokes, not vector art. Distant marks get the dashed
ghost ring (§1).

---

## 3. EDITING — erase YES, move = erase+re-mark, stale = intended fog

**Erase: YES**, grease rub-out, map-OPEN only (you clean your map at the map, not down the barrel).
Reuse the route's Delete/Backspace idiom; a right-click "rub" removes the nearest mark under the cursor.
**Move: there is no drag** — a grease pencil doesn't slide. Move = erase + re-mark (which re-pays the LOS
cost, correctly). **Stale marks mislead, and that is CORRECT** — the sweep-circle precedent is explicit
and verbatim law here (`:136-137`: "it never checks off, never updates"). Marks NEVER auto-update, never
re-project, never delete themselves when the camp moves. A wrong CAMP mark in empty jungle is honest
fog-of-war (ADR-022, "the map is your memory"). Do not build any freshness/decay system — that would BE
the tracking §4 forbids.

---

## 4. RECONCILE — one map, NO mode switch to READ; a single optional erase toggle to EDIT

Both layers are always drawn together in `_draw_overlay:132`; you never toggle to "see intel vs plan."
They read apart by **ink + form**, no legend needed:
- **PLAN** = green **connected polyline**, numbered nodes (R3 — number = identity, never progress).
- **INTEL** = grease-black **discrete stamps**, no connecting line, each a distinct glyph.
- **CO ORDER** = red grease circle (existing `:138-144`).

Continuous-green-line vs scattered-black-stamps vs red-ring is unmistakable at a glance. **No mode switch
for placement either** (§1: route is map-open, marks are map-closed). The only mode is an optional
map-open ERASE toggle, and even that can be right-click-to-rub with no explicit mode. One pencil, multiple
stamps, three inks — resolved.

---

## 5. HUD RECONCILIATION — the report verb dissolves into core HERE

CONTACT is the one glyph that is dual-channel: it **drops a map stamp AND calls over the net** — the
compass order-line / toast (`mission_hud.gd:302`, per R5). The other four glyphs are **silent map stamps
only** — a note-to-self, no net traffic (which is exactly what keeps them §4-clean: a private scribble,
not a broadcast objective).

**One verb, whole vocabulary:** aim + press; context picks the glyph AND whether it goes over the net
(enemy → CONTACT + net; terrain feature → silent stamp). **CONFIRMED: this dissolves the parked HUD
Phase-4 "overloaded report verb" (#3) into the core loop** — the report verb IS the field-mark verb IS the
squad-order verb the loop decree already pulled forward (period-HUD synthesis §RE-SLOTTED, patrol synthesis
R5). No new persistent HUD element; CONTACT rides the already-load-bearing order-line, which must survive
`hardcore`/SPARSE as an event tell (R5.1, `mission_hud.gd:302`).

---

## §4 GUARDRAIL (the hard one) — marks are inert paint, probed

A field mark is pure draw data: a `Vector3` + a glyph enum in a debrief-only array, rendered like the
sweep circle. **No completion field, no checkable state, no objective label, ever.** A TUNNEL mark is
"come back and go inside," never "OBJECTIVE: CLEAR TUNNEL." Structural probe (same family as R2):
1. No per-mark `complete`/`objective`/`checked` field anywhere on the mark struct.
2. Marks live only in the debrief-only array; no in-field HUD counter of marks (a "3 tunnels found"
   readout is the tracking §4 forbids — the instant it's on-screen it's an objective tracker).
3. The tasking-string builder (`_advance_route_tasking`, R2 family) NEVER references a player mark as a
   target — command tasks features/ordinals (R2.3), it does not read the player's grease.

This keeps ADR-029 §4 and ADR-022's two-layer law intact: the player writes on the intel layer; nothing
the player writes is promoted to the command/objective layer.

---

## Phase slotting (my lens)

- **CONTACT-only, aim-and-press → map stamp + net** comes with **the SPINE (Phase 1)** — it IS the report
  verb the loop already pulls into core, and it needs zero new UI beyond one `_draw_overlay` branch.
- The **full 5-glyph vocabulary + erase + ghost-ring imprecision** rides **Phase 2 (the route pencil)** —
  same `_overlay` pencil pass, same authoring session, gated on the same "is it worth drawing" playtest.

## Persistence (scope call — recommend)

**Recommend: marks persist to the wire-AAR and seed a firebase ACCUMULATED map (ADR-017 persistent
province), NOT reset each patrol.** This is the multi-patrol AO-knowledge payoff and it deepens ADR-022
("the map is your memory" → the firebase remembers too). BUT accumulated marks must inherit the
never-update law — a three-patrols-old CAMP mark that's now empty is *the best fog-of-war the game can
produce*. Caleb rules; I recommend persist-and-never-refresh.

## ADR-022 amendment

Canonize: the player grease-pencil layer holds TWO authoring methods — **map-click (route, the plan)** and
**world-space aim-and-press (field marks, the intel, LOS-gated)** — one render layer, three inks
(green plan / red command / grease-black intel), and **nothing on this layer ever checks off or updates**
(the `:136-137` sweep law generalized to every player mark).

---

## THE SINGLE BIGGEST UX RISK

**Glyph legibility in the PSX low-res authored buffer.** The period-HUD decree (ADR-030 draft) blits the
UI through a 640×480 / possibly 320×240 nearest-filter buffer at 8px. Five hand-drawn grease glyphs at
~10px on a 512px map, then downsampled through that buffer, risk mushing into indistinguishable blobs —
CONTACT vs CAMP vs CACHE become the same smudge, and a mis-read intel mark is worse than no mark. Combined
with deliberate positional imprecision (§1), a smudged mark in the wrong spot reads as a **bug, not
fog-of-war**. Mitigate hard: cap at 5 maximally-distinct silhouettes, lean on the three-ink color code to
carry identity before form, keep the scrawled 3-letter label, and **prototype the glyphs THROUGH the
Phase-0 blit seam** — do not design them at native 512 and hope they survive the downscale.
