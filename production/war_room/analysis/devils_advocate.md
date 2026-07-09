# DEVIL'S ADVOCATE — Living Squad XP + Radio Fire Support

*No free lunches. Every hook can be gamed, every attachment can be hoarded, every strike can trivialize. Named below with the cheapest patch for each.*

---

## PROPOSAL 1 — LIVING SQUAD XP

### R1. Learn-by-doing rewards playing BADLY / slowly (the core sin of ES-style systems)
Every usage hook the briefing names is farmable, and the farm is the OPPOSITE of good play:

- **Medic XP → get downed on purpose.** `squad_system._revive_heal_amount()` heals the *first* revive of a mission to **FULL (999)**. If medic XP ticks per revive, the optimal play is to walk into fire, go down, get revived, repeat. `revives_left` caps it at 2/mission, but that's still "deliberately eat a bullet twice per op to level Doc." That is farming by playing badly.
- **detect_ambush XP → creep, don't fight.** `_point_scan()` fires one warning per `lazy_group` (deduped by `_point_warned`). Reward POINT-man XP per warning and you incentivize slow-walking the whole AO to trip every group's radius — the antithesis of "outstanding gunplay," and it directly farms the SKILL that lets you avoid combat. A leveled POINT man warns from `30 + al*0.15 + det*8` metres — at det 8 that's ~94m, so max skill means you *never* get surprised and *never* have to fight. **The skill's own success state erases the gunplay pillar.**
- **small_arms XP → let the AI shoot, or farm trash.** The Pig/Rifleman level `small_arms` from `attacker == self` kills. But kills flow to whoever the AI decides to shoot; there's no bad-play farm for the *player* here — the bad-play farm is that the player will **hang back and let allies rack kills** to level them, instead of leading the assault.
- **fo_fac XP → spam the radio.** If the RTO levels from fire-support dispatch, the player calls every strike he has every mission to grind turnaround, which feeds straight into Proposal 2's "trivialize gunplay" problem. Double jeopardy.

**Sacrifice named:** any use-based curve tuned to be *reachable* is also *grindable*; tuned to be un-grindable it's un-reachable and the feature is cosmetic.

**Cheapest mitigation:** Gate every hook on **mission SUCCESS**, award once at debrief as *counted events → capped XP*, never live per-event. i.e. `doc_revives_this_mission` counter, credited only if `result.success`, `min(events, CAP)`. Farming requires *finishing missions*, which is already the intended loop. Downing yourself to farm Doc now costs you the mission if it goes wrong. One counter dict per member, flushed in `on_mission_end()` — reuses the exact place `missions` already increments.

### R2. Permadeath + investment → players HOARD veterans, killing the aggressive Vietnam feel
This is the sharpest contradiction with the pillars. Pillar 4 says soldiers "die for real"; Pillar 3 says "escalation not fail-states / no rails." But a soldier you've invested 6 missions of use-XP into is a **sunk cost you will refuse to risk.** The dominant strategy becomes: order the veteran squad to `HOLD` in a safe treeline (the order already exists, F2) and solo the objective yourself. That is *less* aggression, *more* camping — the opposite of the intended feel. Iron Man makes it worse: `game_flow` wipes the **whole campaign** on player death, so the veterans you hoarded die anyway when you eventually slip.

**Sacrifice named:** attachment and permadeath *create* hoarding by construction. You cannot have "I care about this soldier" without "therefore I won't spend him." Pick which you sacrifice.

**Cheapest mitigation:** Make growth **cheap and replaceable, not precious.** (a) Keep the random-start-skill roll generous so a fresh rookie is ~70% as good as a veteran — the marginal loss of a vet stings but isn't campaign-ending. (b) XP that pushes a *skill* up should be shallow (the `max: 8` cap already bounds it). (c) Do NOT let use-XP touch the RECON *attributes* (st/ag/al) — those are the RolePlay identity; keep them fixed at generation so no soldier becomes irreplaceable. This preserves attachment (names, nicknames, kill counts, the log) while keeping every man *spendable* — which is the actual Vietnam feel.

### R3. Learn-by-doing is ILLEGIBLE for units the player doesn't control
The player drives exactly four levers over allies: FOLLOW / HOLD / MOVE_TO / weapons-free (`squad_system._unhandled_input`). He never aims the Pig, never chooses Doc's revive, never points the RTO. So **ally skill growth happens on the AI's whims** — the Pig levels `small_arms` based on where the AI's target-selection sends its bullets. From the player's chair this is invisible and unsatisfying: "why did Kowalski get better and Reyes didn't? I did the same thing with both." ES learn-by-doing works because *you* swing the sword. Here you don't.

