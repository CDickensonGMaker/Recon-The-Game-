# Overnight Claude — progress log (2026-07-08 → morning)

Branch: `overnight-claude`. Discipline: reuse existing systems, verify-before-writing, commit each task.
Status of the 50 tasks in `OVERNIGHT_50.md`.

## MORNING SUMMARY — 13 tasks done, all validated headless & pushed
**5 research docs** (`production/research/`): squad mechanics, coop feasibility, air support, gore FX, ragdoll —
each grounded in the actual code, each proposing REUSE of existing systems (not rewrites).
**8 code/doc tasks**, one commit each, every one passing a full-project headless compile (Godot 4.6.2):
1. Enemies + allies bleed on flesh hits (was player-only) — reuses `GunFX.blood`
2. Firebase interior variety — `stamp_firebase` uses its rng (closed bead `hi9c`)
3. Pain-quota stagger on solid hits — wired the dead `apply_stagger()`
4. Functional VC punji traps — new `PunjiTrap` actor (claymore pattern) + village placement
5. **F-4 fast horizontal flyby + CBU cluster** — your headline: 200m spawn, low+fast, pickles on the pass,
   climbs and despawns into the clouds; napalm menu now routes through it
6. Allies use their OWN Small Arms skill (veterans shoot tighter; was player-only)
7. `WIRING_STATUS.md` — the "how much before scaling" map you asked for
8. `detect_ambush` skill wired to POINT-man warning radius (was buyable-but-dead)

**No new duplicate systems** — every code task extended something that already existed. Stopped short of a
toe-popper mine (would ~90% duplicate the punji actor — needs a shared base, better with you awake) and of the
fire-VFX/bios/napalm-perf tasks (medium-risk, want you or a runtime perf test). Nothing left half-wired.

**Discipline notes below.**

---

Updated as I go.

## Legend: ✅ done · 🔄 in progress · ⏳ queued · ⏸ gated (needs you/Blender)

---

## Log
- **Setup** ✅ — branched `overnight-claude`, committed the 50-task queue + F-4 despawn-into-clouds detail.

### Research done (docs in production/research/)
- #1 squad_mechanics.md ✅ · #3 coop_feasibility.md ✅ · #4 air_support.md ✅ · #5 gore_fx.md ✅ · #6 ragdoll.md ✅
  (coop verdict: viable DLC ~6-10wk, not a rewrite; ragdoll: one shared physical skeleton .tscn; air: F-4 reuses CASAirplane.)

### Code done (each committed, headless-validated)
- #21 ✅ enemies + allies spawn blood on flesh (reuse GunFX.blood; was player-only)
- #12 ✅ firebase interior variety — stamp_firebase uses its rng (closes hi9c)
- #27 ✅ pain-quota stagger on solid hits (wire dead apply_stagger)
- #31 ✅ functional VC punji traps (new PunjiTrap actor on claymore pattern + village placement)
- **Full project validated headless (Godot 4.6.2) — no script errors.**

- #36+38 ✅ F-4 fast horizontal flyby + CBU cluster ordnance (napalm menu now routes through the dramatic
  flyby; spawns 200m out, low+fast, pickles on the pass, climbs and despawns into the clouds 100m+ past)
- #47 ✅ allies use their OWN Small Arms skill (veteran riflemen shoot tighter; was player-only)
- #50 ✅ WIRING_STATUS.md (full wired/stubbed/missing map + "how much before scaling")
- #46 ✅ (skill half) detect_ambush wired to POINT-man warning radius (was buyable-but-dead)

### Queued next (safe code)
- #46 remainder: player `al` → "being-noticed" HUD pip · #32/#33 tripwire + toe-popper traps (like punji)
- #44 100 bios data file (batchable) · #26 fire VFX wire (terrain_vfx NAPALM_FIRE — cross-subsystem)
- #37 napalm strip wider burn — HELD: touches the deliberate perf "crater cap", needs runtime perf test (⏸)

### ⏸ GATE (Blender/textures/audio/perf — need you or MCP)
- #35 claymore + F-4 models · #20/22/23 blood textures+audio · #24 ragdoll rig verify · #41/43 voice VO · #37 perf test
