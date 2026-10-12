## Island, shore, backdrop and vegetation for each level: realistic props from Poly Haven,
## the Sketchfab trees, palms and mountain. Each level has its own style (shore and sky) so
## no two maps look alike; scattering is seeded by the level id.
class_name Decor

## Per level: shore ("sand", "rocks" or "cliffs") and sky ("noon", "sunset", "overcast", "night";
## storms override the sky). A level can set "terrain": {"shore": ..., "sky": ...} instead.
const STYLES := [
    ["sand", "noon"], ["sand", "sunset"], ["rocks", "noon"], ["rocks", "noon"], ["cliffs", "noon"],
    ["sand", "sunset"], ["cliffs", "noon"], ["rocks", "night"], ["cliffs", "noon"], ["sand", "overcast"],
    ["sand", "noon"], ["cliffs", "sunset"], ["rocks", "overcast"], ["rocks", "night"], ["cliffs", "noon"],
    ["sand", "noon"], ["sand", "night"], ["cliffs", "noon"], ["sand", "overcast"], ["cliffs", "noon"],
]

static func style(data: Dictionary, storm: bool) -> Dictionary:
    var id := int(data.get("id", 1))
    var terrain: Dictionary = data.get("terrain", {})
    var row: Array = STYLES[(id - 1) % STYLES.size()]
    var sky: String = terrain.get("sky", row[1])
    if storm:
        sky = "storm"
    elif float(data.get("sea", 0.0)) >= 0.4 and sky == "noon":
        sky = "overcast"
    return {"shore": terrain.get("shore", row[0]), "sky": sky, "beach": float(terrain.get("beach", 4.2)), "tree_max": float(terrain.get("tree_max", 0.0))}

## Areas nothing may be placed in (x, z rectangles): the castle and the view in front of it,
## and the sea lane the ship sails in along, far out to the right where it comes from.
static var _clear: Array[Rect2] = []
## A level's ceiling for trees in metres (terrain "tree_max"); 0 means no cap.
static var _tree_cap := 0.0
## Palm islands cap their trees here unless the level says otherwise, as the first island
## does: a palm never outgrows the fort into a long bare trunk.
const PALM_MAX := 6.5

static func _free(x: float, z: float, r: float = 0.0) -> bool:
    for rect in _clear:
        if rect.grow(r).has_point(Vector2(x, z)):
            return false
    return true

