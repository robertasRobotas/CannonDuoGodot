## Wordless tutorial drawn with shapes: step 1 a phone tilting left and right under two curved
## arrows (turn the phone to aim); step 2 a finger pressing, pulling down and letting go while
## a glowing power bar fills (drag down to load, release to fire). Soft, looping, and it
## fades out as soon as the player does the thing it shows.
class_name TutorialHint
extends Control

enum Step { AIM, LOAD, DONE }

var step := Step.AIM
var _t := 0.0
var _alpha := 0.0
var _aimed := 0.0   # degrees the player has turned so far
var touch_mode := false
var allowed := false   # set by the HUD: only while the player is aiming
var _nudge_until := 0.0

func set_touch_mode(on: bool) -> void:
    touch_mode = on

## The player tried to aim with a finger in gyro mode: show the phone hint again for a moment.
func nudge() -> void:
    _nudge_until = _t + 3.0

const GOLD := Color(1.0, 0.8, 0.35)
const WHITE := Color(1, 1, 1)

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

## Called by the HUD each frame with what the player is doing.
func observe(aim_change: float, power: float, fired: bool) -> void:
    if step == Step.AIM:
        _aimed += absf(aim_change)
        if _aimed > 12.0 or power > 0.05 or fired:
            step = Step.LOAD
            _t = 0.0
    elif step == Step.LOAD and fired:
        step = Step.DONE

func _process(delta: float) -> void:
    _t += delta
    var want := 0.0 if step == Step.DONE else 1.0
    if _t < _nudge_until:
        want = 1.0
    _alpha = move_toward(_alpha, want, delta * 2.0)
    visible = allowed and _alpha > 0.01
    queue_redraw()

func _draw() -> void:
    if step == Step.AIM or _t < _nudge_until:
        _draw_aim(Vector2(size.x / 2.0, size.y * 0.62))
    if step == Step.LOAD and _t >= _nudge_until:
        _draw_load(Vector2(size.x * 0.68, size.y * 0.5))

func _c(col: Color, a: float = 1.0) -> Color:
    return Color(col.r, col.g, col.b, col.a * a * _alpha)

## Point the phone: an upright phone held in front of you swings left and right like a camera
## panning, with a beam from its top showing where it looks, and straight arrows either side.
## In touch mode: a finger swiping sideways instead.
func _draw_aim(c: Vector2) -> void:
    var swing := sin(_t * 1.8)
    draw_circle(c, 230, _c(Color(0, 0, 0), 0.3))
    draw_arc(c, 230, 0, TAU, 64, _c(GOLD, 0.35), 3.0)
    # Straight arrows left and right.
    for side: float in [-1.0, 1.0]:
        var tip := c + Vector2(side * 200, 40)
        draw_line(c + Vector2(side * 120, 40), tip - Vector2(side * 20, 0), _c(GOLD, 0.95), 10.0)
        draw_colored_polygon(PackedVector2Array([tip + Vector2(side * 14, 0), tip - Vector2(side * 22, 24), tip - Vector2(side * 22, -24)]), _c(GOLD, 0.95))
    if touch_mode:
        # A finger swiping sideways across a dotted line.
        for k in 9:
            draw_circle(c + Vector2(-160 + k * 40, 120), 5, _c(WHITE, 0.35))
        var fp := c + Vector2(swing * 140, 90)
        _round_rect(Rect2(fp.x - 22, fp.y - 10, 44, 120), 22, _c(WHITE, 0.95))
        _round_rect(Rect2(fp.x - 22, fp.y + 60, 110, 150), 40, _c(WHITE, 0.95))
        draw_arc(fp + Vector2(0, 4), 30, 0, TAU, 32, _c(WHITE, 0.5), 3.0)
        return
    # The phone slides and turns a little, as if pointed at different parts of the fort.
    var w := 100.0
    var h := 180.0
    var pos := c + Vector2(swing * 70, 70)
    var ang := swing * 0.18
    # View beam from the top of the phone to a target mark above.
    var look := c + Vector2(swing * 170, -150)
    var top := pos + Vector2(0, -h / 2).rotated(ang)
    draw_colored_polygon(PackedVector2Array([top, look + Vector2(-46, 0), look + Vector2(46, 0)]), _c(GOLD, 0.22))
    draw_arc(look, 26, 0, TAU, 32, _c(GOLD, 0.95), 5.0)
    draw_circle(look, 6, _c(GOLD))
    draw_set_transform_matrix(Transform2D(ang, pos))
    _round_rect(Rect2(-w / 2 - 8, -h / 2 - 8, w + 16, h + 16), 26, _c(WHITE, 0.95))
    _round_rect(Rect2(-w / 2, -h / 2, w, h), 20, _c(Color(0.15, 0.25, 0.4), 0.95))
    draw_circle(Vector2(0, h / 2 - 16), 7, _c(WHITE, 0.5))
    draw_set_transform_matrix(Transform2D.IDENTITY)
    # Two hands holding it.
    for side: float in [-1.0, 1.0]:
        _round_rect(Rect2(pos.x + side * (w / 2 + 6) - 18, pos.y - 10, 36, 110), 18, _c(Color(0.95, 0.8, 0.7), 0.9))

