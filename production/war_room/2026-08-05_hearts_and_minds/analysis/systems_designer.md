# SYSTEMS DESIGNER — The Machine

**War Room:** 2026-08-05 Hearts & Minds · **Architect:** Systems Designer · **Scope:** analysis only, no code
**All pointers verified against source 2026-08-05.** Where I could not find a pointer, I say so — that is the finding.

---

## 0 · What I verified beyond the briefing

The briefing proved the system does not exist. I went looking for what *does* exist that a
hearts-and-minds machine could be bolted to without inventing anything. Five findings, all new:

| # | Finding | Pointer |
|---|---|---|
| V1 | **Villages already have a deterministic generator index.** `mission_generator.gd:565` appends `{"kind":"village","center":found}` once per quadrant in a fixed loop. The loop ordinal IS ADR-017 §7's "deterministic generator index" — it is computed and then **thrown away**. | `scripts/missions/mission_generator.gd:550-567` |
| V2 | **Villages already have stable NAMES.** `HamletNames.name_for(seed, index, radius)` is seeded by `hash(seed*7919 + index)` and is already used for the topo sheet. The naming scheme already assumes a stable index — it just re-derives it from `surveyed_sites.size()`, which is a *presentation* order, not a generator order. | `scripts/world/hamlet_names.gd:26-31`, `scripts/missions/field_director.gd:1261-1264` |
| V3 | **A village id already exists in one place and is a position hash — exactly what ADR-017 §7 forbids.** `civilian.gd:309` computes `absi(hash(Vector2i(int(center.x), int(center.z))))` and hands it to `DynamicMissionFactory.report_village_distress`. It works today only because the world is regenerated from one op seed; it is unsound the moment a village moves a metre. | `scripts/world/civilian.gd:308-310`, `scripts/missions/dynamic_mission_factory.gd:65-69` |
| V4 | **`EvidenceLedger.on_structure_burned` has ZERO callers repo-wide.** The arson hook the briefing calls "the arson hook" is itself a fossil. The only thing in the game that sets huts alight is `CASAirplane._ignite_nearby_structures` (`cas_airplane.gd:383-384`), and it does not touch the ledger. **There is no player Zippo verb.** Burning a village — the literal sentence ADR-019 is built on — is not implementable today by any means except calling napalm on it. | `scripts/enemies/evidence_ledger.gd:71` (def) vs. repo-wide grep (0 callers) |
| V5 | **Trap density is already a one-line roll at a per-village call site.** `for _t in range(rng.randi_range(1, 2))` → `PunjiTrap.place(...)`. This is the cheapest, most legible consumer a village ledger will ever have. | `scripts/world/site_planner.gd:282-285` |

V1+V2 are the good news: **village identity is 90% built and one line from being real.**
V4 is the bad news and belongs in the Arbiter's decree: ADR-019 §3's binding law ("burning the
village must genuinely work") is unbuildable until a burn verb exists. That is a *separate* piece of
work from the ledger and it must not be smuggled into the ledger's scope.

---

## A · PERSISTENCE MODEL

### Recommendation: **HYBRID — a per-village dated decaying conduct ledger, plus ONE derived AO-wide scalar that feeds the existing threat road.**

The Summoner's instinct is right and I am endorsing it without hedging: **faction memory should be
`add_threat_modifier`'s shape**, not a float. Here is why, in machine terms rather than taste.

A single float per village is *lossy in exactly the wrong place*. `threat_modifiers` is not a list
because a list is prettier — it is a list because **each entry knows when it dies and why it exists**.
`campaign_state.gd:234-239` decays entries one mission at a time and drops them; `effective_threat()`
(`:204-208`) sums whatever survives. That gives three properties a float cannot give you at any price:

1. **Forgiveness is free and automatic.** A float needs a decay rate, a floor, a clamp and a tuning
   session. A list forgets by construction, and each entry forgets on its own schedule — a burned
   hut can outlive a stray round without a second variable.
2. **The reason string is the debrief.** ADR-019 §4 forbids a meter but *sanctions* sentiment
   language. A ledger entry already carries `reason`. The AAR line "THEY HAVE NOT FORGOTTEN AP BINH
   HOA" is a string lookup, not a threshold classifier over an opaque float.
3. **It is auditable when it goes wrong.** Delayed consequence is the single biggest risk ADR-019
   names ("easy to experience as unfairness", `ADR-019:106`). When the Summoner says "why did that
   ambush happen," a list answers. A float shrugs.

The cost of the list is that it is **unbounded without a cap** and that summing it is O(n). Both are
priced in §E and both are nothing.

### The data structure

One new array on `CampaignState`, sitting beside `threat_modifiers`:

```
## [{vid: String, kind: String, delta: float, patrols_left: int}]
var conduct_ledger: Array = []
```

- `vid` — the village's stable id (§D). `""` means **AO-wide** (artillery in open jungle, a body
  left on a trail nobody owns). AO-wide entries are legal and necessary; not every act happens in a ville.
