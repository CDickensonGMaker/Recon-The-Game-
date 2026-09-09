# THE DISTANT WAR — GAME/WORLD DESIGNER'S ANALYSIS

**Council:** 2026-09-09 firebase-kit pivot, Briefing II (`briefing_distant_war.md`).
**Architect:** Game/World Designer. **Method:** code read, no game run, no window opened, no write
outside this file. Every claim carries `file:line`. Where I could not measure, I say UNVERIFIED.

---

## 0 · THE HEADLINE, BEFORE ANYTHING ELSE

I was sent to test the hypothesis *"the war does not feel present because `AmbientWar` is real and
almost never fires."* **That hypothesis is REFUTED.** It fires roughly **32 times in a 30-minute
demo** — about one distant war event every 56 real seconds. The number is derived in §5.

The real finding is different and worse, and it is a **design** finding, not a perf one:

> **He hears a war he can never touch, and he can touch a war that almost never rolls.**

Two tiers exist and nothing lives between them:

| Tier | Range | What it is | Outcomes it writes | Can he reach it? |
|---|---|---|---|---|
| `AmbientWar` (`ambient_war.gd`) | **400–800 m** (`:69`) | pure sound + a fake 12× fireball (`:190-193`) | **ZERO** | **NO — provably impossible, §2** |
| `AmbientEncounters` (`ambient_encounters.gd`) | **110–200 m** (`:41-42`) | full man-by-man AI, both sides real (`:397-398`) | almost zero (§3) | yes, it spawns on top of him |

**The 200–400 m band is empty.** That gap — the band where a fight is far enough to be somebody
else's and close enough to walk to — is the thing the "war runs without you" promise actually lives
in, and nothing occupies it.

---

## 1 · THE VERDICT

### **YES — WITH FOUR MECHANICAL CONDITIONS.**

Distant engagements MAY be resolved abstractly and presented as sound. But the verdict is much
less dangerous than the briefing feared, because of a fact I had to measure before I could rule:

> **A distant NPC-vs-NPC engagement writes ZERO ledger rows today. There is nothing to preserve.**

The casualty ledger the 7/30 decree names is **the player's own butcher's bill and nothing else.**
`campaign_state.gd:50-75` states it plainly: `kia_total`, `ward_wounded`, `bags_unlifted`. Its only
writers are `campaign_state.gd:258` (`pilot_lost`), `:264-266` (`result.squad_kia`), `:275`
(`ward_wounded` derived at `WIA_PER_KIA` 3), `:278` (`friendly_wia`). And `squad_kia` has exactly
**one** writer repo-wide — `squad_system.gd:809` — the player's own five men.

`FriendlyPatrolGroup` (`scripts/missions/friendly_patrol_group.gd`) has **no** banking path at all.
The three ambient friendlies who die in an `AmbientEncounters` "contact" event 150 m from the player,
fought by the real combat AI, with real bodies and real wounds — **write nothing into any ledger.**
The AAR kill book is stricter still: `field_director.gd:115-120` requires
`killer.is_in_group("player")` or a squad ally, or it returns.

So the briefing's standing constraint — *"the same men die and the same ledger rows are written
whether or not the player watches"* — **has no referent for this class of event.** It is a true and
good law that binds nothing here, because nothing distant has ever written a row. The dangerous
prize the briefing warned about is not on the table. **This is not permission to widen the answer:
it is the reason the answer is cheap.**

### The four conditions — mechanical and testable

**C1 · THE UNREACHABILITY INVARIANT MUST BECOME A LAW, NOT AN ACCIDENT.**
An abstract engagement must resolve before the player can physically arrive. Today that is true by
arithmetic (§2) but by accident — two unrelated constants happen to sit the right way round.
Bind it:

> `min_spawn_distance_m / PLAYER_SPRINT_SPEED > max_lifetime_s`
> Today: `400.0 / 8.0 = 50.0 s` travel vs `40.0 s` maximum life. **Margin 10.0 s (25%).**
> Sources: `ambient_war.gd:69` (`randf_range(400.0, 800.0)`), `ambient_war.gd:73`
> (`randf_range(14.0, 40.0)`), `player.gd:13` (`SPRINT_SPEED = 8.0`).

Assert it in a probe. It is a three-line test and it is the only thing standing between the shipped
design and the incoherent mid-fight transition §2 proves cannot be made to work. **A 25% margin is
thin** — raising the lifetime ceiling to 55 s, or dropping the floor to 300 m, silently breaks it
and nobody would notice until a playtester walked into a phantom.

