# GAME-DESIGNER — Individual Sight
**Session:** 2026-07-31 demo ship audit · **Lens:** is the demo a good SHOW-OFF piece?
**Basis:** briefing.md + evidence.md (scout IDs cited). No cross-talk.

## 1. What actually READS on screen

A stranger watching 10-15 minutes of this demo will remember, in order:

1. **The air show.** Five aircraft, real ordnance, Huey landings (Scout 1 "air spectacle wired"). Aircraft over a jungle firebase is the single most Vietnam-coded image that exists. This is the poster.
2. **The night siege escalation.** "THEY'RE INSIDE THE WIRE" + siren + 4-squad assault + satchel breach (Scout 1 overrun chain). A scripted-feeling climax that is actually systemic — that is the show-off claim of the whole project.
3. **The firebase as a place.** Walking a real, sculpted FSB with mounds, wire, helipad. Rule #1 is "FUN to walk + FEEL Vietnam" and the walkable base IS the first 3 minutes of the arc.
4. **Lethality + audio.** 24-voice pool, HLL-style kills, VFX pass. Strangers feel gunfight quality instantly even if they can't name it.

What will NOT read, ever: the 2862-line AI coordinator, save migration, SimClock internals, the one-world-build-path architecture. Deep systems only show through the four surfaces above. Every fix should be judged by whether it feeds one of those four.

## 2. Gaps ranked by visibility-per-minute (not engineering severity)

**Tier S — a stranger notices in the first minute or at the climax:**
- **Dead base at boot (Scout 3 non-art cap: 7 men animate 198 markers).** The demo opens with the player standing in the firebase. Seven animated men in a base built for 198 work stations reads as "empty asset flythrough," and first impressions are unrecoverable in a show-off piece. Raising FSB_GARRISON_MAX_MEN is a config decision, not art. Highest visibility-per-hour item on either list.
- **D1 gate-funnel assault.** The climax is "they're inside the wire." If every squad conga-lines through one gate, the all-round-defense fantasy collapses into a tower-defense lane, and the viewer sees it from the first breach. This is THE centrepiece dependency and Scout 3 already scoped it (~1 day). Non-negotiable.
- **End card behavior (Scout 1 #4, #9).** The last thing a viewer sees is an opaque, undismissable card over a still-running siege, 80s after a "dawn" card while fighting continues. Demos are judged by their last 30 seconds almost as much as their first 60. Cheap fix (pause + dismiss + move card past MAX_DURATION or end siege at card), huge memory-of-the-demo value.
- **Player death freeze (Scout 1 #3).** In HIS hands, avoidable. In a stranger's hands at a show, near-certain during a night siege — and it ends the demo in a frozen screen. If anyone but Caleb ever holds the controller, this is Tier S; if it's capture-footage-only, it drops a tier.

**Tier A — noticed by anyone who looks where the demo points them:**
- **D7 RPG/RPD men holding launchers like rifles.** The siege camera-magnet enemies. RPG is the signature VC silhouette; wrong grip breaks period authenticity exactly where the player stares. ~2-3h per family, pipeline built.
- **D3 empty building interiors, props exported but unplaced.** The walkable-base pillar dies at the first doorway. Half a day of CODE (call `_furnish_interior`, fix INTERIOR_PROPS map) — Scout 3's own "best payoff-per-hour" call, and I concur.
- **D12 (partial): RPG procedural synth audio.** The signature siege sound being a synth stab undercuts the climax audibly. One or two real launcher samples covers the demo; the rest of D12 waits.
- **Double "STAND TO" + siren (Scout 1 #7).** Small, but it happens at the dramatic beat and reads as a bug to any viewer. Trivial guard.
- **Scout 1 #5/#6 SimClock dedup + air death at t≈213s.** The ambient air layer is half the "Vietnam sky" feel across the whole midgame; losing it after 3.5 real minutes quietly deflates the middle of the arc. Masked by the 42s demo cadence, so verify by eyes: if the sky still feels busy for the full arc, waive; if it empties, fix the dedup key.

**Tier B — visible but survivable:**
- **D2 medical complex export.** The casualty-ledger medic tent is a genuine show-off system; a patient on bare floor undersells it. Hours. Do it if D1/D3 land first.
- **D11 Spooky gunless.** Seen at distance, at night, muzzle-flash VFX carries it. Fix only if spare hours.
- **No demo build/export (Scout 1 #1).** Zero on-screen visibility, but it is the difference between "a demo" and "a thing only Caleb can run." Not a spectacle item — it's the ship gate itself. Belongs to tech-director, flagged here so the cut-line doesn't forget it.

## 3. Explicit waivers — do NOT spend week time on these

- **D4/D5 stale gun exports + placeholder ADS** — only visible if the player picks up a VC weapon and aims. For a show-off arc, keep the player on the finished US armory; waive except M16/M60 loadout must be benched (M60 hip_position bug, Scout 4 — waive by simply not issuing the M60).
- **D6 M79/LAW/RPG-7 player weapons** — the 15-min M79 is a freebie if idle; LAW/RPG-7 GLBs (2 days) are full-game.
- **D8 bunker slits + occupiable positions** — a whole feature, ~1 day+code, invisible unless you go looking. Full-game.
- **D9 claymore viewmodel, D10 ArmorersBench** — niche verbs nobody demos.
- **Scout 2 full-game gaps entirely**: sleep verb (demo arc has its own clock), hearts & minds, rank gates, dead route system, siege stakes, canon-index cleanup. None render a single pixel in the demo.
- **Scout 1 #2 double world-build** — wasted boot seconds, invisible after boot. Waive unless boot time is embarrassing on camera.
- **LIVE_CAP 50 vs 18** — don't touch pre-emptively; only if the perf pass (his eyes) stutters.
- **NPC footstep audio, VO barks, NVA flair, gore, tunnel kit, faction-sheet dedupe** — all full-game.

## 4. Designer's cut-line (ordered by spectacle value)

1. **Raise the garrison ceiling** so the base is ALIVE in minute one (config + one perf eyeball).
2. **D1 wire-ring split** — all-round assault at the climax (~1 day, the centrepiece).
3. **End-of-arc dignity**: dismissable/pausing end card + resolve the dawn/siege overlap + kill the double siren + a non-freezing player-death path (respawn-as-next-man or straight-to-card).
4. **D3 furnish the interiors** (half-day code) + **D2 medical export** (hours) — the walkable base earns its pillar.
5. **D7 launcher/MG poses** — the enemies you stare at hold their weapons right.
6. **Real RPG launch audio** (the one D12 slice that plays at the climax).
7. **Verify ambient air survives the full arc by eyes**; fix SimClock dedup only if the sky empties.
8. (Tech, not spectacle, but on the gate:) demo export preset + the 45-min playtest script pass — Scout 4 is right that his eyes are the critical path.

**Tradeoff named:** this cut-line spends the week on the first minute and the last five, and deliberately ships stale VC hand-weapons, empty bunkers, and a gunless Spooky. That is correct for a show-off piece: strangers remember openings, climaxes, and silhouettes — not inventory depth.