- `kind` — the conduct event key from the §B table. Doubles as the reason string and as the debrief
  lookup key. One vocabulary, not two.
- `delta` — signed, **in the same units as `threat_modifiers.delta`**, i.e. a fraction of 1.0 where
  one threat band is 0.25. This is the whole point of the hybrid: conduct and AA sabotage speak the
  same number, so they can be compared, argued about and tuned against each other.
- `patrols_left` — decayed in `on_mission_end` in the same loop shape as `:234-239`. **Patrols, not
  seconds.** Village memory that decayed on a wall clock would forget while the player slept in the
  firebase, which is the wrong fiction and also unfalsifiable in a test.

**Cap: 60 entries.** On overflow, drop the oldest *positive-delta* entry first (never the newest, never
a negative one — dropping the player's good deeds to make room for his sins is a bug that reads as malice).

### The save key

`cfg.set_value("campaign", "conduct_ledger", conduct_ledger)` — one line at `campaign_state.gd:305`
(beside `threat_modifiers`), one read at `:351`, one entry in `to_dict()`/`from_dict()`
(`:390-408` / `:411-432`), one line in `reset_campaign()` (`:435-465`).

**`SAVE_VERSION` does NOT need to bump.** `cfg.get_value(..., [])` defaults an absent key to empty,
which is the correct reading of a save written before anyone was counting — exactly the precedent
`kia_total` set at `:368-369`. *Sacrificed:* no migration means an old save starts the ledger at zero
and the player's pre-patch sins are forgiven. That is the right answer and it is free.

⚠️ **`from_dict` is a known trap here.** `field_marks` was written to the `.cfg` while being absent
from *both* sides of `to_dict`/`from_dict` — a SaveManager snapshot round-trip silently deleted the
player's whole intel layer (`campaign_state.gd:424-426` documents the wound). A conduct ledger added
to `save_campaign` but forgotten in the dict pair will be silently erased by any slot save, and it will
look like the *decay* working. **Both pairs, same change, or it is a fossil on arrival.**

### Cost

- **Save size:** a `threat_modifiers` entry serialises to ~70 bytes of ConfigFile text. A conduct
  entry (four keys, one short string vid, one short string kind) is ~110 bytes. **60 entries ≈ 6.6 KB.**
  `campaign.cfg` today carries a 40-entry `mission_log`, a roster, and unbounded `field_marks` /
  `pencil_marks` / `collapsed_tunnels` arrays. 6.6 KB is noise against what already ships.
- **CPU:** see §E. Zero per-frame.

### What each alternative sacrifices

| Model | Buys | Sacrifices |
|---|---|---|
| **One global scalar** | Trivial. Two lines. Ships this afternoon. Cannot desync from a village that stopped existing. | **Kills the whole design.** ADR-019's fiction is *"the ville down the road"*. A global number means burning a hamlet 900m away wires the trails outside a village you were kind to. The player can never learn the rule, so he cannot make a *choice*, and choice is the system. Also: no reason string worth printing — "THE PROVINCE IS ANGRY" is not a briefing, it is a mood ring. |
| **Per-district ledger** | Right granularity for ADR-017's province. Bounded entry count. | **Districts do not exist.** `grep -ri ProvinceState` = 0 hits (briefing, verified). There is no district generator, no district id, no district anything. A design keyed on districts is a design that ships when ADR-017 ships, i.e. **never on current evidence**. |
| **Per-village ledger only** (no AO scalar) | Maximum fidelity. | The pressure has nowhere to go. Every existing consumer — `NIGHT_CHANCE` (`siege_director.gd:191`), `_grant_fire_support` (`field_director.gd:1421`), the barracks label (`barracks.gd:45`) — reads **one AO-wide number**. A purely local ledger would need every one of those retrofitted before the player felt anything. The AO scalar is the adapter that makes the ledger *land on day one*. |
| **HYBRID (recommended)** | Local fidelity where the fiction needs it; global pressure through a road that is already built, saved, decayed and consumed by three systems. Every consumer is a one-liner. | **Double-counting risk** (§C names the exact trap). And one honest loss: a player who wrecks village A gets marginally hotter nights near village D too. That is defensible — word travels — but it *is* a fudge, and it is the price of not waiting for ADR-017. |

### What can be built on `CampaignState` alone — plainly

**All of it, minus the district manpower pool.** `CampaignState` is an autoload, is saved, is
versioned, already carries per-thing arrays keyed by world position (`collapsed_tunnels:36`,
`field_marks:40`), and already owns the one number the sim reads. It needs no `ProvinceState`, no
province generator, no save migration, and no ADR-017 work of any kind.

The one ADR-019 promise that genuinely **cannot** be built on `CampaignState` alone is
§2's headline — *"VC manpower regenerates at a rate set by how the districts feel about you"* — because
there is no persistent manpower pool. `_hunter_pool` (`field_director.gd:116`) is a per-mission `int`
reset every world build, and it is *already* overridden in demo (`:1391`). A persistent pool is real
work and it is not this session's. **Say so in the decree rather than letting ADR-019's most quotable
line ride as if it were within reach.**

---

## B · THE WEIGHTS

### The calibration frame

Three fixed points, all from live code:

1. **One threat band = 0.25** (`campaign_state.gd:211-219`), and a band is a real jump in felt
   pressure: `NIGHT_CHANCE` LOW 0.05 → MODERATE 0.15 → HIGH 0.30 → CRITICAL 0.45
   (`siege_director.gd:12`). Crossing one band roughly **doubles** your odds of being hit at night.
2. **The largest single lever in the game today is −0.25 over 3 missions** — destroying an AA battery
   (`campaign_state.gd:248`). That is a battalion-level event. **No single act of personal conduct may
   exceed it.** This is the ceiling and it is not negotiable, or the ledger swallows the campaign.
3. **The smallest meaningful lever is −0.08 over 2** — one opportunistic AA kill (`:250`). Anything
   below ~0.02 is beneath the resolution of a system the player is forbidden to read
   (ADR-019 §4). **0.02 is the floor.**

Everything below sits between 0.02 and 0.20 and is stated in those units.

### The table

`+` = toward HOSTILE (raises pressure). `−` = toward COOPERATIVE. Scope `V` = the village whose
radius contains the event; `AO` = the whole ledger.

| # | Conduct event | delta | patrols | scope | Detection today |
|---|---|---|---|---|---|
| 1 | **Civilian killed** (direct fire, per body) | **+0.06** | 12 | V | ✅ **exists** — `civilian.gd:630 _record_noncombatant_death` → `field_director.gd:88` → `mission_state.gd:26`. Needs Bug B fixed to survive banking. |
| 2 | **Civilian killed by arty / airstrike** (per body) | **+0.09** | 12 | V | 🟡 **partial** — the death fires; the *attacker* param is received and discarded (`civilian.gd:630 _record_noncombatant_death(_killer)` — note the underscore: it is deliberately unused). Attribution needs the killer routed, not invented. |
| 3 | **Village structure destroyed or burned** (per hut) | **+0.05** | 16 | V | 🟡 **partial** — `flammable_structures` group exists (`site_planner.gd:255`) and napalm ignites it (`cas_airplane.gd:383-384`), but **nothing counts it and `EvidenceLedger.on_structure_burned` has no caller (V4)**. |
| 4 | **The ville is gone** — latched once at ≥50% of huts destroyed | **+0.10** | 20 | V | ⛔ **new** — derives from #3, needs a per-village hut census the generator does not keep. |
| 5 | **Prisoner or surrendered man executed** (per man) | **+0.12** | 20 | V | 🟡 **partial** — `enemy_base.is_surrendered` (`:2761`) and the surrendered group (`:2648, :2791`) exist; the damage path at `:2397-2399` already special-cases them. A hook fires cheaply here. Witness requirement is the hard part. |
| 6 | **Atrocity witnessed** — ear taken in sight of a civilian | **+0.08** | 20 | V | ⛔ **BUG A** — `player.gd:249-250` calls it behind a `has_method` guard with **zero definitions repo-wide**. The call site is built; the function is not. |
| 7 | **Enemy bodies left in the ville** — per body past the 3rd | **+0.02** | 6 | V | 🟡 **partial** — `EvidenceLedger.on_body_left(pos)` (`:67`) has the position; nothing correlates it to a village centre. |
| 8 | **Prisoner taken alive** (per man) | **−0.05** | 10 | AO | ✅ **exists** — `player.gd:963-978`, the SECURE verb, already grants +1 intel. One extra line at the same site. |
| 9 | **Fire discipline** — patrol passed within 150m of a ville and left zero gunshot fixes inside its radius | **−0.04** | 8 | V | 🟡 **cheap** — `EvidenceLedger.fixes` (`:33`) carry `pos`; village centres are in `patrol_locations` (`field_director.gd:1259`). This is an O(fixes × villages) sweep **once, at `_bank_patrol`**. Genuinely near-free. |
| 10 | **Medical aid to a civilian / medcap** | **−0.10** | 12 | V | ⛔ **new** — no verb. The US medic revives *squad* only (`recon-medic-fix-and-rosters`). |
| 11 | **Supplies delivered** | **−0.06** | 10 | V | ⛔ **new** — no verb, no carriable. |
| 12 | **VC tax collector / extortion visit broken** | **−0.15** | 12 | V | ⛔ **new** — no such event, no such actor. This is a whole authored encounter, not a hook. |
| 13 | **Village defended from a VC night raid** | **−0.20** | 16 | V | ⛔ **new** — `SiegeDirector` only ever attacks the firebase (`siege_director.gd:169 fsb_center` gate). A ville raid is a new director mode. |

### Why these numbers relative to each other

- **Four dead civilians in one ville = +0.24 ≈ one full threat band.** That is the calibration
  sentence, and I chose four because a hooch holds a family. It is legible, it is defensible in a
  design conversation, and it means a single stray burst (1 body, +0.06) is a *smudge*, not a
  catastrophe. ADR-019 dies if one accident brands you.
- **Arty/air collateral (#2) costs 1.5× a rifle death (#1).** Not because the corpse is different —
  because *who did it* is different. A trooper who panicked is a man; a battery that dropped on a
  ville is the Americans. This is also the ONLY lever that makes fire discipline near a ville a real
  decision rather than a slogan, and ADR-019 §2 names artillery explicitly.
- **Executing a prisoner (#5, +0.12) is the most expensive single act.** It is deliberate, unforced,
  witnessed by definition, and it is the one act with a live positive twin (#8, −0.05). The
  **2.4× asymmetry between killing and taking** is the moral weight, expressed as arithmetic, with
  nobody lecturing. It is also the cheapest pair to build — both hooks land within twenty lines of
  each other in `player.gd`.
- **Burning is intentionally NOT catastrophic per hut (#3, +0.05).** Fifteen huts ≈ +0.75 raw, which
  would pin the AO at CRITICAL forever and turn arson into a trap door. It must not be. The
  **latch (#4)** is how it stays bounded: the ledger caps a razed ville near **+0.10 (latch) +
  ~0.30 (huts, capped)**, ≈ 1.6 bands. Severe, survivable, and it decays in 20 patrols. **ADR-019 §3
  is binding: the fast road must genuinely work.** A permanent brand is a morality meter with a
  correct answer, which is the PS2-cheese he rejected by name.
- **Positive acts are individually larger but rarer.** −0.10 to −0.20 each, but every one of them is
  ⛔ new. That asymmetry is honest history — it is far easier to lose a ville than to win one — but
  it is also a **live design hazard**: if the negative column ships first and the positive column
  ships never, the system is a one-way ratchet to CRITICAL and ADR-019 §3 is violated by omission.
  **Item #9 (fire discipline) is the mitigation** and it is the reason I priced it as buildable
  today: it is the ONE negative-delta earner that needs no new verb, no new actor and no new art.
  **If exactly one positive lever ships, ship #9.**
- **Decay lengths run 6–20 patrols** vs. `threat_modifiers`' 2–3. Conduct memory must outlive a
  tactical spike or it is not memory. 20 patrols is long enough to span a tour and short enough that
  no state is terminal.

### Cheap vs. expensive, summarised

- **Buildable on existing hooks (5):** #1 (needs Bug B), #7, #8, #9, and #5 modulo witnessing.
- **Needs attribution plumbing (2):** #2, #3.
- **Needs a new verb, actor or director mode (6):** #4, #6 (Bug A), #10, #11, #12, #13.

**The honest read: the ledger can be fed a meaningful diet from four hooks that already exist.**
Everything else is content, and content is main-game.

---

## C · THE FEEDBACK LOOP

### How standing becomes pressure

**Do NOT append conduct events into `threat_modifiers`.** That is the obvious move and it is wrong
twice: (a) the entry would decay in `threat_modifiers`' 2–3 mission cadence *and* in the conduct
ledger's 12–20 patrol cadence, **double-decaying**; (b) it pollutes the `reason` list that the
barracks and main menu already surface (`barracks.gd:45`, `main_menu.gd:97`) with thirteen new
strings, which is a meter by accident and an ADR-019 §4 violation.

**Instead: one term added to the sum.** `effective_threat()` (`campaign_state.gd:204-208`) becomes:

```
total = threat_level + Σ(threat_modifiers.delta) + conduct_pressure()
```

where `conduct_pressure()` sums every live conduct entry (all villages, all scopes) × a coupling
constant. **`CONDUCT_COUPLING = 0.5`.** The ledger's numbers are *village*-scale; the AO feels half of
what any one ville feels. With four villages, wrecking one (~+0.30 local) moves AO threat +0.15 —
**MODERATE toward HIGH, night-raid odds 0.15 → 0.30.** That is ADR-019's delayed cost, in numbers,
delivered through machinery that already ships.

*Sacrificed:* `effective_threat()` stops being a pure sum of one array and becomes a sum of two. It
is called from three sites and clamped at `:208`, so the blast radius is small — but the clamp now
matters far more than it did, and **a runaway ledger silently saturates at 1.0 and the system goes
mute at exactly the moment the player is being punished hardest.** Whoever builds this must assert on
`conduct_pressure()` magnitude in a test, not trust the clamp.

### The consumers, honestly triaged

| Consumer | Call site | Exists today? | What changes |
|---|---|---|---|
| **Siege night chance** | `siege_director.gd:191` — `NIGHT_CHANCE.get(CampaignState.threat_label(), 0.0)` | ✅ **LIVE** | **Nothing.** It reads `threat_label()`, which reads `effective_threat()`. Conduct lands here for free the instant the term is added. This is the single most valuable fact in this analysis. |
| **Fire support tier** | `field_director.gd:1421` — `var tier := CampaignState.threat_label()`; HIGH/CRITICAL unlock napalm+CBU (`:1427-1431`) | ✅ **LIVE** | **Nothing** — and it is *load-bearing for ADR-019 §3.* Wrecking villes raises threat, which **buys you napalm**. The fast road pays, immediately and legibly, through code that already runs. Nobody has to design that; it falls out. |
| **Barracks / menu sentiment** | `barracks.gd:45`, `main_menu.gd:97` | ✅ **LIVE** | Free. The word the player already reads now includes his conduct. |
| **Siege strength roll** | `siege_director.gd:203` — `_rng.randi_range(1, 50)` | 🟡 one line | `randi_range(1, 50 + int(conduct_pressure() * 40))`. At +0.30 pressure the d50 becomes a d62. Note it is rolled **once per run** (`:200-204`) and `run_peak` must move with it (`:205-215` documents exactly how this goes wrong). |
| **Hunter pool size** | `field_director.gd:116` `_hunter_pool: int = 12`; demo floor at `:1391` | 🟡 one line | `12 + int(conduct_pressure() * 12)`. **Per-mission, not persistent** — this is a *rate* knob, not ADR-019 §2's manpower pool. Do not mislabel it as one. |
| **Trap density** | `site_planner.gd:282` — `rng.randi_range(1, 2)` per village | 🟡 one line, **per-village** | `randi_range(1, 2 + int(hostility(vid) * 8))`. **The most legible consumer in the game.** ADR-019 §4's "trails that used to be clean and are now wired," literally. Requires `vid` at stamp time (§D). |
| **Informer density** | `civilian.gd:190` `civ.is_informer = informer`, set from the spawner around `mission_generator.gd:1025` | 🟡 one line, per-village | Hostility raises informer probability; cooperation drops it toward zero. `_inform_clock` and the `hands_up` tell already exist (`civilian.gd:336, :399, :652`). |
| **S2 intel toast** | `field_director.gd:1382-1386` — fires when `intel_points > 0` | 🟡 one line | Gate it on the *target* village's hostility: a ville that hates you tells S2 nothing. **Withholding information is the correct move** per ADR-019's own Consequences (`:98-100`). |
| **Ambush pre-positioning** | — | ⛔ **DOES NOT EXIST** | Be plain about this. `_pick_patrol_location()` (`field_director.gd:1679-1727`) reads **crisis triggers, the player's route anchor, and push-direction from the gate**. It reads **no threat value whatsoever.** Hunters are the only reactive spawn, and they spawn 180–230m from an `EvidenceLedger.best_fix` (`:168-179`) — i.e. from *what the player left behind*, deliberately, so they are never telepathic (`evidence_ledger.gd:1-9`). **"The ambush that was waiting where nobody should have known you were going" (ADR-019:76) has no implementation and is architecturally at odds with the ledger's founding principle.** Resolving that is a design question for the Arbiter, not a knob. |
| **Patrol composition / quality** | — | ⛔ **DOES NOT EXIST** | Enemy quality is `"res://data/enemies/nva_regular.tres"`, hardcoded at the hunter spawn (`field_director.gd:179`). There is no composition selector to read a ledger. |
| **VC manpower regeneration** | — | ⛔ **DOES NOT EXIST** | ADR-019 §2's headline. No persistent pool anywhere. See §A. |

**Score: 3 consumers land free, 5 are one-liners, 3 do not exist at all.** That ratio is the argument
for the hybrid. A per-district design scores 0 / 0 / 11.

---

## D · THE RETROFIT HOOK

### The ONE thing: **a stable village id, emitted by the generator, carried to the stamp and the director.**

Concretely, the minimum is two lines and one field:

- `mission_generator.gd:565` — `p.sites.append({"kind":"village", "center":found, "vid":"v%d" % qi})`
  where `qi` is the quadrant loop ordinal that **is already being computed and thrown away (V1)**.
- `field_director.gd:1259` — carry `vid` into `patrol_locations` alongside `pos` and `kind`.
- `SitePlanner.stamp_village` — accept it, so the trap roll (`:282`) and the informer roll can read it.

That is the whole hook. Nothing else. No ledger, no weights, no save key.

### Why it, and not Bug B

Bug B (`_bank_patrol` at `field_director.gd:1770-1776` never copying `civilian_deaths`, while
`fail_mission` does at `:210`) is a **real bug and must be fixed** — the number the whole system eats
survives only when the player dies, which is the exact fossil shape ADR-023 names. But it is **not a
retrofit hook.** It is one line, it can be fixed on any Tuesday, it changes no data shape, and fixing
it late costs exactly the sessions before the fix. Its urgency is *bug* urgency, not *architecture*
urgency. Filing it as the retrofit hook would give it the wrong priority for the right reason.

**Village identity is different in kind, because it is the thing you cannot add later without
invalidating saved data.** The moment a ledger ships keyed on *anything else* — a world position, a
`Vector2i` hash of the centre (`civilian.gd:309`, V3), a hamlet name, a `surveyed_sites` array index
(`field_director.gd:1264`) — every save written from then on is keyed on a value that is not stable
under generator change. Move one village 30cm, change one placement constant, insert one site kind,
and every ledger entry orphans. The player returns to find **the wrong hut burned** — which is the
precise failure ADR-017 §7 wrote itself to prevent, and which ADR-017 §8 calls out as *worse than no
persistence at all* (`:93-95`).

There is a second, sharper reason: **the wrong key is already in the codebase and spreading.** V3's
position hash is live, in shipped code, feeding `DynamicMissionFactory`. If a hearts-and-minds ledger
is built next year by an agent reading this repo, that line is the pattern it will copy — it is the
only village-id precedent that exists. Laying the real id now does not just enable the ledger; it
**deletes the wrong answer before it becomes the convention.**

*Sacrificed:* three lines of scope creep into the demo build, and a `vid` field that nothing reads for
months — which is precisely the **UNFINISHED** category the fossil law warns about (built ahead of its
wiring). Mitigation: one line of the pointer law in the ADR that names what it is for and when it
gets wired, so the next reader triages it correctly instead of deleting it as dead.

---

## E · PERF — pricing the recommendation

The frame is CPU-bound in the AI, and there is no gating FPS number. So the price must be **zero
per-frame cost**, not "small per-frame cost." My recommendation is zero, and here is the arithmetic.

**Writes.** An `Array.append` of a 4-key Dictionary. Frequency: a handful per patrol (the §B table's
buildable events are civilian deaths, prisoners, bodies, and one fire-discipline sweep). Worst
realistic case — a massacre — is ~20 appends in a 30-minute patrol, none in the same frame as another.
Unmeasurable.

**Reads.** Three shapes, all O(n) over `n ≤ 60`:
- `conduct_pressure()` — one pass, summing. Called from `effective_threat()`, which is called from
  `siege_director.gd:191` (once per night roll), `field_director.gd:1421` (once per walk-out), and
  the two UI screens (once per screen open). **Call count per patrol: ~4.**
- `hostility(vid)` — one filtered pass. Called at village stamp time (4 villages per world build) and
  at the S2 toast (once). **Call count per world build: ~5.**
- Decay — one pass in `on_mission_end` (`campaign_state.gd:234-239` shape). **Once per patrol.**

Ten passes over a 60-element array per patrol ≈ **600 dictionary lookups per 30-minute patrol.**
That is microseconds of total CPU across an entire play session. It does not appear in a profile.

**The fire-discipline sweep (#9)** is the only non-trivial read: `EvidenceLedger.fixes` × villages,
`Vector3.distance_to` each. `fixes` is bounded by the 40m merge radius (`evidence_ledger.gd:31`) —
realistically tens, not hundreds — × 4 villages. **~200 distance checks, once, at `_bank_patrol`,
during a toast the player is already reading.** Free.

**Save.** +6.6 KB worst case to a `ConfigFile` write that already happens at every `save_campaign()`
and already serialises a roster, a 40-entry mission log, and three unbounded mark arrays.

### THE LAW THIS DESIGN MUST SHIP WITH

> **No consumer may call `conduct_pressure()` or `hostility()` from `_process` or `_physics_process`.**
> Every consumer reads it ONCE, at spawn / stamp / roll / bank, and caches the result on the node.

This is not a style note — it is the entire perf story. The design is free *because* every consumer
in §C is a one-time roll at a discrete event (a night roll, a walk-out, a village stamp). The moment
one AI reads village hostility in its think loop, an O(60) array walk enters a 6–7 Hz per-enemy budget
and the price stops being zero. ADR-019 says "a live numeric meter is forbidden" for moral reasons;
the same prohibition is the perf contract, and that alignment is not an accident. **Anything the
player is forbidden to read continuously is also something the sim never needs to poll.**

*Sacrificed:* conduct cannot change mid-patrol in a way the world reflects *this* patrol. Burn a ville
at minute five and the trails outside it are not wired until you walk out again. Correct on every
axis — perf, fiction (word takes time), and ADR-019's whole thesis that the cost **comes later, and
quietly** (`:60-62`).

---

## NAMED SACRIFICES — the full list

1. **The hybrid's AO scalar smears local conduct across the map.** Wrecking village A makes nights
   hotter near village D. Defensible as word-of-mouth; it is still a fudge, and it exists only because
   ADR-017's districts do not.
2. **No save migration** means pre-patch conduct is forgiven wholesale. Free, correct, and it does
   mean the system's first day starts everyone clean.
3. **`effective_threat()` stops being a pure array sum**, and its `clampf` at `:208` becomes
   load-bearing. A runaway ledger saturates at 1.0 and goes silent under maximum punishment.
4. **The `vid` field is an UNFINISHED per the fossil law** from the day it lands until the day the
   ledger reads it. It needs a pointer-law note in the ADR or the next agent deletes it.
5. **The negative column is buildable and the positive column mostly is not.** Ship the table as
   written and ADR-019 §3 is violated by omission — a one-way ratchet with no road back. **#9 fire
   discipline is the mandatory counterweight.**
6. **ADR-019's most quotable promise — allegiance-driven VC manpower regeneration — is out of reach**
   and should be stated as out of reach rather than implied. `_hunter_pool` is a per-mission rate knob
   and calling it a manpower pool would be the exact drift CLAUDE.md legislates against.
7. **Three of eleven named consumers do not exist** (ambush pre-positioning, patrol composition,
   manpower). Of those, pre-positioning is not merely unbuilt — it is in **tension with
   `EvidenceLedger`'s founding law** that enemies never converge on a route the player picked in
   private (`evidence_ledger.gd:1-9`). That contradiction belongs in the Arbiter's decree.
8. **And the one that outranks all of them: `EvidenceLedger.on_structure_burned` has no callers and
   there is no player burn verb (V4).** Every weight in §B that involves burning is priced against a
   verb that does not exist. ADR-019 is founded on a sentence — *"maybe one day you just wanna burn
   down the village down the road from you"* — **that the game cannot currently execute.** Building
   the ledger without building the Zippo is building a scoreboard for a game nobody can play.
