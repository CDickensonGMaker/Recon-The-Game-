# UX DESIGNER — the firebase siren (ADR-035 siege signal)

**Date:** 2026-07-29 · Read from CODE, not plans. All claims carry `file:line`.
*(Overwrites the 2026-07-10 drift-audit analysis at this path.)*

---

## 0. What actually exists today (the ground truth the siren lands on)

- **The siege lifecycle is real and shipped.** `scripts/missions/siege_director.gd` —
  cadence roll `_maybe_open` (`:118-138`), the once-per-run d50 (`:148`), the probe split
  `is_probe = run_strength <= PROBE_MAX` (`:157`, `PROBE_MAX = 11` at `:17`), sector bearing
  (`:162`), `_build_cells` (`:163`), then **`siege_began.emit(run_strength, is_probe)` at `:164`**.
- **`siege_began` fires BEFORE a single body exists.** `_build_cells` (`:170-194`) makes
  `MarchingCell` nodes that hold strength as an **integer with zero bodies**
  (`marching_cell.gd:33 materialized=false`, `:55-63 live_strength`). Cells sit at
  `RING_MIN..RING_MAX` = **300–500 m** (`siege_director.gd:20-21`) and only materialize inside
  **80 m** (`marching_cell.gd:15 MATERIALIZE_M`) or when lit (`:99-105`).
  At `emit`, the enemy is 300–500 m out and does not exist as flesh.
- **Marching = 2.2 m/s** (`marching_cell.gd:16`). 300–500 m of approach is **~135–225 s** of
  walking before the first cell even materializes at 80 m. That is the siren's dramatic runway.
- **Dormant cells already make noise** — `NoiseBus.emit_noise(FOOTSTEP, …)` every 6 s
  (`marching_cell.gd:17, :84`). ADR-035 §2 contract 4: *"An approaching company is heard before
  it is seen."*
- **The player's current warning channel is a TEXT TOAST.** `field_director.gd:1273-1279`
  `_on_siege_began` → `_garrison_stand_to()` + `toast.emit("STAND TO - THEY'RE COMING IN
  STRENGTH (%d ON THE WIRE)")` — **and it prints the exact enemy count.** The toast renders as a
  centre-top label queue, `scripts/ui/mission_hud.gd:299-303`, box built at `:49-53`.
  `_garrison_stand_to` (`field_director.gd:1228-1245`) emits a *second* toast
  `"STAND TO - THE WIRE'S IN CONTACT"` when it promotes anyone.
- **Garrison posts include two towers/LOS points with sentries:** `site_planner.gd:796
  ["tower_los_point_001","sentry",1]`, `:793 ["bunker_los_point_001","sentry_night",1]`,
  `:791-792` SOCKET_A/B sentries, `:797` `GUN_POINT_001` gun crew of 2. **There is a manned tower
  to hang the siren on, and a man in it.** The marker contract at `:778-786` is the mounting point.
- **No siren asset and no alarm code exists anywhere.** Grep for `siren|klaxon|alarm` across
  `scripts/`, `assets/audio/`, `production/adr/` returns only unrelated hits (enemy alert prose,
  ADR-005 detection beacon). This is a **new asset + new emitter**, not a rewire.
- **Ambience already has every hook the siren needs.** `game_world.gd:250-300` builds the wildlife
  emitter list `_wildlife`; `start_night_ambience()` (`:378-393`) loads
  `assets/audio/sfx/night_insects_loop.wav` at −12 dB and **appends it to `_wildlife`**;
  `set_wildlife_ducked()` / `set_war_loud()` / `_apply_wildlife_duck()` (`:316-362`) tween the whole
  wildlife bed to **−58 dB over 3 s down, 14 s back up** with two independent causes tracked
  (rain, war) so neither un-ducks the other. `AudioManager.duck_ambience()`
  (`autoload/audio_manager.gd:393-402`, `DUCK_DB = 8.0` at `:52`) is the short transient duck.
