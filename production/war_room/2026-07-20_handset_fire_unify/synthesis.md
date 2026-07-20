# DECREE — Unify the handset with the fire-support net (Stage 1 of 2)

**Date:** 2026-07-20 · **Arbiter:** Overseer · **Council:** ux-designer, systems-designer/programmer, devil's-advocate
**Summoner's ruling that opened this:** *"once i have the radio in my hand i had no options to call in any fire support or anything."*

## The invariant (law for this change)
`player.holding_handset` (player.gd:103) ⟺ `FieldDirector.fire_menu_open` (field_director.gd:192) ⟺ fire options visible. They may never disagree.

## Verified disconnect (file:line)
- `_on_handset_taken` (player.gd:335) sets `holding_handset`, slings rifle. Never opens the menu.
- T / `cas_strike` (field_director.gd:150-165) toggles `fire_menu_open` gated by `_radio_check()`. Never raises the handset.
- `bind_radio_handset`/`_attach_radio_to_rto` are called ONLY in the arena (ai_stress_arena.gd:1253,1294). Real game has no physical handset yet — T is its only net path.

## Council answers (unanimous)
- **Q1 — T auto-grabs from the squad RTO.** `_radio_check` already proves a living RTO within 10m; a second look-at gesture reads as a rail (Pillar 3). One key = "get on the horn." Aiming at the RTO stays for the ORDER menu (FOLLOW/HOLD/grab), not for fire.
- **Q2 — dispatch HANGS UP** (lowers handset + closes menu). A call goes out, the rifle comes back up — you fight, you don't loiter on the horn (Pillar 1/5). Repeat calls cost one T press.

## Architecture (decreed)
Single source of truth = `player.holding_handset`. `fire_menu_open` is a **terminal mirror**.
- `player.set_on_net(want)`: if want & a bound handset is stowed → `handset.take()` (fires `handset_taken`); else `_enter_net()`. If not want & handset HELD → `handset.stow()`; else `_exit_net()`.
- `_on_handset_taken → _enter_net()`; `_on_handset_returned → _exit_net()`. All visuals (rifle hide, placeholder) live in enter/exit; the callbacks only delegate.
- `_enter_net`/`_exit_net` write `holding_handset` AND call `FieldDirector.set_fire_menu_mirror(bool)` (set bool + emit `fire_menu_changed` ONLY — never calls back; forbid connecting the signal back).
- Field director's T handler + `_close_net()` (dispatch / radio-fail) call `player.set_on_net(want)` instead of writing `fire_menu_open`.

## Guards (from the council)
1. **Idempotency:** `_enter_net` returns early if already on net; `_exit_net` if already off. Absorbs the cord double-fire (radio_handset.gd:94-95 emits `cord_snapped` THEN `handset_returned`). `_on_cord_snapped` is bark-only; `handset_returned` drives the exit.
2. **Leash unchanged:** T handler keeps its `_radio_check` open-gate; `request_fire_support`'s own `_radio_check` (field_director.gd:211) is untouched. `set_on_net` is leash-free — the caller gates.
3. **Real game (no handset):** `_bound_handset` null → `set_on_net` falls to `_enter_net()` directly; null-guard weapon_model / placeholder / director lookup so the net opens rifle-slung with no art.
4. **Death/downed:** KIA → world teardown frees player+RTO+handset (mission_scope.reset already clears the static `any_fire_menu_open`). Residual in-world case = grab, get downed, revive → force `set_on_net(false)` on revive.

## Sacrifices named (no free lunch)
- Every dispatch auto-rips the handset back; two missions = two T presses. Judged correct.
- The cord becomes the tighter of two leashes: walking past cord-stretch on the net snaps you off (menu closes) before the 10m radio check would. Judged good — a physical leash on the RTO (Pillar 4).

## Stage 2 hand-off (leave field_director clean)
- Real game never calls `bind_radio_handset` — the squad RTO carries no `RadioHandset`. Stage 2 (garrison/defense) or a Blender handset pass must wire it for the real game to show the raised handset art; the state logic already degrades gracefully without it.
- RTO dying while on the net: `_radio_check` fails the next call and `_close_net` now lowers the handset too, but nothing proactively kicks the player off the net the instant the RTO dies. Stage 2 may want that.
