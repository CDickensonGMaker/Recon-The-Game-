# BRIEFING — PLAYTEST FINDINGS, 2026-07-13

**Convened by:** §10 Director (RECONgame) · **Session type:** Playtest-driven scope recalibration
**Sister session:** `archive/2026-07-13_jungle_not_plugged_in/` (still active; this session BUILDS ON it, does not relitigate).

---

## 0. WHY THIS SESSION EXISTS

The Summoner played the build for ~10 minutes and reported five concrete observations. Three map
onto already-beaded bugs from this morning; two are fresh inputs the prior council did not see.
The standing decree (OVERSEER_CHARTER §8) says: **any pillar-touching or scope change goes through
the council first.** Two of the five findings are scope changes. This is a council, not a fix.

---

## 1. THE FIVE FINDINGS (verbatim, owner voice)

1. **"Squad that spawns in have additional models attached, not v3 grunts."**
2. **"Firebase is great for placeholders but that will have to be its own thing I customize."**
3. **"None of the 3D terrain is in the game — still 2D trees."**
4. **"There were rivers and deep water, and all the trees spawned in the water, etc."**
5. **"We need to add a swimming and bouncy effect to the player, and that's when the US models
    should do the swim animation."**

---

## 2. CANONICAL BINDING

- **Pillars (5):** gunplay · atmosphere · freedom · squad is the RPG · fail forward.
- **ADR-014:** GAME_GUIDE + ADR/ > this briefing. **ADR-015:** feature epics blocked while playtest
  P1s are open. The GATE bead `97u3` is mechanically held by 7 P1s.
- **ADR-023 (Fossil Law):** every replacement buries its predecessor, in the same change.
- **The Summoner holds final authority; the Director holds the pillars; the war room advises.**

---

## 3. PRIOR-CONTEXT THE COUNCIL MUST NOT RE-PROVE

- **jungle_not_plugged_in synthesis** is the binding architectural verdict for the jungle wiring.
  Phase 0 = measure perf. Phase 1 = determinism fix in `has_line_of_sight`. Phase 2 = paddy as site.
  Phase 3 = trunk colliders, defer destruction. **Do not relitigate; build on it.**
- **`RECONgame-v58s`** carries the paddy root cause (map min elevation 87.9 m; gates impossible;
  riparian inversion). **The fix is in the prior decree; this session ratifies priority, not design.**
- **`RECONgame-xo7i`** carries the terrain-preset root cause (game has only ever generated
  ROLLING_HILLS; `set_preset()` called from exactly one place, the dev tool). The fix is one line
  + a table. **This session ratifies priority, not design.**

---

## 4. THE MAPPING (Drafter's guess; council must verify and correct)

| # | Finding | Best-guess bead | Tier | Council action |
|---|---------|-----------------|------|----------------|
| 1 | Squad second body | `eq6n` (Base_Human) + `x1bs` (gear donors) — **already beaded P1** | Bug | Confirm fix path; ratify as Decree item 1 (must precede any squad-art work) |
| 2 | Firebase is placeholder | `222e` P3 "Firebase designer" + un-beaded complaint about *the current placeholder being too concrete* | Scope statement | **Defer** custom firebase; **shrink** the shipped placeholder so it does not pretend to be a system. Owner's own scope call. |
| 3 | No 3D terrain, still 2D trees | `en75` P1 (23 patches exported) + `wwz4` P2 (grass_patch.fbx missing) | Wiring bug | Ratify prior Phase 0/1/2/3 sequence. **Add: `wwz4` resolves inside Phase 0 — either ship the asset or kill the lie.** |
| 4 | Trees spawning in water | `xo7i` P0 (one terrain preset) + `v58s` P0 (paddy elevation band) | Wiring bug | Ratify prior Phase 0/2 fix. **The trees-in-water is a downstream symptom of `xo7i` and is healed when the paddy+water layer is correct.** |
| 5 | Need swimming + bouncy + US swim anim | `4x7` P3 (R37 water gameplay) + `wzal` P2 (Player-feel anim wishlist) | **Scope CHANGE** | **Promote to live work** as a new epic; must NOT preempt the GATE; defines the binding condition that the prior decree's Phase 2 (paddy as site) creates the WATER that the swim gameplay needs. |

---

## 5. THE TENSIONS THE COUNCIL MUST RESOLVE

- **T1 — Scope vs GATE:** `97u3` blocks feature work. Water gameplay + swim anim ARE feature work.
  Is the Summoner overriding the GATE? Or is the swim work a presentation layer for an already-
  shipped system (water collision already exists per `v58s`'s `get_water_depth()` contract), making
  it **exempt** under OVERSEER_CHARTER §8 ("presentation for already-shipped systems")?
- **T2 — Visual vs perf:** Adding swim anim, bouncy, water-fx is visible work. The prior decree's
  Phase 0 said **MEASURE FIRST**. Adding new shader work before a native-resolution FPS number is
  exactly the perf anti-pattern that the P0 GATE is meant to prevent.
- **T3 — Owner-stated vs council-stated priority:** Owner's "we need to add swimming" is a clear
  reprioritization. The council must honor it, but it must not violate the GATE; the deliverable
  is a **sequencing decree**, not a "drop everything."
- **T4 — The `eq6n`/`x1bs` blockers:** Both are P1 BUGS that are still open. Finding #1 is the
  Summoner reporting the visual symptom of these. **They are the actual highest-priority work**
  because they ship *wrong art* into the next playtest. The P1 GATE is mechanically held by
  playtest P1s that are *playtest blockers*, not art-blockers. The council must clarify: do
  `eq6n`/`x1bs` count as **standing-decree items** under §8, exempt from the feature-work block?

---

## 6. THE COUNCIL'S DELIVERABLE

1. **Decree** naming the playtest findings as a new playtest-driven epic; tiering them against the
   standing decree; reconciling T1–T4.
2. **Per-bead verdicts** for `eq6n`, `x1bs`, `en75`, `wwz4`, `v58s`, `xo7i`, `4x7`, `222e`,
   plus any new beads the council opens.
3. **A concrete next-action list**, each line either a `bd update` or a `bd create`.
4. **What is sacrificed.** The law binds the Arbiter too.
5. **Architects to summon:** Godot Specialist (visual+engine), Lead Programmer (the wiring +
   the `eq6n` fix), Level Designer (terrain preset + paddy siting), Animator (swim anim +
   second-body model), Game Designer (water gameplay design + scope).

---

## 7. THE LAWS (binding on this session)

- No decree may violate a Pillar. **Pillar 3 (freedom, no rails) is the one most at risk here.**
- Tradeoffs must be named.
- A playtest P1 is a P1; do not deprioritize without a probe.
- "Mitigated" never closes a bead. Name the proof.
- "Done" without a probe/measurement/verified playtest is a lie.
- ADR-023: every replacement buries its predecessor in the same change.
- The standing decree is the build order. This session SEQUENCES against it, not in parallel.
