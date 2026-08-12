"""Probe 2: why is there no flame emission? Dump the stock quick_smoke volume
material, then render an explicitly-authored fire volume shader and check that
blackbody emission actually reaches the film.
"""
import bpy, os, math, time

OUT = r"C:\Users\caleb\RECONgame\_scratch\mil_fire\probe"
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.5, location=(0, 0, 0.3))
flow_obj = bpy.context.active_object
flow_obj.scale = (1.0, 1.0, 0.4)

bpy.ops.object.quick_smoke()
dom = bpy.context.active_object
ds = dom.modifiers["Fluid"].domain_settings
ds.domain_type = 'GAS'
ds.resolution_max = 48
ds.use_noise = False
ds.cache_directory = os.path.join(OUT, "cache2")
ds.cache_frame_start, ds.cache_frame_end = 1, 30
ds.cache_type = 'ALL'
ds.use_adaptive_domain = False
# Fire tuning
print("FIRE ignition=%.2f max_temp=%.2f burn=%.2f smoke=%.2f vort=%.2f" % (
    ds.flame_ignition, ds.flame_max_temp, ds.burning_rate, ds.flame_smoke, ds.flame_vorticity))

fs = flow_obj.modifiers["Fluid"].flow_settings
fs.flow_type = 'BOTH'
fs.flow_behavior = 'INFLOW'
fs.fuel_amount = 2.0
fs.temperature = 2.0

# ---- dump the stock material ----
mat = dom.data.materials[0] if dom.data.materials else None
print("STOCK_MAT", mat.name if mat else None)
if mat and mat.use_nodes:
    for n in mat.node_tree.nodes:
        print("  node", n.type, n.name)
        for i in n.inputs:
            if not i.is_linked and hasattr(i, 'default_value'):
                try:
                    print("     in %-22s = %s" % (i.name, list(i.default_value) if hasattr(i.default_value, '__len__') else round(i.default_value, 3)))
                except Exception:
                    pass
        if n.type == 'VOLUME_PRINCIPLED':
            print("     density_attr=%r temperature_attr=%r" % (n.inputs['Density Attribute'].default_value if 'Density Attribute' in n.inputs else '?', ''))

# ---- author an explicit fire volume shader ----
m2 = bpy.data.materials.new("FireVolume")
m2.use_nodes = True
nt = m2.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
out = nt.nodes.new('ShaderNodeOutputMaterial')
pv = nt.nodes.new('ShaderNodeVolumePrincipled')
pv.location = (-300, 0)
nt.links.new(pv.outputs['Volume'], out.inputs['Volume'])
print("PV_INPUTS", [i.name for i in pv.inputs])
dom.data.materials.clear()
dom.data.materials.append(m2)

sc.frame_start, sc.frame_end = 1, 30
ctx = bpy.context.copy(); ctx['object'] = dom; ctx['active_object'] = dom
t0 = time.time()
with bpy.context.temp_override(**ctx):
    bpy.ops.fluid.bake_all()
print("BAKE_OK %.1fs" % (time.time() - t0))

cd = bpy.data.cameras.new("C"); cd.type = 'ORTHO'; cd.ortho_scale = 6.0
cam = bpy.data.objects.new("C", cd); bpy.context.collection.objects.link(cam)
cam.location = (0, -10, 1.0); cam.rotation_euler = (math.radians(90), 0, 0)
sc.camera = cam

sc.render.engine = 'CYCLES'
sc.cycles.samples = 24
sc.cycles.use_denoising = False
sc.cycles.volume_step_rate = 0.5
sc.cycles.volume_max_steps = 1024
sc.render.resolution_x = sc.render.resolution_y = 128
sc.render.film_transparent = True
sc.view_settings.view_transform = 'Standard'
sc.render.image_settings.file_format = 'PNG'
sc.render.image_settings.color_mode = 'RGBA'


def stats(path):
    img = bpy.data.images.load(path)
    px = img.pixels[:]
    n = len(px) // 4
    lit = sum(1 for i in range(0, len(px), 4) if px[i + 3] > 0.02)
    peak = max(max(px[i], px[i + 1], px[i + 2]) for i in range(0, len(px), 4))
    bpy.data.images.remove(img)
    return 100.0 * lit / n, peak


# Sweep: does temperature need scaling to Kelvin, and does Blackbody fire?
for label, temp_val, bb in (("temp1200_bb1", 1200.0, 1.0), ("temp2500_bb2", 2500.0, 2.0)):
    pv.inputs['Temperature'].default_value = temp_val
    pv.inputs['Blackbody Intensity'].default_value = bb
    pv.inputs['Density'].default_value = 5.0
    for f in (10, 20, 29):
        sc.frame_set(f)
        p = os.path.join(OUT, "fire_%s_f%02d.png" % (label, f))
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        cov, peak = stats(p)
        print("FIRE %s frame %2d coverage=%.1f%% peak=%.3f" % (label, f, cov, peak))

print("PROBE2_DONE")
