# THE TECHNICAL DIRECTOR — PROJECT DRIFT

**Council:** The Drift Council, 2026-07-13
**Domain:** repository integrity · asset pipeline · build health · the process vector
**Method:** every claim below is backed by a command run against the live repo. Where the briefing
and the repo disagree, **the repo wins and I say so.**

---

## FINDINGS

### F0 — THE BRIEFING UNDERCOUNTS THE DAMAGE BY 8×. (The headline.)

The briefing says the restructure "swallowed 236 MB of derived art." It did not. It swallowed
**1,940 MB of new large blobs**, for a **net tracked-tree growth of 1.66 GB**.

```
$ git ls-tree -r -l origin/audit-fixes | awk '{s+=$4} END {print s}'   -> 1.26 GB
$ git ls-tree -r -l HEAD              | awk '{s+=$4} END {print s}'   -> 2.89 GB
                                                            DELTA     -> 1,663 MB
```

New blobs >20 MB that are **not on origin** — 19 files, 1,940 MB:

| Size | File | Blocked? |
|---|---|---|
| 217.4 MB | `_backups/gear_armory_BEFORE_civsplit.blend` | **>100MB HARD BLOCK** |
| 217.4 MB | `_backups/gear_armory_BROKEN_STATE.blend` | **>100MB HARD BLOCK** |
| 129.3 MB | `assets/us/characters/us_base_v3.blend` | **>100MB HARD BLOCK** |
| 118.9 MB | `assets/reference/review/lineup_review.blend` | **>100MB HARD BLOCK** |
| **90.0 MB ×10** | **`assets/civilians/characters/civ_*.blend`** | **the briefing never saw these** |
| 90.0 MB ×2 | `assets/us/characters/us_pilot_{white,black}.blend` | ditto |
| 67.7 MB | `assets/us/characters/satchel_m3.blend` | ditto |
| 62.3 MB | `assets/us/characters/gear_armory.blend` | ditto |
| 47.3 MB | `assets/civilians/characters/civ_anim_workbench.blend` | ditto |

The briefing found the four files that trip GitHub's *hard* limit. It missed **~1.2 GB of 50–90 MB
files that trip GitHub's warning threshold and bloat the repo forever.** The civilians alone are
900 MB, and they were sitting behind `.gitignore: art_source/characters/civilians/`. Same mechanism,
7× the volume. **The briefing's P0 is real but its number is wrong, and the wrong number would have
produced a wrong fix** ("delete 4 files and push") that leaves 1.2 GB of permanent bloat in the
history and *still* costs the project its source art (see F1).

### F1 — THE REAL P0 IS NOT THE PUSH. IT IS THAT THE TRUTH SOURCE IS GONE.

`art_source/` was deleted from disk. The **tracked** files inside it are recoverable from `origin`.
The **gitignored** files inside it are not — and the gitignored files were the *authoring* files.

```
$ ls art_source/                            -> DOES NOT EXIST ON DISK
$ find . -iname "gear_library*.blend"       -> (nothing)
$ find . -iname "us_grunt_v2.blend"         -> (nothing)
$ git rev-list --objects --all | grep "characters/locker"   -> (nothing — NEVER TRACKED)
```

| File | Role | Tracked? | On disk? | Status |
|---|---|---|---|---|
| `art_source/characters/locker/gear_library.blend` | **THE LOCKER** — every hand-authored gear piece. Read by `make_civilians.py`, `make_gear_armory.py`, `make_rto.py`, `make_civilian_anims.py` | **NEVER** (gitignored `characters/locker/`) | **NO** | **LOST.** Only an *older* snapshot survives: `art_source/characters/base_psx/gear_library.blend` @ `12a14bb` (85 MB, "batch 1: 12 pieces"), deleted at `d6ae7cd`. |
| `art_source/characters/locker/satchel_medic.blend` | medic bag, read by `make_medic.py` | **NEVER** | **NO** | **LOST.** No git object under any path. |
| `art_source/characters/us_troops/us_rto.blend` | the RTO variant source (bead `cn68`) | **NEVER** (gitignored `characters/us_troops/`) | **NO** | **LOST.** Only the `us_rto.glb` export survives. |
| `art_source/characters/base_psx/us_grunt_v2.blend` | **THE ROOT SOURCE** of the whole US lineage — `make_base_v3.py`'s declared `SRC` | yes | **NO** | **Recoverable** — `git show origin/audit-fixes:"art_source/characters/base_psx/us_grunt_v2.blend"` (94,079,010 bytes). |
| `art_source/characters/base_psx/vc_guerilla_v2.blend` | VC root source | yes | yes (moved) | safe |

