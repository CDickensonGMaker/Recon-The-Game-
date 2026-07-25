# Devil's Advocate — The Period HUD (640×480 buffer doctrine)

**Convened:** 2026-07-24 · **Role:** Devil's Advocate · **Charge:** find where this
handoff BREAKS. No free lunches. Every claim below cites `file:line`.

---

## 0. TL;DR — the two the Arbiter must not gloss

1. **The "one rule" is geometrically incompatible with the shipped resolution, and
   the only fix hits the top systemic risk.** 640×480 @2× = 1280×**960**. The game
   ships at **1280×720** (`project.godot:55-56`, `window/size/mode=3` fullscreen).
   960 > 720 by 240px — a 2× 4:3 buffer *cannot fit vertically*. The doctrine's own
   headline example ("2× @1280×960") assumes a display the game does not run at.
2. **The four "persistent elements" are split across two live CanvasLayers and lean
   on a class shared with the menus — a textbook Fossil-Law trap.** Ammo + reticle
   live in `hud.gd`; compass + roster live in `mission_hud.gd`; both are built from
   `ReconUI`, which the handoff bans in-game but *keeps for menus*. A naive "add the
   buffer" births a THIRD way to draw ammo and leaves half-wired signal handlers the
   fossil probe cannot see.

---

## 1. FOSSIL LAW — what gets deleted vs kept, and the third-HUD birth

### The four elements are NOT in one place
- **Ammo** → `hud.gd` (`.tscn` `BottomRow`): `ammo_label` / `mag_label` /
  `grenade_label` / `medkit_label` (`hud.gd:9-13`), driven by
  `_on_magazine_changed` (`:144-146`), `_on_grenade_count_changed` (`:173-174`),
  `_on_health_pack_changed` (`:140-141`).
- **Reticle** → `hud.gd` `$Crosshair` (`:15`, coloured green `:54-56`).
- **Compass** → `mission_hud.gd` `_compass` (`:45-47`, driven `:306-315`).
- **Roster** → `mission_hud.gd` `_squad_panel` (`:229-262`).

So the "buffer HUD" straddles TWO CanvasLayers that are instantiated **separately**:
`HUD` from `hud.tscn` (`game_world.gd:8,452`) and `MissionHUD.new()`
(`game_flow.gd:319-322`). Both extend `CanvasLayer`; both draw at display res.

### The third-HUD risk is concrete
If someone builds the 640 buffer as a new `SubViewport`/CanvasLayer and wires ammo
into it, there are now **three ammo drawers**: (a) `hud.tscn`'s `BottomRow` labels,
(b) `mission_hud`'s slot slider which *also* prints round-adjacent kit
(`mission_hud.gd:164-176` — "1 RIFLE / 3 FRAG x / 4 MEDKIT x"), and (c) the new
buffer. Exactly the "multiple things a coding agent reads as the same thing" the
Fossil Law (ADR-023:15) exists to kill.

### You cannot half-delete `hud.gd`
`hud.gd` owns far more than ammo: death screen (`:295-311`), hitmarker (`:262-292`),
heal prompt (`:90-97`), field prompt (`:99-107`), bleed clock (`:242-255`),
`action_progress` reload/heal/switch ring (`:18`, wired `:185-239`), slot indicator
(`:17,164-170`), and the **entire signal graph** (`setup()` `:74-119` connects ~20
signals). If the buffer takes ammo+reticle but `hud.gd` keeps the signal wiring, one
of two failure modes lands:
- **Delete the Labels, keep the handlers** → `_on_magazine_changed` writes to
  `ammo_label` (a freed/removed node) → null-deref crash, or
- **Keep the Labels, hide them** → dead nodes still updated every shot = fossils the
  probe won't flag (they're still referenced by live handlers). Fossil-by-camouflage.

The honest move is a full re-home: the buffer owns the four elements AND their signal
subscriptions, and `hud.gd`'s ammo/mag/gren/med labels + `$Crosshair` are **deleted**,
not hidden. That is a signal-graph surgery, not a cosmetic pass — and it ripples to
**four scenes** that each instantiate `hud.tscn` independently: `game_world.gd:452`,
`ai_stress_arena.gd:1240` (the Pillar-1 AI benchmark), `gore_lab.gd:268`,
`gun_range.gd:109`. Break the arena HUD, you blind the AI test rig.

