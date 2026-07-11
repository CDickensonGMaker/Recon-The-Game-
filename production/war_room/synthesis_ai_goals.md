# THE DECREE — AI Goals & Behavior Doctrine, both factions (2026-07-10)

Four architects deliberated (`analysis_ai/`); the Summoner answered the doctrine questions directly.
This decree binds both EnemyBase and AllyBase.

## The Summoner's rulings (verbatim intent, now law)
1. **Commitment dial: HIGHLY REACTIVE** — ~1s goal dwells; smoothness comes from input debouncing
   (contact confidence), not long commitments. Interrupt classes still apply.
2. **The squad is a PERSONALITY SPECTRUM, not a doctrine clone.** "In war everyone's goal is to
   survive... there can be men that are truly bad at combat and cower or anchor and complain and
   miss... and total go-getters getting kills. The player leads the push with one or two others;
   the rest sit back suppressing." Smoke + grenades to advance = standard doctrine, with FINITE
   inventory (resupply from the dead / the firebase).
3. **Personality: RANDOM per playthrough** (rolled per man; meta-tuning the squad is later, not now).
4. **Rallying: PRESENCE RALLIES** for Army (and Marines later) — standing near a rattled man steadies
   him; leading from the front is mechanical. **MACV-SOG (DLC): orders override** — the smooth
   special-forces fantasy. (Faction-flavored command doctrine — recorded for the DLC forks.)
5. **Enemy morale: YES, NOW** — Local Force breaks/routs/surrenders under pressure (canon: "Local
   Force breaks, NVA doesn't"); the EnemyData.courage field powers it.
6. **Friendly fire: FULL REALISM** — everyone hurts everyone at full damage. Consequence accepted
   and engineered: both factions gain muzzle discipline (hold fire on friendly-in-lane).

## Council findings ratified (all four converged; evidence in analysis_ai/)
- FACING: double-writer bug — body look_at + model local-yaw-from-world-vector compound (why enemies
  read ~180° wrong, allies nearly right). ONE yaw owner: `global_rotation.y` in ModelActor.set_facing.
- STRAFE: 3 stacked defects — intent_for maps ALL combat movement >0.3 to "strafe" (no aim-walk
  intent exists), MODEL_ALIASES resolves strafe→run_left always, executors live in the strafe band.
- ALLY COVER OBSESSION: structural loops — drift >2.5m releases the claim → instant re-seek;
  _cover_fail_count never resets; no contact clock; SEEK→IDLE 2s thrash; zero hysteresis.
- CORNER PILE: distance-only candidate sort; broker blocks only the same 2m cell.

## The doctrine (implementation spec)
1. **One input, debounced:** contact confidence C (0-1) per brain — builds to 1 in ~0.3s of LOS,
   drains to 0 over ~2.0s blind. GOALS read C and target_last_seen_time; only FIRING reads raw LOS.
   (Deliberately slower than the exposure-accuracy drain so fairness forgives before intent does.)
2. **Short commitments, real interrupts:** goal dwell ~1.0s (Summoner's dial) + incumbent ×1.25.
   Interrupt classes — A (always): took damage, suppression >0.8, target dead, threat <6m, player
   order. C (never): LOS flicker, score wiggle. Rushes complete: SEEK_COVER commits until arrival
   (cap 4s).
3. **Cover is a phase of fighting, not a competing goal:** ally cover-first gets the enemy's escape
   hatches (contact clock <5s, fail-count resets on new contact); arrival LOCKS a 1.5m leash —
   re-anchor inside it, never release-by-drift; suppressed+covered = hunker (never relocate);
   fail-exit goes to COMBAT, not IDLE.
4. **Dispersion:** cover/bound candidate cost = distance + 6.0×claims_within_4m (+3.0×friendlies_
   within_3m for allies). Zero raycasts. Five men fan; no corner piles.
5. **Animation intent policy:** still <0.5 = aim · slow-forward <3.2 = aim-walk (run_forward at
   reduced anim speed until a dedicated clip exists) · ≥3.2 = run · strafe ONLY lateral-and-slow,
   with left/right resolved correctly (run_right alias fixed) · 0.25s intent debounce.
6. **Facing:** ModelActor.set_facing sets GLOBAL yaw; the body no longer look_at's while a model
   drives facing (one owner).
7. **PERSONALITY SPECTRUM (allies):** per-man roll at spawn — courage 0-1, skill 0-1 (random per
   playthrough; roster persistence later). Behavior mapping: LOW courage = anchors deep, rear cover,
   suppressive fire, sluggish orders, complaint barks, accuracy penalty; MID = base of fire; HIGH =
   bounds forward with the player (push-with-player radius), better accuracy from skill. PRESENCE
   RALLY: player within 6m adds +0.25 effective courage (Army doctrine).
8. **ENEMY MORALE (now):** courage-powered break ladder — threat+casualties vs courage: LOW-courage
   (Local Force) men ROUT (drop contact, flee to map edge cover, may throw weapon down = the
   existing surrender path / Chieu Hoi); NVA/sapper courage holds. Uses existing threat_level +
   the new courage field; no new perception work.
9. **FULL-REALISM FRIENDLY FIRE:** ray masks include friendly layers for every shooter; damage paths
   accept friendly hits at full value; BOTH factions check friendly-in-lane before squeezing
   (one cheap ray/angle check at fire time — muzzle discipline) so AI doesn't massacre itself.
10. **Wave spawns (bench):** arrivals placed within 3m of a cover point, fireteams split ≥12m.

## Deferred (beaded, not lost)
- Ally smoke doctrine + finite frag/smoke inventory with scavenge/firebase resupply (needs AI smoke
  throw + equipment plumbing) — the "smoke and grenades to advance" half of ruling 2.
- Roster-persistent personalities + meta squad tuning (ruling 3's "later").
- SOG orders-override command doctrine (DLC fork).
- Real-terrain bench (buildings/ruins/jungle) — next bench build after this doctrine lands.