**The consequence is the whole council's crux.** `.gitignore` lines 31–35 assert:

> *"us_base_v3.blend is a pure function of us_grunt_v2.blend + tools/make_base_v3.py."*

That is **now false**. `make_base_v3.py:37` reads
`SRC = assets\us\characters\us_grunt_v2.blend` — **which does not exist on disk.** And every
downstream generator reads the locker, which does not exist at all.

**Nothing in `assets/` is derived any more. It is all de-facto irreplaceable source.**
The 900 MB of civilians that git just swallowed were labelled DERIVED — and they are now the *only*
copies, because their generator cannot run. **If you gitignore them today to fix the push, you
delete the game's civilian cast.**

### F2 — THE PUSH BLOCK IS CONFIRMED, AND IT IS CHEAP TO FIX. (Briefing correct.)

```
$ git ls-tree -r -l origin/audit-fixes | awk '$4>100000000'   -> (empty)   # zero on origin
$ git ls-tree -r -l HEAD               | awk '$4>100000000'   -> 4 files
$ git status -sb                                              -> ahead 2
```
All four >100 MB blobs are **new objects introduced by the two unpushed commits, and by nothing
else.** Verified against the full origin object set:
```
cb63dc10… _backups/gear_armory_BEFORE_civsplit.blend  : NOT ON ORIGIN
12237fe1… _backups/gear_armory_BROKEN_STATE.blend     : NOT ON ORIGIN
9378715f… assets/us/characters/us_base_v3.blend       : NOT ON ORIGIN
2715050c… assets/reference/review/lineup_review.blend : NOT ON ORIGIN
```
Blame is split across **both** unpushed commits — this matters, because "just fix the restructure"
is not enough:
- `53c903d` — the commit titled ***"cleanup"*** — **ADDED the two 217 MB backup blends** (`A
  art_source/_backups/gear_armory_BROKEN_STATE.blend`). A cleanup commit that added 434 MB.
- `615ddd0` — the restructure — **ADDED** `us_base_v3.blend` and `lineup_review.blend` (status `A`,
  not `R`: they were previously untracked-because-ignored) and moved the backups to `_backups/`.

`.gitignore` was **not touched by either commit** (`git diff origin/audit-fixes..HEAD -- .gitignore`
is empty). The Arbiter's phrasing is exactly right: *the rule did not fail, the rule was walked out
from under.* And note **the ignore file still names `art_source/` paths that no longer exist** — it
is now a document that protects nothing.

### F3 — `.git` IS 4.8 GB, BUT ONLY 508 MB OF IT IS REAL. (Briefing's number is right, its
implication is wrong.)

```
$ git count-objects -vH
count: 9251          size: 4.21 GiB     <- LOOSE
in-pack: 13455       size-pack: 507.68 MiB
```
**4.21 GB of the 4.8 GB is loose objects** — the un-gc'd remains of the last two days of blend churn.
The actual packed history is **508 MB**. This is not a permanent 4.8 GB problem; it is a `gc` away
from being a ~600 MB problem *once the offending blobs are unreachable*. **Do not let anyone propose
a pushed-history rewrite on the strength of the 4.8 GB number. It is 90% garbage, not history.**

### F4 — THE RESTRUCTURE BROKE 27 TOOL SCRIPTS, NOT ONE. (Briefing's P1 is 1/27th of the truth.)

The briefing names `tools/make_jungle_patches.py`. The real count:

```
$ grep -rl "art_source" --include=*.py --include=*.ps1 --include=*.bat tools/   -> 27 files, 42 hits
```
`add_variants · assemble_sheets · bake_family_clip · bake_gun_wood · build_sprite_stage ·
build_weapons_vc · catchup_farmer.ps1 · export_anim_library{.py,.bat} · export_edited_blend ·
export_grunt.bat · export_us_grunt_v2 · export_vc_guerilla{.py,.bat} · finish_units.ps1 ·
fit_webbing · fix_unit_files · make_civilian_anims · make_civilians · make_gear_armory ·
make_gear_library · make_medic · make_rto · make_satchel · make_soldier_lineup · overnight_run.ps1 ·
render_sprite_sheets · sync_anim_library`

The commit message claims *"30 tool scripts re-pathed."* What actually happened is worse than "not
re-pathed": several were **half** re-pathed. `make_civilians.py` reads
`BASE = assets\us\characters\us_base_v3.blend` (new, correct) **and**
`LOCKER = art_source\characters\locker\gear_library.blend` (dead). It *looks* migrated. It will fail
at line 437, after opening the base, with a path that no longer exists. **Half-migrated is more
dangerous than untouched, because it defeats a grep-and-eyeball review.**

