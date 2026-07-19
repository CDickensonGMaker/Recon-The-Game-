# ANALYSIS — Game Designer + UX Designer lens
**Council:** 2026-07-19 playtest bundle (7 items) · **Lens:** player experience
**Assignment:** Q1 (Item 2 canon conflict) primary; rulings on Items 7, 4, 1.

---

# PART ONE — ITEM 2: "HOW DO I FINISH THE CLEARING?"

## 0 · What actually went wrong (name it precisely)

The owner's report contains two complaints that look like one and are not:

1. *"it was like wait sweep this area"* — he did not know what DONE meant.
2. *"i did find a vc tunnel but couldn't do anything about it. couldn't blow it up or hit F"* — he
   found the one object that obviously mattered and the game offered him **no verb at the moment of
   opportunity**.

**Complaint 2 is not a design conflict. It is a flat r4bk violation and it is the whole bug.**
`player.gd:241-251` *does* handle `tunnel_entrances` at 3.0 m radius — the tunnel was interactable the
entire time. There is **no world prompt, no HUD affordance, nothing**. A feature without a visible
affordance does not exist, and to the owner it did not exist. He was standing on a live verb and the
game never said so.

Complaint 1 is the genuine canon question. I answer it below, but the council must not let the
interesting philosophical question hide the fact that **the cheap fix is 80% of the felt problem.**

## 1 · The resolving principle

> ### **A REPORT IS NOT A RAIL.**
> ADR-029 forbids *tracking* — a persistent, player-facing thing that says what to do and how much is
> left. It does not forbid the world **telling you what already happened.**
>
> **A tracker is an instruction that persists. A report is a fact that passes.**

That is the seam, and it is legal on the ADR's own text. ADR-029 §4 forbids "player-facing mission
tracking" and "floating objective markers" — and in the *same clause* explicitly permits "compass,
repeatable point-man bark, **one gate toast**." The ADR already blessed transient diegetic reporting.
A one-shot toast that says the area went cold is the same species as the gate toast it authorizes.

What stays forbidden, and I would enforce hard:
- ❌ any persistent HUD element counting tunnels/defenders ("TUNNELS 1/2")
- ❌ any world marker floating over an unfinished thing
- ❌ any progress bar, checklist, or "SWEEP THE AREA" instruction
- ❌ `mission_state.register_objective` / `complete_objective`

## 2 · The diegetic signal: THE JUNGLE COMES BACK

**What the player SEES/HEARS when an area is finished:**

> The birds start again.

This is the answer, and it is the one the project already half-built. `game_world.gd:230` holds a
`_wildlife` array with an existing duck tween (used for rain, ~`:289`), and
`AudioManager.duck_ambience()` (`audio_manager.gd:339`) is the shipped "the world gets quieter" lever.
The system exists; nothing has ever pointed it at threat.

The loop, three beats, all diegetic:

| Beat | Signal |
|---|---|
| **You approach a live location** | wildlife bed ducks out. The jungle goes tight and quiet. |
| **While it is hot** | it stays quiet. No bird, no insect layer. |
| **When it goes cold** | wildlife bed fades back in over ~4 s + point man barks it + ONE toast. |

This is Pillar 2 doing the job of a UI element, which is the highest form of this game's design. It is
also **period-true** — silence is how a real patrol read the ground, and it is already canon language
(`GAME_GUIDE.md:227` lists "wildlife silence" under diegetic UI).

Crucially it is **not a rail**: it is a consequence, not an instruction. It tells you nothing about
what to do. It only confirms what you did. And it is **honest under uncertainty** — if a sentry is
still alive out in the trees, the birds stay down, and the player is *correct* to feel unfinished.

**The r4bk affordance** is the point man + one toast, not the audio. Audio alone would fail r4bk (the
owner would say "it just got quiet, so what?"). So:

- **Point man bark on cold:** reuse `field_director.rebark_patrol()`'s exact shape
  (`field_director.gd:500`) — `VOManager.play_squad(line_id, point.member, point.global_position)`.
- **One toast, transient**, through the existing bus: `director.toast.emit(...)` →
  `mission_hud.show_toast` (3.5 s hold + 1 s fade, `mission_hud.gd:215`). It disappears. That is what
  makes it a report.