**C2 · ABSTRACT RESOLUTION MAY WRITE ONLY WHAT AN OBSERVER COULD NOT CONTRADICT.**
It may write: threat/heat modifiers, `MissionState.flags`, an intel mark, a bark, a radio line. It
may **NOT** write anything that implies a physical scene the player could go inspect — because the
scene will not be there (§3 proves corpses free themselves in 45 s). A ledger row that says
"11 KIA at grid X" and a grid X with nothing on it is a lie in the world, which is the FOSSIL LAW
pointed at fiction.

**C3 · THE AMBIENCE LAW BINDS UNCHANGED (ADR-020 §4, `ADR-020-authored-threshold.md:144-150`).**
*"Every ambient event must be safe to ignore. The moment ignoring something COSTS the player, it is
not ambience — it is a MISSION."* An abstract resolution that costs him something he could have
prevented by walking is a mission with no board, which is the exact failure ADR-020 was written to
forbid. Any cost surfaces through `DynamicMissionFactory` as an offer (`mission_generator.gd:273-276`)
or it does not exist.

**C4 · ADR-010, ONE SEED.** Any abstract resolution is drawn from the operation seed or it is not
deterministic. Note the documented exemption: `AmbientWar`'s roll is deliberately **unseeded**
(`ambient_war.gd:11` bare `RandomNumberGenerator.new()`; the exemption is stated at
`demo_game.gd:9-11` and echoed at `ambient_encounters.gd:70-72`). **That exemption is only safe
while the roll produces nothing.** The moment an abstract resolution writes an outcome, it leaves
the exemption and must be seeded. This is the single sharpest edge on the whole proposal.

### Against the five Pillars

| Pillar | Reading |
|---|---|
| **1 · Believable firefights** | **Neutral-to-positive.** Pillar 1 is about the fight *he is in*. A fight at 600 m is not a firefight, it is weather. Nothing at 600 m has ever been believable-or-not; it has been inaudible-or-audible. Spending 94% body cost (ADR-035 §2) on men he cannot see is the pillar-violating move, not the abstraction. |
| **2 · Atmosphere** | **The pillar this serves, and the pillar most at risk.** Serves it: sound at range IS the atmosphere, and he said so. At risk: §5's measured defect — the jungle **never hushes** for a distant firefight, so the war layers *under* birdsong instead of interrupting it. Atmosphere is contrast, and the contrast is currently unreachable by one metre. |
| **3 · Freedom** | **Protected only by C1.** Freedom means he may walk toward the gunfire. Today he may walk toward it and it will be gone — that is honest (a fight ended) and it is what real war sounds like. What would violate Pillar 3 is arriving and finding *nothing that was ever there*: no craters, no shell scrape, no story. See §3. |
| **4 · The squad is the RPG** | **Untouched.** Nothing at 400–800 m involves his five men. The one place this pillar bites is `AmbientEncounters` "contact" (`:399-429`), which is inside the near tier and stays simulated. |
| **5 · Fail forward** | **Protected by C3.** An abstract battle he ignored must never become a fail-state discovered later. Under ADR-020 §4 it becomes an offer or it becomes nothing. |

**No pillar forbids this. Pillar 2 conditions it.**

---

## 2 · THE TRANSITION CASE

The briefing asked me to press hardest here. I did, and the honest answer is the one the briefing
invited: **a mid-fight transition cannot be made coherent — and the shipping design already avoids
needing one, by arithmetic it does not know it is relying on.**

### 2.1 The transition is currently IMPOSSIBLE. Measured.

- Nearest an `AmbientWar` event can be born: **400.0 m** (`ambient_war.gd:69`).
- Longest it can live: **40.0 s** (`ambient_war.gd:73`).
- Fastest the player can move: **8.0 m/s** sprint (`player.gd:13`); 7.0 m/s once winded
  (`player.gd:81`); 5.0 m/s walk (`player.gd:12`); 2.5 crouched (`:14`); 1.0 prone (`:74`).
- **400.0 / 8.0 = 50.0 seconds of travel, minimum, on a straight line over open ground.**

**50.0 > 40.0. He cannot reach a distant firefight before it ends. Not at the closest possible
spawn, not at the longest possible life, not at full sprint, not ever.** And that ignores terrain,
vegetation, and the fact that a sprint at 8 m/s burns stamina (`player.gd:78-81`).

