# UX DESIGNER ANALYSIS — Full Game Audit (2026-07-09)
*Lens: what the player sees, hears, and understands. Covers HUD/UI, controls, onboarding, feedback, audio.*

---

## (a) Top 5 strengths

### 1. One coherent interface language, everywhere
`ReconUI` (scripts/ui/recon_ui.gd:1-163) is a real primitive kit — mono font, olive/amber/dim palette, hairline panels, card buttons, key-art screen roots — and every screen actually builds from it (main_menu.gd:42-65, briefing.gd:62-85, mission_hud.gd:41-48). Menus, HUD panels, and the fire menu all read as the same tactical document. This is rarer than it sounds at this stage; there is no "programmer UI" screen left in the flow.

### 2. The toast voice is diegetic and consistently in-fiction
Sixty-plus call sites, one channel (`director.toast`), and the writing never breaks character: "PAPA BEAR INBOUND - POP SMOKE AND HOLD THE LZ" (exfil_zone.gd:94), "TOO FAR FROM THE RADIO - GET TO YOUR RTO" (mission_director.gd:175), "CIVILIAN DOWN. THAT FOLLOWS YOU HOME." (civilian.gd:125). Promotion barks fire *at the moment of the deed* (ally_base.gd:51-55) — the learn-by-doing XP system is visible exactly when it should be. The DESIGN 4.10 "diegetic-first" vision is real *in tone*; it just isn't audible yet (see weakness 1).

### 3. Closed feedback loops on weapon state
The classic invisible-state traps are handled: jam gives a dry click + reload ring instead of a silent dead trigger (hud.gd:161-167), hitmarker has three distinct reads — white hit / yellow headshot / big red kill X with audio pitch layers (hud.gd:215-245), damage direction wedge (mission_hud.gd:163-173), slot slider that appears on switch and fades (mission_hud.gd:127-159), bleed-out countdown with flash (hud.gd:41-47, 195-208). Reload/heal/switch all share one `ActionProgress` ring vocabulary.

### 4. The "on the net" rifle-down state is physically readable
Opening the fire menu drops the viewmodel 60° and back (weapon_holder.gd:588-593), blocks aim/fire (weapon_holder.gd:171-179), and slows the player to a shuffle (player.gd:608-610), with the menu panel itself stating the contract: "RIFLE DOWN - AIM AT TARGET, PRESS NUMBER. [T] OFF NET" (mission_hud.gd:119). Cost of the call is communicated through the body, not a tooltip. This is the diegetic pillar done right.

### 5. Weapon/ambience audio architecture is ahead of the content
audio_manager.gd is production-grade: pooled 3D voices with priority stealing and transient locks (:234-253), distance-banded near/distant reports with per-weapon convention loading (:169-205), a tail/echo layer for the player's rifle (:280-287), ambience ducking so "the gun doesn't get louder; the world gets quieter" (:340-363). The wildlife ambience is a positional ring that re-seats around the player every 6s (game_world.gd:194-246) plus a night-insects swap (game_world.gd:250). HARDCORE cleanly strips compass and markers (mission_hud.gd:242-248). The plumbing for great audio exists; it's the *speech* layer that's missing.

---

## (b) Top 5 weaknesses — ranked by confusion caused

### 1. The entire event channel is silent 17px text — while 162 generated VO files sit unwired
Everything the squad "says" — CONTACT!, MAN DOWN!, THUMPER OUT!, grenade warnings — is a fading top-center label (mission_hud.gd:225-232: 3.5s hold + 1s fade, no log, no replay). In a firefight the player's eyes are on the center of the screen and on muzzle flashes; top-center text at font 17 is exactly where they are not looking. WIRING_STATUS.md:37 names it: "barks exist as on-screen TEXT only." Meanwhile `assets/audio/vo/` contains **162 finished, DSP-processed lines** across 9 voices — radio (15), squad barks (25×4 voices + medic 17), and Vietnamese enemy callouts (10×3 voices) — with roles already assigned (tools/voice_studio.py:108-112: joe=radio, john=squad, norman=medic, ryan=grunt) and line IDs that were *derived from the in-code bark text* (voice_studio.py:34-92). Zero references to `audio/vo` exist anywhere in scripts/ (grep confirms). PLAYER_MANUAL.md:40 even promises "when you hear 'LUU DAN!', move" — the game cannot currently make that sound. This is the single largest gap between the DESIGN 4.10 vision and the build, and the assets to close it are already on disk.

