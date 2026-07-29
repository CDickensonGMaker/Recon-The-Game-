# Game Designer — VFX Realism Pass (2026-07-29)

Lens: FX as gameplay information + Pillar 2 (Atmosphere). All pointers verified this session.

## 1. The core ruling: every effect is a message, and today the messages are mute or lying

### 1a. Explosions do not telegraph lethality — one visual for a 150-damage M79 and a 290-damage RPG-7
`gun_fx.gd:118-185` is the ONLY explosion visual, and `play_explosion_3d()` (`gun_fx.gd:108`)
takes a `kind` string that changes **audio only** — the visual is byte-identical for every caller.
Meanwhile the mechanics differ hugely:

| Ordnance | Damage (decree of record) | Kill/blast radius (code) |
|---|---|---|
| M26 frag | 190 | 10.0m (`grenade.gd:12`) |
| M79 HE | 150 | (M79 path) |
| RPG-7 | 290 | rocket path |
| Arty shell | — | 14m (`fire_plan.gd:19` ARTY_BLAST_M) |
| Snake Eye bomb | — | 16m (`fire_plan.gd:22`) |
| CBU bomblet | — | 5m (`fire_plan.gd:32`) |

A player who eats an arty stonk cannot learn "that fireball means stay 15m back" because the
fireball is the same 3-unit quad every time. That is a Fairness Law failure in slow motion:
the game withholds the information the player needs to make cover decisions. **Ruling: the
upgraded explosion must take a blast-radius parameter and scale the fireball, debris throw
distance, and lingering smoke from it.** The plumbing half-exists — `scale_mult` is already
threaded through `_spawn_explosion_visual` (used only by `ambient_war.gd:77` at 12.0x). Promote
it: callers pass their real blast radius, visual scale derives from it. One function, every
caller honest at once.

Second message inside the message: `grenade.gd:15` RIM_FRAC 0.13 — the rim wounds, the centre
kills. The visual should carry the same two-zone grammar: hot fireball ≈ the kill core, dirt/
debris/dust ring reaching out to ≈ the blast radius ≈ the wound rim. Debris that flies 25m from
a 10m grenade is a lie; debris that dies at 3m under-warns.

### 1b. Smoke: the visual sphere IS the mechanic, so the new cloud must fit inside it
`smoke_cloud.gd:15-28` — `blocks_sight()` is a strict segment-vs-sphere test at centre
`pos + (0,1.5,0)`, radius `current_radius()`. Two timing facts are gameplay truth the art must
honor:
- **Grow-in (`:32`)**: radius ramps over 3s, and `blocks_sight` ignores clouds under r=1.0
  (`:20-21`). The first ~0.4s of a smoke grenade is NOT concealment. A pretty cloud that blooms
  full-size instantly tells the player "you're covered" while the AI still shoots him. Unfair
  death, Fairness Law violation.
