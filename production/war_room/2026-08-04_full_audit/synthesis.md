# THE DECREE — 2026-08-04 — FULL AUDIT: DEMO + FULL GAME

**Convened:** the Overseer/Director as Arbiter, at the Summoner's direction.
**Council:** game-designer · systems-designer · ai-architect · art-director · technical-director ·
devil's-advocate. Six independent analyses, no cross-talk, code only. Debate: `discussion.md`.
**His ask:** *"see where were weakest, strongest and where we can improve still."*

---

## 0. THE ONE-PARAGRAPH VERDICT

The game under the demo is **stronger than the demo itself**: the stealth economy, the siege
escalation, the death paths, the revive economy, the open-patrol cycle and the campaign's memory all
survived six hostile lenses. But the 8/4 wiring — one day old, parse-checked, never run — is
convicted on its spine: **the 06:30 dawn start never happens.** The boot fires the operation build
without awaiting it, sets the clock mid-build, and the plan's fossil `"time": "DUSK"` overwrites it
when the build lands (`demo_game.gd:100-103` → `game_flow.gd:591-592`, `:677-679` →
`mission_generator.gd:673` → `mission_weather.gd:51`). The demo as wired starts at **17:30**, rolls
midnight mid-run, and fights its "night assault" in daylight. Around that spine: the radio handoff
can silently consume the medic and with him the whole R3 revive economy (`squad_system.gd:588-601`,
three architects independently), the ruled ending renders as a ~2-3 second freeze-frame of arrival
rather than circling gunships, and **at least five ruled items the 8/4 record claims wired do not
exist in code**. The measurement plan meant to catch all of this is itself broken — `--print-fps`
does not exist (`site_planner.gd:859` is a comment). None of this is deep damage: every defect named
above is boot-order, a guard clause, or constants — **days, not weeks** — and the audit's real
sentence is unchanged from 7/31: this project ships code daily and truth never. One repaired
measurement pass plus one exported playtest discharges 12 of 17 unverified systems.

---

## 1. DEMO — THE RANKED LISTS

### STRONGEST (verified where possible; survived all six lenses)
1. **Every death path lands on a verified terminal screen with named men** — headshot, bleed-out,
   squad-wipe, end-card (`demo_game.gd:431-469` via `health_system.gd:267` → `field_director.gd:201`).
2. **The revive economy per R3** — window, pressure, channel, bandage count, box restock; complete
   and legible (`squad_system.gd:222-348`). *Conditional on fixing the radio-heir defect (W-1).*
3. **Save sandboxing both directions** — the demo can neither read his tour nor leak into it
   (`demo_game.gd:81-95`, `:112-117`). Devil's Advocate called it airtight.
4. **The witness→evidence→hunt-net stealth economy** — a closed loop that teaches itself
   (`enemy_base.gd:970-1051`, `field_director.gd:146-174`).
5. **Siege escalation logic** — probe→assault reinforcement, broken-probe re-open, peak scaling
   (`siege_director.gd:192-249`). Every failure mode the Devil hunted was already closed.
6. **Bounding discipline** — 15 accumulator families capped/reaped; fossil ratchet intact at 3
   (`tests/fossil_baseline.json:3-10`).

### WEAKEST (what embarrasses us in front of a stranger, ranked)
1. **THE CLOCK RACE** — the demo starts at DUSK 17:30, not DAWN 06:30; all four lighting events
   land wrong; midnight rollover re-arms a second siege and the allotment mid-run; the assault
   plays in daylight (pointers in §0; adjudicated in `discussion.md §1`).
2. **The radio can eat the medic** — `_hand_off_radio` overwrites the nearest man's MOS
   (`squad_system.gd:601`); a medic-heir silently deletes revive forever, persisted to the save.
3. **Five ruled items recorded as wired, absent in code** — hunter top-up (§2.9), the §2.8 night
   arithmetic (zero hooks), informer 100% (`mission_generator.gd:1010` still coin-flip), §2.11 ally
   items 1-4 (courage still `randf()` `ally_base.gd:295`; concealment zero hits), "hunters" tagging.
   Without the top-up the AO goes empty at ~the 8-minute mark and stays empty; the squad still owns
   **1 spendable verb of 5**.
