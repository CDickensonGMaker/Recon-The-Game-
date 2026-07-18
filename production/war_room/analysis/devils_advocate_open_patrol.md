# DEVIL'S ADVOCATE — OPEN PATROL PIVOT: THE SACRIFICE LIST (2026-07-17)

Verdict up front: **the decree's fantasy has no content engine behind it.** The briefing is not what
stands between the player and an open patrol — MissionGenerator.build() is the only code path that
populates the AO, and it is fused to the offer/plan dict the briefing produces. Remove the briefing
naively and you ship an empty walk. **The briefing is the ignition key for the only world that
exists. Pull the key LAST, not first.**

## Sacrifice list (evidence in code, severity, salvage)
1. **The populated world — P0, extract don't delete.** Villages/civilians/paddies/ambient
   patrols/camps/convoys/weather/craters ALL stamp inside plan()+build()
   (mission_generator.gd:103-644); build_hub is "No objectives, no enemies" (:896-924).
   LocationPlanner is test-only. Cut naively → RULE #1 dies at the wire.
2. **MissionDirector — must-survive-headless. It is the field OS, not a mission tracker.** Toast bus
   (40+ emitters: barks, KIA, traps, SAVED), hunter escalation + finite pool, fire-support net + RTO
   leash + danger-close, supply drop, state.flags written by squad/civilians. Hub already runs it
   missionless (game_flow.gd:411-423). Salvage: rename field director.
3. **Toast display already broken at hub → total blackout. P0.** Only MissionHUD connects the toast
   signal; enter_hub creates no MissionHUD. Open sim on hub context = every bark/KIA/save toast
   INVISIBLE. Ship a stripped FieldHUD (toast + compass + squad strip) or Pillar 4 is inaudible.
4. **Death is a soft-lock. P0.** mission_failed connected only in _run_mission; hud death screen
   suppressed under managed_by_flow. Die outside the wire: nothing happens. Pillar 5 lives entirely
   inside the mission frame today. Must build: death → field AAR → wake at firebase, consequences
   committed.
5. **Scoring/stealth economy loses its payout moment. P0-design.** ±25 ledger, ghost bonus, team_xp
   all pay at the debrief. No debrief = stealth becomes vibes. Salvage: patrol AAR on
   return-to-wire — the closure moment the decree needs anyway.
6. **CampaignState all-or-nothing bracket breaks both ways. P0.** Without begin_mission: KIA writes
   hit disk instantly unframed; with begin and no end: _defer_saves forever, nothing persists until
   quit. A new commit point (return-to-wire) must be DESIGNED.
7. **Rank freezes at PVT forever. HIGH.** rank_for reads member["missions"], incremented only in
   on_mission_end. LW-10's "promotion is the tutorial" loses its clock. (credit_use learn-by-doing
   SURVIVES if #1/#2 survive.)
8. **Intel (W80) becomes a dead number. MEDIUM.** 5 award sites, one consumer (briefing fuzz), one
   sink ("spent going in"). Fossil law: delete the whole 6-site chain or give it a new consumer
   (intel sharpens the pointed location).
9. **Threat/AA layer inert but live-looking. MEDIUM.** threat_level mutates only in on_mission_end;
   frozen below the 0.5 AA gate forever. Park or retarget to patrol outcomes.
10. **Mission-scoped economies become one-shots. HIGH, subtle.** revives_left=2, _hunter_pool=12,
    supply_used, fire_support budgets reset by OBJECT LIFETIME per mission. Endless session: Doc
    revives twice EVER. Every one needs an explicit per-patrol reset.
11. **Save shape + CONTINUE. HIGH, silent.** hub_snapshot carries offers/accepted_offer/
    checkpoint_offer; CONTINUE routes checkpoint_offer into start_mission. Removal requires
    SCHEMA_VERSION bump + migration or old saves dead-end.
12. **Complications + weather variety are briefing-born. MEDIUM.** enter_hub hardcodes CLEAR/DAY;
    offer roll carried weather/time/complications. Re-home the draws to world-gen or every patrol
    is the same sunny afternoon.
13. **Exfil chain honestly dead (foot-only), one gap:** nothing replaces extraction as the
    commit moment; return-to-wire detection does not exist and must be written.
14. **Survival economies half-survive.** Hunger drains only in context=="mission"; hub resets it.
    Rations need the patrol context or they never matter. Weapon condition + armorer bench survive.
15. **DynamicMissionFactory — the decree's own engine aimed at the thing being deleted.** Converts
    sim events into OFFERS. Retarget outputs to pointed locations or it fossilizes on pivot day.

## Three regrets within a week
1. #1 Empty world on night one — the pivot's promise unfulfilled by the pivot's own cut.
2. #4+#6 Death/persistence have no frame — first death outside the wire is a silent soft-lock.
3. #5+#7 Nothing pays — "the game stopped keeping score"; k77e (Living War) is keyed to the exact
   pipeline being deleted.

## Minimal honest cut
KILL (fossil law, fully): HubBriefing, BriefingScreen, MissionSelectScreen, MissionOffers, TOC
prompt + briefing gate + board-the-bird flow, show_select/show_briefing/launch_accepted,
insertion_ride, exfil bird chain — WITH schema bump + CONTINUE rewrite.
MUST SURVIVE HEADLESS (rename, don't remove): MissionDirector→field director, stripped FieldHUD,
MissionState contact ledger as patrol ledger, credit_use, casualty persistence + NEW per-patrol
resets, return-to-wire commit, death→AAR→firebase loop.
PARK-FOR-LW behind flags (beaded UNFINISHED, not FOSSIL): result pipeline (retarget = patrol AAR),
DynamicMissionFactory (retarget to locations), plant/rescue sensors (future pointed-location
content), intel (new consumer or full deletion). Deleting these is deleting the Living War epic's
spine and calling it cleanup.
PRECONDITION: extract build()'s population pass into the resident world build (ADR-028) BEFORE
removing the briefing.
