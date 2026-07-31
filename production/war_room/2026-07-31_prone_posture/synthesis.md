# THE DECREE — prone posture (2026-07-31)

**Summoner's ruling:** *"Build it — full War Room first."* Four architects, summoned in parallel,
no cross-talk. All four reported. **Every pointer below was re-verified by the Arbiter against the
code before this decree was written** — none was taken on the architect's word.

---

## WHAT THE COUNCIL CONVERGED ON

**1. Prone is STATIONARY-ONLY.** Two architects reached this from opposite doors and neither knew
the other was looking. The animator measured the glTF: all four prone clips are **in-place**, zero
horizontal hip travel, a pure 0.311 m drop — and `wounded_crawl` is NOT prone locomotion (hips
0.385 m vs 0.149 m, 36° apart; it is a hands-and-knees casualty crawl). The programmer found
`_CLIP_SPEED` (`model_actor.gd:943-954`) has no prone entry, so `set_locomotion_speed` resets to
1.0 and a moving prone man ice-skates. **There is no prone locomotion clip. This is an art
constraint, not a design choice.**

**2. The state map carries prone WITHOUT a rewrite.** `clip_for()` (`sprite_state_map.gd:204`) is
a flat intent lookup and crouch is already a post-hoc remap — `_to_crouch()`
(`sprite_state_map.gd:99-122`), driven by `CombatPosture.Posture` (`combat_posture.gd:9`). Prone
is a **third enum value, not a cross product.** The handoff's "register axis is a War Room item"
warning is about calm/concerned/alert/combat, which multiplies every intent by four. That warning
does not bind here.

**3. Widening the enum silently does NOTHING.** Verified: `decide()` has exactly two callers,
`enemy_base.gd:409` and `ally_base.gd:378`, and **both are `_is_low_posture() -> bool` doing
`== Posture.CROUCH`**. A third value returns `false` — a prone man is classified *standing*
across eleven downstream consumers (clips, `CROUCH_SPEED_CAP`, footstep volume, the stumble guard
`enemy_base.gd:2263`, the crouch-death pick `enemy_base.gd:2596` / `ally_base.gd:1451`). No error,
no warning, eleven wrong behaviours. **Fix the RETURN TYPE, do not merely widen the enum.**

---

## THE FINDING THAT RESHAPES THE WORK

**AI low-posture buys the AI NOTHING MECHANICAL today.** Not concealment, not protection — a clip,
a speed cap, and footstep volume. That is the whole list.

- Every AI bullet leaves a **hardcoded** `global_position + Vector3.UP * 1.35`
  (`model_actor.gd:984-989` — verified, both `muzzle_ballistic` and `muzzle_visual`). **A prone man
  shoots over the log he is lying behind.**
- Every AI line-of-sight ray is hardcoded eye 1.5 / target 1.0, at 17 sites across both AI files.
- The ONLY posture-aware sight code in the game reads **the player's** `is_prone`
  (`enemy_base.gd:977-982, 1007-1013` — sight cap ×0.4, awareness gain ×0.35). **There is no
  AI-side equivalent. That is the finding.**

**The player already has a complete prone system** — `is_prone`, `PRONE_HEIGHT 0.5`,
`PRONE_SPEED 1.0`, sprint and jump blocked, faster suppression decay (`player.gd:44, 64-65,
1554, 1624, 1671, 1694-1695`) — **and the enemies already pay him for it.** The AI gets the cost
and none of the payoff.

**Ship prone without a payoff term and it is a slower crouch that shoots through cover.** That
fails Pillar 1 (believable firefights) on the exact axis the pillar names.

---

## THE LIVE DEFECT FOUND ON THE WAY — and it is not about prone

**A crouching or prone PLAYER keeps his STANDING hitzones.** `HitzoneBuilder._build_static`
(`hitzone_builder.gd:580-595`) parents fixed-offset bands to the body — HEAD at local Y **1.65** —
and `player.gd:1179` builds them once. Its own comment admits it: *"Bands are fixed to the
standing capsule."* `_handle_crouch` (`player.gd:1691-1701`) shrinks the capsule to
`PRONE_HEIGHT 0.5` and moves `collision_shape.position.y`. **It never touches the hitzones.**