So the transition case §2 of the briefing worries about **does not exist in the shipping build.**
`MarchingCell`'s 80 m answer was never asked to generalise here, because nothing here ever
materializes.

### 2.2 Why it could never be made coherent anyway

Suppose we broke the invariant — dropped the floor to 250 m, or stretched a "long engagement" to
3 minutes — so he *could* arrive mid-fight. Take the briefing's four questions in order.

**Where do the already-dead bodies go?** They would have to be spawned as corpses. `EnemyBase._die`
(`enemy_base.gd:3014`) is the only path into `lootable_corpses` (`:3045`, `:3103`), and every corpse
starts a **45-second self-free** the instant it enters that state
(`enemy_base.gd:3047` and `:3105` — `get_tree().create_timer(45.0).timeout.connect(queue_free)`).
There is **no distance check and no "only when unseen" guard**. So either we spawn the dead as he
arrives — bodies appearing out of nothing, the exact failure `MATERIALIZE_M` exists to prevent
(`marching_cell.gd:12-15`) — or we spawn them at abstract-kill time and they are gone before he
covers a third of the ground.

**What wounds do they carry?** Nothing in the abstract resolution knows. Wounds are a property of
the hit that made them: `Hitzone` + the death clip + the gore/ragdoll branch
(`enemy_base.gd:3058-3099`). An abstractly-killed man has no hit. We would be authoring a wound to
match a bullet nobody fired, from a direction nobody chose, and any player who checks the bearing
of the fire he heard against the entry wound catches us. **This is the point where the fiction
stops being cheap and starts being a content pipeline.**

**Whose weapons are on the ground?** This one is *nearly* free, and it is the interesting exception.
`WorldWeapon` (`world_weapon.gd:22`) carries `LIFETIME_S = 600.0` — **ten minutes**, thirteen times
the corpse clock — with a global cap of `MAX_WORLD_WEAPONS = 24` (`:29`) and a reprieve for guns
near the player (`:88-90`). A dropped rifle is cheap, persistent, seeded (`_seeded_partial`, `:97`
derives a 5–18 round partial load from the position, ADR-010-clean), and it survives long enough to
be walked to. **The gun outlives the body by design, and that asymmetry is the whole aftermath
opportunity.** See §3.

**Does the surviving side hold a position that makes sense given what he heard?** No, and this is
the one that cannot be patched. `ambient_war.gd:133-157` places the two parties **15–40 m apart on
a random bearing** (`PARTY_SPREAD_M` 40.0, `:20`) with no terrain query, no cover, no navmesh, no
`_passable_near` call. The sound is emitted from two points in space that may be inside a tree, on
a cliff, or in a river. The near tier does this correctly — `ambient_encounters.gd:413` routes
through `MissionGenerator._passable_near` and `:416` through `_seat`. The far tier does not, because
it never needed to. **Making the far tier's geometry defensible is not a tweak; it is giving the
abstract layer a terrain model, which is most of the cost of just simulating it.**

### 2.3 THE DESIGN THAT AVOIDS NEEDING THE TRANSITION

**Ratify the invariant that already holds, then give the 200–400 m band an AFTERMATH instead of a
fight.** Three parts:

1. **FAR TIER (400–800 m) — sound only, no outcomes, unreachable by C1.** Exactly what ships.
   Keep it. Fix the hush (§5.3). Do not add bodies, do not add a ledger, do not lower the floor.
   Its job is weather, and weather is not walked to.

2. **MID TIER (200–400 m) — the empty band — gets AFTERMATHS, never live fights.** An abstract
   engagement resolves *before* it is placed. What lands in the world is a finished scene, seeded
   from the operation seed, at a `_passable_near` point. It has no clock, no live AI, and nothing to
   transition. **The player never watches an abstract fight become real, because it was never live.**
   He hears something at 600 m in the far tier; twenty minutes later he finds a scene at 300 m that
   the world says is what that was. The link is fiction and it does not need to be true — he cannot
   check, and that is the point.

3. **NEAR TIER (110–200 m) — stays fully simulated.** `AmbientEncounters` is correct as built and
   its comment at `:397-398` states the law I would state: *"Both sides are the REAL combat AI — the
   gunfire the player hears is the real systems fighting, never a sound prop."* **Do not abstract
   anything he can walk to inside a minute.**

