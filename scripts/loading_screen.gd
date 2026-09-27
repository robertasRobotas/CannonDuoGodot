## Full screen loading card: dusk sky over layered waves, the level badge, castle name,
## place and weather chips, a pirate tip and a progress bar. Used from the moment a castle is
## tapped until the fly-in starts, so there is never a gap.
class_name LoadingScreen
extends Control

const TIPS := [
    "Pirates took these islands from the Crown. Take them back.",
    "Every pirate that falls drops his stolen doubloons.",
    "Red powder barrels go up in a chain. Find the first one.",
    "Pull down further for a stronger shot.",
    "Tilt the phone to aim. Tap the target button to recentre.",
    "Pinch to zoom out and see your ship.",
    "Stone shrugs off iron. Hit the wood beneath it.",
    "In a storm the ship rolls. Fire as it rises.",
]

var progress := 0.0
var _bar: ColorRect
var _bar_w := 560.0
var _t := 0.0
var _sky: Texture2D

func build(id: int, name: String, subtitle: String, place: String, weather: String, tip_text: String = "") -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    var g := Gradient.new()
    g.set_color(0, Color(0.07, 0.10, 0.20))
    g.add_point(0.62, Color(0.30, 0.24, 0.38))
    g.set_color(g.get_point_count() - 1, Color(0.06, 0.16, 0.24))
    var gt := GradientTexture2D.new()
    gt.gradient = g
    gt.fill_from = Vector2(0, 0)
    gt.fill_to = Vector2(0, 1)
    _sky = gt

    var col := VBoxContainer.new()
    col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    col.alignment = BoxContainer.ALIGNMENT_CENTER
    col.add_theme_constant_override("separation", 26)
    col.offset_top = -260
    col.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(col)

    var badge_row := CenterContainer.new()
    var badge := PanelContainer.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(1.0, 0.58, 0.18)
    sb.set_corner_radius_all(90)
    sb.border_color = Color(1.0, 0.82, 0.55)
    sb.set_border_width_all(6)
    badge.add_theme_stylebox_override("panel", sb)
    badge.custom_minimum_size = Vector2(180, 180)
    var num := _label(str(id), 88, Color.WHITE)
    num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    badge.add_child(num)
    badge_row.add_child(badge)
    col.add_child(badge_row)

    col.add_child(_label(name, 96, Color.WHITE, 6))
    if subtitle != "":
        col.add_child(_label(subtitle, 40, Color(1, 1, 1, 0.75)))
    var chips := HBoxContainer.new()
    chips.alignment = BoxContainer.ALIGNMENT_CENTER
    chips.add_theme_constant_override("separation", 20)
    chips.add_child(_chip(place))
    chips.add_child(_chip(weather))
    col.add_child(chips)

    var gap := Control.new()
    gap.custom_minimum_size = Vector2(0, 60)
    col.add_child(gap)
    var bar_row := CenterContainer.new()
    var track := PanelContainer.new()
    var ts := StyleBoxFlat.new()
    ts.bg_color = Color(1, 1, 1, 0.14)
    ts.set_corner_radius_all(12)
    track.add_theme_stylebox_override("panel", ts)
    track.custom_minimum_size = Vector2(_bar_w, 22)
    _bar = ColorRect.new()
    _bar.color = Color(1.0, 0.66, 0.26)
    _bar.size = Vector2(20, 22)
    track.add_child(_bar)
    bar_row.add_child(track)
    col.add_child(bar_row)
    col.add_child(_label("Loading the castle…", 30, Color(1, 1, 1, 0.55)))

    # Old Tomas's advice for this island, with his portrait.
    var said: String = tip_text if tip_text != "" else TIPS[randi() % TIPS.size()]
    var face := Portrait.new("fisher", 170.0)
    face.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    face.position = Vector2(70, 2556 - 470)
    add_child(face)
    var who := _label("Old Tomas", 32, Color(1.0, 0.84, 0.4))
    who.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    who.position = Vector2(270, 2556 - 470)
    add_child(who)
    var tip := _label("\"" + said + "\"", 36, Color(1, 1, 1, 0.9))
    tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    tip.position = Vector2(270, 2556 - 425)
    tip.size = Vector2(840, 160)
    add_child(tip)

func _label(text: String, size: int, color: Color, outline: int = 0) -> Label:
    var l := Label.new()
    l.text = text
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    if outline > 0:
        l.add_theme_constant_override("outline_size", outline)
        l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

func _chip(text: String) -> PanelContainer:
    var p := PanelContainer.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(1, 1, 1, 0.12)
    sb.set_corner_radius_all(30)
    sb.content_margin_left = 28
    sb.content_margin_right = 28
    sb.content_margin_top = 10
    sb.content_margin_bottom = 10
    p.add_theme_stylebox_override("panel", sb)
    p.add_child(_label(text, 32, Color(1, 1, 1, 0.9)))
    return p

func _process(delta: float) -> void:
    _t += delta
    if _bar:
        _bar.size.x = maxf(20.0, _bar_w * clampf(progress, 0.0, 1.0))
    queue_redraw()

## The sky gradient, then three layers of rolling waves along the bottom.
func _draw() -> void:
    var w := size.x
    var h := size.y
    if _sky:
        draw_texture_rect(_sky, Rect2(0, 0, w, h), false)
    var layers := [[0.80, Color(0.10, 0.24, 0.36, 0.9), 38.0, 0.8], [0.86, Color(0.08, 0.20, 0.30, 0.95), 30.0, 1.2], [0.92, Color(0.05, 0.14, 0.22, 1.0), 24.0, 1.7]]
    for layer in layers:
        var base: float = h * float(layer[0])
        var amp: float = layer[2]
        var speed: float = layer[3]
        var pts := PackedVector2Array()
        var steps := 40
        for i in steps + 1:
            var x := w * float(i) / float(steps)
            pts.append(Vector2(x, base + sin(x * 0.012 + _t * speed) * amp + sin(x * 0.027 - _t * speed * 0.7) * amp * 0.4))
        pts.append(Vector2(w, h))
        pts.append(Vector2(0, h))
        draw_colored_polygon(pts, layer[1])
