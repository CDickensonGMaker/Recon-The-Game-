# Lead-Programmer Analysis — The Firebase Defense (2026-07-20)

Verdict: **ACCEPT-WITH-CHANGES.** Every piece is buildable on the existing bones with
no new brain and no parallel population. But three integration mechanics will bite, two
of the six proposed probes pass against both the fix and its absence, and the fossil
cleanup is bigger than the plan admits. Details below, all cited to code read this session.

---

## 1. The garrison Civilian -> AllyBase hand-off

### What Civilian.spawn stands up (must ALL be undone on promotion)
`civilian.gd:111-164`, per garrison man:
- CollisionShape3D child (layer 2 / mask 1) — `:117-123,149-150`
- static hitzones on layer **512** via `HitzoneBuilder._build_static` — `:155-156`
- `add_to_group("civilians")` — `:161`; the spawner also adds `"firebase_garrison"`
  (`mission_generator.gd:768`)
- `AgentRegistry.register(civ, CIVILIAN)` — `:162`
- `NoiseBus.noise_emitted.connect(civ._on_noise)` — `:163`
- `_exit_tree()` calls only `AgentRegistry.unregister` — `:167-168`

### The clean teardown sequence (do it SYNCHRONOUSLY, before spawning the ally)
`queue_free()` is deferred: the corpse lingers in every group and both rosters until
end-of-frame. If you free-then-spawn in one call, for the rest of that frame the registry
holds the civ as CIVILIAN *and* the ally as ALLY, the civ's 512 hitzone still eats player
rounds at the post, and any same-frame group scan double-counts. So tear the civ down by
hand first, in this order:

```
# 1. snapshot what the ally needs (do this BEFORE any teardown)
post   := civ.working_point_pos            # HOLD anchor
unit   := civ.actor.unit                   # us_grunt_* model (civilian.gd:105-108)
occ    := civ.occupation
# 2. pull it out of every index the world reads, NOW (don't wait for _exit_tree)
civ.remove_from_group("firebase_garrison")
civ.remove_from_group("civilians")
AgentRegistry.unregister(civ)               # idempotent (agent_registry.gd:23-27); _exit_tree re-calls it harmlessly
if NoiseBus.noise_emitted.is_connected(civ._on_noise):
    NoiseBus.noise_emitted.disconnect(civ._on_noise)   # godot_standards _exit_tree law; engine auto-drops on free but be explicit
civ.set_physics_process(false)
# 3. now release the body (children incl. the 512 hitzones die with it)
civ.queue_free()
```

(`_transform_to_vc()` at `civilian.gd:399-411` is the pattern for steps 2 minus the
NoiseBus disconnect — it forgets the disconnect and gets away with it only because the
engine auto-cleans a freed callable target. Copy its group/registry moves, ADD the
explicit disconnect.)

### spawn_ally: what must be set BEFORE vs AFTER add_child
`ally_base.gd:1162-1179`. `parent.add_child(ally)` at `:1176` FIRES `_ready()`
(`:251-265`) **before** `ally.global_position = pos` at `:1177`. So:

- **BEFORE add_child (spawn_ally already does it):** collision shape, `collision_layer=2`,
  `collision_mask=1`. Correct as-is.
- **`_ready()` runs at the origin**: it calls `_setup_visual()` (`:274-300`, which
  `call_deferred("dress_visual")` at `:285`) and `_setup_hurtbox()` (`:415-417`). Both run
  before the body is positioned — harmless, because zones ride the skeleton every physics
  frame via `HitzoneBuilder.sync` (`:428-429`) once positioned.
