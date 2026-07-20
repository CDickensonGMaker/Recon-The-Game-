# DEVIL'S ADVOCATE — The Firebase Defense (2026-07-20)

Read the code, not the plan. Every pointer below verified this session.

---

## 1. FAIRNESS — is the sapper actually silent, is the garrison actually gated?

### The "silent" sapper is silent by ACCIDENT, not by design — and it leaks.
The silence is a single-line emergent property: `enemy_base.gd:1303` early-returns `_execute` to
`_execute_assault` (`:1356`, legs only) **whenever `assault_objective != Vector3.ZERO`**. No
`_execute_combat`, so no `NoiseBus.emit_noise(GUNSHOT...)` (`:1991/:2029`) and no muzzle. Good — TODAY.
But it leaks in three places the plan does not account for:

- **`GunFX.play_combat_sting` fires the instant the FIRST sapper detects the player** (`enemy_base.gd:932`,
  inside `_set_tier(COMBAT)` when `was_cold`). The sapper still runs `_update_perception`/`_think`
  (the assault override is in `_execute`, not `_think`). So awareness climbs to 1.0 on the crouched
  player at the night-reduced sight cap, the tier flips to COMBAT, and a **global combat sting plays
  before the satchel blows.** That is a telegraph of the "surprise" night attack. It is congruent with
  the LOUD assault element (item 3) — but a lone sapper detecting the player at 40m in the dark trips it
  early, on its own.
- **A non-lethal hit barks pain VO + a 30m VOICE noise** (`enemy_base.gd:2354`; downed loop `:475-476`).
  A sapper you wing screams. Fine narratively, but it is not "silent."
- **The whole silence rests on `assault_objective` never being zeroed while alive.** The ONLY writer that
  zeroes it is `sapper_charge.gd:56`, one line before `take_damage(9999)` — so today there is no
  live-fire gap. But `vc_sapper.tres` is a **mislabeled RPD machine-gunner** (briefing; `weapon_path=rpd`,
  aggression 0.7). It is a loaded gun: the day any future code zeroes `assault_objective` on
  suppression/retreat/stagger, every "sapper" becomes a firing MG-class (42 dmg) gunner. **Fixing
  vc_sapper to a real quiet sapper is not polish — it is load-bearing.** Add a probe asserting the
  invariant "a driven sapper's `assault_objective` is only ever cleared in the same frame it dies."

### Never-invisible: flare → detection.
`AllyBase._find_target` (`ally_base.gd:528-554`) gates every candidate on
`SightCap.at(grid, self, epos)` (`:545`). `SightCap.at` (`sight_cap.gd:32-39`) lifts the cap to ≥0.9
**only if `mult < 0.9` AND `IllumFlare.is_lit(look_pos)`** (`:34`). So the flare restores garrison
detection of the sapper — BUT ONLY IF the world is actually dark (`mult < 0.9`). See the probe trap below;
at an unpinned clock `mult == 1.0` and the flare branch is dead code.

### Promotion fairness — the real cost nobody costed.
Promoted garrison become `AllyBase` in group `"allies"`. **The player's rounds now hurt them**
(they leave `CIVILIAN_HURTBOX_LAYER`, `civilian.gd:22`, which is in the player's fire mask; AllyBase
sit in the allies fire economy). In a chaotic night spray toward the wire the player can gib his own
garrison. That is realism, and there is no roster-KIA cost (`squad_member=false, member={}`), so it is
survivable — but it is a new way to eat your own men that did not exist when they were bullet-pass-through
civilians. **Name it.**

---

## 2. THE PROBE-LIES TABLE (this suite has been burned 3× today)

The traps that make a naive probe pass against BOTH the fix and its absence:

| Claim | Mutation that MUST make the probe fail | Does the naive probe still pass against that mutation? |
|---|---|---|
| **Garrison fires only when assaulted** | Promote on ANY nearby enemy (near≥1, no assault gate) | **YES — LIES.** An assault always has an enemy present, so "promotion happened during launch_sapper_assault" passes identically whether the gate is `on-assault` or `on-any-enemy`. Only a NEGATIVE control catches it: peacetime + one lone wandering enemy near the ring → garrison MUST stay `Civilian` and MUST NOT fire. |
| **Sapper harder to see at night** | `DARKNESS_BY_PERIOD` all set to `1.0` (kill the night term) | **YES if the probe never sets the clock.** `SimClock` free-runs from DAWN=1.0 (`sight_cap.gd:9-12`). A probe that never sets `SimClock.sim_hour` into NIGHT reads `darkness_mult()==1.0`; the stealth mult alone still yields `cap_sapper < cap_grunt`, so it passes even with darkness deleted. Trap: set `sim_hour` to NIGHT, assert `cap_night < cap_day` **and** `cap_sapper < cap_grunt`. |
| **Flare restores detection** | `IllumFlare.is_lit` → always false, or delete `sight_cap.gd:34-35` | **YES at daylight.** With `mult==1.0` the flare branch (`if mult < 0.9`) is never entered; cap is high with or without a flare because it is DAY. A "cap is high near flare" assertion passes against a flare that does nothing. Trap: run at NIGHT (`mult 0.4`), assert the DELTA — no flare → low cap, flare lit → cap ≥ 0.9. |
| **Assault has a charging element** | Spawn the loud element with `assault_objective == ZERO` (it just stands) | **YES.** "An enemy in group `assault` exists" passes against a static spawn. Trap: assert the loud element's `assault_objective != ZERO` AND that it emits a GUNSHOT noise (telegraphs) — distinguishing it from the silent sappers. |
| **Breach docks + PERSISTS** | Dock `fire_support` live but never read the penalty in `_grant_fire_support` | **YES in one process.** A same-process probe checks `fire_support["mortar"]` dropped at detonation and passes — but `_grant_fire_support` (`field_director.gd:618`) HARD-ASSIGNS a fresh dict every walk-out, wiping the dock. Persistence needs a SEPARATE probe: write → `save_campaign` → new `CampaignState.from_dict` → assert the NEXT allotment is shorter. See Hole C. |
| **Crisis re-fires** | Keep the constant `entity_id` (`hash(fsb_center)`) so `_seen` blocks it forever | **YES with one assault.** Firing once passes against the CURRENT broken code (`field_director.gd:686` dedupes forever, `dynamic_mission_factory.gd:39`) AND against a correct re-fire. Trap: TWO successive assaults with the threat cleared between → assert the crisis fires the SECOND time; AND assert NO spam while enemies loiter at the 90m ring. |
| **RTO-death kicks net** | Do nothing (rely on the existing next-press gate) | **YES — LIES.** `member_by_mos("RTO")` already filters dead (`squad_system.gd:127`), so `_radio_check` (`field_director.gd:354`) returns `"NO RADIO - RTO IS DOWN"` on RTO death WITH ZERO new code. A probe asserting `_radio_check() != ""` passes on the unfixed build. The kick's only observable effect is `player.holding_handset` flipping false WHILE ON the net. Trap: `set_on_net(true)` → kill RTO → tick director → assert `player.holding_handset == false` AND `fire_menu_open == false`. |

**Boot trap for ALL of the above:** `GameFlow._ready()` auto-starts the default operation
(briefing: `game_flow.gd:27`). A probe that boots the full game gets live RNG, a possibly-daylit clock,
and the real sapper gate. **Construct `FieldDirector` in isolation and drive `launch_sapper_assault()`
directly** (it is public precisely so the RNG gate can be bypassed — `field_director.gd:709`), and set
`SimClock.sim_hour` explicitly.

