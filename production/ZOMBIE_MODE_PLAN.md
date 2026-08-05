# JUNGLE UNDEAD — survival mode plan

**Status:** PARKED. Not green-lit, not scheduled. Written 2026-08-05 so it survives the session.
**Owner's framing:** a small shippable side output while RECON's main scope runs long — *and* a
candidate expansion mode for RECON itself later.

**Premise:** round-based survival at the firebase, built almost entirely from RECON parts.
Not a separate project. A scene in this repo, in `scripts/levels/`, alongside the AI stress arena.

---

## 1. THE RULE THAT KEEPS THIS SMALL

**No new art may be authored for this mode.** Every model, texture, weapon, animation and structure
comes from what RECON already ships, or it does not go in.

The moment something is being modelled *for the zombie mode*, the premise is dead and the mode should
be cancelled. That is the tripwire, and it is the whole reason this is worth doing at all.

Corollary: viewmodel defects fixed along the way are RECON's bill, not this mode's. They were already
owed (`viewmodel-open-defects-2026-08-05`: shotgun, M70, M79, Mosin still open; M60 confirmed fixed).

---

## 2. SCOPE — locked small on purpose

| | Count | Note |
|---|---|---|
| Maps | **1** | The firebase. Nacht der Untoten was one map. |
| Undead types | **3** | Shambler · Runner · one special |
| Weapons | **5** | From the existing US armory |
| Perks | **3** | Maximum |

**Explicitly NOT in scope:** Pack-a-Punch · Easter-egg quest · second map · boss rounds · co-op
(see §7) · any new character model · any new weapon.

Three levels was considered and cut. Round-based survival gets its replay value from the round curve
and the economy, not from map count, and three maps triples the polish burden — which is the part the
owner correctly identified as the real cost.

---

## 3. WHAT ALREADY EXISTS (verified 2026-08-05)

This is the reason the mode is cheap. All pointers checked against code on the date above.

**Wave director — `scripts/missions/siege_director.gd`**
- Chained survival waves already run: `ai_stress_arena.gd:88-89` (`SIEGE_STRENGTH = 30`,
  `WAVE_BREATHER_S = 15.0`), relaunched by `_on_siege_ended`. This is the owner's 2026-08-04 ruling
  ("send 30 people at a time … chained for as long as he lasts") already live.
- Spawn ring + deferred materialize: `SIEGE_RING_MIN/MAX`, `SIEGE_MATERIALIZE_M`, `MarchingCell` —
  cells stay dormant until close. Exactly the "spawn out of sight, walk in" behaviour needed.
- Live-body budget with hold and thaw: `siege_director.gd:453-484`. Cells are held at the ring when
  `LIVE_CAP` (50) is reached and released as the dead make room. This is the Zombies spawn-budget
  mechanic, already written and already debugged.
- Kill ledger (`run_strength` / `run_peak` / `killed_count`), mid-wave escalation (`reinforce`),
  reap/despawn of leftovers.

**Everything else the mode needs, also already shipped**
- The firebase: interiors, chow hall, medical complex, bunkers, kit, chunks.
- Gore: `GibSystem`, `force_gib` crank in the arena (`ai_stress_arena.gd:182`).
- Night environment, illum flares, campfires, dense jungle, fellable treeline.
- US armory + FP viewmodels; PSX character models and the animation library.
- Down/revive exists on the medic path — retarget to the player rather than rebuild.

---

## 4. WHAT IS ACTUALLY WRONG FOR ZOMBIES

Three behaviours the siege system has that must change. Two are trivial, one is real.

**4.1 — It breaks. (trivial)**
`BREAK_BASE_RATIO = 0.575` routs the assault at ~42.5% killed and reaps the survivors. The undead
never break and never withdraw. Flag off the break-state check and the reap path.

**4.2 — No round curve. (small)**
Currently one fixed-strength wave, repeated. Needs round N → body count and HP scaling. The ledger
already supports it; this is a curve function, not a system.

**4.3 — Barricades cannot open a path. (THE REAL BLOCKER)**
From the file's own note, `siege_director.gd:64-67`: nothing re-bakes the navmesh when a parapet
segment dies (`nav_baker.gd:16-18`), and the barbwire is a single merged ring that cannot be broken
at all. **The only way in is the wire gate.**

For a siege that is correct doctrine. For zombies it kills the core loop — the genre *is* "they tear
through the boards and come in somewhere new."

**Recommended resolution: fixed boarded entry points, not arbitrary wall destruction.** Discrete
openings (windows, doorways, wire gaps) that toggle as nav links when their boards are torn down or
repaired. Cheaper than nav rebaking, doesn't touch the baker, and it is how the real games do it
anyway — you board windows, not walls.

---

## 5. WHAT MUST BE BUILT

