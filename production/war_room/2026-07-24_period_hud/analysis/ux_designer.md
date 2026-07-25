# UX-Designer Analysis — The Period HUD (640×480 doctrine)

**Architect:** ux-designer · **Convened:** 2026-07-24 · **Lens:** the four-element cap vs the r4bk Law
("a feature without a visible HUD affordance does not exist"). I judged the CODE, not the plan.

Sources read in full: `scripts/ui/hud.gd` (316 ln), `scripts/ui/mission_hud.gd` (353 ln),
`scripts/ui/action_progress.gd`, `scripts/autoload/game_settings.gd`, hud-system + interaction-prompts skills.

---

## The core tension

The handoff caps the **persistent** HUD at four elements — compass, roster, ammo, reticle
(briefing §"Four persistent elements MAX") — and bans per-man sub-lines outright
(`Roster ... NO per-man sub-lines`). r4bk says every live feature owes the player a visible tell.
The reconciliation the handoff itself supplies is the escape hatch: **"everything else is transient
or a sound."** So the real question is never "does it survive as one of the four" — it is
**"does each banished affordance have a legal transient/sound home, and does the player still learn
the state in time to act on it."** The five open items do NOT cover this. This is the integration work.

A transient overlay is r4bk-compliant *only if it fires when the state becomes true*, not only when
the player queries it. An affordance that appears **as a refusal after the press** fails r4bk — the
code already knows this (`mission_hud.gd:265-267`: "player must see he is off the net BEFORE he
presses T, not as a refusal after").

---

## 1. The full affordance ledger — every on-screen tell today, and its verdict

Every current affordance, its code home, and where it lands under the four-element doctrine.
Verdict key: **PERSIST** (folds into one of the four) · **TRANSIENT** (legal overlay, timed/state-gated) ·
**SOUND** (folds to audio/voice) · **DIES**.

| # | Affordance | Code home | Verdict | Where it re-homes |
|---|-----------|-----------|---------|-------------------|
| 1 | Compass 8-way + bearing | `mission_hud.gd:306-315` | **PERSIST** | IS element 1 (the amber plate). Direct fit. |
| 2 | Ammo round count | `hud.gd:144-146` | **PERSIST** | IS element 3 (32px count). |
| 3 | Spare MAGS | `hud.gd:146` | **PERSIST** | ammo block, 8px 2-digit zero-pad. |
| 4 | Weapon name | `hud.gd:155-157` | **PERSIST** | ammo block, 8px name line. |
| 5 | Grenade count | `hud.gd:173-174` | **PERSIST** | ammo block "GREN 2" (briefing folds it in). |
| 6 | Medkit count | `hud.gd:140-141` | **PERSIST** | ammo block "MED 3" (briefing folds it in). |
| 7 | Reticle | `hud.gd:15,55-56` | **PERSIST** | IS element 4. Note: green `(0.35,1,0.35)` → handoff `#96B45A`. |
| 8 | Squad roster name/MOS/status | `mission_hud.gd:246-255` | **PERSIST** | IS element 2 (the acetate form). |
| 9 | WEAPONS FREE/TIGHT | `mission_hud.gd:242-243` | **PERSIST** | roster header right cell ("WPNS FREE"). |
| 10 | Pointman "scanning 51m" sub-line | `mission_hud.gd:260-262` | **PERSIST (demoted)** | BANNED as sub-line → becomes the single roster **footer** "SCAN 51M" (briefing already specifies this footer). One line for the squad, not a per-man row. |
| 11 | **Off-net radio state** | `mission_hud.gd:257-259,268-273` | **PERSIST (re-homed) + SOUND** | BANNED as sub-line. See §2 — the dangerous one. |
| 12 | **Bleed-out clock** | `hud.gd:242-255` | **TRANSIENT (state-gated)** | Not one of the four. See §2 — the biggest casualty. |
| 13 | Hurt vignette (no HP bar) | `hud.gd:130-137` | **SURVIVES (diegetic, off-HUD)** | Already a shader overlay, not a HUD element. Untouched — it is the model for how RECON hides state in the world, not the plate. |
| 14 | Heal prompt "HOLD [F] TO PATCH UP" | `hud.gd:90-97,177-183` | **TRANSIENT** | Verb-prompt overlay; appears only with medkit out + packs>0. Legal — it is already transient by nature. |
| 15 | Field prompt (verb under feet) | `hud.gd:42-46,99-107` | **TRANSIENT** | The interaction-prompt pattern (skill §7). Appears only on a live verb in reach. Legal and *load-bearing* — without it caches/tunnels/shrines are invisible verbs. |
| 16 | Healing progress bar | `hud.gd:14,188-205` | **TRANSIENT** (or fold to ring) | Redundant with the action ring (#17); collapse the two. |
| 17 | Action ring (reload/heal/switch) | `hud.gd:18`, `action_progress.gd` | **TRANSIENT** | Center ring only while an action runs. Legal. |
| 18 | **Weapon jam feedback** | `hud.gd:211-214` | **SOUND + TRANSIENT** | Dry click (`GunFX.play_click`) is the primary tell; the ring reappears as the clear-action. See §2. |
| 19 | Slot indicator "1:PRIMARY" | `hud.gd:164-170` | **DIES / fold to #20** | Duplicate of the slot slider. Fossil-law candidate — two systems name the same state. |
| 20 | Slot slider (kit at a glance) | `mission_hud.gd:56-66,148-192` | **TRANSIENT** | Fades in on switch, out after 1.6s. Legal. Carries the r4bk-only tells for flares/claymores/satchels (`:172-176`) — those items exist ONLY here. |
| 21 | Fire-support menu (T) | `mission_hud.gd:81-119` | **TRANSIENT** | Held-key overlay = the open item (2) keyed submenu. Legal as a transient. |
| 22 | **Danger-close placement line** | `mission_hud.gd:127-146` | **TRANSIENT (inside #21)** | Lives inside the fire menu. Legal home, but a legibility hazard at 8px — see §4. |
| 23 | Damage-direction pip | `mission_hud.gd:195-207` | **TRANSIENT** | Ring wedge, 0.7s. Legal. Recolor to palette; drop the eased fade → hard blink. |
| 24 | Toast queue | `mission_hud.gd:283-290` | **TRANSIENT** | Top-center stack. Legal. Drop the 1.0s tween fade → 2-frame cut (briefing: no eased transitions). |
| 25 | Distant-squadmate markers | `mission_hud.gd:323-353` | **TRANSIENT (world-anchored)** | Pillar-4 "never lose your team". Legal as world-space transient; stripped by hardcore/SPARSE. |
| 26 | Death screen | `hud.gd:295-311` | **SEPARATE LAYER** | Full-screen; GameFlow owns it under fail-forward. Not a HUD plate. |

**Net:** of 26 affordances, four persist as the plates, ~14 are legal transients/sounds, two fold to
sound, one dies (slot_indicator, a fossil), and **two are genuine r4bk casualties that the four-element
cap orphans with no home the handoff names**: the bleed-out clock (#12) and off-net radio state (#11).

---

## 2. r4bk risk — what VANISHES under the cap, and the re-home rulings

The cap does not delete features; it deletes their *tells*. r4bk is violated the moment a live feature
loses its only tell. Four are in the danger zone.

### (a) Bleed-out clock — THE casualty
`hud.gd:5-6` states it outright: **"the bleed warning is the only numeric death clock the player ever
sees."** There is no HP bar by design (`:5,130`). If the number `BLEEDING OUT: 3.4s` (`:250`) vanishes
under the four-element cap, the player has **zero** numeric read on the one timer that ends the run.
This is the single most r4bk-load-bearing element in the codebase, and it is not one of the four.

**Ruling: re-home as a state-gated TRANSIENT that persists for the duration of the bleed, not a plate.**
It is legal precisely because "everything else is transient or a sound" — and a bleed is a bounded
event, so a transient that lives only while `is_bleeding` is true is honest. Author it as a red 8px
line stacked directly above the ammo block (same bottom-right stencil, no panel), flashing on the
2-on/2-off blink (briefing motion law) rather than the current `sin()` ramp (`hud.gd:62-65` — an eased
pulse, an anachronism to kill). The count swaps on a frame. It must be paired with a SOUND (a heartbeat
/ labored-breath loop that quickens) so a player looking down the sights still knows the clock is
running. **Tradeoff sacrificed:** the clock is no longer always-on furniture — but it never was; it only
appears when bleeding (`:242-244`), so nothing is actually lost except the false comfort that it "counts
as a fifth persistent element." It does not.

### (b) Off-net radio state — the question the roster ban creates
The roster's radio sub-line (`mission_hud.gd:257-259`) and its three states (`radio_state()`,
`:268-273`: ON THE NET / OFF THE NET — RADIO 14m / NO RADIO — RTO DOWN) are **banned** by the
no-sub-lines rule. But `:265-267` is explicit r4bk canon: the player must learn he is off the net
**before** he presses T. If this only surfaces inside the T menu (`:117` "[T] OFF NET"), it is a
refusal-after-the-press — an r4bk failure by the code's own standard.

**Ruling: fold net state into the PERSISTENT roster without a sub-line — the RTO's own status cell.**
The roster already has a right-aligned status column (OK/HIT/CRIT, `:253-255`, colors `:214-219`). Give
the RTO row a **fourth status token in that same cell**: `NET` (green `#96B45A`) when in range, `OFF`
(alert `#C04A28`) when tethered out, `—` when the RTO is KIA. Zero new lines, zero new geometry — it
rides the column the roster already owns, so it survives the ban and stays persistent. Back it with a
SOUND: radio static/squelch when the net drops, so the player hears the tether break while moving.
The tether distance number (`RADIO %dm`, `:273`) is the only casualty — acceptable; the binary
in/out is what gates the T press, and the compass already tells him which way the squad is.
**Tradeoff:** the player loses the exact metreage of the radio tether; he keeps the go/no-go.

### (c) Weapon jam
The jam tell today is a dry click + the reload ring reappearing (`hud.gd:210-214`). The ring is a legal
transient (#17). **Ruling: the SOUND is the primary tell (`GunFX.play_click`), the clear-action ring is
the transient confirmation.** No persistent element needed — a jam is an event, not a state. r4bk
satisfied by the click + ring. Safe.

### (d) Danger-close
Lives inside the fire menu, itself a transient (#21). It survives *as* a transient — legal. Its risk is
not vanishing, it is **legibility** at 8px — see §4.

---

## 3. Density (FULL/SPARSE/NONE) vs the existing hardcore toggle — reconcile

The codebase already ships a HUD-stripping switch: `GameSettings.hardcore` (`game_settings.gd:13`,
consumed at `mission_hud.gd:301-305`) hides **compass + markers** and, per its own comment, runs a
**faster bleed** (`:13`). Critically, hardcore is **coupled to a mechanic** (bleed rate) and to the
save system (`save_manager.gd:80`) — it is a *difficulty*, not a *display* setting.

The handoff's density is a **display-only** ladder: FULL (all four) / SPARSE (compass+order only) /
NONE (reticle only) (briefing §"HUD density").

**Is hardcore == SPARSE? No — and they must be untangled, or the Fossil Law (ADR-023) is violated the
day density ships.** They overlap (both hide markers) but differ in kind:
- hardcore strips compass; SPARSE **keeps** compass+order. They disagree on the single most-argued
  element. If both live, `_process` (`:301-315`) has two masters deciding the compass's visibility.
- hardcore changes bleed timing + save cadence. Density must not touch a mechanic — a display setting
  that silently makes you die faster is a UX lie.

**Ruling:** density is the display axis; hardcore's *display* effect is subsumed by choosing SPARSE/NONE,
and hardcore is demoted to **difficulty only** (bleed rate, save cadence, enemy aim). The old
`if GameSettings.hardcore: _compass.visible=false` block (`:301-305`) is **deleted** when density lands
(fossil law — do not leave the parallel path), replaced by a single `hud_density` read. The settings
screen line (`settings_screen.gd:57-65`) stops advertising "no compass, no objective markers" — that
sentence moves to the density control in the pause menu.

**Does SPARSE fight r4bk?** SPARSE hides roster + ammo. On the letter of r4bk, yes — the mag count and
squad status lose their tells. **But r4bk governs the DEFAULT (FULL) contract; a player who opts into
SPARSE has consented to read the world instead of the plate.** "Read the mag by weight, your men by
voice" is acceptable *as an opt-in* — the ammo/roster tells still exist at FULL, so the feature still
"exists" in r4bk terms. The line I draw: **NONE must still ship the state-gated transients (bleed clock,
danger-close, jam click) — you may hide the furniture, you may not hide the death clock.** A player
bleeding out with NONE selected still gets the red transient + heartbeat, because that is an event tell,
not persistent furniture. Encode this as a rule: **density hides PERSISTENT elements only; TRANSIENT
and SOUND tells are never suppressed by density.** That is the clean reconciliation.

---

## 4. The 8px / 640-buffer constraint on the transients — CONFIRMED, with one flag

The briefing is right and it must be enforced: **there is no second UI layer.** Every transient
(#14-25) authors into the same 640×480 buffer with the same 8px bitmap face (32px reserved for the
round count alone). Today they do not — they use `ReconUI.make_label(text, 16/17/30, ...)` at display
res with intermediate sizes (`mission_hud.gd:45,95,112,178,197,284`; `hud.gd:94,102,265`) and
`create_tween()` eased fades everywhere (`hud.gd:282-285`; `mission_hud.gd:203-205,287-289,191-192`).
All of that is the "modern tell" the handoff bans: 16px/17px/30px are illegal intermediate sizes; the
eased fades are the cubic-bezier anachronism. **Confirm the constraint: every transient collapses to
8px, hard-cut/blink motion, in the buffer.**

**The one thing that cannot live at 8px as written — the danger-close line (`mission_hud.gd:141`):**
```
"SNAKE EYE  240m  - DANGER CLOSE - MEN IN THE FOOTPRINT"
```
That is ~52 characters. At an 8px face with 0 letter-spacing on a ~208px-wide fire panel (briefing's
left overlay), it either clips (losing "MEN IN THE FOOTPRINT" — the whole point) or wraps (banned:
"clips, never wraps"). **This is the one transient the 8px grid breaks.** Rulings, in order of
preference:
1. **Split the warning off the metrics.** Line 1 (metrics, always): `SNAKE EYE 240M`. Line 2 (state,
   color-carried): `DANGER CLOSE` in alert red, or `LMB TO SEND` in olive. The words "MEN IN THE
   FOOTPRINT" become **redundant with the color** — red already means men are in it. Fits 8px.
2. Back it with the **blink**: a danger-close line blinks 2-on/2-off (the motion law already gives us
   this), so "danger" is carried by *motion + color*, not by a long English sentence. 8px + red + blink
   reads faster than 52 characters ever did.
3. The single most important beat — *are my own men in the blast?* — should ALSO be a **voice line**
   ("DANGER CLOSE!" from the FO), because at the moment of the send the player is aiming, not reading a
   left-panel line. Fold to sound as the backstop.

Everything else fits 8px. The 32px round count is the only large glyph, per the briefing.

---

## Verdict (sacrifice named)

The four-element cap is survivable — 14 affordances re-home cleanly as transients/sounds and one
fossil (the duplicate slot indicator) dies. **The one element the cap genuinely orphans is the
bleed-out clock:** it is the codebase's only numeric death signal, there is no HP bar behind it, and
it is not one of the four. It must re-home as a **state-gated transient + heartbeat sound**, and
density must be forbidden from ever suppressing it. Second casualty: off-net radio state, re-homed
into the RTO's existing roster status cell as a `NET/OFF/—` token so the player learns it before the T
press. **What is sacrificed:** the radio's exact tether metreage, the danger-close line's full English
sentence (carried now by color+blink+voice), and the false comfort that these were ever "persistent"
elements — they never were; they were always events, and the doctrine just forces us to admit it.
