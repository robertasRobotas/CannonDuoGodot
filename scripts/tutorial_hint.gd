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
    _alpha = move_toward(_alpha, want, delta * 2.0)
    visible = _alpha > 0.01
    queue_redraw()

func _draw() -> void:
    if step == Step.AIM or (step == Step.LOAD and _t < 0.5 and _alpha < 1.0):
        _draw_aim(Vector2(size.x / 2.0, size.y * 0.62))
    if step == Step.LOAD:
        _draw_load(Vector2(size.x * 0.68, size.y * 0.5))

func _c(col: Color, a: float = 1.0) -> Color:
    return Color(col.r, col.g, col.b, col.a * a * _alpha)

## A phone rocking side to side with a curved double arrow above it.
func _draw_aim(c: Vector2) -> void:
    var tilt := sin(_t * 2.2) * 0.35
    # Glow disc behind.
    draw_circle(c, 210, _c(Color(0, 0, 0), 0.28))
    draw_arc(c, 210, 0, TAU, 64, _c(GOLD, 0.35), 3.0)
    # Curved arrow over the top, both ways.
    var r := 170.0
    var a0 := PI + 0.55
    var a1 := TAU - 0.55
    draw_arc(c + Vector2(0, 40), r, a0, a1, 40, _c(GOLD, 0.95), 10.0, true)
    for end: float in [a0, a1]:
        var tip := c + Vector2(0, 40) + Vector2(cos(end), sin(end)) * r
        var tangent := Vector2(-sin(end), cos(end)) * (1.0 if end == a1 else -1.0)
        var n := Vector2(tangent.y, -tangent.x)
        draw_colored_polygon(PackedVector2Array([tip + tangent * 34, tip - n * 22, tip + n * 22]), _c(GOLD, 0.95))
    # The phone.
    var w := 110.0
    var h := 200.0
    var xf := Transform2D(tilt, c + Vector2(0, 50))
    draw_set_transform_matrix(xf)
    _round_rect(Rect2(-w / 2 - 8, -h / 2 - 8, w + 16, h + 16), 26, _c(WHITE, 0.95))
    _round_rect(Rect2(-w / 2, -h / 2, w, h), 20, _c(Color(0.15, 0.25, 0.4), 0.95))
    # A little cannon on the screen that turns with the phone.
    draw_circle(Vector2(0, 40), 18, _c(GOLD))
    draw_line(Vector2(0, 40), Vector2(0, 40) + Vector2(0, -56).rotated(-tilt * 1.6), _c(GOLD), 14.0)
    draw_circle(Vector2(0, -h / 2 + 14), 5, _c(WHITE, 0.6))
    draw_set_transform_matrix(Transform2D.IDENTITY)

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
