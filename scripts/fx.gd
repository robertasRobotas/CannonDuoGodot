## Particle effects. CPU particles, one-shot, small counts: fine on phones. Smoke, fire and
## flash sprites come from the Kenney smoke and particle packs.
class_name Fx
extends Node3D

static var _sprite_mats: Dictionary = {}

## Camera-facing textured sprites that grow and fade over their life.
func _sprites(at: Vector3, texture: String, color: Color, count: int, speed: float, size: float, life: float, gravity: float = 0.0, grow: float = 2.0, spread: float = 180.0) -> void:
    var p := CPUParticles3D.new()
    p.emitting = false
    p.one_shot = true
    p.amount = count
    p.lifetime = life
    p.explosiveness = 0.9
    p.direction = Vector3(0, 1, 0)
    p.spread = spread
    p.initial_velocity_min = speed * 0.4
    p.initial_velocity_max = speed
    p.gravity = Vector3(0, gravity, 0)
    p.damping_min = 1.5
    p.damping_max = 3.0
    p.angle_min = 0.0
    p.angle_max = 360.0
    p.scale_amount_min = size * 0.7
    p.scale_amount_max = size
    var curve := Curve.new()
    curve.add_point(Vector2(0, 1.0 / grow))
    curve.add_point(Vector2(1, 1))
    p.scale_amount_curve = curve
    var ramp := Gradient.new()
    ramp.set_color(0, color)
    ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
    p.color_ramp = ramp
    var q := QuadMesh.new()
    p.mesh = q
    if not _sprite_mats.has(texture):
        var m := StandardMaterial3D.new()
        m.albedo_texture = load(texture)
        m.vertex_color_use_as_albedo = true
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        m.cull_mode = BaseMaterial3D.CULL_DISABLED
        _sprite_mats[texture] = m
    p.material_override = _sprite_mats[texture]
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    p.position = at
    add_child(p)
    p.emitting = true
    get_tree().create_timer(life * 1.3).timeout.connect(p.queue_free)

func _burst(at: Vector3, color: Color, count: int, speed: float, size: float, life: float, gravity: float = -6.0) -> void:
    var p := CPUParticles3D.new()
    p.emitting = false
    p.one_shot = true
    p.amount = count
    p.lifetime = life
    p.explosiveness = 1.0
    p.direction = Vector3(0, 1, 0)
    p.spread = 180.0
    p.initial_velocity_min = speed * 0.5
    p.initial_velocity_max = speed
    p.gravity = Vector3(0, gravity, 0)
    p.damping_min = 1.0
    p.damping_max = 2.0
    p.scale_amount_min = size * 0.6
    p.scale_amount_max = size
    p.color = color
    var m := SphereMesh.new()
    m.radius = 0.5
    m.height = 1.0
    m.radial_segments = 6
    m.rings = 3
    p.mesh = m
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.vertex_color_use_as_albedo = true
    p.material_override = mat
    p.position = at
    add_child(p)
    p.emitting = true
    get_tree().create_timer(life * 1.4).timeout.connect(p.queue_free)

func prewarm(at: Vector3) -> void:
    _burst(at, Color(1, 1, 1, 0.01), 2, 0.1, 0.01, 0.2)

func muzzle(at: Vector3) -> void:
    _sprites(at, "res://assets/particles/flash03.png", Color(1, 0.9, 0.7, 1), 2, 0.2, 1.3, 0.14, 0.0, 1.5)
    _sprites(at, "res://assets/particles/whitePuff05.png", Color(0.92, 0.92, 0.9, 0.55), 7, 1.4, 0.55, 1.3, 0.4, 2.2, 50.0)

func dust(at: Vector3, material: String) -> void:
    var c: Color
    match material:
        "wood": c = Color(0.7, 0.5, 0.3)
        "glass": c = Color(0.8, 0.92, 1)
        "stone": c = Color(0.6, 0.6, 0.6)
        "metal": c = Color(0.4, 0.4, 0.4)
        _: c = Color(1, 0.6, 0.15)
    _burst(at, c, 16, 1.5, 0.06, 0.6)
    _sprites(at, "res://assets/particles/smoke_07.png", Color(c.r, c.g, c.b, 0.6), 5, 0.8, 1.2, 1.4, 0.2, 2.0)

func pop(at: Vector3, color: Color) -> void:
    _burst(at, color, 46, 3.2, 0.08, 0.9)
    _burst(at, Color(1, 0.96, 0.88), 14, 1.5, 0.14, 0.6)