Toast text — no numbers, no completion language, all voice:
- VC camp: `"SECTOR'S COLD. NOTHING LEFT STANDING."`
- Village: `"VILLE'S QUIET. HOLE'S BLOWN."`

## 3 · Is the tunnel the right verb? Yes — and canon already ruled it.

`GAME_GUIDE.md:262`, the FROZEN list, in the Summoner's own scoping:

> "tunnel INTERIORS (a second game… it eats a year. **Tunnel MOUTHS you mark and satchel are IN SCOPE
> TODAY.** Going down the hole is the FIRST THAW…)"

**The satchel verb is not a new feature request. It is standing canon that was never built.** The
council does not need to authorize it; it needs to notice it was skipped.

The tunnel is also the *right* verb for a deeper reason: it is the only object at a location whose
destruction is **permanent and meaningful**. `GAME_GUIDE.md:80` — "Destruction is temporary;
attrition is permanent. Bases rebuild; men don't." A killed garrison respawns with the province. A
blown tunnel mouth is a fact you put in the ground. **Completion should attach to the thing that
persists, never to a body count** — that is ADR-006's whole holding (kills pay zero) and the reason
the 80% village-clear quota was already deleted.

### Ruling: hold-to-satchel, self-contained, no inventory

Copy `armorers_bench.gd` wholesale (`:18` group, `:56` Label3D prompt, `:67-95` hold loop). It is the
right pattern because it is **self-contained and carries its own world prompt** — which is exactly the
missing affordance.

