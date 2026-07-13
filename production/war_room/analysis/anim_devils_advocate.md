# DEVIL'S ADVOCATE — the art backlog, and why he cannot see it

**Matter:** Caleb's art/anim backlog + *"I haven't seen it develop in the game."*
**Verdict up front:** He is not art-starved. **He is integration-starved.** Every item he
proposed building has a finished twin already rotting in `assets/`. Building more art is the
one action guaranteed NOT to fix his complaint.

---

## Q2 — WHY HE CANNOT SEE IT. (The evidence. This is the whole report.)

He thinks the art didn't land. The art landed. **The engine still spawns capsules over it.**

| Art he finished | Where it sits | What the engine actually renders |
|---|---|---|
| `civ_farmer_m/f`, `civ_elder`, `civ_kid` (+6 prop variants) | `assets/models/characters/*.glb`, imported | **A brown CapsuleMesh.** `scripts/world/civilian.gd:31-40` builds `CapsuleMesh` r=0.3 h=1.6, `albedo_color = Color(0.55,0.45,0.3)`. Called live at `mission_generator.gd:346` and `:519`. |
| `us_pilot_white.glb`, `us_pilot_black.glb` | on disk, imported | **An olive CapsuleMesh.** `insertion_ride.gd:56-64` builds `CapsuleMesh` r=0.28 h=1.1, `albedo_color = Color(0.32,0.36,0.24)` — one per crew seat. |
| `us_rto.glb` (today's radio man + webbing) | on disk, imported | **Nothing. Zero references.** No spawner, no scene, no script instances it. |
| `radio_handset.gd`, `radio_cord.gd`, `antenna_sway.gd` | written, elaborate, bone-attach specs and all | **Never instanced.** grep for `RadioHandset|RadioCord|AntennaSway` outside their own files returns **zero hits.** Dead code on the engine side *and* dead art on the Blender side, pointed at each other, never introduced. |
| `"reloading"` clip (already in the shared library) | `anim_library.glb` | Played by **one** thing: `gore_dummy.gd:29` — **the debug bench.** Nothing in the live game plays it. |

**`ART_MISSING_2026-07-11.md:7-11` states "Villages no longer need capsules." That line is
false.** The villages are still capsules. The doc recorded the *art* as done and mistook that
for the *feature* being done. That confusion is the disease.

### The mechanism that produces "I can't see it"
Look at the beads:
- `cn68` — **"US soldier base model + RTO variant: DONE"** — P1.
- `zbmi` — **"Civilians + RTO: engine wiring once the art lands"** — **P2. Open.**

**He files the art at P1 and the wiring at P2.** The art gets made, the wiring bead sinks
beneath ~40 open P1s and never surfaces. He has industrialized the production of invisible art.
"Once the art lands" arrived — days ago — and nothing woke up, because nothing was watching.

### The law he already wrote, and is breaking
`GAME_GUIDE.md §1`, **the r4bk Law (binding, "learned twice")**:
> *"A feature without a visible HUD affordance does not exist. Simulation without presentation
> is unfinished work, not shipped work."*

Invert it and it is the same law: **an asset without an instantiator does not exist. Art without
integration is unfinished work, not shipped work.** He learned this lesson twice on the systems
side and wrote it into canon. He has not yet applied it to his own art. `ModelActor` even
*hands him the tool* — `setup(unit_id)` + `play_first(clips)` (`model_actor.gd:64,319`), and
`model_actor.gd:31-34` **already contains the civilian height table.** Somebody built the socket.
Nobody plugged anything in.

**The gap is ~15 lines of GDScript per asset. He has been solving it with weeks of Blender.**

---

## Q3 — RELOAD ANIMATIONS: he is about to make the mistake AGAIN, on purpose

He wants to build reload animations. Two facts:

1. **A `reloading` clip ALREADY EXISTS in the shared library** (`gore_dummy.gd:29`;
   `ANIM_WISHLIST.md:23` even measures its start pose at 69° off idle). He is proposing to
   build a thing he already owns.
2. **The engine cannot play a reload animation if he builds one.** `weapon_holder.gd:714-756`
   is a complete reload — `is_reloading`, `reload_timer`, `reload_started`/`reload_progress`/
   `weapon_reloaded` signals, a HUD ring, a *sound* (`GunFX.play_reload_2d`, line 735) — and
   **not one AnimationPlayer call.** The only `.play()` in the entire 960-line file is
   `vm_anim.play("rifle_idle")` at **line 940**. There is no `play("reload")`. Anywhere.

**The reload is a progress bar with a sound effect.** If he spends a week on beautiful reload
animations tomorrow, the engine will play exactly none of them, and he will come back and say
*"I still haven't seen it develop in the game."* **This is the exact loop he is complaining
about, and he is about to run it again.**

The fix is not an animation. It is **~10 lines in `_start_reload()`** telling the viewmodel's
existing AnimationPlayer to play the clip that already exists. Do that FIRST. Then, and only
then, is authoring a better reload clip an act that produces something visible.

---

## Q4 — MEDIC: he is RIGHT. Reuse the work animation. (And he's right for a reason he missed.)

He says: *"we could just use the work animation that we made, it's pretty much the same thing,
it'll work."* **Ship that. Do not author a bespoke medic clip.** Three reasons, escalating:

1. **Read-value is near-identical.** Kneeling, bent over, hands working at something on the
   ground. At PSX poly counts, in jungle, at combat distance, under a 2.5s revive channel
   (`squad_system.gd:162`) — nobody alive will distinguish "aid" from "work." The player is
   watching the treeline, not the medic's hands.
2. **A bespoke medic clip TODAY EXPORTS TO A BROKEN RIG.** `tools/export_medic_gltf.py:18`:
   `RIG = 'MixamoRig'` with `mixamorig:` (colon) bone paths — **off the shared-library
   contract** (`ANIM_WISHLIST.md:34`, task C3). A new medic clip is the single item on his list
   most likely to be built and then be *literally unplayable.*
3. **The medic himself is a v1 rig.** `ART_MISSING §1`: `us_medic` is one of the 8 v1-rig
   characters that **"can NEVER receive the shared anim library — frozen at 21 clips."** So a
   gorgeous bespoke medic animation cannot reach the medic *at all* until he is remade on the
   slim base.

**The real medic task is a 2-line exporter rename (C3), not an animation.** He guessed right
on instinct. The Council should ratify it and move on.

---

## Q1 — RANKED BY GAME-FELT-VALUE PER HOUR (ruthless)

**Tier S — not art at all. Engine wiring of art he ALREADY OWNS. Hours, not weeks.**
| Item | Cost | What he sees |
|---|---|---|
| **Pilots into the Huey seats** (capsule → `us_pilot_white/black`) | ~1h | Two real men in the cockpit, **first 10 seconds of EVERY mission** |
| **Civilians into villages** (capsule → `civ_*`) | ~2h | Villages become populated; **the VILLAGE RAID mission type stops being placeholder** |
| **RTO into the fireteam** (`us_rto.glb` + wake the 3 dead radio scripts) | ~3h | Today's radio man + webbing, *visible*, with the handset system that's already written |
| **`_start_reload()` plays the `reloading` clip that already exists** | ~10 lines | The reload becomes a reload instead of a progress bar |

**Tier A — real art, high felt-value**
- `mg` + `launcher` family clips (`ART_MISSING §3.1-2`) — `nva_rpg` currently *rifle-holds an
  RPG tube*. Worst visual read in combat. Genuinely broken, genuinely needs Blender.
- SKS FP model — enemy-common weapon currently shows a **Kar98k**; capture hands you a WW2 rifle.

**Tier C — content he will never notice is missing**
- `death_from_the_left` (he has front/back/right + 2 headshots + a crouch death — the 4th
  direction is a rounding error on a corpse)
- More VC/NVA variants (he has 6 already; variety is invisible next to *capsules in the villages*)
- Pistol family 8-clip set (**`ART_MISSING §3.4`: "lowest — no AI carries one yet"** — he'd be
  animating for zero units)
- Per-gun FP idle/fidget/inspect

---

## Q5 — THE SINGLE ITEM HE'D MOST SEE, WITHIN A DAY

**Put the pilots in the Huey.** `insertion_ride.gd:52-64`.

- The sockets **already exist** (`SeatPilot`, `SeatCopilot`, `SeatDoorRight`).
- The models **already exist** (`us_pilot_white.glb`, `us_pilot_black.glb`).
- `ModelActor.setup()` + `play_first()` **already exist**.
- **He rides the Huey at the start of every single mission.** He is seated directly behind
  those two capsules, staring at them, on every run of the game. There is no asset in this
  project with a higher guaranteed-eyeball count.
- **It probably closes a P1 bug for free.** Bead `a2qb` — *"two heli models visible (green +
  white)"* — names these crew capsules as the prime suspect for the mystery green bodies.

