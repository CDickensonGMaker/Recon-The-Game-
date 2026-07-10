# UX DESIGNER — DRIFT AUDIT #2 (2026-07-10)
*Lens: what the player sees, presses, and understands. Every claim grounded in file:line.*

---

## THE FULL KEYBIND TABLE (from `project.godot [input]`, verified against handlers)

Physical keycodes decoded: 4194325=Shift, 4194326=Ctrl, 4194305=Esc, 4194332–4194335=F1–F4,
4194336=F5, 4194340=F9.

| Key | Action name | What it actually does | Handler | In manual? |
|---|---|---|---|---|
| W/A/S/D | move_* | movement | player.gd:602 | YES |
| Shift | sprint | sprint (blocked winded/wounded/on-net) | player.gd:648 | YES |
| Ctrl | crouch | crouch (hold) | player.gd:698 | YES |
| Z | prone | prone (toggle) | player.gd:606 | YES |
| Space | jump | jump | player.gd:693 | YES |
| Mouse1 | fire | fire / cook-throw frag (slot 3) / channel medkit (slot 4) | weapon_holder.gd:201, equipment_manager.gd:88-99 | YES |
| Mouse2 | aim | ADS (blocked while on the net) | weapon_holder.gd:198 | YES |
| Wheel | wheel_up/down | cycle slots 1-4 (guarded while net open) | equipment_manager.gd:62,75-78 | NO |
| R | reload | reload (also clears jams via reload ring) | weapon_holder.gd:207 | YES |
| Q / E | lean_left/right | lean; **E also raw context-interact during Huey ride only** | player.gd:720-723, insertion_ride.gd:107 | YES (E claim overstated) |
| 1–4 | slot_1..4 | weapon slots; **remap to bombs/napalm/arty/mortar while net open** | equipment_manager.gd:66-73, mission_director.gd:188-195 | PARTIAL (net remap absent) |
| 5 | throw_smoke | smoke; **= SPOOKY GUNSHIP while net open** (guarded, player.gd:610) | player.gd:610, mission_director.gd:200-201 | PARTIAL |
| **6** | **place_claymore AND cbu_strike** | **both actions bound to physical 54.** Claymore when net closed (guard player.gd:622-623); CBU when net open (mission_director.gd:202-203) | project.godot: cbu_strike + place_claymore both physical 54 | PARTIAL (claymore only) |
| 7 | pop_flare | pop flare — **NOT guarded by any_fire_menu_open** (fires even "rifle down on the net") | player.gd:633 | YES |
| 8 | supply_drop | resupply drop (RTO-gated) | mission_director.gd:206 | YES |
| 9 | use_ration | eat C-rats (restores hunger) — no net guard | player.gd:614 | **NO** |
| 0 | use_repair_kit | clean weapon (condition +45) — no net guard | player.gd:616 | **NO** |
| F | interact | loot / capture / tunnel / shrine / crate / ally kit / **TOC briefing / board bird at hub** | player.gd:629, hub_controller.gd:48,54 | YES (field uses) / **NO (hub uses)** |
| B (hold) | binoculars | zoom 18° + 2s-dwell target mark | player.gd:110-149 | YES |
| V (hold) | hold_breath | sway/spread cut while aiming | player.gd:100-107 | **NO** |
| P | photo_mode | free-fly spectator cam, HUD hidden | player.gd:521-548 | **NO** |
| M | map | topographic map toggle | topo_map.gd:142 | YES |
| T | cas_strike | **opens/closes the fire-support net** (6 options), not a direct strike | mission_director.gd:170-186 | **STALE** ("call CAS strike") |
| Y | mortar_strike | mortar shortcut (RTO-leash-gated) | mission_director.gd:204 | YES |
| G (hold 2s) | radio | ABORT — emergency exfil | mission_director.gd:161-168 | YES |
| C / F1 | squad_follow | squad: on me | squad_system.gd:81 | F1 only |
| H / F2 | squad_hold | squad: hold | squad_system.gd:83 | F2 only |
| X / F3 | squad_move | squad: move to aim point (**silent no-op if no ground point**, squad_system.gd:85-87) | squad_system.gd:85 | F3 only |
| N / F4 | squad_fire_toggle | weapons tight/free | squad_system.gd:89 | F4 only |
| F5 | quicksave | quicksave (tier-gated, refusal toast) | save_manager.gd:60-65 | **NO** |
| F9 | quickload | quickload — **zero feedback of any kind** | save_manager.gd:66-69 | **NO** |
| Esc | pause | freezes tree + shows mouse — **there is NO pause menu** | game_manager.gd:24-50 | **NO** |