4. **The ruled ending is ~2-3s** — inbound flight eats the 12s hold; the ceiling can cut the
   gunships to zero ships (`air_traffic.gd:272-275`; `demo_game.gd:410,445`).
5. **The night seam is mis-set even after the race is fixed** — NIGHT falls at sim 19.0 ≈ 1184s,
   not 1380s (`sim_clock.gd:57-64`); and 1-in-20 boots roll a rogue random siege
   (`siege_director.gd:168-188`).
6. **The verification instrument doesn't exist** — M-2/M-3 specify `--print-fps`, which is a
   comment; `--perf-probe` null-crashes the export (`game_flow.gd:713`).
7. **The stale GLB** — `fsb_main_v3.glb` (Jul 26) has no chow hall, no medical complex, one pad;
   the aid station, litter team and chow schedule are fully coded and have never executed. Gated by
   M-1 and his bench.
8. **Air-transit burst** — hour-crossing truncation fires up to ~14 airframes in one frame every
   ~95s at 38x (`sim_clock.gd:86,91` + `air_traffic.gd:105`), on a call-bound project.
9. **Minutes 2-5 are unauthored air** and the baked weapon drops may render underground
   (`world_weapon.gd:143,186-192`) — a stranger's first pickup may be invisible.

### IMPROVE (value-per-effort, ranked — sacrifices in §4)
1. **W-1: Fix the clock race** (await the build or set time on world-ready; kill the fossil
   `"DUSK"`) — restores the whole 8/3 decree's spine. ~1-2h.
2. **W-2: Guard the radio heir** (exclude MEDIC, prefer RIFLEMAN; ~4 lines) — protects R3. ~0.5h.
3. **W-3: Ship the missing ruled wiring** — hunter top-up at the gate seam (1 line), informer 100%
   (1 line), "hunters" tag, §2.11 items 1-3 (~20 decreed lines) — the highest behavior-per-line in
   the project (ai-architect). ~0.5-1d.
4. **W-4: A shipped FPS/draw-call printer** (~20 lines) + repair the M-specs — unblocks the entire
   verification plan. <1h. **Then run M-6 (clock print at seat), M-1, M-2..M-5.**
5. **W-5: Guarantee the ending** — hold→30s, nearer orbit spawn, ceiling exception for the finale
   pair; keep `ENDING_PLAYER_SURVIVES` cheap to flip per R1. ~1h.
6. **W-6: Demo-gate the rogue siege roll + move the seam to the real NIGHT hour.** ~0.5h.
7. **W-7: 60-second eyes-on drop-bench check** (are baked drops visible?) before his playtest.
8. **W-8: De-burst the air schedule** (spread transits off the hour crossing). ~1-2h.
9. **His bench (unchanged, one session): M-1 FIRST, then the re-export** — dual pads, wire split,
   medical, bunker slits, chow markers (`gen_firebase_v3.py:912` correct, `:1104` stale) — lights
   three fully-coded systems at once.

---

## 2. FULL GAME — THE RANKED LISTS

### STRONGEST
1. **The open-patrol loop genuinely cycles** — gate→bank→fresh state→re-armed gate, all-or-nothing
   commits (`field_director.gd:1214-1237, 1586-1610`).
2. **Campaign memory breadth is real** — tunnels, ink layers, rack fouling, butcher's bill
   (`campaign_state.gd:298-377`).
3. **Progression actually gates** — hidden rep→rank with a working armory tier gate
   (`armorers_bench.gd:50` + 7 tiered .tres); 7/31's "rank gates nothing" is retired as stale.
4. **The AI consolidation spine is paid for** — one goal scorer, one break authority, one cover
   broker, one spawn authority; hot-set think budgeting keeps the witness check even when cold
   (`enemy_base.gd:811-864`).
