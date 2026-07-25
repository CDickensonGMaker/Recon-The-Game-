# SYSTEMS DESIGNER — CoD 2000–2005 "Living Fight" Mechanics Extraction

> **BANNER (corrected 2026-07-25, ghost-code audit):** References to `MISSION_DESIGN_RESEARCH.md`
> below are historical; that doc was deleted on purpose 2026-07-23. Do not seek or restore it. Canon
> is `production/GAME_GUIDE.md` + `production/adr/`.

**Architect:** systems_designer · **Session:** analysis_cod2000 · **Date:** 2026-07-11
**Lens:** mechanisms only — what the machine actually did, what transplants into a finite-enemy open AO, what conflicts.
**Read first:** `production/war_room/synthesis_ai_goals.md` (live AI doctrine), `MISSION_DESIGN_RESEARCH.md` (RTCW/MoHAA architecture — NOT re-derived here; this analysis extends it with the CoD-specific layer it deliberately skimmed: chatter, ally theater, spawner discipline, suppression theater).

---

## 1. What CoD-2000 actually did (the machine under the feeling)

### 1.1 The Battle Chatter System (BCS) — CoD2's single biggest "living fight" mechanism
Cited (GameSpot developer Q&A, CoD2): the chatter is **context-sensitive and specific to points within each level**. Infinity Ward "looked at all of the levels in the game and the geometry, and basically gave it all names," wrote callout templates in real military phraseology, and recorded **~20,000 lines**. Result: squadmates call "Germans behind that wrecked car," warn of flanks, call their own movement. ([GameSpot Q&A](https://www.gamespot.com/articles/call-of-duty-2-qanda-story-characters-weapons-vehicles-ai/1100-6123417/))

The mechanism decomposed:
- **Named geometry**: every callout-worthy prop/feature carries a designer-assigned noun ("wrecked car", "the church").
- **Template grammar**: `{faction} {relation} {landmark}` / `{action} callout` — the 20k lines are combinatorial coverage of a small template set, not 20k bespoke moments.
- **Chatter is diegetic UI**: it is the game's threat-display. FEAR's lesson (already ratified in MISSION_DESIGN_RESEARCH §7.7) — perceived AI ≈ vocalization.
- **Enemy chatter is honest information in a foreign language**: Wehrmacht callouts are real warnings — "Achtung! Granate!" (grenade out), attack orders, artillery warnings ([CoD Wiki Wehrmacht quotes](https://callofduty.fandom.com/wiki/Wehrmacht/Quotes)). Players *learn the enemy's language* as a survival skill. That is a mechanic, not flavor.

### 1.2 Enemy AI: authored affordances + small systemic core
Cited (GameSpot Q&A): CoD2 enemies "run from cover to cover," "break off from firefights to flank," respond to cover-campers with **frag grenades to flush**, and "immediately duck down when fired upon" — both sides actively suppress. Crucially: "**There are a set number of enemies on the map that begin reacting to the player's presence once the first shot is fired** — groups farther away send units to investigate, while enemies directly in front join in and take cover."

Under the hood (modding docs, [CoD Radiant node tutorials](https://wiki.zeroy.com/index.php?title=Call_of_Duty_4%3A_SP_-_Basic_AI_Paths), [Steam AI scripting guide](https://steamcommunity.com/sharedfiles/filedetails/?id=321250822)):
- **Cover nodes are hand-placed affordances**: `node_cover_stand/crouch/prone`, window variants, `ambush` nodes (DONT_LINK = the man stays put until contact), with per-node stance locks (DONT_STAND/DONT_CROUCH). The AI's apparent tactical intelligence is mostly *node placement quality* — the designer pre-solved the tactics of each courtyard.
- **Per-archetype data**: accuracy, engagement min/max distance (`setEngagementMinDist/MaxDist`), goal radius leashes. AI never free-roams; it fights inside a designer-drawn bubble.
- **Threat bias**: engine-level target-selection weighting (the player is usually favored) — the thing our doctrine explicitly rejected as "fatal to squad fiction at HLL lethality."

### 1.3 Ally theater: friendly chains → color groups (the shepherding machine)
Cited ([CoD4 SP Color Groups wiki](https://wiki.zeroy.com/index.php?title=Call_of_Duty_4%3A_SP_-_Color_Groups), which documents the system that replaced CoD2-era "friendly chains"): friendly AI are moved through the level by **color-coded sets of cover nodes activated by player-crossing triggers** (`script_color_allies: r0` on a trigger_multiple; each AI carries `script_forceColor`). When the player crosses the line, the red squad bounds to the red nodes. Friendly reinforcement spawners (`friendly_respawn_trigger`) backfill dead allies out of sight.

What this actually is: **the ally squad is a stage crew keyed to player progress**. Allies advance because the player advanced, fight from pre-chosen positions, and are topped up so the fight always *looks* squad-scale. Combined with near-invincible named characters, allies are set dressing with rifles — magnificent theater, zero simulation.

### 1.4 Spawner discipline — and exactly why the faucet felt bad
Mechanism (GSC scripting, [spawner tutorials](https://steamcommunity.com/sharedfiles/filedetails/?id=321250822)): spawner entities with a `count` (max ever spawned), woken by triggers; the infamous pattern is a loop that respawns a pocket's enemies **until the player crosses a forward trigger**. Player-facing result, as documented in years of player criticism ([GameFAQs WaW thread](https://gamefaqs.gamespot.com/boards/944199-call-of-duty-world-at-war/47669339), [CoD3 review](https://gamefaqs.gamespot.com/ps3/932962-call-of-duty-3/reviews/108583), [Quora on CoD4](https://www.quora.com/Do-enemies-infinitely-respawn-in-Call-of-Duty-4)):

> The design is a **conflict of actions**: to stop players rushing, the game spawns enemies when you kill them; to stop the spawning, you must rush. On Veteran this collapses into suicide-sprinting for invisible lines.

The failure decomposes into four distinct lies, worth naming because each has an honest counterpart:
1. **The kill lie** — killing a man doesn't reduce the enemy; effort is not conserved. (Honest form: finite population; every kill is bankable.)
2. **The geometry lie** — the fight's intensity is keyed to *player position*, not world state. Standing still = infinite war; walking forward = peace. (Honest form: intensity keyed to alarm/witness state.)
3. **The teleport lie** — men blink into existence behind cover the player just cleared. (Honest form: reinforcements enter from map edges/structures, audibly, and travel.)
4. **The pacing theft** — the player can never *win a quiet*; silence is not earnable. (Honest form: RECONgame's eerie-quiet-as-feature — the quiet IS the reward receipt.)

RTCW shipped the verdict already (MISSION_DESIGN_RESEARCH §8.1): its devs *removed* spawn-from-thin-air. CoD reintroduced it because a 4-hour cinematic corridor needed a pressure faucet. We have neither the corridor nor the excuse.

### 1.5 Suppression theater: the MG42 as a level-design pin
Cited: being fired on by an MG42 throws the player's aim off; tank MGs induce shellshock ([CoD Wiki MG42](https://callofduty.fandom.com/wiki/MG42)). Mechanically the emplaced MG is: fixed arc, high volume, deliberately survivable accuracy, **continuous visible tracer stream**, and a distinctive sound signature ("Hitler's buzzsaw") — a *pin*, not a killer. Its job is to make one axis unwalkable so the player reads "flank" without a tutorial. The counter (flank/smoke/grenade) is the encounter's puzzle. This is almost entirely a systemic mechanism — it needs no script, just an archetype that holds a gun, sweeps a beaten zone at last-known, and never leaves.

### 1.6 Tracer discipline & fire readability
CoD-era games render tracers far above the historical 1-in-5 ratio (HLL players still argue about this — [HLL forum](https://steamcommunity.com/app/686810/discussions/0/1607148447814270534/)); real MG doctrine loaded ~every 5th round ([Axis History Forum](https://forum.axishistory.com/viewtopic.php?t=46415)). The design function of tracers in CoD: (a) every fire lane is *legible* — you can see who is shooting where without HUD; (b) volume of visible fire = perceived battle scale; (c) tracers point back at the shooter — they are counter-information. Faction color coding (Axis green/white vs Allied red — historically grounded: ComBloc green, US red) makes the exchange readable at a glance.

### 1.7 The ambient war: the fight beyond the playable bubble
CoD1's celebrated "real battle" feel was substantially **non-interactive theater**: ricochet pings, distant artillery, planes crossing, off-map MG duels, buildings collapsing on cue ([Old PC Gaming review](https://oldpcgaming.net/call-of-duty-1-review/), noting also: "the game is entirely scripted — die and reload, and every soldier and tank appears in exactly the same place"). The war *sounds* bigger than the ~10 active brains the engine actually ran. This is the cheapest mechanism in the whole lineage and the least dependent on level structure: an audio director, not an AI system.

### 1.8 Grenade indicator (CoD2's HUD innovation)
CoD2 added the on-screen grenade danger icon. Mechanically it solved "invisible death by cooked frag." Note the alternative it displaced: MoHAA/CoD1 relied on the *enemy shout* ("Achtung! Granate!") as the warning channel — the diegetic version of the same information.

### 1.9 What the CoD lineage did NOT do (so we don't cargo-cult ghosts)
- No systemic alertness ladder mid-fight (MoHAA/RTCW had one; CoD collapsed it — the campaign is permanently ALERT after the opening shot of each level). *Speculation from design analysis, consistent with modding docs: CoD AI has no RELAXED→COMBAT stealth model worth copying; ours (from RTCW/MoHAA) is strictly superior.*
- No morale/rout: CoD Germans fight to the last man. Our Chieu Hoi/rout ladder has no CoD ancestor — keep ours.
- No persistent squad: allies respawn; deaths are theater. Pillar 4 has no CoD ancestor either.

---

## 2. What transplants systemically (mechanism → RECONgame mapping)

| CoD mechanism | RECONgame status | Verdict |
|---|---|---|
| BCS squad callouts w/ named geometry | **GAP** — VOManager exists (radio/squad/enemy channels, cooldowns, positional 3D), MISSION_DESIGN_RESEARCH §7.7 specs barks, but nothing fires on contact/state transitions, and generated geometry is unnamed | Transplant as template grammar over generator-tagged landmarks |
| Enemy chatter as honest info (foreign language) | **PARTIAL** — grenade telegraph "LUU DAN!" + VO, retreat/surrender VO ship today (`enemy_base.gd` `_throw_grenade`, rout path). No tier-transition or maneuver barks | Extend: bark on SUSPICIOUS/ALERT/COMBAT transitions and on FLANK/ADVANCE goal adoption (doctrine 5.6 already *requires* "enemies vocalize before flanking" — unimplemented) |
| Duck-when-shot-at, grenade flush, cover-to-cover | **COVERED** — suppression→hunker, grenade broker, bounding advance, cover-first are all live in `enemy_base.gd` | Nothing to do; CoD2 parity already exceeded (ours is systemic, theirs was node-authored) |
| Set number of enemies; distant groups send investigators | **COVERED/PARTIAL** — finite pockets + NoiseBus investigation exist; "distant group dispatches a 2-man team to look" (fraction-of-squad response) is not distinct from whole-squad alert | Small gap: squad-level *probe* response (send 2, keep the rest anchored) |
| Cover nodes as authored affordances | **CONFLICT (by design)** — we use live raycast cover sampling + claim broker; generator stamps CoverPoints later (§6.2). Hand-placed nodes don't exist in a generated AO | Keep systemic; let SitePlanner emit *hint* points at structures (cheap prior, not authority) |
| Color-group ally shepherding | **REJECT** as progress-gating; ally doctrine is player-paced. But the *slot set* idea survives as: ordered ally positions around a player-designated anchor | Covered by existing orders (FOLLOW/HOLD/MOVE_TO) + formation offsets |
| Emplaced MG pin + suppression theater | **GAP** — SUPPRESS_TARGET goal exists, player suppression exists (`add_suppression`, near-miss cracks), but no emplacement archetype, no beaten-zone sweep, no sustained tracer stream | Transplant fully — this is the best CoD mechanism for an open AO because its counter is *routefinding*, which is Pillar 3 |
| Tracer ratio/color discipline | **GAP** — `_fire_at_target` spawns a tracer on *every* round, one hardcoded green | Per-weapon `tracer_ratio`/`tracer_color` in WeaponData; MG streams vs rifle sparsity |
| Spawner `count`/budget discipline | **COVERED** — `_hunter_pool = 12`, finite, detection-gated (witness rule: `last_combat_contact_ms` beacon; silent kills stay cold). Wave spawns place near cover, fireteams split | Extend with §3 honesty rules (arrival vectors, per-source caps) |
| Ambient war beyond the AO | **GAP** — MissionWeather/audio exists; no distant-war audio bed | Transplant as an audio director with a **silence budget** (see warning) |
| Grenade HUD indicator | **REJECT** — diegetic shout channel already chosen and shipped | Keep the shout; maybe add the *ally* grenade callout ("frag out!" / "grenade! get down!") |
| Shellshock/aim-throw on suppressed player | **COVERED** — player suppression from near-miss cracks | — |

## 3. The reinforcement question (central): the honest rule set for finite density

Current live state: detection (any enemy reaching COMBAT) starts one global escalation; hunters spawn 2–4 at a time from a 12-man pool, every 100–160s, **in a ring 180–230m around the player**, clamped to map bounds (`mission_director.gd:87-96`). Finite: yes. Honest: not yet — the ring is keyed to *player position* (CoD's geometry lie, slowed down), and men appear from any compass direction including ones the player watched.

The honest rules (each mapped to the four lies of §1.4):

**R1 — Population is a ledger, never a faucet.** AO total budget set at generation: garrison pockets 4–8 men each (2–4 pockets), roving patrols 3–5 men (1–3 routes), QRF/hunter pool 8–16. Everything the player kills stays dead; the ledger visibly exhausts (MGSV model, already canon in MISSION_DESIGN_RESEARCH §5.5/§8.4). ~30–55 men per AO at current perf contract (8–12 active brains per pocket, think-LOD already live).

**R2 — Escalation keys to *witness state*, not player position.** Already half-built (detection beacon). Extend per the stealth witness rule (bead pwu5): each escalation increment requires a *witness event* — an enemy in COMBAT who survives ≥Xs, a runner reaching a radio, an alarm object firing. No witness, no draw on the pool. Kills without witnesses *lower* future response (patrols that fail to report are missed at intervals — a delayed, bounded suspicion tick, not a psychic alarm).

**R3 — Reinforcements are squads that travel, not spawns that appear.** QRF enters at map edge / road head / known enemy structure (never inside the ring the player can see — MoHAA's `func_spawnoutofsight` rule, already canon §8.2), moves as a fireteam with a moving leash, and is *audible before it is visible*: truck engine, Vietnamese chatter, a signal flare over the treeline. The telegraph is the atmosphere. 90–180s arrival already matches canon.

**R4 — Radios and alarms are physical, killable, and capped.** Each camp owns at most one summon source (radio hut, field telephone, flare NCO). Each source can draw a **bounded number** of increments from the pool (e.g., radio = up to 2 QRF squads, flare = +1 patrol redirect). Destroy the radio before the runner transmits → that camp's cap is spent silently. This makes "race the runner" (§5.4.4) and sapper-style pre-work real strategy. When the pool is empty or all sources dead, the AO goes quiet **forever** — and that quiet is the Pillar-2/Pillar-5 payoff.

**R5 — The quiet must be diegetically confirmed.** CoD never let silence mean anything; ours must. When the last man of a pocket dies or routs, the squad says so ("that's the last of 'em… I think"), wildlife audio returns after ~60–90s, and the ambient-war bed (if any) recedes. Uncertainty is preserved — the squad *thinks*, the player verifies. Eeriness = silence + unconfirmed safety.

## 4. What to reject (named, with what is sacrificed)

1. **Respawn-until-push / position-gated pressure** — rejected per Summoner's verbatim intent. Sacrificed: the guarantee that every minute is loud. Accepted willingly; Pillar 2 buys it back.
2. **Ally shepherding via progress triggers (color groups)** — conflicts with player-paced squad doctrine and Pillar 3. Sacrificed: perfectly composed squad staging at authored beats. Our substitute is the personality spectrum + orders.
3. **Player threat bias** — already rejected (honest attention, `_target_score` has no player term). CoD needs it because allies are immortal props; we don't.
4. **HUD grenade indicator** — sacrificed: guaranteed legibility of every frag. Bought: the "learn Vietnamese warnings" mechanic (§1.1's best idea, in our setting: *the player who learns "LUU DAN!" lives longer*). Ally callout covers the fairness floor.
5. **20,000-line VO ambition** — sacrificed: bespoke per-location specificity. Template grammar over ~40 landmark nouns × ~12 templates × existing 162-wav library + subtitles gets 80% at 1% cost.
6. **Permanent post-contact ALERT-everywhere (CoD's flat alertness)** — our tier ladder with local propagation is strictly better for stealth-optional play; keep it.

## 5. Concrete proposals (numbered; effort S/M/L; pillar served)

**P1. State-transition bark layer (both factions).** Wire VOManager calls into existing seams: `_set_tier` (SUSPICIOUS = query bark, ALERT = warning shout, COMBAT = contact scream), `_set_goal` on FLANK_TARGET/ADVANCE adoption (doctrine 5.6's "vocalize before flanking" — currently unimplemented), rout (exists), ally equivalents on target acquisition/suppression/man-down. Pure plumbing on existing hooks; anti-spam cooldowns already exist in VOManager. **Effort S. Pillars 2, 4, and fairness (1).**

**P2. BCS-lite landmark callouts.** SitePlanner/generator tags placed structures and terrain features with noun keys ("hooch", "dike", "treeline", "wreck"); ally contact barks resolve `{enemy} {octant-relative-direction} {nearest-landmark-to-target}` → subtitle always, VO when a matching wav exists. Enemy side gets the Vietnamese equivalent for *their* callouts (information the player can learn). **Effort M. Pillars 4, 2.**

**P3. Emplaced MG archetype (the pin).** New EnemyData archetype + behavior: anchored to a gun position (leash ≈ 0), SUPPRESS_TARGET as dominant goal, sweeps a beaten zone around last-known (fires at *area*, not believed-position raycast center), long bursts with sustained tracer stream, exposure-ramp accuracy retained (the pin is survivable by doctrine), abandons gun only via the turret retarget ladder (§6.1) or flank contact <8m. Player counter = route around it: Pillar 3's freedom made legible. **Effort M. Pillars 1, 2, 3.**

**P4. Tracer discipline in WeaponData.** `tracer_ratio` (MG 1:4, AK/SKS 1:7 or 0 for VC militia night ambushers, US red vs ComBloc green via `tracer_color`), remove the hardcoded every-round green in `_fire_at_target` (and ally/player paths for parity). Muzzle flash + report stay every-round (fairness floor, canon 5.6). MG streams become the battlefield's readable geometry. **Effort S. Pillars 1, 2.**

**P5. Radio/alarm counterplay + bounded per-source reinforcement caps (R2/R4).** Physical radio prop per camp (damageable, optional objective — MISSION_DESIGN_RESEARCH §5.4.4 already specs it), runner behavior reusing existing goal machinery, `_hunter_pool` draws gated by witness events and per-source caps instead of one global timer. This is the escalation-not-fail-states pillar made mechanical, and it's the project's answer to CoD's faucet. **Effort L (prop + runner + director bookkeeping). Pillar 3 (primary), 5.**

**P6. QRF arrival honesty (R3).** Hunters spawn at map edge/road nodes (world-anchored, not player-ring), grouped as one squad with `squad_id`, moving leash, audible approach telegraph (engine loop / chatter / flare) 20–40s before contact possible. Replaces `mission_director.gd:89-96` ring placement. **Effort M. Pillars 2, 3.**

**P7. Ambient-war audio director with a silence budget.** Distant arty rumble, far-off firefight exchanges, Hueys crossing — a 2D/3D bed whose *density is a mission parameter* and which is **suppressed near cleared/quiet AO state** (the war is elsewhere; here it is eerily over). Hard rule: after a pocket is exhausted, minimum 90s of bed-free wildlife-silence before any distant layer may return. The eerie quiet is authored by contrast, never filled. **Effort M. Pillar 2.**

**P8. Pocket wake choreography.** When a dormant garrison wakes (noise/trigger/runner), stagger per-man activation 0.3–1.2s with barks and cover-node scrambles instead of synchronized combat entry — the camp visibly *comes alive* (CoD's best theater beat, fully systemic here: it's just jittered wake + P1 barks + existing cover-first doctrine). **Effort S. Pillar 2.**

**P9. Squad probe response.** A pocket that hears distant priority-≥6 noise dispatches a bounded probe (2 men, existing patrol/investigate machinery, moving leash toward noise origin) while the rest anchor — CoD2's "groups farther away send units to investigate," which is also authentic VC practice. Gives the stealth player moving targets and the loud player early warning skirmishes. **Effort M. Pillars 2, 3.**

**P10. Last-man-confirmed quiet (R5).** MissionDirector tracks per-pocket ledgers; on pocket exhaustion → delayed squad bark ("think that's all of 'em…"), wildlife audio return timer, debrief credit. Cheap, and it converts the finite-enemy design decision into a *felt* feature instead of an absence. **Effort S. Pillars 2, 5.**

### Suggested order
P1 → P4 → P8 → P10 (all S, all pure payoff on existing systems) → P3 → P6 → P9 → P2 → P7 → P5 (the L item lands last but is the pillar-critical one; bead it as an epic).

---

## Sources
[GameSpot CoD2 developer Q&A](https://www.gamespot.com/articles/call-of-duty-2-qanda-story-characters-weapons-vehicles-ai/1100-6123417/) (BCS, enemy AI, finite-set-reacting claim) · [CoD Wiki — Wehrmacht quotes](https://callofduty.fandom.com/wiki/Wehrmacht/Quotes) · [CoD Wiki — MG42](https://callofduty.fandom.com/wiki/MG42) · [CoD4 SP Color Groups — zeroy wiki](https://wiki.zeroy.com/index.php?title=Call_of_Duty_4%3A_SP_-_Color_Groups) · [CoD4 SP Basic AI Paths — zeroy wiki](https://wiki.zeroy.com/index.php?title=Call_of_Duty_4%3A_SP_-_Basic_AI_Paths) · [Steam CoD AI scripting basics](https://steamcommunity.com/sharedfiles/filedetails/?id=321250822) (spawner flags/count, engagement distances) · [GameFAQs WaW respawn thread](https://gamefaqs.gamespot.com/boards/944199-call-of-duty-world-at-war/47669339) · [CoD3 review — infinite respawns](https://gamefaqs.gamespot.com/ps3/932962-call-of-duty-3/reviews/108583) · [Quora — CoD4 respawns](https://www.quora.com/Do-enemies-infinitely-respawn-in-Call-of-Duty-4) · [Old PC Gaming — CoD1 review](https://oldpcgaming.net/call-of-duty-1-review/) (ambient theater, deterministic scripting) · [PC Gamer — MoHAA reappraisal](https://www.pcgamer.com/reappraising-medal-of-honor-allied-assault-one-of-our-highest-scoring-shooters-ever/) · [HLL tracer discussion](https://steamcommunity.com/app/686810/discussions/0/1607148447814270534/) · [Axis History Forum — tracer ratios](https://forum.axishistory.com/viewtopic.php?t=46415) · Speculation is marked inline (§1.9); RTCW/MoHAA/Quake-3 mechanics cited from `MISSION_DESIGN_RESEARCH.md` rather than re-derived.
