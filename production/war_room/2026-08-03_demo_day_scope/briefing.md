# WAR ROOM BRIEFING — 2026-08-03 — THE DEMO DAY RESCOPE

**Convened by:** the Overseer/Director (Arbiter) at the Summoner's direction.
**Subject:** rescope the shipped ~7-minute night-siege demo into a ONE FULL DAY arc on the firebase
ending with the night attack. 30 real minutes. No save.

---

## 0. WHAT IS ALREADY DECIDED (Summoner's rulings this session — DO NOT RE-ASK, DO NOT RE-LITIGATE)

1. **30 real minutes total.** His first shipped game averaged 30 min; players beat it and came back.
   A marketed demo launches BEFORE the full game, for hype and feedback.
2. **THE 5-MINUTE RULE IS LAW.** *"if a player isnt hooked by the first 5 minutes than the game isnt
   for them."* No slow tutorial. Quick and to the point.
3. **Opening beat, his words:** spawn 0700, head out on patrol with your unit, an indicator that you
   should head out the gate and into the field. *"we should have the heuys taking off when the player
   turns the corner and sees them."*
4. **Two areas: one village, one enemy camp.** No tunnel interiors — but a destructible tunnel MOUTH
   (the IDEA of destroying them) is in scope.
5. **3 RTO fire missions.** *"first one you gotta assume most players will just do it to do it (which
   they can) and then they will use the other two wisely."*
6. **NO SAVE.**
7. **Fail forward via the medic** — going down outside the wire = the squad works on you, you come
   back degraded, you lose time and blood while the hunt net closes. Real death only when fail-forward
   runs out. Death during the night attack ENDS the demo. (Pillar 5; a no-save demo that rewinds 25
   minutes is a punishment, not a retry.)
8. **RULED: going down does NOT cost an RTO mission** — *"that wouldnt make sense logically."* The
   radio does not care that you are on your back. **DO NOT PROPOSE IT AGAIN.** (Open extension he has
   NOT ruled on: if the RTO MAN goes down, do the calls stop?)
9. **A hunter patrol must be able to hit the player at any time outside the wire**, explicitly tied to
   *"the being seen aspect."*
10. **Ally AI must be intelligent and self-preserving to *Vietcong*'s bar, NOT Medal of Honor /
    Wolfenstein.** *"those are single man army games where i need the squad alive as a crucial pillar
    just like the jungle has to look right."* He is elevating squad survivability to pillar level.

---

## 1. THE ARBITER'S PROPOSED SHAPE (attack it — this is a target, not a decree)

~23 min of day + ~7 min of attack.

**Clock.** `DEMO_CLOCK_RATIO` is **110x** (`scripts/levels/demo_game.gd:42`) and the demo currently
starts at **17:30**, running to ~06:20 in 7 minutes. The rescope inverts this: 0700 → 1900 across 23
real minutes is roughly **31x**, possibly ramping toward ~60x for the night so DAWN stays true and not
a caption (the 110x comment at `:36-41` states exactly why the ratio exists — read it before proposing
a new number).

**Beat sheet.** 0:00 spawn 0700, unit forming up · 0:30 turn the corner, pads with birds lifting off ·
1:00 one diegetic pointer to the gate · 1:30–4:00 out the wire, something to look at by 200m · 5:00
village in sight. Then village → return through the wire at midday (the chow hall is what the return
is FOR) → afternoon sortie to the camp → back before dark → stand-to → attack.

**The village is THE ENEMY'S EYES**, not "a place with enemies": being seen, a cache / tunnel mouth,
civilian ambiguity. What you do in daylight sets `SIEGE_STRENGTH` that night
(`scripts/levels/demo_game.gd:48`, currently 45 — already a single variable). Sketch: clean day 35 /
default 45 / seen-and-camp-intact 55. **THE CATCH: an invisible consequence is no consequence.** This
needs one RTO line at the gate and one on the end card, or do not build the link at all (r4bk Law).

**Multi-pad Hueys.** Several landing pads with staggered concurrent routes (his ask). Needs pad markers
in the Blender firebase + a per-pad scheduler + per-route jitter so the animations do not sync.

---

## 2. WHAT THE COUNCIL MUST ANSWER

**A. The clock ratio.** What number, and is a VARIABLE ratio (day vs night) right, or a cheat the
player will feel? Cite the clock consumer code, not just the constant.

**B. The gate pointer's form.** He has DEFERRED the period HUD (ADR-030, `recongame-period-hud-decree`).
What is the diegetic pointer that neither violates that deferral nor reads as a tutorial?

**C. Multi-pad cost against the measured 48 FPS mid-siege** (W7 A/B on the exported demo, `--print-fps`,
150s, at garrison 24 AND 40; see `production/PERF_LEDGER.md`). This project is **call-bound**. Every
airframe is draw calls. Price it or kill it.

**D. `scripts/missions/field_director.gd:133` — `field_mult` decays the hunt −2%/min past 15 minutes,
floor 0.6.** In a 30-minute demo the SECOND HALF IS SOFTER than the first, which is backwards for an
arc building to a night assault. Invert, flatten, or leave? Name the sacrifice either way.

