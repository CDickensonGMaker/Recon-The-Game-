# GAME-DESIGNER / ATMOSPHERE — Support Fire Test Room

**Lens:** Does a support-fire benchmark + environmental destruction SERVE the pillars, and does
destruction READ in PSX low-poly? Judging value/priority, not implementation.

**Sources verified:**
- Fire-support roster is BUILT — `scripts/missions/field_director.gd:249` (`fire_support` dict),
  `:418-449` the `match` that already fires each type with a `toast.emit()` banner **and** a
  `_radio_vo()` bark (snake_eye/napalm_run/arty_barrage/mortar/spooky/cbu_cluster). The *call* and
  its *audio-visual language* already exist; what's missing is the ordnance hitting a world that
  reacts.
- Screen shake prior art exists — `scripts/player/player.gd:1394-1400` drives a concussion camera
  h/v-offset jitter (`_shake_seed`, pure-visual, never touches aim). This is the exact hook a blast
  needs; no new shake system required.
- Debris spawner exists — `scripts/combat/gib_system.gd:318 _spawn_gib()`. Phase 2b/4 correctly say
  reuse it, do not write a second.
- Craters BUILT — `terrain/systems/damage_system.gd` (heightmap dig + scar Decal, DamageType
  profiles, `MAX_DEFORMS_PER_MISSION = 40`).
- Pillars of record — `production/bible/BIBLE.md:84-95`.

---

## Q1 — Does state-based destruction READ in PSX low-poly?

**Yes — and PSX is the *easy* case, not the hard one.** The whole doctrine of PSX-era destruction
(Syphon Filter, MGS, RE, the early Battlefields) was exactly the state-swap: the crate is whole,
there's a puff and a bang, the crate is now a different mesh of splinters. Nobody fractured anything.
Low-poly is *forgiving* of the hard swap because the eye isn't tracking sub-object continuity — there
are no high-frequency surface details for a swap to violate. A 300-tri hut becoming a 300-tri
burned-hut inside one frame of a dust cloud is invisible as a swap and reads as a collapse. Chasing
real-time fracture here would be *anti*-PSX (ADR-001) as well as a perf disaster.

**What actually sells "I destroyed that" — in strict priority order:**

1. **The occlusion frame.** The single most important trick: the swap must happen *behind* the
   particle burst / smoke, never in clear air. Spawn the one-shot dust/smoke burst, swap the mesh on
   the frame the burst peaks (~0.1-0.2s in), and the player never sees the pop — they see a cloud
   clear to reveal a ruin. This is free and it is 60% of the illusion.
2. **Screen shake + SFX concussion.** The blast has to *hit the player's body*, not just the object.
   `player.gd:1394` already does the camera jitter; wire a distance-scaled kick + a low-end thump
   into every `damage_area()` site. Feel is what upgrades "a mesh changed" into "an explosion
   happened." This is the difference between a UI event and a firefight.
3. **Permanence.** The ruin/log/crater must still be there when the player walks back. A destruction
   that heals is not destruction — it's a decoration that plays once. Permanence is what makes the
   world feel *authored by the player's violence* (Pillar 2, Pillar 3). The crater system already
   gives this for terrain; the swap gives it for objects.
4. **The particle burst itself** (leaf scatter for trees, splinter/thatch for huts, dirt column for
   craters). Necessary but least differentiated — it's the wrapper, not the payload.

**The minimum that reads as "I destroyed that":** mesh-swap under an occluding one-shot burst +
distance-scaled screen shake + a permanent changed state. Three cheap things. If any one is missing
the effect collapses: no burst → you see the pop; no shake → it's a menu event; no permanence → it
was a magic trick. All three are already-built or one-line hooks. **This is a low-risk READ.**

---

## Q2 — Is "fell a tree to BUILD cover" a real Pillar-3 win? Layer ranking.

**It is the single most Pillar-aligned idea in the entire plan, and it is worth the build —
*conditionally* (see Q5).** Here is why it's not a tech-demo novelty:

