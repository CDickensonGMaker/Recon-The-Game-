# SESSION HANDOFF — 2026-07-30, MIXAMO ANIMATION WAVE

Six commits, `0b7a1707..1d5740b1`, all pushed. Adds to `SESSION_HANDOFF_2026-07-30_NIGHT.md`.

**NOTHING HERE IS PLAYTESTED.** 39 clips and ~16 wiring changes, none judged by eye. Parse scan
clean (`godot --headless --path . --editor --quit`, 0 errors) — that proves the code compiles,
not that a single man moves correctly.

---

## START HERE (next session)

1. **Open the project in Godot 4.7 once.** `anim_library.glb` went 124 -> 163 clips and needs a
   reimport.
2. **Do HIS GATE below before building anything.** It is a verification pass, not a feature.
3. Then pick up `TO DO` in order. §2 (the aid station) is the largest reward for the work.

**Do not launch the game to "check" things — he drives testing.** Parse-check with
`godot --headless --path . --editor --quit` and count `SCRIPT ERROR|Parse Error|Compile Error`.
`--check-only --script` cannot judge any file touching an autoload and reports false errors.

**Uncommitted and HIS, untouched all session — do not sweep these into a commit:**
`assets/player/arms/fp_arms_rifle.blend`, `assets/player/viewmodels/mosin_fp.glb`, the huey
blends, `assets/ui/menu_bg.png`, the weapon `.tres` edits, the m26 grenade deletions. A broad
`git add` swallowed his files once already (recorded in the 7/30 NIGHT handoff). Stage by path.

---

## THE ONE FINDING THAT MATTERS

**Mixamo clips are DROP-IN on `PSXRig`.** 41/41 bone names shared, object scale 1.0 both sides,
0 unmatched either way — measured by `tools/probe_mixamo_fit.py`. `build_ragdoll_scene.gd:3` said
so all along ("Every character shares Mixamo bone names"). **There is no retarget step.** The
previous handoff's claim that retargeting was the bottleneck was wrong and had been holding this
work back. A batch is now ~5 minutes, most of it the GLB export.

`anim_library.glb`: **124 → 163 clips, 14.44 MB.**

---

## YOUR GATE — verify before anything else is added

Your words: *"i need to verify all the animations we're making so i shouldn't go super crazy."*
**Nothing below gets built until this is done.** Highest-value looks, in order:

1. **Sapper planting** — `sapper_room.tscn`, `[H]`. New `plant_charge` pose replaces the
   `mortar_dropper` stand-in.
2. **A camp at rest** — the VC camp roles carry 9 new clips, and two bug fixes ride on them.
3. **A village at work** — villagers now key off `scheduled_action()`, not pose.
4. **Take a solid non-lethal hit** — `stumble_hit`. And get shot from the LEFT: that death
   direction did not exist before.

**Two live defects were fixed on the way — confirm both read right:**
- the camp `sleep` role played `laying_breathless`, the DOWNED/dying clip. **Every sleeping man
  read as a casualty.**
- the loop-mode heuristic is a prefix match and missed nearly every ambient clip (`sitting_idle_b`
  is not `sitting`; `prone_idle` does not begin with `idle`). All would have **played once and
  frozen the man where he stood.**

---

## TO DO — ranked (§1 mostly done; §2-§6 not started)

### 1. Wire the clips with no caller — MOSTLY DONE 2026-07-30

**Wired:** `sentry_scan` / `crouch_scan` / `nervous_scan` -> the camp `guard` role, and
`kneeling_idle` -> `cook`. Guards also needed a fix to fire at all: `_assign_guards` never set
`work_pos`, so a guard pose could never have played (the schedule loop skips guards). His post is
now his station.

**STILL UNWIRED, and deliberately - both need a trigger EVENT that does not exist yet:**
- `salute` — wants a greeting/rank moment. There is no officer-encounter event to hang it on.
- `signal_move_up` — a one-shot beckon; wants a fireteam leader ordering a bound. Inventing a
  caller would mean inventing the behaviour, which is a design call, not wiring.

The three scans are **unarmed body language**. On a man holding a rifle the weapon follows his
hand but hangs at an odd angle, because the pose never accounted for it. Either accept that read
or use them as BASE clips for a weapon-family bake (§5) — one hold makes them armed.

**The guard fix is worth a look on its own:** the role silently did nothing before — no error, no
warning — so any camp guard you watched was running the plain state map, not a guard pose.

### 2. The aid station — a whole system keeping score with nobody watching
`campaign_state.ward_wounded` grows from real casualties, caps at `WARD_BEDS_MAX`, and has
**ZERO consumers outside `campaign_state.gd`** (measured). The ward is a number and an empty
building. No man is spawned in a bed, at a desk, or over a casualty.

A populator reading `ward_wounded` would light it up, and the art is mostly already here:
- wounded in cots → `laying_idle`, `sleeping_laying`
- casualty being worked on → **`medic_treat_receive`** (this is the consumer it lacks today)
- doc working → `medic_treat_give` (currently only on the squad revive)
- **officer at a desk → NOTHING. The one genuine art gap.** Mixamo has candidates
  (`Working On Device`, clipboard/writing sets) — a small pull whenever wanted.

Pairs directly with the casualty-ledger decree: the ward filling from real fights is the point.

### 3. The prone posture
`prone_idle` · `crouch_to_prone` · `prone_to_crouch` · `prone_firing_rifle` are all in the GLB.
What is missing is a **prone posture the state map can select**, with speed caps and in/out
transitions. `wounded_crawl` IS wired (the `crippled` intent, which used to be
`injured_walk_backwards` — crippled men moonwalked). Engine work, not art work.

