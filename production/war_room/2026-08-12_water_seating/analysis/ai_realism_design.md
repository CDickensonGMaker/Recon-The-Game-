# GAME DESIGNER — "make the AI read as men, not bots"

**War Room 2026-08-12. Analysis only; no file was edited.** Lens: **what the player PERCEIVES, and
in what order.** Systems correctness belongs to the other two architects — where a system is already
correct and merely mute, I say so and move on.

**Governing constraint (Summoner, mid-session):** *"modern ai thinking with our units with our old
school feeling game."* At PSX fidelity there is no face, no aim tremor, no nuanced blend — those
channels are **deliberately given up** and must not be spent on. What survives the fidelity floor is:

| Channel | Reads at PSX? | Why |
|---|---|---|
| **SOUND** | **Fully — fidelity-independent** | A .wav is a .wav. This is the one channel where RECONgame can match a modern game exactly. |
| **Silhouette** | Yes | Standing / crouch / prone / rout / hands-up are legible at 30m as pure outline. |
| **Position** | Yes | Where a man chooses to stand. In the open vs behind the berm. |
| **Timing** | Yes | The beat before he reacts; the lull; the pause at the bound. |
| Facial / micro-anim | **No** | Do not spend here. |

Everything below is ranked against that table.

---

## 1 · THE BOT-TELLS, RANKED BY HOW LOUDLY THEY READ

Ranked for **this** camera (first person, iron sights), **these** ranges (engage 22–32m; night
56m open / 18m jungle) and **this** lethality (1–2 shots). Ally column weighted heavier per the
Summoner's ruling: his squad is on screen constantly, the enemy is on screen for seconds.

| # | Tell | Ally | Enemy | Channel | Status in RECONgame |
|---|---|---|---|---|---|
| **1** | **Silence.** Men fight, are hit, die and break contact without a human sound. | **CRITICAL** | **CRITICAL** | Audio | **PRESENT — the single loudest defect. See §2.** |
| **2** | **Dying without a voice.** A man drops mid-stride with a body-fall and nothing else. | **CRITICAL** | **CRITICAL** | Audio | `ally_base.gd:1790 _die()` plays **no sound at all**. Enemy tries a pain grunt and it is a **no-op** (§2). |
| **3** | **Never being hurt** — taking a round and continuing the same behaviour. | **HIGH** | Handled | Silhouette + audio | Enemies flinch/stagger/stumble (`enemy_base.gd:2450-2469`). **Allies never flinch — `flinch` has zero hits in `ally_base.gd`** while `FlinchModifier` exists (`scripts/visuals/flinch_modifier.gd`; `model_actor.gd:73`). |
| **4** | **No lull — continuous fire until someone dies.** Nobody runs dry. | HIGH | HIGH | Timing + audio | **AI has no ammunition and never reloads.** `reload` returns **zero hits** across `scripts/enemies`, `scripts/allies`, `scripts/ai`. Confirmed by design comment: *"the skipped round costs cadence, not ammo"* (`enemy_base.gd:2292`, `ally_base.gd:1695`). |
| **5** | **Uniform behaviour across men** — every soldier the same courage, same voice, same tempo. | MED | MED | All | Partly solved: `char_reaction` rolls per man (`enemy_base.gd:385-397`), courage per faction, VO voice stable per speaker (`vo_manager.gd:63,71`). Undermined by #1 — variety you cannot hear is variety you cannot perceive. |
| **6** | **Talking by subtitle.** Squad "speaks" via HUD toast rather than voice. | **HIGH** | n/a | Audio | 20+ `_toast()` calls in `squad_system.gd`; only 9 carry VO, and 2 of those point at files that do not exist. A HUD line is a UI element; a shout is a man. |
| **7** | **Instant, telepathic coordination** — the whole squad turns at once. | MED | MED | Timing | Enemy contact propagates man-to-man with `char_reaction` gating (`enemy_base.gd:1719-1723`). Reads acceptably. Not my top spend. |
| **8** | **No self-preservation / never breaks.** | LOW | LOW | Silhouette | **Already built and good**: courage×pressure×nerve ladder → rout or hands-up (`enemy_base.gd:2498-2525`), `try_surrender()` (`:2840`), `squad_broken` (`squad_system.gd:451-457`), `marching_cell.withdraw_to()` (`:135`). **The behaviour exists; the player just cannot hear it happen.** |
| **9** | **Straight-line movement / engaging from the open.** | LOW | LOW | Position | Bounding advance is real: sprint → `_bound_pause = randf_range(0.8, 1.6)` → 2–3 round burst → next bound (`enemy_base.gd:1866-1935`). Posture ladder ties suppression to crouch/prone (`combat_posture.gd:35-71`). This reads well already. |
| **10** | **No facial reaction, no aim tremor.** | — | — | — | **DE-RANKED TO ZERO. Does not read at PSX. Do not spend here.** |

