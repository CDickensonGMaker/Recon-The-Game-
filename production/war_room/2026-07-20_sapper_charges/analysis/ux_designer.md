# UX DESIGNER — sapper charges on the firebase wire
**Date:** 2026-07-20 · **Lens:** perception, affordance, fairness · **Read, not planned:** every pointer below is `file:line` verified against the tree today.

---

## 0 · The state of the orphan

`scripts/enemies/sapper_charge.gd` is 37 lines. Its entire player-facing surface is:

- `:26-28` — `director.toast.emit("SAPPER IN THE WIRE!")` once at 40m
- `:31-34` — `apply_explosion_damage(pos, 180, 60, 10.0)` · `DamageSystem.apply_damage(MEDIUM_EXPLOSION)` · `GunFX.play_explosion_3d(..., "explosion_heavy")` · `NoiseBus.emit_noise(EXPLOSION, pos, 1)`

The toast at `:28` is **dead affordance**. The feature only exists while `patrol_out == true` (`field_director.gd:627`), which means the player is by definition ≥120m outside the wire (`WIRE_GATE_M`, `:491`) and typically 240–470m away at a site (`mission_generator.gd:512`, `:519`). He will never read that toast in the context it was written for. Under the FOSSIL LAW it is not a warning, it is a corpse: **delete it, or route it through `raise_crisis()`.**

The three world-effect lines at `:32-34`, by contrast, are the only honest channels in the file — because they are **physical**, not informational, and nothing gates them.

---

## 1 · The channels, ranked

### RANK 1 — The RTO's net · `field_director.gd:605-621` (`raise_crisis`)
The canonical channel and the only one that is *canon-shaped*. The wording already exists: `CRISIS_CALL["firebase_attack"] = "SIX: THE FIREBASE IS IN CONTACT"` (`:500`). The call prints kind + bearing + range (`:618-620`) and plays diegetic radio VO off the RTO's back (`:621` → `_radio_vo` → `vo_manager.gd:44`).

**This is the channel that must carry ADVANCE warning** — the sappers moving, not the satchel going off. `_poll_firebase_threat()` (`:626-641`) already detects it. Wire the sappers so this is what the net buys the player: **time.**

Two live defects that make this rank-1 channel silently fail:

- **`DynamicMissionFactory._seen` is a one-shot per entity id** (`dynamic_mission_factory.gd:10`, `:39-40`). `field_director.gd:640-641` passes `hash(Vector2i(int(fsb_center.x), int(fsb_center.z)))` — a **constant for the whole session**. The firebase can therefore raise a crisis **exactly once, ever**. The second sapper attack of the campaign produces no radio call, no toast, no circle. That is a straight r4bk violation sitting in shipped code. Fix: key firebase crises on an incrementing attack id, or exempt this state from `_seen`.
- **Sappers must be spawned through `spawn_tracked_enemy()`** (`:30-44`) or they never enter `_live_enemies` and `_poll_firebase_threat`'s loop at `:629-635` never sees them. A sapper spawned any other way is invisible to the only detector in the game.

### RANK 2 — The topo sheet · `topo_map.gd:136-144`
`_draw_overlay` draws `director.patrol_location` as a red grease-pencil double-arc labelled **"SWEEP"**. `raise_crisis` retargets `patrol_location` (`:614`), so the firebase circle is already free — but it will be labelled `SWEEP`, which is wrong and actively misleading for a compound the player already owns.

Fix: label the circle off `patrol_location_kind`. `"firebase_attack"` → `"FSB"` or `"HOME"`. Nothing else changes; the existing per-kind data is already carried at `:615`.

### RANK 3 — The squad's own voices · `vo_manager.gd:61` (`play_squad`)
The cheapest fair channel in the game and **it is not radio-gated**. Men standing next to the player hear a 180-damage detonation 400m away and say so. This is Pillar 4 (you are in the squad, not above it) doing the work the radio cannot when the radio is dead.

Critically: a squad bark is a *reaction to a sound the world made*, not an intel injection. It cannot violate the Fairness Law because it reports something that physically happened within earshot.

