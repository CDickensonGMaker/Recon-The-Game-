"""Re-seat a gun's marker empties onto its CURRENT geometry. Non-destructive.

This tool never creates, deletes or edits a mesh. It only moves marker empties,
so it is safe to run after the Summoner has reshaped or repositioned parts by
hand - which is exactly when the markers go stale.

Seating rules (measured, never guessed):
  muzzle_        bore centre at the frontmost geometry face
  sight_front_   front post TIP, not the FSB protective ears
  sight_rear_    rear aperture ring CENTRE
  grip_LeftHand_ handguard centre, on the bore
  grip_RightHand_ pistol grip, upper third (where the palm sits)
  magwell_       the magazine object's own transform, so a reload snaps to it
  eject_         ejection port centre, local +Z along the brass path
  contact_*      the grab point on the part the hand manipulates

Run inside the live session:
    exec(open(r'C:\\Users\\caleb\\RECONgame\\tools\\reseat_gun_markers.py').read())
"""
import bpy
import math
from mathutils import Vector

GUNS = ('M16A1v3', 'CAR15')


def bbox(o):
    pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
    return (Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))),
            Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))


def part(gun, role):
    return bpy.data.objects.get('%s_%s' % (gun, role))


def mid(o, axis):
    a, b = bbox(o)
    return (a[axis] + b[axis]) / 2.0


def measure_bore(gun):
    """Bore = the axis of the symmetric muzzle shells, taken from geometry."""
    for role in ('hider_ring', 'hider_rear', 'barrel', 'moderator'):
        o = part(gun, role)
        if o:
            return mid(o, 1), mid(o, 2)
    raise SystemExit('%s: no muzzle shell to derive the bore from' % gun)


def frontmost_x(gun):
    ms = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith(gun + '_')]
    return min(bbox(o)[0].x for o in ms)


def place(gun, key, disp, loc, rot=None):
    nm = '%s_%s' % (key, gun)
    e = bpy.data.objects.get(nm)
    created = e is None
    if created:
        e = bpy.data.objects.new(nm, None)
        root = bpy.data.objects.get('%s_root' % gun)
        coll = (root.users_collection[0] if root and root.users_collection
                else bpy.context.scene.collection)
        coll.objects.link(e)
    e.empty_display_type = disp
    e.empty_display_size = 0.02
    par = e.parent
    e.parent = None
    e.matrix_world.translation = loc
    if rot is not None:
        e.rotation_euler = rot
    if par is None:
        par = bpy.data.objects.get('%s_root' % gun)
    if par is not None:
        w = e.matrix_world.copy()
        e.parent = par
        e.matrix_parent_inverse = par.matrix_world.inverted()
        e.matrix_world = w
    return e, created


def reseat(gun):
    by, bz = measure_bore(gun)
    x_front = frontmost_x(gun)
    out = []

    out.append(('muzzle', 'PLAIN_AXES', Vector((x_front, by, bz)), None))

    post = part(gun, 'sight_post')
    if post:
        a, b = bbox(post)
        out.append(('sight_front', 'PLAIN_AXES', Vector(((a.x + b.x) / 2, by, b.z)), None))

    rs = part(gun, 'rear_sight')
    if rs:
        a, b = bbox(rs)
        out.append(('sight_rear', 'PLAIN_AXES',
                    Vector(((a.x + b.x) / 2, by, (a.z + b.z) / 2)), None))

    hg = part(gun, 'handguard')
    if hg:
        out.append(('grip_LeftHand', 'PLAIN_AXES', Vector((mid(hg, 0), by, bz)), None))

    gr = part(gun, 'grip')
    if gr:
        a, b = bbox(gr)
        # palm sits in the upper third of the grip
        out.append(('grip_RightHand', 'PLAIN_AXES',
                    Vector(((a.x + b.x) / 2, by, b.z - (b.z - a.z) * 0.33)), None))

    mag = part(gun, 'magazine')
    if mag:
        out.append(('magwell', 'ARROWS', mag.matrix_world.translation.copy(), None))
        a, b = bbox(mag)
        out.append(('contact_mag', 'PLAIN_AXES',
                    Vector(((a.x + b.x) / 2, by, a.z + (b.z - a.z) * 0.35)), None))

    port = part(gun, 'port_cover')
    if port:
        a, b = bbox(port)
        out.append(('eject', 'SINGLE_ARROW',
                    Vector(((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2)),
                    (math.radians(-75), 0.0, math.radians(15))))

    ch = part(gun, 'charge_handle_t') or part(gun, 'charge_handle')
    if ch:
        a, b = bbox(ch)
        out.append(('contact_chandle', 'PLAIN_AXES',
                    Vector(((a.x + b.x) / 2, by, (a.z + b.z) / 2)), None))

    print('=== %s  bore y=%.5f z=%.5f  muzzle x=%.5f' % (gun, by, bz, x_front))
    for key, disp, loc, rot in out:
        before = bpy.data.objects.get('%s_%s' % (key, gun))
        prev = before.matrix_world.translation.copy() if before else None
        e, created = place(gun, key, disp, loc, rot)
        moved = (prev - loc).length * 1000 if prev is not None else float('nan')
        print('   %-16s x%8.1f z%+8.1f y%+7.1f   moved %6.1f mm%s' % (
            key, (loc.x - x_front) * 1000, (loc.z - bz) * 1000, (loc.y - by) * 1000,
            moved, '  (created)' if created else ''))

    sf = bpy.data.objects.get('sight_front_%s' % gun)
    sr = bpy.data.objects.get('sight_rear_%s' % gun)
    if sf and sr:
        d = sf.matrix_world.translation - sr.matrix_world.translation
        print('   SIGHT LINE: pitch %+.4f deg  yaw %+.4f deg  radius %.1f mm' % (
            math.degrees(math.atan2(d.z, -d.x)), math.degrees(math.atan2(d.y, -d.x)),
            d.length * 1000))


def main():
    if bpy.context.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    for g in GUNS:
        if any(o.name.startswith(g + '_') for o in bpy.data.objects):
            reseat(g)
    bpy.context.view_layer.update()


if __name__ == '__main__':
    main()