Also still live: 3 GDScript files + `make_jungle_patches.py` + `make_jungle_vegetation.py` +
`make_medic.py` reference the deleted `assets/models/` tree (8 hits).

### F5 — `project.godot` IS CORRUPT, AND HAS BEEN SINCE `8fb613e`.

```
config_version=5
"ï»¿config_version"=5
"Ã¯Â»Â¿config_version"=5
```
Two garbage keys. A script wrote `project.godot` with a UTF-8 BOM; Godot parsed the BOM bytes as
part of the key name — and then it happened **a second time**, re-encoding the first corruption
(`ï»¿` → `Ã¯Â»Â¿`). Introduced by `8fb613e "Retire dummy_lab and combat_lab"`
(`git log -S 'ï»¿config_version'`). Harmless today. It is the **fingerprint of an automated writer
that nobody read the output of** — which is the entire subject of this council. Delete both lines.

### F6 — PERF: STILL UNGATED, AND EVERY FPS NUMBER WE HAVE IS MEASURED AT 77% RESOLUTION.

Answering the charge directly (bead `mhfv`):

- **`rendering_method` is STILL UNSET.** `grep -rn "rendering_method" project.godot` → nothing.
  `[rendering]` (line 290) contains `default_texture_filter`, `use_debanding`, `scaling_3d/*`,
  `mesh_lod/*` — **no `renderer/rendering_method`.** The engine silently defaults to Forward+
  (`config/features=PackedStringArray("4.7","Forward Plus")`). The restructure did not touch it.
  The 4.6→4.7 bump is *still uncommitted* in the working tree.
- **There is still no gating FPS number.** `tests/perf_probe.gd:58` **prints** `PERF SUMMARY: avg=…`
  and asserts nothing. `run/max_fps=120` is a *cap*, not a gate. Nothing in the suite turns red on a
  frame-rate regression.
- **NEW — and this is a truth-law problem nobody has recorded:** `[rendering]
  scaling_3d/mode=1, scaling_3d/scale=0.77` — FSR upscaling at **77 % render resolution** — was
  introduced by `c17c1fe "NS04: perf gate PASS avg 35.6 (was 4.5) … 0.77 render scale"`.
  **Every FPS number this project has ever quoted — the 19–25, the "40–41 FPS on 4.7" in `mhfv`'s
  notes — was taken at 77 % resolution, and neither the bead, the charter, nor `GAME_GUIDE` says so.**
  We are not at 40 FPS. We are at 40 FPS *with a 23 % resolution discount already spent*. The
  headroom is smaller than the ledger claims. **This must be written into `mhfv` before anyone
  A/B's a renderer against it, or the A/B is measuring a lie.**

### F7 — THE PROCESS VECTOR, MEASURED.

**The restructure — the single most destructive commit in this repository's history — has no bead
and no War Room.**

```
$ bd list | grep -iE "restructur|asset tree|art_source|blend|lfs|repo"   -> (empty)
$ ls production/war_room/                                                -> briefing_grunt_not_ghost,
   briefing_destructible_jungle, briefing_ai_goals, briefing.md … NO briefing_restructure, NO synthesis
```
It moved 1.66 GB, deleted the source tree, broke 27 tools, and destroyed three irreplaceable
authoring files. It was convened by nobody, blocked by nobody, and beaded nowhere. **The standing
law in `CLAUDE.md` — "the War Room is the default process for ANY change" — was simply not applied
to the largest change of the day.**

**The cadence is the tell** (`git log --date=format:"%m-%d %H:%M"`):

| Time | Commit |
|---|---|
| 07-13 00:14 | `b078f8a` BRIEFING: THE GRUNT, NOT THE GHOST |
| 00:17 | `3f11b58` ART-AHEAD WIRING |
| 00:19 | `750a677` **DECREE … *awaiting ratification*** |
| 00:26 | `2f2aab9` **us_grunt_v3 IS LIVE** ← shipped **7 minutes** after a decree that was *awaiting the Summoner's ratification* |
| 00:34 | `8af9deb` **STOP: us_base_v3 fails its own bone_attach gate. 15 props displaced up to 1.8m** |
| **08:09** | `bcda3cc` **CORRECTION: my P0 was a FALSE ALARM** ← **7½ hours** of a live P0 that never existed |
| 15:08 | `53c903d` "cleanup" (+434 MB) |
| 15:22 | `615ddd0` restructure (1.66 GB, 27 tools broken) ← **14 minutes** after the "restore point" |

**The vector is not the phone. The vector is that the phone removes the read.**

