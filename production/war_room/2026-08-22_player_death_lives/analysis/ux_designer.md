# UX DESIGNER — Death, rebirth, and the men left on the line (2026-08-22)

## What exists today
Flow-managed death shows the player NOTHING: `hud.gd:326-331` hides the bleed UI and returns
("GameFlow routes death to the debrief"); the standalone DeathScreen + `reload_current_scene()`
(`hud.gd:332-342`) never fires in the demo. The demo's actual death presentation is
`demo_game.gd:547-549` → `_show_end_card("YOU FELL BEFORE DAWN")`, which freezes the war
(`GameManager.pause_game()`, `demo_game.gd:559-560`), lists the squad by NAME with KIA/HELD
(`demo_game.gd:566-573`), and offers RESTART THE NIGHT / QUIT. Upstream, `health_system.gd:270-278`
already runs a downed/medic-revive layer (DOWNED_BLEED_SECONDS 30, `:267`) and a 25–30s bleed
clock (`:44-48`); only `force_death()` (`:282-287`) is the true end, routed via
`field_director.gd:219-220` to `fail_mission("KIA")`. Body bags as cumulative scoreboard are
already canon (`campaign_state.gd:51`).

## 1. The death→rebirth moment — RECOMMEND: the epitaph card over a running war
Not Easy Red's hard cut (reads arcade), not "wake as the man who dragged you" (beautiful, but it
requires a rescuer to exist at a scripted spot — that is a rail, and it collides with the medic
revive layer which already owns that fantasy). The cheap, PSX-honest shape:

1. Bleed-out/death plays exactly as now — vision collapses, `force_death()` fires.
2. Screen goes to black **but the war does not pause**. Audio keeps running: gunfire, the wire,
   then a radio bark ("CONTACT — MAN DOWN, MAN DOWN—"). Sound continuing under black IS the
   "war goes on" read; it costs one ColorRect and one voice line.
3. On the black, 3–4 seconds, ReconUI amber on black (the end card's exact idiom):
   **`PFC MERCER — KIA` / `the line holds`** — then one line naming who you wake as:
   **`YOU ARE CPL DOAKES`**.
4. Cut into Doakes's eyes at his fighting position, weapon already up, muzzle flashes on the
   wire. No camera flight, no kill-cam, no body pan. The disorientation is the feature.

Everything here is existing kit: ReconUI labels, a CanvasLayer, the toast/radio audio path.
Crucially the swap fires only AFTER `force_death()`, so the entire downed→medic economy
(`health_system.gd:270-278`) is untouched — a life is only spent when the medic fails, which
makes the medic sprint matter more, not less.

## 2. The lives affordance (r4bk) — the counter is NAMES, shown when it changes
No persistent "LIVES: 3". The pool is legible three ways, all period:
- **At the swap** (the moment the number changes — the only moment it matters): under the
  epitaph, the remaining men by name: `HOLDING: DOAKES · WEBB`. Two names is a number a
  stressed player reads in half a second.
- **On the end card**: the roster already lists KIA/HELD (`demo_game.gd:566-573`) — every body
  you inhabited shows KIA there. Zero new work.
- **On demand**: the same names on the pause/map screen. Body bags stacking is canon and should
  still happen at the aid station, but bags at night from a fighting hole are atmosphere, not an
  instrument — do not lean on them for legibility.

## 3. Pool empty
The demo already owns this screen: the `ENDING_PLAYER_SURVIVES=false` branch
(`demo_game.gd:543`, "THEY CAME BACK FOR THE WIRE") proves a fall-variant card is one string
away. Final man dies → **"THE WIRE BROKE BEFORE DAWN"**, full named roster all KIA/DIM, same
RESTART THE NIGHT button. It is an ENDING, not a game-over: fail-forward as presentation.
Campaign tour-over screen is post-EA.

## 4. Frustration curve — 3 is right IF they are men, not lives
HLL lethality means a cherry can burn three bodies in five minutes of siege. That is survivable
emotionally because (a) the day phase is combat-free, so the pool only drains in the last
~10 minutes; (b) each loss is a named man with an epitaph — dread reads as story, not as a
depleting arcade meter; (c) the empty-pool state is a dramatic card, not a "YOU LOSE, retry"
slap. Framed as `HOLDING: <names>`, 3 creates the right dread; framed as `LIVES: 3` it would
invite rage. Five men would dilute each death's weight and pad the card list. **3.**

## Tradeoffs named
- 3–4s of black under fire: you can be shot at while blind — accept it; being helpless during
  the epitaph is the fantasy. If playtests scream, damage-immune only while the card is up.
- No persistent counter: a player may forget how many men remain until the next death. That
  uncertainty is dread and it is deliberate; the pause screen is the safety valve.
- Swapping bodies means inheriting the next man's loadout, not yours — that is a systems ruling,
  but presentation-wise it must be TRUE (his rifle in your hands) or the swap reads fake.
- Rejecting "wake as your rescuer" sacrifices the strongest single image on the board for
  no-rails purity. Post-EA, the medic-revive success path already delivers a cousin of it.