### 2. Detection state is invisible — a stealth economy with no speedometer
DESIGN.md:87 specifies "one subtle 'being noticed' directional pip sharpened by AL." It does not exist: WIRING_STATUS.md:23 confirms the player's `al` attribute is "saved, never read" and the pip is task #46. Today the player's only detection feedback is the *binary, after-the-fact* escalation toast "YOU'VE BEEN MADE" (mission_director.gd:71) — by which point the decision window is closed. The manual teaches a rich noise model (sprint 16m, gunshots 55m, monsoon halves hearing — PLAYER_MANUAL.md:38-45) that the HUD gives zero confirmation of. Players cannot tell whether crouch-walking is working, whether the rain is covering them, or whether that patrol is suspicious or oblivious. Stealth without perceivable state reads as random.

### 3. Key sprawl with a live conflict: key 6 is both CLAYMORE and CBU
project.godot binds `cbu_strike` (:129-133) and `place_claymore` (:174-178) to the **same physical key 54 ("6")**. The fire menu consumes `cbu_strike` while open (mission_director.gd:198-199), but `place_claymore` in player.gd:564 has **no `any_fire_menu_open` guard** (compare throw_smoke, correctly guarded at player.gd:560) — so pressing 6 on the net both **places a claymore at your feet and calls a cluster run**. Beyond the bug, the overload pattern is inconsistent: on the net, 5 means Spooky (was smoke), 6 means CBU (was claymore), 7 still pops a flare (mission_director.gd:194-195 deliberately passes). The full map is ~25 bindings (T/Y/G/B/V/M/P/Z/5/6/7/8/F1-F4/Q/E...), there is no controls screen in-game, and no remapping (settings_screen.gd exposes only sensitivity, volume, difficulty, hardcore).

### 4. Zero onboarding — minute 1 is a text wall and an unexplained AO
PLAYER_MANUAL.md is good writing but lives outside the build; no screen references it (grep for MANUAL/CONTROLS/TUTORIAL across scripts/ui/screens/: no matches). A new player's first minutes: menu → OPERATION ORDER text panel (briefing.gd:70-75) → deployed with a compass and a rifle. Nothing teaches F1-F4 squad orders, T=net, hold-G abort, B glassing, or that 5-8 are kit keys. Every one of those is a system the game is *about* (Pillar 4). The manual's fiction ("FM 69-1, PROVISIONAL") is itself the obvious in-game artifact — it wants to be a barracks/pause-menu document, and its controls table wants to be the pause screen.

### 5. One undifferentiated toast queue; no persistent objective/squad state
Promotions (★), KIA notices, objective completions, fire-mission confirms, leech flavor — all share one centered yellow queue at the same size and hold time (mission_hud.gd:225-232). High-stakes lines ("SAPPER IN THE WIRE!") visually equal flavor lines ("LEECHES. GODDAMN LEECHES."). Once a toast fades there is no recall: no message log, and no persistent objective line on the HUD — objective state lives only in world markers (hidden entirely in HARDCORE, mission_hud.gd:243-245) and the M map's marks (topo_map.gd:3). The squad strip polls HP status only (mission_hud.gd:189-222) — no ammo state, no revives-remaining, no orders-mode indicator (am I in HOLD or FOLLOW right now? Nothing on screen says). Minor but same family: hud.gd:111 shows exact round count, not the DESIGN 4.10 "ammo-by-mag icon."

**Accessibility note (unranked):** status colors are pure red/green semantics (mission_hud.gd:181-186, hud.gd:97-102) with no colorblind alternative; 11-13px DIM olive-on-dark labels (mission_hud.gd:119, main_menu.gd:60) are borderline at 1080p; no text-size option. Cheap to fix later, should be on the list before any public build.

---

## (c) The ONE next build: wire the generated VO into the existing bark hooks