A phone can transmit *approval*. It cannot transmit *review*. You cannot read a 4,000-file
`--name-status` on a phone; you can only type "yes". Every failure above is a failure of **reading**,
not of judgment:

- `8af9deb` — a red gate was **believed** instead of interrogated. The gate (`bone_attach.verify_all`,
  asserts `matrix_world == IDENTITY`) is a **locker contract**, and it was pointed at a **non-locker
  asset** (`us_base_v3`'s gear was cut out of the joined mesh by `make_base_v3.py` and legitimately
  carries a non-identity transform). Thirty seconds of *reading* the gate would have killed the P0.
  Nobody read it. A P0 shipped, and stood for 7½ hours.
- `615ddd0` — the commit **honestly reports** the verification it ran: *"headless reimport clean …
  every character still loads."* **That verification was true and completely beside the point.** It
  proved Godot could still import the tree. Nobody asked git whether the tree could still be
  *pushed*. **The commit verified what it was thinking about, not what it broke.**

In fairness to the record — **ADR-015 was honoured on the *close*.** `bd show w66i` closes with real
measurements (hip coords, belt cluster distances, helmet z). The law failed on the **alarm**, not on
the close. The gap in ADR-015 is that it governs *closing* a bead and says nothing about *opening*
one. A false P0 costs a night.

**Accretion, measured** — the debris this speed leaves behind, all currently tracked or on disk:
`_backups/gear_armory_BROKEN_STATE.blend` · `_backups/gear_armory_BEFORE_civsplit.blend` ·
`_backups/weapons_us_BEFORE_markers.blend` · `assets/us/characters/_archive/us_base_v3_DUPLICATE_from_us_troops.blend`
· `_us_base_v3_STALE_BACKUP.blend` (pushed) · `assets/us/characters/_archive/` (4 files). Half a
gigabyte of fear-of-loss, and **it was justified fear** — F1 proves the loss was real. The backups
are not paranoia. They are the only reason the gear survived at all.

---

## THE BLEND POLICY

### The enumeration (the crux)

Derived-vs-source, established by reading each generator's `open_mainfile` / `save_as_mainfile`
pairs — **not by reading the .gitignore's claims about them.**

#### TIER S — TRUE SOURCE. Hand-authored. No generator produces it. **Irreplaceable.**
| File | Why it is source | State |
|---|---|---|
| `us_grunt_v2.blend` (90 MB) | **the root of the entire US lineage.** `export_us_grunt_v2.py` only *exports* it. Nothing writes it. `make_base_v3.py:37` names it `SRC`. | **NOT ON DISK** — restore from `origin` |
| `gear_library.blend` (the LOCKER) | `make_gear_library.py` seeded batch 1; **Caleb hand-authored into it after**, and `make_gear_armory.py:183` *writes back to it* | **LOST** — only the 85 MB `12a14bb` snapshot survives |
| `vc_guerilla_v2.blend` (55 MB) | no generator; `export_vc_guerilla.py` only exports | safe |
| `anim_library.blend` (9 MB) | 100 hand-authored clips; `sync_anim_library.py` syncs *from* it | safe at `assets/shared/` |
| `base_human_rigged.blend` · `arms_rig.blend` · `fp_arms_rifle.blend` · `semi_auto_rifle_arms.blend` | hand rigs | safe |
| `weapons_us.blend` · `weapons_v1.blend` | `append_gun.py` *appends into* them | safe |
| `helmet_v3_fitted.blend` (12 MB) · `grunt_head_parts.blend` (12 MB) | no generator found | **`helmet_v3_fitted` is DELETED in the working tree, uncommitted** |
| `satchel_m3.blend` (68 MB) | `make_satchel.py` writes it, but *from* the lost locker | **DELETED in the working tree, uncommitted** |
| `gear_armory.blend` ×2 (62 MB tracked + **52 MB UNTRACKED at `assets/us/props/`**) | the locker's only surviving descendant; **Caleb has it open and modified right now** | **the 52 MB one is UNTRACKED — one `git clean -fd` from oblivion** |
| `us_v3_soldier_lineup.blend` (49 MB) | Caleb's live work, 16:14 today | **UNTRACKED** |
| `caleb_cower_pose.json` · `caleb_handsup_pose.json` · `caleb_work_pose.json` | **Caleb's hands. The most irreplaceable bytes in the repo, and the smallest.** | tracked ✅ |
| `civ_anim_workbench.blend` (47 MB) | the file those poses are baked into | tracked |
| `emplacements_batch2` · `ruins_batch1` · `civilian_props` · `village_props` | hand-modelled | safe |

