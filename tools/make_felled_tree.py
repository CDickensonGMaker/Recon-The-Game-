"""THE THREE TREE PIECES THE GAME NEEDS TO FELL ONE.

    blender -b -P tools/make_felled_tree.py

The jungle's trees are BAKED INTO the patch meshes - a tree is not an object, it is a few
hundred triangles welded into a 12m tile that gets instanced forty times across a chunk.
That is fine for standing there, and useless for falling over. So the game does this:

    standing   the patch MultiMesh              free - it is already there
    falling    ONE transient node, ~2 seconds   felled_tree.glb      <- this file
    fallen     an instance in a shared MultiMesh + a capsule collider
               felled_trunk.glb + tree_stump.glb                     <- this file

The expensive animated object only exists for the couple of seconds it is actually in the
air. What it LEAVES is cheap and permanent - and what it leaves is COVER. Drop a tree
across open ground and there is now a log to crawl behind that was not there before. That
is the whole reason to build any of this.

THREE THINGS THE GAME DEPENDS ON, so do not "tidy" them away:

  * ORIGIN AT THE BASE. felled_tree pivots about (0,0,0). The fall is a scripted hinge
    rotation about the trunk's foot - not a RigidBody, because a real tree on a rigidbody
    is unpredictable and will eventually launch one into the sky. Move the origin and the
    tree hinges about its own navel.

  * SAME PALETTE ATLAS, SAME SWAY MASKS. These pieces sit in the same jungle as the patch
    meshes and must render through the same material and the same shader, or a felled tree
    will be a different green from the forest it fell out of.

  * COLOR.b = 0. These are not destructible-tree slots - they ARE the destroyed tree.
    Tag them and the game would try to fell the thing that already fell.
"""
import bpy, sys, os, math, random

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import make_jungle_flora as F

OUT_DIR = r"C:\Users\caleb\RECONgame\assets\world\vegetation"
SEED = 771104
# Read them from the ONE place that defines a tree. Hardcoding these here is how the
# felled tree ends up a different size and thickness from the tree it replaced.
TRUNK_R = F.TRUNK_RADIUS        # 0.32 - the collider radius AND half the log's height
HEIGHT = F.TREE_REF_HEIGHT      # 10.0 - the game scales by (actual height / this)


def export(ob, path):
    """Use the SAME settings make_jungle_patches.export() uses. Do not improvise.

    `export_vertex_color='MATERIAL'` only writes COLOR_0 if the MATERIAL NODE TREE reads
    it - and the palette material does not, because the sway masks are read by Godot's
    shader, never by Blender's. So 'MATERIAL' silently drops COLOR_0 and the felled tree
    ships with no sway data at all, which is the exact class of silent bug that let
    patch_paddy_far's sway sit dead for months. 'ACTIVE' +
    export_active_vertex_color_when_no_material is what the working exporter does."""
    for o in bpy.data.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    kwargs = dict(filepath=path, export_format='GLB', use_selection=True,
                  export_apply=True, export_animations=False, export_skins=False,
                  export_morph=False, export_cameras=False, export_lights=False,
                  export_yup=True, export_extras=False, export_tangents=False,
                  export_vertex_color='ACTIVE', export_all_vertex_colors=False,
                  export_active_vertex_color_when_no_material=True)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    bpy.ops.export_scene.gltf(**{k: v for k, v in kwargs.items() if k in props})
    print("   -> %s  (%d tris)" % (os.path.basename(path),
                                   sum(len(p.vertices) - 2 for p in ob.data.polygons)))


def felled_tree(rng):
    """The STANDING tree, standalone, pivoting about its foot. This is the thing that
    plays the fall. It is the same broadleaf the patches plant, just not welded into one."""
    p = F.broadleaf_tree(rng, height=HEIGHT)
    return p


def felled_trunk(rng):
    """The SETTLED state: the bole on its side with its canopy crushed under it.

    This is the piece that stays forever, so it has to be cheap - it lives in a shared
    MultiMesh and there may be a hundred of them by the end of a bad afternoon.

    It is also COVER, so its height matters more than its looks: a bole lying on its side
    is about 40cm of hard cover. That is prone height. You do not crouch behind a fallen
    tree, you get DOWN behind it, and the geometry should make that read instantly."""
    p = F.Plant("felled_trunk")
    L = HEIGHT * F.BOLE_FRACTION             # the bole, same as the standing tree's

    # the trunk, lying along +X, resting on the ground
    v, f, s = F.trunk(L, TRUNK_R, TRUNK_R * 0.5, sides=6, bend=0.03)
    # trunk() builds up +Z; tip it over onto its side and lift it onto its own radius
    v = F.place(v, tilt=math.radians(90.0), origin=(0.0, 0.0, TRUNK_R))
    p.add(v, f, "bark_grey", [0.0] * len(v))

    # the splintered stump end - a tree does not snap clean, it tears
    for i in range(5):
        a = math.tau * i / 5
        sp = [(0.0, TRUNK_R * 0.8 * math.cos(a), TRUNK_R + TRUNK_R * 0.8 * math.sin(a)),
              (0.0, TRUNK_R * 0.3 * math.cos(a), TRUNK_R + TRUNK_R * 0.3 * math.sin(a)),
              (-rng.uniform(0.25, 0.55), 0.0, TRUNK_R + rng.uniform(-0.1, 0.1))]
        p.add(sp, [[0, 1, 2]], "rot_wood", [0.0, 0.0, 0.0])

    # the canopy, crushed flat under the far end. Leaves splayed on the deck, not a ball.
    for _ in range(22):
        d = rng.uniform(L * 0.55, L * 1.05)
        off = rng.uniform(-1.5, 1.5)
        ll = rng.uniform(0.35, 0.7)
        lv, lf, ls = F.paddle(ll, ll * 0.5, segs=1, curve=0.2)
        lv = F.place(lv, yaw=rng.uniform(0, math.tau),
                     tilt=math.radians(rng.uniform(75, 105)),   # lying down, not standing
                     origin=(d, off, rng.uniform(0.02, 0.22)))
        p.add(lv, lf, "leaf_deep" if rng.random() < 0.6 else "leaf_olive", ls,
              detail=True)

    # a couple of broken branches sticking up out of the wreck - the silhouette that says
    # "something fell here" from a hundred metres
    for _ in range(4):
        d = rng.uniform(L * 0.35, L * 0.95)
        bl = rng.uniform(0.8, 1.6)
        bv, bf, bs = F.trunk(bl, 0.05, 0.02, sides=4, bend=0.10)
        bv = F.place(bv, yaw=rng.uniform(0, math.tau),
                     tilt=math.radians(rng.uniform(20, 55)),
                     origin=(d, rng.uniform(-0.5, 0.5), TRUNK_R * 0.9))
        p.add(bv, bf, "bark_dark", bs)
    return p


