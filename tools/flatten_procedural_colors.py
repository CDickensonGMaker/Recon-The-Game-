"""THE ONE WAY TO STOP PROCEDURAL MATERIALS SHIPPING WHITE. Import this.

    from flatten_procedural_colors import flatten

glTF cannot carry a node tree. A Principled whose Base Color is driven by a
Wave->ColorRamp (the wood), a Color Ramp (MitchellCamo) or a Mix (Webbing) exports
with NO baseColorFactor, and Godot renders it placeholder WHITE - which reads in game
as "this thing is missing its texture" (model_actor.gd:577-583, and the warning it
raises at :611).

This is not new. It was diagnosed and fixed once already, in 9441273a, as an inline
block inside tools/export_viewmodel_clips.py - so the FIRST-PERSON guns came out right
while the same materials on the world models kept shipping white for weeks, because the
character exporters never got the step. That is the whole reason this lives in one file
now instead of being pasted into a fifth one.

Untextured is NOT the defect: this project paints weapons and webbing with flat palette
colours by decree. The defect is a material left on the engine default. So we resolve a
flat colour from the node driving the socket and bake it into the Principled default.

The blend is never saved by this - the viewport look is untouched, only the export.
"""


def _upstream(node, seen):
    if node in seen:
        return
    seen.add(node)
    yield node
    for inp in node.inputs:
        for l in inp.links:
            yield from _upstream(l.from_node, seen)


def _colour_inputs(node):
    """The RGBA sockets of a mix-ish node, in order. Blender 5 calls them A/B;
    the legacy MIX_RGB calls them Color1/Color2."""
    return [i for i in node.inputs if i.type == 'RGBA']


def _factor_of(node):
    for i in node.inputs:
        if i.type == 'VALUE' and i.name in ('Fac', 'Factor'):
            return float(i.default_value)
    return 0.5


def _eval(node, depth=0):
    """Resolve a node down to one flat RGBA.

    Color Ramp averages its stops - that is what 9441273a shipped for the wood, and it
    reproduces MitchellCamo's historical [0.127, 0.166, 0.07] exactly, so it stays.
    Mix was never handled, which is why Webbing fell through to Blender's 0.8 grey.
    """
    if depth > 8 or node is None:
        return None
    if node.type == 'RGB':
        return list(node.outputs[0].default_value)
    if node.type == 'VALTORGB':
        els = node.color_ramp.elements
        return [sum(e.color[i] for e in els) / len(els) for i in range(3)] + [1.0]
    if node.type in ('MIX', 'MIX_RGB'):
        cols = _colour_inputs(node)
        if len(cols) >= 2:
            a = _eval(cols[0].links[0].from_node, depth + 1) if cols[0].is_linked \
                else list(cols[0].default_value)
            b = _eval(cols[1].links[0].from_node, depth + 1) if cols[1].is_linked \
                else list(cols[1].default_value)
            if a is None:
                return b
            if b is None:
                return a
            f = _factor_of(node)
            return [a[i] * (1.0 - f) + b[i] * f for i in range(3)] + [1.0]
    # anything else: follow the first linked colour input we can resolve
    for i in node.inputs:
        if i.type == 'RGBA':
            if i.is_linked:
                got = _eval(i.links[0].from_node, depth + 1)
                if got:
                    return got
            else:
                return list(i.default_value)
    return None


def flatten(objs, verbose=True):
    """Bake a flat Base Color for every procedural material on `objs`.

    Materials fed by a real image are left alone - those export correctly.
    Returns [(material_name, [r, g, b]), ...] for what was changed.
    """
    done = []
    mats = {slot.material for o in objs if getattr(o, "type", None) == 'MESH'
            for slot in o.material_slots if slot.material and slot.material.use_nodes}
    for mat in sorted(mats, key=lambda m: m.name):
        bsdf = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if bsdf is None:
            continue
        sock = bsdf.inputs['Base Color']
        if not sock.is_linked:
            continue
        chain = list(_upstream(sock.links[0].from_node, set()))
        # an image node with NO image in it is not a texture, it is a hole - bandolier_tex
        # sat in exactly that state and shipped white for weeks
        if any(n.type == 'TEX_IMAGE' and n.image is not None for n in chain):
            continue                      # a real texture: exports fine, leave it
        col = _eval(sock.links[0].from_node)
        if col is None:
            # nothing resolvable upstream - a Color Ramp anywhere in the chain is still
            # a better answer than the socket default, which is Blender's 0.8 grey
            ramp = next((n for n in chain if n.type == 'VALTORGB'), None)
            if ramp:
                els = ramp.color_ramp.elements
                col = [sum(e.color[i] for e in els) / len(els) for i in range(3)] + [1.0]
            else:
                col = list(sock.default_value)
        mat.node_tree.links.remove(sock.links[0])
        sock.default_value = col
        done.append((mat.name, [round(c, 3) for c in col[:3]]))
    if verbose:
        print("  procedural base colours flattened: %s" % (done or "none"))
    return done


def assert_none_white(objs, limit=0.9):
    """Nothing may leave on the engine default. Raises rather than shipping it."""
    bad = []
    for o in objs:
        if getattr(o, "type", None) != 'MESH':
            continue
        for slot in o.material_slots:
            m = slot.material
            if m is None or not m.use_nodes:
                continue
            bsdf = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
            if bsdf is None:
                continue
            sock = bsdf.inputs['Base Color']
            if sock.is_linked:
                chain = list(_upstream(sock.links[0].from_node, set()))
                if any(n.type == 'TEX_IMAGE' and n.image is not None for n in chain):
                    continue
                bad.append("%s (still linked to %s)" % (m.name, sock.links[0].from_node.type))
                continue
            c = sock.default_value
            if min(c[0], c[1], c[2]) > limit:
                bad.append("%s (flat %s - the engine default)"
                           % (m.name, [round(v, 3) for v in c[:3]]))
    return sorted(set(bad))