#### TIER D-BROKEN — labelled DERIVED, but **the generator cannot run.** Treat as SOURCE until proven.
| File | Generator | Why it cannot run |
|---|---|---|
| `us_base_v3.blend` (129 MB) | `make_base_v3.py` | `SRC = us_grunt_v2.blend` **not on disk** |
| `civ_*.blend` ×10 (**900 MB**) | `make_civilians.py` | `LOCKER = art_source/characters/locker/gear_library.blend` — **LOST** |
| `us_pilot_{white,black}.blend` (180 MB) | `make_pilot_variant.py` | source chain runs through the same tree |
| `us_rto.blend` | `make_rto.py` | LOCKER lost **and** it writes to dead `art_source/us_troops/` |
| `us_medic.glb` | `make_medic.py` | `satchel_medic.blend` — **never tracked, gone** |

**This tier is 1.2 GB and it is the entire argument.** `.gitignore` calls these "derived, regenerated
from the tracked truth source." **The truth source is not tracked, and it is not on disk.** A policy
that ignores this tier today is a policy that deletes the civilian cast.

#### TIER D-REAL — genuinely derived. Reproducible **today**, from tracked inputs, right now.
| File | Generator | Proof |
|---|---|---|
| `lineup_review.blend` (**119 MB**) | `make_soldier_lineup.py` | reads **only** `.glb` (`path = os.path.join(CHAR, unit + ".glb")`) and writes the blend. **Pure function of the tracked .glb set.** |
| `civilians_all_lined_up.blend` (17 MB) | same family | same |

**This is the only clean win: 136 MB, and one of the four >100 MB blockers, is genuinely,
provably ignorable.**

#### TIER X — SNAPSHOTS AND CORPSES. Never in git.
`_backups/gear_armory_BROKEN_STATE.blend` (217 MB) · `_backups/gear_armory_BEFORE_civsplit.blend`
(217 MB) · `_backups/weapons_us_BEFORE_markers.blend` · `assets/us/characters/_archive/*` (100 MB) ·
`sprite_stage.blend` (4 MB — ADR-001 killed the sprite renderer; it is dead).

**But they must leave the repo *sideways*, not downward.** The two 217 MB backups are, right now,
**the newest surviving snapshots of the lost locker's gear.** `git rm` them and gc, and you finish
the job that killed the locker. **Copy them out of the tree first.**

### The recommendation

**Git LFS. Not .gitignore. And the reason is not size — it is that .gitignore is what killed the
locker.**

`.gitignore` is not a storage policy. It is an **absence of one**. Every file this project has lost
was lost because it was gitignored: it existed in exactly one place, on one disk, and a `git mv` of
the folder above it was enough to end it. The `.gitignore` philosophy was *correct in principle* and
*fatal in practice*, because it depended on a pure-function guarantee that no probe ever enforced —
and the moment the function's input was deleted, the ignore rule silently converted from
"safe deduplication" into "the only copy is unprotected."

**Caleb hand-poses in Blender. Hand-authored work must never be at risk. Gitignore *is* risk.**

The policy, in four rules:

1. **`.gitattributes`: `*.blend filter=lfs diff=lfs merge=lfs -text`.** git-lfs 3.7.1 is already
   installed (`git lfs version` → `git-lfs/3.7.1`). **Do NOT migrate pushed history** — LFS tolerates
   a mixed history perfectly: old commits keep their plain blobs, new commits store pointers. Zero
   blast radius.
2. **Tier S + Tier D-BROKEN go into LFS and stay tracked.** ~1.6 GB. GitHub's free LFS is 1 GB; this
   needs **one $5/mo data pack (50 GB)**. That is the honest price of not losing Caleb's hands again,
   and it is the cheapest line item in this entire project.
3. **Tier D-REAL is `.gitignore`d — but only behind a probe.** ADR-015 already demands this and we
   never applied it to art. Add `tools/probe_regen.py`: from a clean checkout, run the generator,
   assert the output blend appears and its tri-count/bone-count matches the recorded contract. **A
   blend may be ignored only when a green probe proves it can be rebuilt.** No probe → it is Tier S,
   by law. *This one rule, existing on 2026-07-12, would have prevented every loss in F1.*
4. **Tier X leaves the repo.** `_backups/` and `_archive/` become gitignored **and** mirrored to a
   path outside the working tree. A backup inside the thing you are restructuring is not a backup.

**Rejected alternatives, and why:**
- *Keep .gitignore, add discipline.* — This IS the current policy. It just cost us the locker, the
  medic satchel, and the RTO. Discipline is not a mechanism.
