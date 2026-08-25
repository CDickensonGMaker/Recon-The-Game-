# RULINGS — Magazine ammo (Summoner, 2026-08-24)

A1. **BUILD ORDER RE-RULED**, his words: *"body swap to teammates, ammo than well run the siege
    test"* — the queue is now: (1) death body-swap build → (2) magazine ammo build → (3) THEN the
    siege playtest runs, verifying both. This supersedes "siege replay first" as the literal next
    build; the siege test becomes the verification gate at the END of the two builds.
A2. **SPLIT BY CALIBER.** M60 gunner hands M60 belts only; the grenadier keeps the 7/30 ammo box
    for rifle mags + 40mm. Both prior rulings survive.
A3. **HUD: v1 stays VISUAL AND EASY TO READ** — pips with legible fill, no press-check ritual yet.
    His words: *"i think for now we keep is visual and easy to read but maybe post launch add the
    full effect"*. The full press-check (modeled mag with rounds vs empty per weapon, heft ritual)
    is POST-LAUNCH. Approved craft note from him: *"we could cut up the reload animations for
    making a ammo check where its them taking the clip out, pausing and looking and than putting
    it back"* — the ammo-check animation is spliced from existing reload clips (mag out → pause →
    look → reseat), no new mocap.
A4. **LOADOUT TUNE ADOPTED:** M16 1 seated + 6 spare 20-rd mags (140 rds), gunner stock ~8 draws,
    siege ≈300-rd closed economy per man, dead gunner's corpse yields his remaining stock.
    Retunable after his playtest.

Binding from the synthesis: fullest-first auto-pick reload · partial pouches at true count ·
FeedType MAGAZINE/BELT/INTERNAL/SINGLE · kill current_ammo/spare_magazines mirrors + supply_crates
whole-kit verb (fossil law) · deep-copy the mounted-M60 snapshot (weapon_holder.gd:103/130 alias
trap) · save migration key + round-trip probe · ships with tests/test_magazine_ammo.
