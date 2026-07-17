# THE DECREE — Full Game Audit #2: The Drift Audit (2026-07-10)

Six architects audited independently (`analysis/`); the debate record is `discussion.md`. The Arbiter weaves.

## The one-line diagnosis
**The drift is real, but it is not in the code you feared — it is in the law and the ledger.** The
long-window's new systems (save backbone, hub, VO, locational damage, fire support) are mostly well-built
and strictly typed. What rotted: *code comments claim fixes that don't exist, CLAUDE.md teaches a dead
game, the council's own laws were ignored within hours, and the scoring economy trains the player against
Pillar 3.* The game is better built than it is governed.

## Pillar scorecard (council average of six lenses; audit #1 in parentheses)
| Pillar | Score | Verdict |
|---|---|---|
| 1. Outstanding gunplay | **3.3** (3.0) | unification + feedback grammar real; still ungated by any FPS number; Mosin one-shot lurks in data |
| 2. Atmosphere | **3.1** (2.8) | VO/radio/weather shipped; the Summoner's eyes overrule: speck soldiers, popping terrain, tame jungle |
| 3. Freedom | **2.9** (3.4) | **DOWN — the audit's headline.** Stealth fix never landed (comments lie); scoring pays kills×10; village raid demands bodies |
| 4. The squad is the RPG | **3.4** (3.2) | XP/roster/VO strong; squad keys unverified across two playtests; loss still costless |
| 5. Fail forward | **3.4** (3.4) | HARD checkpoints + all-or-nothing commit genuine wins; default quicksave-anywhere quietly repeals the pillar |
| **Process compliance** | **1.5** (—) | gate law lasted ~2h; perf day skipped; KILL/SHRINK rulings ignored; a decree item marked done that isn't |

## The verdict on the drift fear
1. **Code quality did NOT drift.** Strict typing near-perfect (3 untyped vars / 90 files). MissionScope,
   SaveManager, fire-support fixes verified genuinely correct. The long window built well.
2. **Truth drifted.** o18o claimed fixed in comments, not fixed in code (`enemy_base.gd:1497` vs `:189-191`).
   96114f5 says damage unification "closed" at ~80% (4 live WW2 .tres, Mosin one-shot on vc_rifleman).
   CLAUDE.md false on damage, renderer, FOV. PLAYER_MANUAL 9 gaps. FOUR roadmap files disagree.
3. **The economy drifted.** Debrief pays kills×10, tracks zero avoided contacts, banks 1:1 into XP —
   the game *teaches loud* while the design sells a stealth economy.
4. **Presentation drifted behind simulation (again).** Survival, saves, consumables, detection: all
   simulated, none displayed. The r4bk lesson ("a feature without a HUD affordance doesn't exist")
   was codified into law and violated the same night.

## What is genuinely strong (verified this audit, keep building on it)
1. **The save backbone** — versioned, deferred, tier-derived; best new code since audit #1 (needs atomic writes).
2. **The walkable firebase hub** — right shape for Pillars 2/4; ratified with conditions (ADR-008).
3. **Fire-support ladder post-fixes** — adversarially verified really fixed.
4. **Locational damage + blood v2 + VO** — the combat feedback grammar is nearly complete.
5. **The test harness's honesty about what it covers** — 38 scenes, headless-boot law known; it needs
   eyes (scale probe, FPS gate), not replacement.

## The wounds, ranked
1. **STEALTH ECONOMY VOID (Pillar 3, second audit running):** o18o not fixed + kills×10 scoring +
   80% village body count. The entire ghost-play payoff chain is dead while its comments claim otherwise.
2. **THE THREE VISUAL P0s (Summoner's ground truth, all root-caused):** tiny units (ModelActor AABB
   measures mesh space, k=0.02–0.20 observed), terrain pop (3km streaming policy inside a fully-loaded
   1280m map), tame jungle (no wind sway, no undergrowth layering).
3. **PERF STILL UNMEASURED:** decree item 4 skipped; `rendering_method` unset (Forward+ on Intel UHD);
   19-25 FPS baseline stands; MAX_THINK_TIME declared, never used; decals uncapped.
4. **INVISIBLE SYSTEMS:** no HUD for hunger/condition/consumables/stamina/breath; F5 toast has no
   listener in the hub; F9 silent; Esc pause has no menu; detection pip unshipped after two decrees;
   hub prompts show [E], listen F.