One hour. His art, in his face, every mission, plus a P1 bug dies. **Nothing else on his list is
within an order of magnitude of that.**

---

## Q6 — WHAT HE SHOULD NOT BUILD

1. **Reload animations** — until `weapon_holder.gd` can play one. He already has a `reloading`
   clip and the engine ignores it. Building more is pouring water into a bucket with no bottom.
2. **A bespoke medic animation** — it exports to a broken rig (`export_medic_gltf.py:18`) onto a
   v1-rig medic that cannot receive the library. Reuse the work clip. He already said so.
3. **More VC/NVA variants, death_from_the_left, pistol family** — variety and polish on units
   the player currently meets as *working characters*, while civilians and pilots meet him as
   *capsules*. Fixing the 4th death direction while the villagers are brown pills is sanding a
   door that isn't hung.

**Runner-up: more Huey art.** Bead `a2qb` says the player **still isn't seated in the Huey** and
there are two visible fuselages. Modeling a better Huey on top of a broken Huey integration is
the same mistake in a larger size.

---

## WHAT IS SACRIFICED (no free lunch — say it plainly)

Redirecting him to integration means **he does not get to be in Blender**, which is where he is
happiest, fastest, and most confident. Tier-S work is GDScript — his weaker, less joyful lane.
I am prescribing a week of the work he likes least.

**Take the trade anyway.** The alternative is another month of beautiful models, an art folder
that grows, a game that does not change, and a solo dev whose morale dies of an entirely
preventable cause. **He said the quiet part himself: "I haven't seen it develop in the game."
That is not a man asking for more art. That is a man asking to SEE his art.** The fastest route
to that sentence never being said again is not a Blender session. It is a spawner.

**Make the game show him what he already made. Then let him go back to Blender — and this time
what he builds will appear.**
