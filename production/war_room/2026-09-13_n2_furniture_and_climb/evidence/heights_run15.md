# Evidence — blocker heights, run 15 (complete, four samples)

Per stuck man: the collider his 10 cm test_move toward his target hits, the contact point's height over his feet, and the collider's top (its CollisionShape3D debug-mesh AABB) over his feet. The bake's effective agent_max_climb is 0.5 m (0.4 rounded to 0.25 m cells, nav_baker.gd:402); a 0.3 m-radius capsule with its origin at the feet has no step-up.

```
      2 10cm step HITS 'fb_int_cot_p1_228' contact +0.30m top +0.50m
      2 10cm step HITS 'fb_int_cot_m2_103' contact +0.30m top +0.47m
      2 10cm step HITS 'MC_pit_floor_2358' contact +0.33m top +0.35m
      2 10cm step HITS 'MC_pit_floor_2256' contact +0.22m top +0.22m
      1 10cm step HITS 'tent_frame_chowhall_2772' contact +0.30m top +3.18m
      1 10cm step HITS 'fb_terrain_mound_1473' contact +0.00m top +1.53m
      1 10cm step HITS 'fb_int_radiochair_252' contact +0.54m top +0.90m
      1 10cm step HITS 'fb_int_radiochair_252' contact +0.50m top +0.90m
      1 10cm step HITS 'fb_int_locker_p0_475' contact +0.30m top +0.39m
      1 10cm step HITS 'fb_int_locker_m2_104' contact +0.32m top +0.32m
      1 10cm step HITS 'fb_int_locker_m0_467' contact +0.28m top +0.28m
      1 10cm step HITS 'fb_int_cot_p1_476' contact +0.45m top +0.52m
      1 10cm step HITS 'fb_int_cot_m1_468' contact +0.35m top +0.43m
      1 10cm step HITS 'fb_int_cot_m1_468' contact +0.30m top +0.45m
      1 10cm step HITS 'fb_int_cot_m1_220' contact +0.49m top +0.55m
      1 10cm step HITS 'fb_int_cot_m1_101' contact +0.67m top +0.72m
      1 10cm step HITS 'MC_pit_floor_2358' contact +0.35m top +0.39m
      1 10cm step HITS 'MC_pit_floor_2358' contact +0.34m top +0.38m
      1 10cm step HITS 'MC_pit_floor_2358' contact +0.32m top +0.34m
```

Free 10 cm steps among stuck rows (the blocker is not straight ahead): 3

Samples:
- 0 wrong-target, 3 stuck, 5 still walking, 1 overlaps, 0 roofs
- 0 wrong-target, 7 stuck, 8 still walking, 3 overlaps, 0 roofs
- 0 wrong-target, 9 stuck, 6 still walking, 4 overlaps, 0 roofs
- 0 wrong-target, 7 stuck, 4 still walking, 4 overlaps, 0 roofs
- total: 0 wrong-target, 26 stuck, 12 overlaps, 0 roofs, 0 posts off the mesh (content, not counted)

Tops at or under 0.50 m (floor to the bake, wall to the body): 16 rows. Tops over 0.50 m (the mesh should not cross these - check whether their collider is in the bake at all): 7 rows.
