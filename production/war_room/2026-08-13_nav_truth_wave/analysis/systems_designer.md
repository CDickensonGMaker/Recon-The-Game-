# SYSTEMS DESIGNER — nav-truth wave (FIX A / B / C), behavioral consequences

Independent analysis, 2026-08-13. Every claim verified against code this session; pointers inline.
Focus: what changes for the siege, the garrison, the squad, and the casualty/intel systems.

---

## 1. FIX A — when the mesh becomes honest

### What the fiction costs today (verified)

The bake's own contract — "the exact colliders move_and_slide() hits, so navmesh and physics
cannot disagree" (`scripts/world/nav_baker.gd:36-41`) — is defeated by `_shape_faces` returning
`concave.get_faces()` raw (`nav_baker.gd:563-566`) while physics runs the same shapes with
`backface_collision=true` (`scripts/world/site_planner.gd:1420-1431`, forced in the repair pass
at `:1481-1490`). Down-facing ground contributes no walkable surface; the flat 174 terrain seat
wins. Every nav consumer inside the FSB box (370 m, `FSB_HALF` 185 at `nav_baker.gd:43`) runs on
that fiction:

- **NavRouter clamps every target to the fictional plane** — cover points, work posts, follow
  stakes all pass through `map_get_closest_point` (`scripts/ai/nav_router.gd:112-115`), and
  civilians clamp their work posts the same way (`scripts/world/civilian.gd:1081-1082`, router at
  `:137`, shared step at `:722`). The stake lands at Y=174 under ground that is really 175.66–175.82.
- **Physics repairs it silently** — `move_and_slide` climbs what nav calls flat, until it can't:
  19 of 37 bunker-post routes physically block on `fb_terrain_mound` (briefing, probe log).

### What improves — and it is mostly the DEFENSE, not the attack

1. **Garrison men reach their fighting positions.** The 37 `work_bunker` fire points
   (28 fighting + 8 MG, `probe_bunker_entry.gd:11-12`) are the posts the promoted garrison
   (`scripts/allies/garrison_defender.gd:20-27`) fights from. Today half their routes grind on
   berm volume and the men arrive late or jam. Honest mesh = honest routes = **defenders on the
   fire steps faster during the siege**. This is the single biggest behavioral delta, and it
   points AT the siege tuning (below).
