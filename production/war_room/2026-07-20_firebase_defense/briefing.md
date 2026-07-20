# WAR ROOM — The Firebase Defense Fantasy (2026-07-20)

Summoner's decree: build the firebase night-defense as ONE coherent encounter (not 5 features).
Pillar-touching (Pillar 1 believable firefights; changes what the garrison IS). Arbiter: recon-overseer.

## The encounter (his words)
Sappers creep the wire in the dark (high stealth); a satchel blows as a main assault charges — a
coordinated night attack. The garrison, on watch, fights back like soldiers. Cost of a breach = lost
fire support / mortars. The player's counter to stealth is the flare; killing the RTO cuts his fire net.

## As-built facts (verified this session, cite file:line)
- Garrison = `Civilian` (`civilian.gd`) with `is_garrison=true`, panic suppressed (`:174`), armed idle
  chains (`:312 _play_garrison`), US models (`:105 GARRISON_MEN`). Spawned `mission_generator.gd:744
  _build_firebase_garrison` at posts from `site_planner.gd:502` (sentry/gun_crew, group "firebase_garrison").
  They CANNOT shoot today — cheap ambient bodies with LOD tiers, no combat brain.
- `AllyBase` (`ally_base.gd`): `squad_member:bool` (`:146`) = "is he MINE" vs group "allies" = "will my
  bullets hurt him"; `OrderMode.HOLD` (`:141`, `_settle`); `_find_target` (`:528`) uses
  `SightCap.at(...)` (night cap); takes damage/dies/gibs (`:1086/:1120`). NOT tied to the roster if
  `member` stays empty / `squad_member=false`.
- Sapper assault SHIPPED: `field_director.gd:530-726` — `_maybe_launch_sappers` (one/op, night, threat
  tier chance), `launch_sapper_assault`, `SAPPER_COUNT=3`, spawn ring 300-500m, `SapperCharge`
  (`sapper_charge.gd`) drives to the bench and detonates (250 dmg, currently `spare_garrison=true`).
- Sapper MOVEMENT already silent: `enemy_base.gd:1303 _execute` early-returns to `_execute_assault`
  (`:1356`, movement only) whenever `assault_objective != ZERO`, so a driven sapper never runs combat/
  fires — no muzzle flash, no gunshot noise. Sight is `SightCap.at` (darkness ~0.4, flare lifts to 0.9).
- `vc_sapper.tres` is MISLABELED — it is an RPD machine-gunner reskin (`weapon_path=rpd`, aggression 0.7).
- Crisis bug: `field_director.gd:686 _poll_firebase_threat` calls `emit_location(...,
  hash(Vector2i(fsb_center)), ...)` — a CONSTANT entity_id; `dynamic_mission_factory.gd:39` dedupes on
  `_seen.has(entity_id)`, so the firebase-attack crisis fires ONCE per operation, ever.
- Net: `player.set_on_net` (`player.gd:345`) is truth; `FieldDirector.set_fire_menu_mirror` terminal
  mirror; RTO death does NOT proactively kick the player off the net (only fails on next press).
  Fire support gated on living RTO within 10m (`_radio_check`, `:352`).
- Fork B persistence surface: `CampaignState` (`campaign_state.gd`) pattern = var + save_campaign
  set_value + load_campaign get_value + to_dict/from_dict + reset_campaign. `_grant_fire_support`
  (`field_director.gd:613`) builds the next allotment on walk-out (mortar 3 base).

## Proposed design (ATTACK IT)
1. GARRISON FIGHTS via PROMOTION-IN-PLACE: on stand-to (sapper launch OR `_poll_firebase_threat`
   detects a threat), each `firebase_garrison` Civilian hands off 1:1 to an `AllyBase` at its exact
   post, `squad_member=false`, `order_mode=HOLD`, `member={}` (no roster). The Civilian is freed. Same
   pattern as `civilian._transform_to_vc()`. Reuses AllyBase fire logic — NO third brain, NO parallel
   population (1:1 swap). They hold posts, face+fire the threat, can be hit and die. Revert to Civilians
   at dawn or when the threat clears.
2. SAPPER STEALTH: silent already (assault override). Add `stealth:float=1.0` on EnemyData; sapper ~0.6;
   apply as a cap multiplier ONLY in defender detection (never raises cap; non-sappers unaffected at
   1.0). Flare + veg + darkness are the levers. vc_sapper fixed to a real quiet sapper (low HP, pistol/
   satchel, holds fire).
3. COORDINATED ASSAULT: behind the 3 silent sappers, spawn a LOUD assault element (existing VC squad,
   `EnemyBase.assault_objective` pointed at the wire/bench) that shoots/telegraphs — tracers & voices.
4. FORK B: on satchel detonation at the bench, dock live `fire_support` mortars AND record a persistent
   `CampaignState` depot penalty that shortens the NEXT `_grant_fire_support` allotment; toast names the
   loss. Flip `spare_garrison=false` (garrison are now participants).
5. CRISIS RE-FIRE: give `_poll_firebase_threat` a per-wave key that increments only after the threat
   clears for a cooldown — a genuinely new assault re-announces; no 0.5s spam.
6. NET KICK: when the RTO dies mid-call, FieldDirector proactively drives `player.set_on_net(false)`.

## Your charge
Read the CODE, not this plan. Return a SHORT verdict (accept / accept-with-changes / reject + why),
name what each choice SACRIFICES, and flag any probe that would pass against both the fix and its
absence. Write your full analysis to analysis/<your_role>.md.
