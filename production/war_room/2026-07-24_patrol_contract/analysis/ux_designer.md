# UX-DESIGNER — The Patrol Contract (player-facing surface)

**Session:** 2026-07-24 · Lens: route authoring, command tasking, order confirmation, OP-state, HUD reconciliation.
Judged the CODE, not the plan. Pointers are `file:line`.

---

## 0. What the code actually is today (the substrate I am building on)

- **`topo_map.gd`** — a full-screen `Control` modal, `visible` toggled by `M` (`_unhandled_input:159-162`).
  It draws in one pass, `_draw_overlay:132`: roads (`_draw_roads:115`), the CO's grease-pencil **SWEEP**
  circle (`:138-144`, "never checks off, never updates" `:136-137`), and the player's green heading arrow
  (`:146-156`). The world↔screen transform is `_world_to_map(pos)` `:127-129`:
  `Vector2(pos.x/map_size*s.x, pos.z/map_size*s.y)`. **There is no inverse, no click handler, no player
  input on the sheet at all.** Opening the map re-barks the point man (`:164-165 → rebark_patrol`).
- **`mission_hud.gd`** — compass Label (`_compass`, built `:45`, updated `:308-315`,
  `"<<  N  000  >>"`); toast queue (`show_toast:283-290`, 3.5s fade); squad roster strip
  (`_update_squad_strip:222-263`, header `"SQUAD // WEAPONS FREE"` `:243`, per-member row
  `nick/mos/status` `:254`). **Hardcore hides the compass AND markers** (`:302-305`).
- **Squad orders already exist** (`squad_system.gd:147-178`): FOLLOW / HOLD / MOVE_TO + weapons-free
  toggle, each firing `_order_all` → **one toast + `squad_changed` + generic VO** (`:173-178`). There is
  **no per-order acknowledgement VO and no roster order-state column** yet — the confirm is a single toast.
- **The report verb** is the fire-mission grammar (`arm_fire_mission`/placement line
  `_update_placement_line:127-146`) — aim-and-press, danger-close read BEFORE the send. This is the verb the
  briefing says the squad-order set overloads.

This matters: the loop is **90% wiring into things that exist**. Route authoring is the one genuinely-new
surface; everything else is a second row, a VO line, and a roster column on shipped elements.

---

## 1. ROUTE AUTHORING on `topo_map.gd`

### Interaction model — click-to-place on the existing overlay
Add a player pencil layer to the SAME `_overlay` that already draws the CO circle. Concretely:

- **Inverse transform** (new, mirrors `_world_to_map:127`): `_map_to_world(mv: Vector2) -> Vector3` =
  `Vector3(mv.x/s.x*map_size, 0, mv.y/s.y*map_size)`, y filled from `terrain_manager.get_height_at`.
- **State:** `var route: PackedVector3Array` on the map (persisted to the op ledger, ADR-010 one-seed).
- **PLACE** — LMB on the sheet: `_overlay.gui_input` (or map-scoped `_unhandled_input` while `visible`)
  → convert cursor → append to `route`. Cap at ~5–6; the 6th either refuses or rolls the oldest.
- **UNDO** — Backspace / RMB: pop the last point. **CLEAR** — Delete: empty `route`.
- **CONFIRM-AND-LEAVE** — `M` closes the map. **There is no "commit" verb and there must not be one.**
  Closing the map does not sign a contract; it just puts the pencil down. The route persists as a mark, and
  the player may reopen and redraw it at any time (ADR-022 §2: annotate forever, no validation).

### Drawing it — it must read as HIS pencil, not the CO's, never a tracker
- Draw the route as a **polyline through the points** + a small **tick/cross at each node**, in the
  **player's green pencil** (reuse the arrow green `Color(0.2,0.8,0.25)` family), deliberately DISTINCT from
  the CO's **red** grease pencil (`:140`). ADR-022's whole law is "saturated colour = the player's hand";
  two saturated pencils on one sheet is exactly the "two layers, instantly distinguishable" problem the ADR
  names as its biggest risk (ADR-022 Consequences). Green-player vs red-CO is the cleanest split we have.