def tree_stump(rng):
    """What is left standing in the ground. Waist high, torn off, not sawn."""
    p = F.Plant("tree_stump")
    h = rng.uniform(0.55, 0.85)
    v, f, s = F.trunk(h, TRUNK_R * 1.15, TRUNK_R, sides=6, bend=0.02)
    p.add(v, f, "bark_grey", [0.0] * len(v))
    # jagged torn top - splinters, because it was blown apart, not cut
    for i in range(6):
        a = math.tau * i / 6
        b = math.tau * (i + 1) / 6
        r = TRUNK_R
        sp = [(r * math.cos(a), r * math.sin(a), h),
              (r * math.cos(b), r * math.sin(b), h),
              (r * 0.3 * math.cos((a + b) * 0.5), r * 0.3 * math.sin((a + b) * 0.5),
               h + rng.uniform(0.10, 0.34))]
        p.add(sp, [[0, 1, 2]], "rot_wood", [0.0, 0.0, 0.0])
    # buttress roots left in the dirt
    for i in range(4):
        yaw = math.tau * i / 4 + rng.uniform(-0.3, 0.3)
        bl, bh, t = 0.9, 0.42, 0.05
        bv = [(0, -t, 0), (0, t, 0), (bl, -t * 0.3, 0), (bl, t * 0.3, 0),
              (0, -t, bh), (0, t, bh)]
        bf = [[0, 2, 3, 1], [0, 4, 2], [1, 3, 5], [4, 5, 3, 2]]
        p.add(F.place(bv, yaw=yaw), bf, "bark_grey", [0.0] * 6)
    return p


def main():
    F.clean()
    F.save_palette_png()
    os.makedirs(OUT_DIR, exist_ok=True)
    rng = random.Random(SEED)

    print("THE THREE PIECES OF A FELLED TREE\n")
    for name, fn in (("felled_tree", felled_tree),
                     ("felled_trunk", felled_trunk),
                     ("tree_stump", tree_stump)):
        p = fn(rng)
        # COLOR.b = 0 on all of them: these are not destructible slots, they ARE the
        # destroyed tree. Plant.__init__ already zeroes it; assert rather than assume.
        if any(t != 0 for t in p.tree):
            raise RuntimeError("%s carries a tree slot - it must not" % name)
        ob = p.bake(flat=False)
        vs = [v.co for v in ob.data.vertices]
        print("%-14s  %5d tris   bbox x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f"
              % (name, sum(len(f.vertices) - 2 for f in ob.data.polygons),
                 min(v.x for v in vs), max(v.x for v in vs),
                 min(v.y for v in vs), max(v.y for v in vs),
                 min(v.z for v in vs), max(v.z for v in vs)))
        # THE PIVOT - only felled_tree needs it. That one is HINGED about its origin when
        # it falls, so the origin must BE the foot; if it drifts, the tree pivots about
        # its own navel. felled_trunk and tree_stump are just placed, and a fallen tree's
        # crushed leaves legitimately press below ground level.
        if name == "felled_tree" and abs(min(v.z for v in vs)) > 0.05:
            raise RuntimeError(
                "%s does not sit on z=0 (lowest vert %.3f). It hinges about its ORIGIN; "
                "if the origin is not the foot, the tree pivots about its navel."
                % (name, min(v.z for v in vs)))
        export(ob, os.path.join(OUT_DIR, name + ".glb"))
        bpy.data.objects.remove(ob, do_unlink=True)

    print("\nfelled_tree  : pivots about (0,0,0) - the game hinges it about the foot")
    print("felled_trunk : ~%.2fm of hard cover lying on its side - PRONE height" % (TRUNK_R * 2))
    print("tree_stump   : what stays in the ground")
    print("\ncollider radius %.2f m - MUST match make_jungle_patches.record_tree()" % TRUNK_R)


if __name__ == "__main__":
    main()