- Billboarded `Label3D` at the mouth, visible inside ~3 m: **`HOLD [E] — SATCHEL THE HOLE`**
- Hold **3.0 s** (not the bench's 20 — this is under fire), prompt doubles as `SETTING CHARGE... 62%`
- Release out of range resets progress (bench `:78-81`). Being interrupted is the tension.
- On complete: fuse delay ~4 s, then `AudioManager.play_explosion_3d` + existing
  `CombatManager.apply_explosion_damage`. **Do not invent a second damage router.**
- Mouth is marked collapsed; the enter branch (`player.gd:241`) gates on it. Note that branch
  currently has *no* re-entry guard at all.

**Scope calls, stated as cuts:**
- ❌ **No inventory item, no charge counter, no ammo-style consumable this bundle.** A counter is a new
  persistent HUD element — a fresh r4bk debt to pay for a feature meant to *fix* an r4bk debt. The
  demo charge is squad equipment, abstracted. **Scarcity comes from tunnels being rare, not from
  satchels being rationed.** Named tradeoff: a player could theoretically satchel-spam if we ever add
  more holes; revisit only when that is true.
- ❌ **Do not wire the `demolitions` skill this bundle.** It backs zero code (`skill_catalog.gd:10`).
  Gating a brand-new verb behind an unbuilt skill means the owner plants a charge and it fails for
  reasons he cannot see — a second illegibility bug on top of the first. Ship the verb ungated; let
  `demolitions` later shorten the hold time (3.0 s → 1.5 s), which is the honest use of a levelled
  skill under ADR-018 (**rank/skill gates authority and speed, never ability**).
- ⚠ **Flag, do not adjudicate:** `TunnelRoom` and the enter/loot/exit path (`player.gd:214-251`) are
  live, while `GAME_GUIDE.md:262` lists tunnel INTERIORS as FROZEN. Somebody built a piece of a frozen
  epic. That is a separate ruling for the Arbiter. For this bundle: **satchel and enter must not
  fight** — offer enter *and* satchel at the mouth, satchel being the one that ends the sector.

## 4 · Does this route through `mission_state`? **NO. And delete the API.**

Ruling: **pure world-state + transient toast.** `mission_state` is not touched.

Further, and I want this on the record as a fossil-law call: `register_objective` (`:21-27`) and
`complete_objective` (`:30-35`) have exactly one caller each — their own test. ADR-029 §7 says
"Objective tracking dies." **A system whose only caller is its own test, which current canon declares
dead, is the textbook fossil.** ADR-023: delete the old system when you replace it. Leaving it is
worse than leaving nothing, because the next agent to read this problem will find a complete, tested,
inviting objective API and wire the tunnel into it — which is *precisely the mistake this council was
convened to prevent.* **Delete both functions and their test in this bundle**, or the conflict
recurs in a month with a different agent.

### Where the state actually lives

`site_planner.placed_sites` are plain Dictionaries, and `field_director.setup_patrol` (`:464`)
**copies** `pos`/`kind` out of them — so a flag written on the source dict will not propagate. Use the
project's existing one-shot state idiom instead: `set_meta()` on the site's node
(already the pattern for `shrine.set_meta("searched")`, `fallen.set_meta("looted")`). The tunnel node
owns `collapsed`; the site node owns `cold`. Nothing global, nothing serialized into a tracker.

### The one persistent record: the topo sheet, not the HUD

ADR-022 is the correct home for "what have I finished." The location gets an **OBSERVED** stamp —
game's hand, precise, because you were there and a real man would have marked it. And per ADR-022,
**observed marks decay**, which is not a limitation here but the best part of the design: *your sweep
goes stale, because the VC come back.* A checkbox says "done forever." A staling grease-pencil mark
says "cold as of Tuesday." The second one is the game we are making.

This also means the answer to "how do I know it's finished" has a persistent home that is **not a
quest log** — it is memory, and it is allowed to be wrong (the grease-pencil law).

## 5 · Village vs VC camp — YES, they differ, and the difference is the point

| | **VC CAMP** (`stamp_vc_camp`, `site_planner.gd:582`) | **VILLAGE** (`stamp_village`, `:208`) |
|---|---|---|
| Contents | tunnel + cache + 1–2 spider holes, no civilians | 7–10 huts, cache, **1 tunnel**, civilians, punji |
| Word for done | **CLEARED** | **SWEPT** |
| Cold condition | no living hostiles + tunnel collapsed | **tunnel collapsed + no *armed* hostiles engaged** |
| Civilians | n/a | **irrelevant to completion, always** |
| Cost of the boom | none | **sentiment**, in words (ADR-019) |
| Point man, cold | "Sector's cold. Nothing left standing." | "Ville's quiet. Mama-san won't forget that hole." |

Three bindings:

1. **A village must be completable without firing a shot.** Sneak in, hold E on the hole, walk out.
   Pillar 3: *stealth is an economy, never a gate* — and ADR-006 already deleted the 80% body-count
   quota for exactly this reason. If the sweep requires kills we have silently reinstated the quota
   the canon killed on 2026-07-12. **This is the single hardest constraint on the feature.**
2. **Civilian presence never blocks or advances completion.** The moment a civilian is part of the
   cold condition, the player has a mechanical reason to shoot or herd them, and ADR-019's entire
   moral engine inverts.
3. **Blowing the hole under a village is a real cost** — it is "destroying homes" on ADR-019's HOSTILE
   column. That is *correct and should stay*: the village sweep is a genuine dilemma (leave the hole
   and the VC keep the ville, or blow it and the ville hates you), while the camp sweep is free. **The
   camp is the clean kill; the village is the war.** No meter — the cost surfaces later as the ville
   going quiet when you walk in.

## 6 · How does he know BEFORE he starts? (the r4bk answer, three layers)

1. **On arrival — the point man names the verb.** Reuse `rebark_patrol()`. Village: *"Ville up ahead.
   Watch for holes — they always got a hole."* Camp: *"Camp. There'll be a tunnel in the middle of
   it."* This is the pre-teach, it is a voice not a UI, and ADR-029 explicitly permits the repeatable
   point-man bark. **It teaches the noun ("holes") before he ever sees one.**
2. **At the object — the world prompt.** `HOLD [E] — SATCHEL THE HOLE`, on the mouth. This is the layer
   whose absence caused the entire complaint.
3. **On the map — he can re-ask.** `topo_map.gd:139` already re-triggers `rebark_patrol()` when the
   sheet is opened. That is a beautiful existing affordance: **the map is where you ask "what are we
   doing," and the point man answers.** It costs nothing and it means the player is never stranded
   without a legal way to re-request orientation.

**Layers 1 and 3 already exist as machinery.** The genuinely new work is layer 2 plus the satchel.

## 7 · If only one thing ships

**The tunnel prompt + the satchel verb + the cold toast.** That alone converts "couldn't do anything
about it" into a verb, and gives one legible end-beat. Wildlife return and the arrival bark are the
polish that make it *feel* diegetic rather than *be* legible — high value, second priority.

---

# PART TWO — SHORTER RULINGS

## Item 7 — squad nameplate

Range/cone are LOCKED and I am **not** asking to widen them. My honest report on how 5.0 m / 12° will
feel, as requested:

**It will feel correct, with one failure mode that must be handled.** 12° at 5 m is a ~1 m radius
circle — a man-sized target, so acquiring one deliberately is fine and reads as *"I looked at him,"*
which is the intended CoD-classic feel. The failure is **two squadmates standing close** (which is
constantly true in a file or at a halt): both inside the cone, and the plate flickers between them.

- **Ruling: exactly ONE plate, ever.** `_find_looked_at()` (`squad_nameplate.gd:67-89`) already picks
  min-angle-with-LOS. Keep that, and add hysteresis: the currently-shown man keeps the plate until
  another beats him by a real margin (~3°). Flicker, not the cone, is what will feel bad.

**Anchor height: `ally.global_position + Vector3.UP * 1.95`.**
`global_position` is FEET; `TARGET_HEIGHT_M = 1.7132` is head-top (ADR-002, `model_actor.gd:18`).
1.95 puts the plate ~0.24 m of clear air above the head — enough to clear a boonie hat/helmet and read
as a *label about him* rather than a hat *on* him. Do not reuse the existing `TORSO_OFFSET = 1.35`
(that lands mid-chest) and do not reuse `_update_markers`'s `+3.0` (that is a distant-squadmate
chevron floating well overhead; at 5 m it would sit off the top of the screen).

