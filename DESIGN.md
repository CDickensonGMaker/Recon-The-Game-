# RECON — Design Document

## One-Sentence Pitch

RECON is a systems-driven Vietnam combat-tour simulator where the player lives inside the war, not above it. What makes it unforgettable is the atmosphere of a lost 2002 PS1-era tactical shooter—*Parasite Eve* production values meets *Medal of Honor* memory-stain meets *SOCOM* squad tension—powered by emergent AI, persistent soldiers, and a randomly seeded world that tells a story with the player rather than to the player.

---

## Setting

Vietnam. Named explicitly. Not allegory, not a thinly-veiled Southeast Asian conflict.

The AO is a province-sized, randomly seeded map of coastal plains, river valleys, rolling highlands, steep mountains, and plateaus. Villages, firebases, paddies, trails, and jungle patches are placed procedurally within that seed. The same seed reproduces the same world; different seeds are different tours.

---

## Core Fantasy

The player is not a superhero. They are a soldier in a small unit inside a larger war. The fantasy has three parts:

1. **Tension before contact.** Patrol is long, quiet, and dangerous. Every bush could hide an ambush. Every trail could be mined.
2. **Chaos during contact.** When firing starts, it is sudden, loud, and confusing. The player must trust their squad, use cover, suppress, flank, and survive.
3. **Weight after contact.** Soldiers remember who died. The firebase feels different when half the squad is gone. The world does not reset.

The goal is not to "win" Vietnam. The goal is to survive an operation, bring as many people home as possible, and feel like the experience mattered.

---

## What RECON Is Not

- Not an XP-and-unlock shooter.
- Not a crafting or base-building game.
- Not a linear campaign with scripted missions.
- Not multiplayer.
- Not a cinematic cutscene game.
- Not a comedy or comic-book treatment of the war.

It is a single-player, emergent, systems-heavy combat tour simulator. Rule of Cool applies to action; tone stays grounded.

---

## Tone

*Platoon* meets *Hamburger Hill* meets a 2002 Vietnam FPS that never existed. Gritty, humid, exhausted, and dangerous. Avoid camp, avoid cheap heroism, avoid exploitative edge. The player should feel present, not entertained by spectacle.

Art direction: PS1/early-2000s inspired low-poly stylized realism. Strong silhouettes, efficient assets, performance-friendly environments. Not photorealism. Believability through identity.

---

## The Player Loop

RECON is built around a single **Operation** at a time.

1. **Deployment.** The player arrives at a firebase on a new seeded map.
2. **Missions of the Operation.** The squad receives a set of missions (recon, ambush, rescue, patrol, firebase defense, etc.) performed in a semi-open order. The player may die during any mission.
3. **Death and Continuation.** The player has two strikes before final death:
   - First death: unconscious. The squad medic will attempt to recover the player.
   - Second death: medic may still try, but can be stopped by enemy fire.
   - Third death: the player is dead.
   After final death, the player returns as a **new replacement** in the same squad. The squad remembers the dead soldier. New dialog, new names, same persistent unit.
4. **Operation End.** Once the operation's mission set is complete, the player may begin a new operation on a new seed with a new squad, or continue in the same persistent campaign.

The strategic layer across operations is intentionally lightweight for now: new map, new missions, same persistent war. A larger province-level strategic layer is future work and should be hardened separately.

---

## Pillars

> **⛔ SUPERSEDED 2026-07-19 — merged into `production/bible/BIBLE.md:62-90`, which is the text of record.**
> These five competed with a different five in the Bible and CLAUDE.md for the life of the project.
> The Summoner ruled: merge, keeping what each set uniquely held. **Pillar 3 below was the one the
> enforced set had dropped**, and its loss is why the squad was built as offsets from the player.
> It now lives inside merged Pillar 4. Kept here verbatim as the founding text; cite the Bible, not this.

### Pillar 1 — Believable Firefights

The AI must fight like soldiers. This is the load-bearing design law. Everything else—terrain, weapons, animations, sound—exists in service of this.

Good behavior: squads spread out, use cover, suppress and maneuver, maintain spacing, leaders direct, fire teams support each other.
Bad behavior: stacking, walking into fire, ignoring terrain, instant deathmatches.

> **AI Stress-Test Arena Law:** If soldiers cannot create believable large-scale engagements in a deliberately ugly arena, beautiful terrain will not fix the game. The arena is both an internal milestone and a design gate.

### Pillar 2 — Squad Attachment

Soldiers have names, MOS roles, injuries, moods, and histories. The player should remember them because of what happened, not because of stats.