**THE SINGLE MOST LIKELY PROBE-THAT-LIES:** the garrison-promotion probe with no peacetime negative
control. It is the textbook case — an assault always contains an enemy, so proving "promotion happened"
proves nothing about the gate. The briefing itself names the mutation ("a garrison that promotes on ANY
nearby enemy could fire in a non-assault control"); the probe must include the control or it is theater.

---

## 3. CRISIS RE-FIRE oscillation

`_poll_firebase_threat` (`field_director.gd:672-687`) counts enemies within `FSB_THREAT_M`=90m, fires
when `near >= FSB_THREAT_MEN`=2. A per-wave key that "increments after the threat clears" is SAFE against
the loiter case ONLY if "clear" means near<2 sustained for a cooldown: an enemy hovering at exactly 90m
keeps near≥2, never clears, never re-fires — good. The DANGER is implementing "clear" as an edge
(dropped-then-rose): a single man walking in and out of the 90m ring re-arms the key and re-fires on the
next tick. **Probe the loiter case explicitly** (two men parked at 88m for 30s → exactly ONE crisis).

---

## 4. NET KICK — seam-safe, but detection is the whole job

`player.set_on_net(false)` → `_exit_net()` which early-returns `if not holding_handset` (`player.gd:395`)
→ **idempotent, safe to call when already off net.** It routes player→`_notify_net`→`set_fire_menu_mirror`
(`player.gd:408-411`), the ALLOWED direction. The forbidden wire is `fire_menu_changed → set_on_net`;
calling `set_on_net` directly is exactly what `_close_net` already does (`field_director.gd:377`). **No
seam violation.** The real work is DETECTION: nothing today watches the RTO. Add a check in the 0.5s poll
(`field_director.gd:144-148`); calling `set_on_net(false)` every poll after death is harmless (idempotent)
but gate it on a `_rto_was_alive` latch so it fires the kick once, not every frame.

---

## THE THREE SHARPEST HOLES

### HOLE A — the satchel deletes the promoted garrison at FULL damage; `spare_garrison=false` is a no-op for them.
`CombatManager.apply_explosion_damage`'s `spare_garrison` guard protects ONLY the `civilians` array
(`combat_manager.gd:161-167`). Once promoted, garrison are `AllyBase` in `AgentRegistry.allies` and are
hit by the ALLIES loop (`:138-158`). The satchel passes `attacker = enemy` (NON-null,
`sapper_charge.gd:51`), so the indirect-fire 0.4× reduction (`:149`, `attacker == null`) does NOT apply —
**250 dmg, 14m radius, at full.** Every promoted sentry/gun-crew clustered at the bench (the sappers'
aim point) is deleted in one blast. So the plan's "flip `spare_garrison=false`" is meaningless for the
promoted men and, if the threat cleared and they reverted to civilians, that global flip now lets the
satchel kill the ambient garrison the decree originally spared. **SACRIFICE:** "cost of a breach = lost
fire support" silently becomes "the breach also one-shots your entire defending garrison before they
trade a single round" — the AI-vs-AI firefight the encounter is FOR dies in the blast. Decide the intended
lethality and either exclude promoted men from the satchel or accept it explicitly.

### HOLE B — the silent sapper is silent by one accidental line, and the loaded RPD is still chambered.
Silence = the `assault_objective != ZERO` early-return (`enemy_base.gd:1303`), only ever cleared in the
same frame the sapper self-kills (`sapper_charge.gd:56`). `vc_sapper.tres` is an RPD gunner reskin.
Combine them and the day anyone zeroes `assault_objective` on a stagger/suppress path, the "sapper" opens
up with an MG. Plus `play_combat_sting` (`:932`) telegraphs on first detection, and pain VO leaks on a
wing. **SACRIFICE:** the surprise fantasy is one refactor away from evaporating, and the fix
(vc_sapper → quiet low-HP satchel man) must ship WITH an invariant probe, not after.

### HOLE C — Fork B persistence is cosmetic unless `_grant_fire_support` is rewired.
`_grant_fire_support` (`field_director.gd:613-621`) HARD-ASSIGNS a fresh `fire_support` dict on every
wire-cross. A mortar docked at detonation is wiped on the next walk-out. A persistent `CampaignState`
depot penalty means NOTHING unless `_grant_fire_support` READS it and subtracts. And the idiomatic vehicle
for a decaying persistent penalty already exists — `threat_modifiers` (`campaign_state.gd:23,84`) — so a
bespoke new field duplicates that machinery AND must be threaded through all five seams (`var` +
`save_campaign` + `load_campaign` + `to_dict`/`from_dict` + `reset_campaign`, `:154-256`) or it silently
does not persist. **SACRIFICE:** skip the `_grant_fire_support` rewire and Fork B is a toast with no
teeth after one patrol.

### (Bonus — PERF, item 5) Promote sentries, not all 17.
`AllyBase._find_target` (`:533-548`) walks `AgentRegistry.enemies` every 0.15s think with a per-enemy
`SightCap.at` + distance, plus cover-search LOS raycasts. Standing up ~17 full brains AND tearing down 17
Civilians in the ONE stand-to frame — the same frame the satchel/assault/loud-element spawn — is a spike
exactly when the CPU is already hot. **Gate promotion to the posts on the assault bearing (sentries /
gun_crews facing the sappers), stagger the swap over a few frames, and leave the far side of the perimeter
as ambient civilians.** Only sentries should promote.

---

## WHAT THE WHOLE ENCOUNTER SACRIFICES
- **Determinism of the AO's peace.** Promotion-in-place means the garrison's identity now flips on a
  threat poll; a false positive (two stray enemies wandering to 90m in daylight) can arm a firefight the
  designer never staged. The gate must be night+assault, never bare proximity.
- **The player's own garrison as collateral** (Hole A + friendly-fire on promoted men).
- **One-line fragility of the silent-sapper trick** (Hole B) traded for reusing the assault override
  instead of a real stealth-movement state.
- **Five new CampaignState seams and a `_grant_fire_support` rewire** for a penalty the existing
  `threat_modifiers` could carry (Hole C).

## VERDICT
**Accept-with-changes (qualified GO).** The encounter is coherent and reuses the right seams (AllyBase
fire logic, the assault override, the net mirror, CampaignState). But it does not ship until: (A) the
satchel-vs-promoted-garrison full-damage wipe is resolved and `spare_garrison` semantics are fixed for
AllyBase; (B) `vc_sapper.tres` is corrected AND an `assault_objective`-invariant probe guards the
silence; (C) the persistent penalty is plumbed INTO `_grant_fire_support` (or reuse `threat_modifiers`),
not just docked. Every probe carries its named control — peacetime-negative for promotion, NIGHT-set for
darkness/flare, two-wave for re-fire, on-net precondition for the RTO kick — or it lies.
