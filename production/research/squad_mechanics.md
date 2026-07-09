# Squad Command Mechanics — Research & Roadmap

Research into squad-command systems across the tactical-FPS canon, distilled into a
**prioritized, low-bloat upgrade path** for RECONgame's existing squad. Every
recommendation extends the current `AllyBase.OrderMode` enum and `SquadSystem`
F1–F4 layer — nothing here demands a rewrite of the Quake-3-style think/execute AI.

## What we have today (verified baseline)

- `AllyBase.OrderMode { FOLLOW, HOLD, MOVE_TO }`, set via `set_order(mode, pos)`.
- `_evaluate_goals()` (think, 6–7 Hz): suppressed→SEEK_COVER; target+LOS+weapons_free→COMBAT; else IDLE.
- `_execute_idle()` branches on `order_mode`: FOLLOW = close to `follow_distance`; HOLD = settle; MOVE_TO = walk to `order_pos`.
- `SquadSystem._unhandled_input`: F1 FOLLOW ("on me"), F2 HOLD, F3 MOVE_TO (`_aim_ground_point()` ray-march), F4 weapons free/tight toggle. Orders broadcast to all 5 via `_order_all`.
- MOS role automation (Medic/Point/Grenadier/Pigman/RTO) + on-screen text barks.

The bones are already SWAT/Republic-Commando shaped (function-key verbs, a whole-squad broadcast). The gap versus the genre is **formation, context-targeting, and fire-and-maneuver** — exactly the things below.

---

## The genre patterns (what the canon actually does)

| Game | Order surface | The idea worth stealing |
|------|---------------|------------------------|
| **Republic Commando** | 4 context keys (F1 offensive / F2 form-up / F3 secure-where-pointing / F4 return) | One key, meaning changes by what the crosshair rests on. Minimal-input "smart" order. |
| **SWAT 4** | Right-click context menu; "stack up" auto-reports lock state | The *world object you look at* filters the command list (door → stack/breach; room → clear). |
| **Six Days in Fallujah** | 4 "GO! commands": **Suppress / Watch / Move / Form-Up**; hold-button → 3–5 context commands in-world | Buddy-pair fire-and-maneuver from one tap; hold-to-reveal contextual verbs. Closest modern analogue to our target. |
| **Brothers in Arms** | Move / suppress / rally / cover / charge; enemy suppression pie-chart | **Find-Fix-Flank**: your base-of-fire team pins (grey-out meter), you flank. The core loop, not a feature. |
| **Ghost Recon** | Map-issued overwatch + hold-fire, then "open fire" on cue | Pre-position an element on overwatch, trigger the ambush on command. |
| **Full Spectrum Warrior** | Two fireteams (Alpha/Bravo); bound = pick destination **+ firing vector** | Bounding overwatch as a first-class movement mode; you aim the team while it moves. |
| **ARMA 3** | Numbered command tree: 1 Move · 3 Engage (open/hold/disengage) · 7 Combat-mode (stealth/aware/danger) · 8 Formation (column/wedge/line/file/diamond) | Formations + engagement-posture are *separate axes* from movement orders. |
| **R6 Vegas** | Context-sensitive D-pad; "regroup/fall-in/on-me"; rappel/breach prompts | Single context button that reads the situation; explicit regroup verb. |

**Convergent truth:** the best systems keep a tiny verb set but make each verb *context-aware* (look at ground = move, look at enemy = attack/suppress, look at teammate/self = regroup), and treat **formation** and **fire-posture** as orthogonal toggles rather than new orders. That is the design lane RECONgame should stay in.

---

## Prioritized upgrades

Priority = (tactical depth added) ÷ (code + UI risk). Effort is rough dev-days for one person.

### P1 — Context command ("smart order" key) — HIGH value, MEDIUM effort (~1–1.5 d)
A single new key (recommend hold-to-issue on the existing `squad_move` action, or a
dedicated `squad_command`). On press, raycast from camera:
- **Hits enemy hurtbox** → `OrderMode.ATTACK_TARGET` with a `target_override` Node → squad focuses that man.
- **Hits ground** → existing `MOVE_TO` (reuse `_aim_ground_point()` verbatim).
- **Hits nothing / aimed at self** → `FOLLOW` (= regroup/on-me).

