# DECREE — The Period HUD (authored-buffer UI doctrine)

**Session:** 2026-07-24 · **Arbiter:** recon-overseer · **Status:** PROPOSED — awaits Summoner blessing.
Nothing here is built or blessed. This is a planning-gate decree.

**RE-SLOTTED BY THE PATROL CONTRACT (2026-07-24, see `../2026-07-24_patrol_contract/synthesis.md`):** the
core-loop decree sits UPSTREAM of this HUD. It confirms the loop adds ZERO persistent HUD elements (the four
stand), makes the compass **order-line load-bearing** (command's tasking voice — must name a feature/ordinal,
must survive hardcore/SPARSE as an event tell), and **pulls the parked Phase-4 items forward into the core
loop**: map-as-object (#4) and the report verb (#3, = the squad-order verb) become core, the pre-patrol
planning screen (#5) is DISSOLVED into the existing M-map (no separate screen), keyed radio (#2) is likely
unneeded for the loop MVP; only researched identifiers (#1) stays pure polish. A new TRANSIENT OP-state
element (top-right, 8px) appears during the OP-hold setpiece only. Open-decisions #1 (buffer resolution) and
#3 (Phase-0 spike) below are UNAFFECTED and still await the Summoner.

**Framing (Summoner correction, mid-session):** the `.dc.html` handoff is *research, not law*. It is
adjudicated here as a strong proposal, free to be challenged. Final UI direction = handoff + Caleb's
own period-FPS research + this council, blessed by Caleb. Therefore every EXACT number in the handoff
(coords, palettes, identifiers, the deliberate artefacts) is treated as PROVISIONAL, and the build is
designed to make those trivially swappable (palette + layout as data), so research drops in without rework.

## Council verdicts (full analyses in ./analysis/)
- **Technical-director:** ADOPT the SubViewport pipeline — 640×480 SubViewport (`disable_3d`,
  `transparent_bg`, `UPDATE_ONCE` driven at 15Hz) → nearest-filter TextureRect blit at a cached integer
  scale N from device height → a top CanvasLayer scanline ColorRect sampling `SCREEN_UV` in device pixels.
  The 640 grid and the 3D `scaling_3d/scale=0.75` do **not** stack (the scaler only touches the 3D pass).
  Font = `FontFile` bitmap atlas 8px + native 32px digits, smoothing/subpixel/hinting FORCED off (4.7
  gotcha). **#1 risk: `window/stretch/mode="canvas_items"` stamps a non-integer transform on every
  CanvasLayer — prototype the stretch-neutralised blit FIRST or nothing above it matters.**
- **Devil's-advocate:** two dangers — (1) the shipped 1280×720 base can't fit a 2× 4:3 buffer; force a
  target-resolution decision; (2) the fossil trap is worse than it looks — four elements split across TWO
  CanvasLayers both built on `ReconUI`, which is banned in-game but KEPT for menus, so it can't be deleted
  and a naive buffer births a third ammo drawer.
- **UX:** four-element cap survivable (14/26 affordances re-home as transients/sounds; `slot_indicator`
  fossil dies). Biggest r4bk casualty = the **bleed-out clock** (only numeric death signal). Re-home as a
  state-gated blinking transient + heartbeat sound. Density NEVER suppresses event tells. `hardcore != SPARSE`.
- **Game-designer:** CONDITIONAL YES — most on-Pillar-2 UI decision the project has made. Keep name
  truncation (add naming-collision probe). **Cut the "MAGS 00 at 100" clause — clamp at 99** (`00` reads as
  empty = combat-critical lie). Pre-patrol planning screen vs ADR-029 needs a Summoner ruling.

## ADR / Pillar adjudication (the Summoner's explicit question)
- **Forward+ (ADR-026 Amdt A):** NO conflict. HUD SubViewport is 2D (`disable_3d`); the 3D pass is
  untouched; the two scalers do not stack. The buffer is *transparent* — the 3D world fills the screen
  underneath, so there are no black bars and **3D fill cost is unchanged** (it is driven by the monitor res
  in fullscreen today, not by the 640 base — the devil's "raising the window grows fill" only bites if we
  change fullscreen behaviour, which we do not).
- **PSX aesthetic (ADR-001):** REINFORCED. `default_texture_filter=0` and `scaling_3d/mode=5` (nearest)
  already ship; an authored low-res nearest HUD is consistent, not contradictory.
- **Existing UI ADR:** none governs the HUD render pipeline. This doctrine becomes a NEW **ADR-030
  (Proposed)** — drafted now, ratified only AFTER the Phase-0 spike proves the seam and Caleb blesses.
- **Fossil law (ADR-023):** binding. This REPLACES the two HUD draw paths; the old Label paths + the
  `hardcore` compass block + `slot_indicator` are DELETED, not paralleled, and a ratcheting probe enforces
  one ammo drawer.
- **r4bk law:** preserved by re-homing event tells as transients in the SAME buffer; sub-rule added —
  **event tells (bleed, jam, danger-close, off-net) are never suppressed by the density setting.**
- **ADR-029 (no briefing UI):** the pre-patrol PLANNING screen is the one real tension → **Summoner rules
  on content:** your-own-map/kit = legal (Pillar 3 / ADR-022); objectives/offers = the deleted loop in a
  period font = illegal.
- **ADR-022 (map is memory):** the report-verb + map-cost items DEEPEN it — legal only if a report stamps
  the OBSERVED layer, never the player's grease-pencil. **ADR-012 (input):** keyed radio submenus already
  ARE the game's pattern; a radial wheel would be the anachronism.

## Where the council DIVERGES from the handoff (now licensed by the reframe)
1. **MAGS clamps at 99**, never shows "00". 2. **Danger-close cannot be one 8px line** (~52 chars) — split
metrics from the warning; carry "danger" by colour + blink + FO voice. 3. **`hardcore` stays a difficulty
axis** (couples to bleed-rate/save), separate from the display-density axis; both kept, orthogonal.
4. **"No eased transitions anywhere"** adopted in full: mandatory on the 4 persistent elements; transient
tells become blink/instant — naming the cost (the hitmarker/slot-slider tween polish dies). 5. **The five
open items are a research-absorbing LATER EPIC**, not this build. 6. All exact numbers are PROVISIONAL.

## THE PHASED PLAN (spike-gated)
**Phase 0 — THE SEAM (spike; GO/NO-GO for the whole doctrine).** Prove a transparent 640×480 SubViewport
blits nearest at integer scale over the Forward+ world despite `canvas_items` stretch, and that the scanline
samples at device pixels. Decide target-res handling (design at 1080p → 2×; 1440p → 3×; 720p degrades to 1×,
accepted). No HUD content. Output: the blit seam + a `hud_buffer` node graph + ADR-030 draft.
**Phase 1 — Font + palette tokens.** 8px atlas (+32px digits) FontFile, smoothing/hinting off, advance
table; the three non-reconciling palettes as constants (NOT unified). 1:1 render probe.
**Phase 2 — The four elements + fossil kill.** Author compass/roster/ammo/reticle into the buffer; migrate
`hud.gd` signal wiring to feed it; DELETE old Label draw paths (hud.gd ammo/mag/gren/med; mission_hud
compass/roster), the `hardcore` compass block, and `slot_indicator`; keep the controllers; add the
one-ammo-drawer ratcheting probe. `ReconUI` untouched for menus.
**Phase 3 — Transient tells re-homed (r4bk).** bleed clock (blink + heartbeat), jam, danger-close (split),
off-net radio token in the RTO cell, hitmarker, damage-direction, toast, slot slider, action ring,
field/heal prompts — all in the buffer at 8px, instant/blink. Density FULL/SPARSE/NONE in the pause menu,
orthogonal to hardcore, event tells never suppressed. Amendments applied (MAGS 99, name-collision probe).
**Phase 4 — LATER EPIC (PARKED; gated on Caleb's research + blessing).** researched identifiers · keyed
radio submenus · overloaded report verb · map-as-object-with-cost · pre-patrol planning screen. Each = its
own war-room + ADR. Pre-patrol planning blocked on the ADR-029 content ruling.

## Tradeoffs named (no free lunch)
One extra fullscreen pass/frame on the perf-bound Intel UHD floor (mitigated: 15Hz update, cheap scanline) ·
either a fragile per-layer stretch inversion or a global stretch change that regresses menu scaling (Phase-0
resolves which) · lost eased-motion polish · 720p loses the CRT upscale · SPARSE can't be default until squad
barks carry wound/reload state (ship FULL default) · the fossil migration is delicate (controllers live,
views die in the same change).

## OPEN DECISIONS FOR THE SUMMONER
1. **Target resolution** — bless "design at 1080p, integer-scale by device height, 720p → 1× fallback"?
2. **Pre-patrol planning** — is it player's-own-map planning (legal) or briefing/objectives (ADR-029 illegal)?
3. **Phase 0 first?** — bless spending a spike to prove the blit seam BEFORE committing the doctrine / ADR-030.
4. **Provisional numbers** — confirm we build the pipeline data-driven and hold exact coords/palettes/
   identifiers open for your period-FPS research to fill.
