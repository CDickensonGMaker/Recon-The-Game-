# GAME-DESIGNER — OPEN PATROL LOOP + PACING (2026-07-17)

Lens verdict for the pivot decree. All cites verified in code. Full detail retained here for the record.

## Loop skeleton (states, owned by a new small PatrolDirector attached in enter_hub)
The decree's world already exists in the HUB path: build_hub is "No objectives, no enemies"
(mission_generator.gd:896-897) and enter_hub (game_flow.gd:392-445) loads the full deterministic
world + squad + weather + director. **The patrol sim = the hub world made live.**

1. AT-BASE — inside wire radius of hub.center; rearm/chow/armorer (all shipped).
2. WIRE-CROSSED — player >~120m from firebase center; gate fires ONCE per excursion; rolls a
   patrol location seeded hash(op_seed, patrol_count) (ADR-010); grease-pencil circle on the topo
   sheet; point-man bark. No HUD element. (Polling template: hub_controller.gd:38-63.)
3. MOVEMENT-TO-CONTACT — ambient ecology re-keyed to the wire→location corridor: the existing
   corridor spawner (mission_generator.gd:557-609) already does exactly this between insertion_lz
   and objective — swap its two anchors, keep everything.
4. DISCOVERY — within ~150m of the location: a real stamped site. No completion event, no toast.
   OBSERVED map marks auto-stamp what he personally sees (ADR-022 layer 1).
5. DRIFT — one location per excursion; free wander; nothing tracks him.
6. RETURN — re-crossing the wire inward banks the AAR + re-arms the gate; next location biased to
   an unvisited sector.

## Pacing numbers (code-grounded)
Walk 5.0 / sprint 8.0 m/s (player.gd:5-7); effective patrol pace ~3.0-3.5 m/s. Map 1280m
(world_config.gd:9), site margin 100m → usable radius 540m (764 corners).
- Wire radius: **120m** (firebase stamp 44m + apron).
- First-sign band (craters/cold cookfire/trail): **150-300m** — something inside 60-90s.
- Village band: **280-450m** → first village 2-3.5 min (the owner's "fairly close" number).
- Patrol-location band: **350-550m**. Camp band: **400-540m** (deeper half, never doorstep).
- Time-to-first-contact 3-5 min falls out (LazyGroup activation 120-140m on the corridor).
- Discoverable density: one per 150-250m of corridor; existing corridor build already provides
  ~1-2 ambient villages + 2-3 walking patrols + 2-4 craters + 0-1 temple.

## LocationPlanner verdict: CROWN THE DOCTRINE, KILL THE FILE
location_planner.gd IS the decree's topology (firebase + village ring + camp ring, :50-104) but is
test-only (test_world_alive.gd:64,75), its 600-800m camp ring is mostly OFF-MAP at 1280
(center-to-edge 640), and it is a second settlement doctrine (ADR-028 ban). Port the ring-band idea
into SitePlanner.find_site as a radial band constraint with the rescaled bands above; delete
location_planner.gd per ADR-023. 4-6 villages + 2-3 camps saturates a 1.28km AO (not its 8-10).

## Pointer that is not a rail (three diegetic channels, zero HUD)
1. Topo sheet (topo_map.gd, M, shipped): penciled circle + "SWEEP NW" in ADR-022 grease-pencil
   language. An order on paper — never checks off, never updates, replaced not completed.
2. Compass (mission_hud.gd:255-259, shipped): the player converts circle→bearing himself. That
   conversion IS the gameplay.
3. Point-man bark, repeatable: "Six wants us sweeping northwest, half a klick."
KILL ON SIGHT: the floating objective-marker system (mission_hud.gd:264-314, "TITLE 320m" live
distance labels) — that IS a quest tracker. HARDCORE already strips it (:246-249), proving the game
plays without it.

## Top 3 risks to RULE #1
1. **Corridor loses its anchor** — all ambient life is keyed insertion_lz→objective; the hub build
   spawns NONE of it. Re-key in the same change or the first patrol is 400m of empty jungle.
2. **Invisible pointer = aimless wander** — circle bold on map-open, bark repeatable, one toast
   concession at the gate ("SWEEP NORTHWEST - HALF A KLICK OUT").
3. **Three patrols memorize the AO** — one fixed seed + bands at 280-550m = ring walked in ~3
   excursions. Sector-biasing + ADR-021 rotation + CampDirector schedules (same village at 06:00 vs
   22:00) are the replayability of the entire mode, not polish.

## Squad-on-patrol gap
Allies FOLLOW as a 2.5-4.5m orbit huddle (ally_base.gd:190,535-542) — bodyguards, not a patrol.
The enemy side already has the answer: staggered file column + wedge
(enemy_base.gd:103-105,1851-1863; enemy_squad.gd:454-473). One change: on sustained bearing outside
the wire, allies string into file along the movement vector, POINTMAN slot 10-15m AHEAD. No new
orders, no new UI.