- **Number the nodes 1–5** — but the number is **identity, not progress.** It never turns green, never gets
  a checkmark, never greys out when walked (that is the ADR-029 §4 line, and the CO circle's `:136` comment
  is the exact precedent: "never checks off, never updates"). No "3/5 waypoints" counter anywhere. The
  ordinal exists solely so command's voice can say "your third mark" (see §2).
- **No live objective counter, no on-screen ground-covered bar** (briefing §"ADR-029 §4 boundary";
  ground-covered is debrief-only per blessed call #2).

### Does the map need a distinct "planning mode"? — NO. One map, always drawable.
A separate pre-wire **planning screen** resurrects the deleted briefing loop (the exact tension the HUD
decree parked pending the Summoner, synthesis `:46`, `:89`). ADR-022 already says the player may annotate
**any time** — so the pencil verb is identical inside the wire and out in the bush. Keep ONE map object:
- **Pre-wire at the firebase** the sheet opens "clean" (fresh seed, only roads/contours/water) — an empty
  sheet *invites* the plan without any mode flag.
- **In the field** the same sheet now also carries the OBSERVED layer (contacts, sign) the patrol earned,
  and the same LMB still draws. Opening it in the bush costs you time and situational awareness — that is
  good diegetic tension, not a mode to gate.

The only thing I would gate is the **sim-pause-on-open**: safe to pause at the wire, should NOT pause in the
field (systems call — flag it to the programmer, not a UX mode). The verb stays one verb.

---

## 2. COMMAND TASKING surface — the compass order-line is the right home

**Confirmed: the order-line belongs inside the compass plate.** The compass is where the eye already sits
for bearing, and command's taskings ARE directional ("sweep NE", "check the village at your next mark",
`rebark_patrol:869-874` already speaks bearing+distance). Hanging the tasking voice as a **second row under
the bearing** couples the order to the instrument that answers it. Today the compass is a single Label
(`:315`); the order-line is a second Label in the same `compass_panel` (`:40-47`), e.g.:

```
<<  NE  042  >>
SIX: CHECK THE VILLAGE — NE 300M
```

The tasking arrives triple-channel (briefing): **radio bark (VO) + this order-line + a toast** — the same
`director.toast` path (`:23`, `raise_crisis:899`) plus a persistent order-line that does NOT fade (unlike the
toast). The toast is the *alert*; the order-line is the *standing record* you can re-read.

### Which waypoint does the task reference WITHOUT a floating marker?
This is the load-bearing fairness problem (ADR-029 §4 / ADR-005 witness: no marker appears from nothing).
The answer is the **map is the index, the order-line names the ordinal:**

- The order-line carries **bearing + distance + the player's own node number**:
  `"SIX: EYES ON YOUR 3RD MARK — NE 300M"`.
- The player already drew and numbered that mark (§1). He presses `M`, sees his own pencil node "3", and
  matches it. **No floating diegetic marker is ever spawned** — the coupling lives entirely on the map
  (ADR-022 "the map is your memory") and in the bearing on the compass. This is the whole reason route
  nodes carry stable ordinals.
- **Fallback when the task is a persistent-world feature not on his line** (blessed call #1 — command can
  reference a village near, not on, the route): the order-line names the feature + bearing
  (`"THE VILLAGE — E 200M"`), and the OBSERVED layer stamps it on the map the instant he lays eyes
  (ADR-022 §1, legal because he witnessed it). Still no from-nothing marker.

**The risk here:** if the order-line ever gives a bearing with no node ordinal and no map correlate, the
player gets "go NE" and 5 pencil marks and no way to know which — that is the "where do I go" confusion the
deleted objective pin used to paper over, and fairness law forbids the easy fix. **The order-line MUST always
name either an ordinal ("your 3rd mark") or an observed feature ("the village"), never a bare bearing.**