- **AFTER spawn_ally returns, SAME frame, SYNCHRONOUSLY** — before the next physics tick
  and before the end-of-frame deferred `dress_visual`:
  - `order_mode = HOLD` (or `set_order(OrderMode.HOLD, post)`) — **this is load-bearing.**
    The default is `FOLLOW` (`:157`). One `_execute_idle` tick with FOLLOW
    (`:656-697`) yanks the man off his post toward `GameManager.player`. Set it before the
    first `_physics_process`, never defer it.
  - `squad_member = false` (`:146`) — keeps him out of break-state / roster exemptions.
  - `member = {}` (`:147`) — memberless is the intended "bench/POW" path.
  - `director = self` for the promotion barks.
  - `set_sprite(unit, weapon, "US Army and Co")` (`:305-322`) to wear the us_grunt model
    and carry a rifle. This is the SquadSystem-blessed post-spawn swap: it queue_frees the
    default `us_grunt_v3` actor, rebuilds, then `HitzoneBuilder.clear(self)` +
    `_setup_hurtbox()` (`:320-321`) so zones re-map to the NEW skeleton. Do NOT skip it or
    the promoted man wears the wrong rig.
  - `add_to_group("garrison_promoted")` — a **NEW** group, NOT `"firebase_garrison"`
    (see the probe trap in §3).

### Null-deref audit for a HOLD ally with member={} — ALL SAFE
- `dress_visual` (`:330-343`): `member.has("face")`/`has("helmet")` on `{}` are both false;
  `dress_actor(ma, rng, {})` is fine. No deref.
- `_fire_at_target` `SquadRoster.skill_level(member,…)` (`:1009`): **already guarded** by
  `if not member.is_empty() else 0`. sa=0. No deref. The briefing's worry is a non-issue —
  the guard predates this work.
- `on_skill_up` (`:152-156`): `director == null` returns early; `member.get("nick","GRUNT")`
  on `{}` returns "GRUNT". Safe. (A memberless ally never levels anyway — nothing feeds it.)

Conclusion: the AllyBase side is already memberless-safe. The ONLY real hazard is the
**Civilian teardown ordering** above.

---

## 2. Strict-typing landmines in the NEW code (CLAUDE.md GDScript rules)

1. **Reading `stealth` off the enemy loop var (rule 6).** `AgentRegistry.enemies` is
   `Array[Node]` (`agent_registry.gd:8`). In `AllyBase._find_target` (`ally_base.gd:528-554`)
   the loop var is a `Node`. You MUST cast, never `enemy.enemy_data.stealth`:
   ```gdscript
   var eb := enemy as EnemyBase
   var s: float = 1.0
   if eb != null and eb.enemy_data != null:
       s = eb.enemy_data.stealth
   var cap: float = SightCap.at(grid, global_position, epos) * s   # explicit float
   if dist > cap: continue
   ```
   Guard `enemy_data != null` — some spawns can precede data assignment.
2. **`EnemyData.stealth` needs a typed default** (`@export var stealth: float = 1.0`) so
   every existing `.tres` that lacks the key loads at 1.0 (non-sappers unaffected). This is
   the "never raises the cap" contract — apply as `* s` only, `s <= 1.0`.
3. **Variant from Dictionary.get** — `SAPPER_CHANCE.get(label, 0.0)` is already wrapped in
   `float(...)` at `field_director.gd:702`. The new re-fire key and any CampaignState depot
   read do the same: `int(CampaignState.get_value(...))`, `float(...)`. Never `:=` a
   `.get()` or a `get_value()`.
4. **Net-kick: do not hand-roll `player.set_on_net`.** Reuse `_close_net()`
   (`field_director.gd:374-379`) — it already null-guards `world.player`, checks
   `has_method`, and falls back to `set_fire_menu_mirror(false)` for the probe harness.
   Calling the player directly re-introduces the desync `test_handset_fire_net` guards.
5. `SightCap.at` returns `float` (`sight_cap.gd:32`); keep the product in a typed `float`.

---

## 3. Regression surface in the SHARED field_director.gd (arena hosts its own — do NOT edit it)

`ai_stress_arena.gd` and `test_*` build bare `FieldDirector`s. Anything you add to
`_process` (`:138-182`) or the poll trio (`:146-148`) runs against those rigs.