## `castle` is the castle footprint in x/z (from its blocks); `ship_z` the ship's lane.
static func build(parent: Node3D, level_id: int, biome: String, storm: bool, st: Dictionary, ship_z: float, castle: Rect2 = Rect2()) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = level_id * 7919 + 13
    var shore: String = st.get("shore", "sand")
    _tree_cap = float(st.get("tree_max", 0.0))
    _flat_ease = float(st.get("flat_ease", 5.0))
    if _tree_cap <= 0.0 and biome in ["tropic", "harbor"]:
        _tree_cap = PALM_MAX
    _clear = [Rect2(-13.0, ship_z - 5.5, 90.0, 11.0)]
    if castle.size.x > 0.0:
        var c := castle.grow(2.0)
        # The castle, and everything between it and the water.
        _clear.append(Rect2(c.position.x, c.position.y, c.size.x, Tuning.SHORE_Z - c.position.y))
    _terrain_on = false
    _seed = float(level_id) * 1.37
    # The level ground round the castle: wider for a hillfort, so the mound stands on an open
    # field and no dune rises against its foot.
    _flat = castle.grow(float(st.get("flat", 3.0))) if castle.size.x > 0.0 else Rect2()
    # The level yard stops at the waterline: a pier's footprint stays over the water.
    if _flat.size.x > 0.0 and _flat.end.y > Tuning.SHORE_Z - 1.5:
        _flat.size.y = maxf((Tuning.SHORE_Z - 1.5) - _flat.position.y, 0.5)
    if biome != "opensea":
        _island(parent, biome, shore, float(st.get("beach", 4.2)))
    var first_decor := parent.get_child_count()
    # One kind of island per biome: its own trees, hills and ground. Trees never mix.
    match biome:
        "opensea":
            # Distant rocky islets around the open water.
            for i in 9:
                var m := Models.prop("coastal_cliff_01" if i % 3 == 0 else "namaqualand_cliff_01")
                var k := rng.randf_range(0.3, 0.6) if i % 3 == 0 else rng.randf_range(2.0, 4.0)
                m.scale = Vector3(k, k, k)
                m.position = Vector3(rng.randf_range(-90, 90), -1.0, rng.randf_range(-110, -70))
                m.rotation.y = rng.randf_range(0, TAU)
                parent.add_child(m)
        "highlands":
            # Cold north: snowy peaks and pine forest.
            _mountains(parent, rng, 7, 22.0, 34.0)
            _forest(parent, rng, ["pine"], 70, 4.0, 8.5)
            _trees(parent, rng, ["pine"], 24, 3.5, 7.0)
            _props(parent, rng, [["boulder_01", 0.8, 2.2], ["namaqualand_boulder_02", 1.0, 2.0], ["fern_02", 1.4, 2.4], ["tree_stump_01", 0.8, 1.2]], 60)
        "badlands":
            # Dry red country: mesas instead of mountains, dead trees.
            _mesas(parent, rng, 7, -70.0, -45.0, 5.0, 8.0)
            _mesas(parent, rng, 6, -40.0, -16.0, 1.6, 2.8)
            _props(parent, rng, [["dead_tree_trunk", 3.0, 5.0], ["tree_stump_01", 1.0, 1.6], ["boulder_01", 1.0, 3.0], ["namaqualand_boulder_02", 1.0, 2.2]], 60)
        "volcano":
            # Black ground, dead trees, and the smoking mountain behind.
            _volcano(parent)
            _mesas(parent, rng, 5, -60.0, -40.0, 3.0, 5.0, Color(0.35, 0.3, 0.3))
            _props(parent, rng, [["dead_tree_trunk", 3.0, 5.0], ["boulder_01", 1.0, 2.6], ["namaqualand_boulder_02", 1.0, 2.4]], 50)
        "harbor":
            # A tropical port: palms and shrubs like the rest of the southern islands.
            _hills(parent, rng, Color(0.5, 0.72, 0.42))
            _forest(parent, rng, ["palm_coconut", "palm_coconut", "palm_plant"], 40, 5.0, 8.5)
            _props(parent, rng, [["shrub_02", 0.7, 1.2], ["fern_02", 1.5, 2.6], ["boulder_01", 0.6, 1.4]], 60)
            _quay(parent, rng)
        "meadow":
            # Green farmland: rolling hills, oaks and maples, windmills turning.
            _hills(parent, rng, Color(0.62, 0.8, 0.5))
            _forest(parent, rng, ["oak_small", "oak_medium", "oak_large", "maple", "oak_medium"], 40 if biome == "meadow" else 18, 4.5, 8.0)
            _trees(parent, rng, ["oak_small", "oak_medium", "oak_large", "maple"], 10 if biome == "meadow" else 4, 3.5, 6.5)
            if biome == "meadow":
                _windmills(parent, rng, 3)
            _props(parent, rng, [["shrub_02", 0.7, 1.2], ["boulder_01", 0.6, 1.4], ["tree_stump_01", 0.8, 1.2]], 40)
            if biome == "harbor":
                _quay(parent, rng)
        _:
            # Tropic: palm forest and green hills, ferns and shrubs.
            _hills(parent, rng, Color(0.5, 0.72, 0.42))
            _forest(parent, rng, ["palm_coconut", "palm_coconut", "palm_plant"], 55, 5.0, 8.5)
            _trees(parent, rng, ["palm_coconut", "palm_plant"], 14, 4.5, 7.5)
            _props(parent, rng, [["shrub_02", 0.7, 1.2], ["fern_02", 1.5, 2.6], ["boulder_01", 0.6, 1.6]], 80)
    if castle.size.x > 0.0 and biome != "opensea" and bool(st.get("yard", true)):
        _yard(parent, castle, biome)
    if biome != "opensea":
        _shore(parent, rng, biome, shore, ship_z)
    _clouds(parent, rng, storm, st.get("sky", "") == "night", st.get("sky", "") == "sunset")
    # Everything placed above stands on the ground, not on a flat plane.
    if _terrain_on:
        for i in range(first_decor, parent.get_child_count()):
            var n := parent.get_child(i)
            if n is Node3D and not (n is CPUParticles3D):
                var p := (n as Node3D).position
                if absf(p.z) < 115.0:
                    (n as Node3D).position.y += height(p.x, p.z)

