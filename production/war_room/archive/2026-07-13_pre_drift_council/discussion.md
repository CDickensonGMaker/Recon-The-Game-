# THE DEBATE — Full Game Audit #2: The Drift Audit (2026-07-10)

Six architects analyzed independently (`analysis/`). This is the record of where they converged,
where they clashed, and how the Arbiter resolved each clash.

---

## Unanimous agreements (no debate needed)

1. **o18o (stealth witnessed-contact fix) is a FALSE POSITIVE.** Four architects independently traced
   it: `enemy_base.gd:1497` stamps COMBAT before the death check; `_set_tier` writes the global beacon
   (`:626-627`) before its own dedup; `mission_director.gd:65-71` fires "YOU'VE BEEN MADE" off the beacon.
   A silent one-shot kill still escalates the AO. Worse, comments at `enemy_base.gd:189-191` and
   `mission_director.gd:51-54` describe the fixed behavior as shipped — **the code lies about itself.**
   The bead is honestly OPEN; the comment is not. This voids the stealth economy for the second audit running.
2. **CLAUDE.md is a drift generator, not a law file.** Damage section wrong on every line (code truth:
   HEAD=fatal, TORSO 2.0, GUT 1.75+bleed, LIMB 0.75, enemy HP 65-85 — not HEAD 4x/TORSO 1.5x/LIMB 0.6x/60-80);
   line 3 still sells the killed sprite renderer; the FOV-75 "DO NOT CHANGE" law was already broken by
   shipped code (`weapon_holder.gd:215-220`, per-weapon `ads_fov` in every .tres). For a model-driven
   project, a stale law file injected into every session actively *manufactures* drift.
3. **The 7/9 decree's process laws failed mechanically.** Gate law adopted 16:37, violated by ~18:36
   (BLOOD v2), then FPS arms, SaveManager, hub, survival — all while 6 playtest P1s sat open. Perf-spike
   day (decree item 4) never happened: `rendering_method` still unset, 8pbo still open, zero measurements
   in ~30 commits. KILL/SHRINK rulings ignored (9xd/j8o still open P1, ooel still "100 bios").
