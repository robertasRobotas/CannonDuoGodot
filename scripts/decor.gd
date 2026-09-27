## Island, shore, backdrop and vegetation for each level: realistic props from Poly Haven,
## the Sketchfab trees, palms and mountain. Each level has its own style (shore and sky) so
## no two maps look alike; scattering is seeded by the level id.
class_name Decor

## Per level: shore ("sand", "rocks" or "cliffs") and sky ("noon", "sunset", "overcast";
## storms override the sky). A level can set "terrain": {"shore": ..., "sky": ...} instead.
const STYLES := [
    ["sand", "noon"], ["sand", "sunset"], ["rocks", "noon"], ["rocks", "noon"], ["cliffs", "noon"],
    ["sand", "sunset"], ["cliffs", "noon"], ["rocks", "sunset"], ["cliffs", "noon"], ["sand", "overcast"],
    ["sand", "noon"], ["cliffs", "sunset"], ["rocks", "overcast"], ["rocks", "sunset"], ["cliffs", "noon"],
    ["sand", "noon"], ["rocks", "sunset"], ["cliffs", "noon"], ["sand", "overcast"], ["cliffs", "noon"],
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
    return {"shore": terrain.get("shore", row[0]), "sky": sky}

static func build(parent: Node3D, level_id: int, biome: String, storm: bool, st: Dictionary, ship_z: float) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = level_id * 7919 + 13
    var shore: String = st.get("shore", "sand")
    if biome != "opensea":
        _island(parent, biome, shore)
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
            _mountains(parent, rng, 7, 22.0, 34.0)
            _forest(parent, rng, ["pine"], 70, 4.0, 8.5)
            _trees(parent, rng, ["pine"], 24, 3.5, 7.0)
            _props(parent, rng, [["boulder_01", 0.8, 2.2], ["namaqualand_boulder_02", 1.0, 2.0], ["fern_02", 1.4, 2.4], ["shrub_02", 0.6, 1.0], ["tree_stump_01", 0.8, 1.2]], 60)
        "badlands":
            _mountains(parent, rng, 6, 14.0, 24.0, true)
            # Red mesas: rock outcrops standing out of the scrub.
            for i in 6:
                var m := Models.prop("namaqualand_cliff_01")
                var k := rng.randf_range(1.6, 2.8)
                m.scale = Vector3(k, k * rng.randf_range(0.9, 1.4), k)
                m.position = Vector3(rng.randf_range(-32, 32), -0.2, rng.randf_range(-40, -16))
                m.rotation.y = rng.randf_range(0, TAU)
                parent.add_child(m)
            _props(parent, rng, [["dead_tree_trunk", 3.0, 5.0], ["tree_stump_01", 1.0, 1.6], ["boulder_01", 1.0, 3.0], ["namaqualand_boulder_02", 1.0, 2.2]], 60)
        _:
            _mountains(parent, rng, 6, 20.0, 32.0)
            _forest(parent, rng, ["oak_small", "oak_medium", "oak_large", "maple", "oak_medium"], 55, 4.5, 8.0)
            _trees(parent, rng, ["oak_small", "oak_medium", "oak_large", "maple"], 14, 3.5, 6.5)
            _props(parent, rng, [["shrub_02", 0.7, 1.2], ["fern_02", 1.5, 2.6], ["boulder_01", 0.6, 1.6], ["tree_stump_01", 0.8, 1.2]], 80)
    if biome != "opensea":
        _shore(parent, rng, biome, shore, ship_z)
    _clouds(parent, rng, storm)

## Painted cloud cards (2D Cloud Pack) spread across the sky behind the island.
static func _clouds(parent: Node3D, rng: RandomNumberGenerator, storm: bool) -> void:
    var src: Node3D = Models.instance("res://assets/hq/clouds/scene.gltf")
    var cards: Array = []
    for c in src.find_children("*", "MeshInstance3D", true, false):
        var mi := c as MeshInstance3D
        var rel := Models._relative_transform(src, mi)
        var a := rel * mi.mesh.get_aabb()
        # Upright cards facing the camera; skip the flat and sideways ones.
        if a.size.y > 2.0 and a.size.x > a.size.z * 4.0:
            var mat: BaseMaterial3D = mi.get_active_material(0).duplicate()
            mat.cull_mode = BaseMaterial3D.CULL_DISABLED
            mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            # Soft edges: blend the painted alpha instead of cutting it.
            mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
            mat.albedo_color = Color(0.55, 0.56, 0.62) if storm else Color(1.0, 0.97, 0.94)
            cards.append({"mesh": mi.mesh, "xf": Transform3D(Basis.IDENTITY, -a.get_center()) * rel, "mat": mat})
    src.free()
    if cards.is_empty():
        return
    for i in (11 if storm else 8):
        var card: Dictionary = cards[rng.randi_range(0, cards.size() - 1)]
        var part := MeshInstance3D.new()
        part.mesh = card.mesh
        part.transform = card.xf
        part.material_override = card.mat
        part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        var holder := Node3D.new()
        holder.add_child(part)
        var k := rng.randf_range(1.3, 2.6)
        holder.scale = Vector3(k * (1.0 if rng.randf() < 0.5 else -1.0), k, k)
        holder.position = Vector3(rng.randf_range(-55, 55), rng.randf_range(11, 24) if not storm else rng.randf_range(9, 16), rng.randf_range(-70, -42))
        parent.add_child(holder)

static func _island(parent: Node3D, biome: String, shore: String) -> void:
    var extent := 90.0
    var depth := extent + Tuning.SHORE_Z
    var ground := StaticBody3D.new()
    ground.name = "Ground"
    ground.add_to_group("ground")
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(extent, 1.4, depth)
    shape.shape = box
    ground.add_child(shape)
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = box.size
    mi.mesh = bm
    match biome:
        "badlands": mi.material_override = Models.tex_material("dry_ground_01", 0.3, Color(1.0, 0.72, 0.56))
        "highlands": mi.material_override = Models.tex_material("forest_leaves_02", 0.35, Color(0.9, 0.95, 0.85))
        _: mi.material_override = Models.tex_material("leafy_grass", 0.3)
    ground.add_child(mi)
    ground.position = Vector3(0, -0.7, Tuning.SHORE_Z - depth / 2.0)
    parent.add_child(ground)
    # The strip along the water: sand, pebbles or rock shelf.
    var beach_mat: Material
    var wet_mat: Material
    match shore:
        "rocks":
            beach_mat = Models.tex_material("gravelly_sand", 0.45, Color(0.85, 0.85, 0.85))
            wet_mat = Models.tex_material("gravelly_sand", 0.45, Color(0.55, 0.55, 0.58), 0.4)
        "cliffs":
            beach_mat = Models.tex_material("coast_sand_rocks_02", 0.35)
            wet_mat = Models.tex_material("coast_sand_rocks_02", 0.35, Color(0.6, 0.6, 0.62), 0.4)
        _:
            var tint := Color(1.0, 0.8, 0.66) if biome == "badlands" else Color.WHITE
            beach_mat = Models.tex_material("coast_sand_01", 0.4, tint)
            wet_mat = Models.tex_material("coast_sand_01", 0.4, Color(0.7, 0.62, 0.52) * tint, 0.4)
    var beach := MeshInstance3D.new()
    var beach_mesh := BoxMesh.new()
    beach_mesh.size = Vector3(extent, 0.06, 4.2)
    beach.mesh = beach_mesh
    beach.material_override = beach_mat
    beach.position = Vector3(0, 0.03, Tuning.SHORE_Z - 2.1)
    parent.add_child(beach)
    var wet := MeshInstance3D.new()
    var wet_mesh := BoxMesh.new()
    wet_mesh.size = Vector3(extent, 0.07, 0.7)
    wet.mesh = wet_mesh
    wet.material_override = wet_mat
    wet.position = Vector3(0, 0.035, Tuning.SHORE_Z - 0.35)
    parent.add_child(wet)
    # A worn path from the shore to the castle.
    var path := MeshInstance3D.new()
    var path_mesh := BoxMesh.new()
    path_mesh.size = Vector3(1.4, 0.05, 6.0)
    path.mesh = path_mesh
    path.material_override = Models.tex_material("coast_sand_01", 0.5, Color(0.9, 0.82, 0.7))
    path.position = Vector3(0, 0.025, Tuning.SHORE_Z - 3.0 - 2.5)
    parent.add_child(path)

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
    for i in count:
        var x := rng.randf_range(-30, 30)
        var z := rng.randf_range(-36, -8.5)
        # Thin out right behind the castle so the figures stay readable.
        if absf(x) < 4.5 and z > -12:
            continue
        var t := Models.tree(names[rng.randi_range(0, names.size() - 1)], rng.randf_range(min_h, max_h) * (1.0 + (-z - 8.0) / 40.0))
        t.position = Vector3(x, 0, z)
        t.rotation.y = rng.randf_range(0, TAU)
        _sway(t, rng)
        parent.add_child(t)

## Pirate life on the shore: boats pulled up the sand, cargo, a dock, a hut, rocks in the surf.
static func _shore(parent: Node3D, rng: RandomNumberGenerator, biome: String, shore: String, ship_z: float) -> void:
    var sz := Tuning.SHORE_Z
    # Cargo on the shore: real bodies, so a stray ball knocks them about.
    for side: float in [-1.0, 1.0]:
        _loose(parent, "wooden_barrels_01", Vector3(side * rng.randf_range(5.2, 7.0), 0.0, rng.randf_range(-1.4, 0.0)), 1.0, rng.randf_range(0, TAU), 120.0)
        for k in 3:
            _loose(parent, "wooden_crate_01", Vector3(side * rng.randf_range(8.0, 10.5), 0.0, rng.randf_range(-1.4, 0.2)), rng.randf_range(1.2, 1.8), rng.randf_range(0, TAU), 30.0)
        # A pinnace riding at anchor off each end of the shore.
        var boat := Models.prop("pinnace")
        var k := 9.0 / 33.2
        boat.scale = Vector3(k, k, k)
        boat.position = Vector3(side * rng.randf_range(21.0, 27.0), -10.3 * k * 0.28, sz + rng.randf_range(6.0, 12.0))
        boat.rotation.y = rng.randf_range(-0.6, 0.6) + (PI if side > 0 else 0.0)
        parent.add_child(boat)
    _loose(parent, "treasure_chest", Vector3(-5.8, 0.0, -0.6), 1.0, 0.4, 60.0)
    # Rocks in the surf, never in the lane the ship sails along.
    for i in (18 if shore != "sand" else 8):
        var x := rng.randf_range(-26.0, 26.0)
        var z := sz + rng.randf_range(0.4, 10.0)
        if x > -13.0 and x < 15.0 and absf(z - ship_z) < 4.5:
            continue
        if absf(x) < 5.0:
            continue   # the firing lane
        _place(parent, "boulder_01" if i % 2 == 0 else "namaqualand_boulder_02", Vector3(x, -0.45, z), rng.randf_range(1.0, 2.6), rng.randf_range(0, TAU))
    match shore:
        "rocks":
            # A broken line of big rocks along the waterline either side of the landing.
            for i in 22:
                var side := -1.0 if i % 2 == 0 else 1.0
                var x := side * rng.randf_range(5.5, 30.0)
                var r := "namaqualand_cliff_01" if i % 4 == 0 else ("namaqualand_boulder_02" if i % 2 == 0 else "boulder_01")
                var k := rng.randf_range(0.35, 0.6) if r == "namaqualand_cliff_01" else rng.randf_range(1.2, 2.6)
                _place(parent, r, Vector3(x, -0.3, sz + rng.randf_range(-1.5, 1.0)), k, rng.randf_range(0, TAU))
        "cliffs":
            # Two headlands running out to sea make a bay around the landing.
            for side: float in [-1.0, 1.0]:
                var c := Models.prop("coastal_cliff_01")
                var k := rng.randf_range(0.5, 0.62)
                c.scale = Vector3(k, k * rng.randf_range(0.9, 1.25), k)
                c.rotation.y = PI / 2.0 + rng.randf_range(-0.2, 0.2)
                c.position = Vector3(side * rng.randf_range(17.0, 22.0), -1.2, sz + 4.0)
                parent.add_child(c)
                for j in 4:
                    _place(parent, "namaqualand_cliff_01", Vector3(side * rng.randf_range(6.5, 14.0), -0.4, sz + rng.randf_range(-3.5, 0.5)), rng.randf_range(0.4, 0.7), rng.randf_range(0, TAU))
        _:
            if biome == "coast":
                # Palms along both ends of the sandy beach.
                for i in 16:
                    var side := -1.0 if i % 2 == 0 else 1.0
                    var t := Models.tree("palm_coconut" if i % 3 != 0 else "palm_plant", rng.randf_range(5.0, 8.0))
                    t.position = Vector3(side * rng.randf_range(7.5, 26.0), 0.0, rng.randf_range(-4.5, 1.2))
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
        if abs(x) < 6.5 and z > -11:
            continue
        var e: Array = entries[rng.randi_range(0, entries.size() - 1)]
        _place(parent, e[0], Vector3(x, 0, z), rng.randf_range(e[1], e[2]), rng.randf_range(0, TAU))

## Scatters baked trees (see Tools/bake_foliage.gd); heights are in metres.
static func _trees(parent: Node3D, rng: RandomNumberGenerator, names: Array, count: int, min_h: float, max_h: float) -> void:
    for i in count:
        var x := rng.randf_range(-20, 20)
        var z := rng.randf_range(-26, 1)
        if abs(x) < 5.8 and z > -10:
            continue
        var t := Models.tree(names[rng.randi_range(0, names.size() - 1)], rng.randf_range(min_h, max_h))
        t.position = Vector3(x, 0, z)
        t.rotation.y = rng.randf_range(0, TAU)
        _sway(t, rng)
        parent.add_child(t)

## Marks a tree for the wind: Level sways everything in the "sway" group about its base.
static func _sway(t: Node3D, rng: RandomNumberGenerator) -> void:
    t.add_to_group("sway")
    t.set_meta("phase", rng.randf_range(0.0, TAU))
    t.set_meta("yaw", t.rotation.y)
    t.set_meta("scale", t.scale.x)
