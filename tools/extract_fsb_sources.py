"""Pull the blessed source parts out of RealVietnamRTS into our firebase kit.

    blender -b -P tools/extract_fsb_sources.py

READ-ONLY on RealVietnamRTS. CLAUDE.md: "RTS assets get copied in from
C:\\Users\\caleb\\RealVietnamRTS as needed - never edit that project from here."

Two things come across, both by the owner's ruling (2026-07-26):

  fb_gate_assembly.glb  the gate he pointed at - gate_left/right, the two posts and the
                        watchtower. STRIPPED of the mg_nest_* cluster, whose materials are
                        `FRAHotchkissMle1914.mat` and `FRAInfantry` (a Spring 1944 FRENCH
                        faction atlas), and of the seven `barbed_wire` meshes at 878 tris
                        each - wire is barbwire_card, always.

  fb_sandbag_*.glb      his modular sandbag revetment. THIS is the wall material for the
                        whole firebase now: "use the sandbags ive got in the project. they
                        arent weighing down the game and fit into the asthetics." The copy
                        inside the RTS gate is 176 tris on a 64x64 `Sandbags` map - far
                        leaner than the 588-tri variant in firebase_chunks.blend, so it is
                        the one to standardise on.

Nothing here is generated. If a part looks wrong, fix it at the source and re-extract.
"""
import bpy, os, re

RTS_GATE = r"C:\Users\caleb\RealVietnamRTS\assets\models\structures\firebase\gate_entrance_lowpoly.glb"
KIT_DIR = r"C:\Users\caleb\RECONgame\assets\world\building models\structures\firebase\kit"

## Dropped on sight. FRA* is the Spring 1944 faction atlas naming; barbed_wire is solid
## geometry we replace with the canonical alpha card.
BANNED_MAT = ("FRAHotchkiss", "FRAInfantry", "BarbedWireMetal", "m2hb", "hessian")
BANNED_NAME = ("mg_nest", "barbed_wire")

GATE_KEEP = ("gate_left", "gate_right", "gate_post_left", "gate_post_right", "watchtower_1")


def base_name(o):
    return re.sub(r"\.\d+$", "", o.name.replace("-col", ""))


def is_banned(o):
    if any(b in base_name(o) for b in BANNED_NAME):
        return True
    for m in o.data.materials:
        if m and any(b in m.name for b in BANNED_MAT):
            return True
    return False


def export(objs, path):
    for o in bpy.data.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_animations=False,
                              export_materials='EXPORT', export_extras=True,
                              export_draco_mesh_compression_enable=False)


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def main():
    os.makedirs(KIT_DIR, exist_ok=True)
    bpy.ops.wm.read_homefile(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=RTS_GATE)
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']

    kept, dropped, bags = [], [], {}
    for o in meshes:
        b = base_name(o)
        if is_banned(o):
            dropped.append((o.name, tris(o)))
            continue
        if b.startswith("sandbag_"):
            if b not in bags:
                bags[b] = o
            continue
        if b in GATE_KEEP:
            kept.append(o)
        else:
            dropped.append((o.name, tris(o)))

    print("---EXTRACT---")
    print("KEPT for the gate assembly:")
    for o in kept:
        print(f"   {o.name:24s} {tris(o):5d} tris  mats={[m.name for m in o.data.materials if m]}")
    print("SANDBAG MODULES:")
    for b, o in sorted(bags.items()):
        print(f"   {b:24s} {tris(o):5d} tris  dim={[round(v,2) for v in o.dimensions]}")
    print(f"DROPPED ({sum(t for _, t in dropped)} tris):")
    for n, t in dropped:
        print(f"   {n:24s} {t:5d}")

    # the gate assembly, recentred on the gate opening (between the two posts)
    if kept:
        cx = sum(o.matrix_world.translation.x for o in kept) / len(kept)
        gate_objs = [o for o in kept if base_name(o).startswith("gate_")]
        if gate_objs:
            cx = sum(o.matrix_world.translation.x for o in gate_objs) / len(gate_objs)
        for o in kept:
            o.location.x -= cx
        export(kept, os.path.join(KIT_DIR, "fb_gate_assembly.glb"))
        print("wrote fb_gate_assembly.glb  tris:", sum(tris(o) for o in kept))

    # each sandbag module on its own origin, so the generator can place it anywhere
    for b, o in sorted(bags.items()):
        o.location = (0, 0, 0)
        o.rotation_euler = (0, 0, 0)
        export([o], os.path.join(KIT_DIR, f"fb_{b}.glb"))
        print(f"wrote fb_{b}.glb  {tris(o)} tris")

    # The short and tall bag variants only exist in the authored chunk file. Three heights
    # is what makes a revetment read as built rather than extruded: light for a knee wall,
    # heavy for a chest wall, foxhole for a tall thin parapet.
    CHUNKS = r"C:\Users\caleb\RECONgame\production\props_workshop\firebase_chunks.blend"
    if os.path.exists(CHUNKS):
        bpy.ops.wm.open_mainfile(filepath=CHUNKS)
        pal = bpy.data.collections.get("PALETTE")
        pool = list(pal.all_objects) if pal else list(bpy.data.objects)
        for want in ("sandbag_light", "FoxholeSandbags"):
            src = next((o for o in pool if o.type == 'MESH' and base_name(o) == want), None)
            if src is None:
                print("   MISSING from chunk file:", want)
                continue
            cp = src.copy()
            cp.data = src.data.copy()
            bpy.context.collection.objects.link(cp)
            # KEEP THE SOURCE SCALE. Zeroing it to (1,1,1) strips the compensating 0.01
            # these RTS meshes carry and the bag comes out 214 m long - the same 100x bug
            # CLAUDE.md warns about for the RTS .tscn collisions. Only place and orient.
            cp.scale = src.matrix_world.to_scale()
            cp.location = (0, 0, 0)
            cp.rotation_euler = (0, 0, 0)
            cp.name = "fb_" + want
            dim = [round(v, 2) for v in cp.dimensions]
            if max(dim) > 6.0:
                raise RuntimeError(
                    f"{want} exports at {dim} - a sandbag is not 6 m. Scale bug, aborting.")
            export([cp], os.path.join(KIT_DIR, f"fb_{want}.glb"))
            print(f"wrote fb_{want}.glb  {tris(cp)} tris  dim={dim}")


main()