4. **Tiny units root cause** (tech director, from Caleb's own logs): `ModelActor._aabb_of`
   (model_actor.gd:138-152) measures raw mesh-space AABBs and ignores armature/export compensation scale —
   observed k=0.020–0.204 vs expected ~0.9, shrinking already-correct models 5–50×. One-function fix.
5. **Terrain pop root cause** (tech director): there is no LOD bug — a 3km-era streaming policy runs
   inside a fully-loaded 1280m map, synchronously unloading/reloading whole 256m tiles (mesh + trimesh +
   vegetation, no time budget) at a 768m radius that is visible from everywhere. Disable streaming on
   ≤2km maps.
6. **The scoring economy teaches the opposite game.** Debrief pays kills×10 with zero contact tracking
   (debrief.gd:21-31); RECON_ADAPTATION.md's adopted ±25 avoided/detected rule appears nowhere in
   scripts/; VILLAGE_RAID demands an 80% body count (mission_generator.gd:233). Score banks 1:1 as XP,
   so the XP economy actively trains loud play against Pillar 3.
7. **Strict typing, MissionScope, the save backbone, and the fire-support fixes are genuinely excellent.**
   The lead programmer adversarially verified the fire-support cluster: really fixed. 3 untyped vars in
   90 files. The panic was about the wrong thing — the *new code quality* held up.

## The clashes, and the Arbiter's resolutions

### Clash 1 — Survival v1: cut it or give it teeth?
- **Game designer:** hunger serves NO pillar; it bites at minute ~22 of ~15-25-minute missions and the hub
  resets it free — cut or park it. Weapon condition serves Pillars 1+2; keep, weapon-weight it.
- **Systems designer:** confirms the arithmetic (drain 100/45min, penalty <50, missions sub-15-min —
  hunger is *incapable of firing*). Condition works as tuned (−0.15/shot, ~4.8% jam at 60).
- **Devil's advocate:** "give it teeth or cut it" — but names the tax of keeping dead systems visible.
- **RESOLUTION:** **Park hunger** (leave data fields in SaveData, remove the drain + any future HUD claim
  on it; it returns only if multi-day missions ever exist). **Keep weapon condition**, weapon-weight the
  jam curve per DESIGN §4.3. Rations [9] remain as the condition/stamina consumable. Tradeoff named:
  we ship less "hardcore checklist" and more felt game.

### Clash 2 — The walkable hub: unratified overreach or the right call?
- **Devil's advocate:** decree said menu-first HQ; a walkable hub shipped anyway while P1s sat open —
  process violation, maintenance tax named (interaction prompts, save integration, restore paths).
- **Game designer:** the hub *shape* is right (atmosphere, ritual, diegesis) but it amputated the loop's
  front half: the RECON 7-element briefing never shows on the campaign path (game_flow.gd:305-312) and
  `plan.erase("start_pad")` (game_flow.gd:166-167) deleted the live Huey insertion.
- **UX designer:** the hub's first prompt lies ([E] shown, F listened — hub_controller.gd:47,53).
- **RESOLUTION:** **Ratify the walkable hub retroactively — with conditions** (ADR-008): (1) the TOC
  briefing must present the RECON 7 elements before launch; (2) the Huey ride returns to the campaign
  path (it also masks world-load); (3) prompt/input truth fixed. The process violation is recorded — the
  outcome is kept because it serves Pillars 2 and 4 better than the decreed menu. Tradeoff: we reward a
  law-break with ratification; the compensating control is the new mechanical gate (Clash 4).

### Clash 3 — Atmosphere score: 2.5 (game designer) vs 4.0 (systems designer)
- Systems scored the *systems* (VO, ambience beds, weather, blood); game designer scored the *felt world*
  (Caleb's ground truth: speck soldiers, popping terrain, "jungle a white kid in america made").
- **RESOLUTION:** both are right; the Summoner's eyes outrank green tests. Council average stands at
  **3.1**, with the note that atmosphere's ceiling is now gated on the three visual P0s (scale fix,
  streaming fix, jungle pass), not on more audio systems.

### Clash 4 — Process: is another law worth writing?
- **Devil's advocate:** a law living in archived markdown was empirically measured to last two hours.
  Enforcement must be mechanical: a GATE bead that `bd dep add`-blocks every feature epic while playtest
  P1s are open, so `bd ready` physically hides gated work.
- **Lead programmer:** adds the verification law — no decree item or playtest P1 closes without a probe,
  measurement, or verified playtest ("mitigated/investigated" ≠ fixed).
- **Tech director:** adds test-suite law — headless boot + SCRIPT ERROR scan is the definitive check;
  the suite needs a rendered-scale probe and a gating FPS number or "all green" stays a comfort blanket.
- **RESOLUTION:** all three adopted as **mechanical process** (ADR-015), implemented in beads this session.

### Clash 5 — ADS zoom: the law says no, the code says yes
- **Lead programmer / devil's advocate:** W40 re-enabled ADS FOV zoom (per-weapon `ads_fov`, M16=60,
  binocs 18) in direct violation of CLAUDE.md's "FOV LOCKED at 75 (DO NOT CHANGE)" — while bead 2spa
  still frames it as an open decision.
- **RESOLUTION:** **the code is right, the law was stale.** Ratify per-weapon ADS zoom (ADR-004), amend
  the law, close 2spa's decision half. Iron-sight alignment work remains open in 2spa.

## Positions adopted without opposition
- The ONE build is the **stealth-economy restoration bundle**: real o18o witness guard + GUNSHOT noise
  55m→~150m (noise becomes the honest price of a kill) + RECON ±25 contact scoring replacing kills×10 +
  village clear made optional. Three architects independently nominated its parts.
- The **trust-restoration perf/visual day** (rendering_method A/B, AABB fix, streaming-off, decal FIFO,
  AI think budget with the never-used MAX_THINK_TIME) closes 8pbo + n2ij with numbers, not adjectives.
- The **Player-State HUD layer** (hunger out, condition/consumables/stamina/breath in + the DESIGN.md:87
  detection pip, still unshipped after two audits) as milestone 0 of the fmc8 UI modernization.
- Damage-grammar completion: the live **Mosin 1d10+68 on vc_rifleman one-shots the player at all ranges**
  (×2.0 torso vs 100 HP); enemies fire different weapons than their descriptions name. Delete/replace the
  4 WW2 .tres, fix vc_rifleman→SKS, rewrite CLAUDE.md's damage law.
- Kill the dead **GameEnums autoload (722 lines, zero references, boots every launch)** and the ~2,136
  lines of dead RTS import.