**5.1 `ZombieBase` — write it fresh, do NOT subclass `EnemyBase`.**
`EnemyBase` is a goal-driven soldier: seeks cover, suppresses, flanks, weighs force ratio, routs.
A zombie wants none of it, and making it dumb enough means fighting every system inside it.
Straight-line path to nearest player, melee attack, loud death. ~200 lines, and far cheaper per body
than a soldier — which matters at a 50-body live cap.

The three types are one model reskin plus two behaviour variants:
- **Shambler** — the wall of bodies. Reskinned grunt/VC.
- **Runner** — same model, faster clip set, enters from ~round 6. Changes the panic curve.
- **One special** — a crawler under the wire, or a screamer that pulls the horde. **One.**

**5.2 Points economy.** Kills pay, points buy. This is the entire loop; without it the mode is just
an endless horde. Build it first.

**5.3 Wall buys + mystery box.** The reason to leave the safe room.

**5.4 Boarded entry points + repair.** Per §4.3.

**5.5 Round curve.** Per §4.2.

**5.6 Player down + revive.** Retarget the existing medic revive.

That is the whole bill. Two genuinely new systems (economy, barricades); everything else is small.

---

## 6. BUILD ORDER

Each step should be playable before the next begins.

1. **Scene + wave loop.** Fork the arena scene pattern into `scripts/levels/`. Wire `SiegeDirector`
   with break and reap disabled. Prove: endless waves arrive and can be fought.
2. **`ZombieBase` + shambler.** Replace the soldier actor. Prove: a horde beelines and kills.
3. **Round curve.** Prove: round 12 is meaningfully harder than round 2.
4. **Points + wall buys.** Prove: the loop has a reason to move. *This is where it becomes a game —
   if it isn't fun here, stop.*
5. **Boarded entry points + repair.** Prove: the horde opens new paths over time.
6. **Runner + special.** Prove: the panic curve has shape.
7. **Mystery box, 3 perks, down/revive.** Prove: a run has arc.
8. **Polish only.** No new features past this line.

---

## 7. OPEN QUESTIONS FOR THE OWNER

**Q1 — Solo or co-op?** Zombies is a Discord-and-couch genre; solo-only cuts real appeal. But netcode
is the one item here that could eat a month and destroy the "easy output" premise entirely.
*Recommendation: build solo-first with an architecture not actively hostile to co-op, ship solo, add
co-op only if the mode lands.* **UNRULED.**

**Q2 — Standalone product or RECON game mode?** Recommendation is game mode first, in this repo. Spin
it out only if it proves fun. **UNRULED.**

**Q3 — Fiction.** Recommendation, and the reason it's worth doing at all: **the firebase's own dead
get up.** The casualty ledger is already the scoreboard; the men who died in the siege come back
through the wire in their own kit. The VC dead come too. Both sides, neither one friendly. Reuses the
shipped grunt and VC models with no new asset, and it is an original hook rather than a Treyarch
tribute with a palm tree. **UNRULED.**

---

## 8. NAMED COSTS

No decision is free.

- **Attention.** RECON is one month in and moving. A side project at month one is the most common way
  a good project dies. The only safe version is one that *consumes* RECON output instead of competing
  for it — see §1.
- **Cannibalization.** If this ships first with the same firebase and the same grunts, RECON's world
  stops being a reveal. That may be an acceptable trade (it could work as a trailer for the real
  thing), but it must be chosen deliberately, not stumbled into.
- **Polish is unavoidable.** For a game like this, polish *is* the product — gun feel, horde audio,
  the round transition, how a body comes apart. Expect 60–70% of the calendar regardless of scope.
  The only lever available is surface area, which is why §2 is locked.

## 9. KILL CRITERIA

Cancel the mode, without regret, if any of these become true:

- Anything is being modelled in Blender specifically for it (§1).
- Step 4 of the build order isn't fun.
- RECON work stalls for more than a week because of it.
- Scope grows past §2 — a second map or a Pack-a-Punch is the tell.

---

## 10. WHY THIS GENRE

Market read, 2026-08-05: itch.io's top sellers are dominated by PSX/VHS-era low-poly horror
(*Dead Trust*, *Night of the Nun*, *Night of the Consumers*, *Buckshot Roulette*), with visual novels
second. Low-poly and dark is the aesthetic, not a compromise; 30–90 minutes is a full product;
$3–7 is the impulse price. Caveat: paid games get poor organic visibility on itch, so the realistic
shape is a free short version driving a paid full version, and/or itch as the demo channel for Steam.

A jungle undead mode built on RECON's parts sits exactly in that lane, and the Vietnam-era grime is
the thing that separates it from the flood of generic Unity-store PSX horror.

*(Dinosaurs-in-the-jungle was considered as the alternative and rejected: new models, new rigs, new
locomotion and attack sets, non-humanoid hitboxes. Roughly 10× the art cost of undead, which reskin
existing humans. Park it as a possible third thing, never as the second.)*