There is **no head bone marker on AllyBase** — do not add a BoneAttachment3D for this. A fixed
1.95 m offset from feet is correct and cheaper; a bone-tracked plate would bob with the walk cycle,
which is noise, not fidelity.

**Projection:** copy the house pattern verbatim (`mission_hud.gd:254-283`) — `cam.is_position_behind()`
guard, then `cam.unproject_position()`, then `label.position = screen - Vector2(size.x * 0.5, 0)`.
Reparent under a `PRESET_FULL_RECT` Control like `_marker_box` (`:35-38`). The root cause is known
(`:22` preset on a zero-size Control); the fix is to stop trusting the preset, as every sibling
already does.

**Should it scale with distance within 5 m? NO.**
Constant screen-space font size. Reasons: (a) the projected delta across 1–5 m is small enough that
scaling reads as jitter, not depth; (b) a plate that swells as you close is the single most
recognizable MMO/arcade tell and it is straight against Pillar 2. **But do fade alpha** — full at
0–3.5 m, linear to 0 at 5.0 m. `FADE_SPEED = 12.0` already exists; keep it. **Pop is UI. Fade is
atmosphere.**

**Content: one line, `RANK LASTNAME` — e.g. `SGT MILLER`.** No background box, no health bar, no
icon, no role line at this size. Small, dim olive, slight dark outline for legibility against jungle.
Pillar 4 says the squad is the RPG, and the *name* is the relationship — that is all the plate owes.
Keep the RTO's hot-orange tint (`:58-61`): it is the one piece of tactical information that is also
characterization, and `_radio_check()` requiring a living RTO within 10 m (`field_director.gd:294`)
makes knowing which man he is genuinely load-bearing.

## Item 4 — flinch / death theater

**What must the player feel, in one sentence:** *the man's body changed shape because of where I hit
him.*

Note the recon on this: **the player-side confirmation already ships** — `hud.gd:239-269` gives a
crosshair X plus a pitched audio tick on every hit. So the missing thing is **not** feedback that a
hit registered. It is that **the victim does not react**, so the world does not corroborate the HUD.
Right now the crosshair says "hit" and the man stands there. That contradiction is worse than no
feedback at all, and it is why hits feel unbelievable.

**Minimum viable presentation, in priority order:**

