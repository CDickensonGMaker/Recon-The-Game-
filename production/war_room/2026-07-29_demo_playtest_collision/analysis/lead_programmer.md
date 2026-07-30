# LEAD PROGRAMMER — there is no navmesh inside the firebase. None. At all.

## Finding P1: the firebase is excluded from nav baking, twice over

`scripts/missions/mission_generator.gd:814-818`:

```gdscript
var nav_sites: Array[Dictionary] = []
for bs in built_sites:
    if str(bs.get("kind", "")) != "firebase_main":
        nav_sites.append(bs)
nav_baker.queue_sites(nav_sites, _enemy_anchors(p))
```

The main firebase is **explicitly skipped**. And even if that filter were removed, it would
still be dropped: `NavBaker.should_bake` (nav_baker.gd:79) tests the site kind against
`WorldConfig.NAV_SITE_KINDS` (world_config.gd:35), which lists `"firebase"` — while
`place_firebase_main` tags the site `"firebase_main"` (site_planner.gd:940). Two independent
gates, both closed.

## Finding P2: what that does to a man

`NavRouter.step` (scripts/ai/nav_router.gd:44-49):

```gdscript
var use_nav: bool = WorldConfig.NAV_ENABLED and box >= 0 and NavBaker.box_contains(box, to)
if agent == null or not use_nav:
    return direct
```

No baked box → `box == -1` → **direct steering**. Every ally, every promoted garrison
defender and every VC inside the wire walks in a straight line at his destination and grinds
into the first sandbag revetment, bunker wall or berm face between him and it. That is the
Summoner's "stuck in the spawn", and it is not a collision-tightness problem — the colliders
are doing their job. Nothing is telling the men to walk around them.

Note the honesty of the fallback: it is a `push_warning` gated on `direct.length_squared() >
25.0` (nav_router.gd:69) and fires **once per agent**. Twelve stuck men produce twelve lines
and then silence. The log understated this badly.

## Finding P3: fixing the two gates is necessary but not sufficient

Two more things break the moment `firebase_main` is let through:

1. **The box is a quarter the size of the base.** `NavBaker._box_for` clamps the half-extent
   to `HALF_MAX = 70.0` (nav_baker.gd:28). The firebase site radius is
   `FSB_HALF.length()` ≈ 186 m, and the compound is ~300 m across. One 140 m box centred on
   the compound leaves the gate, the spawn point and the whole outer wire off-mesh.
2. **The structures would not be carved.** `NavBaker._add_structures` (nav_baker.gd:222) only
   walks `get_tree().get_nodes_in_group("nav_blockers")` and reads a `nav_box` meta. The
   firebase GLB is added by `place_firebase_main` as one plain `Node3D` root
   (site_planner.gd:918-921) — not in the group, no meta. A bake would produce a flat mesh
   straight through every bunker, and the men would path *into* walls with full confidence.

The right source for this one site is the real colliders:
`NavigationServer3D.parse_source_geometry_data()` with
`geometry_parsed_geometry_type = PARSED_GEOMETRY_STATIC_COLLIDERS` over the firebase root,
merged with the synthesised terrain faces. That parses exactly the `-colonly` trimeshes
`move_and_slide()` hits, so navmesh and physics cannot disagree — the same principle
`_add_structures` already states in its own comment.

**Cost, named.** One 320 m box at the map's 0.25 m cell size is a ~1280² heightfield. The
bake is async (`bake_from_source_geometry_data_async`), so it costs load time, not frame
time — but it must be MEASURED, not assumed, and it must be measured after the one-ground fix
lands, because parsing the collider set is exactly where a duplicate ground plate would
double the work.
