# HANDOFF — LIVE MODEL SESSION (Caleb at the computer, Blender open)

**Written 2026-07-13, at the end of a long remote session. Read this before touching anything.**

---

## 1 · THE TRUTH SOURCE IS DECLARED. USE IT.

> ## **`assets/us/characters/us_base_v3.blend`  —  V3 IS THE TRUTH SOURCE**

*(Path updated: `art_source/` no longer exists. The file lives under `assets/us/characters/` and is
tracked in **Git LFS** — `git check-attr` reports `filter: lfs`. `.gitignore:31-33` states the same:
v3 is NOT a derived blend, because **`us_grunt_v2.blend` does not exist on disk and v3 therefore
cannot be regenerated from anything.**)*

**Caleb, 2026-07-13:** *"v3 of the grunt is actually our newest truth source, because we updated it."*

The docs still name **v2** (`VC_FIX_LIST.md:122`, `make_base_v3.py:1`) — **those are STALE.** V3 superseded
it. **THE DOCS ARE OUT OF DATE, NOT CALEB.**

**What changed v2 → v3, and it is only these two things:**
1. **The v3 WEBBING** (the M1956 harness, fitted with `fit_webbing.py`).
2. **UPDATED HITBOXES** — the gear is cut OUT of the body mesh, so the helmet and the ruck no longer
   inflate the hurtbox. (HEAD −47%, TORSO −64%. You could once shoot a man's backpack and hurt his spine.)

**Everything else is the same man.**

---

## 2 · WHAT THE MODELS ACTUALLY MEASURE (all 25, verified 2026-07-13)

| | |
|---|---|
| **41 bones** | on **EVERY** model |
| **gib donors** | on **EVERY** model |
| **height** | 2.69–2.73m, **uniform** — that is the authoring scale; the engine normalises from the skeleton rest span at runtime. **NOT a fault.** |

> ## **THE MODELS ARE CONSISTENT. THE RIG IS NOT THE PROBLEM.**

*(I flagged all 25 as broken on a bad height check. A check that fires on everything is not a check.)*

**Real notes, and only these:**
- `us_grunt_v2` — the superseded ancestor. Its gear is **welded into the body**, which is why v3 exists.
  **No `us_grunt_v2.blend` survives on disk** — only its textures (`assets/us/characters/us_grunt_v2_*.png/.webp/.jpg`)
  and `tools/export_us_grunt_v2.py`. There is nothing to go back to; **v3 is the only base.**
- `us_rto` reads 3.46m — that is his **antenna**. Not a fault.
- `us_grunt_m14`, `vc_guerilla_m16` — **orphans**, nothing in the game spawns them.
- `us_medic` — **new (mine)**. The aid bag rides a little high on the ribs.
- **NVA: NO MODEL EXISTS.** `nva_regular` and `nva_rpg` currently render as `vc_guerilla_ppsh` / `_rpg` —
  **the NVA are wearing VC black pyjamas.** Already pre-wired: the moment `nva_regular.glb` lands in
  `assets/models/characters/`, he puts it on. No code change.

---

## 3 · THE REAL PROBLEM — and it is not the models

**SEVEN files claimed to be a US grunt base. Four of the seven are now GONE from disk — what
actually survives is THREE:**
```
assets/us/characters/us_base_v3.blend        <- THE TRUTH SOURCE (LFS). Renders with REFERENCE
                                                PHOTOS on the legs — it is a textured WIP, which is
                                                why tools build from the shipped us_grunt_v3.glb
assets/shared/rigs/base_human_rigged.blend
assets/us/characters/_archive/unit_us_grunt.blend
assets/us/characters/_archive/unit_us_grunt_slim.blend   <- archived, not live
```
GONE (do not go looking): `us_grunt_v2.blend` · `_us_base_v3_STALE_BACKUP.blend` ·
`us_base_v3_DUPLICATE_from_us_troops.blend`, and the whole `art_source/` tree they sat in.

**FIVE lockers claimed to hold the gear. Only ONE survives:** `gear_armory` — and it is in **two**
places, `assets/us/characters/gear_armory.blend` and `assets/us/props/gear_armory.blend`.
`gear_library` · `us_gear_kit` · `webbing_m1956` · `satchel_m3` no longer exist on disk.

> **Every tool guesses which one to open, and every guess is a coin flip. That is why this keeps
> happening.** Today alone it cost: a medic built on the wrong base; webbing found in three places; and a
> satchel that existed in **no file at all**, only in an unsaved window.

**This is the thing to fix, and it is a decision about WHICH FILE WINS. That is Caleb's call, not mine.**

---

## 4 · STATE OF HIS BLENDER RIGHT NOW (do not clobber it)

- **`gear_armory.blend` is OPEN and UNSAVED.**
- It contains his **PRC-25 / rice props / webbing / ruck / helmet** work…
- **…plus the NEW M3 aid bag I appended** (`sat_sling`, `sat_body`, `sat_flap`, `sat_buckle_a/b`,
  `sat_cross`). The old 26-vert blockout was removed. **He must Ctrl+S to keep it.**
- There is also a scene called **`MODEL_LINEUP`** I created (all 25 GLBs, laid out and labelled). It is a
  separate scene — his working scene is untouched. **Delete it when done.**

**`sat_sling` carries a LIVE SHRINKWRAP masked by a `wrap` vertex group** — the same contract as
`web_belt`. `tools/fit_webbing.py` re-solves it per soldier.

**KNOWN, UNFIXED:** the sling's tail does not quite reach the bag (`fit_webbing`'s gate measures 284mm and
**refuses to skin it — correctly**). It needs the last ribbon segment dragged into the bag **by eye**. Ten
seconds with a mouse; I could not do it blind.

---

## 5 · THE TOOLS THAT EXIST (use them; do not write new ones)

| Tool | What it is |
|---|---|
| **`tools/fit_webbing.py`** | **THE FABRIC TOOL.** STRAPS get a live Shrinkwrap + weights from the body; RIDERS wear their host strap's weights. Gate poses through every animation and fails on clipping or shearing. |
| `tools/bone_attach.py` | **THE ONE WAY** to hang a thing on a bone. Requires the rig in **REST**. |
| `tools/make_gear_armory.py` | rack / pack the locker |
| `tools/make_satchel.py` | the new M3 aid bag (mine) |
| `tools/make_medic.py` | assembles the medic. Already builds from the **shipped `us_grunt_v3.glb`** (`make_medic.py:43`), deliberately — the v3 blend still wears reference-photo textures. Do not "repoint" it at a v2 blend; there isn't one. |
| `tools/export_us_grunt_v2.py` | the **proven** exporter. Copy its export call; do not invent one. |

**Character GLBs are MESH-ONLY.** `model_actor.gd:133`: *"anim_library.glb carries every clip ONCE (91);
character exports go mesh-only."* Do not bake animations into a character.

---

## 6 · THE LESSON FROM TODAY, STATED PLAINLY

**Caleb, verbatim:** *"When I sit in front of the computer we make models really good. When I try to have
you do it through my phone you have a hard time doing it."*

**He is right, and here is the mechanism:** modelling is a **visual** loop. Remote, I cannot see the
result, so I substitute inference for observation — and every one of today's failures was me *reasoning*
about geometry instead of *looking* at it. The satchel that was "finished" was a blockout. The base that
was "the source" was a clone. The bag that "came off its sling" hadn't.

**When he is at the computer: he looks, I execute. That is the division of labour that works.**
Ask him what he sees. Do not tell him what I think is there.