**Sacrifice named:** delegated growth is opaque growth. Making it legible (per-soldier telemetry HUD) costs UI budget and clutters the atmosphere pillar.

**Cheapest mitigation:** **Announce the growth, don't chart it.** At debrief, one line per soldier who leveled: `"DOC — MEDIC ↑ (4 revives under fire)"`. Reuses the debrief screen (`debrief.gd` already builds a line list) and the per-mission counters from R1. Legibility comes free from the counter you already need. No live HUD, no atmosphere cost.

### R4. Barracks + use-based = double-dipping / incoherent economy
Both systems mutate the **same `member.skills[id]`** dict. `buy_skill()` spends shared `team_xp`; use-XP would raise the same number from play. The player cannot reason about builds: did Doc hit MEDIC 3 because I *paid* 300 XP or because he revived a lot? Worse, they **double-count the same activity** — `compute_score()` banks `kills*10` into the shared pool *and* the same kills would credit per-soldier small_arms. One firefight pays twice.

**Sacrifice named:** keep both → confusion + double-pay. Drop barracks → lose all *player agency* over builds (growth becomes something that happens *to* you, reinforcing R3's opacity). Drop use-XP → the whole Proposal 1 headline dies.

**Cheapest mitigation (cleanest of the three):** **Split the currencies by target.** Use-XP raises *individual soldiers' MOS skills* (the thing they do). Shared `team_xp`/barracks is repurposed to *player-body skills only* (`PLAYER_SKILLS = small_arms, sniping, silent_movement` already exists as exactly this partition!). The codebase already separates "skills whose effect lives on the player's body" from "skills that belong to a squadmate's role" (`skill_catalog.gd:19-32`). Honor that seam: barracks = player, use-XP = squad. Zero double-count, clear mental model, and you keep agency over *your own* build while soldiers grow organically.

### R5. Save-compat — old rosters break on any naive field read
Existing `user://campaign.cfg` rosters are Arrays of dicts with `skills:{}`, `kills`, `missions`, `alive` — **no `xp`, no per-skill usage counters.** `SAVE_VERSION` is 1 and `_migrate()` only *warns*. Reads via `.get(id, 0)` are safe (that's why `roster_skill`/`skill_level` survive), but:
- `generate_member()` must add the new fields or new recruits mismatch old ones.
- Any new code doing `member.xp` / `member.skill_use["medic"]` directly (not `.get`) will hard-error on a loaded veteran from before this patch.
- If you add fields to the roster shape you should bump `SAVE_VERSION` to 2 and add a real `_migrate` branch, or old saves silently half-load.

**Sacrifice named:** defensive `.get()` everywhere is ugly but cheap; a real migration is clean but is code you must write and test today.

**Cheapest mitigation:** Add fields via `generate_member()` **and** a one-line normalizer run in `ensure_roster()` that back-fills missing keys on every loaded member (`m["skill_use"] = m.get("skill_use", {})`). `ensure_roster` already iterates the whole roster and already calls `save_campaign()`, so the back-fill costs one loop body and self-heals old saves on first load. Bump `SAVE_VERSION` to 2 with a `_migrate` no-op branch documenting it. **Never read a new field without `.get()`.**

---

## PROPOSAL 2 — RADIO FIRE SUPPORT

### R6. Abundant arty/napalm/CBU TRIVIALIZES the gunplay pillar
Pillar 1 is "outstanding gunplay." Every ordnance you expose is a reason **not** to fight. And the economy already leaks in fire support's favor: `MissionDirector.state.record_kill()` fires for **every** enemy death — including fire-support kills — and `debrief.compute_score()` pays `kills*10` into the shared XP pool. So today, **calling arty on a cluster and banking the score is a dominant XP strategy** that requires zero marksmanship. Exposing CBU (16 bomblets) and generous budgets makes "why fight when you can call fire" the correct answer.

**Sacrifice named:** fire support is the Freedom-pillar escalation valve; make it scarce enough to protect gunplay and it stops feeling like the "real, reachable, satisfying" system the Summoner asked for.

**Cheapest mitigation:** Keep it **scarce and per-mission-budgeted (already is: `{bombs:0, napalm:0, arty:0, mortar:2, spooky:0}`)** and let the *generator* hand out most tubes only on ANTI-AA / heavy missions. Two extra cheap levers: (a) fire-support kills should **not** feed the shared XP score at the same `*10` rate — tag them and score them at `*2` (they cost ordnance, not skill). (b) Long, honest cooldown (`_cas_cooldown` exists, 10–25s) so a firefight is *decided by rifles* before steel arrives. Fire support finishes fights; it shouldn't open them.

### R7. Danger-close friendly fire — the crux, and it compounds R2
`_drop_bomb()` / `_arty_impact()` / `_drop_cluster()` all call `apply_explosion_damage(impact, …, null)` with a **null attacker** and a fat radius (bomb 16m, arty 14m, napalm 10m). The player picks the target with a **camera ray** (`_cas_ground_target`) while his AI squad may be advancing under `FOLLOW`. Two outcomes, both bad:
- **If the blast hits allies:** you will delete your own leveled veterans with your own strike — directly compounding R2's sunk-cost trauma. One misjudged arty and Doc (MEDIC 5, 11 missions) is gone forever.
- **If allies are immune:** there's no danger-close tension at all, and strikes become consequence-free area-denial → straight back to R6 trivializing gunplay.

**Sacrifice named:** realism/tension (friendly fire) vs. protecting the investment you spent Proposal 1 building. You can't have maximal both.

**Cheapest mitigation:** **Asymmetric danger-close.** Allies take *reduced* blast (they're prone/aware NPCs — apply a 0.4 multiplier or a "GET DOWN" duck state on incoming-fire warning), while the **player** stays fully vulnerable. Add a one-shot toast when the aimed target is within `blast_radius + margin` of any living squadmate: `"DANGER CLOSE — CONFIRM"` (require a second keypress). Reuses the existing `member` positions and the toast bus. Tension preserved, veterans survive a near-miss, careless calls still hurt.

### R8. The RTO is a single point of failure for ALL support
`request_fire_support()` and `request_supply_drop()` both hard-gate on `is_rto_alive()`. Lose the RTO — one AI-controlled man among five — and you lose **every strike, every resupply, and your fo_fac growth** in one death. Mid-firefight, that's the moment you most want the radio and it's gone. Pillar 3 says "escalation **not** fail-states"; a dead RTO turns your escalation valve into a hard fail-state.

**Sacrifice named:** the RTO-as-linchpin is great *tension* (protect the radioman!) and terrible *feels-bad* (arbitrary loss of your whole support kit to AI pathing into a bullet).

**Cheapest mitigation:** Make the radio a **recoverable object, not a heartbeat.** On RTO death, drop a "RADIO" pickup at his body (reuse the supply-crate `StaticBody3D` + `[E]` interact already in `_drop_supply_crate`). Any squadmate — or the player — can `[E]` it to become acting RTO (`is_rto_alive()` becomes "anyone carrying the radio"). Fire support degrades (longer cooldown without a trained fo_fac operator) but isn't *deleted*. Fail-forward, not fail-state — exactly Pillar 5.

### R9. CBU/napalm terrain destruction reintroduces the perf problem the team already SOLVED
The crater cap is the shipped perf fix: BOMB = 1 deform, napalm = center drop only, CBU = `is_first` only, arty = 2 of 6 rounds (`cas_airplane.gd` header + `mission_director._arty_impact`). But that cap is **per-strike, not per-mission.** Proposal 2 wants to *expose more ordnance and make it reachable* — i.e. more strikes per mission. Cap holds each call to ~1 deformation, but 8 calls = 8 crater rebuilds across the AO, plus CBU/napalm spawn `FireHazard` nodes and `_ignite_nearby_structures` loops over `flammable_structures`. **The aggregate is the exact perf regression the cap was written to prevent** — just spread over a mission instead of one frame.

**Sacrifice named:** every exposed tube and every generous budget trades directly against the frame budget the crater cap bought back.

**Cheapest mitigation:** Add a **per-mission deformation ceiling** (a static counter in the terrain/deform path: after N total craters this op, further strikes deal damage + FX but **skip the terrain deform**, same as the non-`is_first` bomblets already do). Costs one `if _mission_craters >= CAP` guard on the deform call. Also cap concurrent `FireHazard` count. The scarcity from R6 already limits call *count*; this makes the perf floor hard regardless of how the budget is tuned.

---

## THE ONE-PARAGRAPH INDICTMENT
Both features are *attachment machines wired to loss machines.* Proposal 1 makes soldiers precious, then permadeath makes you hoard them (R2) and delegated AI makes their growth invisible (R3); Proposal 2 hands you the tool to delete those precious soldiers yourself (R7) or lose the whole kit to one AI death (R8), while the scoring already pays you to skip the gunplay pillar entirely (R6). None of this is fatal — but every mitigation above is a *deliberate scarcity or legibility choice*, and if the council ships the features without those choices, the systems will actively fight three of the five pillars.