The rule that falls out, and it is the one line I would put in the ADR:

> **Simulate what he can reach. Sound what he cannot. Never place a live abstract fight in between —
> place its aftermath.**

---

## 3 · THE AFTERMATH QUESTION

**Can an abstractly-resolved battle produce bodies worth searching and a scene he reads as coherent?
TODAY: NO. With one constant changed: YES, and cheaply.**

### 3.1 The blocker, measured

`enemy_base.gd:3047` and `:3105` free every corpse **45 seconds** after death, unconditionally. A
scene made of bodies has a 45-second shelf life. He needs 50 s minimum just to cross 400 m. **The
aftermath is gone before he is halfway there.** This single constant is why the "walk toward the
war" fantasy does not currently exist in any form.

Note what this also means for the *near* tier: `ambient_encounters.gd:492-493` comments that
*"Corpses keep their own 45s linger"* and only lifts the living. That is correct for a fight he
watched. It is fatal for a scene he is meant to discover.

### 3.2 What an aftermath must carry to be worth the walk — the minimum

Ranked by story-per-byte. The first three are the floor; below that it is decoration.

| # | Element | Why it is load-bearing | Cost today |
|---|---|---|---|
| 1 | **2–4 searchable bodies** | Intel is the ONLY thing a body gives (`bodies-give-intel-only`, 7/30). `player.gd:1150-1170` requires an `EnemyBase` in group `lootable_corpses` within 2.5 m. **This is the whole reason to walk there.** | Needs the 45 s clock made conditional. Nothing else. |
| 2 | **The weapons where they fell** | `WorldWeapon` already persists 600 s, seeded, partial mags (`world_weapon.gd:22,97`). A rifle lying 3 m from its owner with 7 rounds left tells the fight's last minute with no authoring. | **Free. Already built.** |
| 3 | **Direction** | Bodies facing one way, brass and dropped kit trailing the other. Reads instantly as *who was advancing*. | Free — it is a placement rule, not a system. |
| 4 | One blast crater / burn patch | Says indirect fire was involved; explains the `explosion_heavy_dist` thumps he heard (`ambient_war.gd:125-128`). | Cheap (`GunFX` already owns the visuals). |
| 5 | A survivor | A wounded man, a prisoner, or nobody. `EnemyBase` already has downed/secure (`player.gd:1103-1107`) and surrender (`:3130-3145`). | Moderate — one live body, not a fight. |

**Elements 1–3 are the minimum, and 2 and 3 are already free.** The entire aftermath feature
reduces to: *make the corpse clock conditional, and place the scene sensibly.*

### 3.3 Is that cheaper than simulating the fight? YES, by a wide margin — and the margin is measured

ADR-035 §2 (`ADR-035-the-siege.md:55-58`) gives the number: the AI wall is ~38–40 ms/tick and **~94%
of it is the BODY** — `move_and_slide` ~9 ms, hitzone sync ~10 ms, anim/execute ~18–19 ms. Think is
~1.2 ms.

An aftermath is bodies with **`set_physics_process(false)`** already set at death
(`enemy_base.gd:3034`), no think, no `move_and_slide`, no execute — and hitzone sync only at 6 Hz
while `_body_hot` (`enemy_base.gd:801-806`). **It is the corpse's cost with none of the soldier's.**

Six corpses standing still forever is dramatically cheaper than six soldiers fighting for 90
seconds and then becoming six corpses. And the aftermath is *strictly more valuable to the player*,
because he cannot be at every fight but he can walk past every aftermath.

**The one honest caveat:** a persistent corpse is a permanent node, and the 45 s clock exists to
stop `_live_enemies` growing without bound — the same ghost problem ADR-035 §4 names for
withdrawal (*"~40 permanent full-cost ghosts"*, `ADR-035-the-siege.md:78`). **Any conditional clock
needs its own cap and its own reap**, or we have re-created the defect ADR-035 spent a whole section
killing. Suggested shape: keep the 45 s clock for fights the player *watched* (unchanged, zero risk),
and give **aftermath-placed** corpses a distance-gated reap — free at >250 m from the player, hard
cap ~12 bodies world-wide, reaped oldest-first. That mirrors `WorldWeapon`'s existing pattern
(`world_weapon.gd:80-94`) exactly, which is the argument for it: **one pattern, already shipped,
already reviewed.**

### 3.4 Does it satisfy `bodies-give-intel-only`?