**Collision verdict:** one true double-bind survives (key 6, deliberate + guarded — see Drift #2),
one fictional bind (hub "[E]" prompts require F — Drift #1), and a guard-consistency fork
(5/6 respect the on-the-net commitment; 7/9/0 don't).

**Learnability verdict:** ~34 bound inputs, zero in-game controls reference (settings_screen.gd
has sensitivity/volume/difficulty/hardcore only, :25-65), a stale manual, and loading-screen tips
(game_flow.gd:131-146) as the sole in-game teacher. The map is NOT learnable from inside the game.
Squad orders, the fire ritual, survival upkeep, and save rules are all discoverable only by
reading code or the (now-wrong) manual.

---

## (a) DRIFT CATALOG

### DRIFT 1 — Hub prompts say [E]; the game listens for F. **P1, code ≠ code ≠ docs**
- **Doc/intent:** PLAYER_MANUAL.md:15 "E doubles as context interact at prompts". HubController's own
  header comment (hub_controller.gd:4) says "distance scan + [E], copied from insertion_ride._poll_board".
- **Code:** insertion_ride.gd:107 accepts `interact` OR raw `KEY_E`. hub_controller.gd:48,54 checks
  **only** `Input.is_action_just_pressed("interact")` (= F, physical 70) while displaying
  `"ENTER THE TOC - GET BRIEFED [E]"` (:47) and `"BOARD THE BIRD [E]"` (:53).
- **Which is right:** neither. The prompt lies at the front door of the flagship new loop (commit 4573616).
  A new player walks to the TOC, presses E, leans right, and concludes the hub is broken.
- **Fix:** either adopt E-as-universal-context-interact (add E as a second binding on `interact`, retire the
  raw-key hack in insertion_ride) or change the prompts to [F]. One decision, applied everywhere. ADR it.

### DRIFT 2 — Decree item 1 said key-6 double-bind "fixed same-day"; the double-bind is still in the map. **Code ≠ decree wording (code is RIGHT)**
- **Decree:** synthesis.md:30 lists "key 6 double-bound (cbu_strike + place_claymore, physical 54)" under
  "fix TODAY", marked fixed in the addendum.
- **Code:** project.godot still binds BOTH actions to physical 54. The actual fix was a context guard:
  claymore refuses while `MissionDirector.any_fire_menu_open` (player.gd:619-623, comment "[audit fix:
  key-6 double-bind]"), and CBU only fires while the net is open (mission_director.gd:202).
- **Which is right:** the code. Shared-key-with-context-owner is a sound pattern (1-5 already work this
  way on the net). But the decree reads as "unbound", and nothing records the *pattern* as the decision.
  **ADR candidate #1.** Also fold in the stragglers: 7/9/0 ignore the same context (player.gd:633,614,616).

### DRIFT 3 — Decree item 5, second half: the detection "being noticed" pip DID NOT ship. **Code ≠ decree, code ≠ DESIGN**
- **Docs:** DESIGN.md:87 — "one subtle 'being noticed' directional pip sharpened by Al/perk" (pillar-level,
  diegetic-first HUD spec). Decree build order #5: "Stealth witnessed-contact fix **+ detection pip**".
- **Code:** the witnessed-contact half shipped (detection beacon on COMBAT entry, enemy_base.gd:189-190;
  mission_director.gd:52-71). The pip half: **zero UI**. The per-enemy `awareness` accumulator with a
  SUSPICIOUS threshold exists and decays (enemy_base.gd:73-74, 600-614) — the exact data a pip needs is
  computed every think-tick and shown to nobody. The only detection feedback remains the after-the-fact
  toast "YOU'VE BEEN MADE" (mission_director.gd:71), by which point the decision window is closed.
- **Which is right:** the docs. This is the second audit in a row flagging it. The stealth economy
  (fixed at the simulation layer) still *plays* as random because its state is invisible.

### DRIFT 4 — Survival v1 shipped with ZERO HUD affordance. **Code ≠ the r4bk law the council adopted**
- **The law:** last audit's lesson (briefing.md, r4bk): "features whose HUD affordance was dropped
  effectively don't exist."
- **Code:** hunger, stamina, breath meter, weapon_condition, ration/kit/claymore/flare/smoke counts —
  **none has any persistent display**. `grep hunger|stamina|breath|condition|ration|claymore|flare|smoke
  scripts/ui/` returns nothing. hud.tscn nodes: HP, bleed, ammo, grenades, medkits, crosshair only.
  The systems speak solely in threshold toasts: hunger <25 (player.gd:317-319), condition <60/<30
  (weapon_holder.gd:300), "C-RATS DOWN (2 left)" (player.gd:338). A player cannot answer "am I hungry?
  is my rifle dirty? how many claymores do I have?" without spending an item to read the toast.
- **Which is right:** the systems are good; the presentation was skipped — the exact one-line diagnosis
  of Audit #1, reproduced in the newest code. **This is the headline drift of the audit from my lens.**

### DRIFT 5 — Save backbone has no face. **Code ≠ code (feedback path broken in hub), docs silent**
- Quicksave "SAVED" toast routes through `director.toast` (save_manager.gd:292-295) → only MissionHUD
  listens (mission_hud.gd:25). **The hub has no MissionHUD** (hub_controller.gd:3 says so) → F5 at the
  firebase saves silently. Quickload (save_manager.gd:66-69) has no confirmation, no fade, no failure
  message anywhere. The HARD-tier wheels-down checkpoint (game_flow.gd:112-114) writes slot 5 with **no
  toast** — the one moment a hardcore player most needs to know "your progress is safe" is silent.
- There is **no save/load slot UI** at all: 10 slots exist (save_manager.gd:12-15), the menu exposes only
  CONTINUE-latest (main_menu.gd:52, game_flow.gd:279-284). Slots 1-7 are unreachable by any player.
- PLAYER_MANUAL.md contains no save section whatsoever.

### DRIFT 6 — Esc is bound to a pause with NO pause menu. **Code ≠ genre-baseline expectation, docs silent**
- game_manager.gd:24-50 toggles `get_tree().paused` and frees the mouse. `game_paused` signal has zero
  listeners outside game_manager (verified by grep). Result: frozen frame, cursor, no RESUME / SETTINGS /
  SAVE / QUIT. Mid-mission there is no path to settings or a clean exit except Alt-F4 (which, to its
  credit, exit-autosaves — save_manager.gd:39-44).

### DRIFT 7 — Difficulty checkboxes silently change SAVE RULES. **Code ≠ its own UI copy**
- settings_screen.gd:58: "HARDCORE (no compass, no objective markers)". barracks.gd:29: "IRON MAN (death
  archives the campaign)". But save_manager.gd:7-9,72-77 derives save TIERS from these same flags:
  HARDCORE also = HARD (no field saves, checkpoint-only), IRON MAN also = hub-saves-only. A player opting
  into "no compass" is silently opting into a different save contract, discovered only via the refusal
  toast "NO SAVING IN THE FIELD ON THIS DIFFICULTY" (save_manager.gd:65). The tier design is good
  (fail-forward-compatible); the consent copy is wrong. Update both labels; ADR the tier derivation.

### DRIFT 8 — PLAYER_MANUAL.md controls table is stale (9 gaps/errors). **Docs ≠ code**
Missing: rations [9], cleaning kit [0], hold-breath [V], photo mode [P], quicksave/quickload [F5/F9],
pause [Esc], squad secondaries C/H/X/N (PLAYER_MANUAL.md:24 lists F1-F4 only), wheel slot-cycling,
save tiers. Wrong: "T / Y | Call CAS strike / mortar" (:20) — T now opens a six-option fire-mission
board (mission_director.gd:170-203); "E doubles as context interact" (:15) — only true in the Huey ride.
The manual predates the campaign-loop overhaul entirely: no firebase hub, no TOC, no operation select
(§1 still describes "pick your op, fly in" menu flow).

### DRIFT 9 — Loading tip teaches a wrong key. **Docs-in-code ≠ code**
game_flow.gd:145: `"LOOT THE DEAD [E]"`. Looting is `interact` = F (player.gd:629,285-309). The one
teaching surface the game has, contradicting the bind.

### DRIFT 10 — Two HUD construction languages persist. **Code ≠ code (cosmetically converged, structurally forked)**
hud.tscn is the scene-built HoD-legacy HUD (ProgressBars, DeathScreen w/ RestartButton) retinted via
tactical_theme.tres and olive font colors (hud.tscn:5,90-110); everything newer is code-built ReconUI
(mission_hud.gd, hub_briefing.gd, all screens). The retint means the fork is invisible to players today
— good triage — but the modernization pass (fmc8) must pick one construction idiom or every HUD change
gets made twice. Note hud.gd:134 slot names ("1:PRIMARY...") duplicate mission_hud.gd:138-143 slot
slider — two widgets, same info, different vocabulary.

### DRIFT 11 — Fire-menu guard grammar is inconsistent. **Code ≠ its own fiction**
"On the net = rifle down, committed" is enforced beautifully: no aim/fire (weapon_holder.gd:195-201),
movement capped (player.gd:669-670), sprint blocked (player.gd:647), slots owned (equipment_manager.gd:62),
smoke and claymore guarded (player.gd:610,623). But flare [7] (player.gd:633), rations [9] (:614), and
cleaning kit [0] (:616) all still act while on the horn. Small, but it forks a rule the game otherwise
states with total confidence.

### DRIFT 12 — Squad status strip improved past the last audit, unratified. **Code > docs (drift is an improvement)**
mission_hud.gd:209-210 now shows "SQUAD // WEAPONS FREE|TIGHT" — the fire-mode indicator Audit #1 asked
for. Still missing: current order mode (FOLLOW/HOLD/MOVE — nothing on screen says which), and
squad_move with no valid ground point is a silent no-op (squad_system.gd:85-87) where fire support in the
identical situation says "NO TARGET - AIM AT THE GROUND" (mission_director.gd:242). Copy the grammar.

### DRIFT 13 — TopoMap's paper palette intentionally breaks ReconUI. **RIGHT — record it**
topo_map.gd:11-16 uses a 1960s paper palette, not ReconUI olive/amber. This is a diegetic prop, not UI,
and it's correct ("The map IS the AO", :4). Without an ADR, a future "consistency pass" will flatten it.

### DRIFT 14 — mission_select.gd:18-48 is dead code (early `return` at :17). Legacy offer-rolling kept
as unreachable commentary. Harmless, but it's exactly the doc-sprawl-in-code the Summoner fears.

---

## (b) TOP 5 STRENGTHS

1. **One UI language, deliberately extended.** ReconUI (recon_ui.gd:1-5) now covers menu (built to the
   Summoner's mockups, main_menu.gd:1-2), operation select, hub briefing, all screens, and the mission
   HUD panels — colors, mono font, hairline borders, card buttons. The praised strength survived the
   30-commit sprint. Modernization v1 (bead fmc8) is genuinely underway, not aspirational.
2. **VO wiring kept the toast-as-subtitle law.** vo_manager.gd:10-11: "Text toasts stay on screen as
   subtitles - VO is additive, never a replacement." Plus diegetic sourcing: radio traffic is positional
   at the RTO's backpack unless you're holding the handset (vo_manager.gd:43-57). Decree's ONE BUILD,
   executed with UX discipline.
3. **The fire-support net is the best interaction ritual in the game.** Menu lists exactly what the keys
   do with budgets and dim-when-empty (mission_hud.gd:105-119), the danger-close double-press with a 5s
   freshness window (mission_director.gd:220,248-255) makes you look at your men and mean it, and the
   rifle-down/slow-walk commitment is enforced across three systems consistently.
4. **Combat state is never invisible.** Jam = dry click + reload ring (hud.gd:161-167), three-tier
   hitmarker with audio pitch (hud.gd:215-245), damage-direction wedge (mission_hud.gd:163-173),
   suppression as shader + shake + lowpass (player.gd:842-898), bleed countdown. The gunplay feedback
   grammar is complete — it's the *survival* grammar that got skipped (Drift 4).
5. **The hub flow is prompt-led and state-aware.** TOC → board → bird reads without a tutorial:
   "GET BRIEFED AT THE TOC FIRST" when you approach the bird unbriefed (hub_controller.gd:59-62), board
   panel over the live world with no screen swap (hub_briefing.gd:1-4), firebase feeds you and cleans
   your rifle (game_flow.gd:354-361 — legible fiction for the meter resets). One wrong key label from great.

## (c) TOP 5 WEAKNESSES / RISKS (ranked)

1. **Survival v1 is invisible (Drift 4).** Violates the council's own r4bk law within days of adopting it.
   Hunger/condition/consumables effectively don't exist for a player who missed one 3.5-second toast.
2. **The hub's [E]/F prompt lie (Drift 1).** First-contact failure on the newest, most load-bearing flow;
   30 seconds into a fresh campaign the game teaches "prompts can't be trusted."
3. **The save backbone has no face (Drifts 5+6).** Silent saves, feedback-less loads, unreachable slots,
   no pause menu, silent HARD checkpoint. PHASE A is real engineering the player cannot see or trust —
   the exact "simulation built, presentation skipped" failure mode, again.
4. **Save-tier consent (Drift 7).** Two innocuous checkboxes silently rewrite the save contract. That's a
   trust wound in a fail-forward game whose whole pitch is "consequence, not punishment."
5. **No detection pip, two audits running (Drift 3).** The stealth economy — now mechanically sound after
   o18o — still presents as a coin flip. Pillar 3's "stealth optional" only reads as a choice if the
   player can see the stealth state they're choosing to manage.

## (d) PILLAR SCORECARD (UX lens)

| Pillar | Score | One line |
|---|---|---|
| 1. Outstanding gunplay | **4.0** | Feedback grammar complete (jam/hitmarker/wedge/suppression/recoil recovery); nothing fired leaves the player guessing. |
| 2. Atmosphere | **3.5** | VO + diegetic radio + menu soundscape are a real jump; silent saves, menu-less Esc-freeze, and lying prompts crack the fiction at the seams. |
| 3. Freedom | **3.5** | Abort-hold, escalation toasts, and the net ritual read clearly — but invisible survival meters and undocumented save tiers constrain choices the player can't see. |
| 4. Squad is the RPG | **3.0** | Orders now dual-bound + toasted + voiced and fire-mode shows on the strip; but order-mode state, discoverability (loading tips only), and a plain barracks keep the RPG at arm's length. |
| 5. Fail forward | **3.0** | Tier design is genuinely fail-forward; its communication is a refusal toast, a silent checkpoint, and mislabeled checkboxes. |

## (e) THE ONE THING TO BUILD NEXT

**The Player-State Layer: one HUD status cluster + the detection pip — sold as milestone 0 of the fmc8
modernization pass.** A single bottom-right ReconUI panel (the language already exists): hunger pips,
weapon-condition pips, ration/kit/claymore/flare/smoke counts, stamina/breath as thin bars — plus the
DESIGN.md:87 "being noticed" directional pip driven by the already-computed `max(enemy.awareness)`
(enemy_base.gd:73,600-614), amber at SUSPICIOUS, red at COMBAT.

Why this one: it retires the two oldest broken promises at once (r4bk's law and decree item 5's unshipped
half), it converts Phase C/D's *finished systems* from invisible to playable at pure-presentation cost
(every value is already on the player or one group-lookup away), and it is the correct FIRST slice of the
declared UI/UX modernization focus — you cannot "Delta Force-ify" screens whose core state layer doesn't
exist yet. (The [E]→F prompt fix in Drift 1 is a 15-minute rider, same PR: hub_controller.gd:47,53 +
game_flow.gd:145.)

## (f) ADR CANDIDATES (decisions living only in code/commits)

1. **Shared-key context ownership** — one physical key, the open context owns it (key 6 claymore/CBU;
   keys 1-5 slots/fire-missions), guarded via `MissionDirector.any_fire_menu_open`; rebinding is NOT the
   fix. Decision in player.gd:619-623 + mission_director.gd:188-203. Matters: next dev "fixes" the
   double-bind and breaks the net. Must also name the rule's scope (7/9/0 currently exempt — ratify or fix).
2. **Interact key doctrine** — `interact`=F everywhere; E accepted only as a raw-key alias during ride
   prompts (insertion_ride.gd:107) while all hub prompts print "[E]". Decide E-alias-everywhere vs
   F-labels-everywhere. Currently three surfaces disagree (Drifts 1, 9).
3. **Save-tier derivation** — REGULAR/HARD/IRONMAN derived from existing GameSettings.hardcore /
   CampaignState.iron_man with "no new knobs" (save_manager.gd:6-9,72-77); slot layout 0=quick, 1-7 manual,
   8 autosave, 9 exit; 30s autosave; exit-autosave on WM_CLOSE. Load-bearing and totally undocumented.
4. **Toast-as-subtitle law** — VO is additive; text toasts are never removed (vo_manager.gd:10-11).
   The single rule keeping one UI language through the audio expansion.
5. **Diegetic radio sourcing** — net traffic is 3D at the RTO's backpack unless the handset is up
   (vo_manager.gd:43-57). A pillar-2 commitment that a future "make VO louder" pass could silently undo.
6. **Squad order dual-binding** — C/H/X/N added alongside F1-F4 as the r4bk mitigation (project.godot
   squad_* double events). Also record: every order echoes a toast + VO (squad_system.gd:81-98).
7. **The hub is a live mission world with no MissionHUD** — prompts owned by HubController on layer 10
   (hub_controller.gd:27-35); consequence: `director.toast` has no display surface at the firebase
   (breaks save feedback, Drift 5). Ratify the architecture AND give the hub a toast surface.
8. **Hardcore = HUD-strip AND save-tier** (two effects, one checkbox) — settings_screen.gd:58 +
   save_manager.gd:8 + mission_hud.gd:243-245. Ratify as one deliberate bundle or split the toggles.
9. **TopoMap diegetic exemption** — the paper-map palette (topo_map.gd:11-16) is a prop, exempt from
   ReconUI; protect it from consistency passes.
10. **Danger-close confirm protocol** — same-kind second press within 5s, net stays open through soft
    failures, closes only on dispatch (mission_director.gd:220,225-257). The decree's fix produced a real
    interaction pattern; write it down before someone "simplifies" it.
11. **Photo mode [P]** — free-fly spectator with HUD hide and position snap-back (player.gd:521-548).
    Exists, unbound from any doc; decide if it's a shipping feature (then manual + guard against
    mission abuse) or dev tool (then debug-gate it).