5. **The art pipeline is an asset, not a liability** — 182-clip shared library under one contract
   (`model_actor.gd:280-310`), 31/31 characters resolve, 9 guns through the strict viewmodel v2 gate.

### WEAKEST
1. **The siege has no stakes** — the handler under the comment "the night banks its own AAR" banks
   NOTHING (`field_director.gd:1466-1478`); a siege fought at home writes no butcher's bill;
   ADR-036 blocked. The demo's climax is the full game's hollowest system.
2. **Hearts & minds is zero code behind an Accepted ADR** — allegiance lives in two comments;
   civilian murder is free (`civilian.gd:4-7`).
3. **The night economy has no player-facing consumer** — no sleep verb (`game_flow.gd:51-94` dev
   key only); 68 bunks are spawn markers.
4. **ADR-029 — the game's entire shape — is still DRAFT** with two ratified amendments hanging off it.
5. **`_thaw_held_cells` first executes in the full game** — the demo can never run it (45 <
   LIVE_CAP 50); it double-spends headroom and `materialize()` has no cap check
   (`siege_director.gd:448-479`, `marching_cell.gd:89-90`).
6. **Save hardening still open** — no atomic write, no future-version reject, `to_dict` drops 4
   fields with cross-campaign bleed (systems-designer's ADR-007 findings).
7. **MARKSMAN never spawns** (`squad_roster.gd:64`) — a whole MOS with a body and a weapon, absent
   from the draw.

### IMPROVE (value-per-effort, ranked)
1. **F-1: Bank the night** — wire a siege AAR into `_on_siege_ended`; the machinery sits ~120 lines
   away. Hours, and it gives the demo's climax full-game meaning.
2. **F-2: ADR-007's two amendments + fix the false `to_dict` mirror** — tiny effort, protects every
   campaign.
3. **F-3: Ratify ADR-029** (or amend it) — a paperwork hour that de-risks every future council.
4. **F-4: Sleep verb with siege-wake interrupt** — one verb unlocks the entire built night economy.
5. **F-5: M-AI-1** (forced 50+20 strength in the test room) before any siege-strength tuning — the
   thaw path must not first-run in front of a player.
6. **F-6: Place the 21 interior props** — pure code, on disk since 7/31, unclaimed through two audits. ~0.5d.
7. **F-7: MARKSMAN into `MOS_ORDER`** + the promised alternate draw, or delete the promise.
8. **F-8: Hearts & minds thin slice** — make the empty hook in `civilian.gd:4-7` count ONE thing
   (civilian deaths → informer odds) before building the economy.

---

## 3. THE MEASUREMENT ORDER (repaired; run in this sequence)

| # | Measurement | Gates | Status |
|---|---|---|---|
| **M-6** (NEW) | Print sim clock at player seat, 60s after boot. FAIL ≠ 06:30 | The whole arc; verifies W-1 | cheapest, FIRST |
| **M-1** | Occupation histogram from `fsb_garrison_plan` | every chow/medical decision | unchanged, minutes |
| **W-4** | Build the FPS/call printer | M-2, M-3, M-9 | prerequisite |
| **M-2** | Siege strength A/B/A (as specified 8/3, via the new printer) | §2.8 link | after W-4 |
| **M-3** | 30-min exported run, draw calls watched | 12 of 17 unverified systems | after W-4 |
| **M-4** | Squad arrivals at gate, 10 runs | the opening | unchanged |
| **M-5** | Huey launch-to-clear timing | the 0:30 beat | unchanged |
| **M-7** (NEW) | Kill the RTO, then take a hit: does revive fire? | W-2 | one run |
| **M-8** (NEW) | Seconds of visible orbit before the end freeze | R1's image; W-5 | one run |
| **M-9** (NEW) | Siege-break wall-clock vs the 1800s card | dead-air risk | inside M-3 |
| **M-AI-1** (NEW) | Forced 50+20 in the test room: thaw order, cap holds | full-game siege | before tuning |

## 4. WHAT IS SACRIFICED (Law 2, collected)

- **W-1** costs the boot a synchronous wait — the title beat sits on a black/build screen ~2-4s
  longer, or the time-set moves inside game_flow (a demo hook in shared code).
- **W-2** kills the "anyone can pick it up" purity of R4 — the heir is now policy, not proximity.
- **W-3's** hunter top-up formally breaks ADR-035's finite pool inside the demo (already excepted
  8/3, restated). §2.11 item 1 means the squad visibly abandons the player at the climax — correct,
  and it will read as a bug to a stranger. Concealment (item 3) without a nameplate check costs
  squad legibility: his own men vanish into grass.
- **W-5's** ceiling exception knowingly overspends the air budget for 30 seconds on a call-bound
  project — priced, once, at the finale.
- **W-6** deletes a real emergent hazard (the rogue siege) from the demo — the full game keeps it.
- **W-8** trades period-authentic clustered flights for legibility and frame safety.
- **F-1** makes losing men at home COST — playtesters will feel the campaign get harder; that is
  the point, but it is a difficulty increase shipped as a bug-fix-shaped change.
- **F-4** spends the player's only guaranteed-safe time; a sleep verb that can be interrupted is a
  trap the player will resent — it must telegraph.
- **F-8's** thin slice risks reading as the whole feature and parking ADR-019 forever.
- **Deferred entirely, on the record:** wounded squadmates (R9 stands), the 70m ally cover ring,
  VC armory stubs, m72_law/rpg7/car15 render nothing in hand, mg/bolt/launcher/pistol clip families
  (every RPD/Mosin carrier rifle-holds through the night attack).

## 5. LAW 1 CHECK

No item above violates a pillar. W-1..W-6 restore HIS rulings (R1, R3, R4-adjacent, §2.8-§2.11) —
they are compliance, not design. F-1/F-4 serve Pillars 4/5. The finite-pool exception remains
demo-scoped per the 8/3 decree. The r4bk law is honored: every consequence named here has a visible
carrier or is flagged as needing one.

## 6. THE DECISION QUEUE — only Caleb can rule these (glossed, chat-answerable)

**Q1. When your radioman dies, who is allowed to inherit the radio?** You ruled anyone nearby picks
it up. As built, that can be the medic — and the moment he becomes the radioman, nobody can revive
you, silently, for the rest of the run. **Choice:** (a) anyone EXCEPT the medic; (b) riflemen first,
specialists only as a last resort; (c) keep pure nearest-man and accept the medic risk.

**Q2. How long should the final image hold?** As wired, the circling gunships are on screen about
two to three seconds before the freeze — the fly-in eats the hold. **Choice:** give me a number of
seconds (council recommends ~30), or say "until I press a key."

**Q3. The demo's day can end with the enemy attack force reduced by your day's work — but the
wiring for that arithmetic was never actually built.** Building it is cheap, but its consequence is
invisible at night unless the wire visibly holds or breaks. **Choice:** (a) build it with the
visible carriers (radio line, breach-or-no-breach, end card); (b) drop the day-feeds-night idea
from the demo and keep the fixed 45-man attack.

**Q4. Held over from 8/3, still open: the evening meal.** Fill the hall in three sittings so the
base never empties (my recommendation), or raise the garrison headcount and pay the frame cost so
it fills at once?

**Q5. The rulebook that defines the whole open-patrol game is still marked DRAFT.** You have ruled
by it for weeks. Say the word and I mark it ratified as-is; or tell me what you want changed first.

**Q6. Full-game priority after the demo fixes:** (a) make the night attack COUNT in the campaign
(your dead write into the books); (b) the sleep verb that unlocks the night economy; (c) the
hearts-and-minds thin slice (killing civilians finally costs). Pick the order.

## 7. THE RECORD (Phase 6)

Actionable items recorded in `production/DEMO_SHIP_BACKLOG.md` §2026-08-04 AUDIT. The 8/4 wiring
record's overclaims are corrected there (five ruled items marked NOT WIRED). ART_Track_Log
convictions noted for correction on next touch. Memory updated by the Overseer.