1. **The body moves.** Procedural spine punch — impulse on the spine bone away from the shot vector,
   decaying over ~0.25 s. **Reuse the existing 0.25 s fire stall window** (`enemy_base.gd:2159-2161`)
   so it needs no new timing state; the stall is already the flinch, it just has no body.
   I **endorse the procedural route** over clips (`ANIM_WISHLIST.md:16,57`), on design grounds not
   just art-debt grounds: a clip library needs 4 directions × 5 hitzones and *still* snaps to the
   nearest bucket, while one impulse is exactly right for every angle and scales free. `last_hit_dir`
   is already stored (`:2116-2122`). Precedent exists — `severed_bones_modifier.gd:10` is a shipped
   `SkeletonModifier3D`; the ordering constraint (after `PhysicalBoneSimulator3D`) is already solved
   there.
2. **Blood at the hitzone, direction-aware.** `GunFX.blood()` (`gun_fx.gd:329`) already exists with a
   24-decal cap. Just aim it at the zone that was hit.
3. **Death carries the bullet's momentum.** `_die()` (`:2375-2398`) already passes `last_hit_dir` into
   `start_ragdoll`. Ensure the impulse is applied **at the hit point**, not at the root — that one
   change makes a death read as *caused by my shot* instead of *he fell over*, and it is nearly free.

**Cuts, stated plainly:**
- ❌ **Do not author `death_from_the_left`** or any new death clips (`ANIM_WISHLIST.md:12`).
- ❌ **Delete the 0.1 s red flash** (`:2124-2131`) once 1+2 land. It is an arcade tell that exists only
  because the body did nothing; keeping both stacks two languages for one event, and the flash is the
  less truthful one. This is the fossil-law cleanup that makes the change *shipped* rather than added.
- ❌ **Delete the dead `"flinch"` → `rifle_aiming_idle` entry** (`sprite_state_map.gd:138`). Nothing
  emits it; it is a lie in the map.
- ⚠ Flag for a later council, not this one: the crosshair X hitmarker is itself a Pillar-2 tension in a
  game this hardcore. Out of scope today.

## Item 1 — honest fire support budget

**Recommended budget: `{"mortar": 3, "arty": 1, "spooky": 0, "napalm": 0, "bombs": 0, "cbu": 0}`**

Justification, item by item:

- **Mortar 3.** The player walks out the wire of *his own firebase*. The firebase's 81 mm tubes are
  the one asset that is diegetically, unambiguously his — that is what a firebase is *for*. Mortar is
  correctly the plentiful verb, and `_run_mortar_mission` already delivers 3 rounds (+1 at FO 5), so
  three missions is a real capability without being an answer.
- **Arty 1.** A 105 battery belongs to somebody else; you are asking a favor. One charge already means
  a **six-round fire-for-effect** (`:246-254`), two of which deform terrain. That is enormous. One.
- **All air = 0, by default.** A foot patrol 400 m outside its own wire does not get a Skyraider,
  an F-4, CBU, or Spooky on demand. Aircraft require a request up the chain, weather, and something
  already on station. Zero is not a nerf — **it is the honest answer**, and it protects the moment
  when air *does* arrive.

**The UX ruling that matters more than the numbers:** the fire panel currently renders **all six rows
always**, dimmed at zero (`mission_hud.gd:81-109`). Five dead rows out of six is what the owner
actually hit, and injecting budgets does not fix it — it just makes four dead rows. **The net must
list only what you have.** Two live lines (`MORTAR x3`, `ARTY x1`) is a working radio. Six lines with
four crossed out is a broken promise rendered at 60 fps. When air later unlocks situationally
(escalation, a shaped moment), the row **appears** — and an option arriving is a *beat*. A row
un-greying is a patch note.

**Against Pillar 3 (must not become the optimal loud strategy):**
The economy already prices this and needs no new gate. ADR-006: kills pay zero, and **−25 per contact
detected**. A fire mission means the contact is detected *by definition* — every call you make is
already scored against you. The player who mortars every camp is choosing to earn less, freely and
legibly. **That is Pillar 3 working exactly as designed: priced, never forbidden.** No mechanic should
gate the radio.

**Against ADR-006 more specifically:** because avoidance is where the money is, a 3+1 budget lands in
the right place — too small to be a strategy, big enough to be a genuine way out when you are pinned,
which is Pillar 5 (fail forward). The correct throttle on mortar-spam is **the delay and the danger**
(3.0 s spot round, 4.0 s to first arty round, `_cas_cooldown` 10–25 s), **not a smaller number.** Time
is the tax that makes fire support feel like a decision; scarcity alone just makes it feel stingy.

