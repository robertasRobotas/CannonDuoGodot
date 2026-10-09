## Stern Chase: pirate gunships come up from astern under full sail while our ship runs; the
## gun is on the stern. The water streams past; sink two, two more crowd on sail.
class_name ScnChase
extends Scenario

var _wave := 0
var _spawned := 0

func setup(lv: Level) -> void:
    super.setup(lv)
    lock()
    level.sea.current = Vector2(0, 7.0)
    _wake()

## Spray at the bow and a long foam wake astern: the ship is under way.
func _wake() -> void:
    var ship := level.ship
    var spray := CPUParticles3D.new()
    spray.amount = 70
    spray.lifetime = 0.6
    spray.local_coords = false
    spray.direction = Vector3(0, 1, 1)
    spray.spread = 40.0
    spray.initial_velocity_min = 3.0
    spray.initial_velocity_max = 6.5
    spray.gravity = Vector3(0, -13, 0)
    spray.scale_amount_min = 0.12
    spray.scale_amount_max = 0.35
    spray.mesh = QuadMesh.new()
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/whitePuff12.png")
    m.albedo_color = Color(1, 1, 1, 0.55)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    spray.material_override = m
    spray.position = Vector3(-Ship.LENGTH * 0.5, 0.2, 0)   # the bow, in ship space
    ship.add_child(spray)
    var wake := CPUParticles3D.new()
    wake.amount = 90
    wake.lifetime = 2.6
    wake.local_coords = false
    wake.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    wake.emission_box_extents = Vector3(0.3, 0.05, 1.1)
    wake.direction = Vector3(0, 0, -1)
    wake.spread = 6.0
    wake.initial_velocity_min = 6.0
    wake.initial_velocity_max = 7.5
    wake.gravity = Vector3.ZERO
    wake.scale_amount_min = 0.6
    wake.scale_amount_max = 1.3
    var ramp := Gradient.new()
    ramp.set_color(0, Color(1, 1, 1, 0.55))
    ramp.set_color(1, Color(1, 1, 1, 0.0))
    wake.color_ramp = ramp
    wake.mesh = QuadMesh.new()
    var wm := m.duplicate()
    wm.vertex_color_use_as_albedo = true
    wm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
    wake.material_override = wm
    wake.rotation.x = -PI / 2.0
    wake.position = Vector3(Ship.LENGTH * 0.5 + 0.3, -0.75, 0)   # the stern
    ship.add_child(wake)

func _spawn_pair() -> void:
    _wave += 1
    for i in 2:
        var x := (-9.0 if i == 0 else 9.0) + randf_range(-2.0, 2.0)
        level._spawn_enemy_ship({"position": [x, 0.0, -78.0 - i * 8.0], "speed": 2.6 + 0.3 * _wave, "hitPoints": 3,
            "hasCannon": true, "interval": 7.0, "length": 6.5})
        level.ships_remaining += 1
        _spawned += 1

func tick(_delta: float) -> void:
    if not playing():
        return
    if _spawned == 0:
        _spawn_pair()
        banner("THEY'RE GAINING!", "Sink them before they board")
    elif level.ships_remaining == 0:
        if _wave < 2:
            _spawn_pair()
            banner("MORE SAIL ASTERN!", "")
        else:
            release(level.ship.global_position)
