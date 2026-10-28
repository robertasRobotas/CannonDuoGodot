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
signal arrived(ship: EnemyShip)

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
var friendly := false            # the merchant under escort: our balls do not hurt it
var target_node: Node3D = null   # something other than the player to sail at (the merchant)
var waypoint := Vector3.INF      # sail here instead, and say so on arrival
var max_hp := 2
var interval_jitter := 0.0       # each wait between shots varies by up to this much
## With hits_every > 0 the gunners find the range only every so many shots: the others
## are aimed wide on purpose, the one in `hits_every` is laid dead on `sure_target`. With
## hits_every_max above it, each count is drawn anew between the two.
var hits_every := 0
var hits_every_max := 0
var _next_sure := 0
var sure_target := Vector3.INF   # where a sure shot goes (the player's gun), set by Level
var _shot_n := 0
var _rig_gone := false
var _holes := 0

static var _parts: Dictionary = {}   # "body"/"rig" -> ArrayMesh split from the pinnace

func setup(sp: float, hp: int, cannon: bool, iv: float, ship_length: float = 5.5) -> void:
    speed = sp
    hit_points = hp
    max_hp = hp
    has_cannon = cannon
    # Big ships (the duel's galleon) work their guns faster than a pinnace.
    interval = maxf(iv, 5.0 if ship_length >= 9.0 else 8.5)
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

## A hit that does not sink it: a ragged hole where the ball struck, a worse heel, a fire.
## A big ship loses her masts half way down.
func hit(at: Vector3) -> void:
    _list += 0.08 if length < 9.0 else 0.045
    _hole(at)
    if _fires.size() < (5 if length >= 9.0 else 3):
        var f := _flames(1.0)
        add_child(f)
        f.global_position = at
        f.position.y = maxf(f.position.y, 0.4)
        _fires.append(f)
    if length >= 9.0 and hit_points <= max_hp / 2 and not _rig_gone:
        if sails_burn:
            _light_sails()
        else:
            _topple_rig()

## Dress a big ship as the pirate galleon: a small black flag on a staff at the stern, and
## two guns run out on the deck on the side that faces the player (+z), each standing on
## the deck as the model has it there. Her fire comes from the two guns in turn.
## `variant` "black": a darker ship, her hull near black and her sails dyed red, with a
## second flag at the main truck.
func dress_galleon(variant: String = "") -> void:
    var s := length / HULL_LEN
    if variant == "black":
        for c in _model.get_children():
            if c != _rig:
                Models.tint(c, Color(0.42, 0.38, 0.4))
        if _rig:
            Models.tint(_rig, Color(0.75, 0.28, 0.25))
        var truck := Vector3(3.0 * s, 32.4 * s + _model.position.y, 0.0)
        _rig_extras = Atmosphere.ship_flag(self, truck, 0, 1.0)
    # Model space (bow +z, up y) to ship space: the model is turned a quarter back, so
    # model z lands on -x and model x on z.
    # The flag: a short staff on the taffrail, right aft and on the centreline.
    var stern := Vector3(18.6 * s, _deck_height(0.0, -18.5) * s + _model.position.y, 0.0)
    Atmosphere.ship_flag(self, stern, 0, 0.7)
    for mz in [4.0, -8.0]:
        var gun := Models.instance("res://assets/hq/cannon/cannon_01_1k.gltf")
        Models.fit(gun, Vector3(0.6, 0.55, 0.95) * 1.5, true)
        Models.tint(gun, Color(0.7, 0.65, 0.65))
        gun.position = Vector3(-mz * s, _deck_height(2.6, mz) * s + _model.position.y, 2.6 * s)
        _model.get_parent().add_child(gun)
        gun.owner = null
        _guns_deco.append(gun)
        _gun_dead.append(false)
        for arg in OS.get_cmdline_user_args():
            if arg.begins_with("--settle="):
                print("GALLEON gun %d at local %s" % [_guns_deco.size() - 1, gun.position])

## The deck's height in the model at (x, z): the top of the deck surface's vertices within
## a metre or so, so a gun stands on the planking, over a hatch or a step alike.
static var _deck_verts := PackedVector3Array()
static func _deck_height(mx: float, mz: float) -> float:
    if _deck_verts.is_empty():
        var src: Mesh = Models.prop("pinnace").mesh
        for i in src.get_surface_count():
            var mat := src.surface_get_material(i)
            if mat and mat.resource_name == "ship_pinnace_deck":
                _deck_verts = src.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
    var best := -INF
    for v in _deck_verts:
        if absf(v.x - mx) < 1.2 and absf(v.z - mz) < 1.2:
            best = maxf(best, v.y)
    return best if best > -INF else 8.0

var _guns_deco: Array = []
var _gun_dead: Array = []     # per deck gun: knocked out by a ball, fires no more
var _gun_i := 0               # which of the two deck guns fires next
var sails_burn := false       # half way down, the sails catch fire instead of the masts falling
var _sails_lit := false