**Where the factions differ.** The enemy's expression layer is ~70% wired and his *reaction* layer is
rich. The ally's expression layer is ~10% wired: **`ally_base.gd` contains zero `VOManager` calls**
(verified repo-wide grep) — every friendly voice in the game is a *squad-level* event fired from
`squad_system.gd`, on an 8-second cooldown, attributed to `caller = first living member` rather than
the man who actually saw the enemy (`squad_system.gd:640-655`). Since the squad is Pillar 4 and is on
screen permanently, **the ally side is where believability is being lost fastest.**

---

## 2 · AUDIO — THE LEVER, AND IT IS ALREADY PAID FOR

This is the finding. **The VO library is recorded, imported, cast and routed. Most of it never
plays, and the loudest lines are silently broken.**

`vo_manager.gd:10` states the contract: *"Missing wavs no-op silently."* `_load()` caches the miss
and returns null (`:106-114`); `_play_field` early-returns (`:77`). **A typo'd line id is not an
error — it is a permanently silent soldier.**

### 2a · Enemy VO: 5 of 9 call sites fire into the void

On disk (×3 Vietnamese voice folders `vi_vais1000` / `vi_25hours` / `vi_vivos`):
`advance · flanking · grenade · man_down · open_fire · reload · retreat · spotted_us · surrender · taunt`

Called in code (`enemy_base.gd`):

| Call site | line id | File exists? |
|---|---|---|
| `:765` (pain) | `pain` | **NO — silent** |
| `:2715` (pain) | `pain` | **NO — silent** |
| `:1087` (contact, witness) | `contact` | **NO — silent** |
| `:1122` (contact, self) | `contact` | **NO — silent** |
| `:2625` (order) | `order` | **NO — silent** |
| `:977`, `:2523` (rout) | `retreat` | yes |
| `:2330` (grenade) | `grenade` | yes |
| `:2858` (surrender) | `surrender` | yes |

**The two loudest human moments in a Vietnam firefight — a man screaming when he is hit, and a man
shouting that he has seen you — are BOTH wired to files that do not exist.** The fix is a rename, on
either side of the contract.

**Seven of ten recorded enemy lines have no caller at all** — `advance`, `flanking`, `man_down`,
`open_fire`, `reload`, `spotted_us`, `taunt`. At ×3 voices that is **21 finished .wav files dead on
disk.** `spotted_us` is almost certainly the intended target of the broken `contact` calls, and
`man_down` of the broken `pain` calls.

### 2b · Squad VO: 16 of 25 lines never called; 1 call site broken

Recorded per voice (`john`, `ryan`; `norman` a 17-line medic subset). **Never called anywhere:**
`ammo_low · clear · enemy_left · enemy_right · fall_back · fire_in_hole · frag_out · grenade ·
moving · on_me · push_up · reloading · reloading_cov · sniper · taking_fire · treeline`.

Read that list. It is *precisely* the atmosphere set — direction calls, warnings, the treeline, the
frag, taking fire. **The single most valuable unused line in this project is `squad_taking_fire`**:
it is the sound of a man who noticed he is being shot at, and right now that man says nothing.

And `squad_system.gd:678` calls `bandages_over_here` — **no such file in `john`, `ryan` or
`norman`.** Silent no-op.