### ReconUI: live for menus, fossil in-game — the probe is BLIND here
`ReconUI` (`recon_ui.gd`) is the handoff's named villain: "one disciplined accent,
uniform panels, hairline borders, tracked labels" = the modern tell. But it is used
by BOTH huds AND menus (`make_menu_button` `:99`, `make_card_button` `:125`,
`make_screen_root` `:50` are menu-only). **You cannot delete the class.** Every
in-game caller must stop using it — `mission_hud.gd` calls `ReconUI.make_label`/
`make_panel`/`make_header` at least a dozen times (`:40,45,83,95,112-118,178,197,
230-259,284,339`). After the pass, `ReconUI` is *dead for HUD, live for menus*.
`grep ReconUI` still lights up everywhere, so `test_fossils.tscn` sees a healthy
live class and reports nothing. **The Fossil Law's machine cannot detect a
half-dead class.** This is the exact "lie in the map" ADR-023 warns of — and the
probe won't save us. It has to be caught by eye, in review, or it festers.

---

## 2. "NO eased transitions anywhere" — the rule is a strawman AND over-broad

The code is full of `create_tween()`:
- Hitmarker fade+scale (`hud.gd:282-285`)
- Toast dwell+fade (`mission_hud.gd:287-290`)
- Slot slider fade (`mission_hud.gd:190-192`)
- Damage-direction pip fade (`mission_hud.gd:203-206`)
- Distant-marker lifecycle, healing bar.

Two problems the Arbiter must resolve, not wave past:

**(a) The ban attacks the wrong thing.** The handoff says "cubic-bezier ease = instant
anachronism" (`README.md:145-147`). But Godot's `create_tween()` defaults to
`TRANS_LINEAR` — none of these are cubic-bezier. They are **linear alpha fades**. A
linear cross-dissolve reads just as modern as an eased one; the anachronism is the
**fade itself**, not the easing curve. If the decree only bans "eases," a coder
keeps every linear fade and technically complies while the HUD still cross-dissolves
like a 2015 shooter. **Pin the real rule: no fades/dissolves on HUD elements, eased
or linear. Elements pop on and off on a frame** (which the handoff *does* say for the
persistent four at `README.md:150-154` — but not for the transients).

**(b) Scope: does the ban reach the transients?** The four persistent elements have no
tweens today, so "swap on a frame" is free for them. The tweens are all on
**transient** furniture (hitmarker, toast, pip, slot slider). If the ban is literal
("anywhere"), you rip them all out: the hitmarker `X` **pops off instantly** instead
of its 0.28s fade — a harsh, cheap-feeling flash; the toast loses its graceful 1.0s
dissolve after 3.5s dwell and **blinks out mid-read**. That is real feel sacrificed.
If the transients are exempt, then the rule is honestly *"no fades on the four
persistent elements,"* and the handoff should say so. **Name the sacrifice either
way — do not let "anywhere" ship undefined.**

---

## 3. Two downscales stacking — mismatched pixel grids on one screen

The 3D world already renders sub-native: `scaling_3d/scale=0.75`, `mode=5` NEAREST
(`project.godot:302-303`). At a 1280×720 target the 3D internal buffer is 960×540,
nearest-upscaled by 1.333× to fill. A world "pixel" is therefore **~1.333 display px**.

