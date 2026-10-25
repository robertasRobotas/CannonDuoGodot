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
## The skirt of a mound: SKIRT, or half for a small one (style "mound:small").
static func skirt_of(tint: String) -> float:
    return SKIRT * 0.5 if tint == "small" else SKIRT

static func _ring_point(size: Vector3, t: float, i: int, skirt: float = SKIRT) -> Vector3:
    var a := float(i) / SIDES * TAU
    var spread := skirt * t      # the foot is the full footprint; the top sits `skirt` inside it
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
static func hull(size: Vector3, skirt: float = SKIRT) -> PackedVector3Array:
    var pts := PackedVector3Array()
    for i in SIDES:
        var foot := _ring_point(size, 0.0, i, skirt)
        pts.append(Vector3(foot.x, foot.y - ROOT, foot.z))
    for r in range(1, RINGS + 1):
        var t := float(r) / RINGS
        for i in SIDES:
            pts.append(_ring_point(size, t, i, skirt))
    return pts

## The visual: the grassy hill.
## `stone` makes a crag of the same shape: grey rock instead of turf, its faces lumpier.
static func build(size: Vector3, stone: bool = false, skirt: float = SKIRT) -> Node3D:
    var root := Node3D.new()
    # The island's own turf (the terrain's land texture at its scale), so the hill grows out
    # of the field rather than sitting on it; or bare grey rock for a crag.
    var grass: StandardMaterial3D = (Models.tex_material("coast_sand_rocks_02", 0.45, Color(0.66, 0.66, 0.7)) if stone else Models.tex_material("leafy_grass", 0.3, Color.WHITE)).duplicate()
    grass.vertex_color_use_as_albedo = true
    var lump := 0.09 if stone else 0.03
    var lift := 0.3 if stone else 0.1
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
            var p := _ring_point(size, t, i, skirt)
            if r < 0:
                p.y -= ROOT
            elif r > 0 and r < RINGS:
                # Turf is never smooth: a little bulge and sag over the face.
                var k := 1.0 + rng.randf_range(-lump, lump)
                p.x *= k
                p.z *= k
                p.y += rng.randf_range(-lift, lift)
            row.append(p)
            # Patchy grass: lusher and lighter toward the top, worn and darker in streaks.
            # Rock: darker in the clefts, paler on the ledges.
            shades.append(lerpf(0.9, 1.0, t) * rng.randf_range(0.8 if stone else 0.9, 1.06))
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
    if stone:
        # A crag's face is a cliff of fissured rock (see _cliff_face), not the smooth turf
        # mesh: swap it in, keeping the shape and the colour.
        mi.queue_free()
        root.add_child(_cliff_face(size, rng))
        _scrub(root, size, rng)
    return root

## A point on the slope at `t` up it, spread evenly round the hill's perimeter (the ring
## points crowd into the corners), on the straight run of one of its four faces.
static func _slope_point(size: Vector3, t: float, rng: RandomNumberGenerator) -> Vector3:
    var spread := SKIRT * t
    var hw := size.x / 2.0 - spread
    var hd := size.z / 2.0 - spread
    var y := -size.y / 2.0 + size.y * smoothstep(0.0, 1.0, t)
    # Which face, by its length; then where along its middle run.
    var u := rng.randf() * (2.0 * hw + 2.0 * hd)
    var k := rng.randf_range(-0.85, 0.85)
    if u < hw:
        return Vector3(k * hw, y, hd)
    elif u < 2.0 * hw:
        return Vector3(k * hw, y, -hd)
    elif u < 2.0 * hw + hd:
        return Vector3(hw, y, k * hd)
    return Vector3(-hw, y, k * hd)

## A point on the hill's ring at `t` up the slope, `u` (0..1) of the way round.
static func _ring_point_u(size: Vector3, t: float, u: float) -> Vector3:
    var a := u * TAU
    var spread := SKIRT * t
    var hw := size.x / 2.0 - spread
    var hd := size.z / 2.0 - spread
    var c := cos(a)
    var sn := sin(a)
    var x := signf(c) * pow(absf(c), 2.0 / 3.2) * hw
    var z := signf(sn) * pow(absf(sn), 2.0 / 3.2) * hd
    var y := -size.y / 2.0 + size.y * smoothstep(0.0, 1.0, t)
    return Vector3(x, y, z)

