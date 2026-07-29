# ADR-036 — The Fall of the Firebase: objectives, the respawn stake, and the lethality pass

**Status:** DRAFT — **BLOCKED.** Ruled by the Summoner 2026-07-28; **not buildable today.** Nine of its
dependencies do not exist. Ratification is deliberately withheld until §1's blockers are cleared.
**Date:** 2026-07-28 · **Pillars:** 2 (atmosphere), 5 (fail forward — contested, see §5).
**Related:** ADR-035 (the siege — the fight this ADR gives stakes to), ADR-031 (destruction doctrine —
never yet run in the live world), ADR-016 (flat damage grammar — amended by §4), ADR-007 (save
architecture), ADR-018 (progression — replacements are green), ADR-006 (scoring).
**War room:** `production/war_room/2026-07-28_firebase_siege/`.

---

## Context — why this is a separate ADR

rev.1 of ADR-035 ruled the siege and the loss of the firebase together. The War Room found the second half
anchored to things that do not exist, and both reviewers that examined it returned SEND BACK. Splitting
lets the siege ship while this waits for its foundations.

**The Summoner's rulings recorded here are LAW and are not re-opened by the split.** What is deferred is
the BUILD, not the decision.

## The Summoner's rulings (verbatim intent, 2026-07-28)

1. **Objective installations.** The VC/NVA must capture or destroy specific points inside the firebase; the
   defenders must hold them. This also fixes the attacker-with-no-target problem: a man with an objective is
   never in an undefined state.
2. **True failure exists.** Losing the position is a real loss, not a scoreboard entry.
3. **You cannot respawn if the firebase is overrun.** The base is the recovery anchor; losing it removes it.
4. **Combat damage can then be tuned UP** (HLL-grade lethality), because a death stops being a run-ender
   when there is somewhere to come back to.

## §1. THE BLOCKERS — measured 2026-07-28, every one verified at source

**1. The firebase is ONE node.** `site_planner.place_firebase_main` instantiates `fsb_main_v3.glb` and
returns `"nodes": [root]` (`site_planner.gd:904-925`). Every installation this ADR names is **baked
geometry inside a single GLB**. There is nothing to register, nothing to damage, nothing to lose.

**2. The named objectives do not exist as entities.**
- **TOC** — the fatal objective, the whole stake — exists only as a Blender family `fb_toc`
  (`tools/gen_firebase_v3.py:945`), surfacing at runtime under the alias `FOOTPRINT_003` and consumed as a
  *radioman spawn post* (`site_planner.gd:696`).
- **Commo bunker** — does not exist. The only such string repo-wide is a fossil collision row
  (`collision_table.gd:114, :232`).
- **MG emplacements** — exactly **one** is placed (`site_planner.gd:693`), and it has no `take_damage`.
- **Depot** — modelled today as `_firebase_breached`, a single bool (`field_director.gd:805`), against one
  `_sapper_aim` Vector3. (Note: `CampaignState.depot_loss` is already a Dictionary,
  `campaign_state.gd:47` — the boolean is the breach latch, not the loss record.)

**3. ADR-031 has never run in the live world.** `Destructible` is instantiated in four places, **all
benches** (`ai_stress_arena.gd:1248/1276/1302`, `fire_support_bench.gd:76`). The blast bus is real; the
receivers are not. **80 authored sandbag destructibles already sit unread in
`firebase_v3_destructibles.json`** — the cheapest possible first step.

**4. There is no respawn system to take away.** Death is downed → a squad-medic revive window
(`health_system.gd:233-246`) → otherwise `player_died` (`game_manager.gd:51`). Worse, **player death tears
the world down** (`field_director.gd:141-142` → `game_flow.gd:169-185`). **Today's consequence for dying is
already harsher than this ADR's headline stake** — §5's premise is not yet true.

**5. The lethality argument is therefore circular** until 4 is fixed: higher damage is affordable *because*
you come back, and you do not come back.

## §2. Objectives — the shape, when it can be built

Installations are **real damageable things**, never capture circles: no progress bars, no objective
counter — ADR-029 killed that UI and this ADR does not resurrect it. **Legibility is diegetic:** you learn
the depot is gone because your mortars are, and the north wire is open because the gun there stopped.
**The map is the objective display.**

Objectives register on the existing blast bus — `AgentRegistry.props` / `take_damage` per ADR-031. No new
damage authority.

