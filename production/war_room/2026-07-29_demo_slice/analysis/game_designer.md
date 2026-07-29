# Game Designer — DEMO GAME: the 20-minute arc as first impression

Lens: a stranger plays this once, cold. Every minute must either sell a pillar or set up the minute
that does. Pointers cited against code as of 2026-07-29.

---

## (a) The phase timeline

Hard framing constraint first: **NIGHT is 600 real seconds** (`sim_clock.gd:17`, cited by
`siege_director.gd:38-40`) and the siege self-limits to **480 s** (`MAX_DURATION_S`,
`siege_director.gd:40`) before breaking on `"dawn"` (`:203-204`). So the fight half of the demo is
already shaped like an 8-minute act with a built-in curtain. The demo director's real job is owning
the OTHER 12 minutes: it must **hold the sun** — pin the clock in late dusk for the exploration
window, then release nightfall on its own schedule (or on a player trigger, below). If SimClock runs
free, the arc's pacing is the clock's, not ours.

| Phase | Minutes | What the PLAYER is doing | What it sells |
|---|---|---|---|
| **1. DUSK ARRIVAL** | 0:00–2:00 | Boots standing inside the wire at golden hour. Garrison moving, radio chatter from the RTO's PRC-25 (diegetic VO, `field_director.gd:592-598`), gun audio test-fire in the distance, weather. NO text briefing, NO objective marker — one squadmate line: "Word is Charlie's been moving after dark. Wire's yours till stand-to." | Pillar 2 (atmosphere), Pillar 3 (no briefing UI — ADR-029), Pillar 4 (you're a member, someone talks TO you) |
| **2. EXPLORATION WINDOW** | 2:00–10:00 | Free. Village ~150 m one bearing, temple ruin ~150 m another, both visible from the berm (lamp smoke; silhouette on the dusk skyline — the pull must be OPTICAL, not UI). Crossing 120 m out arms the fire-support grant (`_poll_wire_gate`, `field_director.gd:1066-1085`) — the demo's one "tutorialized" beat, delivered as a radio call, not a popup. | Pillar 3 (freedom), Pillar 2, Pillar 4 (squad walks with you, holds its own spacing) |
| **3. NIGHTFALL + PROBE** | 10:00–12:00 | Full dark falls. Demo director calls `open_siege(forced_strength≈8)` — ≤ `PROBE_MAX` 11 (`siege_director.gd:17, :142-157`), so it reads as sappers testing the wire, not a broken siege. Player runs back / is already back; stand-to toast (`field_director.gd:1240`). First shots in the dark, first illum decision. | Pillar 1 (first blood is a SITUATION — dark, wire, asymmetry), Pillar 2 |
| **4. MAIN ASSAULT** | 12:00–18:00 | Demo director forces the real roll: `open_siege(forced_strength≈40-45)` (the `elif forced_strength > 0` override, `siege_director.gd:151-152`). Ranging mortars walk in over 180 s (`:47-49, :266-272`), cells materialize when lit (`:242-245`), player calls illum/HE through the living RTO (`request_fire_support`, `field_director.gd:444`; illum is "the siege's strategic verb", `:675-681`), break fires at ~42.5% killed (`BREAK_BASE_RATIO`, `siege_director.gd:30`). | Pillars 1+2+4 at once — this is the demo's thesis statement |
| **5. RESOLUTION** | 18:00–20:00 | Break → withdrawal → the reap clears the AO (`_process_reap`, `siege_director.gd:363-387`). Sun comes up. Player walks the wire among the bodies and the burnt sandbags. Radio VO closes the net. Fade to a period-styled end card. | Pillar 2, and the emotional landing (§d) |

### The exploration window must REWARD, never REQUIRE

The rule: **the siege comes whether or not you walked out.** A player who sits on the berm for 8
minutes gets the same night. But walking pays in three currencies, all diegetic, all shipped or cheap:

1. **Foreknowledge.** Cut wire, a marked trail, drag marks near the temple — set dressing placed on
   the demo's forced `sector_bearing`. The player who explored KNOWS which side the attack comes
   from. That is a real tactical edge worth ~2 minutes of walking, and it costs zero systems — the
   demo seed is fixed, so the signs and the sector agree by authorship.