- **Fade-out (`:32`)**: mechanical radius shrinks over the last 5s of the 25s life. The visual
  must visibly thin/shrink in lockstep — a cloud that looks thick while the AI already sees
  through it kills the player at the worst moment (he's been sitting in it for 20s trusting it).

**Law: the rendered cloud may be equal to or SMALLER than the mechanic sphere, never larger.**
Err inward. An over-pretty over-sized cloud makes the player stand in "smoke" the AI sees
straight past. Under-sized merely wastes a little concealment he didn't know he had — annoying,
not lethal. The particle emission shell should be authored to ~0.9 of `current_radius()` and
driven from it every frame, exactly as the SphereMesh scale is today (`:66`).

This matters because smoke is a **player tool economy** (Pillar 3/5): the smoke grenade is the
break-contact verb, the fail-forward verb — contact goes bad, pop smoke, peel. AI honors it at
`enemy_base.gd:752` (can't confirm target) and `:866` (can't acquire). If the player can't trust
the cloud's edges with his life, the tool dies and fail-forward loses its main lever.

### 1c. Fire: the burn area currently under-shows its damage circle
`fire_hazard.gd:29` draws the cylinder at `radius * 0.9` while the damage sphere is `radius`
(`:19`). Same law, opposite sign as smoke: **a damage area may render equal to or slightly
LARGER at its visible edge than the hazard radius, never smaller** — a man standing on ground
that looks unburnt while taking 25 dps is an unfair death. The upgraded napalm should mark the
ground (scorch decal / low flame cards) out to the full damage radius, with the visual flame
density falling toward the edge so the boundary reads as "edge of fire," not a hard hoop.

## 2. Vietnam sensory palette (Pillar 2 — what the films say the war looks like)

- **Napalm = the black column.** Platoon/Apocalypse Now: the signature is not the fireball, it's
  the greasy orange roll at ignition and then the oily BLACK smoke column standing over the
  canopy for the whole burn. Current state: a flat emissive cylinder and nothing rises
  (`fire_hazard.gd:26-40`, self-described placeholder). The column is also a **Freedom-pillar
  landmark**: in an open AO with no objective markers, a strike the player called becomes a
  navigation feature visible over the trees — "the fire is west of us." Column lifetime should
  outlast the 15s damage window (FirePlan.NAPALM_BURN_S) — smoke lingering after the mechanical
  burn ends is honest (the hazard is gone, the mark remains) and is pure atmosphere for free.
- **Smoke color grammar is period doctrine and must be enforced, not decorative:**
  white/grey = screening (concealment tool), colored (goofy grape, banana, etc.) = MARKING
  (signals, LZ, target ID). The code already half-knows this — `smoke_cloud.gd:9` exports a
  purple "goofy grape" default while `spawn_at()` defaults to screening grey-white (`:35`), and
  WP is a separate white bloom in `field_director.gd:665-718`. The upgrade should make the
  grammar deliberate: player thrown smoke is grey-white screening; any future marking use is
  saturated color; WP is the tall brilliant-white plume with streamers (visually distinct from
  both — WP looks like no other smoke, and players must never mistake its incendiary bite for
  safe screening).
- **Arty as distant weather.** `ambient_war.gd` already rolls 1-3 horizon events/sim-hour at
  200-800m through the SAME shared visual at 12x scale (`:77`). This is the force multiplier:
  upgrade `_spawn_explosion_visual` once and the distant war upgrades itself. Distant impacts
  should leave a slow-fading smoke smudge on the horizon, not just a flash — the "war happening
  around you" pillar in one cheap particle.
- **The connective tissue: dust and haze.** After a real firefight the air is dirty. A cheap
  lingering low-alpha dust layer at heavy-fire positions (keyed off existing impact calls, FIFO
  capped like decals) is the difference between "effects played" and "a place where fighting
  happened." Strictly cosmetic — it must NOT feed `blocks_sight` or any perception math, or it
  becomes an untelegraphed concealment mechanic.

## 3. Priority order (felt atmosphere per unit of work)

1. **Explosion rework** — radius-scaled flipbook fireball (flipbook path proven by the blood
   mist, `gun_fx.gd:345-373`) + dirt column + short lingering smoke, scale driven by real blast
   radius. Highest frequency effect in the game; one function serves grenade, M79, RPG, LAW,
   mortar, arty, bombs, AND the ambient horizon war. Fixes the lethality-telegraph fairness gap
   at the same time. Biggest win, one choke point.
2. **Napalm/fire** — ignition roll + flame cards + black column over the canopy + full-radius
   ground truth. Worst current placeholder, biggest single atmospheric signature, doubles as a
   Freedom landmark.
3. **Smoke grenade cloud** — particle shell driven by `current_radius()`, sized inside the
   mechanic sphere, honest grow-in and fade-out. Gameplay-tool trust; also inherits the WP/
   marking color grammar.
4. **Impact dust + lingering firefight haze** — cosmetic garnish, cheap, capped, no perception
   coupling.
5. **WP consolidation** — fold `field_director.gd:703-721`'s inline CPUParticles WP puff into
   the shared smoke system (Fossil Law: delete the inline block in the same change).

Perf note within my lens: the game is CPU-bound at 23fps (briefing #3) and every current effect
is CPUParticles3D. The upgrade should move the heavy emitters (explosion smoke, napalm column,
smoke cloud shell) to GPUParticles3D — GPU has the headroom, and readability improves free
because we can afford more particles where the message needs density.

## 4. What must NOT change (the untouchables)

- `FLASH_SECONDS = 0.06` (`gun_fx.gd:253`) — the shooter's telegraph floor. Not a look knob.
- `SmokeCloud.blocks_sight()` math, the `(0,1.5,0)` centre, the r<1.0 grow-in gate, and
  `current_radius()`'s 3s-grow/5s-fade envelope (`smoke_cloud.gd:15-32`). Art conforms to
  mechanic, never the reverse.
- `FireHazard` damage radius, 0.5s tick, 15s duration (`fire_hazard.gd:5-7,44-55`) and every
  `fire_plan.gd` constant — the placed footprint preview is computed from these
  (`fire_plan.gd:49`); moving them to fit a visual breaks the player's fire-mission contract.
- `EXPLOSION_RADIUS = 10.0` and `RIM_FRAC` (`grenade.gd:12,15`); the decree damage values
  (M26 190 · M79 150 · LAW 250 · RPG-2 250 · RPG-7 290).
- Explosion visuals spawn AT impact, instantly — no pre-roll flourish that delays or
  anticipates the damage frame.
- The concurrency caps' intent (`MAX_FLASHES` comment `gun_fx.gd:61-64`: the bound must never
  silence a shooter the player could see). Raising a cap for the new art is a conscious perf
  decision, not a side effect.
- No new coupling from cosmetic FX into perception: only `SmokeCloud` blocks sight; dust, haze
  and explosion smoke stay blind to the AI unless a future decree says otherwise.

## Sacrifices named
- Radius-scaled explosions give up "one iconic explosion look" — arty will dwarf a grenade, and
  the small stuff will read humbler than movie memory wants.
- Erring the smoke cloud inward sacrifices a little visual majesty for trust; the cloud will
  look a touch tighter than a real M18 plume.
- Lingering black columns cost persistent alpha overdraw budget; capped like decals or they
  accumulate across a long patrol.