## The crag's face: the mound's shape cut as a limestone cliff. The surface is ribbed with
## near-vertical fissures (narrow dark clefts between pale buttresses) that run from the
## foot to the rim and wander a little, with ledges breaking them here and there. The
## relief is in the mesh itself, the shading in the vertex colours over the crag's grey.
static func _cliff_face(size: Vector3, rng: RandomNumberGenerator) -> MeshInstance3D:
    var mat: StandardMaterial3D = Models.tex_material("coast_sand_rocks_02", 0.2, Color(0.66, 0.66, 0.7)).duplicate()
    mat.vertex_color_use_as_albedo = true
    mat.roughness = 1.0
    var sides := 160
    var rings := 28
    var noise := FastNoiseLite.new()
    noise.seed = rng.randi()
    noise.frequency = 1.0
    var seed2 := rng.randf() * 100.0
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rows: Array = []
    var perim := 2.0 * (size.x + size.z)
    for r in range(-1, rings + 1):
        var t := maxf(float(r), 0.0) / rings
        var row: Array = []
        var shade: Array = []
        for i in sides:
            var u := float(i) / sides
            var p := _ring_point_u(size, t, u)
            var c := 1.0
            if r < 0:
                p.y -= ROOT
            elif r > 0 and r < rings:
                # The fissures: a high-frequency ribbing round the hill, wandering with
                # height; deep where the rib function troughs. Ledges: slow bands with height.
                var along := u * perim
                var wander := noise.get_noise_2d(along * 0.15, t * 6.0 + seed2) * 2.5
                var rib := sin((along + wander) * 1.9) * 0.5 + 0.5          # 0 cleft .. 1 buttress
                var rib2 := sin((along - wander) * 4.7 + 1.0) * 0.5 + 0.5
                var relief := pow(rib, 1.6) * 0.75 + rib2 * 0.25
                var ledge := smoothstep(0.75, 1.0, noise.get_noise_2d(along * 0.4, t * 14.0 + seed2 * 2.0) + 0.5) * 0.6
                var k := 0.86 + 0.26 * relief + 0.1 * ledge
                p.x *= k
                p.z *= k
                p.y += (ledge - 0.3) * 0.25
                # Pale buttresses, dark clefts: the contrast is most of the look.
                c = 0.12 + 1.45 * pow(relief, 0.7) + 0.3 * ledge
            row.append(p)
            shade.append(c)
        rows.append([row, shade])
    for j in rows.size() - 1:
        var lo: Array = rows[j][0]
        var hi: Array = rows[j + 1][0]
        var sl: Array = rows[j][1]
        var sh: Array = rows[j + 1][1]
        for i in sides:
            var k := (i + 1) % sides
            for v: Array in [[lo[i], sl[i]], [lo[k], sl[k]], [hi[k], sh[k]], [lo[i], sl[i]], [hi[k], sh[k]], [hi[i], sh[i]]]:
                st.set_color(Color(1, 1, 1) * float(v[1]))
                st.add_vertex(v[0])
    var top: Array = rows[-1][0]
    var centre := Vector3(0, size.y / 2.0, 0)
    for i in sides:
        var k := (i + 1) % sides
        for v: Vector3 in [centre, top[i], top[k]]:
            st.set_color(Color(0.92, 0.92, 0.92))
            st.add_vertex(v)
    st.generate_normals()
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    mi.material_override = mat
    return mi

## Scrub on the cliff: dark green tufts rooted in the clefts and on the ledges, in small
## clusters, as on a limestone face. One MultiMesh.
static func _scrub(root: Node3D, size: Vector3, rng: RandomNumberGenerator) -> void:
    var sphere := SphereMesh.new()
    sphere.radius = 0.5
    sphere.height = 1.0
    sphere.radial_segments = 8
    sphere.rings = 5
    var green := Models.flat_material(Color(0.14, 0.22, 0.1), 1.0)
    var xforms: Array = []
    for c in 34:
        var t0 := rng.randf_range(0.1, 0.92)
        var u0 := rng.randf()
        for i in rng.randi_range(2, 5):
            var t := clampf(t0 + rng.randf_range(-0.04, 0.04), 0.05, 0.97)
            var u := u0 + rng.randf_range(-0.012, 0.012)
            var p := _ring_point_u(size, t, u)
            var r := rng.randf_range(0.3, 0.65)
            var out := 1.0 + (r * 0.3) / maxf(Vector2(p.x, p.z).length(), 1.0)
            var basis := Basis.from_euler(Vector3(0, rng.randf_range(0, TAU), 0)).scaled(Vector3(r * rng.randf_range(0.9, 1.5), r * 0.6, r * rng.randf_range(0.9, 1.5)))
            xforms.append(Transform3D(basis, Vector3(p.x * out, p.y, p.z * out)))
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = sphere
    mm.instance_count = xforms.size()
    for i in xforms.size():
        mm.set_instance_transform(i, xforms[i])
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.material_override = green
    root.add_child(mmi)

## A point on the slope at `t` up it and `u` (0..1) of the way round the hill's perimeter,
## on the plain rectangle of that level (the corners' rounding is within a boulder's reach).
static func _perimeter_point(size: Vector3, t: float, u: float) -> Vector3:
    t = clampf(t, 0.0, 1.0)
    var spread := SKIRT * t
    var hw := size.x / 2.0 - spread
    var hd := size.z / 2.0 - spread
    var y := -size.y / 2.0 + size.y * smoothstep(0.0, 1.0, t)
    var d := u * 4.0 * (hw + hd)
    if d < 2.0 * hw:
        return Vector3(-hw + d, y, hd)
    d -= 2.0 * hw
    if d < 2.0 * hd:
        return Vector3(hw, y, hd - d)
    d -= 2.0 * hd
    if d < 2.0 * hw:
        return Vector3(hw - d, y, -hd)
    d -= 2.0 * hw
    return Vector3(-hw, y, -hd + d)
