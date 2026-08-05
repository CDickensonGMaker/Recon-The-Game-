# SYSTEMS-DESIGNER — what is actually a system, and where it lives

## The structural fact that decides most of this

`demo_game.gd` is **not a level**. It is a 496-line *driver* that sets `GameFlow.demo_mode = true`
(`demo_game.gd:98`) and lets `GameFlow` build `game_world.tscn` through the same builder the patrol
uses (`game_flow.gd:582`, branching only at `:606` between `plan_demo_world` and
`plan_patrol_world`). ADR-028's one-world-build-path is real in code.

**Consequence: there is no "migrate to demo" and separately "migrate to game world."** Anything
landed in `MissionGenerator` / `SitePlanner` / `GameWorld` / the autoloads appears in BOTH, the same
day, with no second wiring job. Caleb's instinct — "because those are derived from each other" — is
correct, and it is the cheapest fact in this council.

## Fire support: nothing to migrate. It is one system already.

`support_fire_range.gd:91` wires `FireSupportBench.wire(self, player, FIELD)` and thereafter only
*calls* the shipped director (`request_fire_support` at `:346, :720, :724`;
`field_director.gd:508`). It computes no sheaf, no delay, no round count.

Every tuned number he has been turning lives in shared code and is therefore already in the demo and
the patrol world:

| Value | Where | In the shipped world? |
|---|---|---|
| Arty sheaf 18 m, 8–12 rounds | `fire_plan.gd:15-54` | yes |
| Mortar sheaf 8 m | `fire_plan.gd` | yes |
| Napalm 5 drops · CBU 16 bomblets / 22 spread · WP 3 rounds · Spectre dispersion 4 m | `fire_plan.gd` | yes |
| Arty shell 260 max / 90 min (his 8/4 retune) | `field_director.gd:841` `_arty_impact` | yes |
| Danger-close 45 m, 5 s confirm | `field_director.gd:351, :353` | yes |
| Enemy accuracy −15 % at the player (`PLAYER_TONE_MULT 1.15`) | `ai_marksmanship.gd` | yes |
| Explosion visuals ×5 | `GunFX.ORDNANCE_VISUAL_MULT` | yes |
| No-overfly 40 m | `field_director.gd _no_overfly_axis` | yes |

The only divergences are **deliberately bench-only**: unlimited stock
(`fire_support_bench.gd:156-157` all 9s vs the shipped `field_director.gd:333` `mortar: 2`),
`_hunter_pool = 0` to keep the inert host from escalating, and `_cas_cooldown = 0.0`
(`support_fire_range.gd:718, :722`) to bypass the 10–25 s net cooldown. **None of these may migrate**
— they are the lab's clamps, and shipping them would delete the fire-support economy.

**Verdict: item CLOSED. He should stop spending attention on "getting RTO strikes into the game."
They are in the game. What he has not done is *feel* them there** — see the technical-director on
the deform budget, which is the one place the demo will differ from the bench.

## Destruction: three tiers already exist, and only one is missing

1. **Firebase parapet** — 80 segments at **140 HP** each (`firebase_v3_destructibles.json`;
   `site_planner.gd:1490-1515`), group `fsb_parapet`.
2. **Firebase structures** — bunkers 260 / MG bunkers 260 / sleeping bunkers 260 / towers 180 /
   sandbag stacks 90, adopted by **mesh-name prefix** with no Blender re-export
   (`site_planner.gd:1552-1558`, `_wire_structure_destructibles :1561`, `_adopt_structure :1595`).
3. **Everything else in the AO** — village huts, the village centre, caches, tunnel mouths, VC camp
   structures, the temple and its statues — go through `place_structure`
   (`site_planner.gd:162-200`), get a plain `StaticBody3D`, get ballistic tags, get nav blockers,
   and get **no HP and no place on the blast bus**.

Tier 3 is the gap, and the machine that closes it already exists and ships: `_adopt_structure`.
This is not a new system. It is calling a shipped function from a second place.

## The one dial that must NOT migrate

`SPOT_RANGE 72.0` / `SPOT_CONE_DOT −0.17` / `SPOT_GAIN 0.85` (`ai_stress_arena.gd:218-220`) look
like a spotting system the shipped world lacks. They are not. The shipped `EnemyBase` has a full
perception stack — `_update_perception` (`enemy_base.gd:1055-1136`), awareness accumulator,
`SIGHT_CAP_OPEN 140` / `SIGHT_CAP_JUNGLE 45`, FOV cone, smoke and terrain LOS.

The arena's `SPOT_*` block exists because the arena spawns its US grunts through
`AllyBase.spawn_ally` and never clears `squad_member`, so the **buddy rule** at
`enemy_base.gd:1071-1079` makes them invisible to the VC until COMBAT. The arena hand-feeds
awareness at `:1968` to work around its own spawn choice.

**Migrating these constants would bolt a second perception authority onto a codebase that already
has one — the exact fossil ADR-023 forbids.** Refused.

(Note also that the arena's comment at `:1954-1955` is stale: it claims core perception exempts all
allies, but `enemy_base.gd:1066-1079` was narrowed to exempt only the player's own squad. A
garrison defender — `garrison_defender.gd:57` sets `squad_member = false` — is perceived normally.)