- *Separate art repo.* — Doubles the coordination surface, and the phone (which cannot read) now has
  to keep two trees in sync. It moves the failure, it does not remove it. Also: Caleb would still
  gitignore the big files in the art repo, because they are big.
- *`git filter-repo` the pushed history into LFS.* — See RECOVERY, step "what I will not do."

---

## RECOVERY PLAN

**Cost: 2 unpushed commits. Zero pushed history touched. Zero clones broken. ~30 minutes.**
This is the *cheap* case, and the briefing is right that it is. But it must run in this order,
because steps 1–2 are the ones that prevent a second, permanent loss.

### PHASE 0 — STOP THE BLEEDING (do this before anything else touches git)

```powershell
# 0a. The two 217MB backups are the ONLY recent snapshots of the lost locker.
#     Get them OUT of the repo before any reset/gc can reach them.
New-Item -ItemType Directory -Force C:\Users\caleb\RECONgame_art_vault\2026-07-13
Copy-Item _backups\*.blend                 C:\Users\caleb\RECONgame_art_vault\2026-07-13\
Copy-Item "assets\us\props\gear_armory.blend"        C:\Users\caleb\RECONgame_art_vault\2026-07-13\gear_armory_props_UNTRACKED.blend
Copy-Item "assets\us\characters\us_v3_soldier_lineup.blend" C:\Users\caleb\RECONgame_art_vault\2026-07-13\

# 0b. Caleb DELETED these in the working tree, uncommitted. They are Tier S.
#     Restore them NOW, before any `git add -A` bakes the deletion in.
git checkout -- "assets/us/characters/satchel_m3.blend" "assets/us/characters/helmet_v3_fitted.blend"

# 0c. Restore THE ROOT SOURCE. It is on origin and it is not on disk.
git show "origin/audit-fixes:art_source/characters/base_psx/us_grunt_v2.blend" > "assets\us\characters\us_grunt_v2.blend"
#    -> this makes make_base_v3.py's SRC real again. 94,079,010 bytes.

# 0d. Restore the newest LOCKER git ever saw (85MB, batch-1 era — NOT current, but not nothing).
git show 12a14bb:"art_source/characters/base_psx/gear_library.blend" > "assets\shared\gear_library.blend"
```

**Phase 0 is non-negotiable and it is not about the push. It is about the fact that the project is
currently one `git clean -fd` away from losing 100 MB more of Caleb's hands.**

### PHASE 1 — MAKE THE PUSH LEGAL

```powershell
git lfs install
```
Write `.gitattributes`:
```
*.blend filter=lfs diff=lfs merge=lfs -text
*.glb   filter=lfs diff=lfs merge=lfs -text
```
Rewrite `.gitignore` — delete the five dead `art_source/…` lines, replace with:
```
# Snapshots and corpses. Mirrored to ../RECONgame_art_vault, never committed.
_backups/
**/_archive/
# DERIVED — and PROVEN derived by tools/probe_regen.py. Nothing is ignored without a green probe.
assets/reference/review/lineup_review.blend
assets/reference/review/civilians_all_lined_up.blend
assets/reference/review/sprite_stage.blend
```
Then:
```powershell
git reset --mixed origin/audit-fixes    # un-commits the 2; TOUCHES NO FILE ON DISK
git rm -r --cached _backups             # (already gone from disk via Phase 0a — now remove from index)
git add -A
git commit -m "restructure: one asset tree, one folder per faction (RECONgame-<new-bead>)"
git commit -m "repo: LFS for .blend/.glb; art_source ignore rules retired (RECONgame-<new-bead>)"
git push
```
`reset --mixed` is the key choice: **it moves the branch pointer and the index, and does not touch a
single byte of the working tree.** Caleb's in-flight surgery survives untouched. Nothing he made is
at risk at any point.

### PHASE 2 — RECLAIM THE 4.2 GB
```powershell
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```
The four offending blobs become unreachable and are reclaimed. Expect `.git` to fall from **4.8 GB →
~600 MB** (packed history is only 508 MB — F3).

### PHASE 3 — CLOSE THE LANDMINES (beads, not this council's job to build)
- Re-path the **27** tool scripts (F4) — and the half-migrated ones first, they are the dangerous ones.
- Fix `make_jungle_patches.py:978-980` before the next jungle regen (beads `en75`, `2v3t`).
- Delete the two BOM keys from `project.godot` (F5).
- **Write the 0.77 render-scale disclosure into `mhfv` (F6) before anyone A/Bs a renderer.**
- Fix `enemy_base.gd:366`, `insertion_ride.gd:57`, `civilian.gd:23` — truth-law violations.

