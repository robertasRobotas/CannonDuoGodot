## A pirate pinnace (Poly Haven). At anchor it shells the player; with speed > 0 it sails at
## the player and must be sunk before it rams. Kinematic so cannonballs hit it.
##
## It is built as two parts, hull and rigging, so it can break: every hit starts a fire on
## deck; the last one blows it apart: the masts and sails topple into the sea, planks and
## barrels fly and float on the waves, and the burning hull goes down bow first.
class_name EnemyShip
extends AnimatableBody3D

signal fired(from: Vector3, velocity: Vector3)
signal sunk(ship: EnemyShip)
signal rammed(ship: EnemyShip)

const HULL_LEN := 33.2   # the baked pinnace's length in its own units
const RIG_SURFACES := ["ship_pinnace_rigging", "ship_pinnace_sails"]

var speed: float = 0.0
var hit_points: int = 2
var has_cannon: bool = true
var interval: float = 7.0
var next_fire: float = Tuning.ENEMY_FIRST_SHOT_DELAY + 1.5
var sinking_since: float = -1.0
var heading: float = 0.0
var length := 5.5
var _model: Node3D
var _rig: MeshInstance3D
var _fires: Array[Node3D] = []
var _list := 0.0   # heel from damage, radians

static var _parts: Dictionary = {}   # "body"/"rig" -> ArrayMesh split from the pinnace

func setup(sp: float, hp: int, cannon: bool, iv: float, ship_length: float = 5.5) -> void:
    speed = sp
    hit_points = hp
    has_cannon = cannon
    interval = maxf(iv, 8.5)
    # Gunships do not all open fire at once.
    next_fire = Tuning.ENEMY_FIRST_SHOT_DELAY + 3.0 + randf() * 5.0
    length = ship_length
    sync_to_physics = false
    var k := length / 5.5
    var shape := CollisionShape3D.new()
    var b := BoxShape3D.new()
    b.size = Vector3(4.2, 1.4, 1.9) * k
    shape.shape = b
    shape.position = Vector3(0, 0.3 * k, 0)
    add_child(shape)
    add_to_group("enemy_ships")
    # The baked pinnace lies along z with its bow at +z; a quarter turn back puts the bow at
    # -x, the way `heading` steers. A quarter of the hull sits under water.
    _split_mesh()
    _model = Node3D.new()
    var s := length / HULL_LEN
    _model.scale = Vector3(s, s, s)
    _model.rotation.y = -PI / 2.0
    _model.position = Vector3(0, -10.3 * s * 0.28, 0)
    add_child(_model)
    var body := MeshInstance3D.new()
    body.mesh = _parts.body
    _model.add_child(body)
    _rig = MeshInstance3D.new()
    _rig.mesh = _parts.rig
    _rig.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _model.add_child(_rig)

## Splits the baked pinnace into hull and rigging meshes once, by surface material.
static func _split_mesh() -> void:
    if not _parts.is_empty():
        return
    var src: Mesh = Models.prop("pinnace").mesh
    var body := ArrayMesh.new()
    var rig := ArrayMesh.new()
    for i in src.get_surface_count():
        var mat := src.surface_get_material(i)
        var target := rig if mat and mat.resource_name in RIG_SURFACES else body
        target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(i))
        target.surface_set_material(target.get_surface_count() - 1, mat)
    _parts["body"] = body
    _parts["rig"] = rig

## A hit that does not sink it: a fire where the ball struck, a worse heel.
func hit(at: Vector3) -> void:
    _list += 0.08
    if _fires.size() < 3:
        var f := _flames(1.0)
        add_child(f)
        f.global_position = at
        f.position.y = maxf(f.position.y, 0.4)
        _fires.append(f)

