# THE DECREE — The Living Fight: CoD-2000 Techniques on Honest Finite Bones (2026-07-11)

**Session:** analysis_cod2000 · Architects: game_designer, systems_designer, anim_director, devils_advocate
**Arbiter synthesis.** Composes with the standing AI-goals decree (`synthesis_ai_goals.md`, 2026-07-10) —
extensions and amendments are flagged explicitly in §4.

---

## 1 · The Query

How did CoD 1 / United Offensive / CoD 2 (and the MoHAA/RTCW lineage they came from) build the sense of
a LIVING FIGHT around the player — AI behavior, animation usage, scripted-vs-systemic events, audio and
chatter, tracer discipline, squadmate theater — and how do we adapt those techniques into RECONgame's
open AO with FINITE enemies, where the Summoner has decreed:

- **REJECTED outright:** CoD's forward-locked flow — invisible advance lines feeding respawn faucets.
- **DECREED as feature:** sometimes you kill them all and the AO goes eerie and quiet until you move on.
  The quiet is Pillar 2 working. Punctuation comes from ambushes, villages, boobytraps, patrols —
  never from a spawn faucet.

**The council's unanimous thesis (ratified):** CoD's living fight decomposes into three factors —
(a) systemic AI behaviors *our doctrine already exceeds* (cover-first, bounding, flanking, grenade
broker, suppression, smoke-to-advance), (b) a **presentation layer we do not have** (battle chatter,
tracer legibility, death/flinch theater, audio states), and (c) a **density guarantee we refuse**
(respawn faucets, ally mass, forgiving damage). Two of three factors are cheap and fully compatible
with finite enemies. We are not building CoD-minus-respawns; **we are building CoD's presentation on
Arma's honesty, and the quiet is the payment that makes the loud believable.**

The devil's advocate's reframe is ratified as doctrine: CoD staged *the FIGHT around you*; our fiction
(5-man recon patrol, 45–90m jungle sight cap, HLL lethality) demands *the WAR around you at a
distance* — audio, radio, distant light — while YOUR fights stay small, sudden, and personal.

---

## 2 · The Judgment

Each point marked **SYSTEMIC-NOW** (build in the coming waves, after §2.0's gate),
**SYSTEMIC-LATER** (ratified, sequenced behind NOW items or a dependency), or **REJECTED** (with why).

### 2.0 — The Sequencing Gate *(process law, binding)*
Nothing in this decree ships before standing build-order items **#1 (witness-rule bug o18o)** and
**#2 (trust-restoration perf day: rendering_method A/B, MAX_THINK_TIME actually wired at
enemy_base.gd:211, gating FPS number)**. Detection-driven ambience on a lying detection core is
decoration on a broken machine; aliveness features at 19–25 FPS is drift. This is not new law — it is
GAME_GUIDE §8 restated so no bead from this decree jumps the queue.
**Second gate (game_designer, ratified): presentation before punctuation.** The quiet reads as a bug
until barks, tracers, and the settle ritual exist. Blocks C (quiet) and D (punctuation) land only
after Block B (presentation) is playable.

### 2.1 — Bark System v1: state-transition battle chatter, both factions — **SYSTEMIC-NOW**
CoD2's Battle Chatter System is the single proven multiplier of perceived AI life (20k lines, ~8% of
budget; "smarter" reviews came from the *voice*, not the brain). Ours is a presentation adapter on
signals that already fire:
- **Triggers (all existing seams):** `_set_tier` transitions (SUSPICIOUS = query bark, ALERT = warning
  shout, COMBAT = contact scream), `_set_goal` adoption of FLANK_TARGET/ADVANCE (MISSION_DESIGN_RESEARCH
  §5.6 already *requires* "vocalize before flanking" — unimplemented until now), grenade broker
  (throw + incoming), confirmed kills, reloads, casualties ("Doc! Man down!"), morale breaks and rout.
- **Broker rules:** one voice per faction within earshot; priority ladder (casualty > incoming grenade >
  new contact > movement > flavor); per-man + squad cooldowns; **personality-weighted selection** —
  LOW courage complains, HIGH courage calls targets. The standing decree's personality spectrum
  becomes *audible*.
