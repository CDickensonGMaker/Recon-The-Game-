# SYNTHESIS — Garrison men are soldiers (War Room, 2026-08-04)

**The Summoner's ruling (verbatim, DECIDED):** "Garrison men are soldiers they shoudnt be
civilians. They can fight and react to enemies so thats not correct." Extension same day:
"and we need to make sure VC units arent lableed as civilans too in their camps."

Council: ai-architect · systems-designer · devil's-advocate, independent, code-first.
Analyses in `analysis/`. Verdicts converged from three doors — the strongest signal this
process produces.

## §1 What the council agreed on (unanimous, independently verified)

1. **VC audit: CLEAN — three independent passes.** Every `Civilian.spawn` caller is US
   garrison, true villager, or the dawn demote (`garrison_defender.gd:122`,
   `heli_lift.gd:191`). VC camp life runs ON the soldier class already
   (`camp_director.gd:29` Array[EnemyBase]; role clips `enemy_base.gd:584-644`). The
   informer swaps model only after GONE+invisible (`civilian.gd:307-314,582-593`) and the
   armed response spawns as EnemyBase. **No VC-side change ships — a fix there would be
   drift** (devil's advocate, seconded by the Arbiter).
2. **The reaction gap is REAL and is the substance of his ruling.** Stand-to has exactly
   three doors: siege (`field_director.gd:1441-1442`), a ≥2-enemies-within-90m poll
   (`field_director.gd:971-972,1348-1361`), and a heli landing into a stood-to base
   (`heli_lift.gd:249-250`). Outside those, `civilian.gd:250-251` discards ALL noise for
   garrison men, and a garrison man who is SHOT flees unarmed (`civilian.gd:523-534`). A
   lone sapper, or fire from beyond 90m, leaves the base sweeping floors.
3. **The fight machinery itself is already soldier-correct.** `GarrisonDefender.promote/
   stand_down` (garrison_defender.gd) is a clean 1:1 hand-off to AllyBase's shipped combat
   brain — one promote path, ADR-023 compliant. The ruling's HOW is a trigger-surface and
   verb problem, not a missing combat system.
4. **Option (b) — a shared person base — is REJECTED 3-0.** It is the 15th man-system in
   disguise, days before the demo.
5. **W-9 count 2 needs a move verb, not a class.** `seat_system.gd:332-334` casts
   `as AllyBase`, gets null for Civilians, and glue-teleports men aboard.

## §2 Where they split, and the Arbiter's rulings

**End state.** systems-designer: staged (a) — garrison ends on the soldier class per the
proven VC pattern, killing the promote/demote bridge. ai-architect + devil's-advocate:
(c)/latch now; (a) re-buys a MEASURED cost — Civilian's static hitzone bands exist because
bone-synced hulls ran ~6.4ms/frame at 16-40 heads (`civilian.gd:214-218`), AllyBase syncs
zones pinned HOT with no LOD tier (`ally_base.gd:40-44,548-565`), and AllyBase has no
schedule/marker/chow brain at all.

> **RULED:** The demo ships the bridge slice (§3). The structural end state — garrison on
> the soldier class, VC-pattern, GarrisonDefender bridge deleted in the same change — is
> ADOPTED IN PRINCIPLE but **POST-DEMO and GATED on preconditions**: static hitzone bands
> and the 3-tier LOD ported to the garrison soldier, and the schedule brain carried whole.
> Logged in DEMO_SHIP_BACKLOG; it is not demo-safe inside a day and the council's perf
> evidence says an ungated migration is a regression.

**W-9 mechanism.** systems-designer proposed promote-on-boarding; devil's-advocate
convicted it — `_on_took_off` strips only Civilian casts (`heli_lift.gd:303-306`), so a
promoted AllyBase who flies away stays in `garrison_promoted` forever, `garrison_strength`
(`heli_lift.gd:113-118`) inflates, every sortie reads EXTRACT, and W-9's parent bug is
reborn.

> **RULED:** boarding is a **latch on Civilian** (`board_target`), the puppet-latch
> pattern (`civilian.gd:110-113`), consumed by SeatSystem — NOT a general order grammar,
> NOT a promotion. Seating is arrival-gated so the walk is real and `board_heli` plays at
> the door, where it was authored to read.

**The trigger's exit** (devil's-advocate landmine, accepted whole): a noise-triggered
stand-to had no stand-down — `_garrison_stand_down` fires only from `_on_siege_ended`
(`field_director.gd:1486`) — and `_on_noise` ignores `_team` (`civilian.gd:247`), so the
player test-firing inside the wire would stand his own base to.

