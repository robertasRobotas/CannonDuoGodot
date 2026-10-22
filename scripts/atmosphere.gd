## Life around the castle: waving flags on the highest towers, torches at night that fall with
## the castle, a star field, a lantern on deck, and seagulls wheeling over the shore.
class_name Atmosphere

## Pirate flags on poles on the highest blocks, one per tower cluster, riding the block down.
static func flags(level: Level, max_flags: int, wind: float, spacing: float = 1.6) -> void:
    # Only on something tower-high: a sandbag nest or a stack of crates flies no colours.
    var tops := _highest_blocks(level, max_flags, spacing, 3.0)
    var shader: Shader = load("res://shaders/flag.gdshader")
    var i := 0
    for b in tops:
        var blk := b as Block
        var pole := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 0.025
        cm.bottom_radius = 0.035
        cm.height = 1.7
        pole.mesh = cm
        pole.material_override = Models.tex_material("brown_planks_07", 2.0, Color(0.6, 0.45, 0.35))
        var top_y := _top_y(blk)
        pole.position = Vector3(0, top_y + 0.85, 0)
        blk.add_child(pole)
        var flag := MeshInstance3D.new()
        var pm := PlaneMesh.new()
        pm.size = Vector2(0.95, 0.55)
        pm.orientation = PlaneMesh.FACE_Z
        pm.subdivide_width = 14
        pm.subdivide_depth = 3
        flag.mesh = pm
        var sm := ShaderMaterial.new()
        sm.shader = shader
        sm.set_shader_parameter("kind", 0)
        sm.set_shader_parameter("phase", randf() * TAU)
        sm.set_shader_parameter("wind", wind)
        flag.material_override = sm
        flag.position = Vector3(0.48, top_y + 1.4, 0)
        flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        blk.add_child(flag)
        i += 1

## Night: burning torches on the castle (children of blocks, so they fall with it).
static func torches(level: Level, count: int) -> void:
    var picks := _highest_blocks(level, count, 1.2, 1.2, 5.5)
    for b in picks:
        var blk := b as Block
        var at := Vector3(0, _top_y(blk) + 0.15, blk.size.z / 2.0 + 0.05)
        blk.add_child(_torch(at))

static func _torch(at: Vector3) -> Node3D:
    var root := Node3D.new()
    root.position = at
    var light := OmniLight3D.new()
    light.light_color = Color(1.0, 0.6, 0.28)
    light.light_energy = 2.4
    light.omni_range = 7.5
    light.position = Vector3(0, 0.3, 0.2)
    root.add_child(light)
    var fire := CPUParticles3D.new()
    fire.amount = 14
    fire.lifetime = 0.5
    fire.direction = Vector3(0, 1, 0)
    fire.spread = 12.0
    fire.initial_velocity_min = 0.3
    fire.initial_velocity_max = 0.8
    fire.gravity = Vector3(0, 1.0, 0)
    fire.scale_amount_min = 0.25
    fire.scale_amount_max = 0.45
    var ramp := Gradient.new()
    ramp.set_color(0, Color(1.0, 0.8, 0.35, 1.0))
    ramp.set_color(1, Color(0.8, 0.2, 0.05, 0.0))
    fire.color_ramp = ramp
    fire.mesh = QuadMesh.new()
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/flash03.png")
    m.vertex_color_use_as_albedo = true
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    fire.material_override = m
    root.add_child(fire)
    # Flicker.
    var tw := light.create_tween().set_loops()
    tw.tween_property(light, "light_energy", 1.8, 0.13)
    tw.tween_property(light, "light_energy", 2.6, 0.11)
    tw.tween_property(light, "light_energy", 2.2, 0.17)
    return root

## A bonfire on the ground: crossed logs, a tall flame and a wide warm light that picks the
## fort's walls out of a stormy dark.
## `size` scales the logs and the flame; the light stays the same.
static func bonfire(parent: Node3D, at: Vector3, size: float = 1.0) -> void:
    var root := Node3D.new()
    root.position = at
    var body := Node3D.new()
    body.scale = Vector3.ONE * size
    root.add_child(body)
    var bark := Models.tex_material("brown_planks_07", 1.5, Color(0.55, 0.42, 0.32))
    for i in 4:
        var log := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 0.07
        cm.bottom_radius = 0.09
        cm.height = 0.9
        cm.radial_segments = 8
        log.mesh = cm
        log.material_override = bark
        log.rotation = Vector3(deg_to_rad(68.0), i * PI / 2.0 + 0.4, 0)
        log.position = Vector3(0, 0.25, 0)
        body.add_child(log)
    var light := OmniLight3D.new()
    light.light_color = Color(1.0, 0.66, 0.3)
    light.light_energy = 4.5
    light.omni_range = 13.0
    light.shadow_enabled = false
    light.position = Vector3(0, 1.0, 0)
    root.add_child(light)
    var fire := CPUParticles3D.new()
    fire.amount = 36
    fire.lifetime = 0.8
    fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    fire.emission_sphere_radius = 0.22
    fire.direction = Vector3(0, 1, 0)
    fire.spread = 10.0
    fire.initial_velocity_min = 0.6
    fire.initial_velocity_max = 1.6
    fire.gravity = Vector3(0, 1.4, 0)
    fire.scale_amount_min = 0.5
    fire.scale_amount_max = 1.0
    var ramp := Gradient.new()
    ramp.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
    ramp.add_point(0.4, Color(1.0, 0.45, 0.12, 0.9))
    ramp.set_color(ramp.get_point_count() - 1, Color(0.6, 0.12, 0.03, 0.0))
    fire.color_ramp = ramp
    fire.mesh = QuadMesh.new()
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/flash03.png")
    m.vertex_color_use_as_albedo = true
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    fire.material_override = m
    fire.position = Vector3(0, 0.35, 0)
    body.add_child(fire)
    var tw := light.create_tween().set_loops()
    tw.tween_property(light, "light_energy", 3.6, 0.14)
    tw.tween_property(light, "light_energy", 5.0, 0.12)
    tw.tween_property(light, "light_energy", 4.2, 0.18)
    parent.add_child(root)

