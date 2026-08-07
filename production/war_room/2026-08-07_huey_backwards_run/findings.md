# Huey backwards-run — root causes (diagnosed 2026-08-07, nothing fixed yet)

Summoner's report: *"people run away and towards the huey backwards … overall those animations
are rough."* Two independent live defects + one armed landmine. All pointers verified this session.

**RULING (same day): "im going to let you deicde whats best." Decisions taken and executed:**
- Bug 1 FIXED — velocity-facing added after `move_and_slide()` in `civilian.gd` (mirrors
  `ally_base.gd:490-495`). Awaits his playtest.
- Bug 2 FORMULA FIXED in both scripts (−π/2 → +π/2); **blends NOT rebuilt** — they bake v1
  geometry and are slated for the v3 re-stage per the 8/5 ruling; the corrected math rides along.
- Landmine 3 DEFERRED to v3 export prep (documented below; v3 merge still awaits his rulings).
- Bug 4 (exporter Hips-rotation strip) REJECTED — hips rotation is live pose in every walk cycle;
  wholesale stripping risks all 100+ clips, and with Bug 1 fixed residual clip yaw self-heals
  next frame exactly as it does for allies.

## BUG 1 — IN-GAME: `Civilian` has no yaw owner (primary, high confidence)

`scripts/world/civilian.gd` never calls `ModelActor.set_facing()` — zero hits for any rotation
write; `git log -S` shows it never had one. Every other moving class drives facing every frame
(`ally_base.gd:488-495` velocity fallback, `enemy_base.gd:510`, `zombie_base.gd:288`).
A civilian's yaw is written exactly once in its life: **`SeatSystem.unseat()` stamps the seat
socket's yaw** (`seat_system.gd:311-314` keeps e.y; pax sockets face ±90° out the doors,
`seat_system.gd:37-49`). Then `heli_lift.gd:294-300` walks him 10–22m on a hashed random bearing
with the directional `walk_forward`/`cargo_carry`/`run_forward` clips (`civilian.gd:601-613`) —
body translates on the nav vector, mesh frozen at the door yaw. Extraction converges men on the
staging point from all angles with the same frozen yaw (`seat_system.gd:334-353`): "towards the
huey backwards." AllyBase takes a different branch (`seat_system.gd:346-349`) and self-heals —
this is Civilian-only.
**Fix:** give `civilian.gd` the same velocity-facing rule as `ally_base.gd:490-495` (~6 lines,
after `move_and_slide()`).

## BUG 2 — STAGED BLENDS: 180° facing formula in two scripts

Proven convention (`mocap-toolkit/tools/mc_pose.py:155-160`, used by the working LZ deploy):
rig forward is **−Y**, yaw = `atan2(dx, −dy)`. The two newer scripts used `atan2(dy,dx) − π/2` —
exactly 180° opposite: `tools/huey_embark_loop.py:225-226`, `tools/huey_load_unload_loop.py:235-236`.
Smoking gun: embark's own comment hand-flips the SEATED heading by +π ("pointed his legs into the
cabin") — the same error was noticed once and patched only there; every moving heading stayed
backwards. **Fix:** `− π/2` → `+ π/2` in those four lines; re-run headless to rebuild both blends.
Scheduling: the 8/5 ruling says these staging files bake v1 geometry and get re-staged after the
v3 merge (which still awaits his two open v3 rulings).

## LANDMINE 3 — v3 export will invert every seat (not active today)

`scenes/vehicles/huey.tscn:10-11` mounts the Model subtree **flipped 180° about Y**.
`seat_system.gd:174` resolves `seat_*` sockets RECURSIVELY — inside the flipped subtree.
Today `huey.glb` has no seat empties (`strings` confirms) so the un-flipped fallback table runs.
**The moment huey_v3_transport exports real `seat_*` markers, every occupant's facing inverts
180°** and the fallback retires (`seat_system.gd:186-190`). Fix before export: mount sockets
under the vehicle root, or un-flip the Model and fix `helicopter.gd:71-78`/`:214`.

## Contributing rough-ness (BUG 4, medium confidence)

- `tools/export_anim_library.py:61-64` strips only Hips LOCATION x/z — **Hips rotation is never
  stripped**; `model_actor.gd:358-362` documents clips carrying up to −161.6° root rotation.
  `disembark_heli_*` contains an authored body turn; whatever yaw it leaves persists forever on a
  Civilian (no facing owner to heal it).
- Staged scenes: one crouch-walk clip NLA-looped over linear waypoint paths — no stride/speed
  match (foot slide), no run clip on long legs, no turns. The 8/5 procedural-life work targets this.

## Also noted
`huey_v3.blend` / `huey_v3_transport.blend` are modified-uncommitted; the v3 bird has NEVER been
exported (`ecb042e0` ART_GAPS) — the flying Huey is still the July GLB.