## Painted cloud cards (2D Cloud Pack) spread across the sky behind the island.
static func _clouds(parent: Node3D, rng: RandomNumberGenerator, storm: bool, night: bool = false, sunset: bool = false) -> void:
    if storm:
        _scud(parent)
    # Every other sky is a photograph with its own clouds; no cloud objects needed.
    return
    # Volumetric-looking clouds: each one a cluster of soft camera-facing puffs packed into a
    # flattened dome, sunlit on top and grey-blue underneath, so it stays round and solid from
    # every angle, including from above. High and far, above the fly-in.
    var top := Color(0.2, 0.22, 0.3, 0.55) if night else Color(1.0, 0.99, 0.97, 0.75)
    var belly := Color(0.1, 0.11, 0.16, 0.6) if night else Color(0.72, 0.76, 0.86, 0.7)
    if sunset:
        top = Color(1.0, 0.86, 0.72, 0.75)
        belly = Color(0.62, 0.5, 0.58, 0.7)
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = true
    var q := QuadMesh.new()
    q.size = Vector2(1, 1)
    mm.mesh = q
    var puffs: Array = []
    for c in 9:
        var centre := Vector3(rng.randf_range(-110, 110), rng.randf_range(38, 55), rng.randf_range(-150, -70))
        var span := Vector3(rng.randf_range(14, 26), rng.randf_range(4, 7), rng.randf_range(8, 14))
        for k in 26:
            var u := Vector3(rng.randfn(0, 0.45), absf(rng.randfn(0, 0.5)), rng.randfn(0, 0.45))
            var pos := centre + u * span
            var shade := clampf(u.y / 0.8, 0.0, 1.0)
            var size := rng.randf_range(12.0, 22.0) * (1.0 - 0.3 * shade)
            puffs.append([pos, size, belly.lerp(top, shade)])
    mm.instance_count = puffs.size()
    for i in puffs.size():
        var pf: Array = puffs[i]
        var sz: float = pf[1]
        mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(sz, sz, sz)), pf[0]))
        mm.set_instance_color(i, pf[2])
    var mi := MultiMeshInstance3D.new()
    mi.multimesh = mm
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/whitePuff12.png")
    m.vertex_color_use_as_albedo = true
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    m.billboard_keep_scale = true
    m.disable_fog = true
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    mi.material_override = m
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)

# MARK: Terrain

## The island as real ground: a shoreline that curves into bays and out into points, a beach
## sloping into the sea, dunes and hills rising inland, and a level yard where the castle
## stands. `height(x, z)` gives the ground height anywhere, for placing things on it.
static var _seed := 0.0
static var _flat := Rect2()
static var _flat_ease := 5.0   # metres over which the level ground rises into the dunes
static var _terrain_on := false

static func shore_z(x: float) -> float:
    var p := _seed
    var wobble := 3.0 * sin(x * 0.07 + p) + 1.7 * sin(x * 0.19 + p * 2.3) + 0.8 * sin(x * 0.41 + p * 0.7)
    # Near the firing line the shore stays close to its designed place.
    wobble *= lerpf(0.55, 1.0, smoothstep(6.0, 20.0, absf(x)))
    # A point of land reaching out to sea on the left; the right stays open for the ship.
    var point := maxf(0.0, -x - 26.0) * 0.5
    return Tuning.SHORE_Z + wobble + point

static func height(x: float, z: float) -> float:
    if not _terrain_on:
        return 0.0
    var d := shore_z(x) - z                       # metres inland from the waterline
    var h: float
    if d < 0.0:
        h = d * 0.3 + minf(d * d * -0.05, 0.0)     # sand shelving steeply into deep water
    else:
        h = 0.05 + minf(d, 6.0) * 0.07             # the beach rising gently
        var p := _seed
        var dunes := (sin(x * 0.23 + p) * sin(z * 0.19 - p) * 0.5 + 0.5) * 1.1
        var hills := (sin(x * 0.061 + p * 1.7) + sin(z * 0.045 + x * 0.02 + p)) * 0.5 + 1.0
        h += dunes * smoothstep(5.0, 12.0, d) + hills * 2.6 * smoothstep(14.0, 45.0, d)
    # The castle yard is level ground.
    if _flat.size.x > 0.0:
        var dx := maxf(maxf(_flat.position.x - x, x - _flat.end.x), 0.0)
        var dz := maxf(maxf(_flat.position.y - z, z - _flat.end.y), 0.0)
        var k := smoothstep(0.0, _flat_ease, sqrt(dx * dx + dz * dz))
        h = lerpf(0.0, h, k)
    return h

