# WAR ROOM BRIEFING — The Hearts & Minds / Invisible Factions System
**Convened:** 2026-08-05 · **Arbiter:** RECON Overseer · **Status:** design only, NO CODE

## The ask (Summoner, verbatim)

> "start planning the hearts and mind system for the game and how it works. it doesnt need to be
> in the demo scope but something were claiming as a system and need to make."

Said after he ruled, earlier the same day, that levelling a village makes the enemy come after you
hard — *"thats the hearts and minds invisible factions sytem at work"* — describing it as though it
were live.

## VERIFIED GROUND TRUTH (measured 2026-08-05, before any architect was summoned)

**It is not live. Not one line of it exists.**

| Claim | Verification | Result |
|---|---|---|
| `ProvinceState` exists | `grep -ri ProvinceState scripts scenes` | **0 hits** |
| village `allegiance` exists | `grep -ri allegiance --include=*.gd .` | **0 hits** |
| `sympathy` exists | `grep -ri sympathy --include=*.gd .` | **0 hits** |
| `hearts_and_minds` exists | `grep -ri "hearts_and_minds" --include=*.gd .` | **0 hits** |

ADR-017 (persistent province) and ADR-019 (hearts & minds) are **decree with zero implementation.**
ADR-019's entire "work created" list — allegiance in `ProvinceState`, conduct tracking, district
manpower pool, allegiance-driven trap/ambush/informer density, sentiment language — is unbuilt.

### The two live hooks the design MUST be built on (verified)

1. **`EvidenceLedger`** — `scripts/enemies/evidence_ledger.gd` (107 lines, complete and used).
   Dated, decaying, scattered *fixes* of what the player left behind. Weights:
   `WEIGHT_GUNSHOT 1.0 · WEIGHT_EXPLOSION 1.4 · WEIGHT_BODY 2.0 · WEIGHT_BURNED 1.6`
   (`:15-18`). Decay `240s` noise / `900s` physical (`:22-23`). Scatter `55m` / `8m` (`:26-27`).
   `on_structure_burned` (`:71`) already exists and is the arson hook.
   Consumers: `scripts/enemies/enemy_base.gd`, `scripts/missions/field_director.gd`.
   **Scope: within one patrol.** Nothing carries it across the wire.

2. **`CampaignState.add_threat_modifier`** — `scripts/autoload/campaign_state.gd:222`.
   Appends `{delta, missions_left, reason}` to `threat_modifiers`, summed by `effective_threat()`
   (`:204-208`), labelled by `threat_label()` (`:211-219` → LOW/MODERATE/HIGH/CRITICAL), decayed one
   mission at a time in `on_mission_end` (`:234-239`), and **saved** (`:305`).
   Already read by:
   - `scripts/missions/siege_director.gd:191` — `NIGHT_CHANCE = {LOW 0.05, MODERATE 0.15, HIGH 0.30,
     CRITICAL 0.45}` (`siege_director.gd:11`). **Threat is already the odds the firebase gets hit at night.**
   - `scripts/missions/field_director.gd:1419` — `_grant_fire_support()`; HIGH/CRITICAL unlock napalm+CBU,
     CRITICAL unlocks Spectre.
   - `scripts/ui/screens/barracks.gd:45`, `scripts/ui/screens/main_menu.gd:97` — the player already
     reads the word.

   **This is a persistent, saved, decaying, already-consumed pressure road. It is the retrofit-free
   answer.** Only two callers feed it today, both AA-related (`campaign_state.gd:248,250`).

### The two load-bearing bugs (CONFIRMED)

**BUG A — `on_atrocity_witnessed` is a permanent no-op.**
`scripts/player/player.gd:249-250` calls `civ.call("on_atrocity_witnessed", ...)` behind a
`has_method` guard. `grep -rn "func on_atrocity_witnessed"` returns **zero definitions repo-wide**.
The guard is never true. The villager reaction to ear-taking has never once fired.
*Precision:* the toast `"THEY SAW YOU DO THAT"` at `:251` DOES fire (it is outside the guard), so
the feature reads as working while its only consequence is dead. That is the exact fossil shape
ADR-023 names.

**BUG B — `_bank_patrol` discards `civilian_deaths` on every successful patrol.**
- `MissionState.civilian_deaths` is fed correctly: `civilian.gd:630 _record_noncombatant_death` →
  `field_director.gd:88 record_noncombatant_death` → `mission_state.gd:26`.
- It is **deliberately kept out of `_base_result`** (`mission_state.gd:18-23` says so).
- `fail_mission` re-adds it by hand: `field_director.gd:210` `result["civilian_deaths"] = state.civilian_deaths`.
- **`_bank_patrol` (`field_director.gd:1768-1776`) does not.** It builds `state.build_result(true, "PATROL")`
  and never copies the key.
- The AAR line that would print it (`debrief.gd:89-90`) therefore only ever appears when you **die**.

Under ADR-029 open patrol, `_bank_patrol` is the primary bank point. **The number that hearts-and-minds
must eat only survives if the patrol was a failure.**

## Constraints binding every architect

- **ADR-019 §4** — allegiance is FELT, not read. A live numeric meter is FORBIDDEN. Debrief/board
  *sentiment language* is sanctioned and deliberately thin.
- **ADR-019 §3 (binding)** — the fast road must genuinely work. Burning the village must sometimes be
  the right call and must pay immediately and legibly. A morality meter with a correct answer is the
  PS2-cheese the Summoner rejected by name.
- **ADR-018 / ADR-032** — progression is never a number, anywhere.
- **ADR-006** — kills pay ZERO; +25 avoided / −25 detected. The score is a receipt.
- **ADR-023 fossil law, applied to design** — hearts-and-minds and the PARKED cord-token arc
  (`production/PARKED_cord_tokens.md`, innocent → ears → Buddha) are the same theme. Two systems
  saying the same thing is a design fossil.
- **`recon-bodies-give-intel-only`** — bodies yield intel points only. Do not invent a body-search reward.
- **`recon-garrison-soldiers-decree`** — garrison men are soldiers; `civilian.gd:633` already excludes
  them from the noncombatant tally. Civilian = noncombatant only.
- **ADR-031** — buildings destructible is DECREED but P5 is **NOT BUILT** and sits behind a perf gate.
- **NOT DEMO SCOPE.** Demo is a 30-minute one-day arc. Do not pad it.
- Perf: no gating FPS number is set; the frame is CPU-bound in the AI. Any per-village per-frame
  simulation must be priced.

## Questions each architect answers

1. What does the player FEEL when standing moves? Name concrete diegetic tells.
2. What moves the needle, and by how much relative to each other? Why?
3. Per-village, per-district, or one global number? What does each sacrifice?
4. How does standing become sim pressure over the `add_threat_modifier` road?
5. What is main-game vs what hook must be laid NOW to avoid a painful retrofit?
6. Where is the moral weight, and how does it not become two systems with the cord tokens?