### RANK 4 — Distant detonation audio · `audio_manager.gd:~310` (`play_explosion_3d`)
Already fired by `sapper_charge.gd:33` through `gun_fx.gd:108-110`. Settings at the call site: `volume_db = 6.0` · `unit_size = 30.0` · `max_distance = 600.0`.

**Does 600m carry?** Measured against real geometry:
- villages: 240–470m from the gate (`mission_generator.gd:512`, `:519`)
- map is 3000m (`terrain/core/terrain_manager.gd:18`)

So for the *typical* patrol the detonation is inside `max_distance` — but only barely, and inverse-distance with `unit_size 30` puts a 470m listener at roughly **-18 dB relative**, which will sit under jungle ambience. Past 600m it is a **hard cut to silence.** Camps and outward-retried sites (`_outward_site`) go further than villages.

600m is **not enough**, and raising the generic explosion is the wrong fix — it would make every grenade audible across half the AO. Fix: a dedicated distant-report one-shot for the satchel (`unit_size` ~80, `max_distance` ~1500, low-passed), fired *in addition to* the local `explosion_heavy`. Two sounds, two purposes: the blast for anyone near it, the thump for everyone else.

### RANK 5 — A smoke column over the wire
`scripts/combat/smoke_cloud.gd` exists and `SmokeCloud.active_clouds` is already read by the director (`:413`). A column standing over the firebase after a hit is the single most Vietnam affordance available and it costs nothing informationally — it is *terrain*, it does not tell him anything he could not see with his eyes.

It is also the only channel that keeps working if he was face-down in a firefight when the boom happened. **Audio is a moment; smoke is a state.** For a feature the player is by design not looking at, a state channel is worth more than an event channel.

### RANK 6 — The radio row, as a pre-emptive affordance · `mission_hud.gd:240-245`
`radio_state()` already tells him ON THE NET / OFF THE NET / NO RADIO — RTO DOWN, in the squad strip, continuously, before he presses anything. Its own comment (`:237-239`) states the doctrine: *"The player must see he is off the net BEFORE he presses T, not as a refusal after."*

This is what makes an off-the-net blackout **fair rather than arbitrary**: the game told him, persistently, that he was deaf. It is already built and needs nothing.

---

## 2 · ADR-022 — which layer, and does it decay?

**Neither OBSERVED nor ANNOTATED. It is the third de-facto layer already in the code: the CO'S ORDER.**

`topo_map.gd:136-137` names it explicitly — *"THE CO'S ORDER (ADR-029/ADR-022): a grease-pencil circle. An order on paper — it never checks off, never updates; the next patrol's circle replaces it."* That layer has been shipping since ADR-029 and it is the correct home for a radio-reported firebase attack.

**Does it violate "the game marks what you SAW"?** No — and the distinction matters:

- OBSERVED is the game asserting *you witnessed this*. Its precision is earned by eyewitness, and it decays because **eyewitness intel is perishable** (ADR-022 §1, `:32-33`).
- The CO's circle asserts something different: *this is what was said on the radio at this time.* It is not a claim about the player's eyes at all. It is a claim about a transmission, and a transmission is a real event the player really received.

The Fairness Law is satisfied by the same mechanism the file already relies on: `raise_crisis` returns silently at `:612-613` if `_radio_check()` fails. **No circle appears from nothing.** The circle is downstream of a message he actually got.

**Decay: NO.** Three reasons:
1. It is not perishable eyewitness; it is a dated order. An order does not go stale, it gets superseded — which is exactly the existing replacement behaviour (`patrol_location` is overwritten, `:614`).
2. Decaying it would make the map track live world state, which is the quest-log failure ADR-022 §3 forbids.
3. **The circle must NOT clear when the sappers die.** If he kills the last sapper at the wire, or if the garrison does it for him, the circle stays until the next one replaces it. A circle that self-clears is the map telling him the situation resolved — that is a tracker. Being wrong on paper is the fantasy (`ADR-022:48-49`).

**One real risk, and ADR-022 named it first** (`:73-74`): *"Two visual layers on one sheet is a real UI problem... If observed and annotated are not instantly distinguishable at a glance, the whole law collapses into mush."* We are now at three. The CO's layer must stay visually singular — one circle, ever, replaced not accumulated. It already is. **Do not let the firebase circle coexist with a sweep circle.**