static func _island(parent: Node3D, biome: String, shore: String, _beach_depth: float = 4.2) -> void:
    _terrain_on = true
    var step := 1.3
    var x0 := -110.0
    var x1 := 110.0
    var z0 := -120.0
    var z1 := Tuning.SHORE_Z + 22.0
    var nx := int((x1 - x0) / step) + 1
    var nz := int((z1 - z0) / step) + 1
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for iz in nz:
        for ix in nx:
            var x := x0 + ix * step
            var z := z0 + iz * step
            var h := height(x, z)
            var d := shore_z(x) - z
            var sand := 1.0 - smoothstep(4.0, 10.0, d) if biome != "harbor" else 1.0 - smoothstep(3.0, 6.0, d)
            var wet := 1.0 - smoothstep(-0.2, 1.4, d)
            st.set_color(Color(sand, wet, 0.0))
            st.add_vertex(Vector3(x, h, z))
    for iz in nz - 1:
        for ix in nx - 1:
            var a := iz * nx + ix
            st.add_index(a)
            st.add_index(a + 1)
            st.add_index(a + nx)
            st.add_index(a + 1)
            st.add_index(a + nx + 1)
            st.add_index(a + nx)
    st.generate_normals()
    var mesh := st.commit()
    var ground := StaticBody3D.new()
    ground.name = "Ground"
    ground.add_to_group("ground")
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    var mat := ShaderMaterial.new()
    mat.shader = load("res://shaders/terrain.gdshader")
    var sand_name := "coast_sand_01"
    var sand_tint := Color.WHITE
    match shore:
        "rocks":
            sand_name = "gravelly_sand"
        "cliffs":
            sand_name = "coast_sand_rocks_02"
    var land_name := "leafy_grass"
    var land_tint := Color.WHITE
    match biome:
        "badlands":
            land_name = "dry_ground_01"
            land_tint = Color(1.0, 0.72, 0.56)
            sand_tint = Color(1.0, 0.82, 0.68)
        "volcano":
            land_name = "dry_ground_01"
            land_tint = Color(0.42, 0.36, 0.34)
            sand_tint = Color(0.45, 0.42, 0.42)
        "highlands":
            land_name = "forest_leaves_02"
            land_tint = Color(0.9, 0.95, 0.85)
    mat.set_shader_parameter("sand_tex", load("res://assets/ph/tex/%s.jpg" % sand_name))
    mat.set_shader_parameter("land_tex", load("res://assets/ph/tex/%s.jpg" % land_name))
    mat.set_shader_parameter("sand_tint", sand_tint)
    mat.set_shader_parameter("land_tint", land_tint)
    mi.material_override = mat
    ground.add_child(mi)
    var shape := CollisionShape3D.new()
    shape.shape = mesh.create_trimesh_shape()
    ground.add_child(shape)
    parent.add_child(ground)

## A mountain range along the horizon: overlapping peaks, the tallest behind the castle.
static func _mountains(parent: Node3D, rng: RandomNumberGenerator, count: int, min_h: float, max_h: float, crags: bool = false) -> void:
    var span := 170.0
    for i in count:
        var k := (float(i) + 0.5) / float(count)
        var x := -span / 2.0 + span * k + rng.randf_range(-6, 6)
        # Taller towards the middle of the view.
        var h := lerpf(min_h, max_h, 1.0 - absf(k - 0.5) * 1.4) * rng.randf_range(0.85, 1.1)
        var m := Models.instance("res://assets/hq/great_mountain/scene.gltf")
        Models.fit(m, Vector3(h * 2.4, h, h * 1.8), true)
        var holder := Node3D.new()
        holder.add_child(m)
        holder.position = Vector3(x, h / 2.0 - 1.0, rng.randf_range(-78, -58))
        holder.rotation.y = rng.randf_range(0, TAU)
        if crags:
            Models.tint(m, Color(1.0, 0.72, 0.55))
        parent.add_child(holder)

## A dense wood behind the castle so the fort stands against trees, not bare grass.
static func _forest(parent: Node3D, rng: RandomNumberGenerator, names: Array, count: int, min_h: float, max_h: float) -> void:
    # Woods across the whole island, in clumps: thick in groves, thin in the open, bigger
    # further back where they climb the hills.
    var groves: Array = []
    for g in 15:
        groves.append(Vector2(-88.0 + g * 12.5 + rng.randf_range(-4, 4), rng.randf_range(-80, -8)))
    var total := int(count * 2.2)
    for i in total:
        var c: Vector2 = groves[rng.randi_range(0, groves.size() - 1)]
        var x := c.x + rng.randfn(0.0, 9.0)
        var z := minf(c.y + rng.randfn(0.0, 7.0), -4.0)
        if not _free(x, z, 1.5) or shore_z(x) - z < 5.0:
            continue
        var t := Models.tree(names[rng.randi_range(0, names.size() - 1)], _capped(rng.randf_range(min_h, max_h) * (1.0 + clampf((-z - 8.0) / 60.0, 0.0, 0.6))))
        t.position = Vector3(x, 0, z)
        t.rotation.y = rng.randf_range(0, TAU)
        _sway(t, rng)
        parent.add_child(t)