- **VO is wired and cast.** `scripts/autoload/vo_manager.gd` — `play_radio` (`:44-56`, one net one
  voice, positional at the RTO's back unless the player is on the handset), `play_squad` (`:61-64`,
  john/ryan by member hash, norman for MEDIC), `play_enemy` (`:68-72`, three VC banks by stable
  speaker hash), 4 s anti-spam cooldown (`:21, :98-103`), and **missing wavs no-op silently**
  (`:106-114`). The banks on disk are listed in §5 below.
- **The law that cuts against a pure-audio feature:** GAME_GUIDE.md:44-46, *the r4bk Law* —
  *"A feature without a visible HUD affordance does not exist."* And GAME_GUIDE.md:242 —
  *"Diegetic-first: barks, VO … wildlife silence."* The siren is the rare case where those two
  reconcile: the affordance is **the tower**, and it is in the world, not on the screen.

---

## 1. WHEN does it sound?

### The three candidate triggers, judged by what the player is doing

| Player state | At `siege_began.emit` (:164) | At first materialize (80 m) | At sentry LOS |
|---|---|---|---|
| Asleep/idle in a hootch | ~135–225 s to wake, grab a wall, choose a sector | ~35 s to contact | already being shot at |
| Standing watch on the wire | Confirms the dread he half-heard from `NoiseBus` | Redundant — he sees them | Redundant |
| 800 m out on patrol | Distant wail behind him; a real decision with time to act on it | He hears nothing useful; base is already engaged | The base is lost before he turns around |

**RULING: sound it at `siege_began.emit` (`siege_director.gd:164`), routed through the tower — but
with a deliberate 2–5 s beat, and with the SIREN as the ONLY thing that fires there.**

Rationale, in the player's shoes:

1. **The runway is the whole point.** 300–500 m at 2.2 m/s is a **2–4 minute** approach
   (`siege_director.gd:20-21`, `marching_cell.gd:16`). That window is the only part of a siege where
   the player makes *decisions* instead of reactions — where his men go against one 60° sector
   (ADR-035 §3), whether to spend illum (§7, `illum_strike` key 7). Firing the
   siren at materialize (80 m) **deletes the decision phase** and converts a siege into a jump
   scare. Firing it at sentry LOS is strictly worse: the sentry's own contact bark is that moment,
   and the siren would then be reporting a fact the player already has.
2. **Somebody in the fiction knows.** The siren at `emit` is not omniscience if the *fiction* is
   "the listening post / the tower heard movement." The code already backs that fiction: dormant
   cells push `NoiseBus` FOOTSTEP noise every 6 s from 300–500 m (`marching_cell.gd:84`), and
   ADR-035 §2 contract 4 states the doctrine outright. **The siren is the sentry acting on the
   noise the simulation is already generating.** That is the sentence that keeps it diegetic
   (see §3).
3. **The 2–5 s beat matters.** A siren that starts on the exact frame the director rolls reads as
   a system event. A siren that starts a few seconds after — long enough for the player to *not*
   have caused it — reads as a man climbing to the crank. Cheap, and it buys the whole illusion.
4. **Sector, not just onset.** The siren should be a **positioned 3D emitter on the tower**
   (an `AudioStreamPlayer3D` at the `tower_los_point_001` marker, `site_planner.gd:780/796`), not a
   2D stinger. Then a player 300 m out the far gate hears it *behind and left*, and a player in a
   hootch hears it through a wall. Do NOT let the siren encode the attack bearing —
   `sector_bearing` (`siege_director.gd:65, :162`) is the player's to discover. **The siren says
   THAT, never WHERE.**

### What must change at the same time (this is the real UX defect)

`_on_siege_began` (`field_director.gd:1273-1279`) currently emits
`"STAND TO - THEY'RE COMING IN STRENGTH (%d ON THE WIRE)"` — **a literal enemy headcount pushed to
the HUD.** Nobody on that firebase knows there are 43 men in the treeline. That toast is a
briefing UI wearing a diegetic hat, and it is exactly what ADR-029 forbids.

