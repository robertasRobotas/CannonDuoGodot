## The sea chart: castles on islands along a dotted route, stars under each, a skull on boss
## islands, your ship at the next castle. Header with gold, stars, the daily castle and the shop.
class_name MapScreen
extends Control

signal play(id: int)
signal daily
signal shop
signal back

const ROW := 330.0
const TOP := 470.0   # below the header
const BIOME_COLORS := {"tropic": Color(0.40, 0.66, 0.34), "meadow": Color(0.52, 0.72, 0.38), "harbor": Color(0.62, 0.58, 0.52),
    "highlands": Color(0.30, 0.52, 0.42), "badlands": Color(0.78, 0.46, 0.30), "volcano": Color(0.35, 0.28, 0.28), "opensea": Color(0.55, 0.52, 0.48)}

var _infos: Array = []
var _stars: Dictionary = {}
var _next := 1
var _content: Control
var _scroll: ScrollContainer
var _t := 0.0

func build(infos: Array, stars: Dictionary, next_id: int, gold: int, total_stars: int, max_stars: int, daily_note: String) -> void:
    _infos = infos
    _stars = stars
    _next = next_id
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _scroll = ScrollContainer.new()
    _scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _scroll.scroll_deadzone = 24
    add_child(_scroll)
    _content = Control.new()
    # Only the way you have sailed and the next castle are charted; beyond is fog.
    _content.custom_minimum_size = Vector2(1179, maxf(2700.0, _node_pos(_visible_count() - 1).y + 620))
    _content.mouse_filter = Control.MOUSE_FILTER_PASS
    _content.draw.connect(_draw_chart)
    _scroll.add_child(_content)
    for i in _visible_count():
        _content.add_child(_node_button(i))
    _header(gold, total_stars, max_stars, daily_note)
    _scroll_to.call_deferred(next_id)

func _visible_count() -> int:
    return mini(_next, _infos.size())

func _node_pos(i: int) -> Vector2:
    # Winding route down the chart.
    return Vector2(589 + sin(i * 1.15) * 300.0, TOP + 180 + i * ROW)

func _node_button(i: int) -> Control:
    var info: Dictionary = _infos[i]
    var id := i + 1
    var locked := id > _next
    var boss := bool(info.get("boss", false))
    var r := 138.0 if boss else 74.0
    var b := Button.new()
    b.flat = true
    b.focus_mode = Control.FOCUS_NONE
    b.position = _node_pos(i) - Vector2(r, r)
    b.size = Vector2(r * 2, r * 2)
    b.disabled = locked
    # PASS lets a drag that starts on an island still scroll the chart.
    b.mouse_filter = Control.MOUSE_FILTER_PASS
    b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
    b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
    b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
    b.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
    b.pressed.connect(func(): play.emit(id))
    # Name plate under the node.
    var name := Label.new()
    name.text = info.name
    name.add_theme_font_size_override("font_size", 34)
    name.add_theme_color_override("font_color", Color(1, 1, 1, 0.45 if locked else 0.95))
    name.add_theme_constant_override("outline_size", 8)
    name.add_theme_color_override("font_outline_color", Color(0.04, 0.12, 0.2, 0.8))
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name.position = Vector2(-200 + r, r * 2 + 44)
    name.size = Vector2(400, 50)
    name.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(name)
    return b

func _header(gold: int, total_stars: int, max_stars: int, daily_note: String) -> void:
    var bar := PanelContainer.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.05, 0.10, 0.18, 0.88)
    sb.content_margin_left = 40
    sb.content_margin_right = 40
    sb.content_margin_top = 110
    sb.content_margin_bottom = 26
    bar.add_theme_stylebox_override("panel", sb)
    bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 18)
    var row := HBoxContainer.new()
    var title := _text("Valora Islands", 64, Color.WHITE)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(title)
    row.add_child(_text("● %d   ★ %d/%d" % [gold, total_stars, max_stars], 38, Color(1.0, 0.84, 0.36)))
    col.add_child(row)
    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 16)
    buttons.add_child(_pill("‹ Back", func(): back.emit(), Color(1, 1, 1, 0.14)))
    buttons.add_child(_pill("Daily castle", func(): daily.emit(), Color(0.20, 0.55, 0.85)))
    buttons.add_child(_pill("Workshop", func(): shop.emit(), Color(1.0, 0.58, 0.18)))
    col.add_child(buttons)
    if daily_note != "":
        col.add_child(_text(daily_note, 28, Color(1, 1, 1, 0.65)))
    bar.add_child(col)
    add_child(bar)

