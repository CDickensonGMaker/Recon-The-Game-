# Game Designer — Ally Dressing (GruntRandomizer into the real spawn path)

Lens: Pillar 4 — "the squad is the RPG: named persistent men who improve, wound, rotate home, and die for real."
Code read: `scripts/squad/squad_system.gd`, `scripts/squad/squad_roster.gd`, `scripts/allies/ally_base.gd`,
`scripts/visuals/grunt_dresser.gd`, `scripts/tools/grunt_randomizer.gd`.

## 1. Identity key: name-hash is acceptable, but STORE the face in the roster dict

The decree frames this as hash-vs-save-format-change. That's a false dichotomy. The roster member is a
free-form `Dictionary` persisted by `CampaignState.save_campaign()`, and `SquadRoster.ensure_roster()`
**already back-fills fields added after older saves were written** (`skill_uses`, `xp`, `skills` —
lines 169–176). Adding `member["face"]` / `member["helmet"]` is the established idiom, not a format
change. No migration, no version bump.

**Recommendation: derive deterministically at generation (name-hash is a fine derivation), then write
it into the member dict.** Back-fill for old saves = derive from `hash(name)` once and store. This gets:

- **Stability by record, not by recomputation.** Pure name-hash means his face is an emergent property
  of a function that must never change. If the atlas gets re-cut, `FACE_COLS` changes, or GDScript's
  `hash()` changes across an engine upgrade (it has before), every veteran in every campaign silently
  gets a new face. That is a Pillar 4 wound: the player *knows* Doc's face. Stored value survives all
  of that.
- **Collisions become a non-issue.** 250×250 = 62,500 names; duplicate names in a 5-man roster are
  ~0.016% per squad — but over a long campaign with KIA replacements, a rookie CAN roll a dead man's
  name. Pure hash gives him the dead man's exact face: an accidental ghost. Stored-at-generation
  lets us keep it (it's actually good flavor) or nudge it — our choice, not the hash function's.
- **Replacements after death**: `ensure_roster()` generates rookies with the mission-seeded RNG; face
  assigned at `generate_member()` time and stored is stable from his first patrol forever. Correct.
- **Rotation home** isn't implemented yet (only KIA replacement exists), but a stored face means a
  returning veteran system gets recognizability for free.

If the Arbiter still rules "no new roster keys," name-hash alone is livable — but pin the derivation
(`hash(str(m.name)) % 70`) in an ADR as a frozen contract, because it becomes save data in disguise.

## 2. Helmet: identity-stable, yes — it is the LONG-RANGE identity channel

At PSX resolution a face reads at conversation distance; the helmet graffiti reads at gameplay
distance. If faces are identity but helmets reroll, the player's actual in-mission recognition token
churns every insertion — worse than useless for Pillar 4. "BORN TO KILL" on the same man every
mission IS the Full Metal Jacket fantasy: graffiti is self-authored characterization, and a man does
not repaint his pot weekly.

Keep **gear** (ruck/radio toggles) per-mission — that's loadout, not identity, and mission-to-mission
kit variation is correct flavor. The line: **skin and paint are the man; canvas and steel he carries
are the mission.**

One earned exception worth designing later (separate bead): helmet *upgrades* as a service-time badge
(e.g. `m1_veteran` unlockable at SGT+) — rank_for() already tracks missions. That's identity
*evolving*, which is Pillar 4 at its best. Do not reroll; do let it ratchet.

## 3. Pillar 4 harm in (b)/(c)/(d)? None — with two flags

- **(b) Unnamed/bench random faces**: no harm; benches aren't the RPG. Flag: if a **rescued POW** can
  ever join the roster as a named man, his face must be captured into his member dict at recruitment
  (the face he had when you carried him out), not rerolled. Design that seam now, one line.
- **(c) VC/NVA exclusion**: correct and mandatory. A US face sliding onto a guerrilla is a Pillar 2
  (atmosphere) violation of the highest order — worse than 70 identical enemies. The atlas cell map
  bead is the right gate. No Pillar 4 stake: enemies are not persistent named men.
- **(d) Civilians**: correct, out of scope.
- **Real wrinkle the decree missed**: `WEAPON_BODY_POOLS["m16a1"]` includes `us_grunt_v3`, which
  `GruntRandomizer.NON_ROLES` marks as **not dressable** (no stock-helmet contract). A rifleman who
  draws the v3 body gets a face but no helmet swap — or a dresser warning. Either drop `us_grunt_v3`
  from the squad pool when this ships, or explicitly dress him face-only. Decide it; don't discover it.
- **Tech risk to name in the decree**: the helmet hangs off a `BoneAttachment3D` on the Head bone.
  Verify it rides the ragdoll/gib path (`GibSystem.explosion_kill`, `start_ragdoll`) — a named man's
  helmet floating at spawn height over his corpse would be a gore-contract regression on the exact
  men the player cares about.

## 4. The set_sprite early-return: yes, it eats identity — force-rebuild is the wrong fix, dress-after is the right one

Confirmed gap. `spawn_ally()` runs `_ready()` → `_setup_visual()` with defaults (`us_grunt_v3`/`m16a1`)
**before** `ally.member` is assigned; `SquadSystem.setup()` then calls `set_sprite(unit, weapon)`
(line 47), which early-returns when unit+weapon match the default (ally_base.gd:232-233). Any rifleman
who draws `us_grunt_v3` + `m16a1` skips the rebuild — if dressing is hooked into the rebuild, he is
the one man in the fireteam with the stock face. Guaranteed to happen; the pool makes it a 1-in-3 draw
per rifle slot.

**Don't force-rebuild.** Dressing does not need one: `GruntDresser.dress()` mutates materials and
hangs attachments on a live actor. The clean shape is a separate explicit step after MOS/body
assignment — `set_sprite(unit, weapon)` then `dress-from-member` on whatever `sprite_actor` exists,
whether or not a rebuild happened. This keeps `set_sprite`'s early-return (a legitimate rebuild
guard), keeps dressing idempotent-by-contract, and makes the call order self-evident in
`SquadSystem.setup()`. If implementation instead folds dressing into `_setup_visual()`, then the
early-return must become identity-aware (rebuild when pending dress differs) — more coupling, same
result, worse legibility. Cost of the explicit step: one extra call site. Take it.

## Sacrifices named

- Stored face key = one more roster field to back-fill (trivial, established pattern).
- Identity-stable helmets sacrifice per-mission visual churn — accepted; churn was anti-identity.
- Enemies stay clone-faced until the atlas cell map lands — accepted, correct sequencing.