**When the siren ships, that count goes.** The siren replaces the strength readout; a toast may
survive only as a **subtitle for a spoken line** (VOManager doctrine, `vo_manager.gd:9`
*"Text toasts stay on screen as subtitles"*). Numbers do not survive. Same for
`"THE WIRE HELD - ALL %d ACCOUNTED FOR"` (`:1290`) and `"%d OF %d DOWN"` (`:1287, :1293`) — those
belong in the dawn AAR, not in a live toast. **Fossil law (ADR-023): the siren does not sit beside
the count toast; it deletes it.**

---

## 2. Does a PROBE sound the siren?

`is_probe` is true for a d50 roll of 1–11 (`siege_director.gd:17, :157`). Note what a probe
actually is in this codebase: `_build_cells` (`:170-174`) makes sappers = `mini(2d6, strength)`,
so a probe of 4 can be **four sappers carrying satchel charges**
(`_spawn_cells_for(…, charges=true)`, `:173`), and a satchel that reaches the dump costs the
player his mortars for this patrol *and the next* (`field_director.gd:1250-1260`,
`on_firebase_breach`). **A "small" probe is the single most expensive night in the game per man.**

**Case FOR silence on a probe:** the siren's meaning is scarcity. If it wails for three sappers on
six nights out of ten, by night three the player's body has learned that the siren means nothing,
and on the night it means everything he finishes his coffee. The whole value of an alarm is the
adrenaline it buys, and adrenaline is spent by repetition. This is the cry-wolf argument and it is
correct as far as it goes.

**Case FOR sounding on a probe:** the player has no other channel. `_check_firebase_threat`
(`field_director.gd:1178-1220`) only trips at `FSB_THREAT_M = 90.0` with `FSB_THREAT_MEN = 2`
(`:858-859`) — i.e. **after the sappers are already inside 90 m**. Silence on a probe means the
first thing a sleeping player learns is the satchel. That is not tension, that is a gotcha, and it
punishes with a *persisted* campaign loss (`CampaignState.depot_loss`, `field_director.gd:1257`).

**RULING — a probe does NOT sound the siren, but it does not go unannounced either. Two signals,
not one:**

- **SIEGE (12–50):** the **siren**. Motor spin-up, sustained rising/falling wail. Base-wide, tower
  mounted, unmistakable, and the whole garrison stands to.
- **PROBE (1–11):** **a single sentry's shout and one shot** — the sentry in the tower firing at
  movement, plus a squad bark. No siren. Local, ambiguous, and it wakes the player *without*
  telling him the scale. He must go and look. That is Pillar 3 and Pillar 4 in one gesture.

This preserves the siren's meaning **and** never leaves a real probe silent. It also gives the game
a genuine dramatic tool it does not currently have: **a night that starts like a probe and turns
out to be a siege**. `open_siege` sets `is_probe` once at `:157` and never re-evaluates, so today
that can't happen — but the *escalation* path already exists via the run pool (nights 2–3 carry
survivors, `:354`, `:147-149`). Recommend the siren be allowed to fire **late** on a probe night if
the 90 m threat check trips with `FSB_THREAT_MEN` (`field_director.gd:1192`) — the sentry realises
mid-fight it is bigger than he thought and *then* runs for the crank. That single behaviour is
worth more atmosphere than the whole rest of the feature.

---

## 3. Does the siren violate a pillar or the no-UI stance?

Tested hard. **It does not violate ADR-029, and it does not violate Pillar 4 — provided three
constraints hold. Without them it is a HUD in a hat, and the brief is right to suspect it.**

The honest charge: at `siege_began.emit`, no character has seen anything. The `SiegeDirector` knows.
If the siren fires off the director's *knowledge*, the player is receiving **author information**
through a speaker, which is precisely the thing the toast at `field_director.gd:1276` does today
and precisely what ADR-029 killed the briefing UI to prevent.

**The three constraints that convert it from HUD to world:**

