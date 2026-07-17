# ADR-024 — Cinematic Direction (Late 1998–2003 Prerendered Military Cinematics)

**Status:** DRAFT pending Summoner ratification
**Filed:** 2026-07-15 by recon-overseer
**GATE waiver:** This ADR and the one-asset assembly-contract proof (RECONgame-cine-proof) are filed under an explicit Summoner waiver of the mechanical GATE (`RECONgame-97u3`) **for this turn only**. The GATE itself is NOT closed. The waiver does not extend to the broader cinematic rollout (additional cutscenes, multi-asset staging, glTF export) without an explicit Summoner extension.
**Readiness-audit status:** `RECONgame-x2za` (Blender 5.0.1 readiness audit) remains OPEN and is the gating bead for any work beyond the one-asset proof. Audit scope corrected in this turn: real art path is `assets/**/*.blend`, not `art_source/`.

## Canon source

This text was authored by Caleb Dickenson on 2026-07-15 as a creative brief for the cinematic director. It is being canonized by explicit write (per ADR-014) as a draft pending ratification. Amendment to the canon by drift is forbidden; this is amendment by explicit write.

## Overall style

The world is grounded. Military. Serious. Quiet. Tense. There are long pauses. Characters rarely overact. Movement is economical. Body language is subtle. There is constant environmental motion instead of character motion: rain, fog, dust, helicopters, leaves, grass, smoke, embers, cloth, tarps, radio antennas, heat shimmer. Everything should feel alive.

Never make the scene feel modern. Never imitate Marvel cinematography. Never imitate modern AAA cutscenes. Everything should feel deliberate, restrained, believable.

## Primary inspiration

- Medal of Honor (1999)
- Medal of Honor Underground
- Hidden & Dangerous
- Operation Flashpoint
- Rainbow Six Rogue Spear
- Delta Force
- Half-Life intro
- Resident Evil prerendered cinematics
- Metal Gear Solid
- Final Fantasy VIII FMVs
- Command & Conquer Tiberian Sun
- Ghost Recon (2001)

## Camera direction

Film language, not video-game camera. Preferred shots: static tripod, slow dolly, slow push-in, slow pull-back, crane rise, locked-off wide, low-angle dramatic, over-the-shoulder, long-lens compression, foreground obstruction, silhouettes. Movement very slow. No quick pans. No handheld. No orbits. No impossible drone shots. Camera feels physically present; movement is smooth and motivated.

## Shot pacing

- Average shot: 4–10 s
- Important reveals: 10–15 s
- Wide establishing: 6–12 s
- Dialogue: hold longer than feels comfortable. Never cut rapidly. Silence is acceptable.

## Animation style

Trained soldiers, no exaggerated motion. Idle: weight shifts, small breathing, checking equipment, looking around, adjusting sling, lighting a cigarette, scratching neck, repositioning feet, resting rifle. Dialogue: small head turns, eye contact, minimal hand movement, subtle posture changes. Never over-animate.

## Lighting

Overcast Vietnam, humid jungle, late afternoon, golden sunrise, storm clouds, moonlit firebase, burning village. Few major sources: one sun, one fill, one bounce, fire sources if appropriate. No over-complicated rigs. Heavy shadows encouraged.

## Color

Muted, low saturation. Deep greens, warm mud, dusty browns, dark blacks, slight blue shadows, very slight green tint. Avoid bright colors.

## Render settings

Eevee (Next, on Blender 5.0.1). Bloom very subtle. AO on. Motion blur minimal. Film grain added in compositor. Depth of field used sparingly. Resolution 640×480 or 720×480. Frame rate 24 fps.

## Composition

Classical cinematography. Rule of thirds. Negative space. Foreground framing. Background depth. Characters rarely centered. Wide establishes geography. Medium establishes emotion. Close-ups only for important moments.

## Audio considerations

Blender does not create sound. Every shot must be designed around imagined sound: rotor wash, radio chatter, jungle insects, boots, rain, wind, artillery, distant gunfire, vehicle engines. This influences pacing.

## Cutscene archetypes (seed list)

