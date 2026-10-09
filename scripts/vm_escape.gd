## The Eye: the ship is already in the maelstrom, going round. The current carries her; the
## helm decides whether she climbs out or slides down. Hold the rudder in the window and she
## gains; let it wander and the throat takes her.
class_name VmEscape
extends VoyageMode

const CENTER := Vector3(0, 0, -30)
const R := 26.0
const R_OUT := 23.5
const R_IN := 5.0

var radius := 15.0
var angle := PI / 2.0
var _tick_acc := 0.0
var _out := false
var _said := 0

func build(voyage: VoyageLevel) -> void:
    super.build(voyage)
    win_title = "Out of the Eye!"
    intro_line = "We're in it! Hold the rudder in the window!"
    has_hearts = false
    var packed: Array[Vector4] = [Vector4(CENTER.x, CENTER.z, R, 6.0)]
    v.sea.set_sinks(packed)
    v.speed = 3.0
    _place()

func drives() -> bool:
    return true

func ends_by_distance() -> bool:
    return false

func _window() -> float:
    # The sweet rudder angle wanders slowly: keep adjusting.
    return 0.5 + 0.28 * sin(v.time * 0.33) + 0.12 * sin(v.time * 0.9)

func _place() -> void:
    var p := CENTER + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
    var prev := v.root.position
    v.root.position.x = p.x
    v.root.position.z = p.z
    var d := Vector3(p.x - prev.x, 0, p.z - prev.z)
    if d.length() > 0.001:
        v._yaw = atan2(-d.x, -d.z) + v.steer * 0.35

func tick(delta: float) -> void:
    if v.phase != VoyageLevel.Phase.SAILING:
        return
    v.steer = move_toward(v.steer, clampf(v._steer_touch + v._steer_gyro, -1.0, 1.0), delta * 4.0)
    var win := _window()
    var inside := absf(v.steer - win) < 0.16
    var speed := 3.4 + (R_OUT - radius) * 0.12
    angle += speed / maxf(radius, 1.0) * delta
    if inside:
        radius += 1.6 * delta
        _tick_acc += 1.6 * delta
        if _tick_acc > 0.6:
            _tick_acc = 0.0
            Haptics.tick(radius / R_OUT)
    else:
        radius -= 0.9 * delta
    radius = clampf(radius, 0.0, 40.0)
    v._lat_vel = (1.0 if inside else -1.0) * 2.0
    v.spray.emitting = true
    _place()
    if radius >= R_OUT and not _out:
        _out = true
        v._say("She's out! She's OUT!")
        Haptics.rumble(2)
        Engine.time_scale = 0.5
        var tw := v.create_tween()
        tw.set_ignore_time_scale(true)
        tw.tween_interval(1.0)
        tw.tween_callback(func():
            Engine.time_scale = 1.0
            v._win())
    elif radius <= R_IN:
        _drown()
    elif radius < 9.0 and _said < 2:
        _said = 2
        v._say("The throat! Find the window, lad!")
    elif radius > 19.0 and _said < 1:
        _said = 1
        v._say("That's it! Hold her there!")

func _drown() -> void:
    v.phase = VoyageLevel.Phase.ENDED
    Engine.time_scale = 0.6
    Haptics.rumble(3)
    v._say("Down she goes...")
    var a0 := angle
    var tw := v.create_tween()
    tw.set_ignore_time_scale(true)
    tw.tween_method(func(k: float):
        var ang := a0 + k * TAU * 2.0
        var rad := lerpf(R_IN, 0.5, k)
        v.root.position = CENTER + Vector3(cos(ang) * rad, -6.0 - k * k * 6.0, sin(ang) * rad)
        v.root.rotation = Vector3(k * 0.8, -ang, k * 1.3), 0.0, 1.0, 3.0).set_ease(Tween.EASE_IN)
    tw.tween_callback(func():
        Engine.time_scale = 1.0
        v._fail("The Eye swallowed her."))

func camera(delta: float) -> bool:
    # Behind the ship along her heading, high enough to see the whole funnel.
    var p := v.root.position
    var fwd := Vector3(-sin(v._yaw), 0, -cos(v._yaw))
    var want := p - fwd * 11.0 + Vector3(0, 6.5 + (R_OUT - radius) * 0.1, 0)
    var look := p + fwd * 6.0 + (CENTER - p) * 0.15 + Vector3(0, 0.5, 0)
    v.camera.global_position = v.camera.global_position.lerp(want, minf(delta * 2.4, 1.0)) if v.time > 0.1 else want
    v.camera.look_at(look, Vector3.UP)
    v.camera.fov = lerpf(v.camera.fov, 70.0, minf(delta * 2.0, 1.0))
    return true

func draw(ui: Control) -> void:
    # The helm dial: a faint ring, the window as a thick white arc, the rudder as a needle.
    var c := Vector2(ui.size.x * 0.5, ui.size.y * 0.78)
    var rr := 150.0
    ui.draw_arc(c, rr, PI, TAU, 48, Color(1, 1, 1, 0.25), 10.0)
    var win := _window()
    var a_mid := PI + (win + 1.0) * 0.5 * PI
    ui.draw_arc(c, rr, a_mid - 0.16 * 0.5 * PI, a_mid + 0.16 * 0.5 * PI, 16, Color(1, 1, 1, 0.95), 18.0)
    var a_cur := PI + (v.steer + 1.0) * 0.5 * PI
    var tip := c + Vector2(cos(a_cur), sin(a_cur)) * (rr + 6.0)
    ui.draw_line(c + Vector2(cos(a_cur), sin(a_cur)) * 40.0, tip, Color.WHITE, 12.0)
    ui.draw_circle(c, 22.0, Color.WHITE)
    # Depth gauge: how far out of the throat she is.
    var k := clampf((radius - R_IN) / (R_OUT - R_IN), 0.0, 1.0)
    ui.draw_rect(Rect2(ui.size.x - 70, ui.size.y * 0.3, 16, ui.size.y * 0.35), Color(1, 1, 1, 0.25))
    ui.draw_rect(Rect2(ui.size.x - 70, ui.size.y * 0.3 + ui.size.y * 0.35 * (1.0 - k), 16, ui.size.y * 0.35 * k), Color(1, 1, 1, 0.9))

func autopilot_target() -> float:
    v._steer_touch = _window()
    return v.root.position.x
