## A painted medallion portrait of a character, drawn with shapes (no image files): a coloured
## backdrop, shoulders, head and each character's features, in a gold frame.
class_name Portrait
extends Control

const NAMES := {
    "king": "King Aldric", "fisher": "Old Tomas", "mira": "Mira", "mate": "Pip, first mate",
    "grimhorn": "Grimhorn", "vesk": "Lord Vesk", "olaf": "Olaf", "bottle": "A message in a bottle",
    "bjorn": "Red Bjorn", "captain": "The Captain",
}

var who := "mate"
var talking := 0.0   # 0..1 mouth open

func _init(character: String = "mate", size_px: float = 220.0) -> void:
    who = character
    custom_minimum_size = Vector2(size_px, size_px)
    size = custom_minimum_size
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_d: float) -> void:
    queue_redraw()

func _draw() -> void:
    var s := size.x
    var c := Vector2(s / 2.0, s / 2.0)
    var r := s * 0.5
    var bg: Color = {"king": Color(0.36, 0.18, 0.42), "fisher": Color(0.28, 0.46, 0.58), "mira": Color(0.86, 0.62, 0.42),
        "mate": Color(0.30, 0.58, 0.62), "grimhorn": Color(0.32, 0.08, 0.06), "vesk": Color(0.22, 0.2, 0.3),
        "olaf": Color(0.4, 0.44, 0.5), "bottle": Color(0.2, 0.42, 0.58), "bjorn": Color(0.42, 0.12, 0.06),
        "captain": Color(0.14, 0.24, 0.4)}.get(who, Color(0.3, 0.3, 0.3))
    # Frame and backdrop with a soft light.
    draw_circle(c, r, Color(0.78, 0.6, 0.24))
    draw_circle(c, r * 0.93, Color(0.42, 0.3, 0.12))
    draw_circle(c, r * 0.88, bg)
    draw_circle(c + Vector2(-r * 0.2, -r * 0.25), r * 0.5, Color(1, 1, 1, 0.08))
    if who == "bottle":
        _bottle(c, r)
        _ring(c, r)
        return
    var skin := Color(0.93, 0.72, 0.58)
    if who == "grimhorn" or who == "bjorn":
        skin = Color(0.84, 0.6, 0.48)
    var coat: Color = {"king": Color(0.7, 0.08, 0.1), "fisher": Color(0.95, 0.78, 0.15), "mira": Color(0.25, 0.5, 0.35),
        "mate": Color(0.95, 0.95, 0.95), "grimhorn": Color(0.15, 0.1, 0.1), "vesk": Color(0.35, 0.18, 0.45),
        "olaf": Color(0.45, 0.38, 0.3), "bjorn": Color(0.5, 0.12, 0.08), "captain": Color(0.1, 0.16, 0.34)}.get(who, Color.GRAY)
    # Shoulders.
    _ellipse(c + Vector2(0, r * 0.62), Vector2(r * 0.62, r * 0.28), coat)
    if who == "mate":
        for k in 3:
            draw_rect(Rect2(c.x - r * 0.6, c.y + r * (0.48 + k * 0.14), r * 1.2, r * 0.06), Color(0.2, 0.3, 0.7))
    if who == "king":
        _ellipse(c + Vector2(0, r * 0.55), Vector2(r * 0.55, r * 0.14), Color(0.97, 0.95, 0.9))
    if who == "mira":
        _ellipse(c + Vector2(0, r * 0.5), Vector2(r * 0.34, r * 0.1), Color(0.85, 0.15, 0.15))
    # Hair behind the head.
    if who == "mira":
        _ellipse(c + Vector2(0, -r * 0.05), Vector2(r * 0.46, r * 0.55), Color(0.25, 0.14, 0.08))
        _ellipse(c + Vector2(r * 0.38, r * 0.35), Vector2(r * 0.1, r * 0.3), Color(0.25, 0.14, 0.08))
    # Head.
    _ellipse(c + Vector2(0, -r * 0.08), Vector2(r * 0.36, r * 0.42), skin)
    # Beards.
    var beard: Color = {"king": Color(0.95, 0.95, 0.95), "fisher": Color(0.8, 0.8, 0.82), "grimhorn": Color(0.1, 0.08, 0.08),
        "olaf": Color(0.95, 0.8, 0.4), "bjorn": Color(0.8, 0.3, 0.1), "vesk": Color(0.12, 0.1, 0.12),
        "captain": Color(0.55, 0.55, 0.58)}.get(who, Color(0, 0, 0, 0))
    if beard.a > 0.0:
        if who == "vesk":
            # A thin pointed moustache.
            draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.3, r * 0.02), c + Vector2(0, r * 0.08), c + Vector2(r * 0.3, r * 0.02), c + Vector2(0, r * 0.12)]), beard)
        else:
            draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.36, -r * 0.02), c + Vector2(r * 0.36, -r * 0.02), c + Vector2(r * 0.22, r * 0.42), c + Vector2(0, r * 0.52), c + Vector2(-r * 0.22, r * 0.42)]), beard)
    # Eyes and brows.
    var angry := who in ["grimhorn", "bjorn", "vesk"]
    for side: float in [-1.0, 1.0]:
        var e := c + Vector2(side * r * 0.14, -r * 0.14)
        if who == "grimhorn" and side < 0.0:
            draw_circle(e, r * 0.08, Color(0.05, 0.05, 0.05))   # eyepatch
            draw_line(e + Vector2(-r * 0.3, -r * 0.1), e + Vector2(r * 0.4, -r * 0.2), Color(0.05, 0.05, 0.05), r * 0.03)
        else:
            draw_circle(e, r * 0.06, Color.WHITE)
            draw_circle(e + Vector2(0, r * 0.01), r * 0.035, Color(0.12, 0.08, 0.05) if not angry else Color(0.7, 0.1, 0.05))
        var tilt := side * (0.06 if angry else -0.03)
        draw_line(e + Vector2(-r * 0.08, -r * 0.1 - tilt * r), e + Vector2(r * 0.08, -r * 0.1 + tilt * r), Color(0.2, 0.12, 0.08), r * 0.035)
    # Nose and mouth.
    var nose := 0.1 if who == "mate" else 0.06
    draw_circle(c + Vector2(0, -r * 0.02), r * nose, skin.darkened(0.12))
    var m := c + Vector2(0, r * (0.16 if beard.a == 0.0 else 0.2))
    var open := talking * r * 0.06
    if who == "mate" or who == "mira":
        draw_arc(m, r * 0.1, 0.2, PI - 0.2, 10, Color(0.35, 0.1, 0.08), r * 0.03)   # smile
    elif angry:
        draw_arc(m + Vector2(0, r * 0.08), r * 0.1, PI + 0.3, TAU - 0.3, 10, Color(0.1, 0.05, 0.05), r * 0.03)
    else:
        draw_line(m + Vector2(-r * 0.08, 0), m + Vector2(r * 0.08, 0), Color(0.35, 0.1, 0.08), r * 0.03)
    if open > 0.5:
        _ellipse(m + Vector2(0, r * 0.03), Vector2(r * 0.05, open), Color(0.3, 0.05, 0.05))
    # Hats and helmets.
    match who:
        "king":
            var y := c.y - r * 0.5
            draw_colored_polygon(PackedVector2Array([Vector2(c.x - r * 0.32, y + r * 0.08), Vector2(c.x - r * 0.32, y - r * 0.18), Vector2(c.x - r * 0.16, y - r * 0.04), Vector2(c.x, y - r * 0.24), Vector2(c.x + r * 0.16, y - r * 0.04), Vector2(c.x + r * 0.32, y - r * 0.18), Vector2(c.x + r * 0.32, y + r * 0.08)]), Color(0.95, 0.76, 0.2))
            draw_circle(Vector2(c.x, y - r * 0.02), r * 0.04, Color(0.8, 0.1, 0.15))
        "fisher":
            _ellipse(c + Vector2(0, -r * 0.42), Vector2(r * 0.5, r * 0.12), Color(0.95, 0.8, 0.15))
            _ellipse(c + Vector2(0, -r * 0.52), Vector2(r * 0.32, r * 0.16), Color(0.95, 0.8, 0.15))
        "mate":
            _ellipse(c + Vector2(0, -r * 0.42), Vector2(r * 0.4, r * 0.16), Color(0.2, 0.35, 0.8))
            draw_circle(c + Vector2(r * 0.38, -r * 0.38), r * 0.07, Color(0.2, 0.35, 0.8))
        "mira":
            _ellipse(c + Vector2(0, -r * 0.44), Vector2(r * 0.36, r * 0.1), Color(0.85, 0.15, 0.15))
        "vesk":
            draw_rect(Rect2(c.x - r * 0.3, c.y - r * 0.78, r * 0.6, r * 0.3), Color(0.1, 0.08, 0.12))
            _ellipse(c + Vector2(0, -r * 0.47), Vector2(r * 0.46, r * 0.07), Color(0.1, 0.08, 0.12))
        "captain":
            # A navy bicorne with gold trim and a cockade, plus gold epaulettes.
            var navy := Color(0.08, 0.13, 0.26)
            draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.52, -r * 0.4), c + Vector2(-r * 0.3, -r * 0.72),
                c + Vector2(0, -r * 0.8), c + Vector2(r * 0.3, -r * 0.72), c + Vector2(r * 0.52, -r * 0.4),
                c + Vector2(r * 0.3, -r * 0.46), c + Vector2(0, -r * 0.5), c + Vector2(-r * 0.3, -r * 0.46)]), navy)
            draw_arc(c + Vector2(0, -r * 0.44), r * 0.5, PI + 0.5, TAU - 0.5, 20, Color(0.95, 0.8, 0.36), r * 0.035)
            draw_circle(c + Vector2(r * 0.3, -r * 0.6), r * 0.065, Color(0.95, 0.8, 0.36))
            for side: float in [-1.0, 1.0]:
                draw_rect(Rect2(c.x + side * r * 0.62 - r * 0.14, c.y + r * 0.42, r * 0.28, r * 0.1), Color(0.95, 0.8, 0.36))
        "grimhorn", "olaf", "bjorn":
            var steel := Color(0.6, 0.62, 0.66) if who != "olaf" else Color(0.5, 0.48, 0.46)
            _ellipse(c + Vector2(0, -r * 0.36), Vector2(r * 0.4, r * 0.26), steel)
            draw_rect(Rect2(c.x - r * 0.4, c.y - r * 0.32, r * 0.8, r * 0.06), steel.darkened(0.2))
            draw_rect(Rect2(c.x - r * 0.03, c.y - r * 0.3, r * 0.06, r * 0.26), steel.darkened(0.2))
            var hl := 1.4 if who == "grimhorn" else 1.0
            for side: float in [-1.0, 1.0]:
                var b := c + Vector2(side * r * 0.36, -r * 0.4)
                draw_colored_polygon(PackedVector2Array([b, b + Vector2(side * r * 0.1, r * 0.08), b + Vector2(side * r * 0.3 * hl, -r * 0.28 * hl)]), Color(0.95, 0.9, 0.76))
    _ring(c, r)

func _ring(c: Vector2, r: float) -> void:
    draw_arc(c, r * 0.9, 0, TAU, 48, Color(0.95, 0.8, 0.36), r * 0.04)

func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
    var pts := PackedVector2Array()
    for i in 28:
        var a := TAU * i / 28.0
        pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
    draw_colored_polygon(pts, color)

func _bottle(c: Vector2, r: float) -> void:
    var glass := Color(0.45, 0.75, 0.55, 0.85)
    _ellipse(c + Vector2(0, r * 0.1), Vector2(r * 0.22, r * 0.42), glass)
    draw_rect(Rect2(c.x - r * 0.07, c.y - r * 0.55, r * 0.14, r * 0.3), glass)
    draw_rect(Rect2(c.x - r * 0.08, c.y - r * 0.62, r * 0.16, r * 0.1), Color(0.55, 0.38, 0.2))
    draw_rect(Rect2(c.x - r * 0.12, c.y - r * 0.12, r * 0.24, r * 0.4), Color(0.95, 0.9, 0.75))
