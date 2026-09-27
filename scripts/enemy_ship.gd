## An enemy pinnace (Poly Haven): at anchor it shells the player, with speed > 0 it sails at the player and
## must be sunk before it rams. Kinematic so cannonballs hit it.
class_name EnemyShip
extends AnimatableBody3D

signal fired(from: Vector3, velocity: Vector3)
signal sunk(ship: EnemyShip)
signal rammed(ship: EnemyShip)

var speed: float = 0.0
var hit_points: int = 2
var has_cannon: bool = true
var interval: float = 7.0
var next_fire: float = Tuning.ENEMY_FIRST_SHOT_DELAY + 1.5
var sinking_since: float = -1.0
var heading: float = 0.0
var _model: Node3D

func setup(sp: float, hp: int, cannon: bool, iv: float) -> void:
    speed = sp
    hit_points = hp
    has_cannon = cannon
    interval = iv
    sync_to_physics = false
    var shape := CollisionShape3D.new()
    var b := BoxShape3D.new()
    b.size = Vector3(4.2, 1.4, 1.9)
    shape.shape = b
    shape.position = Vector3(0, 0.3, 0)
    add_child(shape)
    add_to_group("enemy_ships")
    # The baked pinnace lies along z with its bow at +z; a quarter turn back puts the bow at
    # -x, the way `heading` steers. Scaled so the hull is 5.5 m long, a quarter of it under water.
    _model = Models.prop("pinnace")
    var hull_len := 33.2
    var s := 5.5 / hull_len
    _model.scale = Vector3(s, s, s)
    _model.rotation.y = -PI / 2.0
    _model.position = Vector3(0, -10.3 * s * 0.28, 0)
    add_child(_model)
    if has_cannon:
        var gun := Models.instance("res://assets/pirate/cannon.glb")
        Models.fit(gun, Vector3(0.5, 0.45, 0.7), true)
        gun.position = Vector3(0.6, 0.65, 0.3)
        gun.rotation.y = PI
        add_child(gun)

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
    var extra_roll := 0.0
    if sinking_since >= 0.0:
        var k: float = minf((now - sinking_since) / Tuning.SHIP_SINK_DURATION, 1.0)
        y -= k * k * 3.0
        extra_roll = k * 0.9
        if k >= 1.0:
            sunk.emit(self)
            return
    global_position = Vector3(p.x, y, p.z)
    rotation = Vector3(atan(s.z) * 0.6, heading, -(atan(s.y) * 0.8 + extra_roll))
    if has_cannon and sinking_since < 0.0:
        next_fire -= delta
        if next_fire <= 0.0:
            next_fire = interval
            var origin := to_global(Vector3(0.6, 0.9, 0.6))
            fired.emit(origin, EnemyGun.solve(origin, player_pos, Tuning.ENEMY_BALL_SPEED * 1.0))