func _text(t: String, size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = t
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return l

func _pill(t: String, cb: Callable, color: Color) -> Button:
    var b := Button.new()
    b.text = t
    b.add_theme_font_size_override("font_size", 34)
    b.custom_minimum_size = Vector2(0, 96)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var sb := StyleBoxFlat.new()
    sb.bg_color = color
    sb.set_corner_radius_all(48)
    b.add_theme_stylebox_override("normal", sb)
    var sbh: StyleBoxFlat = sb.duplicate()
    sbh.bg_color = color.lightened(0.15)
    b.add_theme_stylebox_override("hover", sbh)
    b.add_theme_stylebox_override("pressed", sbh)
    b.add_theme_color_override("font_color", Color.WHITE)
    b.pressed.connect(cb)
    return b

func _scroll_to(id: int) -> void:
    _scroll.scroll_vertical = int(maxf(0.0, _node_pos(mini(id, _visible_count()) - 1).y - 1300.0))

func _process(delta: float) -> void:
    _t += delta
    if _content:
        _content.queue_redraw()

func _draw_chart() -> void:
    var c := _content
    var h := c.size.y
    # Sea.
    c.draw_rect(Rect2(0, 0, 1179, h), Color(0.07, 0.30, 0.46))
    for i in int(h / 90.0):
        var y := i * 90.0 + fmod(_t * 12.0, 90.0)
        for k in 5:
            var x := fmod(k * 260.0 + i * 131.0, 1179.0)
            c.draw_arc(Vector2(x, y), 22.0, PI * 1.1, PI * 1.9, 8, Color(1, 1, 1, 0.07), 3.0)
    # Route.
    var pts := PackedVector2Array()
    for i in _visible_count():
        pts.append(_node_pos(i))
    for i in pts.size() - 1:
        var a := pts[i]
        var b := pts[i + 1]
        var done := i + 2 <= _next
        var steps := 14
        for k in steps:
            if k % 2 == 1:
                continue
            var p0 := a.lerp(b, float(k) / steps) + Vector2(sin(float(k) / steps * PI) * 60.0, 0)
            var p1 := a.lerp(b, float(k + 1) / steps) + Vector2(sin(float(k + 1) / steps * PI) * 60.0, 0)
            c.draw_line(p0, p1, Color(1.0, 0.86, 0.5, 0.85) if done else Color(1, 1, 1, 0.3), 7.0)
    # Chapter title above the first island.
    var font0 := ThemeDB.fallback_font
    var ch := "Chapter 1  ·  The Valora Islands"
    var cw := font0.get_string_size(ch, HORIZONTAL_ALIGNMENT_CENTER, -1, 40).x
    c.draw_string(font0, Vector2(589 - cw / 2.0, TOP + 40), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1.0, 0.86, 0.5, 0.9))
    # The route runs on into the fog past the next castle.
    if _visible_count() < _infos.size() or _next > _infos.size():
        var last := pts[pts.size() - 1]
        for k in 6:
            var p0 := last + Vector2(sin(k * 0.6) * 40.0, 110.0 + k * 60.0)
            c.draw_line(p0, p0 + Vector2(0, 30), Color(1, 1, 1, 0.3 - k * 0.045), 7.0)
    # Islands and nodes.
    for i in _visible_count():
        var info: Dictionary = _infos[i]
        var p := pts[i]
        var id := i + 1
        var boss := bool(info.get("boss", false))
        var r := 138.0 if boss else 74.0
        var locked := id > _next
        var land: Color = BIOME_COLORS.get(info.biome, Color(0.4, 0.6, 0.35))
        # Island blob: sand rim and land, seeded by the level.
        var rng := RandomNumberGenerator.new()
        rng.seed = id * 977
        var blob := PackedVector2Array()
        var rim := PackedVector2Array()
        for k in 18:
            var ang := TAU * k / 18.0
            var rr := r * rng.randf_range(1.55, 1.95)
            blob.append(p + Vector2(cos(ang) * rr * 1.3, sin(ang) * rr * 0.8))
            rim.append(p + Vector2(cos(ang) * (rr + 14.0) * 1.3, sin(ang) * (rr + 14.0) * 0.8))
        if info.biome != "opensea":
            c.draw_colored_polygon(rim, Color(0.93, 0.84, 0.62, 0.9 if not locked else 0.4))
            c.draw_colored_polygon(blob, land if not locked else land.darkened(0.5))
        # Node disc.
        var fill := Color(1.0, 0.58, 0.18) if id == _next else (Color(0.16, 0.18, 0.24) if not locked else Color(0.2, 0.22, 0.26, 0.7))
        if boss and not locked:
            fill = Color(0.62, 0.12, 0.10) if id != _next else Color(0.86, 0.12, 0.10)   # a boss island is red, next or done
        if id == _next:
            var pulse := 1.0 + 0.08 * sin(_t * 4.0)
            c.draw_circle(p, r * 1.22 * pulse, Color(1.0, 0.4, 0.3, 0.35) if boss else Color(1.0, 0.8, 0.4, 0.35))
        c.draw_circle(p, r + 6.0, Color(1, 1, 1, 0.9 if not locked else 0.3))
        c.draw_circle(p, r, fill)
        var font := ThemeDB.fallback_font
        var label := ("☠" if boss else str(id)) if not locked else "🔒"
        var fs := 176 if boss else 56
        var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
        if boss and not locked:
            # A bolder skull: the glyph drawn as a thick white outline over itself.
            c.draw_string_outline(font, p + Vector2(-tw / 2.0, fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color.WHITE)
        c.draw_string(font, p + Vector2(-tw / 2.0, fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
        # Stars.
        if not locked:
            var got := int(_stars.get(str(id), 0))
            var st := "★".repeat(got) + "☆".repeat(3 - got)
            var sw := font.get_string_size(st, HORIZONTAL_ALIGNMENT_CENTER, -1, 40).x
            c.draw_string(font, p + Vector2(-sw / 2.0, r + 44), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1.0, 0.84, 0.3))
        # Your ship waits beside the next castle.
        if id == _next:
            var sp := p + Vector2(r * 2.1 * (1.0 if p.x < 589 else -1.0), -10 + sin(_t * 2.0) * 6.0)
            _draw_ship(c, sp)
    _draw_fog(c)

func _draw_fog(c: Control) -> void:
    var y0 := _node_pos(_visible_count() - 1).y + 200.0
    # A soft bank of fog: many thin bands easing in, with drifting wisps along its edge.
    var steps := 48
    var band := 9.0
    for k in steps:
        var t := float(k + 1) / steps
        c.draw_rect(Rect2(0, y0 + k * band, 1179, band + 1.0), Color(0.72, 0.78, 0.84, t * t * (3.0 - 2.0 * t) * 0.97))
    c.draw_rect(Rect2(0, y0 + steps * band, 1179, c.size.y - (y0 + steps * band)), Color(0.72, 0.78, 0.84, 0.97))
    for k in 9:
        var wx := fmod(k * 173.0 + _t * 14.0, 1400.0) - 110.0
        c.draw_circle(Vector2(wx, y0 + 30.0 + sin(k * 1.7) * 20.0), 70.0 + (k % 3) * 22.0, Color(0.78, 0.83, 0.88, 0.35))
    var font := ThemeDB.fallback_font
    var done := _next > _infos.size()
    var t := "Chapter 2  ·  The Frozen North" if done else "Uncharted waters"
    var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, 44).x
    c.draw_string(font, Vector2(589 - w / 2.0, y0 + 330), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(0.2, 0.28, 0.36, 0.85))
    if done:
        var t2 := "The ice fleet sails at the thaw. Coming soon."
        var w2 := font.get_string_size(t2, HORIZONTAL_ALIGNMENT_CENTER, -1, 30).x
        c.draw_string(font, Vector2(589 - w2 / 2.0, y0 + 390), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.2, 0.28, 0.36, 0.7))

func _draw_ship(c: Control, at: Vector2) -> void:
    var hull := PackedVector2Array([at + Vector2(-46, 0), at + Vector2(46, 0), at + Vector2(32, 22), at + Vector2(-32, 22)])
    c.draw_colored_polygon(hull, Color(0.45, 0.28, 0.16))
    c.draw_line(at + Vector2(0, 0), at + Vector2(0, -70), Color(0.3, 0.2, 0.12), 5.0)
    c.draw_colored_polygon(PackedVector2Array([at + Vector2(3, -66), at + Vector2(38, -20), at + Vector2(3, -12)]), Color(0.96, 0.94, 0.88))
    c.draw_colored_polygon(PackedVector2Array([at + Vector2(-3, -60), at + Vector2(-32, -16), at + Vector2(-3, -12)]), Color(0.92, 0.9, 0.84))
    c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -70), at + Vector2(20, -64), at + Vector2(0, -58)]), Color(0.85, 0.15, 0.12))
