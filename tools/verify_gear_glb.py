"""verify_gear_glb.py - read back the NVA/VC gear library and prove every GLB.

    blender -b -P tools/verify_gear_glb.py
    blender -b -P tools/verify_gear_glb.py -- --json out.json

Exit code 1 if any check fails, so this can gate an export.

The checks are the bug classes that shipped silently on this library, not a
wishlist. Each one cost a rebuild:

  DEAD IMAGE   a material's texture points at a path outside the repo instead of
               being packed into the GLB. Twelve images were once repointed at a
               session scratchpad; the .blend rendered fine and the GLB was bare.
  DARK COLOR_0 jungle_atlas MULTIPLIES its texture by the vertex colour, and the
               vegetation these cuts came from carries dark green vertex colours
               (measured mean 0.537/0.260/0.000). Exported as COLOR_0 that
               multiply the palette down to near-black. NOTE THE DIRECTION: an
               ABSENT COLOR_0 is safe, because Godot defaults vertex colour to
               white and the palette passes through unharmed. Present-and-dark is
               the defect, and two variants of the same prop disagreeing about
               whether they carry COLOR_0 at all will not match on screen.
  NO UV        an unwrapped mesh takes the atlas's top-left pixel.
  TRI DRIFT    the manifest's tris are what the dresser and the perf ledger are
               read against; a re-export that changes them makes both wrong.
               Only TRIS are compared - glTF splits vertices per unique
               (position, normal, uv), so a GLB's vertex count is legitimately
               ~3x the Blender count on flat-shaded geometry and is NOT a defect.
  BBOX         every prop is authored in its socket BONE's local space so the
               Godot BoneAttachment3D is identity. A prop whose bone-local bbox
               moved is a prop that will hang in the wrong place, and the .blend
               it came from looks correct.
"""
import bpy, os, sys, json

REPO = r"C:\Users\caleb\RECONgame"
MANIFEST = os.path.join(REPO, "assets", "nva_vc", "props", "nva_vc_gear.json")
CATS = ("headgear", "packs", "chest", "belt")

# A prop that has drifted this far from its recorded bone-local box is in the
# wrong place on the body, not merely re-tessellated.
BBOX_TOL = 0.02
# Tri counts are integers and should match exactly; allow nothing.
TRI_TOL = 0
# Mean COLOR_0 luminance below this multiplies the jungle palette down to mud.
DARK_COLOR = 0.55

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
json_out = os.path.abspath(argv[argv.index("--json") + 1]) if "--json" in argv else None

man = json.loads(open(MANIFEST, encoding="utf-8-sig").read())

report, failures = {}, []


def fail(key, msg):
    failures.append("%s: %s" % (key, msg))
    return msg


for cat in CATS:
    for key, entry in sorted(man.get(cat, {}).items()):
        if not isinstance(entry, dict):
            fail("%s/%s" % (cat, key), "manifest entry is not an object")
            continue
        glb = entry.get("glb")
        if not glb:
            # An explicit "wear nothing" sentinel. Nothing to verify, but it must
            # still be a well-formed entry or _hang treats it as a MISSING entry
            # and never takes the welded gear off.
            report["%s/%s" % (cat, key)] = {"sentinel": True}
            continue

        path = os.path.join(REPO, glb.replace("res://", "").replace("/", os.sep))
        tag = "%s/%s" % (cat, key)
        if not os.path.isfile(path):
            fail(tag, "no file at %s" % glb)
            continue

        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=path)

        meshes = [o for o in bpy.data.objects if o.type == 'MESH']
        colour_means = []
        rigs = [o for o in bpy.data.objects if o.type == 'ARMATURE']
        probs = []

        if not meshes:
            probs.append(fail(tag, "GLB contains no mesh"))

        for o in meshes:
            if not o.data.uv_layers:
                probs.append(fail(tag, "%s has no UV layer" % o.name))
            # jungle_atlas multiplies by COLOR_0. Absent COLOR_0 is SAFE (Godot
            # defaults to white); present-and-dark is what renders leaves black.
            uses_atlas = any(m and "jungle" in m.name.lower()
                            for m in o.data.materials)
            ca = o.data.color_attributes.active_color
            if ca is not None:
                vals = [tuple(d.color_srgb)[:3] for d in ca.data]
                if vals:
                    mean = sum(sum(v) / 3.0 for v in vals) / len(vals)
                    colour_means.append((o.name, round(mean, 3)))
                    if uses_atlas and mean < DARK_COLOR:
                        probs.append(fail(tag, "%s COLOR_0 mean %.3f multiplies the "
                                               "jungle palette to mud" % (o.name, mean)))
            elif uses_atlas:
                colour_means.append((o.name, None))

        for m in bpy.data.materials:
            if not m.use_nodes:
                continue
            for n in m.node_tree.nodes:
                if n.type == 'TEX_IMAGE' and n.image:
                    if n.image.packed_file is None:
                        probs.append(fail(tag, "material %s image %s is NOT packed "
                                               "(path %s)"
                                          % (m.name, n.image.name,
                                             n.image.filepath or "<empty>")))

        tris, verts, mn, mx = 0, 0, [1e9] * 3, [-1e9] * 3
        for o in meshes:
            o.data.calc_loop_triangles()
            tris += len(o.data.loop_triangles)
            verts += len(o.data.vertices)
            for v in o.data.vertices:
                w = o.matrix_world @ v.co
                mn = [min(a, b) for a, b in zip(mn, w)]
                mx = [max(a, b) for a, b in zip(mx, w)]

        want_tris = entry.get("tris")
        if isinstance(want_tris, int) and abs(tris - want_tris) > TRI_TOL:
            probs.append(fail(tag, "tris %d but manifest says %d" % (tris, want_tris)))

        box = entry.get("bone_local_bbox")
        if isinstance(box, dict) and "min" in box and "max" in box:
            for i, axis in enumerate("xyz"):
                for lbl, got, want in (("min", mn[i], box["min"][i]),
                                       ("max", mx[i], box["max"][i])):
                    if abs(got - want) > BBOX_TOL:
                        probs.append(fail(tag, "bone-local %s.%s %.4f but manifest "
                                               "says %.4f" % (lbl, axis, got, want)))

        report[tag] = {"tris": tris, "verts": verts, "meshes": len(meshes),
                       "rig": rigs[0].name if rigs else None,
                       "colour_means": colour_means,
                       "bbox": {"min": [round(v, 4) for v in mn],
                                "max": [round(v, 4) for v in mx]},
                       "problems": probs}
        print("%-6s %-30s tris=%-5d verts=%-5d meshes=%d  %s"
              % ("FAIL" if probs else "ok", tag, tris, verts, len(meshes),
                 "; ".join(probs) if probs else ""), flush=True)

checked = sum(1 for v in report.values() if not v.get("sentinel"))
print("\n%d GLBs checked, %d sentinels, %d failures"
      % (checked, len(report) - checked, len(failures)))
for f in failures:
    print("  FAIL", f)

if json_out:
    with open(json_out, "w", encoding="utf-8") as fh:
        json.dump({"report": report, "failures": failures}, fh, indent=1)

sys.exit(1 if failures else 0)