- **Guard every new field with a default.** `_bare_director` (`test_sapper_assault.gd:281`)
  and the handset rig set only a handful of fields. A new `var _fire_wave: int = 0` /
  `var _fsb_threat_active: bool = false` with defaults is safe; a field dereferenced in
  `_process` without a default and unset by the rig is a null crash in three suites.
- **Promotion trigger must be gated behind the SAME conditions as the sapper launch /
  `_poll_firebase_threat`.** `_poll_firebase_threat` needs `patrol_out` (`:673`);
  `_maybe_launch_sappers` needs `patrol_count >= 1` AND night (`:694-699`).
  `test_firebase_garrison` boots a full world but NEVER walks the player out
  (`patrol_out` stays false, `patrol_count` stays 0) and does not force night — so neither
  trigger fires and the garrison stays Civilians. **This is the only reason
  `test_firebase_garrison` survives.** If promotion is ever wired to hour/day-night alone,
  or to a poll that ignores `patrol_out`, that suite's `men` loop
  (`test_firebase_garrison.gd:126-149`) hits an AllyBase where it expects a Civilian and
  fails on "a firebase_garrison member is not a Civilian". **Therefore the promoted ally
  must NOT join group `"firebase_garrison"`** — use a separate group/array so a future
  test-timing change can never make that assertion flaky. The dawn revert reads YOUR group.
- `_poll_firebase_threat` promotion body must **no-op cleanly on a bare rig** (empty
  `"firebase_garrison"` group → the for-loop just does nothing; no world.terrain deref).
- **spare_garrison flip is safe for the tests**: `test_sapper_assault._check_blast_spares_garrison`
  (`:115-139`) calls `CombatManager.apply_explosion_damage` with explicit `true`/`false`,
  NOT through `sapper_charge._detonate`. Flipping the `_detonate` call arg
  (`sapper_charge.gd:52`, `true`->`false`) does not touch that probe. Keep the
  `spare_garrison` PARAMETER — the probe still drives both branches.

---

## 4. Headless boot (`--headless --path . --quit-after 300` + grep "SCRIPT ERROR")

- Boot's default scene runs `GameFlow`, which starts one operation and spawns the garrison,
  but `patrol_count==0` at boot so `_maybe_launch_sappers` (`:699`) never launches and
  promotion never fires. Boot validates parse + spawn + memberless-ally dressing, not the
  fight. Good enough to catch a bad `stealth` cast or a member={} deref.
- **SimClock** is an autoload with **no class_name** (`civilian.gd:540`). You may reference
  the global `SimClock` (as `sight_cap.gd:25` does) but you can NEVER type a var
  `: SimClock`. Same for reaching it by `/root/SimClock` in a unit rig (`civilian.gd:543`).
- **CampaignState** is an autoload. The Fork-B depot penalty MUST follow its
  var + `save_campaign` set_value + `load_campaign` get_value + `to_dict`/`from_dict` +
  `reset_campaign` pattern (briefing `:33`), or a save round-trips a stale allotment. Reads
  from `get_value` are Variant — cast (rule 3).
- No new class_name cycle: `field_director.gd` already references `AllyBase`, `Civilian`,
  `SapperCharge`, `EnemyBase`; adding `EnemyData.stealth` introduces no new edge. Keep it
  that way — do not make `EnemyData` import `SightCap`/`AllyBase`.

---

## 5. Fossil law — what OLD code dies in the SAME change

1. **`vc_sapper.tres` relabel (`data/enemies/vc_sapper.tres`).** It is TODAY an RPD
   machine-gunner: `weapon_path=rpd`, `aggression=0.7`, `sprite_unit=vc_guerilla_rpd`,
   `description="Main Force machine gunner. Belt-fed, aggressive, hard to suppress."`
   Every one of those lines is a lie-in-the-map for a "quiet sapper, low HP, pistol/satchel,
   holds fire". Replace ALL of them (incl. the description string and sprite) — do not leave
   the RPD identity as a fossil under a new `stealth` field.