## The killing blow: the masts go over the side, the deck bursts, debris flies.
func break_apart(sea: Sea, fx: Fx) -> void:
    var world := get_parent()
    var center := global_position + Vector3(0, 0.6, 0)
    # Masts and sails topple into the water.
    var rig_xf := _rig.global_transform
    _model.remove_child(_rig)
    world.add_child(_rig)
    _rig.global_transform = rig_xf
    var side := 1.0 if randf() < 0.5 else -1.0
    var tw := _rig.create_tween()
    tw.set_parallel(true)
    tw.tween_property(_rig, "rotation", _rig.rotation + Vector3(side * 1.35, 0, randf_range(-0.3, 0.3)), 1.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
    tw.tween_property(_rig, "position", _rig.position + Vector3(randf_range(-1, 1), -length * 0.5, side * length * 0.25), 3.2).set_ease(Tween.EASE_IN)
    tw.chain().tween_callback(_rig.queue_free)
    # Planks, beams and barrels flying out, then floating.
    for i in 16:
        var d := Debris.new()
        d.setup(sea, i % 6 == 0, length / 5.5)
        world.add_child(d)
        d.global_position = center + Vector3(randf_range(-1, 1) * length * 0.3, randf_range(0, 0.6), randf_range(-0.6, 0.6))
        d.velocity = Vector3(randf_range(-4, 4), randf_range(4, 9), randf_range(-3, 3))
        d.spin = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
    # The deck goes up in flames.
    for k in 2:
        var f := _flames(1.6)
        add_child(f)
        f.position = Vector3((k - 0.5) * length * 0.35, 0.6, 0)
        _fires.append(f)
    fx.smoke_column(center)
    fx.splinters(center, 24)

func _flames(size: float) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.amount = 20
    p.lifetime = 0.8
    p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    p.emission_sphere_radius = 0.35 * size
    p.direction = Vector3(0, 1, 0)
    p.spread = 18.0
    p.initial_velocity_min = 0.6
    p.initial_velocity_max = 1.6
    p.gravity = Vector3(0, 1.4, 0)
    p.scale_amount_min = 0.5 * size
    p.scale_amount_max = 1.0 * size
    var ramp := Gradient.new()
    ramp.set_color(0, Color(1.0, 0.72, 0.3, 1.0))
    ramp.add_point(0.5, Color(0.9, 0.3, 0.08, 0.8))
    ramp.set_color(ramp.get_point_count() - 1, Color(0.2, 0.18, 0.18, 0.0))
    p.color_ramp = ramp
    p.mesh = QuadMesh.new()
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/flash03.png")
    m.vertex_color_use_as_albedo = true
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    p.material_override = m
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return p

func damage() -> bool:
    if sinking_since >= 0.0:
        return false
    hit_points -= 1
    return hit_points <= 0

func tick(delta: float, now: float, sea: Sea, player_pos: Vector3) -> void:
    var p := global_position
    if speed > 0.0 and sinking_since < 0.0:
        var to_player := player_pos - p
        var flat := Vector3(to_player.x, 0, to_player.z)
        if flat.length() < Tuning.SHIP_RAM_DISTANCE:
            rammed.emit(self)
            return
        var dir := flat.normalized()
        p += dir * speed * delta
        heading = atan2(dir.x, dir.z) + PI / 2.0
    var s := sea.sample(p.x, p.z)
    var y := Tuning.SEA_LEVEL + s.x + 0.15
    var roll := _list
    var pitch := 0.0
    if sinking_since >= 0.0:
        # Down by the stern, bow rising, heeling over.
        var k: float = minf((now - sinking_since) / Tuning.SHIP_SINK_DURATION, 1.0)
        y -= k * k * length * 0.75
        roll += k * 0.7
        pitch = k * 0.55
        if k >= 1.0:
            sunk.emit(self)
            return
    global_position = Vector3(p.x, y, p.z)
    rotation = Vector3(atan(s.z) * 0.6, heading, -(atan(s.y) * 0.8 + roll))
    rotate_object_local(Vector3(0, 0, 1), pitch)
    if has_cannon and sinking_since < 0.0:
        next_fire -= delta
        if next_fire <= 0.0:
            next_fire = interval
            var origin := to_global(Vector3(0.6, 0.9, 0.6) * (length / 5.5))
            fired.emit(origin, EnemyGun.solve(origin, player_pos, Tuning.ENEMY_BALL_SPEED * 1.0))
