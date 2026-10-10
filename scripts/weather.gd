## Rain, wind streaks, sea mist and lightning for rough and stormy levels. Textures from the
## Kenney particle pack; bolts from "3 Pack of Storm Lightning".
class_name Weather
extends Node3D

signal thunder(delay: float)

var _flash: OmniLight3D
var _near_rain: CPUParticles3D
var _level: Level
var _bolts: Array[Mesh] = []
var _bolt_mat: StandardMaterial3D

func setup(level: Level, storminess: float, ship_pos: Vector3) -> void:
    _level = level
    if storminess >= 0.4:
        var wind := _particles("res://assets/particles/trace_04.png", Color(1, 1, 1, 0.22), Vector2(2.2, 0.08), false)
        wind.amount = int(50 + 80 * storminess)
        wind.lifetime = 3.0
        wind.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
        wind.emission_box_extents = Vector3(1, 4.5, 17)
        wind.direction = Vector3(1, 0.03, 0.1)
        wind.spread = 3.0
        wind.initial_velocity_min = 8 + 10 * storminess
        wind.initial_velocity_max = 12 + 14 * storminess
        wind.gravity = Vector3.ZERO
        wind.position = Vector3(ship_pos.x - 28, 3, ship_pos.z - 8)
        add_child(wind)
        # Low mist drifting across the water and the beach.
        var mist := _particles("res://assets/particles/smoke_04.png", Color(0.85, 0.88, 0.92, 0.16 + 0.12 * storminess), Vector2(9, 5), true)
        mist.amount = 26
        mist.lifetime = 14.0
        mist.preprocess = 14.0
        mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
        mist.emission_box_extents = Vector3(30, 0.6, 14)
        mist.direction = Vector3(1, 0, 0)
        mist.spread = 10.0
        mist.initial_velocity_min = 0.6
        mist.initial_velocity_max = 1.4
        mist.gravity = Vector3.ZERO
        mist.scale_amount_min = 0.7
        mist.scale_amount_max = 1.4
        mist.position = Vector3(ship_pos.x, 1.4, ship_pos.z - 10)
        add_child(mist)
    if storminess >= 0.6:
        # The tempest (level 1) rains at about half density, so the fort stays readable under
        # its black sky.
        var density := 0.55 if storminess >= 0.95 else 1.0
        # Rain: streak cards falling at a slant, dense near the camera.
        var rain := _particles("res://assets/particles/trace_01.png", Color(0.85, 0.9, 1.0, 0.5), Vector2(0.05, 0.9), true)
        rain.amount = int((900 + 900 * clampf((storminess - 0.8) * 5.0, 0.0, 1.0)) * density)
        rain.lifetime = 1.3
        rain.preprocess = 1.3
        rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
        rain.emission_box_extents = Vector3(16, 0.3, 14)
        rain.direction = Vector3(0.2, -1, 0)
        rain.spread = 2.0
        rain.initial_velocity_min = 14
        rain.initial_velocity_max = 18
        rain.gravity = Vector3(0, -6, 0)
        rain.position = Vector3(ship_pos.x, 16, ship_pos.z - 4)
        add_child(rain)
        # Close rain: long bright streaks falling right in front of the camera, so the storm
        # is felt, not just seen far off.
        _near_rain = _particles("res://assets/particles/trace_01.png", Color(0.82, 0.86, 0.95, 0.42 * (0.8 if density < 1.0 else 1.0)), Vector2(0.035, 1.4), true)
        _near_rain.amount = int((700 + 900 * clampf((storminess - 0.8) * 5.0, 0.0, 1.0)) * density)
        _near_rain.lifetime = 0.55
        _near_rain.preprocess = 0.6
        _near_rain.local_coords = false
        _near_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
        _near_rain.emission_box_extents = Vector3(7, 0.5, 7)
        _near_rain.direction = Vector3(0.18, -1, 0.05)
        _near_rain.spread = 3.0
        _near_rain.initial_velocity_min = 16
        _near_rain.initial_velocity_max = 20
        _near_rain.gravity = Vector3(0, -8, 0)
        add_child(_near_rain)
        _flash = OmniLight3D.new()
        _flash.light_energy = 0.0
        _flash.omni_range = 120.0
        _flash.position = Vector3(0, 30, -20)
        add_child(_flash)
        var src: Node3D = Models.instance("res://assets/hq/lightning/scene.gltf")
        for c in src.find_children("*", "MeshInstance3D", true, false):
            _bolts.append((c as MeshInstance3D).mesh)
        src.free()
        _bolt_mat = StandardMaterial3D.new()
        _bolt_mat.albedo_color = Color(0.85, 0.9, 1.0)
        _bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        _bolt_mat.emission_enabled = true
        _bolt_mat.emission = Color(0.8, 0.85, 1.0)
        _bolt_mat.emission_energy_multiplier = 3.0

## Camera-facing cards with a Kenney particle texture. Rain streaks keep their length
## vertical (billboard around y), mist and wind face the camera fully.
func _particles(texture: String, color: Color, size: Vector2, y_billboard: bool) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    var q := QuadMesh.new()
    q.size = size
    p.mesh = q
    var m := StandardMaterial3D.new()
    m.albedo_texture = load(texture)
    m.albedo_color = color
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if y_billboard and size.y > size.x else BaseMaterial3D.BILLBOARD_ENABLED
    m.billboard_keep_scale = true
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    m.disable_receive_shadows = true
    p.material_override = m
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return p

func lightning() -> void:
    if _flash == null:
        return
    var at := Vector3(randf_range(-40, 40), 0, randf_range(-70, -35))
    _flash.position = Vector3(at.x * 0.5, 30, at.z * 0.5)
    _flash.light_energy = 16.0
    var tw := create_tween()
    tw.tween_property(_flash, "light_energy", 0.0, 0.4)
    if not _bolts.is_empty():
        var bolt := MeshInstance3D.new()
        bolt.mesh = _bolts[randi() % _bolts.size()]
        bolt.material_override = _bolt_mat
        bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        var k := randf_range(4.0, 6.5)
        bolt.scale = Vector3(k, k, k)
        bolt.position = at
        bolt.rotation.y = randf_range(0, TAU)
        add_child(bolt)
        # Flicker twice, then gone.
        var bt := create_tween()
        bt.tween_property(bolt, "visible", false, 0.06)
        bt.tween_property(bolt, "visible", true, 0.05)
        bt.tween_interval(0.12)
        bt.tween_callback(bolt.queue_free)
    # Sound travels slower than light: the farther the strike, the later the thunder.
    thunder.emit(clampf(at.length() / 120.0, 0.2, 1.4))

func _process(_delta: float) -> void:
    if _near_rain and _level and _level.camera:
        var cam := _level.camera
        _near_rain.global_position = cam.global_position - cam.global_transform.basis.z * 5.0 + Vector3(0, 6.0, 0)