---

## 3 · Off the net or RTO dead — fair, or does it need a fallback?

**As written today it is NOT fair, and the fix is not to weaken the radio gate.**

The existing gate is correct for *intel*. `raise_crisis`'s comment (`field_director.gd:602-604`) is right: off the net, the word does not reach him. That is what a dead radioman should cost, and `mission_hud.gd:240-245` warns him he is deaf before it bites.

But the firebase attack is **not only intel — it is a physical event at a place he knows the location of.** A 180-damage satchel makes a noise, throws smoke, and leaves a hole. Gating the *physical* channels behind the radio would be the game pretending a bomb was quiet, and that is a worse crime than a rail.

**The correct asymmetry:**

| Channel | Radio-gated? | What it buys |
|---|---|---|
| Advance warning — sappers approaching the wire | **YES** — `raise_crisis` / `_radio_check` | **TIME.** A chance to get back and *prevent* it. |
| Distant detonation thump | NO | He knows *something* went off, roughly that way |
| Smoke column over the wire | NO | He knows *where*, and it persists |
| Squad bark on the boom | NO | A man names it: *"that's the firebase"* |
| Craters, bodies, damage on return | NO | The permanent record |

**The net buys TIME, not KNOWLEDGE.** With a living RTO he may be able to turn around and fight. Without one he finds out with everybody else — late, by ear, and by walking back into it. That is a real, legible, thematically perfect cost for a dead radioman, and it never produces a silent unexplained number change.

### The response-window problem (this is the Fairness Law's sharp edge)
`_poll_firebase_threat` fires at `FSB_THREAT_M = 90.0` (`:494`) and the sapper detonates at `DETONATE_RANGE = 9.0` (`sapper_charge.gd:6`). A sprinting sapper covers 81m in well under 20 seconds. A player 400m out cannot cover 400m in 20 seconds. **Warning at 90m is not a chance to respond — it is a notification of a fait accompli.** That is precisely the unavoidable "you lose the firebase" event the Fairness Law forbids.

Two fixes, and **both** are needed:
1. **Detect earlier.** Raise the crisis when the sapper *group spawns and starts its run*, or widen the firebase threat ring for the sapper kind specifically to ~250–350m. He needs a warning proportional to the distance he must cover.
2. **Cap the ceiling.** One satchel must be a **wound, not a decapitation** — kills some garrison Civilians (`combat_manager.gd:159-168` confirms they take blast), craters a bunker, costs something real, does not end the firebase. If the worst case is survivable, a late warning is a *tragedy* rather than an *injustice*, and tragedy is Pillar 5.

The garrison is 100% noncombatant `Civilian` (`mission_generator.gd:739-742`), which makes them perfect victims and terrible defenders. That is a design choice worth being deliberate about: **if nothing at the firebase can shoot back, then failure is guaranteed the moment the player is out of reach**, and no warning length fixes that. Either give the garrison some capacity to resist a rush, or accept satchels as an unavoidable periodic tax and price them accordingly.

---

## 4 · What he sees on RETURN

**This is the load-bearing channel, and it is mostly already built.** For a feature that happens off-screen by design, persistence *is* the feature. An event with no aftermath did not happen.

Verified to persist:
- **Craters.** `terrain/systems/damage_system.gd:99` deforms the actual heightmap via `terrain_manager.modify_terrain` (`:137`) and lays a crater scar decal (`:231-237`). `sapper_charge.gd:32` calls `MEDIUM_EXPLOSION`. The terrain is never reloaded between patrols, so **the hole is there when he walks back through the gate.** Note the mission crater budget (`_deforms_this_mission`, `:254`) — verify a sapper hit is not silently eaten by it.
- **Bodies.** Garrison Civilians take full blast (`combat_manager.gd:159-168`) and their corpses are world objects.

