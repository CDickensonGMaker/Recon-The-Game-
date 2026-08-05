"""Lock the chow hall marker names to the `work_<building>_<role>` convention.

Caleb ruled these on 2026-08-03, before any Godot code read them - which is the only
cheap moment to rename, because `site_planner.gd` turns them into an API.

  work_serve*      -> work_chow_diner*     (where the DINER stands at the counter)
  work_server*     -> work_chow_server*    (where the SERVER stands, other side)
  work_server_line -> work_chow_server_line
  food_stop        -> work_chow_trigger    (the server watches this one)
  chow_exit        -> work_chow_exit

`work_serve` vs `work_server` was one letter apart across the counter, and
`mark_chowhall.py:126` already carried a not-startswith("work_server") guard to keep
them apart - the naming had already cost code once.

`work_eat`, `prop_seat`, `work_queue` and `line_step_*` were already clear and are kept.

    blender -b <file>.blend -P tools/rename_chow_markers.py -- --save
"""
import bpy
import sys

# LONGEST PREFIX FIRST. "work_serve" is a prefix of "work_server", so renaming the short
# one first would eat the long one and merge the two sides of the counter.
RULES = [
    ("work_server_line", "work_chow_server_line"),
    ("work_server", "work_chow_server"),
    ("work_serve", "work_chow_diner"),
    ("food_stop", "work_chow_trigger"),
    ("chow_exit", "work_chow_exit"),
]


def main():
    done = []
    for old, new in RULES:
        for o in sorted(bpy.data.objects, key=lambda x: x.name):
            if o.name == old or o.name.startswith(old + "."):
                o.name = new + o.name[len(old):]
                done.append((old, o.name))
    for old, new in RULES:
        print("  %-18s -> %-24s %d" % (old, new, len([1 for a, _b in done if a == old])))
    left = [o.name for o in bpy.data.objects
            if o.name.startswith(("work_serve", "work_server", "food_stop", "chow_exit"))
            and not o.name.startswith("work_chow")]
    print("  unrenamed leftovers:", left or "none")
    if "--save" in sys.argv:
        bpy.ops.wm.save_mainfile(compress=True)
        print("  SAVED", bpy.data.filepath)
    else:
        print("  dry run (pass --save to write)")


main()