## Pirate life on the shore: boats pulled up the sand, cargo, a dock, a hut, rocks in the surf.
static func _shore(parent: Node3D, rng: RandomNumberGenerator, biome: String, shore: String, ship_z: float) -> void:
    var sz := Tuning.SHORE_Z
    # Cargo on the shore: real bodies, so a stray ball knocks them about.
    for side: float in [-1.0, 1.0]:
        var bx := side * rng.randf_range(5.2, 7.0)
        var bz := rng.randf_range(-1.4, 0.0)
        if _free(bx, bz, 0.6):
            _loose(parent, "wooden_barrels_01", Vector3(bx, 0.0, bz), 1.0, rng.randf_range(0, TAU), 120.0)
        for k in 3:
            var cx := side * rng.randf_range(8.0, 10.5)
            var cz := rng.randf_range(-1.4, 0.2)
            if _free(cx, cz, 0.5):
                _loose(parent, "wooden_crate_01", Vector3(cx, 0.0, cz), rng.randf_range(1.2, 1.8), rng.randf_range(0, TAU), 30.0)
    # Fishing boats moored in a harbour only; elsewhere an anchored ship raises questions.
    var moorings: Array = []
    for spot: Vector3 in moorings:
        var boat := Models.prop("pinnace")
        var k := 9.0 / 33.2
        boat.scale = Vector3(k, k, k)
        boat.position = Vector3(spot.x, -10.3 * k * 0.28, spot.z)
        boat.rotation.y = rng.randf_range(-0.5, 0.5) + (PI if spot.x > 0 else 0.0)
        parent.add_child(boat)
    if _free(-5.8, -0.6, 0.6):
        _loose(parent, "treasure_chest", Vector3(-5.8, 0.0, -0.6), 1.0, 0.4, 60.0)
    # Rocks in the surf, never in the lane the ship sails along.
    for i in (18 if shore != "sand" else 8):
        var x := rng.randf_range(-26.0, 26.0)
        var z := sz + rng.randf_range(0.4, 10.0)
        if not _free(x, z, 2.0) or absf(x) < 5.0:
            continue   # the ship's lane, the castle, the firing line
        _place(parent, "boulder_01" if i % 2 == 0 else "namaqualand_boulder_02", Vector3(x, -0.45, z), rng.randf_range(1.0, 2.6), rng.randf_range(0, TAU))
    # A broken waterline everywhere: rocks and pebbles half in the surf.
    for i in 26:
        var x := rng.randf_range(-40.0, 40.0)
        var z := sz + rng.randf_range(-0.8, 1.6)
        if not _free(x, z, 1.0) or absf(x) < 4.0:
            continue
        _place(parent, "namaqualand_boulder_02" if i % 3 else "boulder_01", Vector3(x, -0.25, z), rng.randf_range(0.5, 1.4), rng.randf_range(0, TAU))
    match shore:
        "rocks":
            # A broken line of big rocks along the waterline either side of the landing.
            for i in 22:
                var side := -1.0 if i % 2 == 0 else 1.0
                var x := side * rng.randf_range(5.5, 30.0)
                if not _free(x, sz, 1.5):
                    continue
                var r := "namaqualand_cliff_01" if i % 4 == 0 else ("namaqualand_boulder_02" if i % 2 == 0 else "boulder_01")
                var k := rng.randf_range(0.35, 0.6) if r == "namaqualand_cliff_01" else rng.randf_range(1.2, 2.6)
                _place(parent, r, Vector3(x, -0.3, sz + rng.randf_range(-1.5, 1.0)), k, rng.randf_range(0, TAU))
        "cliffs":
            # A headland running out to sea on the left, and on the right (where the ship comes
            # from) the cliff runs along the shore instead, leaving the sea open.
            for side: float in [-1.0, 1.0]:
                var c := Models.prop("coastal_cliff_01")
                var k := rng.randf_range(0.5, 0.6)
                c.scale = Vector3(k, k * rng.randf_range(0.9, 1.25), k)
                if side < 0.0:
                    c.rotation.y = PI / 2.0 + rng.randf_range(-0.15, 0.15)
                    c.position = Vector3(-rng.randf_range(19.0, 23.0), -1.2, sz + 4.0)
                else:
                    c.rotation.y = rng.randf_range(-0.08, 0.08)
                    c.position = Vector3(rng.randf_range(36.0, 40.0), -1.2, sz - 3.5)
                parent.add_child(c)
                for j in 4:
                    var x := side * rng.randf_range(6.5, 14.0)
                    var z := sz + rng.randf_range(-3.5, 0.5)
                    if _free(x, z, 2.0):
                        _place(parent, "namaqualand_cliff_01", Vector3(x, -0.4, z), rng.randf_range(0.4, 0.7), rng.randf_range(0, TAU))
        _:
            if biome == "tropic":
                # Palms along both ends of the sandy beach.
                for i in 16:
                    var side := -1.0 if i % 2 == 0 else 1.0
                    var px := side * rng.randf_range(7.5, 26.0)
                    var pz := rng.randf_range(-4.5, 1.2)
                    if not _free(px, pz, 1.0):
                        continue
                    var t := Models.tree("palm_coconut" if i % 3 != 0 else "palm_plant", _capped(rng.randf_range(5.0, 8.0)))
                    t.position = Vector3(px, 0.0, pz)
                    t.rotation.y = rng.randf_range(0, TAU)
                    _sway(t, rng)
                    parent.add_child(t)