Persistent squad memory is core now at the level of names, deaths, replacements, and squad banter. Full individual soldier memory logging (wounds, promotions, relationships) is aspirational and future.

### Pillar 3 — Player as Participant, Not Director

The player is a member of a squad. They can suggest movement, call targets, request support, but they do not puppeteer every soldier. The squad has its own AI intent.

### Pillar 4 — World as Story Generator

The seeded world creates tactical problems. Villages, ambush sites, trails, and firebases emerge from the same map. No two operations are identical. Stories come from what happened in this world, not from authored cutscenes.

### Pillar 5 — Consequences Without Cruelty

Death matters. Soldiers do not respawn as the same person. A failed mission continues. But the game is not a sadism simulator—players get two strikes, medics try to recover them, and the squad endures.

---

## AI Stress-Test Arena

A dedicated sandbox using the existing Gore Lab environment as a foundation. It is not a mission or campaign scenario.

### Purpose

Validate whether soldiers behave like soldiers when placed in a battlefield:

- Squad movement and spacing.
- Tactical positioning.
- Suppression and maneuver.
- Retreat and reinforcement.
- Communication and battlefield flow.
- Emergent, memorable events.

The question being tested: *"If I watched this battle without controlling anyone, would it look like a believable military engagement?"*

### Arena Zones

- **Central Combat Zone:** open space for long-range, flanking, and suppression tests.
- **Defensive Positions:** trenches, sandbags, fighting holes.
- **Natural Cover:** tree clusters, bushes, rocks, elevation changes.
- **Village Area:** simple VC/NVA-style buildings, paths, concealment.
- **Firebase Area:** US spawn point, defensive perimeter, resupply.

### Forces

- **US (Blue):** Alpha, Bravo, Charlie squads. Each has Squad Leader, RTO, Medic, Riflemen, Grenadier, Machine Gunner.
- **VC/NVA (Red):** enemy squad groups with squad leader, riflemen, automatic rifleman, support weapon, grenadier, plus ambush-capable units.

### Desired Combat Flow

Movement → Detection → Contact → Suppression → Maneuver → Flanking → Enemy Collapse / Withdrawal → Aftermath

Avoid: spotted → everyone shoots → one side dies.

### Evaluation Criteria

- Do squads spread out and use cover?
- Do machine guns pin enemies?
- Do leaders suppress while others move?
- Do squads retreat from losing positions?
- Do memorable emergent events happen?

---

## Technology Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Engine | Godot 4.7 | Gameplay, AI, procedural systems, world simulation, UI, save/load |
| 3D Pipeline | Blender | Low-poly characters, weapons, vehicles, environment, animation, rigging |
| Project Tracking | Beads | Tasks, bugs, design decisions, dependencies, session continuity |
| AI Assistance | Claude Code / agentic tools | Programming, debugging, system design, procedural support |

AI accelerates implementation. Design, tone, and direction remain developer-controlled.

---

## Development Priority

Build the smallest foundation that proves the core fantasy, in this order:

1. **The Soldier.** Movement, shooting, weapon handling, basic squad and enemy AI, tactical encounters. The player must already feel inside a dangerous battlefield.
2. **The Squad.** Persistent soldiers, names, MOS roles, morale, injuries, replacement system. The player begins caring about who survives.
3. **The War.** Persistent world events, villages, enemy influence, firebase operations, regional conflict. The player realizes the war exists beyond them.

The AI stress-test arena is the gate between Phase 1 and Phase 2. If soldiers are not believable, the squad layer cannot matter.

---

## Emergent Story Engine (Aspirational)

Future system: every soldier has a persistent history log.

Example:

- PFC Michael Hayes
  - Day 1: assigned to Bravo Squad
  - Day 4: survived first contact near Village 12
  - Day 9: wounded during VC ambush
  - Day 14: returned to active duty
  - Day 22: lost squadmate John Miller
  - Day 30: promoted to Corporal

This history should eventually influence morale, attitude, combat behavior, relationships, and squad cohesion. The player remembers soldiers because of what happened, not stats.

This is explicitly **aspirational**. It is not required for the first operation or the AI arena.

---

## AI Agent Development Rules

When using AI agents during development, evaluate every feature against the pillars:

Does it increase:
- Battlefield immersion?
- Squad attachment?
- Tactical decision-making?
- Persistent world simulation?
- Player agency?

If yes, continue.

If it creates busywork, artificial progression, arcade mechanics, or systems unrelated to the combat-tour experience, remove or simplify it.

---

## Summary

RECON is a systems-driven combat tour simulator, not a traditional mission-based shooter. The technology exists to create a world where soldiers remember, battles have consequences, the environment creates stories, and the player experiences history rather than controlling it.