**Loss classes:** most objectives are a COST; exactly one is FATAL.
- Depot → fire support docked (extend the shipped `depot_loss` path, `field_director.gd:1085-1093`, from
  one breach latch to per-objective losses).
- Commo → no fire missions, no net, no radio VO.
- MG bunkers → that sector of wire opens.
- **TOC → OVERRUN.** §3.

**COST NOT ADMITTED IN rev.1, named here** (devil's advocate, and the Arbiter rates it correctly serious):
splitting the welded firebase GLB into ~20 registered nodes is a **draw-call regression at the densest site
in the game** (678 meshes / 1,116 bodies). This project's measured ruling is that **draw calls and fill are
the levers, never triangle count** — so §2 taxes every hour of the game to pay for eight minutes of it. Any
build must measure the idle-in-base frame before and after.

## §3. Overrun, and the respawn stake

If the TOC falls, the base is **overrun** and the player's recovery anchor is gone.

**§5 below contests whether this is Pillar-5-legal as stated. The Summoner's ruling stands; the
IMPLEMENTATION must satisfy the pillar.** The binding requirement: **the successor state must be
specified.** ADR-035's banking (`field_director.gd:941-943`), the outbound fire-support grant (`:939`) and
the ADR-032 bench all have undefined behaviour after the TOC falls, and an unspecified successor is how a
"consequence" silently becomes a dead end.

## §4. The lethality pass — and the coupling

Any damage change is an **amendment to ADR-016** and turns `tests/test_flat_damage.tscn` red by design.

**rev.1 claimed higher damage makes sieges EASIER and prescribed retuning the break against it. The council
corrected both halves and the Arbiter accepts the correction:**
- Damage is **symmetric**, and the garrison is the *worse*-postured side: stationary on `OrderMode.HOLD`
  with `post_leash = 8.0` (`ally_base.gd:147`), pre-registered under a walking mortar, never replaced.
  Higher lethality makes the night **shorter**, not necessarily easier, and it costs more defenders.
- **Do NOT couple the break threshold to the damage constant.** `break_state` already modulates by
  `avg_courage` (`enemy_squad.gd:111`); coupling would make NVA morale a function of the M16's
  `base_damage` — nonsense in fiction and a permanent drift generator in code.
- **Difficulty is spent on the d50 count, not on the break threshold.**

**Death must keep a cost, or lethality is free.** The cost is already shipped: fire support is granted
crossing the wire outbound (`field_director.gd:939`) and the patrol banks only crossing back inward
(`:941-943`, `_bank_patrol:1213`). Dying in the field means **the walk never banks** — ground covered,
kills, rank progress, gone. (ADR-035 §9 additionally latches the grant so the 25 m wire band cannot be
farmed.)

## §5. The Pillar 5 question — recorded, unresolved

The game designer returned a **PILLAR VIOLATION** finding against rev.1 §9: Pillar 5 is *fail forward*, and
its binding clause is **"never reload-and-memorize."** An unrecoverable, opaque loss inside a 600-second
F5/F9-able night, with no described successor state, is held to be "a fail-state that declined to draw
itself" — and the no-screen defence is weak, since a death screen already ships (`hud.gd:357`).

**The Arbiter does not overrule the Summoner and does not soften his ruling.** The finding is recorded as
the design constraint this ADR must satisfy before ratification: **overrun must MUTATE the campaign, not
end it.** The most promising direction, consistent with the Summoner's stated liking for "surviving a
battered firebase," is displacement — the base is lost, the war continues from a worse position — but that
is not ruled, and it neighbours the parked patrol-vs-repair question.

## §6. Build order, when unblocked

1. Wire the 80 authored sandbag destructibles from `firebase_v3_destructibles.json` — proves ADR-031 in the
   live world at the lowest cost, and measures the draw-call tax of §2 before committing to it.
2. Promote 3–5 installations (depot, commo, MG posts) to registered damageable entities. Blender re-export
   plus wiring, not a GDScript task.
3. Build the respawn concept (§1.4), including surviving player death without tearing the world down.
4. Specify the successor state (§3, §5). Ratify.
5. Only then: the TOC as fatal objective, and the ADR-016 lethality amendment.

## §7. Consequences (the sacrifice)

- This ADR is a **programme, not a change.** Its own council called rev.1 "five systems in a trenchcoat";
  the split is the answer, and this half is the one that waits.
- Until it lands, **a lost siege costs men and materiel but never the war** — sieges have stakes but not
  the Summoner's stake.
- §2 is a permanent frame tax on the most-visited site in the game, paid to make eight minutes matter.