1. **A MAN sounds it, and he can be wrong or dead.** The siren must be owned by the tower sentry
   (`site_planner.gd:796`), promoted at stand-to
   (`field_director.gd:1234-1240`, `GarrisonDefender.promote`). If that post is empty — the man
   was killed on night 1 and **the dead are not replaced** (`_garrison_stand_down`,
   `field_director.gd:1298-1307`; ADR-035 §6, *"Dead men stay dead"*) — **the siren does not
   sound.** Night 2 with a dead tower sentry is a silent night, and the player learns why. That
   single rule is the difference between an alarm and a UI element, and it is the strongest
   Pillar-4 argument the feature has: the warning system is a *person in your squad's world*, and
   losing him costs you something you can feel.
2. **It carries no numbers and no bearing.** Onset only. `strength` (`siege_director.gd:164`) never
   reaches the player's ear or eye. `sector_bearing` (`:65`) is discovered by looking.
3. **It replaces the toast, it does not add to it** (§1). Two channels for one event is how a
   diegetic signal quietly becomes decoration on top of a HUD.

**Against the pillars:**
- **Pillar 1 (believable firefights):** neutral-positive. Firebases had sirens. It is period-true.
- **Pillar 2 (atmosphere):** this is the pillar it pays. The single biggest atmosphere win in the
  siege is *the ninety seconds before contact*, and today that window is silent apart from a text
  label.
- **Pillar 3 (freedom):** see §4 — it must never re-task, never mark, never pull.
- **Pillar 4 (you are IN the squad, not above it):** **passes only under constraint 1.** A siren
  that always fires because the director rolled is the player standing above the squad. A siren
  that fires because *the corporal in the tower heard something and cranked it* is the player
  standing in it.
- **Pillar 5 (fail forward):** positive. It converts "you woke up dead" into "you woke up late".
- **The r4bk Law** (GAME_GUIDE.md:45): satisfied by the **tower prop and the man on it** — a
  visible, locatable, destructible affordance. If the council wants belt-and-braces, the affordance
  is the *siren horn model on the tower*, not a screen element.

---

## 4. When does it stop — and what about the man 800 m out?

`siege_ended.emit(reason, killed, run_peak)` at `siege_director.gd:357`, from `_break_siege`
(`:335`), with four reasons: `"dawn"` (`:204`, the 480 s `MAX_DURATION_S` at `:40`), `"wiped"`
(`:208`), `"broken"` (`:212`, the 42.5 % kill threshold via `BREAK_BASE_RATIO = 0.575` at `:30`).
Handled at `field_director.gd:1284-1296`.

**RULING: the siren winds DOWN on its own long before the siege ends. There is no all-clear siren.**

- **Duration: 45–75 s of wail, then a motor spin-down.** A siren that runs for the full 480 s is
  an endurance test, it masks every gunshot and every bark the player needs to fight by, and it
  destroys the mix at exactly the moment the mix is doing the most work. Real base sirens are a
  *summons*, not a soundtrack. Once the garrison is up, the siren has done its job.
- **It stops on its own timer, NOT on any siege signal.** Tying wind-down to `siege_ended` would
  make the siren a live status indicator — a health bar you can hear. Wind it down while the fight
  is still building.
- **No all-clear.** The all-clear is **dawn**: the light comes up, the insect bed comes back
  (`game_world.gd:378-393`), the survivors stand down (`_garrison_stand_down`,
  `field_director.gd:1298-1307`), and the AAR banks the butcher's bill (ADR-035 §6 — *still not
  built*, currently a toast, per ADR-035:251-253). A second siren blast saying
  "it's over" is a UI notification with a diegetic costume, and it robs the player of the one thing
  a night attack should leave behind: **not knowing whether it's really finished.** If a wind-down
  cue is wanted for the `"broken"` case, it is a **squad bark**, not the siren (see §5).

### The 800 m question — the hardest part of this brief

