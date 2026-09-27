## An enemy cannon on the castle. Fires arcing shots at the player's ship; breaks when hit hard.
class_name EnemyGun
extends RigidBody3D

signal fired(from: Vector3, velocity: Vector3)
signal destroyed(gun: EnemyGun)

var interval: float = 6.0
var power: float = 0.5
var next_fire: float = Tuning.ENEMY_FIRST_SHOT_DELAY
var frozen := false
var _pending_break := false

func setup(iv: float, pw: float) -> void:
    interval = iv
    power = pw
    next_fire = Tuning.ENEMY_FIRST_SHOT_DELAY + 1.5 + randf() * 4.0
    mass = 60.0
    var shape := CollisionShape3D.new()
    var b := BoxShape3D.new()
    b.size = Vector3(0.6, 0.55, 0.9)
    shape.shape = b
    shape.position = Vector3(0, 0.28, 0.05)
    add_child(shape)
    angular_damp = 0.6
    contact_monitor = true
    max_contacts_reported = 4
    add_to_group("dynamic")
    add_to_group("enemy_guns")
    # The Poly Haven cannon, like the player's; it faces +z, the sea, as modelled.
    var model := Models.instance("res://assets/hq/cannon/cannon_01_1k.gltf")
    Models.fit(model, Vector3(0.6, 0.55, 0.95), true)
    model.position.y += 0.28
    Models.tint(model, Color(0.7, 0.65, 0.65))
    add_child(model)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    if frozen:
        return
    var strongest := 0.0
    for i in state.get_contact_count():
        strongest = maxf(strongest, state.get_contact_impulse(i).length())
    if strongest / mass > Tuning.ENEMY_CANNON_BREAK:
        _pending_break = true

func _physics_process(_delta: float) -> void:
    if _pending_break:
        _pending_break = false
        destroyed.emit(self)

func tick(delta: float, target: Vector3) -> void:
    next_fire -= delta
    if next_fire <= 0.0:
        next_fire = interval
        var origin := to_global(Vector3(0, 0.45, 0.6))
        var v := EnemyGun.solve(origin, target, Tuning.ENEMY_BALL_SPEED * (0.85 + 0.3 * power))
        fired.emit(origin, v)

func set_frozen(value: bool) -> void:
    frozen = value
    freeze = value
    freeze_mode = RigidBody3D.FREEZE_MODE_STATIC

## Ballistic solve on the high arc so the ball can be seen and hit.
static func solve(origin: Vector3, target: Vector3, speed: float) -> Vector3:
    var scatter := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * Tuning.ENEMY_AIM_ERROR
    var d := target + scatter - origin
    var flat := Vector2(d.x, d.z)
    var dx := flat.length()
    var dy := d.y
    var g := Tuning.GRAVITY
    var v := speed
    var angle: float
    var disc := v * v * v * v - g * (g * dx * dx + 2.0 * dy * v * v)
    if disc > 0.0:
        angle = atan((v * v + sqrt(disc)) / (g * dx))
    else:
        angle = PI / 4.0
        v = sqrt(g * dx * dx / maxf(dx - dy, 0.5)) * 1.05
    var dir := flat / maxf(dx, 0.001)
    return Vector3(dir.x * cos(angle), sin(angle), dir.y * cos(angle)) * v
