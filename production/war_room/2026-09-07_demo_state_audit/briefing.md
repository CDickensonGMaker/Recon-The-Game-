# BRIEFING — full council audit, "what stands between RECONgame and a playable demo"

**Convened:** 2026-09-07 evening, by the Summoner, in parallel with a separate BP RTS council.
**Arbiter:** the RECON Overseer. **Lenses summoned:** ux-designer, systems-designer,
technical-artist, technical-director (fossil/dead-wire), devil's-advocate.
**Mode:** AUDIT ONLY. No fixes, no commits. Every claim carries a number or a `file:line`.

## The question as put

> A stranger sits down, is given nothing beyond what the game shows, and inside ~15 minutes
> starts a session, understands what they are looking at, acts and has their actions do what
> they meant, meets the enemy, wins or loses on a stated condition, and is told so. Nothing
> crashes, nothing renders as a placeholder, nothing needs the console or the editor.

## The Arbiter's challenge to that definition (Law 1: no decree may violate a Pillar)

**Two clauses of the definition are WRONG FOR THIS GAME and are struck. One is upheld and is
the finding of the session.**

1. **"wins or loses on a stated condition" — STRUCK as written.** ADR-029 §4 and the Summoner's
   2026-08-06 EA ruling forbid a briefing UI, an objective counter and a pin. Pillar 3 (Freedom,
   no rails) means the goal is *legible from the world*, not printed on the HUD. A stated
   condition here means **the world says what it wants** (stand-to, the wire, the dark), not a
   line of text. The correct test is: *does the stranger know what is being asked of him?*
2. **"~15 minutes" — STRUCK as a scope, upheld as a warning.** The demo is a ONE-DAY, ~30-real-
   minute arc by the Summoner's own 2026-08-03 rescope (`demo_game.gd:38-45`), reversing his
   own 2026-07-30 "assault within 60 seconds". Auditing it against a 15-minute window measures
   a product nobody ordered. **But the warning is real and is measured below: the payoff is at
   minute 23-24 and there is no guaranteed contact before it.**
3. **"nothing renders as a placeholder" and "nothing crashes / needs the console" — UPHELD
   WITHOUT AMENDMENT.** These are r4bk and Pillar 2, and they are where the demo is weakest.

## Constraints honoured

No windows. Every Godot run `--headless`, one at a time, logged to the session scratchpad and
grepped. No `--import`. No editor. Binary
`C:\Users\caleb\_tools\godot47\Godot_v4.7-stable_win64_console.exe`.

## Runs taken this session (all headless, all logged)

| Run | Command | Result file |
|---|---|---|
| Main-scene boot | `--headless --path . --quit-after 900` | `recon_boot_main.txt` |
| Demo boot, seed 29072026 | `--headless res://scenes/levels/demo_game.tscn --quit-after 1200` | `recon_demo_boot.txt` |
| 13 gate tests, serial | `res://tests/test_*.tscn -- --test-save` | `recon_test_*.txt` |
| Demo siege study | `demo_game.tscn -- --perf-probe --perf-siege --test-save` | `recon_demo_siege.txt` |
| NEW probe: firebase extent | `res://tests/probe_fsb_extent.tscn` | `recon_fsb_extent.txt` |