**Refresh: per excursion, on crossing back inward through the wire.** ADR-029 §5 already makes the
inward crossing the commit point (patrol AAR, gate re-arms). Resupply riding that same event is free,
diegetic, and needs zero UI.

**Two defects to fix alongside, both Pillar-5:**
1. `_danger_close_to_squad` (`:319-328`) iterates squadmates and **never checks the player.** The
   shipped design is already right — warn (`DANGER_CLOSE_M = 45`) and require a 5 s same-key confirm,
   but **allow it**. The player must be able to kill himself with his own mortars; he must not be able
   to do it *without being told*. Add the player to the check; do not add a hard block.
2. `cbu_strike` and `place_claymore` collide on physical keycode 54 (`project.godot:146-149` vs
   `:191-194`). Since CBU is budgeted 0 and unavailable in the slice, **give the key to the claymore**
   — the verb the player actually has beats the verb he does not.

---

# SUMMARY OF RULINGS

| # | Ruling | Authority |
|---|---|---|
| 2 | **A report is not a rail.** Transient toast + bark legal; persistent tracker forbidden | ADR-029 §4 (permits gate toast + bark) |
| 2 | Diegetic signal = **the wildlife bed returns** + point-man bark + one toast | Pillar 2; `game_world.gd:230` |
| 2 | Verb = **hold-to-satchel the tunnel mouth**, armorer's-bench pattern, world Label3D prompt | `GAME_GUIDE.md:262` ("MOUTHS you mark and satchel are IN SCOPE TODAY") |
| 2 | **No** `mission_state`. World-state + `set_meta`. **Delete the objective API** as a fossil | ADR-029 §7 + ADR-023 |
| 2 | No inventory item, no charge counter, `demolitions` ungated this bundle (later: shorter hold) | r4bk; ADR-018 |
| 2 | Village = SWEPT (tunnel only, **completable with zero kills**, sentiment cost); Camp = CLEARED | Pillar 3; ADR-006; ADR-019 |
| 2 | Persistent record goes on the **topo sheet as a decaying OBSERVED mark**, never the HUD | ADR-022 |
| 2 | Pre-teach via arrival bark; re-ask via the map (`topo_map.gd:139`, already exists) | r4bk; ADR-029 §4 |
| 7 | Anchor **feet + 1.95 m**; **no distance scaling**; alpha fade 3.5→5.0 m; one plate w/ hysteresis | ADR-002; Pillar 2/4 |
| 7 | 5 m / 12° will feel right — **flicker between adjacent men is the real risk**, not the cone | reported as asked, not widened |
| 4 | The gap is the **victim's body**, not player feedback (hitmarker already ships) | `hud.gd:239-269` |
| 4 | **Procedural spine punch** in the existing 0.25 s stall; ragdoll impulse at hit point; kill the red flash | ANIM_WISHLIST; ADR-023 |
| 1 | **mortar 3 · arty 1 · all air 0**, refreshed at the inward wire crossing | Pillar 3; ADR-029 §5 |
| 1 | **The net lists only what you have** — dead rows are the actual defect | r4bk |
| 1 | Loud is priced by −25/detected, never gated. Throttle with **delay**, not scarcity | ADR-006; Pillar 3 |
| 1 | Add the **player** to danger-close (warn, don't block); give key 54 to the claymore | Pillar 5 |

## What I would cut if the bundle is too big
Cut, in this order: the wildlife return (keep bark + toast), the arrival pre-teach bark, blood
direction-awareness, the nameplate hysteresis. **Do not cut the tunnel world prompt** — it is the
entire complaint.

## Biggest risk in my own recommendation
The cold condition depends on "no living hostiles," and Item 3's recon says garrison men beyond
120 m **are not spawned at all** (`lazy_group.gd:8`). If "cold" is computed against units that never
materialized, a location will report cold while men wait unspawned in it — the exact illegibility we
are fixing, wearing a new hat. **The cold check must run against the site's own garrison roster, not
against live nodes**, and this council must not ship Item 2 without reconciling it with Item 3.