## A prop that is a real rigid body: knocked by balls and blasts, asleep until touched.
static func _loose(parent: Node3D, name: String, pos: Vector3, s: float, rot: float, mass: float) -> void:
    var m := Models.prop(name)
    var a := m.mesh.get_aabb()
    var body := RigidBody3D.new()
    body.mass = mass
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = a.size * s
    shape.shape = box
    shape.position = a.get_center() * s
    body.add_child(shape)
    m.scale = Vector3(s, s, s)
    body.add_child(m)
    body.position = pos + Vector3(0, 0.02, 0)
    body.rotation.y = rot
    body.can_sleep = true
    body.sleeping = true
    body.add_to_group("dynamic")
    body.add_to_group("props")
    parent.add_child(body)

## A baked Poly Haven prop at `pos`, scaled by `s` from its real size.
static func _place(parent: Node3D, name: String, pos: Vector3, s: float, rot: float) -> void:
    var m := Models.prop(name)
    m.scale = Vector3(s, s, s)
    m.position = pos
    m.rotation.y = rot
    parent.add_child(m)

## Scatters Poly Haven props over the island, keeping the firing lane and castle clear.
## Each entry is [name, min scale, max scale].
static func _props(parent: Node3D, rng: RandomNumberGenerator, entries: Array, count: int) -> void:
    for i in count:
        var x := rng.randf_range(-24, 24)
        var z := rng.randf_range(-28, 0.5)
        if not _free(x, z, 1.0):
            continue
        var e: Array = entries[rng.randi_range(0, entries.size() - 1)]
        _place(parent, e[0], Vector3(x, 0, z), rng.randf_range(e[1], e[2]), rng.randf_range(0, TAU))

## Scatters baked trees (see Tools/bake_foliage.gd); heights are in metres.
static func _trees(parent: Node3D, rng: RandomNumberGenerator, names: Array, count: int, min_h: float, max_h: float) -> void:
    for i in count:
        var x := rng.randf_range(-20, 20)
        var z := rng.randf_range(-26, 1)
        if not _free(x, z, 1.5):
            continue
        var t := Models.tree(names[rng.randi_range(0, names.size() - 1)], _capped(rng.randf_range(min_h, max_h)))
        t.position = Vector3(x, 0, z)
        t.rotation.y = rng.randf_range(0, TAU)
        _sway(t, rng)
        parent.add_child(t)

static func _capped(h: float) -> float:
    return minf(h, _tree_cap) if _tree_cap > 0.0 else h

## Marks a tree for the wind: Level sways everything in the "sway" group about its base.
static func _sway(t: Node3D, rng: RandomNumberGenerator) -> void:
    t.add_to_group("sway")
    t.set_meta("phase", rng.randf_range(0.0, TAU))
    t.set_meta("yaw", t.rotation.y)
    t.set_meta("scale", t.scale.x)


## Distant ridges: big rock outcrops far behind the island, softened by the haze. `tint`
## greens them for jungle islands.
static func _hills(parent: Node3D, rng: RandomNumberGenerator, tint: Color) -> void:
    for i in 8:
        var m := Models.prop("namaqualand_cliff_01")
        var k := rng.randf_range(4.0, 6.5)
        m.scale = Vector3(k, k * rng.randf_range(0.8, 1.2), k)
        m.position = Vector3(-90.0 + i * 25.0 + rng.randf_range(-6, 6), -2.0, rng.randf_range(-105, -85))
        m.rotation.y = rng.randf_range(0, TAU)
        Models.tint(m, Color(0.7, 0.78, 0.62).lerp(tint, 0.3))
        m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        parent.add_child(m)

## Flat-topped rock outcrops (badlands, volcano).
static func _mesas(parent: Node3D, rng: RandomNumberGenerator, count: int, z0: float, z1: float, k0: float, k1: float, tint: Color = Color(1, 1, 1)) -> void:
    for i in count:
        var m := Models.prop("namaqualand_cliff_01")
        var k := rng.randf_range(k0, k1)
        m.scale = Vector3(k, k * rng.randf_range(0.9, 1.4), k)
        m.position = Vector3(rng.randf_range(-45, 45), -0.2, rng.randf_range(z0, z1))
        if not _free(m.position.x, m.position.z, 7.0 * k / 2.0):
            m.queue_free()
            continue
        m.rotation.y = rng.randf_range(0, TAU)
        if tint != Color(1, 1, 1):
            m.material_override = null
            Models.tint(m, tint)
        parent.add_child(m)

