# RECONgame — Wave 2 backlog (R49–R98)

> **DEAD — do not plan against this file.** ADR-014 (`production/adr/ADR-014-doc-hierarchy.md`:44-46)
> collapses the four roadmap files into `ROADMAP.md` alone and names ROADMAP_NEXT.md, ROADMAP_WAVE2.md,
> and WAVE3_REPORT.md DEAD. The consolidation was never executed, so these files still sit at repo root;
> that is a leftover, not a licence. Task truth lives in beads (`bd ready`), not here.

Fifty items beyond ROADMAP_NEXT.md's 48. No repeats. Council-sorted, P1/P2/P3.

## GUNPLAY & PLAYER DEPTH (game-designer)
49. **P1** Prone stance (missing since HoD) — crawl speed, tiny profile, prone-only weapon steadiness
50. **P1** Stamina: sprint drain, winded sway/aim penalty, encumbrance from loadout weight (RECON St rules)
51. **P2** ADS FOV zoom re-enable per-weapon (`ads_fov` exists unused; sync viewmodel editor)
52. **P2** Weapon sway + hold-breath (shift while ADS steadies, costs stamina)
53. **P2** Grenade family: frag / WP (burns) / smoke / CS — smoke pops mark the LZ ("POP SMOKE... I SEE PURPLE")
54. **P2** M79 arc projectile (real lob, 10m arming distance per RECON)
55. **P2** LAW rocket: single-shot anti-structure — breach bunkers, kill vehicles properly
56. **P2** Knife melee + silent sentry takedown from behind (Ag roll — failure = scream noise event)
57. **P2** Weapon pickup from dead enemies (AK ammo economy + enemy sound signature disguise per RECON p.23)
58. **P2** Bandage vs medkit split: bandage stops bleed only, medkit restores (RECON medic economy)
59. **P3** M60 bipod deploy (prone/sandbag = laser, standing = hose)
60. **P3** Ammo resupply crates at firebases; ask allies for a mag (bark interaction)

## ENEMY AI DEPTH (systems-designer)
61. **P1** AI grenades: flush the player from cover (cooldown, telegraph shout "LUU DAN!")
62. **P2** Pair tactics: bound-and-overwatch — one suppresses while one moves
63. **P2** Wounded state: gutshot enemies crawl, cry out (noise draws buddies, grim ambience)
64. **P2** Spider-hole pop-ups: stamped holes hide an ambusher who emerges behind you
65. **P2** Pursuit squads: after hard detection, a tracker team hunts your trail for N minutes
66. **P2** Enemy mortar team POI: fires on firebase/player until destroyed (counter-battery objective)
67. **P3** Tunnel retreat: mauled VC squads break for tunnel entrances and despawn (they live to fight later missions)
68. **P3** Civilians flee gunfire, cower indoors; killing them tanks score + war state

## WORLD & IMMERSION (technical-artist + ux)
69. **P1** Distant-war ambience layer: far artillery rumble, arc-light thunder, drifting flares on horizon at night
70. **P1** Rain masks sound: monsoon halves NoiseBus radii — move loud when the sky is loud (weather-stealth synergy)
71. **P2** Burning huts: napalm/WP ignite thatch structures (spreads, burns out to husk)
72. **P2** Generation-time old craters: pre-war B-52 strike scars, some water-filled (craters as terrain history)
73. **P2** Rice paddies: knee-deep slow + visible wake + louder movement (risk/reward open ground)
74. **P2** Vegetation wind sway shader tied to weather wind speed
75. **P2** Rotor wash: grass/dust flattening VFX under landing Huey
76. **P2** Mud/water/foliage footstep audio zones (GameplayGrid terrain type driven)
77. **P3** Night insects/fireflies; wildlife flees from movement (visible tell for BOTH sides)
78. **P3** Tracers light the jungle at night (light emission on tracer nodes)

## MISSIONS & SYSTEMS (game-designer + systems)
79. **P1** Complications table: each mission rolls 0-2 modifiers — night op, monsoon, bad intel (objectives shifted), VC spotter tailing you, short ammo, no CAS (RECON MD tables)
80. **P1** Intel pickups: documents on officers/in hootches reveal next-mission POIs or strip intel fuzz (SECURITY loop)
81. **P2** PRISONER SNATCH mission type: subdue the target (non-lethal beat), escort walks with squad AI to exfil
82. **P2** WIRETAP/SENSOR STRING mission type: plant 3 devices along a trail, pure stealth-optional SECURITY
83. **P2** Weapons-free vs weapons-tight ROE per mission (score bonus for tight discipline on SECURITY ops)
84. **P2** Commendations: named medals w/ criteria (Silver Star = clean sweep no damage; Purple Heart = extracted wounded)
85. **P2** Career stats screen: missions, kills, K/D of your squad, seeds played
86. **P2** Named squadmates roster-lite: names on HUD pips, per-mission kill tallies, death announcements ("DOC IS DOWN")
87. **P2** Difficulty presets: enemy density/accuracy-ramp/damage multipliers + HARDCORE toggle (no markers, no compass)
88. **VOID — no screen left to put it on.** There is no mission select: `scripts/ui/screens/mission_select.gd` is deleted (only the orphan `mission_select.gd.uid` remains, alongside `briefing.gd.uid`), and ADR-029 deletes the briefing/offer/select chain outright (`ADR-029-open-patrol-simulator.md`:37). The debrief still prints the seed — `"MISSION:      %s (SEED %d)"` (`scripts/ui/screens/debrief.gd`:70) — so seed sharing survives as a read-only display, not an entry box.
89. **P3** RON (rest overnight) beat for long patrols: set perimeter, claymores out, night watch wave
90. **P3** Chieu Hoi surrender: broken militia throw hands up — capture = intel + score vs the dark alternative (war-state consequence)

## TECH / POLISH / SHIP (technical-director)
91. **P1** Pool tracers + impact effects (allocation spikes in firefights)
92. **P2** Visibility ranges on site structures (hide behind hills — free perf)
93. **P2** Settings persistence to user://settings.cfg (sensitivity, volume, quality)
94. **P2** Gamepad support pass (input map + aim assist curve)
95. **P2** Loading screens: period tips/RECON manual quotes ("WHEN IN DOUBT, TRUST YOUR ALERTNESS")
96. **P3** Photo mode: freecam + HUD toggle (marketing shots)
97. **P3** Windows export preset + build script (one command → zip)
98. **P3** Crash/error log capture to user:// for playtest reports