Yes, and it strengthens it. The 7/30 decree's whole purpose is *"it gives the reason to explore and
patrol more areas."* An aftermath is literally that sentence built as a place. `CampaignState.add_intel(1)`
per body (`player.gd:1165`) → `lifetime_intel` → `next_stash_at = randi_range(20,30)`
(`campaign_state.gd:100`) → a stash of 3 marks, 1 real. **A four-body aftermath is 4 intel, ~15% of
a stash. Walking to the war pays in exactly the currency he decreed.** No new economy, no new
system, no new archetype.

---

## 4 · WHAT THE PLAYER IS OWED AT RANGE — arguing both sides

His words: *"at most just random battle sounds from time to time will sell this war at large effect
more than anything else."* That is a ruling, and I take it as one.

### The case FOR sound-only, no bodies, no rows (his position)

1. **It is already true and he was right about it.** `AmbientWar` produces **zero** physical
   entities: `_make_source` builds `AudioStreamPlayer3D` nodes (`:105-118`) and `_spawn_visual`
   borrows `GunFX._spawn_explosion_visual` (`:190-193`). **No colliders, no bodies, no ledger.** He
   described the system that exists.
2. **He cannot audit what he cannot reach.** §2.1 proves reachability is arithmetically impossible.
   A fiction nobody can check costs nothing to maintain and cannot be caught lying. Simulated men at
   600 m are a proof nobody demanded, paid for in the most expensive currency the project has.
3. **ADR-020 §4 is on his side.** *"The living world's job is to make the quiet feel OCCUPIED, not to
   make the war feel BUSY."* Sound occupies. Simulation busies.
4. **The thing he complained about is the VISUAL half, not the audio half.** He stuttered on ambient
   napalm and generalised. `ambient_war.gd:190-193` spawns a **12.0-scale** explosion visual for
   **4 of 5 kinds** (only `"tracers"` returns early, `:191`) — at the §5 rate that is ~26 horizon
   fireballs per 30-minute demo. **The audio is nearly free; the fireballs are not.** His instinct
   ("just sounds") points at exactly the right half.

### The case AGAINST — what sound-only costs

1. **"The war runs without you" becomes a claim the game never honours.** ADR-020 §3.3
   (`ADR-020-authored-threshold.md:110-112`) promises: *"a battle exists whether the player shows up
   or not. If his AO window happens to contain one, it is live, and he can walk into it."*
   **Sound-only means he can NEVER walk into one.** The promise is not weakened, it is deleted.
2. **A world that only ever talks is a soundtrack.** He walks toward it, it stops, he finds nothing.
   Do that twice and the player learns the correct response to distant gunfire is *ignore it*. That
   is a learned lesson that permanently devalues Pillar 2's best instrument.
3. **It concedes the genre's whole point.** ADR-029's north star is *"i just wanna leave the camp and
   go find problems."* Sound with nothing behind it is a problem you cannot go find.

### My ruling on his ruling

**He is right about the far tier and it should not change. He is describing a symptom in the mid
tier that sound cannot cure.**

Take his sentence literally — *"at most just random battle sounds"* — and it is a ceiling on how much
machinery a **distant** event deserves. It is not a statement that the world should be hollow at
every range. Sound is what he is owed at 600 m. **What he is owed at 300 m is a place.** The
aftermath (§3) honours both: the far tier stays exactly the sound he asked for, and the mid tier gets
the one thing sound can never carry — a scene with consequences in it.

And the cost of *not* doing it is the one line I would put in front of him:

> **The war he hears must occasionally leave something behind, or he learns to stop listening.**

---

## 5 · WHAT IS ACTUALLY REACHING HIS EARS TODAY — the measurement