Missing and needed:
- **A structural mark.** A blown bunker or a gap in the wire, even a crude one. The crater is generic; a *damaged thing* is specific.
- **Smoke/fire still burning** when he arrives, if he was close enough to make it back fast.
- **A garrison bark.** The men who lived through it should say something as he walks in. This is the debrief, delivered diegetically — one line from a survivor beats any panel.
- **The AAR line.** `_bank_patrol()` (`:697-698`) toasts `"BACK INSIDE THE WIRE - PATROL %d LOGGED, %d KILLS"`. If men died inside the wire while he was out, **that sentence must say so.** This is the one place a number is legitimate, because it is a report on a completed event, not a live tracker.

> **If he can walk back in and everything looks normal, the sapper attack did not happen — regardless of what any counter says.**

---

## 5 · What the HUD shows DURING — and where the rail begins

**Permitted (all already exist):**
- The radio call toast with bearing and range at the moment of transmission — `field_director.gd:618-620`
- The pencil circle on the topo sheet — `topo_map.gd:138-144`
- The persistent ON/OFF-THE-NET row — `mission_hud.gd:240-245`
- Squad barks, ambient audio, smoke on the horizon

**Forbidden:**
- A countdown to detonation
- A live "SAPPERS: 3" counter, or any number that changes on its own
- A persistent on-screen panel titled FIREBASE UNDER ATTACK
- A world-space marker over the firebase — `mission_hud.gd:291-293` already deleted objective markers under ADR-029 as rails; re-adding one for this would reopen exactly what was closed
- Any element that clears itself when the threat resolves

**The line, stated as a rule:**

> **A number that describes a MOMENT is a radio report. A number that UPDATES ITSELF is a quest tracker.**

"SIX: THE FIREBASE IS IN CONTACT — NORTHEAST, 380M" is a man speaking. It was true when he said it and the game never revises it. A panel reading `SAPPERS 3 · 0:42` is the game playing the mission on the player's behalf. The first respects that he might arrive to find it already over; the second cannot survive that outcome, which is why it forces the designer to guarantee the outcome — and that is how rails get built.

Corollary for the toast system: `show_toast` fades over 3.5s + 1.0s (`mission_hud.gd:259-262`). **That transience is a feature here.** The word came once, on the radio, and then it was gone — as it would be. The map circle is the only durable trace, and it is durable because it is *paper*, not UI.

---

## 6 · WHAT IS SACRIFICED

No free lunches. Six, named:

1. **Freedom, taxed (Pillar 3).** A firebase that can be hit while you are away teaches the player to stay close. If the warning window and the damage ceiling are not tuned generously, the emergent optimal play is *never patrol past 200m* — and that shrinks the sandbox this entire game is. **This is the biggest risk in the feature and it is a design risk, not a UI one.**
2. **The quiet patrol gets louder.** ADR-021/ADR-022's whole economy is that an uneventful walk is still worth the evening. Every interruption that yanks the player home makes the contemplative patrol harder to have. Interruption frequency must stay low or it eats the mode it is decorating.
3. **The three-layer map risk.** ADR-022 warned that two layers is already a real UI problem (`:73-74`). We are shipping a third (CO's order) and hanging more meanings on it. Every new circle kind is a step toward mush.
4. **Fair-but-brutal will read as a bug.** A player who was 700m out with a dead RTO, heard nothing, and came home to bodies will call it broken. ADR-022 already accepted this class of complaint (`:69-70`). We will get more of them and we should not fix them.
5. **Audio budget and mix complexity.** A second long-range explosion voice competes for the voice pool (`_acquire_voice`) and risks making the AO feel constantly bombed if it is ever used by anything else. It must be sapper-specific and rare.
6. **Persistence has no save story here.** Craters live in a deformed heightmap; if firebase damage is meant to survive a session it needs a home in the province ledger (ADR-017), and that work is not in scope of wiring the orphan. **Until then, the aftermath is session-only — say so out loud rather than discovering it later.**

---

## Verdict

Wire the sapper's *warning* through `raise_crisis` (radio-gated, buys time), and its *aftermath* through physics (never gated: thump, smoke, crater, bodies, barks, AAR line). Label the map circle by kind. Fix the one-shot `_seen` bug. Widen the detection ring and cap one satchel below "you lose the firebase." Delete the dead 40m toast. No timers, no counters, no world markers.