### WHAT I WILL NOT DO, AND WHY

**I will not rewrite pushed history**, and I want to name what that would break so the Arbiter can
overrule me with his eyes open:
- `origin` carries **four** branches (`master`, `audit-fixes`, `audit/remediation`,
  `overnight-claude`). The big blends are in the ancestry of several. A `filter-repo` would rewrite
  **every SHA on all four.**
- The ADRs, the beads, the war-room synthesis docs, and dozens of commit messages **cite commit
  SHAs**. Every one becomes a dangling reference. This project's canon is partly addressed by hash.
- `origin/overnight-claude` = `d6ae7cd` is currently the **only** ref from which
  `gear_library.blend` @ `12a14bb` is reachable. A careless rewrite that drops it **destroys the last
  copy of the locker.**
- I checked the one coupling I feared and it is **clear**: `git ls-remote origin "refs/dolt/*"`
  returns nothing — beads is not syncing through this remote, so a rewrite would not eat the issue
  tracker. **That is one danger the Arbiter does not have to worry about.**

The pushed history is 1.26 GB of tracked bytes and it is ugly. **It is also working, pushed, and
referenced.** The 4.8 GB figure that makes it look urgent is 90 % loose-object garbage (F3). **Fat
and safe beats clean and broken.** Revisit after launch, never before.

---

## THE PHONE GUARDRAIL

**The rule "don't use the phone" is a rule that will be broken, and it is also the wrong rule.** The
phone did not make a bad decision. The phone made *reading impossible*, and then the work proceeded
at the speed of not-reading. Caleb should keep the phone. **The guard must make the unreadable
operations mechanically impossible, while leaving everything a phone is actually good at wide open.**

### G1 — THE SIZE GATE (this one alone stops both bad commits)

`core.hooksPath` is **already claimed by beads** (`C:\Users\caleb\RECONgame\.beads\hooks`) — so do
**not** repoint it; **append below the `# --- END BEADS INTEGRATION ---` marker** in
`.beads/hooks/pre-commit`:

```sh
# --- RECON REPO GATE (drift council 2026-07-13) ---
fail=0
for f in $(git diff --cached --name-only --diff-filter=AM); do
  [ -f "$f" ] || continue
  sz=$(git cat-file -s "$(git rev-parse ":$f")" 2>/dev/null) || continue
  # LFS pointers are ~130 bytes. A real >45MB blob in the index is a bug.
  if [ "$sz" -gt 47185920 ]; then
    echo >&2 "BLOCKED: $f is $((sz/1048576)) MB and is NOT an LFS pointer."
    echo >&2 "         Run: git lfs track '*.blend' && git add --renormalize ."
    fail=1
  fi
  case "$f" in
    _backups/*|*/_archive/*|*_BROKEN_STATE*|*_DUPLICATE_*|*_BEFORE_*|*_STALE_*)
      echo >&2 "BLOCKED: $f is a snapshot/corpse. It belongs in ../RECONgame_art_vault, not in git."
      fail=1 ;;
  esac
done
[ $fail -eq 0 ] || { echo >&2 "Repo gate failed. This is the drift guard. Fix it, do not --no-verify it."; exit 1; }
```
**Test:** this rejects `53c903d` (the 217 MB backups) *and* `615ddd0` (the 129/119 MB blends). Both
bad commits die at the keyboard, phone or not.

### G2 — THE PUSH GATE (`.beads/hooks/pre-push`, same append pattern)

Reject any outgoing object >100 MB *before* uploading 1.6 GB and eating GitHub's rejection four
minutes later. Same loop, over `git rev-list --objects <local_sha> --not --remotes`.

### G3 — THE GITIGNORE-ROT GATE — *this is the one that actually catches the 615ddd0 class*

Add to `run_all_tests.ps1` and to the pre-commit hook:

> **Every non-comment path pattern in `.gitignore` must match at least one real path on disk.**

An ignore rule that matches nothing is a rule that has been **walked out from under**. That is the
exact, literal mechanism of this entire disaster: `art_source/characters/civilians/` stopped matching
anything, silently, and 900 MB fell through the hole. **A gitignore rule going stale is not a
cosmetic issue — it is a live security failure of the asset policy, and it is trivially detectable.**
Nobody, on any project I know, checks this. We should. It would have fired the instant `615ddd0`
staged, with the message *"5 ignore rules now match nothing — did you move a tree?"*

Bundle with it: `grep -r "art_source\|assets/models" tools/ scripts/` must return **zero** (F4).

### G4 — THE PHONE PERMISSION SET (`.claude/settings.local.json`, loaded on mobile sessions)