All derived from constants. **UNVERIFIED at runtime**: the logs at
`AppData/Roaming/Godot/app_userdata/RECONgame/logs/` contain **zero** `[AmbientWar]` or `[AMBIENT-ENC]`
lines (13 files, largest 31 KB dated 2026-07-08; today's are 0.3–2.4 KB editor runs). Nothing has
been observed. He is playing now; that log will settle it.

### 5.1 How often `hour_advanced` fires in the demo

`ambient_war.gd:47-48` connects to `SimClock.hour_advanced`, which fires on integer-hour crossings
(`sim_clock.gd:49-50`). Sim time advances at `delta * real_to_sim_ratio / 3600.0` (`sim_clock.gd:45`).

Demo constants (`demo_game.gd`): `START_HOUR = 6.5` (`:44`), `DAY_RATIO = 38.0` (`:49`),
`NIGHT_RATIO = 20.0` (`:56`), night seam at sim 19.0 (`sim_clock.period_at`, `:62-69`).

- **Day:** one sim hour every `3600 / 38 = 94.7 real seconds`.
  First crossing (07:00) at `0.5 × 3600 / 38 = 47.4 s`. Crossings 07:00…19:00 = **13 emissions**,
  the last at `47.4 + 12 × 94.7 = 1184.2 s` — which matches the comment at `demo_game.gd:46`
  ("reaches NIGHT (sim 19.0) at ~1184s"). **Derivation confirmed against the file's own number.**
- **Night:** one sim hour every `3600 / 20 = 180 real seconds`. Crossings at 1364 s, 1544 s, 1724 s.

**A 30-minute (1800 s) demo run: 13 + 3 = 16 `hour_advanced` emissions.**
To the `END_BACKSTOP_S` 2700 s failsafe (`demo_game.gd:74`): **21 emissions.**

### 5.2 How many events that is

`_roll_events` draws `n = rng.randi_range(1, 3)` (`ambient_war.gd:62`), mean 2.0.

> **~32 distant war events in a 30-minute demo. One every ~56 real seconds.**
> To the 2700 s backstop: **~42 events.**

Of those, `FIRE_CAP = 2` (`:19`) limits concurrently *sounding* engagements. Expected concurrent
firing = arrival rate × mean lifetime = `(2 / 94.7) × 27 = 0.57`. **The cap almost never binds** —
the great majority of events do sound. The `"held silent"` print at `:89-90` should be rare.

And `_spawn_visual` (`:190-193`) skips only `"tracers"` — 1 of the 5 `KINDS` (`:12`). So **~26 of
those 32 events also spawn a 12.0-scale fake fireball + smoke column** at 400–800 m. **That is the
half of this system that costs money, and it is 80% of the events.**

**CONCLUSION: the system is not quiet. It is loud, frequent, and it fires a big explosion visual
roughly every 70 seconds.**

### 5.3 THE DEFECT I FOUND — the jungle never hushes for the war

`game_world.gd:264`: `const AMBIENT_WAR_HUSH_M: float = 400.0`
`game_world.gd:358-362`: hushes the wildlife when any active `AmbientWar` event is `<= 400.0 m` away.
`ambient_war.gd:69`: every event is born at `rng.randf_range(400.0, 800.0)`.

**The hush threshold is the spawn floor.** At birth, no event is ever inside it (a continuous draw
hits exactly 400.0 with probability ~0). It can only trigger if the player happens to be walking
*toward* a near-floor event during its 14–40 s life — which §2.1 shows he can barely do.

**In practice the birds sing straight through every distant firefight.** Atmosphere is contrast, and
the one mechanism built to provide it is unreachable by one metre. **This is a one-number design
defect** — raise `AMBIENT_WAR_HUSH_M` to ~900.0 and every event hushes the jungle it happens near.

**I believe this is a larger part of "the war doesn't feel present" than the firing rate is.** The
war is audible but it never *interrupts* anything, so it reads as part of the ambience bed rather
than as an event.

### 5.4 The other half — the near tier almost never rolls

`AmbientEncounters` is the tier with actual men, actual bodies, actual intel. Its gates
(`ambient_encounters.gd`):

- `HOLD_S = 600.0` (`:21`) — **dead for the first 10 real minutes.**
- `MissionWeather.is_night` blocks all rolls (`:183`); `is_night` is true from sim 19.0
  (`mission_weather.gd:95`, `sim_clock.gd:62-69`) = **~1184 s.**
- **Eligible window: 600 s → 1184 s = 584 real seconds.** One third of a 30-minute demo.
- Inside it: `EVENT_CHANCE = 0.35` (`:19`) per `ROLL_EVERY_M = 65.0` metres **walked outside 110 m
  from `fsb_center`** (`:18`, `:29`, `:172-177`), `COOLDOWN_S = 240.0` between events (`:23`), one
  live at a time (`:145`), and `DAY_CAPS = {harass 1, patrol 2, contact 1}` (`:25`).
- **`contact` — the friendly-squad firefight, the one with a real fight in it — is capped at ONE for
  the entire demo day** (`:25`), and requires the player to be 110–200 m from a pre-placed site
  (`:41-42`, `:232-240`).

With `COOLDOWN_S` 240 s inside a 584 s window, **at most 2–3 encounters are physically possible, and
0 if he does not walk far outside the wire during that specific third of the demo.** The demo's own
arc works against it: the day runs on the garrison schedule and he is back inside for the night
stand-to (`demo_game.gd:32-38`).

**That is the diagnosis.** The far tier fires ~32 times and can never be reached. The near tier can
be reached and fires ~0–3 times, only in a 584-second daylight window, only while walking.

---

## 6 · TRADEOFFS — LAW 2. WHAT MY VERDICT SACRIFICES

**No decision here is free. Named, in order of what they actually cost:**

1. **The province simulation dies as a literal claim.** ADR-020 §3.3 promised units moving on a
   district map colliding into battles the player can walk into. My verdict says: he can walk into
   the *aftermath*, never the battle. **That is a demotion of the promise and it should be written
   into the ADR in those words, not quietly narrowed.** Anyone who reads ADR-020 §3.3 after this
   ruling and expects to join a distant fight will be wrong, and the doc will have lied to them —
   the POINTER LAW, applied to fiction.

2. **Coherence is purchased with unfalsifiability.** The far tier works *because* he cannot check it.
   That is a real design compromise and it has a failure mode: the day someone raises the lifetime
   ceiling or lowers the distance floor "to make the war feel closer", the whole thing becomes
   checkable and instantly incoherent. **C1's probe is the only thing standing there.** Without it,
   this verdict has a fuse in it.

3. **An aftermath is authored, and authored content does not scale.** Three placements will read as
   three placements by the fifth patrol. The seeded variation (`WorldWeapon._seeded_partial`,
   body count, facing) buys real variety, but **a scene the player learns to recognise is worse than
   no scene**, because it converts atmosphere into furniture.

4. **Persistent corpses re-open a defect ADR-035 §4 spent a whole section killing.** Conditional
   lingering means permanent nodes; permanent nodes mean ghosts (`ADR-035-the-siege.md:73-78`).
   The cap-and-reap in §3.3 mitigates it. **It does not eliminate it, and I will not pretend it does.**

5. **Sound-only at range concedes that a whole distance band of the world is theater.** He is right
   that this is the correct trade, but it *is* a trade. A player who works it out — who walks toward
   gunfire three times and finds nothing three times — has learned that a third of the map's audible
   events are painted on. **That knowledge cannot be un-learned**, and it is the reason §3's
   aftermath is not optional decoration: the aftermath is what buys back the credibility the far
   tier spends.

6. **Fixing the hush makes the war louder in the mix, and he complained about ambient events.**
   Raising `AMBIENT_WAR_HUSH_M` to 900 means the jungle goes quiet ~26 times in 30 minutes. **Done
   badly that is worse than never hushing** — a wildlife bed that ducks every 70 seconds is a
   pumping artifact, not atmosphere. The hush fix must come with a rate limit, or the scarcity ADR-020
   §4 calls *"the entire trick"* is spent on nothing.

---

## 7 · WHAT I COULD NOT VERIFY

- **Audibility.** I cannot run the game and I cannot listen. Whether `volume_db = -8.0`,
  `unit_size = 220.0`, `max_distance = 1200.0` and a 900 Hz low-pass (`ambient_war.gd:109-115`)
  actually produce something he notices at 400–800 m over a jungle ambience bed is **UNVERIFIED and
  it is the single most load-bearing unknown in this analysis.** If the mix is 20 dB too quiet, every
  number in §5 is irrelevant and the answer to "why doesn't the war feel present" is one slider.
  **This should be the first thing checked, before any design work is authorised.**
- **Runtime firing rate.** §5's ~32 events is derived from constants, not observed. No log in
  `logs/` contains a single `[AmbientWar]` line.
- **The napalm stutter's actual source.** He generalised from it; I did not trace it. That belongs to
  the perf census agent, not to me. I note only that `AmbientWar` contributes ~26 twelve-metre
  `GunFX` explosion visuals per demo (`ambient_war.gd:190-193`) and that this is a plausible
  contributor to a class of stutter he attributed to "events across the map".
- **Whether `GunFX._spawn_explosion_visual` at 12.0 scale is expensive.** Unmeasured; perf census.

---

*Filed by the Game/World Designer. The Arbiter holds the decree.*