---

## 3. ORDER CONFIRMATION — the anti-rage fix, three channels, same frame

The briefing's core insight (and half the "AI ignored me" feeling): a forgiving area/direction order must
**prove it registered** the instant it is pressed. Today `_order_all:173-178` fires only a toast. Spec the
three channels to fire together in `_order_all` (and the new area/direction orders):

| Channel | Spec | Where |
|---|---|---|
| **Radio bark** | Per-order acknowledgement VO from the addressed man — "COPY, HOLDING" / "EYES ON" / "MOVING UP". NOT the generic weapons-free clip. New VO keys. | `VOManager.play_squad` in `_order_all`; today only `_set_weapons_free:169` plays VO |
| **Compass order-line** | The SAME order-line row (§2) echoes the player's own order for ~2s in a distinct tint, then reverts to command's standing tasking. Player-issued vs command-issued differ by colour (player = green pencil family, command = amber). | `mission_hud` compass panel `:40-47` |
| **Roster change** | The **squad roster HEADER cell** flips from `"SQUAD // WEAPONS FREE"` (`:243`) to the standing order: `"SQUAD // HOLD"`, `"SQUAD // MOVE UP"`, `"SQUAD // EYES NE"`. This is the **persistent** proof — the toast fades, the header does not. | `_squad_header.text`, `_update_squad_strip:243` |

**Which roster cell changes?** For Level-2 (orders are squad-wide, `_order_all` fans to all members), the
**roster header** is the cell — it already carries squad-wide state (weapons-free). The order posture
replaces/augments that string. If orders ever go per-fireteam later, promote to a per-member order token in
the row (`:254` currently `nick/mos/status` → add an order glyph). For now: header is the anti-rage anchor.
The design point: the AI *always* biases toward a forgiving area/direction order (it's intent it already
had), and these three channels make that bias **visible on the same frame** so it never reads as ignored.

---

## 4. OP-STATE HUD element — "HOLD — N MIKES"

A NEW **transient** element (setpiece-only), authored in the 640 buffer at 8px, sitting alongside the four
persistent elements: **compass 213,0** (top, left-of-centre) · **roster 3,307** (far left, mid-low) ·
**ammo bottom-right** · **reticle centre**.

**Placement: TOP-RIGHT corner** (≈ x 500–560, y 4). Rationale:
- It is the only empty edge. Top-centre-left is compass, left is roster, bottom-right is ammo, centre is
  reticle. Top-right balances the compass on the opposite shoulder and keeps the setpiece clock out of the
  reticle sightline (bottom-centre would crowd the aim point during the tensest moment of the game).
- Two 8px lines max: `HOLD THIS GROUND` / `08 MIKES`. Under 1 mike it **blinks** (an event tell — instant,
  never eased, never density-suppressed per synthesis `:44-45`, `:74`).

