## A story scene: the world dims, a parchment card rises from the bottom with the speaker's
## painted portrait and name, and the line types itself out. Tap to finish the line, tap again
## for the next; "Skip" ends the scene.
class_name StoryCard
extends Control

signal done

var _lines: Array = []
var _i := -1
var _shown := 0.0
var _text: RichTextLabel
var _name: Label
var _portrait_holder: Control
var _portrait: Portrait
var _card: Control
var _hint: Label

func play(lines: Array) -> void:
    _lines = lines
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    var dim := ColorRect.new()
    dim.color = Color(0.02, 0.03, 0.06, 0.72)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    _card = Control.new()
    _card.position = Vector2(50, 2556 - 820)
    _card.size = Vector2(1079, 640)
    _card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _card.draw.connect(_draw_parchment)
    add_child(_card)
    _portrait_holder = Control.new()
    _portrait_holder.position = Vector2(40, -150)
    _portrait_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _card.add_child(_portrait_holder)
    _name = Label.new()
    _name.position = Vector2(340, 40)
    _name.add_theme_font_size_override("font_size", 50)
    _name.add_theme_color_override("font_color", Color(0.42, 0.18, 0.08))
    _name.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _card.add_child(_name)
    _text = RichTextLabel.new()
    _text.position = Vector2(70, 150)
    _text.size = Vector2(940, 400)
    _text.bbcode_enabled = false
    _text.fit_content = false
    _text.scroll_active = false
    _text.add_theme_font_size_override("normal_font_size", 44)
    _text.add_theme_color_override("default_color", Color(0.18, 0.12, 0.08))
    _text.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _card.add_child(_text)
    _hint = Label.new()
    _hint.text = "Tap to continue"
    _hint.position = Vector2(760, 560)
    _hint.add_theme_font_size_override("font_size", 28)
    _hint.add_theme_color_override("font_color", Color(0.42, 0.28, 0.16, 0.7))
    _hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _card.add_child(_hint)
    var skip := Button.new()
    skip.text = "Skip"
    skip.add_theme_font_size_override("font_size", 34)
    skip.position = Vector2(1179 - 230, 150)
    skip.custom_minimum_size = Vector2(180, 90)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(1, 1, 1, 0.14)
    sb.set_corner_radius_all(45)
    skip.add_theme_stylebox_override("normal", sb)
    skip.add_theme_stylebox_override("hover", sb)
    skip.add_theme_stylebox_override("pressed", sb)
    skip.pressed.connect(_finish)
    add_child(skip)
    # Rise in.
    _card.position.y += 700
    var tw := create_tween()
    tw.tween_property(_card, "position:y", 2556 - 820, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    _next()

func _next() -> void:
    _i += 1
    if _i >= _lines.size():
        _finish()
        return
    var line: Array = _lines[_i]
    var who: String = line[0]
    if _portrait:
        _portrait.queue_free()
    _portrait = Portrait.new(who, 280.0)
    _portrait_holder.add_child(_portrait)
    _portrait.scale = Vector2(0.6, 0.6)
    _portrait.pivot_offset = Vector2(140, 140)
    create_tween().tween_property(_portrait, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    _name.text = Portrait.NAMES.get(who, who)
    _text.text = line[1]
    _text.visible_ratio = 0.0
    _shown = 0.0

func _process(delta: float) -> void:
    if _text and _text.visible_ratio < 1.0:
        _shown += delta * 42.0
        _text.visible_characters = int(_shown)
        if _text.visible_characters >= _text.get_total_character_count():
            _text.visible_ratio = 1.0
        if _portrait:
            _portrait.talking = absf(sin(_shown * 0.9))
    elif _portrait:
        _portrait.talking = 0.0
    if _hint:
        _hint.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 300.0) if _text.visible_ratio >= 1.0 else 0.0

func _gui_input(ev: InputEvent) -> void:
    var tap: bool = (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed)
    if not tap:
        return
    accept_event()
    if _text.visible_ratio < 1.0:
        _text.visible_ratio = 1.0
    else:
        _next()

func _finish() -> void:
    set_process(false)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var tw := create_tween()
    tw.tween_property(self, "modulate:a", 0.0, 0.2)
    tw.tween_callback(func():
        done.emit()
        queue_free())

## Aged parchment with torn-looking edges and a faint ink border.
func _draw_parchment() -> void:
    var w := _card.size.x
    var h := _card.size.y
    var pts := PackedVector2Array()
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var steps := 30
    for i in steps:
        pts.append(Vector2(w * i / steps, rng.randf_range(-6, 6)))
    for i in 10:
        pts.append(Vector2(w + rng.randf_range(-6, 6), h * i / 10.0))
    for i in steps:
        pts.append(Vector2(w - w * i / steps, h + rng.randf_range(-6, 6)))
    for i in 10:
        pts.append(Vector2(rng.randf_range(-6, 6), h - h * i / 10.0))
    _card.draw_colored_polygon(pts, Color(0.93, 0.85, 0.66))
    # Darker toward the edges.
    for k in 6:
        var inset := 8.0 + k * 10.0
        _card.draw_rect(Rect2(inset, inset, w - inset * 2, h - inset * 2), Color(0.55, 0.38, 0.18, 0.05), false, 12.0)
    _card.draw_rect(Rect2(28, 28, w - 56, h - 56), Color(0.45, 0.28, 0.12, 0.45), false, 3.0)
