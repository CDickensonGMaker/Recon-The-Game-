# ADR-012: Input doctrine: interact key, shared keys, squad orders
**Date:** 2026-07-10 · **Status:** Accepted (War Room audit #2) · **Supersedes/Amends:** Amends PLAYER_MANUAL.md (keybind table, 9 gaps + stale T/Y row); codifies the key-6 guard pattern from Audit #1's decree item 1; supersedes the hub_controller.gd:4 header comment's "[E]" claim.

## Context

The game has one interact action (`interact`, physical keycode 70 = F, project.godot:230-233) but three
different stories about what key the player should press. The hub — the newest, most load-bearing flow —
displays `"ENTER THE TOC - GET BRIEFED [E]"` (hub_controller.gd:47) and `"BOARD THE BIRD [E]"` (:53)
while the listeners two lines below each (:48, :54) check only `Input.is_action_just_pressed("interact")`
— F. A new player at the TOC door presses E, nothing happens, and the first minutes of the campaign
teach distrust. The loading tip `"LOOT THE DEAD [E]"` (game_flow.gd:145) repeats the lie for field
looting, which is also `interact`=F (player.gd:629). PLAYER_MANUAL.md:14 asserts "E doubles as context
interact at prompts" — true in exactly one place: the Huey ride's `context_interact_pressed()`
(insertion_ride.gd:104-107) deliberately accepts `interact` OR raw `KEY_E` while a ride prompt is up.
The drift mechanism is visible in hub_controller.gd:4's own header: "copied from
insertion_ride._poll_board — distance scan + [E]" — the prompt string was copied, the E-handling was not.

Second force: shared physical keys. Key 6 is deliberately double-bound — `cbu_strike` (project.godot:131)
and `place_claymore` (:176) both sit on physical 54 — and it is the one collision done right: claymore
placement refuses while the fire-support net is open (`not MissionDirector.any_fire_menu_open`,
player.gd:622-623), and CBU only fires while it is. Smoke [5] carries the same guard (player.gd:610).
But three siblings do not: flare [7] (`pop_flare`, player.gd:633), rations [9] (`use_ration`, :614), and
repair kit [0] (`use_repair_kit`, :616) fire unguarded, so digits typed into the fire-support menu can
also eat a ration or pop a flare. One pattern, applied to half its family.

Third force: squad orders. Bead r4bk (playtest 2026-07-08) reported F1-F4 squad orders "gone" — bindings
existed, system was in the tree, but with zero HUD affordance the player could not tell a dead feature
from an undiscovered one. The mitigation shipped as dual-binding: C/H/X/N alongside F1-F4
(project.godot:196-217), insuring against laptop Fn-lock keyboards. PLAYER_MANUAL.md:23 still lists
F1-F4 only, part of 9 known manual gaps (9/0/V/P/F5/F9/Esc/CHXN missing; T/Y row stale at :21 —
ux_designer.md:130-132).

## Decision

- **INTERACT IS F, everywhere.** The `interact` action stays bound solely to physical F (project.godot:230).
  - Every prompt string MUST name the key its listener actually checks. hub_controller.gd:47,53 change
    `[E]` → `[F]` (or the listeners gain E — but pick one and make string match listener; the decree's
    default is F). game_flow.gd:145 tip becomes `LOOT THE DEAD [F]`.
  - E remains lean-right (project.godot:106) plus context interact ONLY where explicitly patched: the
    insertion-ride pattern (insertion_ride.gd:107, `interact` OR raw `KEY_E` during ride prompts). This
    pattern MUST NOT be copied without its input handling — copying the prompt text while listening only
    to `interact` is the exact bug this ADR exists to kill (see hub_controller.gd:4's header).
  - PLAYER_MANUAL.md:14's "E doubles as context interact at prompts" is corrected to name the Huey ride
    as the sole exception.
- **SHARED KEYS require context guards.** The key-6 doctrine (cbu_strike + place_claymore, both physical
  54, guarded by `MissionDirector.any_fire_menu_open` — player.gd:622-623 / mission_director.gd) is the
  binding pattern: one physical key, the open context owns it.
  - Stragglers gain the same guard: `pop_flare` [7] (player.gd:633), `use_ration` [9] (:614),
    `use_repair_kit` [0] (:616) each add `and not MissionDirector.any_fire_menu_open`.
  - Test: with the fire-support net open, no digit press may consume a consumable or place a device.
- **SQUAD ORDERS stay dual-bound.** F1-F4 primary + C/H/X/N secondary (project.godot:196-217) are both
  permanent; neither may be removed. The secondaries are laptop Fn-key insurance from r4bk.
  - The r4bk law applies: any order surface MUST have a visible HUD affordance. A feature without a
    visible affordance does not exist. Squad-order hints ship with the player-state HUD layer (decree
    build-order item 3, bead fmc8).
- **THE MANUAL IS PART OF THE INPUT SYSTEM.** The full keybind table lives in the UX analysis
  (ux_designer.md, "Keybind reality table") and PLAYER_MANUAL.md; the manual MUST be corrected: add
  9/0/V/P/F5/F9/Esc/CHXN, fix the stale T/Y fire-support row (:21), fix :14 and :23. Any future binding
  change updates the manual in the same commit or the change is incomplete.

## Consequences

**Buys:** first-contact trust — the hub prompt, the game's opening interaction, tells the truth; a single
testable rule ("string names the listener's key") that a grep can enforce; the fire-support net stops
leaking presses into consumables; squad orders survive every keyboard layout and, once the HUD hint
lands, become discoverable instead of merely bound.

**Costs (named, per council law):** E is demoted — players trained by other shooters to press E will
press the wrong key until muscle memory adapts; we sacrifice genre convention for internal consistency.
The ride's E-alias survives as a permanent asterisk in the doctrine — one exception that must be
documented forever or it becomes the next drift vector. Dual-bound squad keys spend C/H/X/N, four prime
keys now unavailable for future features. Guarding 7/9/0 means a player genuinely trying to eat a ration
mid-fire-mission cannot; the net owns the keyboard while open.

**Work created:** [E]→F string fixes ride in the HUD-layer PR (decree item 3, bead fmc8 — ux_designer.md
scopes it at ~15 minutes); guard additions at player.gd:614,616,633; PLAYER_MANUAL correction lands in
decree item 7 (LAW & LEDGER CLEANUP). Verification per ADR-015's law: prompt-truth checked in PLAYTEST R3
(bead ida9), not by comment.

## Evidence

> **EVIDENCE RE-VERIFIED 2026-07-19 — the DECISION above is unchanged and still law.** The block below
> was written 2026-07-10 and its pointers have rotted. Re-measured today:
> - `project.godot:245` — `interact` (was cited `:230-233`). **Still true.**
> - `project.godot:121` — `lean_right` (was cited `:106-109`). **Still true.**
> - `project.godot:211-231` — `squad_follow/hold/move/fire_toggle` each dual-bound C/H/X/N +
>   F1–F4 (physical 67/72/88/78 + 4194332–4194335), was cited `:196-217`. **Still true — this is the
>   ADR's surviving substantive rule.**
> - `scripts/main/hub_controller.gd` and `scripts/missions/insertion_ride.gd` — **both DELETED.** Every
>   line cited against them (`hub_controller.gd:4,47,48,53,54`, `insertion_ride.gd:104-107`) points at
>   nothing. The `[E]`-vs-`interact` mismatch they evidenced no longer exists to fix.
> - The `PLAYER_MANUAL.md:23` fix this ADR ordered at `:30` **was never done**; corrected 2026-07-19.

- project.godot:230-233 — `interact` = physical 70 (F), single binding. VERIFIED
- project.godot:106-109 — `lean_right` = physical 69 (E). VERIFIED
- hub_controller.gd:47,53 (scripts/main/) — prompts print `[E]`; :48,:54 listen `interact` only. VERIFIED
- hub_controller.gd:4 — header admits pattern copied from insertion_ride without the E handling. VERIFIED
- game_flow.gd:145 (scripts/main/) — `"LOOT THE DEAD [E]"`; looting is `interact` (player.gd:629). VERIFIED
- insertion_ride.gd:104-107 (scripts/missions/) — `context_interact_pressed()`: `interact` OR raw KEY_E. VERIFIED
- project.godot:131-134 + :176-179 — cbu_strike and place_claymore both physical 54. VERIFIED
- player.gd:610, 622-623 — smoke and claymore guarded by `any_fire_menu_open`; :614 (`use_ration`),
  :616 (`use_repair_kit`), :633 (`pop_flare`) unguarded. VERIFIED
- project.godot:196-217 — squad_follow/hold/move/fire_toggle each dual-bound C/H/X/N + F1-F4
  (physical 67/72/88/78 + 4194332-4194335). VERIFIED
- PLAYER_MANUAL.md:14 (E claim), :21 (stale T/Y), :23 (F1-F4 only). VERIFIED
- Bead RECONgame-r4bk — squad controls "gone" playtest; origin of the affordance law. VERIFIED
- production/war_room/analysis/ux_designer.md — keybind reality table, Drifts 1-2, manual gap list.
- production/war_room/synthesis.md — decree build-order items 3 and 7.

## Related

- ADR-008 (walkable hub — the surface where the [E]/F lie lives), ADR-015 (process/verification laws —
  governs how these fixes close), ADR-001 (3D renderer, context for hub ratification).
- Beads: RECONgame-r4bk (affordance law origin), fmc8 (HUD layer carrying the fixes), ida9 (PLAYTEST R3
  verification gate).
- Pillars served: Pillar 4 (the squad is the RPG — orders must be usable and visible) and the audit's
  process finding: presentation must not drift behind simulation; a prompt that lies is worse than no
  prompt.