### 2c · There is no pain/death SFX layer at all

`audio_manager.gd`'s entire public surface is: `play_step_3d`, `play_shot_3d/_player`,
`play_bolt_player`, `play_reload_player`, `play_crack_3d`, `play_explosion_3d`, `play_mortar_tube`,
`play_incoming`, `duck_ambience`. **No pain, no death cry, no flesh impact, no body fall.** In a game
where a firefight is decided in 1–2 shots, the *result* of every shot is mute.

### 2d · The one beat that is fully realised — copy it

`enemy_base.gd:2326-2345`, the grenade: **noise event + Vietnamese VO + a floating "LUU DAN!" +
a 1s arm windup before the throw.** Telegraph, voice, body, timing. It is the only moment in the
game where an NPC reads unambiguously as a man, and it is the template for everything above.

---

## 3 · BODY LANGUAGE

Largely solved, and I will not re-litigate it — the 2026-07-31 orphan-clip sweep
(`production/NPC_ANIM_GAPS.md`) closed prone, the rear death arc, both headshot falls, turn-in-place,
the eight-way octant, and the one-chain-one-pose class. `MODEL_CLIP`
(`sprite_state_map.gd:252-292`) is dense and honest.

Two live gaps, both in silhouette (so both read at PSX):

1. **Allies do not flinch** (§1 #3). The modifier is built and only the enemy calls it. A friendly
   who takes a round and keeps walking is the loudest ally bot-tell after silence.
2. **No reload animation is possible** because no reload state exists (§1 #4). `enemy_reload.wav`,
   `squad_reloading.wav`, `squad_reloading_cov.wav` all sit on disk waiting for a system that was
   never built.

Deliberately-orphaned clips (`CALEB_TODO_7_22_updated.md:519-528`) stay orphaned — that call is made.

---

## 4 · PACING AND SILENCE

**Micro-rhythm exists.** Bounding advance pauses 0.8–1.6s between rushes and fires 2–3 round bursts
with `fire_timer = randf_range(0.3, 0.8)` between them (`enemy_base.gd:1866-1935`). Suppression maps
to posture (`combat_posture.gd:35-71`). At the scale of two seconds, the fight has texture.

**Macro-rhythm does not exist.** The three things that produce a real lull are all absent or mute:

- **Reload** — does not exist. This is the classic lull, and the classic *invitation*: the click, the
  shout, the two seconds where pushing is correct. It is also the beat that makes a player feel he is
  reading a man rather than an actor. Its absence is the largest pacing hole.
- **Losing contact** — the enemy does lose the player (`contact_conf`, `_stamp_contact`), but the
  transition into and out of *not knowing* is silent, so the player never perceives the lull as a
  decision. He perceives it as the AI switching off.
- **Breaking contact** — `squad_broken` and the rout ladder both fire, and both announce themselves
  via a **HUD toast** (`squad_system.gd:457`) or a working-but-lonely `enemy_retreat` line.

**Net:** the fight has rhythm in the code and no rhythm in the ear.

---

## 5 · MISTAKES AND SELF-PRESERVATION

**This is the most over-built and under-expressed area in the project, and the Summoner should know
it before he funds anything new here.** Every mechanic he asked me to look for already exists:

| Behaviour | Where | Player-perceivable? |
|---|---|---|
| Fear/morale break ladder (courage × pressure × force ratio) | `enemy_base.gd:2498-2525` | Only as movement |
| Rout — drops the fight, committed flight ~4s | `enemy_base.gd:2519-2525` | Yes (silhouette) + `enemy_retreat` VO **works** |
| Surrender / Chieu Hoi — alone, hurt, broken | `enemy_base.gd:2840-2867` | Yes + VO **works** |
| Down-not-dead (35% → 0 with overkill) — a wounded witness | `enemy_base.gd:2477-2487` | **Mute** |
| Ally nerve / courage archetypes (the coward anchors deep) | `ally_base.gd:101,139-146` | **Invisible and mute** |
| Squad combat-ineffective → breaking contact | `squad_system.gd:451-457` | **Toast only** |
| Cell withdrawal to rally | `marching_cell.gd:135` | **Mute** |
| Suppression → crouch → prone under a pin | `combat_posture.gd:35-71` | Yes (silhouette) — **this one works well** |

**The verdict on §5: do not build more fear. Give the fear that exists a voice.** The most expensive
thing in this project right now is a rich internal life the player has no channel to hear.

---

## 6 · THE RANKING — perceived impact per hour of work

### ★ 1. Fix the broken VO line ids · ~1 hour · **enormous**
Rename so `pain → man_down` and `contact → spotted_us` resolve (or add the two enemy files). Fix
`bandages_over_here`. **Five dead call sites become live, and they are the loudest five moments in
the game: a man screaming when hit, and a man shouting that he sees you.**
*Sacrificed:* nothing. This is a defect, not a design change.

### ★ 2. Wire the 16 orphaned squad lines + 7 orphaned enemy lines · ~4–6 hours · **enormous**
Every asset is recorded, imported and cast. Wire the highest-value ones **per man, from
`ally_base.gd`** — not squad-level: `taking_fire` when suppression crosses the crouch gate,
`man_down` from the dying man himself, `enemy_left/right` on contact bearing, `frag_out`/`grenade`
on the throw, `fall_back` when `squad_broken` flips, `treeline`/`clear`. Mirror on the enemy:
`open_fire`, `advance`, `flanking`, `taunt` in the lulls.
*Sacrificed:* the 4.0s global `LINE_COOLDOWN_S` (`vo_manager.gd:21`) will need a per-speaker budget
or a firefight turns into a chorus. Budget an afternoon for tuning, not for wiring.

### ★ 3. A pain/death SFX layer in `AudioManager` · ~3 hours · **very large**
`play_pain_3d` / `play_death_3d` / a wet impact on `Hitzone` resolution. **This is the one item that
needs new assets** — but it is 6–10 short files, and it makes every one of the 1–2 shots that decide
a firefight *land*.
*Sacrificed:* asset acquisition time, and voice-pool pressure on `AudioManager`'s 24-voice budget
during a 45-man siege — it needs its own small pool, not the gunshot pool.

### 4. Allies flinch · ~30 minutes · large
One call, mirroring `enemy_base.gd:2455-2457`, into `ally_base`'s damage path. The modifier is
already built and already budget-capped (`MAX_CONCURRENT_FLINCH`).
*Sacrificed:* nothing meaningful.

### 5. Give the existing fear a voice · ~2 hours · large
`squad_broken` → `fall_back` shout before the toast. Rout → already voiced, keep. `_become_downed`
→ `man_down`. Withdrawal → `retreat`.
*Sacrificed:* nothing new is built; this is pure expression.

### 6. AI ammunition + reload · ~1–2 days · large, but the only expensive item
The one genuinely *new system* I recommend. It buys the macro-lull, the dry-click tell, three more
orphaned VO lines, and a reload animation hook. It also has real balance consequences (a suppressing
MG that must pause changes every firefight).
*Sacrificed:* the deliberate "cadence not ammo" simplification (`enemy_base.gd:2292`) — that was a
considered decision and reversing it touches suppression tuning, the siege, and the arena. **Post-EA
unless he wants the lull badly enough to re-tune.**

### 7. De-emphasise HUD toasts as the squad's voice · ~1 hour · medium
Once (2) lands, several toasts become redundant narration of something the player *heard*. Keep
toasts as subtitles per `vo_manager.gd:9`, but stop using them as the primary channel.
*Sacrificed:* readability for players who miss a line. Mitigate — keep the toast, just stop leaning
on it.

---

## 7 · THE ONE THING TO DO FIRST

**Fix the five broken VO line ids.** One hour, no new assets, no design change, no balance risk.
A man screaming when he is hit and a man shouting when he spots you are the two sounds that separate
a firefight from a shooting gallery, and both are currently `null` returns from a cache.

Then wire the sixteen squad lines that have been sitting finished on his disk. He has already paid
for the single biggest believability lever in this project. **He is just not playing the files.**