2. **Crisis re-fire key (`field_director.gd:686-687`).** The `entity_id =
   hash(Vector2i(fsb_center))` is a CONSTANT; `dynamic_mission_factory.gd:39` dedupes on
   `_seen.has(entity_id)` and never clears it (`:38-41`), so the crisis fires once per op,
   ever. When you introduce the per-wave key, DELETE the constant-hash call — do not leave a
   second code path. **Do NOT touch the KIND string** `&"friendly_firebase_under_attack"`
   or its map to `"firebase_attack"` (`dynamic_mission_factory.gd:25-26`,
   `field_director.gd:543`) — `test_sapper_assault._check_notification_path` and
   `CRISIS_CALL` both key on `"firebase_attack"`.
3. **`sapper_charge.gd:50-52` comment + the `spare_garrison=true` arg.** Flipping to
   `false` makes the header comment ("spares the noncombatant garrison by decree",
   `:1-4,50`) false. Correct the comment in the same change (no-more-drift law) or you plant
   a tombstone that hides the flip.
4. **The as-built note that says the garrison "CANNOT shoot"** — once promotion ships, the
   `_play_garrison` armed-idle machinery (`civilian.gd:312-328`) is no longer the whole
   story of a garrison man; if any doc/comment asserts "garrison never fights," bead or
   correct it.

---

## THE PROBE TRAP (briefing's explicit ask): two proposed probes pass against fix AND absence

- **Crisis re-fire.** A probe that calls `_poll_firebase_threat()` ONCE and asserts a
  crisis appears passes whether the key is latched OR free-running — `test_sapper_assault`
  already does exactly this (`:207-211`) and cannot see the spam bug. A honest re-fire probe
  must: poll N times across a PERSISTING threat and assert exactly ONE crisis; then clear
  the threat, wait the cooldown, re-introduce it, and assert a SECOND. If the wave key
  free-runs (increments every 0.5s poll while `near>=2`), you convert a fire-ONCE bug into a
  fire-EVERY-TICK toast spam — and only the multi-poll probe catches it. **Latch the key;
  bump it only after `near < FSB_THREAT_MEN` holds for a cooldown.**
- **Garrison promotion.** A probe that spawns a garrison Civilian, flips the trigger, and
  asserts an AllyBase now holds the post proves promotion happened — but NOT that the
  Civilian was town down (registry/groups/NoiseBus/512-hitzone). Add negative controls:
  after promotion assert the old civ is `not is_instance_valid` (or freed), assert
  `AgentRegistry.civilians` no longer holds it, and assert the post has exactly ONE body on
  a fire mask (no ghost 512 zone). Otherwise the probe is green while a one-frame double-body
  leaks.

---

## What each choice sacrifices

- **Promotion-in-place** sacrifices continuity of the *exact* body: the Civilian is freed
  and a fresh AllyBase spawns, so any per-man state (the villager face RNG, animation phase)
  resets at stand-to. Acceptable — it happens in the dark, mid-alarm — but it is a visible
  pop if a man is on-screen at the trigger. Mitigate by carrying `actor.unit` + face/helmet
  across (snapshot in the teardown).
- **stealth as a defender-side cap multiplier** sacrifices symmetry cleanliness: it lives
  ONLY in `AllyBase._find_target` (and the player's manual eyes), so the Fairness-Law
  "both sides read the identical cap" that `test_night_sight` guards (`:87-111`) now has a
  deliberate one-sided exception. That is correct by design (stealth is the sapper's, the
  defender is who it hides from) but it must be documented at the call site or it reads as a
  Fairness violation to the next auditor — and `test_night_sight`'s symmetry assertion must
  keep comparing a NON-sapper (stealth 1.0) or it goes red.