## Fire Mountain: a dark cone with a glowing crater and a column of smoke.
static func _volcano(parent: Node3D) -> void:
    var cone := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 6.0
    cm.bottom_radius = 42.0
    cm.height = 34.0
    cm.radial_segments = 28
    cone.mesh = cm
    cone.material_override = Models.tex_material("dry_ground_01", 0.08, Color(0.32, 0.26, 0.25))
    cone.position = Vector3(8.0, 15.5, -62.0)
    parent.add_child(cone)
    var glow := MeshInstance3D.new()
    var gm := CylinderMesh.new()
    gm.top_radius = 5.5
    gm.bottom_radius = 5.5
    gm.height = 0.3
    glow.mesh = gm
    var lava := StandardMaterial3D.new()
    lava.albedo_color = Color(0.3, 0.05, 0.02)
    lava.emission_enabled = true
    lava.emission = Color(1.0, 0.35, 0.05)
    lava.emission_energy_multiplier = 4.0
    glow.material_override = lava
    glow.position = Vector3(8.0, 32.6, -62.0)
    parent.add_child(glow)
    var light := OmniLight3D.new()
    light.light_color = Color(1.0, 0.4, 0.1)
    light.light_energy = 6.0
    light.omni_range = 40.0
    light.position = Vector3(8.0, 36.0, -62.0)
    parent.add_child(light)
    var smoke := CPUParticles3D.new()
    smoke.amount = 40
    smoke.lifetime = 9.0
    smoke.preprocess = 9.0
    smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    smoke.emission_sphere_radius = 3.0
    smoke.direction = Vector3(0.25, 1, 0)
    smoke.spread = 10.0
    smoke.initial_velocity_min = 2.0
    smoke.initial_velocity_max = 3.5
    smoke.gravity = Vector3(0.4, 0.2, 0)
    smoke.scale_amount_min = 7.0
    smoke.scale_amount_max = 12.0
    var ramp := Gradient.new()
    ramp.set_color(0, Color(0.25, 0.2, 0.2, 0.7))
    ramp.set_color(1, Color(0.45, 0.45, 0.48, 0.0))
    smoke.color_ramp = ramp
    smoke.mesh = QuadMesh.new()
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/blackSmoke16.png")
    m.vertex_color_use_as_albedo = true
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    smoke.material_override = m
    smoke.position = Vector3(8.0, 34.0, -62.0)
    parent.add_child(smoke)

static var _mill_mat: Dictionary = {}

## Windmills on the fields behind the castle: a white stone tower, a thatched cap and four
## lattice sails turning in the wind.
static func _windmills(parent: Node3D, rng: RandomNumberGenerator, count: int) -> void:
    if _mill_mat.is_empty():
        _mill_mat["wall"] = Models.tex_material("castle_brick_07", 0.6, Color(1.5, 1.45, 1.35))
        _mill_mat["cap"] = Models.tex_material("clay_roof_tiles_02", 0.8, Color(0.75, 0.6, 0.45))
        _mill_mat["wood"] = Models.tex_material("brown_planks_07", 1.2, Color(0.7, 0.55, 0.45))
        _mill_mat["cloth"] = Models.flat_material(Color(0.95, 0.92, 0.84), 0.95)
    var placed := 0
    for attempt in 30:
        if placed >= count:
            break
        # Out on the fields to either side, well back from the fort.
        var x := (1.0 if attempt % 2 == 0 else -1.0) * rng.randf_range(22, 40)
        var z := rng.randf_range(-55, -32)
        if not _free(x, z, 4.0):
            continue
        var mill := Node3D.new()
        mill.position = Vector3(x, 0, z)
        var tower := MeshInstance3D.new()
        var tm := CylinderMesh.new()
        tm.top_radius = 1.3
        tm.bottom_radius = 1.9
        tm.height = 7.0
        tm.radial_segments = 14
        tower.mesh = tm
        tower.material_override = _mill_mat.wall
        tower.position.y = 3.5
        mill.add_child(tower)
        var cap := MeshInstance3D.new()
        var cc := CylinderMesh.new()
        cc.top_radius = 0.0
        cc.bottom_radius = 1.6
        cc.height = 2.0
        cc.radial_segments = 14
        cap.mesh = cc
        cap.material_override = _mill_mat.cap
        cap.position.y = 8.0
        mill.add_child(cap)
        var door := MeshInstance3D.new()
        var dm := BoxMesh.new()
        dm.size = Vector3(0.8, 1.5, 0.1)
        door.mesh = dm
        door.material_override = _mill_mat.wood
        door.position = Vector3(0, 0.75, 1.85)
        mill.add_child(door)
        # Sails on a hub facing the sea.
        var hub := Node3D.new()
        hub.position = Vector3(0, 6.6, 1.6)
        hub.add_to_group("mill_sails")
        hub.set_meta("speed", rng.randf_range(0.5, 0.9))
        mill.add_child(hub)
        for k in 4:
            var arm := Node3D.new()
            arm.rotation.z = k * PI / 2.0
            hub.add_child(arm)
            var spar := MeshInstance3D.new()
            var sm := BoxMesh.new()
            sm.size = Vector3(0.14, 5.0, 0.1)
            spar.mesh = sm
            spar.material_override = _mill_mat.wood
            spar.position.y = 2.5
            arm.add_child(spar)
            var cloth := MeshInstance3D.new()
            var cm2 := BoxMesh.new()
            cm2.size = Vector3(1.0, 3.6, 0.03)
            cloth.mesh = cm2
            cloth.material_override = _mill_mat.cloth
            cloth.position = Vector3(0.58, 3.0, 0.02)
            arm.add_child(cloth)
        mill.rotation.y = rng.randf_range(-0.4, 0.4)
        parent.add_child(mill)
        placed += 1