So against a prone player: **a round through empty air 1.15 m above him is a fatal headshot**, and
a round through his actual body may find no zone at all. Under the headshot law — headshots kill
EVERYONE, `zone_name_is_fatal` is the authority — this is as severe as damage bugs get, and it is
live right now, in the demo, with nothing to do with this decree.

**Fix it first, on its own, so it is never confused with the prone work.**

---

## THE DECREE — three phases, in this order

### PHASE 0 — the prerequisites (prone is a lie without these)
1. **Player crouch/prone hitzones follow the capsule.** Independent live bug. Ships alone.
2. **Muzzle and LOS origins read posture.** `muzzle_ballistic` / `muzzle_visual` and the AI sight
   rays take the man's posture height instead of a hardcoded 1.35 / 1.5 / 1.0. **This pays crouch
   too, immediately** — it is not prone-only scope.
3. **The stuck watchdog goes blind below 1.0 m/s** (`enemy_base.gd:201-202`, byte-identical in
   `ally_base.gd:67`). `CROUCH_SPEED_CAP` is 1.9, which is why crouch never exposed it. Any real
   prone cap trips it: **a wedged prone man crawls in place forever, animating perfectly** — this
   project's exact recorded bug class.

### PHASE 1 — prone itself
- `CombatPosture.decide()` returns the posture; **`_is_low_posture()` becomes posture-typed at
  both call sites**, and all eleven consumers are re-ruled explicitly.
- **Trigger: `SUPPRESSED` + `suppression >= 0.85` held ~1.2 s; exit at 0.6 (hysteresis); hard 6–8 s
  dwell ceiling.** 0.85 because `_suppression_move_mult` already calls that band *"pinned: barely
  able to shift"* (`enemy_base.gd:1803-1804`). **Never** SEEKING_COVER, ADVANCING, FLANKING,
  RETREATING, or plain COMBAT.
- **Rate-limit prone entry per squad.** One M60 burst crosses every man past the threshold in the
  same tick and no squad-level posture arbiter exists anywhere — the unison face-plant, same
  defect class as the Track B1 unison ally-roll.
- **A prone pose is reachable ONLY through a completed transition**, and the latch and its window
  are written in one statement, always. `ModelActor` has **no finished signal** — use the timed
  window pattern (`enemy_base.gd:1853-1856`). Transitions are **1.833 s**; the posture funnel's
  stability filter is **180 ms** (`enemy_base.gd:460-469`) — prone is the first posture with a
  transition cost and the funnel has none.
- **`test_low_posture.gd:52-59` is a CONTRACT, not an obstacle.** It asserts suppression 0.7 →
  CROUCH on both factions (the 7/23 faction-merge contract). The 0.85 threshold is chosen to sit
  ABOVE it so the contract survives untouched. Add prone cases; change no existing assertion.

### PHASE 2 — DEFERRED, needs art that does not exist
Prone locomotion. There is no clip. Do not fake it with `wounded_crawl` — measured 36° apart, it
reads as a casualty, not a soldier crawling to a firing position.

---

## WHAT IS SACRIFICED

- **Prone men cannot move.** A pinned man goes down and stays down until the pin lifts. That is the
  honest consequence of having no clip, and it is why the dwell ceiling exists.
- **Phase 0 is combat surgery on every man in the game**, done to make one posture mean something.
  It pays crouch too, but the risk is real and none of it is playtested.
- **The devil's advocate did NOT concede.** His case: the aid-station populator beats prone —
  `campaign_state.ward_wounded` still has zero consumers, its art is already in the library, and it
  touches no AI file and no test. **Prone is also not on the Summoner's own verification gate.**
  That case is recorded here because it may still be right; the Summoner ruled prone, and the
  Summoner holds final authority (Law 3).
- **`test_fossils.gd:240-245` scans const/signal/func, not enum members** — an unused `PRONE` is
  invisible to the fossil probe. The register cannot guard this one.

## DRIFT CORRECTED ON CONTACT

`CLAUDE.md` claimed the fossil baseline was `ceiling` 19 / `count` 19. `tests/fossil_baseline.json:3-4`
reads **3 / 3** — the ratchet has been doing its job. Corrected, with both numbers dated. That file
is injected into EVERY session, so it was the drift generator its own text warns about.

Also flagged stale by the council, not yet corrected: `GHOST_CODE_AUDIT_2026-07-25.md:134` and
`production/bible/04_AI_LOCOMOTION.md:38-41`.