## A warm lantern on deck by the gun so the ship is not lost in the dark.
static func deck_lantern(ship: Node3D, at: Vector3) -> void:
    var l := OmniLight3D.new()
    l.light_color = Color(1.0, 0.72, 0.4)
    l.light_energy = 1.6
    l.omni_range = 6.0
    l.position = at + Vector3(0.8, 1.6, 0.8)
    ship.add_child(l)

## Stars on a dome over the night sky.
static func stars(parent: Node3D, count: int) -> void:
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    var q := QuadMesh.new()
    q.size = Vector2(0.9, 0.9)
    mm.mesh = q
    mm.instance_count = count
    var rng := RandomNumberGenerator.new()
    rng.seed = 42
    for i in count:
        var az := rng.randf_range(0, TAU)
        var el := rng.randf_range(0.08, 1.3)
        var d := Vector3(cos(el) * sin(az), sin(el), -cos(el) * cos(az)) * 280.0
        var s := rng.randf_range(0.4, 1.3)
        mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)), d))
    var mi := MultiMeshInstance3D.new()
    mi.multimesh = mm
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.9, 0.93, 1.0)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    m.disable_fog = true
    mi.material_override = m
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)

## Seagulls wheeling over the shore.
static func gulls(parent: Node3D, count: int, center: Vector3) -> void:
    for i in count:
        var g := Seagull.new()
        g.setup(center + Vector3(randf_range(-12, 12), randf_range(7, 14), randf_range(-6, 6)), randf_range(5.0, 11.0), randf_range(0.25, 0.45) * (1.0 if randf() < 0.5 else -1.0))
        parent.add_child(g)

# MARK: Helpers

static func _top_y(blk: Block) -> float:
    return blk.size.y / 2.0

## The highest blocks, at least `spacing` metres apart in x; optionally within a height band.
static func _highest_blocks(level: Level, count: int, spacing: float, min_y: float = 0.0, max_y: float = 99.0) -> Array:
    var all: Array = []
    for n in level.get_tree().get_nodes_in_group("blocks"):
        var b := n as Block
        if b.is_fragment or b.material_name == "tnt" or b.material_name == "glass":
            continue
        if not b.rotation.is_zero_approx():
            continue   # a leaning board or strut: a pole on it would lean too
        var top := b.position.y + b.size.y / 2.0
        if top < min_y or top > max_y:
            continue
        all.append(b)
    all.sort_custom(func(a, b): return a.position.y + a.size.y / 2.0 > b.position.y + b.size.y / 2.0)
    var out: Array = []
    for b in all:
        var ok := true
        for o in out:
            if absf((o as Block).position.x - (b as Block).position.x) < spacing:
                ok = false
                break
        if ok:
            out.append(b)
            if out.size() >= count:
                break
    return out

## The Spanish flag flying from the stern of our ship.
static func ship_flag(ship: Node3D, at: Vector3) -> void:
    var pole := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.03
    cm.bottom_radius = 0.04
    cm.height = 2.4
    pole.mesh = cm
    pole.material_override = Models.tex_material("brown_planks_07", 2.0, Color(0.55, 0.4, 0.3))
    pole.position = at + Vector3(0, 1.2, 0)
    ship.add_child(pole)
    var flag := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(1.3, 0.85)
    pm.orientation = PlaneMesh.FACE_Z
    pm.subdivide_width = 14
    pm.subdivide_depth = 3
    flag.mesh = pm
    var sm := ShaderMaterial.new()
    sm.shader = load("res://shaders/flag.gdshader")
    sm.set_shader_parameter("kind", 1)
    sm.set_shader_parameter("phase", 1.3)
    flag.material_override = sm
    flag.position = at + Vector3(0.68, 2.0, 0)
    flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    ship.add_child(flag)