1. **Operation Briefings** — locked tripod, 35–50 mm lenses, slow push-ins, dim bunker lighting.
2. **Insertion Scenes** — wide helicopter shots, slow crane movements, rotor wash, minimal dialogue.
3. **Combat Intros** — long lenses through foliage, soldiers partially obscured by vegetation, almost no music.
4. **After-Action Sequences** — static compositions, smoke drifting through the frame, wounded soldiers, long silent holds.
5. **Death Sequences** — no dramatic slow motion; a sudden grounded event followed by the squad continuing the mission, reinforcing the campaign-persists theme.

The first three cutscenes beaded under this ADR are: Cutscene 01 Operation Briefing (`RECONgame-cine-01`), Cutscene 02 Huey Insertion (`RECONgame-cine-02`), Cutscene 03 Death Sequence (`RECONgame-cine-03`).

## Scene building process

For every cinematic:

1. Analyze scene purpose.
2. Determine emotional tone.
3. Build environment.
4. Position actors.
5. Pose everyone.
6. Assign idle animations.
7. Place lighting.
8. Create cameras.
9. Animate cameras.
10. Review composition.
11. Adjust timing.
12. Render preview.
13. Refine.

Only render final frames after preview approval.

## Camera rules

Each shot must record: camera name, lens focal length, height, tilt, roll, focus distance, movement type, duration. Example:

```
Camera_A
50mm
Height: 1.7m
Tilt: 0
Roll: 0
Focus: Commander (3.2m)
Slow Dolly Forward
5s shot
```

## Timeline

Organize animation into shots.

Example:

```
Shot 01 — frames 1–150
Shot 02 — frames 151–300
Shot 03 — frames 301–480
```

## Scene organization

Maintain clean Blender collections. Mandatory: Environment, Characters, Vehicles, Weapons, Effects, Lights, Cameras, Animation. Never leave unnamed objects. Descriptive names.

## Quality control

Before completing a cinematic, ask:

- Does this feel like a real military documentary?
- Would this have looked believable in 1999?
- Is the pacing too fast?
- Is the camera moving too much?
- Are characters over-acting?
- Can this shot breathe longer?

If any answer is wrong, revise until all criteria pass.

## Goal

A cinematic that feels timeless. The audience should feel they are watching a forgotten Vietnam game intro from 2001 that has somehow been remastered, not a modern game cutscene. Atmosphere over spectacle. Every decision supports realism, tension, immersion.

---

## Director contract (binding for all cinematic work)

- Blender 5.0.1 only (confirmed live on the Summoner's machine).
- APPEND/LINK from `assets/**/*.blend` only. Never re-author an in-project asset. Never "Save As" an older .blend format. Never edit an asset to "fix" a 5.0.1 import warning — surface the warning to the council instead.
- Director stages cinematic .blend files in `production/cinematics/<cutscene_id>/`. Filename markers: `_assembly_proof.blend` for contract proofs, `_previews/` for rendered PNGs. Final cutscene .blend is named after the cutscene (e.g. `cutscene_01_operation_briefing.blend`).
- Director does not export glTF. The existing 4.x-style export pipeline runs the actual Godot-side import. This is because 5.0.1's glTF exporter compatibility with Godot 4.7's importer is **explicitly unverified** (one of the five 5.0.1 compatibility checkpoints from the 2026-07-15 SUMMONING correction). Once the readiness audit (`RECONgame-x2za`) confirms the 5.0.1 exporter is compatible, the director may export directly.
- AI generation backends (Hyper3D, Hunyuan, PolyHaven, Sketchfab) are all disabled. The director assembles, never generates. Re-enabling any backend requires an explicit Summoner decree.
- Every staged .blend must have a real scene (DRIFT-9) — no empty placeholders masquerading as a stage. The "default Cube as a stand-in for an in-project asset" pattern is forbidden outside the literal _assembly_proof.bound contract proof; even there, the contract proof must append from a real in-project asset on top of the default cube, not pretend the cube is the asset.
- The no-unprompted-screenshots rule and the never-guess-in-Blender rule still apply to cinematic work.
- Cinematic bead closes on Summoner playtest + sign-off, not on automated end-to-end.

## Ratification

Ratified by: ____________ (Summoner signature line)