Rings: `WIRE_GATE_M = 120.0` / `WIRE_RETURN_M = 95.0` (`field_director.gd:855-856`) set
`patrol_out` (`:1071, :1087`). ADR-035 §1 removed the `patrol_out` gate: **the siege fires whether
or not the player is inside the wire.**

**RULING: YES, he hears it — attenuated, distorted, and unmistakable. And nothing else happens.**

- **Audibility:** a motor siren carries. At 800 m over open ground at night it is a thin,
  wavering, low-passed rise-and-fall. Implement as the **same 3D emitter** with a large
  `max_distance` and a low-pass that opens with proximity — not a separate 2D "you hear the base"
  cue. (Note the existing distance conventions: VOManager's field voices are 45 m
  (`vo_manager.gd:82`), the radio speaker 26 m (`:36`), footsteps 28 m
  (`audio_manager.gd:99`). The siren is an order of magnitude beyond anything in the current mix
  and needs its own falloff curve authored, not a copied one.)
- **Pillar 3 is protected by what does NOT happen.** No marker. No route change. No toast telling
  him the base is in contact. **Critically, no crisis re-task**: `_check_firebase_threat`
  (`field_director.gd:1197-1207`) can push a `friendly_firebase_under_attack` location that
  `_pick_patrol_location` (`:1313-1320`) takes **first**, and ADR-035 §9 already flags this exact
  hazard. The siren must not feed that path. It is information, not an order.
- **This is the best moment the feature can produce.** A man 800 m out, hearing his own base wail
  behind him, with mortars walking in (`_walk_mortars`, `siege_director.gd:266-272`), deciding
  *on his own* whether to run back or press on — **that is Pillar 3 and Pillar 5 in one moment,
  and it costs nothing to build because the choice already exists.** The siren is what makes the
  choice *legible* as a choice. Without it, the player never knows there was one.
- One honest hazard, named: the radio pull. The player *should* be able to get more via the RTO —
  `radio_on_the_horn.wav`, `radio_say_again.wav` exist. That is a follow-on, not this feature.

---

## 5. LAYERING — the mix, by file

The siren is a mix event, not just a sound. Ordered by importance:

1. **The insects stop. This is the single highest-value line in this whole analysis.**
   `game_world.gd:378-393` `start_night_ambience()` loads
   `assets/audio/sfx/night_insects_loop.wav` and appends it to `_wildlife` (`:392`). The duck
   machinery is already built and already two-cause-aware: `set_wildlife_ducked` (`:319-321`),
   `set_war_loud` (`:359-362`), `_apply_wildlife_duck` (`:325-336`) tweens the bed to **−58 dB over
   3 s**, back over 14 s. **A third cause (`_duck_siege`) joins `_duck_rain` / `_duck_war` in that
   same function** — do not invent a parallel duck (divergent-systems law).
   **And the crickets should stop a beat BEFORE the siren.** The jungle going silent is the
   *approach*; the siren is the *response*. Two seconds of wrong silence is more frightening than
   any horn, and the code to do it is four lines in a function that already exists.
2. **The wail ducks under gunfire, never over it.** Route the siren to the **`Ambience` bus**
   (`audio_manager.gd:62`, `_bus_amb`) so `duck_ambience()` (`:393-402`, `DUCK_DB = 8.0`) pulls it
   down under every shot. The siren must never mask the fight. If it is on Master it will fight
   the weapons bank and win, and the firefight will read as mush.
