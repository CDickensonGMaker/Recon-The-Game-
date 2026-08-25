# SYNTHESIS — Magazine ammo (Arbiter's weave, 2026-08-24)

Full analyses in `analysis/` (game_designer, systems_programmer, ux_designer, devils_advocate).
Council of four, independent reads, and they converged hard: the directive is RIGHT and the build
is SMALL — but it is fighting two things: the calendar, and one of the Summoner's own prior rulings.

## What the code already is (three architects converged on the same lines)
Ammo is ALREADY per-slot `[rounds, spare_full_mags]` (`weapon_holder.gd:23-30`) — not a pooled
counter. The whole lie is one line: `_finish_reload` destroys the partial mag's remainder and tops
to full (`weapon_holder.gd:792-793`). Today's reload EATS rounds; magazine retention makes the
player RICHER, not poorer — the hardcore framing is backwards, and that is an argument FOR it
(it adds a decision, it does not add punishment).

## The build (systems programmer, ratified by the weave)
- Per-slot `Array[int]` of round counts, index 0 = seated mag. Reload pouches the partial at its
  true count, seats the fullest spare (fullest-first: reliability up front, 6-round gasps at the
  back of the siege — legible self-inflicted panic, Pillar 5 in miniature).
- `FeedType` on WeaponData: MAGAZINE/BELT ride the array (M60 belt = 100-rd "mag", no variant;
  mounted MG keeps its snapshot path) · INTERNAL (Mosin/M70/shotgun) = tube + loose pool, stripper
  clip from empty · SINGLE (launchers) = loose rounds unchanged.
- Kill the `current_ammo`/`spare_magazines` mirrors — eight hand-sync sites die (fossil law).
- Squad resupply copies the bandage grammar verbatim: stock beside `medic_bandages`
  (`squad_system.gd:10`), gate/prompt/toast per `player.gd:679-690, 1011-1020`. Allies track no
  ammo (`ally_base.gd:1928`) — no AI conversion needed.
- No top-off/consolidation verb in v1 — the stub pouch is the pressure that makes resupply matter.
- Kill the whole-kit `supply_crates` verb (`player.gd:1025-1033`); loot hands PARTIAL mags (5–18).
- Estimate: 2 sessions, ships with `tests/test_magazine_ammo` + a `spare_magazines` zero-grep
  fossil tripwire.

## Presentation (UX, "the pouch and the press-check")
Kill the round numerals (`hud.gd:160-162`) → pip row of magazine OBJECTS with three fill states
(object counts are HUD-legal — `GREN: %d`, `BANDAGE FROM DOC (%d)`; rounds inside a mag are never
a number). Hold-R press-check = viewmodel heft + FEELS FULL / ABOUT HALF / RUNNING DRY. Tap-R
reloads, system auto-picks fullest — no mag-picker UI. Diegetic hard tells: last-3-rounds tracers
+ bolt-lock on empty for US weapons (AK keeps the plain click). One teach toast on first stow.

## Sacrifices (Law 2)
1. **A calendar slot.** `weapon_holder.gd` is the hottest file in the player spine, 13 days before
   the EA target, behind the siege replay and the greenlit body-swap, under an undischarged
   playtest gate. One of the three gives if this builds pre-EA.
2. **The siege's shape.** Finite squad ammo + one killable resupply man in a 45-man no-exfil night
   risks a run-dry fail-state — and the infinite mounted M60 (`weapon_holder.gd:111`) then funnels
   the player onto the post gun. Guard rails: siege as a ~300-rd closed economy is TUNING, the
   Summoner's playtest is the gate; a dead gunner's corpse yields his remaining stock.
3. **Realism inversion, accepted for play:** Doc is the health node, the gunner becomes the ammo
   node ("[F] DRAW AMMO FROM THE GUN TEAM"); belt-feeding reciprocity parks post-EA.
4. **Press-check discoverability** under night-siege stress — tracer/bolt-lock backstop + one
   toast is the whole mitigation; fallback is always-known fill bands on the pips.

## Collisions needing the Summoner (not assumable)
- **Who carries the ammo:** his 2026-07-30 grammar put the ammo box on the GRENADIER
  (`field_cache.gd:7-10`); this directive hangs resupply on the M60 gunner. Supersede or split.
- **Sequencing:** DA recommends spec-now-build-POST-EA (nothing here is demo-critical; the demo
  has no saves, so the migration cost buys zero demo value). Game designer wants it in hands for
  feel. His call.
- **Loadout depth:** code issues 3 spare mags today (`weapon_holder.gd:82`) — too lean for
  retention; GD proposes M16 1+6×20 (140 rds), gunner stock ~8 draws.
- **Known trap either way:** mounted-M60 mount/dismount `"ammo": primary_ammo.duplicate()`
  shallow-copy (`weapon_holder.gd:103/130`) aliases mag state — the migration must deep-copy or
  the pouch corrupts mid-siege.

## Rulings awaited
A1. Build slot: post-EA · or third in line (after siege replay + body-swap) · or jump the queue.
A2. Resupply carrier: M60 gunner (directive) vs grenadier (7/30 ruling) vs both-split
    (gunner=MG belts, grenadier=rifle mags/40mm).
A3. Loadout numbers: adopt 1+6×20 M16 / gunner 8 draws as the starting tune?
A4. Presentation: adopt the pouch-pips + press-check package (no numerals anywhere)?