**Is a countdown mission-tracking (ADR-029 §4)? — No, if scoped correctly.** It is legal in the same
category the code already ships two precedents for: the **fire-mission placement line** (`:127-146`,
command's own words echoed) and the bleed-out clock the HUD decree homes as a state-gated transient
(synthesis `:26`). "Hold 10 mikes" is **command's diegetic order window spoken back**, not a patrol-progress
meter. **Guard (must hold or it becomes a rail):** it exists ONLY while the hold order is live, it counts a
*command-set duration* not a *player-objective*, and it vanishes the instant the setpiece ends. It must never
become a persistent patrol timer or a ground-covered bar. If it ever survives the setpiece, it has drifted
into the deleted objective HUD — kill it on contact.

---

## 5. RECONCILE with the period-HUD decree

**The loop pulls 4 of the 5 parked Phase-4 items into the core build — confirmed, and this is a real
re-sequencing of the HUD decree, not a footnote:**

| Parked Phase-4 item (synthesis `:76-78`) | Loop role | Verdict |
|---|---|---|
| map-as-object-with-cost | route authoring + memory (§1) | **Core.** It is the plan; the loop cannot exist without it. |
| overloaded report verb | aim-and-press = fire-mission = squad-order verb | **Core.** §3 orders ride the existing placement grammar. |
| keyed radio submenus | command tasking channel (§2) | **Core-adjacent.** Order-line is the *receive* side; the *send* side (report verb) is already the fire menu (`_on_fire_menu_changed:81`). |
| pre-patrol planning screen | route drawing (§1) | **Core — and it RESOLVES the parked ADR-029 question** in the legal direction: your-own-map pencil (synthesis `:46` "your-own-map/kit = legal"), NOT objectives. |

Only **researched identifiers** stays pure Phase-4 polish. **The loop should be told to the Arbiter as a
demand to re-order the HUD phasing:** these four are load-bearing loop surface, not "later epic."

### Four-element cap — NO violation
- The **order-line is a sub-row of the compass element**, not a 5th persistent element. It deepens the
  compass, exactly as the decree deepens the roster with the RTO off-net token (synthesis `:73`).
- The **OP-state is a Phase-3 transient** (category: bleed clock, danger-close), not persistent — off-cap.
- The **map is a full-screen modal**, not a HUD element at all — off-cap. Route pencil lives on the sheet.

So the whole loop adds **zero persistent elements** to the four-element buffer. Clean.

### Density model FULL / SPARSE / NONE
- **SPARSE = compass + order only** (synthesis) — this is *precisely* the tasking channel. **SPARSE carries
  the full command loop.** The loop's minimum surface and the density minimum surface are the same surface.
  That is a strong convergence, not a conflict.
- **NONE** would drop the order-line — but the tasking is **triple-channelled** (VO bark + order-line +
  toast + roster header). Even at NONE the radio bark and the roster header survive, so the command loop
  degrades but never goes silent. The §3 anti-rage design makes the loop **density-robust by construction.**
- **Route authoring does NOT need FULL** — it happens on the modal map, which is always fully drawn
  independent of HUD density. Density gates the in-world HUD, not the map sheet.

### The one real conflict — HARDCORE strips the compass, and the order-line lives in it
`mission_hud.gd:302-305`: under `GameSettings.hardcore` the compass is hidden outright. If the order-line
sits in the compass plate (§2) and hardcore hides the plate, **hardcore silences command's tasking voice** —
and tasking is an event tell (r4bk), which the decree rules is **never suppressed** (synthesis `:44-45`,
`:56` hardcore/density orthogonal). Resolution: **hardcore may strip the navigation compass (bearing +
degrees) but the order-line and the three confirm channels must survive it.** The order-line is not a
nav aid; it is command's voice. Split them: `_compass` (nav, hardcore-hideable) vs the order-line row
(event tell, always on). This is the single concrete code catch the reconciliation surfaces.

---

## What is sacrificed (no free lunch)

- **The player can draw a wrong plan and command can reference a mark near nothing** (briefing tension:
  "a route waypoint with NO living feature nearby"). ADR-022's grease-pencil law *celebrates* the wrong
  map — but a bearing-to-a-node with no feature there will read as a bug to many players, and fairness law
  forbids the floating-marker fix. We eat that.
- **Two saturated pencils on one topo sheet** (green route + red CO circle + green player arrow) is the
  exact "layers turn to mush" risk ADR-022 names. Colour alone may not carry it; it will want line-weight
  and node-glyph differentiation too, and it will still be tight.
- **Per-order acknowledgement VO is new content** — the anti-rage fix is only as good as the bark library;
  a missing or wrong-man clip reintroduces the "ignored me" feeling it exists to kill.
- **No commit gate on the route** means the player can trivially redraw mid-patrol to "cheat" the
  ground-covered grade — acceptable because ground-covered accrues from ACTUAL walked path (blessed call
  #2/#3), not the drawn line, so redrawing buys nothing. But it must stay that way or the sacrifice reverses.