**Why this over the detection pip:** the pip is one new indicator; VO transforms *every existing event* at once, and everything it needs already exists — the hooks (60+ `toast.emit` sites), the assets (162 processed .wavs), the role casting (voice_studio.py:108-112), the bus routing and voice pool (audio_manager.gd), and even the ID mapping (the manifest line IDs were written to mirror the in-code barks: `man_down`, `contact`, `weapons_free`, `fire_mission`...). It is the highest confusion-reduction-per-hour available, it converts weakness #1 and half of #5, and it is the single biggest lever on Pillar 2 (atmosphere) and Pillar 4 (the squad stops being labels and becomes *people* — John yelling "Doc's moving to you!" is characterization no stat sheet can buy). WIRING_STATUS.md:45 already calls audio/VO "the biggest felt absence."

**Shape of the work (1-2 sessions):**
1. `VOManager` autoload: `bark(category, id, speaker_node)` → resolves `res://assets/audio/vo/<voice>/<category>_<id>.wav`; radio lines play 2D on the Weapons/comms path (they're already band-limited), squad barks play 3D positional *from the speaking ally* via the existing voice pool; per-speaker cooldown + priority so it never becomes bark soup.
2. Refactor the ~15 highest-value call sites from `toast.emit(text)` to a helper that both toasts *and* barks: contact (squad_system.gd:255), man down/doc/revive (:130/:147/:165), point warning (:201), thumper (:227), weapons free/tight (:94), KIA (:267), and the radio set in mission_director.gd:241-273 + exfil_zone.gd. Text stays — it becomes the subtitle, which also future-proofs accessibility.
3. Map roles per MOS: RTO events → joe, squad default → john, medic lines → norman, rookies → ryan/bryce/hfc_male by roster slot. Wire the 30 Vietnamese lines into EnemyBase alert-tier transitions later (separate, but the manager supports it day one).
4. Housekeeping: rename `assets/audio/vo/joe the radio man voice/` → `joe/` (spaces in res:// paths; every other folder is already clean).

**Also do (15 minutes, it's a bug):** guard player.gd:564 with `not MissionDirector.any_fire_menu_open` so key 6 stops double-firing claymore+CBU.

---

## (d) Pillar scorecard (UX/audio lens, 1-5)

| Pillar | Score | Evidence |
|---|---|---|
| 1. Outstanding gunplay | **4** | Feedback loops closed: hitmarker tiers (hud.gd:215-245), jam tell (hud.gd:161-167), layered player-shot audio + tail (audio_manager.gd:257-288), rifle-down/sprint-lower body language (weapon_holder.gd:583-593). Held back by placeholder flesh-hit sound (WIRING_STATUS.md:32) and no explosion visual (:29) — impacts don't *land* yet. |
| 2. Atmosphere | **2** | Ambience beds, ducking, night swap are genuinely good — but the world is mute where it matters most: squad and enemies are silent text (WIRING_STATUS.md:37) while 162 VO files sit unwired. Text toasts over a jungle firefight is the single most fiction-breaking element in the build. |
| 3. Freedom / escalation | **3** | Escalation *is* communicated as consequence, not fail-state ("YOU'VE BEEN MADE," mission_director.gd:71; abort-anytime, :156-161; danger-close confirm respects agency, :239-241). But freedom requires informed choice, and the detection/noise state that informs stealth-vs-loud decisions is invisible (WIRING_STATUS.md:23). |
| 4. The squad is the RPG | **3** | Promotion-at-the-deed toasts (ally_base.gd:51-55), KIA with kill count (squad_system.gd:267), squad strip + off-screen member markers (mission_hud.gd:189-222, 269-274) all surface the RPG. But the men are voiceless, F1-F4 orders are undiscoverable, current order mode isn't shown, and member stats never appear in-mission. |
| 5. Fail forward | **4** | The down-not-dead loop is the best-communicated system in the game: bleed countdown (hud.gd:201-203), "DOC IS MOVING TO YOU (%d revives left)" (squad_system.gd:130), bird-down "MISSION CONTINUES" (insertion_ride.gd:231), death routed to debrief not a restart screen (hud.gd:248-253). Docked one point: the 30s revive clock itself isn't shown while you're down. |

*— UX Designer, War Room session 2026-07-09*