## The sails catch: fire up every mast where the canvas hangs, the rig scorched dark.
func _light_sails() -> void:
    if _sails_lit:
        return
    _sails_lit = true
    var s := length / HULL_LEN
    for mz in [9.0, -3.0, -13.0]:
        for my in [13.0, 21.0]:
            var f := _flames(1.3)
            add_child(f)
            f.position = Vector3(-mz * s, my * s + _model.position.y, 0.0)
            _fires.append(f)
    if _rig:
        Models.tint(_rig, Color(0.42, 0.36, 0.33))

## The deck gun nearest `at` (world), within reach of a ball, that still works; -1 if none.
## A ball stops at the hull's side, a little outboard of the guns, so the reach is measured
## along the hull and in height only, and the ball must come in at deck height.
func gun_near(at: Vector3) -> int:
    var best := -1
    var best_d := 1.6
    var lp := to_local(at)
    for i in _guns_deco.size():
        if _gun_dead[i] or not is_instance_valid(_guns_deco[i]):
            continue
        var g := (_guns_deco[i] as Node3D).position
        if lp.y < g.y - 0.6:
            continue
        var d := Vector2(lp.x - g.x, lp.y - g.y).length()
        if d < best_d:
            best_d = d
            best = i
    return best

## A ball into a deck gun: it is thrown over on its side, smokes, and fires no more.
func hit_gun(i: int) -> void:
    if i < 0 or i >= _guns_deco.size() or _gun_dead[i]:
        return
    _gun_dead[i] = true
    var g := _guns_deco[i] as Node3D
    g.rotation.z += 1.2
    g.position.y += 0.1
    var smoke := _smoke(0.9)
    smoke.position = g.position + Vector3(0, 0.4, 0)
    add_child(smoke)
var debris_scale := 1.0       # the wreckage's size, over the hull's own scale
var _rig_extras: Array = []   # the flag and its pole: they go over the side with the masts

## A black shot hole with splintered planking round it, kept in ship space.
func _hole(at: Vector3) -> void:
    _holes += 1
    var local := to_local(at)
    var k := length / 5.5
    # Snap to the hull side the ball came from.
    local.z = signf(local.z if local.z != 0.0 else 1.0) * 0.9 * k
    local.y = clampf(local.y, -0.1 * k, 0.6 * k)
    var hole := MeshInstance3D.new()
    var hm := CylinderMesh.new()
    hm.top_radius = 0.26 * k
    hm.bottom_radius = 0.26 * k
    hm.height = 0.05
    hm.radial_segments = 12
    hole.mesh = hm
    hole.material_override = Models.flat_material(Color(0.05, 0.04, 0.03), 1.0)
    hole.rotation.x = PI / 2.0
    hole.position = local
    add_child(hole)
    for i in 4:
        var sp := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(randf_range(0.25, 0.5) * k, 0.04, 0.08 * k)
        sp.mesh = bm
        sp.material_override = Models.tex_material("brown_planks_07", 1.5, Color(0.55, 0.4, 0.3))
        sp.position = local + Vector3(randf_range(-0.3, 0.3) * k, randf_range(-0.2, 0.25) * k, signf(local.z) * 0.06)
        sp.rotation = Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.9, 0.9))
        add_child(sp)
    var smoke := _smoke(0.6 * k)
    smoke.position = local + Vector3(0, 0.3 * k, 0)
    add_child(smoke)