3. **VO layer — what exists on disk today** (`assets/audio/vo/`, routed by `vo_manager.gd:44-72`):
   - **`joe the radio man voice/`** — the strongest siege bank in the project:
     `radio_fire_mission.wav`, `radio_mortar_mission.wav`, `radio_arty_barrage.wav`,
     `radio_danger_close.wav`, `radio_shot_splash.wav`, `radio_spooky.wav`,
     `radio_dustoff.wav`, `radio_on_the_horn.wav`, `radio_no_commo.wav`,
     `radio_winchester.wav`, `radio_roger_out.wav`, `radio_say_again.wav`,
     `radio_napalm_run.wav`, `radio_snake_eye.wav`, `radio_cbu_cluster.wav`.
     **`radio_on_the_horn`** is already the crisis-call companion (`field_director.gd:1175`
     `_radio_vo("on_the_horn")`) and is the right line to ride the siren's *tail*, never its front.
     `radio_no_commo` and `radio_winchester` are the two lines that would make a bad night feel
     genuinely bad — hold them for when the mortars are gone (`on_firebase_breach`, `:1250-1260`).
   - **`john/` + `ryan/`** (squad, split by member hash, `vo_manager.gd:63`) — the layer that
     should carry the *human* reaction under the wail:
     **`squad_on_your_feet.wav`** (the exact line for a siren waking a hootch — this is the one),
     `squad_contact.wav`, `squad_contact_front.wav`, `squad_movement_ahead.wav`,
     `squad_on_me.wav`, `squad_push_up.wav`, `squad_man_down.wav`, `squad_taking_fire.wav`
     (norman bank only), `squad_treeline.wav` (norman only — perfect for a probe sentry),
     `squad_ammo_low.wav`, `squad_fall_back.wav`, `squad_clear.wav`.
   - **`norman/`** (medic, `vo_manager.gd:16, :62`) — `squad_doc_moving.wav`, `squad_man_down.wav`
     for the casualties the mortar walk produces.
   - **`bryce/` and `hfc_male/`** are full squad-line banks on disk that **`vo_manager.gd:15`
     does not cast** — `SQUAD_DIRS` is `["john","ryan"]` only. Two unused voice banks sitting
     right there. A stand-to is exactly the moment you want *many different voices* shouting at
     once, and the cheapest way to make a firebase feel populated is to widen `SQUAD_DIRS`
     during a stand-to. **Flagged as an opportunity, not proposed inside this feature.**
   - **VC banks** `vi_vais1000/`, `vi_25hours/`, `vi_vivos/` (`vo_manager.gd:17`) —
     `enemy_advance.wav`, `enemy_open_fire.wav`, `enemy_taunt.wav`. Cells materialize at 80 m
     (`marching_cell.gd:15`); those voices arriving out of the dark *after* the siren is the
     payoff for the warning.
   - **Cooldown hazard, named:** `LINE_COOLDOWN_S = 4.0` (`vo_manager.gd:21`) is keyed per line
     (`:98-103`) and `play_radio` **hard-refuses to talk over itself** (`:45-46`). A stand-to that
     queues six barks will drop most of them silently. The siren's VO layer needs **staggering**,
     not simultaneous triggers.
4. **Sequencing the first 20 seconds** (this is the deliverable, not the wav):
   `T−2 s` insects cut → `T+0` motor spin-up (rising pitch as the crank takes) →
   `T+2` full wail, rise/fall cycle → `T+3-6` `squad_on_your_feet` from the nearest awake NPC →
   `T+8-14` scattered garrison barks as `_garrison_stand_to` promotes (`field_director.gd:1234`) →
   first mortar volley (`_walk_mortars`, `siege_director.gd:266-272`) → `T+45-75` siren spins down →
   `T+135-225` first cell materializes at 80 m and the VC voices start.
   **Note the collision:** `_mortar_timer = 0.0` at `:159` and `_walk_mortars` fires when the timer
   hits zero (`:267-272`), so **the opening volley lands within the first half-second of
   `_run_siege`** — today the mortars and the toast are simultaneous. If the siren fires at `emit`
   with a 2–5 s beat, **the first shells land before the siren**, which is either a bug or the best
   thing in the feature (a siren *responding to incoming* is even more diegetic than one responding
   to noise). **A real decision for the Arbiter.** My recommendation: embrace it — give
   `_mortar_timer` a small opening delay so the sequence reads insects-out → shells → siren rather
   than shells-and-siren-together.