5. **DATA LETHALITY DRIFT:** Mosin 1d10+68 (avg 73.5 ×2.0 torso = one-shot at all ranges, all the time)
   on the *basic* VC rifleman while elite NVA fire PPSh (avg 16.5). Lethality by data lineage, not design.
6. **LAW ROT:** CLAUDE.md (injected every session) false on damage/renderer/FOV; four roadmaps; bible
   9/12 unwritten; the manual stale. This is what made the drift *feel* extreme.
7. **PROCESS FAILURE:** laws are markdown, not mechanisms. Empirically measured half-life: 2 hours.

## Scope rulings (Summoner holds final authority)
- **RE-AFFIRM KILL:** sprite render matrix (9xd/j8o) — close the beads this time; 3D is the renderer
  (ADR-001). A/B far-LOD with existing sheets remains optional evidence-gathering, not a track.
- **PARK:** hunger (fields stay in SaveData, drain removed) until missions exceed ~40 min (ADR-009).
- **RE-AFFIRM FREEZE:** coop, interiors, driveables, capture epic, battle director — unchanged.
- **RE-AFFIRM SHRINK:** 100 bios → 20 great ones (ooel to be re-scoped).
- **RATIFY (retroactive, with conditions):** walkable hub (ADR-008) · per-weapon ADS zoom (ADR-004) ·
  locational damage grammar (ADR-002/003 family) · save-tier ladder with UI-visible tier derivation (ADR-007).

## Build order (the decree)
0. **PLAYTEST R3 remains the session entry point (ida9)** — everything below except #1 waits for no one,
   but nothing NEW ships until R3 verifies a2qb/r4bk and the fixes below land.
1. **STEALTH RESTORATION BUNDLE (the ONE build):** real witness guard (beacon only if victim survives or
   is witnessed; delete the lying comments) + GUNSHOT noise 55→~150m + RECON ±25 contact scoring replacing
   kills×10 + optional village clear. Close with a headless probe. (o18o, new scoring bead)
2. **TRUST-RESTORATION DAY (perf + visual P0s, measured):** rendering_method A/B → set it; ModelActor
   instance-space AABB fix (accept k≈0.9); streaming OFF for ≤2km maps; decal FIFO cap; wire MAX_THINK_TIME.
   Close 8pbo + n2ij's first two items with before/after numbers.
3. **PLAYER-STATE HUD LAYER (fmc8 milestone 0):** condition/consumables/stamina/breath cluster + the
   detection pip + save/load feedback + pause menu + [E]→F prompt truth. r4bk's law finally honored.
4. **DAMAGE DATA FINISH:** WW2 .tres deleted/replaced, vc_rifleman→SKS (RECON dice), descriptions match
   loadouts, CLAUDE.md damage law rewritten to code truth.
5. **HUB CONDITIONS (ADR-008):** RECON 7-element briefing into the TOC flow + Huey ride restored to the
   campaign path (it also masks world load).
6. **JUNGLE FEEL PASS (n2ij item 3):** wind-sway shader, undergrowth layer, density/composition —
   after #2's measurements say what we can afford.
7. **LAW & LEDGER CLEANUP:** GameEnums + dead RTS code purged; roadmaps consolidated into ROADMAP.md;
   PLAYER_MANUAL corrected; GAME_GUIDE.md + ADRs become canon (this session's deliverable).

## Process laws (mechanical this time — ADR-015)
- **GATE bead:** `RECONgame` gets a standing GATE bead blocked by all open playtest P1s; every new
  feature epic gets `bd dep add <epic> <gate>` so `bd ready` physically hides feature work while
  playtest P1s are open. Bug fixes, presentation for existing systems, and decree items are exempt.
- **Verification law:** no decree item or playtest P1 closes without a probe, measurement, or verified
  playtest. "Mitigated"/"investigated"/"likely fixed" never closes a bead.
- **Truth law:** a code comment may not claim a behavior a probe hasn't verified. The Bible/GAME_GUIDE
  is amended by explicit decision, never silently.
- **Test-suite eyes:** add a rendered-scale probe (screenshot or k-value assert) and a gating FPS number.

## Tradeoffs named (no free lunches)
Ratifying the hub rewards a process violation — accepted because the mechanical gate now exists.
Parking hunger sheds "hardcore sim" surface to concentrate on felt systems. Killing sprites (again)
abandons ~600 rendered frames. The gate law will genuinely slow feature velocity — that is its purpose.
Scoring avoidance over kills makes loud runs pay less XP; loud remains *viable* (Pillar 3) but stops
being *optimal training*. The perf day spends a full session producing zero features and one number
that gates everything after it.