## The masts and sails go over the side.
func _topple_rig() -> void:
    if _rig_gone or _rig == null:
        return
    _rig_gone = true
    var world := get_parent()
    var rig_xf := _rig.global_transform
    _model.remove_child(_rig)
    world.add_child(_rig)
    _rig.global_transform = rig_xf
    for n in _rig_extras:
        if is_instance_valid(n):
            (n as Node3D).reparent(_rig, true)   # the flag falls with the mast it flies from
    _rig_extras.clear()
    var side := 1.0 if randf() < 0.5 else -1.0
    var tw := _rig.create_tween()
    tw.set_parallel(true)
    tw.tween_property(_rig, "rotation", _rig.rotation + Vector3(side * 1.35, 0, randf_range(-0.3, 0.3)), 1.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
    tw.tween_property(_rig, "position", _rig.position + Vector3(randf_range(-1, 1), -length * 0.5, side * length * 0.25), 3.2).set_ease(Tween.EASE_IN)
    tw.chain().tween_callback(_rig.queue_free)

static func _smoke(size: float) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.amount = 14
    p.lifetime = 2.6
    p.local_coords = false
    p.direction = Vector3(0.2, 1, 0)
    p.spread = 14.0
    p.initial_velocity_min = 0.8
    p.initial_velocity_max = 1.5
    p.scale_amount_min = 0.9 * size
    p.scale_amount_max = 1.7 * size
    var ramp := Gradient.new()
    ramp.set_color(0, Color(0.15, 0.13, 0.12, 0.55))
    ramp.set_color(1, Color(0.4, 0.4, 0.42, 0.0))
    p.color_ramp = ramp
    p.mesh = QuadMesh.new()
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/blackSmoke16.png")
    m.vertex_color_use_as_albedo = true
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    p.material_override = m
    return p

## Air escaping the hull as she goes down.
static func _bubbles(size: float) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.amount = 40
    p.lifetime = 1.2
    p.local_coords = false
    p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    p.emission_box_extents = Vector3(1.6 * size, 0.1, 0.7 * size)
    p.direction = Vector3(0, 1, 0)
    p.spread = 30.0
    p.initial_velocity_min = 0.8
    p.initial_velocity_max = 1.8
    p.scale_amount_min = 0.15 * size
    p.scale_amount_max = 0.4 * size
    p.mesh = QuadMesh.new()
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/whitePuff12.png")
    m.albedo_color = Color(1, 1, 1, 0.6)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    p.material_override = m
    return p

## The killing blow: the masts go over the side, the deck bursts, debris flies.
func break_apart(sea: Sea, fx: Fx) -> void:
    var world := get_parent()
    var center := global_position + Vector3(0, 0.6, 0)
    var k := length / 5.5
    # Masts and sails topple into the water.
    _topple_rig()
    # Planks, beams and barrels flying out to every side, then floating.
    var n := int(16 + 10 * (k - 1.0))
    for i in n:
        var d := Debris.new()
        d.setup(sea, i % 6 == 0, k * debris_scale)
        world.add_child(d)
        d.global_position = center + Vector3(randf_range(-1, 1) * length * 0.3, randf_range(0, 0.6), randf_range(-0.6, 0.6))
        d.velocity = Vector3(randf_range(-5, 5), randf_range(4, 10), randf_range(-5, 5)) * (0.8 + 0.3 * k)
        d.spin = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
    var bub := _bubbles(k)
    add_child(bub)
    bub.position = Vector3(0, -0.2, 0)
    # The deck goes up in flames.
    for j in 2:
        var f := _flames(1.6)
        add_child(f)
        f.position = Vector3((j - 0.5) * length * 0.35, 0.6, 0)
        _fires.append(f)
    fx.smoke_column(center)
    fx.splinters(center, 24)

static func _flames(size: float) -> CPUParticles3D:
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
        var goal := player_pos
        if waypoint != Vector3.INF:
            goal = waypoint
        elif target_node != null and is_instance_valid(target_node):
            goal = target_node.global_position
        var to_goal := goal - p
        var flat := Vector3(to_goal.x, 0, to_goal.z)
        if waypoint != Vector3.INF:
            if flat.length() < 1.5:
                waypoint = Vector3.INF
                arrived.emit(self)
                return
        elif flat.length() < Tuning.SHIP_RAM_DISTANCE:
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
    if has_cannon and sinking_since < 0.0 and not friendly:
        next_fire -= delta
        if next_fire <= 0.0:
            next_fire = interval + randf_range(-interval_jitter, interval_jitter)
            var origin := to_global(Vector3(0.6, 0.9, 0.6) * (length / 5.5))
            if not _guns_deco.is_empty():
                # The deck guns fire in turn, each from its own muzzle; a knocked-out gun
                # is skipped, and with both gone she is silent.
                var live := 0
                for dead in _gun_dead:
                    if not dead:
                        live += 1
                if live == 0:
                    return
                while _gun_dead[_gun_i % _guns_deco.size()]:
                    _gun_i += 1
                var g := _guns_deco[_gun_i % _guns_deco.size()] as Node3D
                _gun_i += 1
                if is_instance_valid(g):
                    origin = g.global_position + Vector3(0, 0.5, 0.9)
            if hits_every > 0:
                _shot_n += 1
                if _next_sure == 0:
                    _next_sure = randi_range(hits_every, maxi(hits_every, hits_every_max))
                var sure_now := _shot_n >= _next_sure
                if sure_now:
                    _shot_n = 0
                    _next_sure = 0
                if sure_now:
                    # The one that tells: laid dead on the gun, no scatter.
                    var sure := sure_target if sure_target != Vector3.INF else player_pos
                    fired.emit(origin, EnemyGun.solve(origin, sure, Tuning.ENEMY_BALL_SPEED, 0.0))
                else:
                    # Wide on purpose: a plume well off the beam, never near the gun.
                    var side := 1.0 if randf() < 0.5 else -1.0
                    var wide := player_pos + Vector3(side * randf_range(6.0, 9.0), 0.0, randf_range(-2.5, 2.5))
                    fired.emit(origin, EnemyGun.solve(origin, wide, Tuning.ENEMY_BALL_SPEED, 0.0))
            else:
                fired.emit(origin, EnemyGun.solve(origin, player_pos, Tuning.ENEMY_BALL_SPEED * 1.0))