**Maps onto existing AI:** add `var target_override: Node` to `AllyBase`. In
`_evaluate_goals()`, *before* the auto `_find_target`, if `target_override` is alive
and in LOS, force it as `target` and go COMBAT. Everything downstream (`_execute_combat`,
aim lerp, burst fire) is **reused unchanged**. Clear override when it dies or on a new
FOLLOW/HOLD order.
**Reuses think/execute:** Yes, fully — only adds a target-selection short-circuit.
**Why first:** it is the single biggest feel upgrade and the connective tissue every
other item below leans on (it gives us "order *that* thing"). Directly serves Pillar 3
(freedom) and Pillar 4 (squad-as-RPG).

### P2 — Follow formations (wedge / column / line / file) — HIGH value, MEDIUM effort (~1 d)
Replace the FOLLOW "spawn-ring + leash" with per-member **formation slots** offset from
the player's facing. ARMA's four shapes cover 95% of need: **wedge** (default patrol),
**column/file** (trail/jungle single-file — very Vietnam), **line** (assault frontage).
- Add `var formation_slot: int` to `AllyBase` and `var formation: int` to `SquadSystem`.
- `SquadSystem` assigns slots 0–4 at spawn; a key (or radial) cycles the shape and toasts it.
- In `_execute_idle()` FOLLOW branch: compute `slot_world = player_pos + rotate(slot_offset[formation][slot], player_yaw)`; `_move_toward(slot_world)` when beyond a deadzone, else `_settle`.