2. **The "solid but nav-invisible" class shrinks** (his 8/12 playtest: "the AI can get in and
   I can't"). The player's honest physics and the AI's mesh finally agree about the mound.
3. **The siege lane doctrine becomes computed truth.** `siege_director.gd:62-66` declares the
   wire gate the only opening ("the lane is the GATE... a night attack goes through ONE lane") —
   but today nav happily plans paths THROUGH berm volume inside the box. After the fix, berm
   faces steeper than `agent_max_slope` 50° (`nav_baker.gd:327`) are real nav walls and the
   funnel the assault was designed around is what the pathfinder actually produces. Attackers
   inside the wire stop tunneling; the overrun press reads as intended.
4. **The REAP reads better.** Withdrawing men (`REAP_TIMEOUT_S` 90, `siege_director.gd:43`)
   must now flee through real openings — a visible retreat stream out the lane instead of men
   ghost-pathing into the berm until the timeout eats them.
5. **Squad follow over the mound.** Allies and the squad share the same router (ADR-023,
   `civilian.gd:258` records the consolidation); follow stakes near the player on the mound now
   clamp to true ground instead of 1.7 m under his feet.

### What retunes silently (name it before he feels it)

- **Every distance-along-path inside the compound lengthens.** Chords through berm volume become
  climbs or go-arounds. Assault approach OUTSIDE the box is untouched — the ring is 300–500 m
  (`siege_director.gd:19-20`) and off-mesh approach is direct steering by design
  (`nav_router.gd:81-91`) — so the shift concentrates in the final ~185 m and inside the wire.
  Time-to-overrun (`OVERRUN_MEN` 3 inside `INSIDE_MARGIN_M` 6, `siege_director.gd:69-75`) moves
  LATER; the overrun measure itself is positional per-bearing and does not move.
- **Garrison commutes lengthen.** The rotation is marker-driven, not deadline-driven
  (`site_planner.gd:871-876` occupation map; markers harvested at `:1034-1064`), so nothing
  breaks — but fewer men stand AT posts at any given minute and transit reads longer. Atmosphere
  shift, not a defect.
- **Cover-seek near the berm foot changes outcome.** Candidates are 3–6 m rings
  (`enemy_base.gd:126-130`); a candidate across a now-impassable face fails pathing honestly
  where it used to "succeed" on fiction. Two dry searches trigger the retreat VO
  (`enemy_base.gd:1850-1853`) — expect the escape hatch to fire in new places.
- **`filter_walkable_low_height_spans` becomes load-bearing** (`nav_baker.gd:329-332`): the
  buried 174 seat under the mound must be culled as a sub-height span or the map gets a second
  layer for `map_get_closest_point` to mis-choose. The flag is already set; verify it earns its
  comment.
- **Break timing may shift EARLIER.** `BREAK_BASE_RATIO` fires at 42.5% killed
  (`siege_director.gd:29`). Defenders reaching fire steps faster = higher garrison lethality per
  minute = the 45-man siege (`demo_game.gd:87`) can break sooner. His validated read of "the
  assault crests, then breaks" sits directly on this.

### The mint-a-roof risk (the one new lie FIX A can tell)

Double-siding faces makes the TRUE tops of roofs contribute walkable surface for any structure
NOT in `NAV_ROOF_CULL_PREFIXES` (`nav_baker.gd:517-520`). The code itself names the exposure:
the chow hall "needs the same entry and CANNOT have one yet" — no common leading token
(`nav_baker.gd:514-516`). `fb_toc` is also unlisted. Today those roofs contribute nothing
(down-facing); after the flip they may bake walkable and men path onto them — the exact defect
`fb_hootch_roof_` was ignored for on 8/12 (`nav_baker.gd:445-449`). Countervailing arithmetic:
`agent_radius` erosion 0.5 m per side (`nav_baker.gd:45,320`) kills anything under ~1 m wide —
the parapet crest at ~0.9 m erodes to nothing, so **walls do NOT become walkable on top**; broad
flat roofs are the only candidates. Watch the per-region poly count delta in the bake print
(`nav_baker.gd:378-380`) — a large jump is minted roof.

### What he must re-verify, in order (demo gate is a verified-playtest gate)

1. **The siege night end-to-end** — probe at the wire (`PROBE_AT_S` 1395, `demo_game.gd:57`),
   45 men, press through the lane, overrun toast, break, gunships. Watch: garrison men ON fire
   steps, assault timing through the gate, whether the break now beats the overrun. This is the
   validated gate content and BOTH fix A and fix C land on it in the same night.
2. **The garrison day** — the work rotation walking to posts, and specifically the bunkers he
   named 8/12 ("bunkers I placed along the berms that I cannot get into"). The probe proves the
   AI side; his capsule is the fresh-player half of the same test.
3. **Squad follow + his own walk** over the mound, berm crests, bunker steps — anywhere nav and
   physics used to disagree.
4. Mortars/illum/air need no re-verify — no nav consumer in that chain.

---

## 2. FIX B — the casualty-prop taxonomy

### The count is wrong in the tracking docs — measured, not estimated

I parsed the GLB JSON chunk directly
(`assets/world/building models/structures/firebase/fsb_main_v3.glb`): **144 `grunt_*`
`-colonly` colliders**, not 548. That is 18 figures × 8 body parts (head, torso, uparm L/R,
forearm L/R, leg L/R): 7 wounded-display figures (`wounded1`×3, `wounded3/6/9/12`), 3 tending
medics + 2 tended patients, and 6 medical staff (`work_surgeon_N`, `work_scrubnurse_N`,
`work_anesthetist_5`, `work_medofficer_0/1/2`). 176 grunt nodes total; 32 are visual-only.
The morning report's "548 character-part colliders" (`production/MORNING_REPORT_2026-08-13.md:59,148,332`)
is 3.8× the truth — correct it in the same wave (drift law). Note the family is NOT only
wounded men: 88 of the 144 are the medical-complex staff and patients. Same flesh, same ruling.

### Ruling: `soft_cover`. Do not strip.

- **Bullets:** today the blanket-hard tag (`site_planner.gd:1506-1529`; `grunt_` absent from
  `FSB_SOFT_PREFIXES` at `:1501-1503`) makes a wounded man STOP a 7.62 with a spark
  (`bullet_system.gd:226`, `_surface_is_hard` group check at `:240-247`) and no hit reaction —
  a sandbag wearing a bandage. As `soft_cover` the round punches through at 0.8 energy,
  `soft_left` budget 2 (`bullet_system.gd:100-103,232-235`) — flesh, not armor, and the impact
  reads dirt-puff, not spark.
- **Blasts:** this is the sharper lie. A hard-tagged prop that wins the per-blast defeat roll
  contributes 0.0 reach to the 8-point sample (`scripts/autoload/combat_manager.gd:334,354`) —
  the wounded display currently functions as an intermittent BLAST-PROOF WALL (25–50% of blasts,
  `_blast_defeat_chance` clamp `:299-300`). Soft: always leaks 0.6 (`:290,352-353`). A grenade
  should not be stopped by a casualty on a stretcher.
- **Smallest change, exactly one line:** add `"grunt_"` to `FSB_SOFT_PREFIXES`
  (`site_planner.gd:1501-1503`). The existing walk tags every collider; nothing else moves.
  The boot print (`:1528-1529`) is the receipt: expect **589 soft / 1901 hard** (445+144 /
  2045−144).
- **Why not strip from ballistics:** the stop-the-round default is structural — any collider hit
  that is neither a Hitzone nor soft ends the flight (`bullet_system.gd:192,226-236`), so
  "stripping the tag" alone changes nothing; truly stripping means disabling colliders, which
  makes the player and every round ghost through the casualty display AND deletes them from the
  nav walk (`_walk_shapes` skips disabled shapes, `nav_baker.gd:484`). That is Blender-adjacent
  surgery, violates smallest-change, and forfeits the correct current behavior where the props'
  eroded halos make men path AROUND the wounded.

### Nav status — consistent with his fb_int_ ruling

`grunt_` is not in `NAV_IGNORE_PREFIXES` (`nav_baker.gd:455`), so the props are in the bake:
**real in both**, exactly the state his 2026-08-13 ruling demands (`nav_baker.gd:450-454`).
Keep it. The floaters (+6.2–6.8 m) are placement defects, Blender-side, QUEUED not fixed
(briefing constraint). Under FIX A their faces double-side too; the island risk is arithmetically
nil — no body part is 1.0 m wide, and 0.5 m erosion per side (`nav_baker.gd:45`) eats anything
narrower. Verify via poly-count delta, not worry.

### No scoring path counts them — proven, three gates deep

1. Damage requires `has_method("take_damage")` (`bullet_system.gd:192`); props are bare
   StaticBody3D colliders — they take the FX branch, never the damage branch.
2. The ledger increments in exactly one place: `_on_enemy_died`
   (`scripts/missions/field_director.gd:98-113`), fired from tracked `EnemyBase` deaths, gated
   on `patrol_out` and a friendly killer → `MissionState.record_kill()`
   (`scripts/missions/mission_state.gd:14-15`). Props have no died signal and are never tracked.
3. The debrief reads that state only (`scripts/ui/screens/debrief.gd:77`, "bodies buy nothing").
   Intel comes from real enemy corpses per canon, not props. **No path counts a display figure.**

---

## 3. FIX C — snapping cover to the face

### The consumers, walked

- **Enemy:** `_find_cover_point` collects ring candidates and claims them raw
  (`scripts/enemies/enemy_base.gd:2148-2169`); the blocker test carries the face position in
  `hit.position` and throws it away (`:2137-2145`). Arrival epsilon 1.5 (`:1834`), restake
  dead-band 3 m (`nav_router.gd:118`), blocker window 2.5 (`enemy_base.gd:133`). Worst-case a
  "covered" man stands ~4–5 m off the face. Crouch begins within 3.0 of the point
  (`scripts/ai/combat_posture.gd:13`).
- **Ally: shares, does not duplicate.** `_sweep_cover` calls `EnemyBase.cover_blocked_from`
  (`scripts/allies/ally_base.gd:1759-1764`), same offsets (`:1782,1808`), same claim broker and
  crowding (`:1721-1724`; broker at `enemy_base.gd:2040-2064`). One definition — a snap in
  `cover_blocked_from`'s sweep serves both brains.
- **The one drift:** `_find_bound_point` duplicates the ray INLINE (`enemy_base.gd:2107-2113`)
  instead of calling the shared function. Fossil law: the snap change must convert it to the
  shared call in the same change, or bounds silently keep the old geometry.
- **The leap gate is ALLY-ONLY.** `_wall_within` exists only in `ally_base.gd:1559-1571`, gating
  the arrival clip (`:1581`, arrival epsilon 1.4 at `:1576`) and the hold/peek poses (`:1458`).
  Enemies have no wall-lean gate — their improvement is positional only.
- **Suppression:** the covered recovery ×3.0 vs open 0.7 (`combat_posture.gd:25-26`) keys off
  the has_cover STATE, not measured distance — rates don't retune, but the state is now earned
  where the wall actually blocks the man's body, so pinned men visibly disappear behind cover.

### What measurably improves

- **The leap finally fires.** Today: claim up to 2.5 short + arrival 1.4 → wall at up to ~3.9 m
  ≫ the 1.2 gate → clip skipped, proof the shortfall is real. Snapped to face minus pull-back
  ~0.6 m → gate passes. Wall-lean hold/peek poses unlock with it.
- **Men behind walls instead of shadowed short of them.** The eye-ray test passes at 4 m; the
  body does not. At the face, the wall blocks the capsule, and the blast 8-point sample
  (`combat_manager.gd:314-357`) now has real geometry between blast and man — hard cover that
  HOLDS its roll protects at 0.0 reach.
- **Self-correcting overshoot:** the mesh is eroded `agent_radius` 0.5 m off every wall
  (`nav_baker.gd:320`), and NavRouter clamps stakes onto the mesh (`nav_router.gd:112-115`) —
  so even a snap AT the face lands the stake ~0.5 m off it. Pull-back 0.6 m (capsule 0.4 + skin)
  and the erosion agree. Keep the snap's Y at the candidate's foot plane, not `hit.position`'s
  eye height, or the 2 m claim buckets (`enemy_base.gd:2040-2041`) mis-key against old claims.

### Over-tightening risks (the sacrifice ledger for C)

1. **Stacking.** Today's shortfall is ACCIDENTAL DISPERSION. Snapped, candidates from the 12
   ring offsets converge onto the same face; the 2 m claim cell and the <4 m crowding cost
   (`enemy_base.gd:2044-2052`) are the only spreaders left → a line of men at ~2 m spacing.
   Grenade math: casualty radius ~10 m (`scripts/combat/grenade.gd:6-7`) — one M26 catches the
   stack. Enemy grenades already target 8–30 m (`enemy_base.gd:1810-1812`). Don't pre-tune:
   crowding cost is the existing dial; measure stack width first.
2. **Closer to the wall = closer to wall-defeat splash.** When a blast DEFEATS hard cover
   (25–50%, `combat_manager.gd:299-300,334`), the man now eats the 0.6-bled damage from ~4 m
   nearer the seat of the blast. Cover protects more when it holds and punishes more when it
   fails — sharper variance, which is doctrine-compatible (fear) but a changed feel.
3. **The siege was tuned against men shadowed short of walls.** Attackers under garrison fire
   will hug the same faces harder; the assault's silhouette changes with zero constants touched.
   This is the risk HE flagged, and he is not watching today — it ships on probe evidence and
   gets the loudest line in the playtest brief.

### What SFR --cover-probe must show

The probe launches an assault and logs every claim: `[COVER] <nick> CLAIMS ...
d(claim->sandbag)=X d(claim->tree)=Y` and `HOLDS ... man at ...`
(`scripts/levels/support_fire_range.gd:772-778`), with reports at T+3/10/20/30 s and a metrics
dump (`:1453-1467`). SFR builds its own flat arena and sandbag line (`:125`), independent of the
FSB — **it isolates FIX C from FIX A cleanly.**

Record before/after: mean and max `d(claim->sandbag)` over all CLAIMS (expect ~2.5–4 m → ≤1.0 m);
man-to-claim at HOLDS (unchanged, ≤1.4); and man-to-sandbag at HOLDS ≤1.2 m as the numeric proxy
for "the leap gate passes." Post-process claim positions for pairwise spacing — claims <2.5 m
apart per report is the stacking number.

---

## 4. The verification package (hands-off day)

| Fix | Probe | Numbers to record |
|---|---|---|
| A | `tools/probe_bunker_entry.tscn` (boots demo_game — one run carries both passes AND the bake lines) | reachable/OFF-MESH/SEALED of 37 (`probe_bunker_entry.gd:106-107`); capsule pass X of Y (`:172-173`, baseline 18/37); per-block `path_y` vs `ground_y` (`:169-171`, expect path_y ≈ 175.7, chord ≈ 0); from the same log: `[NavBaker] bake done ... verts/polys` per region and `... ms total` (`nav_baker.gd:378-390`) — the bake-cost number, and the poly DELTA is the minted-roof detector |
| A | `tests/test_nav_path.tscn` | PASS + wall time vs the ~10.8 s canary (village-hut bake exercises the shared `_walk_shapes` path — it does NOT bake the FSB, `test_nav_path.gd:40`) |
| A | boot log | `[FSB] 2048 concave shape(s) forced double-sided` unchanged — physics untouched by a nav-source fix |
| B | boot log | `[FSB] ballistic tags:` **589 soft / 1901 hard** (from 445/2045, `site_planner.gd:1528-1529`); floating-collider audit line unchanged (placement queued for Blender) |
| B | code-path proof, no runtime probe | scoring immunity is structural: `bullet_system.gd:192`, `field_director.gd:98-113` — state it in the brief with pointers |
| C | `support_fire_range.tscn -- --cover-probe`, before AND after on the same pair of builds | mean/max `d(claim->sandbag)`; HOLDS man-to-sandbag ≤1.2 m (leap proxy); pairwise claim spacing (stacking); enemy pinned-seconds from the metrics block for drift |
| all | full suite at wave end ONLY | leak column: never convict on one reading (AUDIT-12) |

Any honestly-SEALED post FIX A reveals is a FINDING, not a regression — it goes to the queue as
kit/Blender work, named with its post index from the probe print.

### The playtest brief he gets ("here is what changed and what to eyeball")

1. **Siege night first** — defenders reach fire steps faster; the assault funnels at the lane
   for real; the break may beat the overrun now. Eyeball: does the crest still read as a crest?
2. **The berms and bunkers he flagged 8/12** — AI-side proven by probe; his walk is the other half.
3. **Cover under fire** — men AT sandbags, leaping and leaning; eyeball stacking and lob one
   frag at a claimed line.
4. **Shoot a wounded display** — puff not spark, round carries through; a frag past the aid
   station no longer gets stopped by a patient.

---

## 5. Sacrifices — no free lunches

- **FIX A** buys truth with: doubled nav-source faces for 2048 shapes (async bake, but boot
  time-to-live-mesh grows — measured by the ms-total print, not guessed); possible minted
  walkable roofs on unlistable structures (chow hall, named at `nav_baker.gd:514-516`); honest
  SEALED posts that become queued kit work; and the re-opening of a playtest-validated siege
  night — the demo gate must be re-run by him. That last one is the real price.
- **FIX B** deletes the accidental blast shield the casualty displays were providing (correct,
  but any garrison man who benefited loses it); leaves bullet-hole decals possible on wounded
  men (`bullet_system.gd:227-228`, cosmetic); and ships with the floaters still floating —
  the visual lie survives one more wave, queued to Blender.
- **FIX C** deletes accidental dispersion — stacking and grenade clustering stop being
  impossible and start being a tuning surface (crowding cost is the dial); men eat wall-defeat
  splash from nearer; and the assault's look under fire changes with no constant touched, on a
  day the Summoner is not watching. Mitigation is probe evidence plus the loudest flag in his
  brief, and the discipline that the snap lives in ONE shared definition — including converting
  the inline bound-point ray (`enemy_base.gd:2107-2113`) to the shared call in the same change.
- **The count correction** (548 → 144) costs a tracking-doc edit now, or costs the next agent a
  phantom 4× workload later. Pay now.