> **RULED:** the widened trigger ships WITH a team filter (enemy noise only, audibility =
> the emitted radius) and WITH a non-siege all-clear (sustained empty wire on the existing
> 0.5s poll → stand down; a live siege keeps owning its own dawn stand-down via
> `siege.active`).

**The 2026-07-30 pax ruling** (`heli_lift.gd:178-181`, pax are Civilians not AllyBase).

> **RULED, explicitly, not silently:** that ruling is REFINED, not revoked. Its substance
> — camp-life brain, one promote path, no parallel spawn — stands and still binds today's
> slice. Its letter — the class NAME — is what the 2026-08-04 ruling supersedes, and the
> letter is settled by the post-demo migration, not today.

## §3 THE DECREE

**DEMO SLICE (ships today):**
- **A. Soldiers answer fire.** Garrison `_on_noise` deaf gate replaced: enemy-team
  GUNSHOT/EXPLOSION audible at the man (distance ≤ emitted radius) → the EXISTING
  `_garrison_stand_to()` via a public `FieldDirector.garrison_alarm()`. A garrison man
  hit by an enemy raises the same alarm (deferred — promotion is synchronous teardown).
- **B. All-clear.** `_poll_firebase_threat` stands the garrison down after ~90s of
  sustained empty wire (near == 0) when no siege is active. Sieges keep their dawn path.
- **C. Men walk to the bird (W-9 count 2).** `Civilian.board_target` latch;
  `board_squad` sets it for Civilians (AllyBase keeps MOVE_TO); `_board_one` retries
  until arrival, plays `board_heli` at the door, seats after the mount beat. A man who
  never arrives is abandoned by the ship — the latch clears, he stays garrison.
- **D. A dead garrison man is a SOLDIER on the ledger** — `_record_noncombatant_death`
  excludes `is_garrison`. He stays in the `civilians` group (blast/`spare_garrison`
  semantics at `combat_manager.gd:161-167` unchanged — that is Pillar-5 decree, separate).
- **E. Drift corrected on contact:** civilian.gd garrison header, field_director.gd
  stand-to comments ("passive noncombatants", "never for a lone wanderer") rewritten.

**POST-DEMO (logged, gated):** migrate garrison to the soldier class per the VC pattern;
delete GarrisonDefender, the deaf gate, and the double-group bookkeeping in the SAME
change (fossil law). Preconditions: static hitzone bands + LOD tiers + schedule brain
ported. Blast-radius map in `analysis/systems_designer.md`.

## §4 SACRIFICES NAMED (the law binds the Arbiter too)

1. **The demo ships soldiers in a class still named `Civilian`.** The ruling is met in
   BEHAVIOR, not in the type system, until the migration lands. This is the sacrifice
   nobody wanted to name; it is named here.
2. **Stand-to stays all-or-nothing** — one audible enemy shot stands up the whole base,
   40 promoted AllyBase heads for the duration. The all-clear bounds the cost; a
   graduated response (one post investigates) is deliberately NOT built — it would be a
   new behavior days before the demo.
3. **A lone SILENT infiltrator still goes unnoticed** — no shot, no explosion, no
   garrison eyes. Detection-by-sight for garrison men is future work, not a demo patch.
4. **`board_heli`'s mount beat runs on a timed constant, not a measured clip length** —
   good enough at demo distance; measured splice is art-log follow-up.

## §5 Verification plan (ADR-015)

Headless boot (`--quit-after 300` + SCRIPT ERROR grep) — the definitive check per the
charter — then a live run via godot MCP with file-redirected output, grepping for
`[FSB] stand to:` / `[LIFT]` lines and script errors. CLOSE of the reaction gap and W-9
count 2 belongs to HIS eyes (verified playtest, ADR-015) — this session can only prove
the wiring fires.