The HUD buffer at 2× makes a HUD "pixel" **2.0 display px**. So the chunky HUD text
sits over a world whose pixels are a *different, non-matching size* — two resolutions
of pixelation on one frame. Worse, 1.333× is **non-integer**: the 3D nearest upscale
already shimmers/uneven-steps, while the HUD is clean integer. Side by side, the
mismatch is visible and arguably reads *more* synthetic than today's uniform display-
res HUD. The handoff never puts the 3D world in the 640 buffer (it can't — perf), so
this disagreement is structural and permanent. **This is a look problem the "one
rule" does not solve; it may create it.**

---

## 4. 16:9 math — the load-bearing rule does not fit the shipped window

Shipped: `viewport_width=1280`, `viewport_height=720` (`project.godot:55-56`),
fullscreen (`mode=3`).

- **640×480 @1×** = 640×480 → fits, but a postage stamp in a 1280×720 field
  (wastes ~65% of screen area). The "2×/3× nearest blit" doctrine **never engages**.
- **640×480 @2×** = 1280×**960** → 960 > 720. Overflows vertically by 240px. Clipped.
- **854×480 @1×** = 854×480 → fits with margins, still small.
- **854×480 @2×** = 1708×960 → both dims exceed 1280×720. Does not fit.

**At 1280×720 the only integer scale that fits vertically is 1×.** The entire
"integer-upscale nearest blit at 2×/3×" doctrine — the thing the handoff calls "the
single constraint that produces the period look" — **cannot run at the shipped
resolution above 1×.** 1× is sharp but small and defeats the chunky-pixel intent.

The fixes both bite:
- **Raise the window to 1280×960 or 1920×1440.** Breaks 16:9 (letterbox on modern
  displays), and — critically — **increases 3D fill.** ADR-026's entire perf bench
  is at `1280×720, scaling_3d/scale=0.75` (`ADR-026:33-34,139-140`), where night
  jungle 18v18 already runs **~19 fps, GPU-bound at ~50ms** (`ADR-026:11-12`). More
  vertical pixels = more foliage fill = fewer fps on the exact Intel-UHD floor that
  is the **top systemic risk** (charter §9). You cannot grow the framebuffer to make
  the HUD fit without paying the perf bill ADR-026 spends the whole doc clawing back.
- **Accept 1× at 720p.** Then the "period buffer" is just a small sharp HUD and the
  2×/3× doctrine is dead letter — you shipped the *idea* of the rule, not the rule.

This is unresolved in the handoff and it is not a detail — it is the founding
constraint colliding with the shipped `project.godot` and with ADR-026. **The Arbiter
must force a decision: target resolution, or the doctrine bends.**

Add the **SubViewport + scanline** cost: a 640/854×480 offscreen render every frame
plus a **full-screen scanline fragment pass at display res** (`README.md:49-51`) is
non-zero GPU work on a GPU-bound frame. Scanlines at display res are exactly the kind
of full-screen fill ADR-026 Part A's light budget fights (`ADR-026:26-33`). The
handoff treats the HUD as free. On the Intel-UHD bench it is not.

---

## 5. Scope — an epic smuggled in as "still open"

The "5 still-open items" (`README.md:258-275`) are not HUD polish; they are a second
game's worth of systems:
- **(2) Keyed radio submenus** — a whole input tree; `radio_menu.gd` already exists
  and would have to be reconciled or deleted (Fossil Law again).
- **(3) One overloaded report verb** (aim+press = call contact over net + mark map) —
  new input binding under **ADR-012 input doctrine**, touching the net + `topo_map`.
- **(4) Map as an object with a cost** — reworks `topo_map.gd` under **ADR-022**.
- **(5) Pre-patrol planning screen** — **this collides with ADR-029**, the open
  patrol sim with **NO briefing/objective UI** (`CLAUDE.md`, briefing:64). A
  "pre-patrol planning screen at the scale of a single patrol" is a briefing screen
  by another name. It must be checked against ADR-029 before it is even called "open,"
  not nodded through as future work.
- **(1) Researched identifiers** — real III Corps map sheets / PRC-25 freqs /
  battalion designators — a research task, not UI.

**MVP** = the four persistent elements + the FULL/SPARSE/NONE density toggle + the
motion doctrine. **The trap** = letting the 5 open items ride in under the same
decree so they inherit its blessing. Wall them off explicitly as a *separate, later*
epic, and flag item 5 as ADR-029-suspect **now**.

---

## 6. Landmines

### 6a. The banned sub-lines ARE current r4bk affordances — deleting them may violate r4bk
The handoff bans per-man sub-lines (`README.md:110-112`): the `scanning 51m` and
`ON THE NET - [T]` rows. But those rows are **r4bk affordances today**, and the code
says so in its own comment: *"the player must see he is off the net BEFORE he presses
T"* (`mission_hud.gd:265-273`, `radio_state()`). The off-the-net warning is the only
signal that a fire mission will be refused. The handoff says status detail goes "in
the footer strip or nowhere" (`README.md:112`). **"Nowhere" violates r4bk law** (a
feature without a visible affordance does not exist). The footer only holds one line
("SCAN 51M", `README.md:108`). Where do BOTH "OFF THE NET - RADIO 14m" AND the point-
man scan range live in a single 8px footer? Unresolved — and it is a law conflict, not
a taste call.

### 6b. Danger-close at 8px — the one line you must not misread is starved by the two-size rule
Today danger-close is a full red line, "DANGER CLOSE - MEN IN THE FOOTPRINT"
(`mission_hud.gd:140-142`), coloured `#F23…` red, in the fire-placement readout. The
handoff caps in-game type at **8px for everything, 32px for the round count only**
(`README.md:207-214`). That forces the single most safety-critical readout —
friendly-fire warning before a napalm run — down to **8px**, the same size as a roster
role column. No size emphasis, no italic, no bold allowed. An 8px danger-close warning
over a busy jungle is a legibility risk on the one thing whose misread kills your own
squad. The two-size tyranny starves it. At minimum danger-close needs **blink**
(2-on/2-off is allowed) and probably the 32px tier — but 32px is reserved for ammo.
Conflict.