2. **The fire-support grant itself.** It arms on crossing 120 m outbound (`field_director.gd:1092-1110`).
   If the demo keeps that contract, staying home means fighting the night without steel — a fair,
   legible price. (If the council rules that's too punishing for a first impression, grant it at
   stand-to instead — but I'd keep the shipped contract: it teaches "patrolling buys protection,"
   which IS the game's loop in miniature.)
3. **The place itself.** Temple and village are the proof the AO is a world, not an arena backdrop.
   A demo player who never sees them still glimpses them burning tracer-lit at minute 15.

**Optional trigger refinement:** rather than a hard 10:00 nightfall, release night when the player
crosses BACK inside 95 m (`WIRE_RETURN_M`, `field_director.gd:856, :1087`) OR at 10:00, whichever
first. The explorer who returns early isn't punished with dead air; the timer floor protects the
homebody. Cheap, and it makes the arc feel responsive instead of scripted.

---

## (b) Systems IN / systems OUT — a demo shows confidence, not scaffolding

### MUST BE IN (these five sell the five pillars)

| System | Why it's load-bearing |
|---|---|
| **Full gunplay + viewmodel stack** (ADR-016/034) | Pillar 1's second half. Non-negotiable. |
| **SiegeDirector complete** — probe class, ranging walk, light-materialization, break, reap | Pillar 1's first half: an enemy with cadence and morale, not a wave counter. The break-and-withdraw is the single most "AI fights like soldiers" moment we own. |
| **Squad + the RTO radio contract** (living RTO within 10 m, `field_director.gd:579-588`) | Pillar 4. The radio being a MAN who can die is the demo's best 10-second story. Suggest-level squad verbs only — no individual positioning exists and none should be faked for the demo. |
| **Fire support: illum + mortar HE + arty barrage ONLY** | Illum is the siege's designed counterplay (`:675`). HE/arty show the FO-skill system. |
| **Wire gate + stand-to + weather/night/audio** | The grant beat, the "STAND TO" toast (`:1240`), and Pillar 2 wholesale. |

### SURGICALLY OUT — with the sacrifice named (Law 2)

| Excluded | Why | **Sacrificed** |
|---|---|---|
| **Save/load** (ADR-007) | A 20-min deterministic slice; F5/F9 in a demo invites reload-and-memorize — the exact anti-pattern Pillar 5 names (ADR-036 §5). Fixed seed makes restart cheap. | A crash eats the whole run. Accepted: 20 min is the whole stake. |
| **Debrief/AAR banking + campaign XP/ranks** (`_bank_patrol`, `field_director.gd:1089`; ADR-018) | Campaign persistence is OFF by the briefing's definition; a scoreboard after a night like that would cheapen the landing, and XP is hidden by decree anyway (progression ruling). | **The biggest sacrifice on this sheet:** Pillar 4's long arc — "teammates who improve, rotate home, die for real" — is UNSOLD. The demo shows the squad's night, not its career. Mitigate with one end-card line per squadmate by name (alive / wounded / KIA), which costs a text pass, not a system. |
| **ADR-036 objectives / respawn / overrun** | BLOCKED by its own §1 — nine dependencies don't exist. A demo must never ship a system its own ADR calls unbuildable. | The siege has drama but no STAKE-object; you defend a place, not a thing. Accepted — that's ADR-035's shipped shape. |
| **Fixed-wing air (snake eye / napalm / Spooky / CBU)** (`field_director.gd:485-512`) | Four more VO/timing paths to polish and pace-break risk in a tight 6-min assault; mortars + arty already demonstrate the FO system. | The demo's single biggest "wow" candidate (a Spooky burst over a night siege is a trailer shot). If ONE comes back, make it Spooky, scripted once at ~minute 16 as a demo-director beat, not a player verb. |
| **M-map patrol pencil** (patrol-contract decree) | Route-drawing sells a 40-min patrol, not a 400 m stroll; it's UI surface with no payoff at this scale. | The Freedom pillar's signature UI goes unshown. The open window must carry Freedom on its own. |
| **Site intel / stash-reveal economy** (`field_director.gd:1015-1049`) | A claims-economy needs a campaign to spend claims in. | Nothing a demo player would miss. |
| **Player-death world-teardown → demo restart** | Death restarts the 20 min (fixed seed = same night, so knowledge carries — a run-based consolation). Flagged honestly: this is a fail-state and sits in tension with Pillar 5. A demo IS a run; I hold it acceptable HERE and nowhere else. Do not soften damage to dodge it — Pillar 1 outranks demo comfort. | Some demo players die at minute 14 and never see the break. That's Vietnam; it's also the replay hook. |

---

## (c) The AO edge — turning the player around without a wall

400×400 with the firebase centered means the wire-to-edge distance is ~200 m — one minute's walk.
Note the collision with siege geometry: the shipped ring is 300–500 m (`siege_director.gd:20-21`) and
mortar standoff 700 m (`:51`), all outside the slice — but the host-override vars exist precisely for
this (`:68-77`), so the demo scene compresses ring/rally/standoff and this is a config, not a fork.

Three layers, in order of preference — Freedom says no rails, so every layer is denial-by-meaning,
never denial-by-collision:

1. **Geography claims the edges.** Fixed seed = we author the border once: a river bend taking two
   edges (water is honest denial — nobody feels railed by a river at night), an escarpment/deadfall
   on the third, bamboo-and-slope density on the fourth. All from existing terrain + impostor foliage
   kit. This should stop 90% of players without a single system.
2. **The radio turns you around in fiction.** Past ~170 m from center, one RTO line through the
   shipped VO path: *"That's past our fire fan — arty can't reach you out there."* True in-fiction
   AND mechanically honest if the demo scene scales the support envelope to the slice. One line, one
   trigger radius, reuses `_radio_vo`.
3. **The last 15 m: fog + nothing.** Ground mist thickens toward the boundary (dusk/night hides the
   trick), and beyond it there is authored NOTHING — no silhouettes, no lights, no audio sources.
   Players walk toward content; absence steers better than force. If a player swims the river anyway,
   let them: they find dark empty jungle and a squadmate saying "we're way off the map, Sarge." No
   invisible wall, ever — one bump against glass and the Freedom pillar is dead in the reviewer's
   first paragraph.

**Sacrificed:** an authored border quietly contradicts "the seeded world generates the stories"
(Pillar 3's second clause) — the demo's edge is a stage flat. Accepted for a fixed-seed demo;
flagged so nobody promotes the technique into the campaign generator.

---

## (d) Minute 20 — the end state and the emotion

**Dawn, not a relief column.** Three reasons: (1) the dawn break is SHIPPED — `MAX_DURATION_S` ends
the siege with reason `"dawn"` and the reap walks the survivors off (`siege_director.gd:203-204,
:335-357`); (2) no vehicle system has ever moved a convoy — a relief column is a new system built for
a cutscene, the exact scaffolding a demo must not show; (3) dawn is the truthful Vietnam ending — 
nobody comes, the sun does, and you're still there. It's also the stronger image.

**The landing beat, ~90 seconds, all shipped parts plus one authored VO line:**
sky lightens → last cells break and run (the player SEES them go — the reap is the payoff of the
morale system) → firing stops → hold the silence, let birdsong/ambience return → player free-walks
the wire among bodies and wrecked sandbags → RTO VO: net closes, situation report, quiet → fade to a
period-styled end card: the demo title, the date, and the squad roster by name with their state.
If the player died instead: same card, his own name on it, and the restart prompt. Both endings land.

**The emotion is EXHAUSTED RELIEF — "I held," not "I won."** No fanfare, no score, no stinger music.
The demo's last impression must be the same as the game's thesis: you survived a night in a war that
doesn't care, next to men you now know by name. If a first-time player sits through the end card in
silence, phase 5 did its job. A victory jingle would undo all nineteen minutes before it.

**Sacrificed by "no relief column":** the fantasy of cavalry, and a scripted spectacle beat.
**Sacrificed by "no score card":** the player leaves without a number to compare — no leaderboard
hook, no "beat my kills" virality. Ruled worth it: this game's virality is the STORY the player
tells, and stories don't have scores.

---

## Loop-structure flag (briefing asked)

The demo director forcing `open_siege()` twice in one night (probe, then main) uses the
`forced_strength` override to bypass the once-per-run d50 ledger (`siege_director.gd:145-152`). That
is a DEMO-ONLY pacing move — the campaign's roll-once-per-run rule (ADR-035) is untouched, but the
systems architect should confirm the override path leaves `run_peak`/`nights_run` coherent for the
break math when called twice. Composition, not a fork; flagged per briefing constraint 5.
