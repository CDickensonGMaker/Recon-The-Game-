# SILENT DEFAULTS — the register, 2026-08-12

**A silent default is a value the code invents when it does not know the answer, and then never
mentions.** It is not a bug: the game runs. It is worse — it is a decision nobody made, standing
in for one somebody should have, and it survives every grep because nothing about it looks wrong.

This is the FOSSIL LAW pointed at behaviour instead of at dead code. A fossil is a lie about what
the code *means*; a silent default is a lie about what the code *knows*.

## WHY THIS REGISTER EXISTS

**Five were found in a single day, each loud in effect and silent in logging:**

| Found | The stand-in | What it actually did |
|---|---|---|
| `destructible.gd` `BLAST_FOR` | fell through to `explosion_heavy` | a barbed-wire picket died with a ~111m artillery fireball; a 42-card wire belt was 42 artillery bursts |
| `vo_manager.gd` `_load()` | missing wav = silent no-op | a mistyped line id was a permanently mute soldier; 23 recorded lines never played, for months |
| `combat_manager._blast_multiplier` | first clear point returns 1.0 | the entire cover-defeat system underneath never ran; a man in a bunker took what a man in the open took |
| `nav_baker` `agent_max_climb` | `floorf` + float32 | a 0.4m step silently became 0.2m; every crater rim was a cliff |
| `collision_table.get_entry` | `{"box": Vector3(3,2,3)}` | a 12m HQ tent would get a 3m nav carve and men would walk through canvas |

Four of the five were found by chasing an unrelated symptom. **None announced itself.**

**Context measured during the sweep: 130 of 192 script files contain no failure logging at all.**

## THE RULE

> When code cannot determine a value, it must either **fail loudly** or **log once, naming the
> consequence**. A stand-in that is never mentioned is forbidden.

`collision_table.is_soft()` is the model to copy — it has warned correctly all along, which is
exactly why `get_entry()` sitting beside it in silence went unnoticed.

---

## THE REGISTER — dangerous, ranked by blast radius

Swept 2026-08-12. **None of these are fixed.** Each sits in a file another agent held at the time.
Ranked by how much breaks and how quietly.

1. **`scripts/combat/hitzone_builder.gd:107-112`** — invents body dimensions when a bone is not
   found. Wrong hit geometry on **every man in the game**. The file contains **zero** logging calls.
2. **`scripts/world/mission_weather.gd:48, :51, :89`** — a bad weather/time id reverts to
   CLEAR / 10:00 / DAY. Kills the global sight cap and every stealth radius. The file's own
   comment at `:37-39` says this must never happen.
3. **`scripts/visuals/sprite_state_map.gd:382-383`** — unmapped intent → `idle_aiming`; a moving
   man slides along in a standing pose. `:380-381` explicitly forbids it.
4. **`scripts/squad/squad_system.gd:84, :87`** — unknown MOS → `m16a1` and generic courage. The
   MG carries 27 damage instead of 42 (ADR-016).
5. **`scripts/allies/garrison_defender.gd:71`** + **`scripts/world/site_planner.gd:1120`** — three
   chained defaults; a new FSB work type never mans the MG during a siege.
6. **`scripts/world/site_planner.gd:1616-1617`** — parapet `kind`/`hp` default to sandbag/140.
   Same family as the `BLAST_FOR` defect above.
7. **`scripts/enemies/patrol_generator.gd:74`** vs **`scripts/world/road_network.gd:163`** — the
   same table read with **opposite** invented defaults (99.0 vs 1.0). One cell is a wall to a
   patrol and a highway to a road.
8. **`scripts/autoload/noise_bus.gd:32`** — an unknown noise type is heard at 10m; a gunshot is
   150m. Invisible by construction.
9. **`scripts/combat/hitzone.gd:50, :71-72`** — unset `zone_type` → ×1.0, reports "BODY".
10. **`scripts/ai/air_traffic.gd:641`** — an unregistered fixed-wing gets an invented 80m/180 profile.
11. **`scripts/enemies/enemy_base.gd:1028-1035`** — `_fov_deg()`'s `_:` arm returns **360°**. Any
    new alert tier gets omniscience.
12. **`scripts/vehicles/cas_airplane.gd:339`** — unknown ordnance releases on the 6m bomb lead; the
    strip lands long, onto friendlies.
13. **`scripts/visuals/model_actor.gd:1051-1055`** — a renamed clip silently disables foot-planting.
14. **`scripts/data/save_data.gd:107-122`** + **`scripts/autoload/campaign_state.gd:428-445`** —
    every save-drift default is the **generous** one: hp 100, ammo, grenades.
15. **`scripts/missions/field_director.gd:464, :469`** — an unknown fire-mission kind gets 8s;
    `spectre` needs 30s, so its canopy corridor closes 22 seconds early.

## ALREADY LOUD — the pattern to copy

`scripts/missions/scripted_sequence.gd:191-192` · `scripts/world/tree_break_system.gd:36` ·
`scripts/world/site_planner.gd:1600-1601` · `scripts/combat/melee_verb.gd:126-131` ·
`scripts/world/collision_table.gd` `is_soft()` and now `get_entry()`.

## HARMLESS — do not spend time here

~70 sites, mostly `scripts/ui/screens/debrief.gd:29-96` scorecard reads and
`scripts/ui/topo_map.gd:274-343` pin cosmetics. A wrong colour is not a wrong decision.
