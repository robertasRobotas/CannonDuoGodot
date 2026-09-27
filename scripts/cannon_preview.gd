## A side view of the ship's cannon for the workshop, drawn with shapes: carriage, wheels, and
## a barrel in the colour of its rank, gently rocking.
class_name CannonPreview
extends Control

var barrel_color := Color(0.55, 0.38, 0.28)
var _t := 0.0

func _process(delta: float) -> void:
    _t += delta
    queue_redraw()

func _draw() -> void:
    var c := Vector2(size.x / 2.0, size.y * 0.62)
    var wood := Color(0.45, 0.28, 0.14)
    draw_colored_polygon(PackedVector2Array([c + Vector2(-150, 10), c + Vector2(90, 10), c + Vector2(110, 50), c + Vector2(-170, 50)]), wood)
    for x: float in [-110.0, 60.0]:
        draw_circle(c + Vector2(x, 58), 34, wood.darkened(0.3))
        draw_circle(c + Vector2(x, 58), 12, Color(0.2, 0.2, 0.22))
    var a := -0.25 + sin(_t * 1.2) * 0.03
    var dir := Vector2(cos(a), sin(a))
    var n := Vector2(-dir.y, dir.x)
    var b0 := c + Vector2(-120, -5)
    var pts := PackedVector2Array([b0 + n * 36, b0 + dir * 280 + n * 22, b0 + dir * 280 - n * 22, b0 - n * 36])
    draw_colored_polygon(pts, barrel_color)
    draw_colored_polygon(PackedVector2Array([b0 + n * 30 + dir * 20, b0 + dir * 270 + n * 18, b0 + dir * 270 + n * 8, b0 + n * 14 + dir * 20]), barrel_color.lightened(0.35))
    draw_circle(b0, 38, barrel_color.darkened(0.15))
    for k in 3:
        var p := b0 + dir * (60 + k * 85)
        draw_line(p + n * (34 - k * 5), p - n * (34 - k * 5), barrel_color.darkened(0.3), 8)
    draw_circle(b0 + dir * 280, 22, Color(0.1, 0.1, 0.12))