- **Contact calls carry real information** derived from the *believed* position (never true transform —
  honest attention preserved): compass octant + range band.
- **Text-subtitle-first is law (r4bk-compliant):** the system ships on the existing 162-line VO pool +
  subtitles for uncovered contexts. No recording treadmill gates the feature.

### 2.2 — Enemy chatter in-language — **SYSTEMIC-NOW** (triggers) / content ongoing
Vietnamese line-classes on the same broker: alert calls, flank orders, grenade warnings ("LUU DAN!"
already ships), rout screaming, and — the dread special — **calm unalerted chatter** from RELAXED-tier
camps heard before they know you exist. Players who learn the enemy's language gain a real skill layer
(CoD2's "Achtung! Granate!" mechanic, historically resonant for Vietnam).
**HUD grenade indicator: REJECTED** — the diegetic shout channel is already chosen and shipped; an ally
"grenade! get down!" callout covers the fairness floor. Sacrifice named: guaranteed legibility of every
frag. Bought: the learn-the-language mechanic.

### 2.3 — BCS-lite landmark-CLASS callouts — **SYSTEMIC-LATER**
The conflict: systems_designer wants generator-named geometry callouts; devil's advocate names the
line-count explosion as the #1 solo-dev trap. **Resolution — class nouns, not instance names:** the
generator tags placed geometry with a CLOSED taxonomy of ~12 landmark-class nouns (hooch, dike,
treeline, trail, paddy, wreck, rocks…); barks resolve `{enemy} {octant} {landmark-class}` via template
grammar; **subtitle always, VO only when the existing pool has a matching wav.** Landmark-INSTANCE
lines ("the granary, second floor") are **REJECTED** — that is the treadmill. Sacrifice named: bespoke
per-location specificity; the template gets ~80% at ~1% cost.

### 2.4 — Tracer discipline + MG grazing lanes — **SYSTEMIC-NOW**
Tracers are the battle's UI — legible light geometry showing where fire originates and which lane kills.
- Per-weapon `tracer_ratio` + `tracer_color` in WeaponData: MGs (RPD/M60) trace every round or 1:4 —
  they are the battlefield's light architecture; rifles ~1:5–1:7; SKS/Mosin/bolt guns dark; ComBloc
  green vs US red (historically grounded, instant night IFF). Replaces the hardcoded every-round green
  in `_fire_at_target` (enemy, ally, and player paths for parity).
- **Every tracer comes from a real fired shot.** No decorative fire, ever.
- MG suppress behavior gains a **beaten-zone sweep**: fire at believed position ± slow traverse,
  deliberately high when target is unseen (grazing fire). CoD's overhead-tracer moment made systemic —
  it happens wherever an MG loses sight of a target near cover.
- ⚠ This AMENDS the Fairness Law's telegraph wording — see §4 Amendment 1.

### 2.5 — Animation battle theater (the anim_director block) — **SYSTEMIC-NOW** (S items) / **LATER** (M items)
The verified CoD-2000 architecture (GSC animscripts over a big library, ~0.1s blends, one clip at a
time) is exactly what ModelActor already is. All sophistication goes into SELECTION, none into new tech:
- **One-shot latch plumbing (NOW, enabler, do first):** `ModelActor.play_one_shot()` + latch in both
  factions' `_update_sprite`; death/surrender always override. ~30 lines; unlocks everything below.
- **Death selection matrix v2 (NOW — highest feel-per-line in the project):** stance × direction ×
  hit-zone × no-repeat cycling (CoD's death.gsc verified pattern). Six matching death clips already sit
  in anim_library.glb while `_die()` uses two. Finite enemies make death variety MORE valuable per
  corpse than CoD's corridors — the player watches every kill.
- **Procedural flinch (NOW):** ~40-line `FlinchModifier extends SkeletonModifier3D` (same pattern as
  shipped SeveredBonesModifier) — decaying spine punch, direction from `last_hit_dir`, amplitude
  damage-scaled, anti-stunlock caps. Makes the ~80% of hits that are currently an invisible fire-rate
  stall visibly land (Pillar 1). Truly additive over any clip; never touches the intent funnel.
- **Death-clip→ragdoll handoff (LATER, M):** first 0.3–0.5s of authored acting, then `start_ragdoll` —
  slopes, dikes, and paddy water resolve truthfully where canned falls would clip (the problem CoD's
  flat authored maps never had). Headshot/crouch deaths keep full clips; over-ragdoll-budget falls back
  to full clip.
- **Stumble & wounded crawl, grenade-dive, cover-arrival theater (LATER, S–M):** `falling_to_roll`,
  `jump_away`, `stand_to_cover`×3 / `cover_to_stand`×2 — all clips already on the shelf, rate-limited
  to stay flourishes.
- **Ambient-life set for the quiet (LATER, S):** unalerted camps rotate `idle_unarmed`×5 / `sitting` /
  `walking_unarmed` per-man (seeded habit) — what the player studies through binos before choosing the
  ambush; allies drop to weapon-low idles + treeline scans in the lull.
- **AnimationTree wholesale migration: REJECTED** as a prerequisite. Wrong problem — the era's feel
  came from selection scripts, and Godot's MIX_MODE_ADD needs delta clips Mixamo doesn't provide. The
  narrow partial-layer recipe (OneShot BLEND + bone filters) stays a deferred v2 track.
- **Law of the treadmill (devil's advocate, ratified):** no proposal may require a new animation clip
  per event type. Existing clips only; Caleb's Mixamo wishlist (death_from_left, directional
  hit-reactions, crawl loop) upgrades quality later without gating anything.

### 2.6 — Emplaced MG archetype: "the pin" — **SYSTEMIC-LATER** (after perf day)
CoD's best single mechanism and the most transplantable: anchored gunner (leash ≈ 0), SUPPRESS_TARGET
dominant, sweeps a beaten zone at last-known, sustained tracer stream, exposure-ramped accuracy
retained (survivable by doctrine — a pin, not a killer). Its counter is *routefinding*, which is
Pillar-3 freedom made legible. New EnemyData archetype; no new perception work.

### 2.7 — The Honest Quiet (the anti-CoD block) — rule **SYSTEMIC-NOW**, components staged
The quiet is a feature only if it is *legible as aftermath* and *never certain*:
- **Honest-Silence Rule — decreed as a Fairness-Law EXTENSION (see §4):** in-AO ambient threat tells
  (wildlife silence, rustle) fire ONLY from real enemy state (implements bead r6qe). Phantom noises,
  random fauna silence, fake in-AO gunfire: **REJECTED** — dishonest tension fakery trains players
  that tells are noise and kills the tell economy. Out-of-AO war flavor is exempt (it promises nothing
  about your AO).
- **Wildlife/ambience director (LATER, M):** gunfire silences fauna 2–5 min; birdsong returning IS the
  "all clear" — no UI ever says "area secure." **The inversion is the killer feature:** fauna also
  quiets near *moving enemies*, so silence carries information both ways — walking into a
  going-quiet treeline teaches you to stop. Legal under the Honest-Silence Rule because it is driven
  by real enemy state.
- **Last-man-confirmed quiet (NOW, S):** MissionDirector keeps per-pocket ledgers; on exhaustion a
  delayed squad bark ("think that's the last of 'em… I think") — the squad *believes*, the player
  verifies. Uncertainty is the tension. No remaining-enemy counters, no mid-mission clear toast;
  debrief-only stats stay legal (ADR-006).
- **Post-contact settle ritual (NOW, S–M):** CONTACT → CONSOLIDATE (ammo checks, "anyone hit?", medic
  attends, outward scans) → SETTLE (murmurs, one personality-driven line about the dead) → PATROL
  QUIET (whispered barks only). The lull gets choreography — men who just fought, not NPCs out of
  script.
- **Silence budget (systems_designer, ratified as hard rule):** after a pocket is exhausted, minimum
  **90 seconds** of ambient-bed-free wildlife-silence before any distant-war layer may return. Every
  living-fight technique is a noise generator; the eerie quiet is authored by contrast, never filled.
- **The lull is an activity space (LATER):** every combat pocket leaves residue — bodies to search
  (finite-inventory scavenge, already decreed), intel that reveals patrol routes/trap clusters,
  wounded to treat, a calm map check. The player ends the quiet by moving — the Summoner's exact words.

### 2.8 — Shellshock / adrenaline audio state machine — **SYSTEMIC-LATER** (S)
NORMAL → SHELLSHOCK (explosion <8m: muffle, ring, 2–4s — CoD1's single highest-value "I'm in a war"
effect) → COMBAT-NARROW (heartbeat under sustained suppression) → **DECAY** (ears reopen over ~20s).
The DECAY state is the bridge into the quiet: the world coming back to your ears is the lull's opening
note. Pure audio/post-FX; no AI work. Dynamic light caps per devil's advocate (1 flare light; muzzle
flashes as unlit sprites).

### 2.9 — Music doctrine: silence is the score — **RATIFIED-NOW** (doctrine, near-zero cost)
CoD's own choice radicalized: **no combat music loops, no adaptive intensity bed.** Stingers ONLY at
mission-graph nodes (insertion touch-down, exfil called, boarding dash) — the only honest authored
moments a generated mission has. Diegetic radio music (AFVN) at the firebase and on captured enemy
radios: music playing = you are somewhere safe or somewhere enemy. iMuse/Halo-style adaptive layering:
**REJECTED** — documented as considered-and-rejected; it would fill the silence that is the game.

### 2.10 — War-at-a-distance: seeded schedule, not a director — **SYSTEMIC-LATER** (M)
The conflict: an "ambient combat director" is a stealth thaw of the FROZEN battle-director epic
(GAME_GUIDE §6). **Resolution — the devil's advocate's shape with the systems_designer's budget:** the
generator rolls, at briefing time, a SEEDED timeline of out-of-AO war events (distant H&I arty, far
firefight swells, a flare over a far treeline, Hueys crossing) + matching RTO radio traffic about
*other units*. Static data consumed by a dumb player — no runtime brain. The radio net is our midfield
theater: CoD faked a 500m soundstage; our radioman makes it true at audio prices. Density is a mission
parameter, suppressed near cleared/quiet state, and always subordinate to the 90s silence budget.
**Runtime ambient-battle director: REJECTED** (frozen epic; a bead is not a thaw).

### 2.11 — Reinforcement honesty (the anti-faucet rules R1–R5) — **SYSTEMIC-NOW/LATER** per item
CoD's faucet decomposes into four lies (kill lie, geometry lie, teleport lie, pacing theft). Each gets
its honest counterpart, ratified as the reinforcement doctrine:
- **R1 — Population is a ledger, never a faucet** (already law; restated): AO budget fixed at
  generation (~30–55 men: garrison pockets, roving patrols, QRF pool). Every kill is bankable.
- **R2 — Escalation keys to WITNESS STATE, never player position:** each escalation increment requires
  a witness event (surviving COMBAT witness, runner reaching a radio, alarm object). No witness, no
  draw on the pool. Silent kills stay cold; unreported patrols raise delayed, bounded suspicion — not
  psychic alarms. (Extends the detection beacon; composes with bead pwu5.)
- **R3 — QRF arrival honesty (NOW, M):** reinforcements enter at map edge / road head / known enemy
  structure as a traveling squad with moving leash, **audible 20–40s before contact is possible**
  (truck engine, chatter, signal flare). Replaces the player-centered spawn ring at
  `mission_director.gd:87-96` — the current ring is CoD's geometry lie slowed down. ⚠ AMENDS standing
  decree point 10 — see §4 Amendment 2.
- **R4 — Radios and alarms are physical, killable, and CAPPED (LATER, L — the pillar-critical epic):**
  each camp owns at most one summon source (radio hut, field telephone, flare NCO) with a bounded draw
  on the pool (radio ≤2 QRF squads, flare = +1 patrol redirect). Kill the radio before the runner
  transmits → that cap is spent silently. "Race the runner" becomes real strategy; when the pool is
  empty or all sources dead, the AO goes quiet **forever** — escalation-not-fail-states made mechanical.
- **R5 — The quiet must be diegetically confirmed** (= §2.7 last-man bark + fauna return).
- **Pocket wake choreography (NOW, S):** dormant garrisons wake staggered 0.3–1.2s with barks and
  cover scrambles, not synchronized combat entry — the camp visibly *comes alive*. Pure jitter + P1
  barks + existing cover-first doctrine.
- **Squad probe response (LATER, M):** a pocket hearing distant priority-≥6 noise dispatches a 2-man
  probe while the rest anchor — CoD2's "distant groups send investigators," also authentic VC practice.

### 2.12 — Punctuation: the contact deck, then the systemic ambush — **SYSTEMIC-LATER** (phased)
The conflict: game_designer specs a full systemic enemy-initiated ambush system (L); devil's advocate
insists punctuation lives in the existing contact deck, not a new system. **Resolution — phase it:**
- **v1 (M):** ambush as generator deck weights + a prefab event-block from existing clips
  (L-shape placement at generator-tagged chokepoints, hold-fire-until-kill-zone, MG opens). Sharpen
  deck weights for ambush/boobytrap/patrol cadence per canon §4.6 + escalation ladder.
- **v2 (L, the real prize):** enemy-INITIATED systemic ambush with honest preconditions — (a) knowledge
  of player heading (alarm state / escaped spotter), (b) setup time ≥60–90s ahead of projected trail
  arrival, (c) ambush-rated geometry tagged at AO build time. Because it is condition-driven it can
  fire in a zone the player cleared an hour ago — **that single fact keeps the quiet honest forever.**
  Counterplay: point-man detection, fauna silence, moving off-trail (slower, safer — the core Vietnam
  dilemma). The "enemies read fauna silence too" flourish is CUT (speculative, scope).
- **Boobytrap grammar (M):** `punji_trap.gd`/`claymore.gd` exist; add placement grammar (trails and
  likely approaches near enemy zones, never random open field) + **every trap has a tell** — disturbed
  earth, line glint, and the historical VC own-side markers (bent bamboo, stone cairns): a learnable
  language. Point-man skill = detect radius; wounds over kills where possible (Pillar 5 — a leg wound
  is a drag-to-cover story, not a reload).
- **Patrols with errands (M–L):** finite patrols walk the trail graph with purposes (resupply, water
  detail, LP/OP relief, post-alarm sweep) — schedules and destinations mean a cleared zone can be
  *re-entered* by business, not respawned into. Killing a resupply patrol drops that camp's ammo
  budget (completion-changes-world).
- **Villages as encounter decks (L, furthest out):** generator-rolled states (normal life / VC hiding /
  VC-controlled / abandoned-and-trapped) with observable tells from the overwatch ring (cooking fires,
  who's in the paddies, whether children are visible). Civilians are CoD's dying extras transplanted
  honestly — they flee, and full-realism FF makes fire discipline mechanical. Composes with the
  optional-village-clear already in build-order #1.

### 2.13 — Consolidated rejections (Law 2: each names its sacrifice)
1. **Respawn faucets / advance-line spawning / forward-locked flow** — Summoner's verbatim rejection +
   RTCW's shipped verdict + finite-pool canon. *Sacrificed:* guaranteed intensity density; the promise
   that every minute is loud. Accepted willingly; Pillar 2 buys it back.
2. **Invincible named allies** — violates Pillar 4 (deaths are the stakes) and roster permadeath.
   *Sacrificed:* an unkillable readability anchor; barks + role identity carry it instead.
3. **Color-group ally shepherding / progress-triggered staging** — violates player-paced squad doctrine
   and Pillar 3. *Sacrificed:* perfectly composed squad staging; the personality spectrum + orders
   substitute.
4. **Player threat bias** — already rejected by honest attention; CoD needed it because allies were
   immortal props.
5. **Volume-of-fire at the player** — CoD's bullet-storm depends on forgiving damage; at HLL lethality
   it kills the player or makes enemies liars. The storm aims at lanes, cover, and allies.
6. **Ally-mass theater / front lines / camera-aware staged spectacle** — no front exists in an open AO;
   5 men are not a company; jungle sight caps make staged spectacle unwatchable. Our spectacle is audio.
7. **20,000-line VO ambition & landmark-instance chatter** — the solo-dev content treadmill.
   Template grammar + subtitles instead.
8. **HUD grenade indicator** — the diegetic shout is the mechanic (see 2.2).
9. **CoD's flat permanent-ALERT alertness** — our RTCW/MoHAA tier ladder is strictly superior for
   stealth-optional play; keep ours.
10. **Runtime ambient-battle director** — FROZEN epic (GAME_GUIDE §6); seeded schedule instead.
11. **Dishonest in-AO tension fakery** (phantom rustles, random fauna silence, fake AK fire) — kills
    the tell economy the Fairness Law depends on.
12. **AnimationTree migration / modern layered procedural reactions** — wrong era, wrong art direction,
    destabilizes the just-shipped funnel for zero era-authentic gain.
13. **Wall-to-wall bombast (UO mode) & adaptive music layers** — would spend the loud and fill the
    silence that is the game.

### 2.14 — Instrumentation before content — **SYSTEMIC-NOW** (process law)
Log time-since-last-stimulus (contact, bark, radio beat, trap tell, trace discovery) in playtests.
Fund additional valley content ONLY against measured dead air (median >~2–3 min). Do not pre-build for
a boredom nobody has measured. The quiet's half-life is a hypothesis to test, not a decree.

---

## 3 · Tradeoffs Named (Law 2 — the sacrifice ledger)

1. **Dud stretches WILL happen.** Finite honest enemies + open AO = some missions where a player clears
   early and walks 20 quiet minutes, or the generator rolls a sparse corner. We accept variance as
   fail-forward texture. Every mushy-middle "fix" — runtime ambience director, fake tension noises,
   ally-mass theater — is the respawn faucet wearing a mask, and it is refused by name.
2. **Spectacle-on-cue is gone.** Systemic events fire whether or not the player watches; in jungle they
   are usually unseen. Our spectacle is audio-first (radio, distant arty, tracer light).
3. **Pacing guarantees are gone.** The generator validates layout; it cannot control mid-mission player
   behavior. No R-curve runtime enforcement.
4. **The army-around-you feeling is gone entirely.** Reframed as the war-at-a-distance, never faked.
5. **Location-specific chatter is sacrificed** for a bounded landmark-class template grammar (~80% of
   the effect at ~1% of the cost); subtitles cover what VO cannot.
6. **Rifle-tracer sparsity trades telegraph redundancy for readability** — bolt guns go dark; muzzle
   flash + report + near-miss crack remain the guaranteed telegraph (Amendment 1 makes this legal).
7. **Procedural flinch is a jolt, not authored acting** — accepted at PSX fidelity; buys the feel a
   full clip-authoring cycle earlier. Directional hit-reaction clips upgrade it later.
8. **Ragdoll-handoff deaths settle ~1s slower** than snap clips — atmosphere at HLL lethality, held
   inside existing budgets (8 ragdolls, 45s corpses).
9. **Every one-shot anim is a window where the intent funnel is deaf** — bounded by death/surrender
   precedence, ≤0.7s reaction clips, and flinch living outside the funnel entirely.
10. **The silence budget means built audio content deliberately does not play** near cleared state —
    we are paying for assets we intentionally suppress. That suppression IS the atmosphere pillar.
11. **P7 ambient-life clips dress men the player may never fight** — that is the point (recon through
    binos is gameplay), but it adds RELAXED-tier intent surface to test.
12. **The quiet can still bore.** If instrumentation (2.14) proves median dead air beyond tolerance,
    the remedy is contact-deck density tuning at generation — never a runtime faucet.

---

## 4 · Composition with the standing AI-goals decree (2026-07-10)

**Nothing in this decree contradicts the standing doctrine.** It is a presentation and world-structure
layer on top of it. Explicit accounting:

### EXTENDS (no change to standing text)
- **Doctrine 1–4 (contact confidence, dwell, cover phase, dispersion):** untouched. Bark triggers READ
  tier/goal transitions; they never influence them.
- **Doctrine 7 (personality spectrum):** barks make courage/skill audible (complaints vs target calls).
- **Doctrine 8 (enemy morale):** rout gains its reward-sound (screaming, thrown weapons audible).
- **Doctrine 9 (full-realism FF):** civilian presence in villages (2.12) leans on the same muzzle
  discipline; no new rule.
- **Grenade broker:** gains outgoing/incoming barks + the `jump_away` dive one-shot.
- **Detection beacon / witness rule:** R2 formalizes escalation increments as witness-gated (composes
  with beads pwu5, o18o); the standing "detection starts escalation" remains, now with honest currency.
- **MISSION_DESIGN_RESEARCH §5.6 "vocalize before flanking":** finally implemented by 2.1 — this
  decree DISCHARGES an existing unimplemented requirement rather than adding one.

### AMENDS (flagged loudly — the only three)
- **⚠ AMENDMENT 1 — Fairness Law telegraph wording (GAME_GUIDE §1).** Old: "muzzle flash / tracers /
  vocalizations always telegraph." New: **"muzzle flash + report always telegraph every shooter;
  tracers telegraph at per-weapon ratios (MGs stream, rifles sparse, bolt guns dark); every rendered
  tracer comes from a real fired shot; vocalizations telegraph per the bark broker."** The guarantee
  moves from *every channel always* to *at least two channels always* — required for tracer discipline
  (2.4) to exist. First-shot-near-miss and exposure-ramp rules unchanged.
- **⚠ AMENDMENT 2 — Standing doctrine point 10 (wave spawns).** Old: "arrivals placed within 3m of a
  cover point, fireteams split ≥12m" (bench rule; live code spawns in a player-centered ring). New:
  **arrivals are world-anchored squad entries (map edge / road node / known enemy structure), audible
  20–40s before contact, traveling as a fireteam with a moving leash; the 3m-to-cover and ≥12m split
  rules apply at the entry point.** The player-ring at `mission_director.gd:87-96` is deprecated by
  this amendment — it is the geometry lie.
- **⚠ AMENDMENT 3 — Standing doctrine point 5 (animation intent policy).** The intent funnel gains a
  **one-shot latch layer** above it: while a one-shot reaction plays, the funnel is suppressed;
  precedence is **death/surrender > one-shot latch > intent funnel**; the 0.25s debounce and
  movement-owns-the-legs policy are untouched. Procedural flinch lives OUTSIDE the funnel entirely
  (SkeletonModifier3D stack, before SeveredBonesModifier). This is an additive layer, not a rewrite —
  flagged because it touches decreed text.

---

## 5 · Actionable work items (priority order)

Gate G0 (standing build order #1 + #2) precedes Block B. Blocks land in order; items within a block
may interleave. Sizes: S ≤1 session · M 2–4 · L 5+.

### Block A — Gates (standing law, not new work)
| # | Item | Size | Files |
|---|---|---|---|
| A1 | Witness-rule bug (o18o) + perf day (MAX_THINK_TIME wired, rendering_method A/B, gating FPS) | — | `enemy_base.gd:211`, per GAME_GUIDE §8 items 1–2 |

### Block B — The presentation layer (CoD's cheap two-thirds; all payoff on existing systems)
| # | Item | Size | Files / hooks |
|---|---|---|---|
| B1 | One-shot latch plumbing (`play_one_shot` + funnel latch, death/surrender precedence) | S | `scripts/visuals/model_actor.gd`, `scripts/enemies/enemy_base.gd`, `scripts/allies/ally_base.gd` |
| B2 | Bark System v1: state-transition triggers both factions, priority broker, personality weighting, subtitle-first | S–M | `_set_tier`/`_set_goal` seams in `enemy_base.gd`/`ally_base.gd`, VOManager, `scripts/squad/squad_system.gd` `_contact_barks()` |
| B3 | Tracer discipline: `tracer_ratio`/`tracer_color` in WeaponData; kill hardcoded green; MG beaten-zone sweep | S | WeaponData .tres schema, `_fire_at_target` (enemy/ally/player paths) |
| B4 | Death selection matrix v2 + no-repeat cycling + new sprite-map intents | S | `_die()` both factions, `scripts/visuals/sprite_state_map.gd` |
| B5 | FlinchModifier (procedural spine-punch, damage-scaled, anti-stunlock) | S/M | new `scripts/visuals/flinch_modifier.gd`, wire in take_damage both factions |
| B6 | Pocket wake choreography (staggered 0.3–1.2s wake + barks) | S | `scripts/missions/mission_director.gd`, pocket wake path |
| B7 | Last-man-confirmed quiet: per-pocket ledgers → delayed squad bark, fauna-return timer hook | S | `mission_director.gd`, `squad_system.gd` |
| B8 | Post-contact settle ritual (CONSOLIDATE → SETTLE → PATROL QUIET squad states) | S–M | `squad_system.gd` on B2's broker |
| B9 | Quiet-boredom instrumentation (time-since-last-stimulus logging) | S | playtest logging autoload |
| B10 | Music doctrine ratification: no combat loops; stingers at graph nodes; AFVN diegetic beds | S | audio_manager + mission graph nodes; mostly a rule |

### Block C — The honest quiet & the audible war
| # | Item | Size | Files / hooks |
|---|---|---|---|
| C1 | Wildlife/ambience director w/ honest-silence rule + enemy-proximity inversion (bead r6qe) | M | new autoload; NoiseBus events; per-biome beds |
| C2 | QRF arrival honesty: map-edge/road squad entry + 20–40s audible telegraph (Amendment 2) | M | `mission_director.gd:87-96` replacement |
| C3 | Shellshock → COMBAT-NARROW → DECAY player audio state machine | S | player audio/post-FX; light caps per DA |
| C4 | War-at-a-distance seeded schedule + RTO radio traffic (briefing-time roll, dumb playback, 90s silence budget) | M | mission_generator (timeline data) + audio scheduler |
| C5 | Ambient-life clip set: RELAXED-tier idle habits (camps) + ally lull idles | S | `sprite_state_map.gd` `intent_for()`, per-man variant index |
| C6 | Grenade-dive + cover-arrival/peek theater one-shots (rate-limited) | S | B1 latch + existing clips, cover state changes |

### Block D — Punctuation (the faucet's honest replacement)
| # | Item | Size | Files / hooks |
|---|---|---|---|
| D1 | Emplaced MG "pin" archetype (beaten-zone sweep, anchored, tracer stream) | M | new EnemyData archetype, `enemy_base.gd` suppress path |
| D2 | Ambush v1: contact-deck weights + L-shape prefab event-block at tagged chokepoints | M | mission_generator deck, generator geometry tagging |
| D3 | Boobytrap grammar: placement rules + tell language + point-man detect radius | M | `punji_trap.gd`, `claymore.gd`, generator placement pass |
| D4 | Squad probe response (2-man investigate, rest anchor) | M | pocket noise response in `enemy_base.gd`/director |
| D5 | Death-clip→ragdoll handoff (0.3–0.5s acting then physics; budget fallback) | M | `_die()` both factions, `start_ragdoll` (currently gore-lab-only) |
| D6 | Stumble & wounded crawl (existing clips; crawl clip wishlisted) | M | B1 latch, `is_crippled` path |
| D7 | BCS-lite landmark-class callouts (12-noun taxonomy, template grammar, subtitle-first) | M | generator tagging + B2 grammar |
| D8 | Patrols with errands (trail-graph schedules, completion-changes-world) | M–L | patrol routes in generator + director |
| D9 | Radio/alarm counterplay + per-source reinforcement caps (R4) — **epic, pillar-critical** | L | radio prop, runner behavior, director ledger bookkeeping |
| D10 | Ambush v2: systemic enemy-initiated with preconditions (knowledge + setup time + rated geometry) | L | escalation state + generator tags + new group behavior |
| D11 | Villages as encounter decks (states + observable tells + civilians) | L | generator village pass; composes with optional village clear |

**Clip wishlist for Caleb (non-gating, value order):** death_from_left · 2–4 directional standing
hit-reactions · crawl loop · gut-clutch death · run-death · crouched blind-fire · prone fire/idle pair.

---

## 6 · The Arbiter's closing word

The council was unanimous on the deepest point: **the quiet only reads as a feature if the loud reads
as alive.** CoD proved the loud is two-thirds presentation — voice, light, and reaction — and those
two-thirds cost us almost nothing because the standing AI doctrine already emits every signal they
need. Build the presentation first, keep every tell honest, cap every noise with the silence budget,
and let the finite ledger do what CoD never dared: end the fight, and mean it.

*Recorded per Law 4. Work items to enter the Graph per Law 5.*
