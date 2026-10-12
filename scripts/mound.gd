## A hillfort mound: a flat-topped grassy hill, much wider at the foot than at the top, with
## rounded sides like the old earthworks on a river bend. A fort stands on the level
## top. The whole hill is one convex solid, so stones and pirates roll down it. A mound
## block's `size` is the hill's full footprint at the ground; the top is SKIRT narrower on
## every side.
class_name Mound

const SKIRT := 8.0        # how far the foot of the slope reaches beyond the top
const ROOT := 1.5         # the hill carries on this far under the ground, so no edge shows
const SIDES := 36
const RINGS := 12

## A point of the ring at `t` along the slope (0 the foot, 1 the top), angle index `i`: a
## rounded rectangle. The face is an S-curve, level at the foot and level again at the
## top, so the hill eases out of the field and the shoulder is rounded, with no corner at
## either end.
static func _ring_point(size: Vector3, t: float, i: int) -> Vector3:
    var a := float(i) / SIDES * TAU
    var spread := SKIRT * t      # the foot is the full footprint; the top sits SKIRT inside it
    var hw := size.x / 2.0 - spread
    var hd := size.z / 2.0 - spread
    # A superellipse (n = 3.2): straight sides, round corners.
    var c := cos(a)
    var s := sin(a)
    var x := signf(c) * pow(absf(c), 2.0 / 3.2) * hw
    var z := signf(s) * pow(absf(s), 2.0 / 3.2) * hd
    var y := -size.y / 2.0 + size.y * smoothstep(0.0, 1.0, t)
    return Vector3(x, y, z)

## The convex hull for collision, in the block's local space.
static func hull(size: Vector3) -> PackedVector3Array:
    var pts := PackedVector3Array()
    for i in SIDES:
        var foot := _ring_point(size, 0.0, i)
        pts.append(Vector3(foot.x, foot.y - ROOT, foot.z))
    for r in range(1, RINGS + 1):
        var t := float(r) / RINGS
        for i in SIDES:
            pts.append(_ring_point(size, t, i))
    return pts

## The visual: the grassy hill.
static func build(size: Vector3) -> Node3D:
    var root := Node3D.new()
    # The island's own turf (the terrain's land texture at its scale), so the hill grows out
    # of the field rather than sitting on it.
    var grass: StandardMaterial3D = Models.tex_material("leafy_grass", 0.3, Color.WHITE).duplicate()
    grass.vertex_color_use_as_albedo = true
    var rng := RandomNumberGenerator.new()
    rng.seed = int(size.x * 10.0)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rings: Array = []
    # Below the ground, then the foot, then up to the top.
    for r in range(-1, RINGS + 1):
        var t := maxf(float(r), 0.0) / RINGS
        var row: Array = []
        var shades: Array = []
        for i in SIDES:
            var p := _ring_point(size, t, i)
            if r < 0:
                p.y -= ROOT
            elif r > 0 and r < RINGS:
                # Turf is never smooth: a little bulge and sag over the face.
                var k := 1.0 + rng.randf_range(-0.03, 0.03)
                p.x *= k
                p.z *= k
                p.y += rng.randf_range(-0.1, 0.1)
            row.append(p)
            # Patchy grass: lusher and lighter toward the top, worn and darker in streaks.
            shades.append(lerpf(0.9, 1.0, t) * rng.randf_range(0.9, 1.06))
        rings.append([row, shades])
    for j in rings.size() - 1:
        var lo: Array = rings[j][0]
        var hi: Array = rings[j + 1][0]
        var sl: Array = rings[j][1]
        var sh: Array = rings[j + 1][1]
        for i in SIDES:
            var k := (i + 1) % SIDES
            for v: Array in [[lo[i], sl[i]], [lo[k], sl[k]], [hi[k], sh[k]], [lo[i], sl[i]], [hi[k], sh[k]], [hi[i], sh[i]]]:
                st.set_color(Color(1, 1, 1) * float(v[1]))
                st.add_vertex(v[0])
    # The level top: a fan from the centre.
    var top: Array = rings[-1][0]
    var centre := Vector3(0, size.y / 2.0, 0)
    for i in SIDES:
        var k := (i + 1) % SIDES
        for v: Vector3 in [centre, top[i], top[k]]:
            st.set_color(Color(1, 1, 1))
            st.add_vertex(v)
    st.generate_normals()
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    mi.material_override = grass
    root.add_child(mi)
    return root