**Maps onto existing AI:** pure execute-layer change; `_move_toward` already exists.
Column/file is a near-free reskin of the same offset table.
**Reuses think/execute:** Yes — think untouched; only the FOLLOW execute target changes.
**Why second:** cheap, and it makes the squad *read* as a fireteam instead of a mob —
massive atmosphere (Pillar 2) return for the line count. Folds "regroup" in for free
(FOLLOW already snaps them to slots; a fast-move flag = R6's "fall in").

### P3 — Suppress order (Find-Fix-Flank enabler) — HIGH value, MEDIUM effort (~1.5 d)
New `OrderMode.SUPPRESS` with `order_pos` = an area/bearing. Ordered men fire toward the
point on a loose cadence **even without a hard-target LOS**, and enemies within a radius
of the beaten zone take `apply_suppression()` each volley (the API already exists on both
`AllyBase` and enemies). This is Brothers-in-Arms base-of-fire: player/Pigman fix, you flank.
- In `_evaluate_goals()`: if `order_mode == SUPPRESS`, force a COMBAT-like posture aimed at `order_pos`.
- Add a `_fire_at_position(pos)` variant of `_fire_at_target()` (same tracer/muzzle/noise/spread code, no `target` node) and, per volley, call `apply_suppression()` on enemies in ~6 m of the impact.
- **Synergy with MOS:** route the **Pigman** (already `fire_rate_mult 1.6`) as the natural suppressor — a "PIG, SUPPRESS THAT TREELINE" context order is pure Pillar-4 flavor.

**Maps onto existing AI:** reuses the entire fire pipeline; only the target source changes
(position instead of node). Suppression decay/seek-cover on the *enemy* side already works.
**Reuses think/execute:** Yes — new state slots into the existing `match current_state`.
**Why third:** unlocks the genre's core tactical loop and makes `weapons_free` and the
Pigman meaningful, but depends on P1's context-key to feel good ("suppress *there*").

### P4 — Bounding overwatch (fire-and-maneuver) — MEDIUM value, MEDIUM-HIGH effort (~2 d)
Full Spectrum Warrior's signature. Crucially, this needs **no new AllyBase behavior** — it
is an *orchestration in `SquadSystem`* composed entirely of existing HOLD + MOVE_TO + the
P3 SUPPRESS posture:
- Split the 5 men into two elements (e.g., 2 base-of-fire / 3 maneuver, Pigman anchors base).
- A `_bound_tick()` state machine: base element holds (weapons_free, optionally SUPPRESS on last-known enemy bearing) while maneuver element MOVE_TOs to the destination in ~15–20 m bounds; on arrival, swap roles; repeat until both reach the objective.
- Trigger via a context command on a far ground point ("BOUND TO THERE"); FSW's "firing vector" = reuse the crosshair bearing at issue time.

**Maps onto existing AI:** zero new ally code — it only *sequences* orders the men already
obey. Arrival detection uses the existing `distance_to(order_pos)` check.
**Reuses think/execute:** Yes — emergent from composed orders; the AI never knows it's bounding.
**Why fourth:** highest wow-factor and most authentically Vietnam-recon, but it is an
advanced layer that only pays off *after* P1–P3 exist (it literally calls them). Build last.

### P5 — Fire posture as a separate axis (optional polish) — LOW effort (~0.5 d)
ARMA/R6 keep engagement posture orthogonal to movement. We already have the
`weapons_free` toggle (F4); extend to a 3-state cadence to match ARMA's stealth/aware/danger:
**HOLD FIRE → RETURN FIRE (only if shot at) → WEAPONS FREE**. "Return fire" = engage only
when `suppression_level > 0` or a squadmate is in COMBAT. Tiny change in `_evaluate_goals`'s
`weapons_free` gate; big stealth-approach value (Pillar 3 — stealth optional).

---

## UI surfacing recommendation (keep it lean)

- **Keep F1–F4** as instant "quick verbs" (muscle memory; matches Republic Commando/SWAT classic). Rebind F3 to route through the new **context raycast** so "move" auto-upgrades to "attack/suppress/regroup" by what you're looking at.
- **Add one context-command key** (tap = smart order; **hold = radial** of 3–5 situational verbs à la Six Days — Move/Suppress/Watch/Bound/Regroup). Radial is the only new widget and can ship after P1–P3 as text-first.
- **Barks already carry it** — the on-screen toast system ("PIG, SUPPRESS THAT TREELINE", "BOUNDING — COVER US") is enough confirmation; no HUD rework required for P1–P3.
- Defer the SWAT-style **door/object context menu** (breach/stack) until interactable doors exist in the AO — noted, not scheduled.

## Suggested build order
`P1 context-key` → `P2 formations` → `P3 suppress` → `P4 bounding` → `P5 fire-posture`.
P1+P2 alone (≈2–2.5 d) already move the squad from "follow blob" to "reads like a fireteam,"
and each later item composes cleanly on the ones before it.

## Sources
- [Republic Commando squad commands (Steam discussion)](https://steamcommunity.com/app/6000/discussions/0/458604254452413692/) · [manual PDF](https://cdn.akamai.steamstatic.com/steam/apps/6000/manuals/Star_Wars_Republic_Commando_Manual-English.pdf)
- [SWAT 4 Controls — StrategyWiki](https://strategywiki.org/wiki/SWAT_4/Controls)
- [Six Days in Fallujah — How to Command Your Team (DualShockers)](https://www.dualshockers.com/six-days-in-fallujah-how-to-command-your-team/) · [GO! Commands overview (official forum)](https://forums.sixdays.com/main/viewtopic.php?t=1518)
- [Brothers in Arms — Basic Gameplay (Four F's)](https://brothersinarms.fandom.com/wiki/Basic_Gameplay) · [Base-of-Fire Team](https://brothersinarms.fandom.com/wiki/Base-of-Fire_Team)
- [Full Spectrum Warrior — Wikipedia](https://en.wikipedia.org/wiki/Full_Spectrum_Warrior) · [GameSpot walkthrough (bounding overwatch)](https://www.gamespot.com/articles/full-spectrum-warrior-walkthrough/1100-6101763/)
- [ARMA 3 Field Manual — Commanding](https://community.bistudio.com/wiki/Arma_3:_Field_Manual_-_Commanding) · [Commanding the AI (gamepressure)](https://guides.gamepressure.com/armaiii/guide.asp?ID=21605)
- [Ghost Recon Wildlands — AI squad commands (Steam)](https://steamcommunity.com/app/460930/discussions/0/5413843407457249227/) · [Bounding overwatch — Wikipedia](https://en.wikipedia.org/wiki/Bounding_overwatch)
- [Rainbow Six: Vegas — Wikipedia](https://en.wikipedia.org/wiki/Tom_Clancy%27s_Rainbow_Six:_Vegas)