**E. Does the day's hunting feed the night?** `_hunter_pool` is 12 (`field_director.gd:106`). If the
player bleeds it in daylight, should `SIEGE_STRENGTH` come down? The Arbiter leans YES — one arithmetic
instead of two scenes. Argue it.

**F. THE LIVE_CAP COLLISION — MEASURE, DO NOT GUESS.** `LIVE_CAP` is 50 materialized men
(`scripts/missions/siege_director.gd:36`, enforced at `:427` and `:440-446`). **Nobody has ever run
live hunters + a 40-man garrison + a 45-man assault simultaneously.** The 2026-07-28 trickle failure
was an assault authored AT the cap freezing its late cells at the ring (`demo_game.gd:44-47` records
this). This configuration has never existed. **If you cannot measure it this session, SPECIFY THE
MEASUREMENT** — exact command, exact scene, exact counters to read. Do not guess a number.

**G. The proactive-vs-reactive hunter gap.** The hunt net (`field_director.gd:102-162`) is REACTIVE:
`_check_detection` (`:112-119`) arms only on the first COMBAT contact, so it **cannot** fire during the
4-minute walk out to the village — exactly the stretch the 5-minute rule cannot afford to leave empty.
He asked for a squad already out there. Proposal to rule on: ONE ambient cell spawned at boot, walking
a road between village and camp; if it sees you, the existing hunt net takes over. Right? What does it
cost?

**H. Ally AI to the *Vietcong* bar.** The Arbiter has ALREADY VERIFIED that allies have real
self-preservation — do not re-derive this: cover-first doctrine personality-gated by courage (<0.35
coward anchors deep + suppressive, >0.70 go-getter skips the cover trip) at
`scripts/ai/ally_base.gd:78-117`; prone latch byte-for-byte identical to the enemy's through the same
`CombatPosture` authority (`:233-235`, `:395-409`); suppression; cover-fail counting; squad break on
the same authority `EnemySquad` breaks on (`:97`).

**What grep could NOT settle and the council MUST:**
1. Does an ally under fire seek the MEDIC, or only cover?
2. Does a man carrying a CAPABILITY (RTO, medic) weight self-preservation higher than a rifleman —
   i.e. does the RTO hang back?
3. Do allies use CONCEALMENT, or only cover?

*Vietcong*'s AI was frightening because it was **in the grass**, and he has already ruled the jungle
has to look right — concealment is that ruling pointed at the AI.

**THE VIETCONG INSIGHT:** each squad member was a **CAPABILITY, not a gun.** Losing one cost you a
**VERB**, not rifle fire. That is why keeping them alive was a fantasy and not an escort mission.
Pillar 4 already says the squad is the RPG.

**I. The chow hall wiring**, per `production/HANDOFF_chowhall_godot_wiring_2026-08-03.md`.
**Its §4 blocker is DEAD** — the Arbiter measured it this session: the Blender window re-saved
`firebase_v3.1.blend` at 22:45, 15 min after the RECOVERED file's 22:30 save, and decompressing both
blends gives an IDENTICAL payload (`WB_chowhall` ×3, `work_eat` ×24, `food_stop` ×1, `work_serve` ×9,
`WB_medical` ×1). **`tools/gen_firebase_v3.py:912`'s default is CORRECT — DO NOT REPOINT IT.**
(`:1104` → `firebase_v3.blend` IS still stale.) Three open rulings for Caleb: lock the provisional
marker names (once `site_planner.gd` reads them they are an API); cook/server/collector as rostered
soldiers vs always-manned fixtures; how many men eat at once (`build(n=5)` never run; spacing proven at
n=1 only).

---

## 3. HARD CONSTRAINTS ON THIS COUNCIL

- **THE POINTER LAW BINDS THIS COUNCIL.** Every architect reads CODE and cites `file:line`. An
  assertion with no pointer is an opinion. Three times in one day the codebase has beaten the document
  in this project.
- **VERIFY BEFORE PROPOSING TO BUILD.** `production/DEMO_SHIP_BACKLOG.md` has claimed SEVEN items were
  open while they were already shipped.
- **Law 1:** no decree may violate a Pillar. **Law 2:** name what is sacrificed — every time.
- **NO CODE THIS SESSION.** Design + measurement only. Where a question needs a measurement nobody has
  taken (F especially), say so and specify the measurement rather than guessing.
- The synthesis ends with a **DECISION QUEUE** glossed in plain words Caleb can rule on without opening
  a file — no acronyms, no wave codes (his standing rule).

---

## 4. THE PILLARS (Law 1 test, `production/bible/BIBLE.md:85-101`)

1. **Believable firefights** — AI that fights like soldiers AND weapons that kill like weapons.
2. **Atmosphere** — the war happens with or without you.
3. **Freedom** — no rails; stealth is an economy, never a gate.
4. **The squad is the RPG — and you are IN it, not above it.**
5. **Fail forward** — escalation not fail-states; death matters, but this is not a sadism simulator.

Plus the **r4bk Law**: a feature without a visible affordance does not exist.