## Port Alder's waterfront: wooden piers into the sea on the left, a moored boat, crates.
static func _quay(parent: Node3D, rng: RandomNumberGenerator) -> void:
    for x: float in [-17.0, -24.0]:
        var pier := Models.prop("modular_wooden_pier")
        pier.position = Vector3(x, -4.9, Tuning.SHORE_Z + 8.5)
        parent.add_child(pier)
    for k in 5:
        var x := rng.randf_range(-24, -14)
        var z := rng.randf_range(-3.0, 0.5)
        if _free(x, z, 0.8):
            _place(parent, "wooden_crate_01" if k % 2 == 0 else "wooden_barrels_01", Vector3(x, 0, z), rng.randf_range(1.2, 1.8), rng.randf_range(0, TAU))

## A cobbled yard under the castle so it stands on a proper floor.
static func _yard(parent: Node3D, castle: Rect2, biome: String) -> void:
    var r := castle.grow(1.2)
    # The floor stops at the beach: a pier's far end stands in the water.
    if r.end.y > Tuning.SHORE_Z - 1.5:
        r.size.y = maxf(Tuning.SHORE_Z - 1.5 - r.position.y, 0.5)
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(r.size.x, 0.06, r.size.y)
    mi.mesh = bm
    var tint := Color(0.85, 0.8, 0.72) if biome != "volcano" else Color(0.5, 0.46, 0.44)
    mi.material_override = Models.tex_material("cobblestone_floor_01", 0.45, tint)
    mi.position = Vector3(r.get_center().x, 0.01, r.get_center().y)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)

## A storm sky: low, torn rain clouds racing across under the overcast, in several layers.
static func _scud(parent: Node3D) -> void:
    for layer in 3:
        var p := CPUParticles3D.new()
        p.amount = 34
        p.lifetime = 26.0
        p.preprocess = 26.0
        p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
        p.emission_box_extents = Vector3(10, 3 + layer * 2, 26)
        p.direction = Vector3(1, 0, 0.1)
        p.spread = 6.0
        p.initial_velocity_min = 3.5 + layer
        p.initial_velocity_max = 5.5 + layer
        p.gravity = Vector3.ZERO
        p.angle_min = 0.0
        p.angle_max = 360.0
        p.scale_amount_min = 22.0 + layer * 8
        p.scale_amount_max = 38.0 + layer * 10
        var ramp := Gradient.new()
        var shade := 0.2 + layer * 0.06
        ramp.set_color(0, Color(shade, shade, shade + 0.03, 0.0))
        ramp.add_point(0.15, Color(shade, shade, shade + 0.03, 0.55 - layer * 0.1))
        ramp.add_point(0.85, Color(shade, shade, shade + 0.03, 0.55 - layer * 0.1))
        ramp.set_color(ramp.get_point_count() - 1, Color(shade, shade, shade + 0.03, 0.0))
        p.color_ramp = ramp
        p.mesh = QuadMesh.new()
        var m := StandardMaterial3D.new()
        m.albedo_texture = load("res://assets/particles/smoke_04.png" if layer != 1 else "res://assets/particles/smoke_07.png")
        m.vertex_color_use_as_albedo = true
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        m.disable_fog = true
        p.material_override = m
        p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        # High enough that the lowest cards clear a fort's spires.
        p.position = Vector3(-75.0, 36.0 + layer * 7.0, -38.0 - layer * 14.0)
        parent.add_child(p)