### 6c. HARDCORE vs the density setting — two independent axes controlling the same furniture
`HARDCORE` already hides the compass AND the distant-squad markers
(`mission_hud.gd:301-305`: `_compass.visible=false`, `_marker_box.visible=false`).
The new density setting's **SPARSE = compass + order line only** (`README.md:162-164`).
So the two axes **directly contradict** on the compass: HARDCORE hides it, SPARSE
shows only it. What wins when both are set? And HARDCORE hiding `_marker_box` strips a
**Pillar 4** squad affordance (never lose your team). You now have TWO systems deciding
the same nodes' visibility — the exact "two things a coder reads as one" Fossil smell.
**These must be merged into ONE visibility model**, not layered.

### 6d. Death screen + action_progress — un-budgeted "fifth" persistent chrome
The "four persistent elements MAX" ignores furniture that is persistent-adjacent and
lives in `hud.gd`:
- **Death screen** (`hud.gd:295-311`) — full-screen, display-res, modern. After a
  period 640 HUD, a display-res death screen is a jarring chrome mismatch. Is it
  re-authored into the buffer? Unspecified.
- **`action_progress`** reload/heal/switch ring (`hud.gd:18,185-239`) — this is
  combat furniture the player sees constantly. Deleted? Kept at display res
  (inconsistent pixels)? Moved to the buffer? The "four max" rule has no room for it,
  yet cutting the reload ring is a real gameplay-readability loss.
- **Bleed clock** (`hud.gd:242-255`) and **hitmarker** (`:262-292`) — same question.

The handoff's "four persistent elements" is honest only if these are explicitly
classed as **transient** (bleed/hitmarker/action_progress are event-driven) — but
`action_progress` during a long reload is on-screen for a full second every reload,
which is not "transient" in feel. Pin their class.

### 6e. Two reticles risk
`hud.gd` colours `$Crosshair` green at runtime (`:54-56`). The buffer reticle is a
fixed 5×5 at 318,238 in `#96B45A` (`README.md:135-138`). If the buffer reticle ships
and `$Crosshair` is not deleted, there are **two reticles** (one display-res, one
buffer) — parallel systems, Fossil Law. And note the buffer reticle at **318,238 is
NOT the computed centre** (640/2=320, 480/2=240) — the handoff says "leave it there"
(`README.md:73`). That deliberate off-centre reticle will **not align with the 3D
world's actual centre** where bullets go (bullets fire from camera centre). A reticle
2px left / 2px up of true centre in a 1-2-shot-kill lethal shooter (Pillar 1) is an
aim-vs-crosshair mismatch. "Authenticity" here fights **believable gunplay**. Verify
the buffer's 318,238 maps to true screen centre after the integer blit, or the reticle
lies about where you shoot.

### 6f. The bitmap font does not exist — unbudgeted asset+tooling work
Briefing confirms grep: **no bitmap font, no SubViewport, no scanline shader anywhere
in the repo.** The handoff wants a hand-drawn 8px atlas + a hand-tuned advance table,
rendered 1:1 (`README.md:216-218`), with Silkscreen only as a stand-in. That is an
art + tooling pipeline task (glyph sheet, importer, kerning table), not "recreate in
the UI layer." It is a dependency the whole look hangs on and it is invisible in the
"four small components" framing. `ReconUI` currently uses `SystemFont` Consolas
(`recon_ui.gd:21-24`) — a period bitmap face is net-new content.

### 6g. Photo-mode / group membership
`player.gd:1037` iterates `["mission_hud","combat_hud"]` to hide HUD in photo mode;
`hud.gd:53` joins `combat_hud`, `mission_hud.gd:25` joins `mission_hud`. A new buffer
CanvasLayer must join one of these groups or **photo mode (R96) won't hide it** —
another wiring detail the "just add a buffer" framing drops.

---

## 7. What is sacrificed (no free lunch)

- **Perf headroom** on the GPU-bound Intel-UHD floor (SubViewport + display-res
  scanline pass) — spent against ADR-026's top systemic risk.
- **Transient feel** — if the motion ban is literal, hitmarker/toast/pip fades die
  and read cheaper.
- **One-model simplicity** — HARDCORE and density now both govern the same nodes.
- **A full signal-graph refactor of `hud.gd` across four scenes**, with the arena
  (Pillar-1 benchmark) in the blast radius.
- **A net-new bitmap-font art pipeline** the "four components" framing hides.
- **Reticle/aim truth** — the deliberate off-centre 318,238 reticle vs. true bullet
  centre in a lethal shooter.

## 8. Verdict on the Arbiter's read
The survey is accurate but **soft on two things**: it lists the resolution doctrine
without noticing 2××480 does not fit 720p, and it treats "delete the old HUD" as
tractable when ReconUI is menu-shared (undeletable) and the four elements are split
across two live layers with a shared signal graph. Both are structural, not cosmetic.
Do not let "it's only four small components" set the effort estimate.