5. **`AmbientWar`** (`scripts/ai/ambient_war.gd:12` KINDS, `:22 _on_hour`) rolls distant
   artillery/tracers and drives `set_war_loud` within `AMBIENT_WAR_HUSH_M = 400.0`
   (`game_world.gd:259`). During a siege this should be **suppressed**, not layered — the war is
   *here* tonight, and a distant off-map barrage competing with the real one flattens both.

---

## 6. What does the player DO with it? (Is this decoration?)

**It is not decoration. It is the only thing that makes the siege's existing decision window
reachable.** The test: name a decision the player can make with the siren that he cannot make
without it. There are five, all against shipped code.

1. **Wake up and get to a wall.** Without the siren, a player asleep/idle in a hootch learns of the
   siege from a centre-top text label (`mission_hud.gd:299`) he is not looking at, or from a mortar
   round. `MORTAR_DAMAGE = 140` / `MORTAR_BLAST_M = 18.0` (`siege_director.gd:52, :54`) against
   player HP 100 — **the first volley can kill him in his sleep.** The siren is the difference
   between a death he could have avoided and a death he could not. Pillar 5.
2. **Spend or hold the light.** ADR-035 §7: *"deciding when to spend light is the siege's strategic
   verb."* Illum is a granted, limited mission (`illum_strike`, key 7) and force-materializes cells
   in the lit circle (`marching_cell.gd:99-105`, `siege_director.gd:242-245`). Spending it at the
   siren means burning it on an empty treeline; holding it 90 s means catching them at the wire.
   **That decision requires knowing the clock started.** No siren, no clock.
3. **Place his five men against one 60° sector** (`SECTOR_DEG = 60.0`, `:19`; ADR-035 §3 names this
   *the* Pillar-4 verb). `squad_follow/hold/move/fire_toggle` all ship. A player who learns of the
   attack when it is at 80 m has no time to move anyone 100 m across the compound.
4. **Turn around, or don't** (§4). The 800 m case. The choice exists in code today and is
   **invisible** without the siren.
5. **Choose not to fight.** ADR-035 §11.2 concedes a passive player can survive a siege the
   garrison fought. Making that a *choice he knowingly makes* rather than a thing that happened
   while he wasn't looking is the difference between a sim and a slideshow.

**Where it IS decoration, named honestly (no free lunches):**
- On a night the player is already standing on the wire with a weapon out, the siren tells him
  nothing. That is fine — most nights it is redundant, and the nights it is redundant are what
  make the nights it isn't land.
- The information the siren carries is **strictly less** than the toast it replaces (which prints
  the exact strength). **In pure information terms this feature is a DOWNGRADE.** That is the
  point and it should be stated in the decree: we are trading a number for a feeling, and the
  number was a lie a soldier could never have known.
- **Cost named:** a new looping asset with real motor spin-up/spin-down (a flat looped wail will
  sound like a stock effect and undercut Pillar 2 more than silence would), a bespoke falloff
  curve unlike anything currently in the mix, a third duck cause in `_apply_wildlife_duck`, VO
  stagger scheduling to beat the 4 s cooldown, and an owner-verified playtest (ADR-015).
  Perf is negligible — one `AudioStreamPlayer3D`.
- **Dependency named:** the siren's Pillar-4 defence (§3 constraint 1 — a dead tower sentry means a
  silent night) depends on the garrison stand-down identity contract (ADR-035 §6), which **is
  shipped** (`GarrisonDefender.stand_down`, `field_director.gd:1298-1307`). But the **siege AAR is
  NOT built** (ADR-035:251), so the player currently has no dawn accounting to connect a silent
  night 2 back to the man he lost on night 1. **The siren makes the missing AAR hurt more.**
  That is an argument for building the AAR, not against the siren.

---

## VERDICT

Build it, at `siege_began.emit`, owned by the tower sentry, siege-only, 45–75 s, no all-clear,
audible for a kilometre, carrying no numbers and no bearing — **and delete the strength toast it
replaces.** Its Pillar-4 licence is that a man cranks it, and a dead man cannot.