- It creates a **verb that generates its own stories** — the exact language of Pillar 3
  (`BIBLE.md:87`, "the seeded world generates the tactical problems, so the stories come from what
  happened here"). "I couldn't cross that paddy under fire, so I dropped the treeline across it and
  crawled the log" is a *player-authored* tactical solution to a *seeded* problem. That is the pillar
  firing exactly as designed.
- It is **legible and physical** — a soldier understands "that tree is now cover" instantly, no UI,
  no tutorial. It reads in one glance (Pillar 2 atmosphere sells it: a felled hardwood across open
  ground *looks* like Vietnam).
- It closes the loop with systems already present: the log is hard cover the **AI also uses**
  (`DESTRUCTIBLE_JUNGLE_PLAN.md:239`), so felling it changes the firefight for both sides — that's
  Pillar 1 (believable firefights) and Pillar 4 (the squad reacts to terrain you made) getting free
  value from one verb.

The plan's own verification line is correct and should be law: *"drop a tree across open ground and
use it to cross a field you couldn't cross before. If that isn't fun, the whole feature is
decoration"* (`:364`). That is the honest gate.

**LAYER PRIORITY (by pillar value per unit of risk):**

1. **TREES (+ the log verb)** — highest. Uniquely serves Pillars 1, 2, 3 *and* 4, and it is the only
   layer that gives a *new player verb* rather than just a reaction to fire support. The bitmask-hide
   approach (`:169-207`) is also the cheapest of the three (flip a bit, zero mesh surgery). Best
   value, lowest cost. **Build this first.**
2. **TERRAIN (craters)** — second, and it's nearly free because `DamageSystem` is **already built**
   (`terrain/systems/damage_system.gd`). Craters are atmosphere (Pillar 2) and honest cover/LZ
   enablement (Pillar 3, the player-made-LZ mechanic in Phase 3). Reuse, don't build — so its cost is
   wiring, not authoring. High value, near-zero build.
3. **BUILDINGS** — third. Real value (see Q3) but highest perf risk and most authoring surface, and
   it does *not* create a new verb — it's a reaction to fire support you already have. Serve it last.

Note terrain outranks buildings on *value-per-risk* even though buildings are more dramatic, because
terrain is already built and buildings carry the perf tail.

---

## Q3 — Does building destruction serve the loop, or is it a distraction?

**It serves the loop — flattening a village/camp with fire support is a *core fantasy beat*, not a
side toy — but it is the layer most in tension with the perf budget, and it must be gated behind
trees+terrain proving out first.**

Why it serves the loop:
- The AO is villages, camps, bunkers (`site_planner.gd` stamps them). Right now you can call an arty
  sheaf onto a hut complex and **the huts do not care** — the fire-support roster (already built,
  `field_director.gd:418`) lands on an inert world. That is a *believability hole* (Pillar 1): a
  thatch hooch that eats a 105mm round and stands is the immersion-breaker the plan names
  (`DESTRUCTIBLE_JUNGLE_PLAN.md:328`, "a hooch that *survives* a grenade is what breaks immersion").
- A bunker that shrugs off a grenade and needs a LAW/satchel is a **tactical puzzle** — it tells the
  player which tool to spend, which is Pillar-1 weapon identity doing real work.
- Village destruction is also *moral weight* (Pillar 2 atmosphere / the war's tone). Flattening a
  hamlet should feel like something. That's free thematic payload the game currently throws away.

The distraction risk is real and specific:
- Perf (ADR-026, the top systemic risk — deep-night 18v18 already 19-23fps). A hundred `Destructible`
  bodies each with a collider, a swap, a debris burst, and a `DamageSystem.apply_damage()` crater
  call is a *lot* of simultaneous work if a whole village goes up in one arty mission. **This must be
  budgeted** (stagger the crater calls — the arty code at `field_director.gd:437` already only
  deforms `i % 3 == 0`, good instinct — cap concurrent debris, share the fallen-rubble MultiMesh).
- The filename-footgun (`site_planner._SOFT_NAME_HINTS`) MUST die first (`:288-299`) or Phase 4
  spawns a hundred models onto a landmine. That's a correctness gate, not a nicety.

**Verdict: worth it, but it is Phase LAST, and it is the layer the benchmark exists to stress.**

---

## Q4 — Is the test room worth building as a permanent instrument? What must it prove?

**Yes — build it as a permanent benchmark, exactly like the AI arena, for the same reason the arena
earns its keep (Pillar 1: "the stress-test arena is the gate," `BIBLE.md:85`).** Destruction and fire
support are precisely the systems that are *invisible until they misfire* — a crater that doesn't dig,
an M79 that fires hitscan (the real bug, `m79.tres projectile_data_path=""`), a hut that's bulletproof
because it's named "hut." You cannot catch these by playing; you catch them by walking a controlled
row. A permanent room is cheaper than the bugs it will keep catching.

**What it must prove to a designer's eye (not just a probe's):**
1. **Every fire-support type visibly does something to the world** — the roster at
   `field_director.gd:249` fires against a rack of trees/huts/bunkers/terrain and you *see* each one
   land and change state. This is the "do explosions work" answer Caleb actually asked for.
2. **The READ gate** — stand at fixed distance, call each strike, and judge by *eye*: does the swap
   hide under the burst? does the shake sell it? (Q1). A green probe that says "mesh changed" proves
   nothing about whether it *looked* destroyed. The room is where a human confirms the illusion.
3. **The verb gate** — a strip of open ground with a treeline on one edge and a target on the other:
   fell the trees, then cross behind the log under fire. If it isn't fun *here*, it never will be in
   the AO (`:364`).
4. **Material honesty** — a penetration lane: `vc_hut_bunker.glb` must now STOP the round; thatch must
   fall to one grenade; bunker must need a LAW (`:368`). This is the lane that proves ballistics came
   off *authored data*, not the filename.
5. **Perf headroom** — a "flatten the whole village at once" button that spikes the worst case, read
   against the ADR-026 budget. The room is the safe place to find the framerate cliff before the AO
   does.

**Design caution the room must honor** (the plan states it, `:369-373`): every lane needs a control
that fails LOUD if the gun isn't firing — the penetration probe once went green because the gun never
fired and "cover stopped it" is trivially true when nothing was shot. A benchmark that can pass while
proving nothing is worse than no benchmark.

---

## Q5 — The single sharpest pillar tension for the Summoner

**Permanence (Pillar 2/3) versus the perf budget (ADR-026) — and it bites hardest exactly where the
feature is most valuable.**

The log-cover verb and player-made craters are *only* worth building if they are **permanent** — a
log that evaporates while you're prone behind it is, in the plan's own words, "a promise the game
breaks" (`:240`), and a healing crater is a decoration, not destruction. Permanence is the entire
source of the Pillar-3 "you authored this battlefield" payoff. **But permanent means accumulating** —
every felled log, every crater, every ruined hut is a persistent collider + mesh + nav re-carve that
never goes away for the whole patrol, and the game is *already* at 19-23fps in the worst case.

The two pillars pull opposite ways: atmosphere/freedom want *everything you did to stay*; performance
wants *the world to forget*. There is no free lunch here. **What is sacrificed either way:**
- Honor permanence fully → you accept a rising perf tax across a long patrol and must cap-and-recycle
  the *oldest* (the plan's ~96-log safety valve, `:243`) — which means on a long enough patrol, the
  *earliest* thing you destroyed quietly heals. The promise is kept locally and broken globally.
- Protect perf → you time things out or cap aggressively, and you gut the exact verb that justified
  the build.

**The ruling Caleb must make:** what is the permanence *budget* — how many player-authored
destruction artifacts (logs + craters + ruins) may persist at once before the oldest recycles, and
does recycling ever touch anything *within the player's current view/engagement*? (It must not — a log
vanishing on-screen is the unforgivable version.) Recommend: permanence is **sacred within the active
firefight radius**, recycling only reclaims artifacts far behind the patrol. That protects the felt
promise while capping the cost — but it is his call, because it trades a slice of "the world remembers
everything" for a framerate the deep-night AO can survive.
