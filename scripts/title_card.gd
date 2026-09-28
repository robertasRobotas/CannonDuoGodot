## The end of the first battle: sea fog rolls in over the wreck with a rising wind, and the
## game's crest and title rise out of it. Then `done` and the result panel follows.
class_name TitleCard
extends Control

signal done

const HOLD := 4.2

var _t := 0.0
var _wind: AudioStreamPlayer
var _puffs: Array = []   # [x, y, radius, speed, phase]
var _font: Font
var _smoke: Texture2D = load("res://assets/particles/smoke_04.png")

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _font = ThemeDB.fallback_font
    var rng := RandomNumberGenerator.new()
    rng.seed = 11
    for i in 26:
        _puffs.append([rng.randf_range(-300, 1500), rng.randf_range(300, 2400), rng.randf_range(260, 520), rng.randf_range(40, 110), rng.randf() * TAU])
    _wind = AudioStreamPlayer.new()
    _wind.stream = load("res://assets/audio/wind_loop.wav")
    _wind.volume_db = -40.0
    add_child(_wind)
    _wind.play()
    create_tween().tween_property(_wind, "volume_db", -4.0, 1.5)

func _process(delta: float) -> void:
    _t += delta
    queue_redraw()
    if _t > HOLD and _wind:
        var w := _wind
        _wind = null
        var tw := create_tween()
        tw.tween_property(w, "volume_db", -40.0, 1.0)
        tw.tween_callback(w.queue_free)
        done.emit()

func _gui_input(ev: InputEvent) -> void:
    if (ev is InputEventScreenTouch or ev is InputEventMouseButton) and ev.pressed and _t > 1.5:
        _t = HOLD + 0.01

func _draw() -> void:
    var fog := smoothstep(0.0, 1.8, _t)
    # Fog: a grey veil plus drifting banks.
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.62, 0.66, 0.7, 0.55 * fog))
    for p: Array in _puffs:
        var x: float = fmod(float(p[0]) + _t * float(p[3]), size.x + 800.0) - 400.0
        var y: float = float(p[1]) + sin(_t * 0.5 + float(p[4])) * 30.0
        var r: float = float(p[2]) * 1.6
        draw_texture_rect(_smoke, Rect2(x - r, y - r, r * 2.0, r * 2.0), false, Color(0.8, 0.83, 0.86, 0.35 * fog))
    # The crest rises out of the fog.
    var k := smoothstep(0.9, 2.2, _t)
    if k <= 0.0:
        return
    var c := Vector2(size.x / 2.0, size.y * 0.4 + (1.0 - k) * 60.0)
    _crest(c, 190.0, k)
    var title := "CANNON DUO"
    var fs := 110
    var tw := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
    var ty := c.y + 290.0
    draw_string_outline(_font, Vector2(c.x - tw / 2.0, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Color(0.18, 0.12, 0.05, 0.8 * k))
    draw_string(_font, Vector2(c.x - tw / 2.0, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.84, 0.4, k))
    var sub := "KINGDOM OF VALORA"
    var sw := _font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 40).x
    draw_string(_font, Vector2(c.x - sw / 2.0, ty + 70), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, 0.85 * k))

## A shield with two crossed cannons under a crown.
func _crest(c: Vector2, r: float, a: float) -> void:
    var gold := Color(1.0, 0.8, 0.3, a)
    var blue := Color(0.1, 0.22, 0.55, a)
    var shield := PackedVector2Array([c + Vector2(-r, -r * 0.8), c + Vector2(r, -r * 0.8), c + Vector2(r, r * 0.2),
        c + Vector2(r * 0.55, r * 0.75), c + Vector2(0, r), c + Vector2(-r * 0.55, r * 0.75), c + Vector2(-r, r * 0.2)])
    var outer := PackedVector2Array()
    for p in shield:
        outer.append(c + (p - c) * 1.08)
    draw_colored_polygon(outer, gold)
    draw_colored_polygon(shield, blue)
    # Crossed cannons.
    for side: float in [-1.0, 1.0]:
        var dir := Vector2(side * 0.72, -0.7).normalized()
        var from := c + Vector2(-side * r * 0.55, r * 0.45)
        var to := from + dir * r * 1.45
        var n := Vector2(-dir.y, dir.x)
        draw_colored_polygon(PackedVector2Array([from + n * 26, to + n * 16, to - n * 16, from - n * 26]), Color(0.12, 0.12, 0.14, a))
        draw_circle(from, 30, Color(0.12, 0.12, 0.14, a))
        draw_circle(to, 12, gold)
    # Crown.
    var cy := c.y - r * 0.8 - 20
    var crown := PackedVector2Array([Vector2(c.x - 90, cy + 40), Vector2(c.x - 90, cy - 30), Vector2(c.x - 45, cy + 5), Vector2(c.x, cy - 55),
        Vector2(c.x + 45, cy + 5), Vector2(c.x + 90, cy - 30), Vector2(c.x + 90, cy + 40)])
    draw_colored_polygon(crown, gold)
    for x: float in [-90.0, 0.0, 90.0]:
        draw_circle(Vector2(c.x + x, cy + (-55.0 if x == 0.0 else -30.0)), 11, Color(0.85, 0.1, 0.15, a))