## A finger that presses, pulls down and lifts, with a power bar filling beside it.
func _draw_load(at: Vector2) -> void:
    var cycle := fmod(_t, 2.4)
    var press := smoothstep(0.0, 0.25, cycle)
    var pull := smoothstep(0.3, 1.5, cycle)
    var lift := smoothstep(1.8, 2.1, cycle)
    var travel := 360.0
    var y := at.y + pull * travel
    var x := at.x
    var a := (1.0 - lift)
    # Track and fill.
    _round_rect(Rect2(x - 70, at.y - 20, 28, travel + 40), 14, _c(WHITE, 0.2 * a + 0.1))
    var fill := pull * travel
    _round_rect(Rect2(x - 70, at.y - 20, 28, fill + 20), 14, _c(Color(1.0, 0.55 + 0.3 * (1.0 - pull), 0.15), 0.9 * a))
    # Dotted path the finger follows.
    for k in 7:
        var py := at.y + k * travel / 6.0
        draw_circle(Vector2(x + 40, py), 5, _c(WHITE, 0.35))
    # Touch ripple while pressing.
    if press > 0.0 and lift < 1.0:
        draw_arc(Vector2(x + 40, y), 30 + 20 * press, 0, TAU, 32, _c(WHITE, 0.6 * a), 4.0)
    # The hand: a rounded finger and palm.
    var hp := Vector2(x + 40, y - 8 * (1.0 - press) - 30 * lift)
    _round_rect(Rect2(hp.x - 22, hp.y - 10, 44, 120), 22, _c(WHITE, 0.95 * (a * 0.8 + 0.2)))
    _round_rect(Rect2(hp.x - 22, hp.y + 60, 110, 150), 40, _c(WHITE, 0.95 * (a * 0.8 + 0.2)))
    draw_circle(hp + Vector2(0, 4), 14, _c(Color(0.95, 0.8, 0.7), a * 0.8 + 0.2))
    # On release: a burst toward the fort.
    if lift > 0.0:
        var bc := Vector2(x - 56, at.y - 70)
        for k in 8:
            var ang := TAU * k / 8.0
            draw_line(bc + Vector2(cos(ang), sin(ang)) * (20 + 30 * lift), bc + Vector2(cos(ang), sin(ang)) * (40 + 50 * lift), _c(GOLD, 1.0 - lift), 6.0)

func _round_rect(r: Rect2, radius: float, col: Color) -> void:
    var sb := StyleBoxFlat.new()
    sb.bg_color = col
    sb.set_corner_radius_all(int(radius))
    sb.anti_aliasing = true
    draw_style_box(sb, r)
