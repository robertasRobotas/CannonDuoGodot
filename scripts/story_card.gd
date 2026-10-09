## A story scene, framed like a film: black letterbox bars close in, a dark panel with a gold
## trim rises from the bottom, the speaker's painted medallion overlaps its top edge, and the
## line types itself out. Tap to finish the line, tap again for the next; "Skip" ends the scene.
class_name StoryCard
extends Control

signal done

const CARD_Y := 2556.0 - 760.0
const GOLD := Color(1.0, 0.82, 0.38)

var _lines: Array = []
var _i := -1
var _shown := 0.0
var _text: RichTextLabel
var _name: Label
var _portrait_holder: Control
var _portrait: Portrait
var _card: Control
var _hint: Label
var _bars: Array[ColorRect] = []
var _eavesdrop := false

func play(lines: Array, eavesdrop: bool = false) -> void:
    _lines = lines
    _eavesdrop = eavesdrop
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    var dim := ColorRect.new()
    dim.color = Color(0.01, 0.02, 0.05, 0.82 if eavesdrop else 0.6)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    # Letterbox bars slide in from the top and bottom.
    for i in 2:
        var bar := ColorRect.new()
        bar.color = Color(0, 0, 0, 0.95)
        bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if i == 0 else Control.PRESET_BOTTOM_WIDE)
        bar.size.y = 0
        add_child(bar)
        _bars.append(bar)
        var bt := create_tween()
        bt.tween_property(bar, "size:y", 150.0, 0.3).set_ease(Tween.EASE_OUT)
        if i == 1:
            bt.parallel().tween_property(bar, "position:y", 2556.0 - 150.0, 0.3).set_ease(Tween.EASE_OUT)
    if eavesdrop:
        # Listening through the cabin door: a sliver of lamplight down the middle, and a
        # whispered caption above the card.
        var light := ColorRect.new()
        light.color = Color(1.0, 0.85, 0.5, 0.0)
        light.position = Vector2(574, 0)
        light.size = Vector2(16, 2556)
        light.rotation = 0.03
        light.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(light)
        create_tween().tween_property(light, "color:a", 0.16, 0.8)
        var ear := Label.new()
        ear.text = "— you listen through the cabin door —"
        ear.add_theme_font_size_override("font_size", 32)
        ear.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
        ear.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        ear.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
        ear.position.y = CARD_Y - 90
        ear.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(ear)
    _card = Control.new()
    _card.position = Vector2(50, CARD_Y)
    _card.size = Vector2(1079, 560)
    _card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _card.draw.connect(_draw_card)
    add_child(_card)
    _portrait_holder = Control.new()
    _portrait_holder.position = Vector2(44, -170)
    _portrait_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _card.add_child(_portrait_holder)
    _name = Label.new()
    _name.position = Vector2(370, 42)
    _name.add_theme_font_size_override("font_size", 52)
    _name.add_theme_color_override("font_color", GOLD)
    _name.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _card.add_child(_name)
    _text = RichTextLabel.new()
    _text.position = Vector2(80, 165)
    _text.size = Vector2(920, 300)
    _text.bbcode_enabled = false
    _text.fit_content = false
    _text.scroll_active = false
    _text.add_theme_font_size_override("normal_font_size", 48)
    _text.add_theme_color_override("default_color", Color(0.95, 0.96, 0.98))
    _text.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _card.add_child(_text)
    _hint = Label.new()
    _hint.text = "Tap ▸"
    _hint.position = Vector2(900, 480)
    _hint.add_theme_font_size_override("font_size", 32)
    _hint.add_theme_color_override("font_color", GOLD)
    _hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _card.add_child(_hint)
    var skip := Button.new()
    skip.text = "Skip"
    skip.add_theme_font_size_override("font_size", 32)
    skip.position = Vector2(1179 - 220, 170)
    skip.custom_minimum_size = Vector2(170, 86)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(1, 1, 1, 0.12)
    sb.set_corner_radius_all(43)
    skip.add_theme_stylebox_override("normal", sb)
    skip.add_theme_stylebox_override("hover", sb)
    skip.add_theme_stylebox_override("pressed", sb)
    skip.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
    skip.pressed.connect(_finish)
    add_child(skip)
    # Rise in.
    _card.position.y += 700
    var tw := create_tween()
    tw.tween_property(_card, "position:y", CARD_Y, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
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
    _portrait = Portrait.new(who, 300.0)
    _portrait_holder.add_child(_portrait)
    _portrait.pivot_offset = Vector2(150, 150)
    if _eavesdrop:
        # Each voice bursts in: the medallion swings up from the door side and the card jolts.
        _portrait.scale = Vector2(0.3, 0.3)
        _portrait.position = Vector2(220, 60)
        _portrait.rotation = 0.35
        var pt := create_tween()
        pt.set_parallel(true)
        pt.tween_property(_portrait, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
        pt.tween_property(_portrait, "position", Vector2.ZERO, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
        pt.tween_property(_portrait, "rotation", 0.0, 0.3).set_ease(Tween.EASE_OUT)
        var jolt := create_tween()
        jolt.tween_property(_card, "position:x", 42.0, 0.05)
        jolt.tween_property(_card, "position:x", 56.0, 0.06)
        jolt.tween_property(_card, "position:x", 50.0, 0.05)
        Haptics.pop()
    else:
        _portrait.scale = Vector2(0.6, 0.6)
        create_tween().tween_property(_portrait, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    _name.text = Portrait.NAMES.get(who, who)
    _text.text = line[1]
    _text.visible_ratio = 0.0
    _shown = 0.0

func _process(delta: float) -> void:
    if _text and _text.visible_ratio < 1.0:
        _shown += delta * 46.0
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
    for bar in _bars:
        create_tween().tween_property(bar, "size:y", 0.0, 0.2)
    var tw := create_tween()
    tw.tween_property(self, "modulate:a", 0.0, 0.2)
    tw.tween_callback(func():
        done.emit()
        queue_free())

## A dark captain's-log panel: deep navy, a thin double gold frame, a diamond on the frame
## under the portrait, and a soft top sheen.
func _draw_card() -> void:
    var w := _card.size.x
    var h := _card.size.y
    var panel := StyleBoxFlat.new()
    panel.bg_color = Color(0.07, 0.09, 0.15, 0.97)
    panel.set_corner_radius_all(34)
    panel.anti_aliasing = true
    _card.draw_style_box(panel, Rect2(0, 0, w, h))
    var sheen := StyleBoxFlat.new()
    sheen.bg_color = Color(1, 1, 1, 0.045)
    sheen.set_corner_radius_all(34)
    _card.draw_style_box(sheen, Rect2(0, 0, w, h * 0.3))
    _card.draw_rect(Rect2(10, 10, w - 20, h - 20), Color(GOLD.r, GOLD.g, GOLD.b, 0.85), false, 3.0)
    _card.draw_rect(Rect2(20, 20, w - 40, h - 40), Color(GOLD.r, GOLD.g, GOLD.b, 0.3), false, 1.5)
    # A gold diamond pin where the medallion meets the frame.
    var p := Vector2(194, 10)
    _card.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -14), p + Vector2(14, 0), p + Vector2(0, 14), p + Vector2(-14, 0)]), GOLD)
