# GAME DESIGNER — Player death, respawn-as-another-man, lives economy
**Lens: the fantasy and the loop. 2026-08-22.**

## 1. Does respawn-as-another-man serve the grunt fantasy? Yes — and it may be the truest thing we ever add to it.

The tonal north star is Platoon / Hamburger Hill: attrition, dread, the squad as your only anchor. The core sentence of the fantasy is **"you are a line grunt, not an operator"** (GAME_GUIDE §1). An operator is irreplaceable; a grunt is, by definition, the man the Army replaces. A death system where the war shrugs and hands your rifle to the next man is not a compromise of the fantasy — it IS the fantasy, stated mechanically. Cannon Fodder's hill of graves and Easy Red's seamless takeover both understood this: the unit is the protagonist, the man is the ammunition.

It also fixes a live Pillar 5 violation we currently ship. The demo's death path is `force_death()` → end card "YOU FELL BEFORE DAWN" → a button literally labeled **"RESTART THE NIGHT"** (`scripts/levels/demo_game.gd:549,582,594`). That is reload-and-memorize with a period-correct font. Dying at minute 18 of a 20-minute siege and rebooting to minute 0 is the exact loop Pillar 5 forbids. Body-swap is the fail-forward answer: death mutates the story instead of rewinding it.

**One hard warning:** it serves Pillar 4 ("men die for real") ONLY if the life is a named man. An abstract ticket counter — Easy Red's ~40 — converts death from a loss into a currency, and Pillar 4 dies with it. We must never print "LIVES: 37."

## 2. What a life IS: the literal roster, never a number.

A "life" is a named soldier who exists in the world right now. You die; smash to black; you wake behind the eyes of another man already on the ground — a squadmate, a garrison man on the wire (`squad_roster.gd:95-111` already carries name/face/kit for exactly this). The man you were goes on the casualty ledger, and the ledger is the scoreboard (ruled 7/30). The demo's end card already prints KIA/HELD per named garrison man (`demo_game.gd:571`) — under body-swap, **your own previous bodies appear as KIA rows on that card**. That is the Cannon Fodder gravestone moment, and we get it nearly free. When the pool of men is gone, the fight is over — not because a counter hit zero, but because there is no one left to be.

## 3. Rank / reputation / armory when you're in a body bag — three options.

- **A. The rank dies with the man.** Full ADR-032 reset per body. *Emotion:* devastating, roguelike gravity; every patrol is your life's work. *Sacrifice:* SSG at ~48 patrols (ADR-032 tradeoffs) means no one ever sees SGT; it turns HLL lethality into a sadism simulator, which Pillar 5 explicitly forbids. Reject.
- **B. Everything persists untouched.** Rank, rep, nickname carry to the new body. *Emotion:* none — death is a costume change, Pillar 4 gutted. A cherry replacement addressed as "SSG" on his first step is fiction-breaking. Reject.
- **C. The institution remembers; the man is mourned (RECOMMENDED).** Reputation, rank, and armory tiers are the battalion's trust in your **slot/callsign** — institutional, they persist (ADR-032's economy and pacing untouched). The **personal layer dies**: nickname, service-record identity, kill count start fresh; barks call you "new guy" for a mission; optionally a small rep haircut (never below the current rank floor — a demotion cap, not a wipe). *Emotion:* death costs you your NAME — the thing Pillar 4 says matters — without torching 48 patrols of authority. The service record becomes a lineage of dead men, which is the most Platoon screen this game could own.

## 4. The demo siege: body-swap beats restart-day, decisively.

His instinct (~3) is right; the framing must be fictional. Not "3 lives" — **three named defenders**. You die on the wire; you wake as a pre-picked garrison man (give the second man the M60, the third the M79 — each death teaches different kit, free variety per life). The siege never stops; the tension never resets; the seam at night never gets memorized. Third death → end card immediately: "YOU FELL BEFORE DAWN," roster ledger showing every man you were. Garrison-as-pool (all ~45–50 men) is the purist answer but makes the demo unloseable and dilutes each death to noise — reject for the demo, keep it in the drawer for the campaign siege (ADR-036).

He is right about balance: with HLL lethality, no-cap means trivial, and restart-day means scumming. The lives pool is the correct fairness instrument — death cheap per man, expensive per battle.

## 5. Sacrifices (no free lunches) and scope.

- Body-swap sacrifices single-protagonist intimacy: "you" become a lineage, not a biography. ADR-032's rank-as-personal-identity gains a seam Option C only partially stitches.
- Killing RESTART THE NIGHT sacrifices the player's right to retry a bad night cleanly. Keep restart on the END CARD only, never mid-siege.
- REGULAR tier's F5/F9-anywhere (ADR-007) can dodge any lives economy. Named and accepted: the economy binds HARD/IRONMAN honestly; the demo has no quicksave path and is the proving ground.
- The abstract campaign "40" should be rejected even though the Summoner named it — the campaign pool must be the roster/replacement pipeline, post-EA design work.
- EA is 19 days out: the minimum honest version is **demo-only** — possess an existing garrison AI body (camera + control transfer), 3 named hosts, end card unchanged. Campaign body-swap, Option C's personal layer, and the tour-end state are post-EA.

**Recommendation:** rule the life = a named man; ship demo body-swap with 3 named defenders; adopt Option C for the campaign; never render a lives number anywhere.