func blast(at: Vector3) -> void:
    _sprites(at, "res://assets/particles/explosion02.png", Color(1, 0.95, 0.85, 1), 5, 2.5, 3.2, 0.55, 0.0, 2.2)
    _sprites(at, "res://assets/particles/explosion05.png", Color(1, 0.9, 0.8, 1), 5, 4.0, 2.6, 0.7, 0.0, 2.0)
    _sprites(at + Vector3(0, 0.5, 0), "res://assets/particles/blackSmoke08.png", Color(0.3, 0.28, 0.27, 0.8), 14, 2.2, 3.0, 3.2, 1.2, 2.2, 70.0)
    _sprites(at, "res://assets/particles/spark_05.png", Color(1, 0.8, 0.4, 1), 30, 9.0, 0.35, 0.8, -8.0, 1.0)
    _burst(at, Color(1, 0.62, 0.2), 40, 5.5, 0.16, 0.9)
    # Shock ring: a flat expanding disc.
    var ring := MeshInstance3D.new()
    var tm := TorusMesh.new()
    tm.inner_radius = 0.2
    tm.outer_radius = 0.35
    ring.mesh = tm
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(1, 0.9, 0.6, 0.8)
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ring.material_override = mat
    ring.position = Vector3(at.x, maxf(at.y - 0.2, 0.05), at.z)
    add_child(ring)
    var tw := create_tween()
    tw.tween_property(ring, "scale", Vector3(9, 1, 9), 0.4).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.4)
    tw.tween_callback(ring.queue_free)

func splash(at: Vector3) -> void:
    _burst(at, Color(1, 0.98, 0.94), 30, 3.5, 0.12, 0.7)
    _sprites(at, "res://assets/particles/whitePuff12.png", Color(0.9, 0.95, 1.0, 0.8), 8, 3.0, 1.1, 0.9, -5.0, 1.8, 30.0)

func intercept(at: Vector3) -> void:
    _burst(at, Color(0.98, 0.78, 0.32), 50, 4, 0.12, 0.6)
    _burst(at, Color.WHITE, 20, 6, 0.2, 0.3)

func confetti(at: Vector3) -> void:
    _burst(at, Color(0.98, 0.42, 0.4), 60, 4, 0.06, 2.5, -2.5)
    _burst(at, Color(0.98, 0.78, 0.32), 60, 4, 0.06, 2.5, -2.5)
    _burst(at, Color(0.62, 0.88, 0.80), 60, 4, 0.06, 2.5, -2.5)

## Wood splinters: thin shards flying out of a broken plank, pointing along their flight.
func splinters(at: Vector3, count: int = 14) -> void:
    var p := CPUParticles3D.new()
    p.emitting = false
    p.one_shot = true
    p.amount = count
    p.lifetime = 1.6
    p.explosiveness = 0.95
    p.direction = Vector3(0, 1, 0)
    p.spread = 80.0
    p.initial_velocity_min = 2.5
    p.initial_velocity_max = 6.0
    p.gravity = Vector3(0, -9.8, 0)
    p.particle_flag_align_y = true
    p.scale_amount_min = 0.6
    p.scale_amount_max = 1.3
    var bm := BoxMesh.new()
    bm.size = Vector3(0.025, 0.22, 0.03)
    p.mesh = bm
    p.material_override = Models.tex_material("brown_planks_07", 3.0, Color(1.1, 0.85, 0.62))
    p.position = at
    add_child(p)
    p.emitting = true
    get_tree().create_timer(2.2).timeout.connect(p.queue_free)

var _columns := 0

## A column of dark smoke rising from the wreckage for several seconds after a blast.
func smoke_column(at: Vector3) -> void:
    if _columns >= 4:
        return
    _columns += 1
    var p := CPUParticles3D.new()
    p.amount = 26
    p.lifetime = 4.5
    p.direction = Vector3(0.15, 1, 0)
    p.spread = 12.0
    p.initial_velocity_min = 0.8
    p.initial_velocity_max = 1.6
    p.gravity = Vector3(0.25, 0.3, 0)
    p.damping_min = 0.2
    p.damping_max = 0.4
    p.angle_min = 0.0
    p.angle_max = 360.0
    p.scale_amount_min = 1.6
    p.scale_amount_max = 2.6
    var curve := Curve.new()
    curve.add_point(Vector2(0, 0.5))
    curve.add_point(Vector2(1, 1.6))
    p.scale_amount_curve = curve
    var ramp := Gradient.new()
    ramp.set_color(0, Color(0.22, 0.2, 0.19, 0.0))
    ramp.add_point(0.15, Color(0.22, 0.2, 0.19, 0.55))
    ramp.set_color(ramp.get_point_count() - 1, Color(0.4, 0.4, 0.42, 0.0))
    p.color_ramp = ramp
    p.mesh = QuadMesh.new()
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/blackSmoke16.png")
    m.vertex_color_use_as_albedo = true
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    p.material_override = m
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    p.position = at
    add_child(p)
    # Smoke for six seconds, then let the last puffs rise and go.
    get_tree().create_timer(6.0).timeout.connect(func(): if is_instance_valid(p): p.emitting = false)
    get_tree().create_timer(11.0).timeout.connect(func():
        _columns -= 1
        if is_instance_valid(p): p.queue_free())

## A flash of orange light at a blast: at night the whole castle lights up.
func blast_light(at: Vector3, energy: float = 9.0) -> void:
    var l := OmniLight3D.new()
    l.light_color = Color(1.0, 0.62, 0.3)
    l.light_energy = energy
    l.omni_range = 14.0
    l.position = at + Vector3(0, 1.0, 0)
    add_child(l)
    var tw := create_tween()
    tw.set_ignore_time_scale(true)
    tw.tween_property(l, "light_energy", 0.0, 0.7).set_ease(Tween.EASE_IN)
    tw.tween_callback(l.queue_free)
