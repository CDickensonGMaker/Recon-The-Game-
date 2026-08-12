"""Asset 2 -- fire_core_sheet.png (16 frames, 4x4, 128x128, ADDITIVE).

Reuses Asset 1's baked cache -- no second sim. The difference is the shader:
density is driven by Mantaflow's "flame" grid instead of "density", so the
volume exists ONLY where combustion is happening. That is what isolates the
hot core and drops the smoke, rather than trying to subtract smoke afterwards.
"""
import bpy, sys, os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import milcommon as M

BLEND = os.path.join(M.BLENDS, "asset1_fire.blend")
FRAME_DIR = os.path.join(M.FRAMES, "asset2_core")
LOOP_START, LOOP_COUNT = 60, 16
TEST_FRAME = 68
RES = 128
COLS, ROWS = 4, 4


def prep():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    dom = bpy.data.objects["FireDomain"]

    mat = bpy.data.materials.new("CoreVol")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    pv = nt.nodes.new('ShaderNodeVolumePrincipled'); pv.location = (-320, 0)
    # "flame" is the combustion grid: nonzero only inside actual fire.
    pv.inputs['Density Attribute'].default_value = "flame"
    pv.inputs['Density'].default_value = 9.0
    pv.inputs['Color'].default_value = (0.9, 0.9, 0.9, 1.0)   # barely absorbs
    pv.inputs['Blackbody Intensity'].default_value = 2.2
    pv.inputs['Temperature'].default_value = 2150.0
    pv.inputs['Temperature Attribute'].default_value = "temperature"
    nt.links.new(pv.outputs['Volume'], out.inputs['Volume'])
    dom.data.materials.clear()
    dom.data.materials.append(mat)

    # Tighter framing on the flame body itself, which sits low in the domain.
    cam = bpy.data.objects["VFXCam"]
    cam.data.ortho_scale = 3.5
    cam.location = (0.0, -12.0, 1.35)

    M.setup_cycles(RES, RES, samples=32, denoise=True)
    return dom


def test():
    prep()
    os.makedirs(FRAME_DIR, exist_ok=True)
    p = os.path.join(FRAME_DIR, "test_%03d.png" % TEST_FRAME)
    bpy.context.scene.frame_set(TEST_FRAME)
    bpy.context.scene.render.filepath = p
    bpy.ops.render.render(write_still=True)
    M.describe(p, "core ")


def render():
    prep()
    frames = list(range(LOOP_START, LOOP_START + LOOP_COUNT))
    paths = M.render_frames(FRAME_DIR, "f", frames)
    M.pack_sheet(paths, COLS, ROWS, RES, RES,
                 os.path.join(M.SHEETS, "fire_core_sheet.png"), crossfade=3)


if __name__ == "__main__":
    mode = sys.argv[-1]
    {"test": test, "render": render}[mode]()
    print("ASSET2_%s_DONE" % mode.upper())
