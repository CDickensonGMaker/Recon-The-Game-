"""build_medical_workbench.py - the medical complex, staffed, for posing.

    blender -b -P tools/build_medical_workbench.py

Assembles assets/shared/medical_anim_workbench.blend: the medical complex geometry with
its own markers, a surgeon standing at work_surgeon_N, and wounded men laid on the cot
slots. Caleb poses in it; nothing here authors motion.

NOTHING IS INVENTED. The complex already carries every anchor this needs:
    prop_wounded_00..15   16 cot slots, z 4.77 - 0.52 above the floor, i.e. cot height
    work_surgeon_N / _S   the two operating positions
    work_scrubnurse_N/_S, work_anesthetist_2/_5, work_triage, work_scrub,
    work_sterilizer_7, work_supply_N/_S, work_ward_round_0..3, work_litter_rack
The cots themselves are welded into the `medical_complex` mesh, so a man goes ON a slot
empty, not on a cot object - there is no cot object to parent to.

The clips already exist in the shared library too (laying_idle, laying_breathless,
sleeping_laying, medic_treat_give/receive, carry_wounded, wounded_crawl), so this stages
what is there rather than adding a fifteenth near-duplicate.

BLENDER 5: assigning `animation_data.action` alone is a NO-OP. The action carries slots
now and one must be bound, or the rig sits in rest and the clip looks missing.
"""
import bpy, os
from mathutils import Vector

BASE = r"C:\Users\caleb\RECONgame\assets\us\characters\us_base_v3.blend"
MED = r"C:\Users\caleb\RECONgame\assets\world\building models\structures\firebase\kit\firebase_v3.1_RECOVERED_medical.blend"
LIB = r"C:\Users\caleb\RECONgame\assets\shared\anim_library.blend"
OUT = r"C:\Users\caleb\RECONgame\assets\shared\medical_anim_workbench.blend"

WOUNDED_CLIP = "laying_idle"
SURGEON_CLIP = "medic_treat_give"
N_WOUNDED = 6                      # enough to read as a ward without 16 rigs to drag

bpy.ops.wm.read_homefile(use_empty=True)
scene = bpy.context.scene


def link(o, coll_name):
    c = bpy.data.collections.get(coll_name)
    if c is None:
        c = bpy.data.collections.new(coll_name)
        scene.collection.children.link(c)
    for old in list(o.users_collection):
        old.objects.unlink(o)
    c.objects.link(o)


# ---------------------------------------------------------------- 1. the building
with bpy.data.libraries.load(MED, link=False) as (df, dt):
    dt.objects = [n for n in df.objects
                  if n == "medical_complex" or n.startswith(("prop_wounded_", "work_", "med_"))]
brought = [o for o in dt.objects if o]
for o in brought:
    scene.collection.objects.link(o)
    link(o, "MEDICAL_COMPLEX")
slots = sorted([o for o in brought if o.name.startswith("prop_wounded_")], key=lambda x: x.name)
marks = {o.name: o for o in brought if o.type == 'EMPTY'}
print("building: %d objects, %d wounded slots, %d markers"
      % (len(brought), len(slots), len(marks)))


# ---------------------------------------------------------------- 2. the cast
def bring_soldier(tag, new_name):
    """Append a rig and every mesh that belongs to it, as one man."""
    suffix = "_" + tag
    with bpy.data.libraries.load(BASE, link=False) as (df, dt):
        dt.objects = [n for n in df.objects if n.endswith(suffix)]
    got = [o for o in dt.objects if o]
    rig = next((o for o in got if o.type == 'ARMATURE'), None)
    if rig is None:
        print("  %s: no rig" % tag)
        return None
    for o in got:
        scene.collection.objects.link(o)
        link(o, new_name)
    rig.name = new_name
    return rig


def place(rig, target, lying=False):
    """Drop a man on a marker. Lying men are rotated flat onto the cot."""
    rig.location = target.matrix_world.translation.copy()
    if lying:
        rig.rotation_euler = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()


def assign(rig, action):
    """Blender 5 needs the action AND a bound slot, or the pose never takes."""
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = action
    slots = getattr(action, "slots", None)
    if slots:
        try:
            rig.animation_data.action_slot = slots[0]
        except Exception as e:
            print("      slot bind failed: %s" % e)
    bpy.context.view_layer.update()


with bpy.data.libraries.load(LIB, link=False) as (df, dt):
    dt.actions = [n for n in df.actions if n in (WOUNDED_CLIP, SURGEON_CLIP)]
acts = {a.name: a for a in dt.actions if a}
print("clips: %s" % sorted(acts))

made = []
for i in range(min(N_WOUNDED, len(slots))):
    rig = bring_soldier("rifleman", "WOUNDED_%02d" % i)
    if rig is None:
        continue
    place(rig, slots[i], lying=True)
    if WOUNDED_CLIP in acts:
        assign(rig, acts[WOUNDED_CLIP])
    made.append((rig.name, slots[i].name))

surg = bring_soldier("surgeon", "SURGEON")
if surg is not None and "work_surgeon_N" in marks:
    place(surg, marks["work_surgeon_N"])
    if SURGEON_CLIP in acts:
        assign(surg, acts[SURGEON_CLIP])
    made.append((surg.name, "work_surgeon_N"))

print("\nstaged:")
for n, m in made:
    o = bpy.data.objects[n]
    p = o.matrix_world.translation
    print("  %-14s on %-18s at (%7.2f, %7.2f, %6.2f)  action=%s"
          % (n, m, p.x, p.y, p.z,
             o.animation_data.action.name if o.animation_data and o.animation_data.action else "-"))

print("\nfree cot slots left for more: %s"
      % [s.name for s in slots[len(made) - 1:]][:12])

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("\nwrote %s" % OUT)