Deny, on the phone, exactly the operations that **require reading a diff to be safe**:

```json
{ "permissions": { "deny": [
    "Bash(git mv:*)", "Bash(git rm:*)", "Bash(git add -A:*)", "Bash(git add .:*)",
    "Bash(git clean:*)", "Bash(git reset --hard:*)", "Bash(git push --force:*)",
    "Bash(rm -rf:*)", "Bash(mv:*)",
    "PowerShell(Remove-Item*-Recurse*)", "PowerShell(Move-Item*)",
    "Write(**/.gitignore)", "Write(**/.gitattributes)", "Write(**/project.godot)"
]}}
```
**What the phone KEEPS** — and it is nearly everything Caleb actually wants it for: read anything,
write and edit GDScript, run probes and the test suite, file and close beads, run the War Room,
design, argue, plan, commit *code*. **What the phone LOSES:** the ability to restructure a tree it
cannot see, and the ability to edit the three files that define what is protected. **Structural
change requires eyes. Eyes require a monitor.**

### G5 — ONE COMMIT, ONE BEAD (`prepare-commit-msg`, append below the beads marker)

Reject a commit message with no `RECONgame-[a-z0-9]{4}` unless it opens with `wip:`. **`615ddd0` had
no bead.** The charter says *"bd is task truth"*; right now that is an aspiration, not a mechanism.
This makes it one, and it costs four characters per commit.

**The ordering matters:** G1 and G3 are the whole defence. G4 is comfort. If the Arbiter has budget
for exactly one thing today, **it is G1** — it is fifteen lines of shell and it mechanically
forecloses the entire class of failure that convened this council.

---

## WHAT I AM SACRIFICING BY RECOMMENDING THIS

**No free lunches. Here is the bill.**

1. **LFS costs $5/month, forever, and introduces a *new* way to lose art.** If Caleb clones on a new
   machine and forgets `git lfs install`, every `.blend` checks out as a 130-byte text pointer and
   Blender chokes on all of them. I am trading a *silent deletion* risk for a *loud corruption* risk.
   I take that trade — loud beats silent, every time, and this project has just been mugged by
   silent. But I am not pretending it is free. **Mitigation: add `git lfs env` to the SessionStart
   hook alongside `bd prime`.**

2. **I am recommending we keep 1.26 GB of blend blobs in pushed history forever.** Every future clone
   pays ~500 MB. A `filter-repo` would fix it and I am refusing to run one, because the blast radius
   (four branches, SHA-addressed canon, and the last surviving copy of the locker sitting on
   `origin/overnight-claude`) is a worse risk than a fat clone. **I am choosing permanent ugliness
   over a one-time chance of catastrophe.** If the Arbiter values a clean repo more than he fears a
   broken one, he should overrule me — but he should do it knowing that `origin/overnight-claude` is
   load-bearing.

3. **The hooks will make Caleb angry.** He will try to commit a legitimate 60 MB blend, get blocked,
   and the friction will land at exactly the moment he is mid-flow in Blender. `--no-verify` exists
   and a phone-driven agent can type it. **G1 is a speed bump, not a wall.** The wall is G2 (pre-push)
   plus CI. I am accepting that the guard is defeatable, because a guard that cannot be defeated
   cannot be shipped today, and one that fires 95 % of the time today beats a perfect one next month.

4. **G4 takes away the thing Caleb liked about the phone: that it had no brakes.** He will hit the
   deny-list on a legitimate `mv` and have to walk to a desk. **That is the point, and it is a real
   cost to a man who is using the phone precisely because he is not at a desk.** I am betting that
   losing an hour of mobile convenience is worth less than a second lost locker. If he disagrees, the
   honest compromise is G1+G2+G3 alone (which are automatic, invisible, and cost him nothing until
   they save him) and drop G4.

5. **The tiering costs a probe that does not exist yet.** `tools/probe_regen.py` is real work — a day,
   maybe two — and until it is green, **1.2 GB of "derived" art must be treated as source and paid
   for in LFS.** I am asking the project to spend money on files it *believes* are reproducible,
   because belief is exactly what got the locker killed. **We pay the storage until a probe earns the
   right to stop paying.** That is ADR-015 applied to art for the first time, and it is not free.

6. **I am telling the Summoner, mid-surgery, that some of his gear is already gone.** The locker, the
   medic satchel, and the RTO source blend are not coming back — only their exports and an 85 MB
   batch-1 snapshot survive. **The US grunt remake he is doing right now is not optional
   perfectionism. It is the recovery.** I would rather pay for that sentence now than let him find
   out in three weeks when `make_civilians.py` fails at line 437.