### 4. The variety plan — PARKED, see `ANIM_VARIETY_PLAN.md`
Your brief: calm / concerned / alert / combat registers for walking, plus cover-seeking, stealth,
covering fire, cowering under fire. **You are not asking for more clips — you are asking for the
same clip in more registers.** Locomotion has exactly one today, which is why the world reads
samey however many clips get added.

`tools/make_ambient_variants.py` implements the mechanical half (SPLICE / PHASE / RETIME) and
**HAS NEVER BEEN RUN** — its header says so. The engine half (a register axis on
`sprite_state_map.gd`) touches every man in the game: **War Room item, not a quiet edit.**

Cheapest first move when it reopens: **PHASE**. Five men on one walk clip march in lockstep and
read as one animation; phase-offset they read as five men. No new motion at all.

### 5. Weapon families — DEFERRED by you ("that's stuff we can do later")
`__mg` / `__launcher` / `__bolt` are empty; the RPD gunner and RPG man hold their weapons like
rifles. Route when reopened: **one arms-only hold delta per family → all 9 clips via
`bake_family_clip.py`, headless.** Only the hold needs a human — measured: nothing in the library
has a bulky two-handed grip to lift (`gun_loader` span 0.702 m, identical to `idle_unarmed`).

### 6. Housekeeping
- **Judge the 4 controversial clips before wiring**: `standing_arguing`, `briefing_group`,
  `telling_secret`, `sitting_talking`. Modern American social body language — open-palm
  gesturing, casual weight shifts. On a VC camp or a village elder they may read as businessmen
  in costume. Everything else pulled is posture-neutral.
- **Two tools still point into the deleted `art_source/`**: `tools/assemble_sheets.py`
  (sprite_frames — the sprite renderer died with ADR-001, likely a fossil) and
  `tools/export_grunt.bat` (already recorded broken in `GHOST_CODE_AUDIT_2026-07-25`).
  Fossil-law triage, not cleanup.
- **Library size**: 8.5 → 14.44 MB, mostly two very long clips (`briefing_group` 1401 frames,
  `sitting_talking_b` 1350). Trimmable if it ever matters.

---

## PIPELINE — how to add clips next time

Mixamo MCP attaches over CDP to a REAL Chrome window. Google refuses SSO in an automation-flagged
browser, so the old headless-profile design could never work and is deleted.

1. Double-click `~/Desktop/mixamo_login.bat` (real Chrome, `--user-data-dir=C:\mxlogin
   --remote-debugging-port=9222`). Sign in once; it persists. **Leave the window open**, then
   `/mcp` to reconnect.
2. Download FBX (`fbx_7.4`, 30 fps, no skin) into `assets/shared/mixamo_clips/` —
   **the filename stem IS the house clip name.**
3. `blender -b --factory-startup -P tools/import_mixamo_clips.py -- --src assets/shared/mixamo_clips
   --out assets/shared/mixamo_staging.blend`
4. `sync_clips_into_library.py --bones-only` → `export_anim_library.py` (~4 min, slower as it grows)
5. **Add every held pose to `_LOOP_NAMES` in `model_actor.gd`** or it plays once and freezes.

**`art_source/` is a FORBIDDEN path — collapsed this session, never to be recreated.** Sources
live in `assets/` beside what they feed. MCP quirks: a zero-result search TIMES OUT rather than
returning empty; `select_animation` only sees the current page, so `list_animations` first every
time; parallel calls fight over the one browser page.

Mixamo ids for all 39 clips: `ANIM_WISHLIST.md`.

---

## OPEN THE SESSION WITH THESE — his rulings, in plain words

Per his standing practice: surface the decisions only he can make, glossed, before building.

1. **The four social clips — keep or cut?** `standing_arguing`, `briefing_group`,
   `telling_secret`, `sitting_talking` are modern American body language (open-palm gesturing,
   casual weight shifts). `sitting_talking` is already live in the VC camp `talk` role because
   that role had nothing at all. The other three are in the library with no caller. **Watch a VC
   camp at the `talk` hour and rule.**
2. **The aid station — build the populator?** It is the biggest reward on the list and the ward
   has been keeping score with nobody watching. Needs one small art pull (an officer at a desk).
3. **A guard's rifle hangs oddly** while he scans, because the scan clips are unarmed. Accept it,
   or does this move the weapon-family hold up the queue?
4. **`salute` and `signal_move_up` need trigger events** that do not exist — an officer
   encounter, a leader ordering a bound. Are those behaviours he wants, or should the clips sit?
5. **Two dead tools** point into the collapsed `art_source/`: `tools/assemble_sheets.py` (the
   sprite renderer died with ADR-001) and `tools/export_grunt.bat` (already recorded broken).
   **Fossil-law triage: delete, or is either still wanted?**

## WHAT NOT TO DO

- **Do not add more clips before his verification pass.** He said it plainly: *"i need to verify
  all the animations we're making so i shouldn't go super crazy."* More unverified clips make the
  pass harder, not the game better.
- **Do not recreate `art_source/`.** Collapsed this session. Sources live in `assets/` beside what
  they feed. A path that merely LOOKS conventional is not evidence it is alive — check first.
- **Do not run `tools/make_ambient_variants.py` and trust the output.** It has never been run.
  Dry-run it and read the loop-seam measurements first.
- **Do not add a register axis to `sprite_state_map.gd` quietly.** It touches every man in the
  game — War Room item.
