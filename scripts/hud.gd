## In game overlay, built in code: top card, hearts, ammo row, power bar, loading cover,
## intro card, the single hint, results.
class_name Hud
extends CanvasLayer

signal next_level
signal replay
signal quit

var level: Level
var _title: Label
var _ammo: HBoxContainer
var _ammo_shown := -1
var _stats: Label
var _hearts: Label
var _power_fill: ColorRect
var _power_label: Label
var _hint: Label
var _cover: Control
var _intro: Control
var _intro_title: Label
var _result: Control
var _flash: ColorRect
var _pop: Label
var _load_hint: Control
var _knob: Control
var _track_fill: ColorRect
var _last_interaction := 0.0
var _gyro_btn: Button
var _pause_menu: Control
var _loading: LoadingScreen

const FONT_SIZE := 30

func setup(lv: Level, loading: LoadingScreen = null) -> void:
    level = lv
    level.event.connect(_on_event)
    layer = 10
    _loading = loading
    _build()

func _label(text: String, size: int, color: Color = Color.WHITE, bold: bool = false) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
    l.add_theme_constant_override("outline_size", 4 if bold else 0)
    return l

func _panel(radius: int = 24, alpha: float = 0.42) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.12, 0.10, 0.14, alpha)
    sb.corner_radius_top_left = radius
    sb.corner_radius_top_right = radius
    sb.corner_radius_bottom_left = radius
    sb.corner_radius_bottom_right = radius
    sb.content_margin_left = 24
    sb.content_margin_right = 24
    sb.content_margin_top = 16
    sb.content_margin_bottom = 16
    return sb

func _build() -> void:
    _flash = ColorRect.new()
    _flash.color = Color(1, 1, 1, 0)
    _flash.set_anchors_preset(Control.PRESET_FULL_RECT)
    _flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_flash)

    var top := PanelContainer.new()
    top.add_theme_stylebox_override("panel", _panel())
    top.position = Vector2(40, 130)
    top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 8)
    _title = _label("%d. %s" % [int(level.data.id), level.data.name], 40, Color.WHITE, true)
    col.add_child(_title)
    _ammo = HBoxContainer.new()
    _ammo.add_theme_constant_override("separation", 10)
    col.add_child(_ammo)
    _stats = _label("", FONT_SIZE)
    col.add_child(_stats)
    top.add_child(col)
    add_child(top)

    add_child(_icon_button("II", 130, _toggle_pause))
    _gyro_btn = _icon_button("GYRO", 260, func(): level.set_gyro(not level.gyro_enabled); _refresh_gyro())
    _gyro_btn.add_theme_font_size_override("font_size", 24)
    add_child(_gyro_btn)
    add_child(_icon_button("⌖", 390, level.recenter))
    _refresh_gyro()

    # Power bar, bottom right.
    var bar_bg := PanelContainer.new()
    bar_bg.add_theme_stylebox_override("panel", _panel(20))
    bar_bg.position = Vector2(1179 - 40 - 150, 2556 - 120 - 520)
    bar_bg.custom_minimum_size = Vector2(150, 520)
    bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var bar_col := VBoxContainer.new()
    _power_label = _label("0%", 30)
    _power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bar_col.add_child(_power_label)
    var track := Control.new()
    track.custom_minimum_size = Vector2(100, 420)
    var track_bg := ColorRect.new()
    track_bg.color = Color(1, 1, 1, 0.15)
    track_bg.position = Vector2(30, 0)
    track_bg.size = Vector2(40, 420)
    track.add_child(track_bg)
    _power_fill = ColorRect.new()
    _power_fill.color = Color(1.0, 0.58, 0.18)
    _power_fill.position = Vector2(30, 416)
    _power_fill.size = Vector2(40, 4)
    track.add_child(_power_fill)
    bar_col.add_child(track)
    bar_bg.add_child(bar_col)
    add_child(bar_bg)

    _hint = _label("", 32)
    _hint.position = Vector2(40, 2556 - 120 - 560)
    _hint.size = Vector2(880, 120)
    _hint.autowrap_mode = TextServer.AUTOWRAP_WORD
    add_child(_hint)

    # The single control hint: a knob that glides down a track on the right.
    _load_hint = Control.new()
    _load_hint.position = Vector2(1179 - 40 - 150 - 120, 2556 - 120 - 520 + 60)
    _load_hint.visible = false
    _load_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var track2 := ColorRect.new()
    track2.color = Color(1, 1, 1, 0.18)
    track2.size = Vector2(14, 380)
    _load_hint.add_child(track2)
    _track_fill = ColorRect.new()
    _track_fill.color = Color(1, 1, 1, 0.6)
    _track_fill.size = Vector2(14, 20)
    _load_hint.add_child(_track_fill)
    _knob = ColorRect.new()
    _knob.color = Color.WHITE
    _knob.size = Vector2(56, 56)
    _knob.position = Vector2(-21, -10)
    _load_hint.add_child(_knob)
    add_child(_load_hint)

    _pop = _label("", 90, Color(1.0, 0.85, 0.2), true)
    _pop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _pop.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _pop.visible = false
    add_child(_pop)

    # Loading cover.
    if _loading == null:
        _loading = LoadingScreen.new()
        _loading.build(int(level.data.id), level.data.name, level.data.get("subtitle", ""), "", level.sea_description())
    _cover = _loading
    add_child(_cover)

    # Intro card.
    _intro = Control.new()
    _intro.set_anchors_preset(Control.PRESET_FULL_RECT)
    _intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var ip := PanelContainer.new()
    ip.add_theme_stylebox_override("panel", _panel(28, 0.6))
    ip.position = Vector2(200, 1750)
    ip.custom_minimum_size = Vector2(779, 260)
    var iv := VBoxContainer.new()
    iv.alignment = BoxContainer.ALIGNMENT_CENTER
    var i1 := _label("Level %d" % int(level.data.id), 30, Color(1, 1, 1, 0.6))
    i1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _intro_title = _label(level.data.name, 70, Color.WHITE, true)
    _intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var i3 := _label("%s · %s" % [level.data.get("subtitle", ""), level.sea_description()], 30, Color(1, 1, 1, 0.75))
    i3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    iv.add_child(i1)
    iv.add_child(_intro_title)
    iv.add_child(i3)
    ip.add_child(iv)
    _intro.add_child(ip)
    _intro.visible = false
    add_child(_intro)

    _result = Control.new()
    _result.set_anchors_preset(Control.PRESET_FULL_RECT)
    _result.visible = false
    add_child(_result)

    _pause_menu = Control.new()
    _pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
    _pause_menu.visible = false
    _pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.55)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    _pause_menu.add_child(dim)
    var pm := PanelContainer.new()
    pm.add_theme_stylebox_override("panel", _panel(28, 0.85))
    pm.position = Vector2(240, 1000)
    pm.custom_minimum_size = Vector2(700, 400)
    var pv := VBoxContainer.new()
    pv.add_theme_constant_override("separation", 20)
    var pt := _label("Paused", 60, Color.WHITE, true)
    pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pv.add_child(pt)
    pv.add_child(_button("Resume", _toggle_pause, true))
    pv.add_child(_button("Restart", func(): _toggle_pause(); replay.emit()))
    pv.add_child(_button("Quit level", func(): _toggle_pause(); quit.emit()))
    pm.add_child(pv)
    _pause_menu.add_child(pm)
    add_child(_pause_menu)
    _refresh()

func _button(text: String, cb: Callable, accent: bool = false) -> Button:
    var b := Button.new()
    b.text = text
    b.add_theme_font_size_override("font_size", 38)
    b.custom_minimum_size = Vector2(0, 110)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(1.0, 0.58, 0.18) if accent else Color(1, 1, 1, 0.14)
    for c in ["corner_radius_top_left", "corner_radius_top_right", "corner_radius_bottom_left", "corner_radius_bottom_right"]:
        sb.set(c, 55)
    b.add_theme_stylebox_override("normal", sb)
    var sbh: StyleBoxFlat = sb.duplicate()
    sbh.bg_color = sbh.bg_color.lightened(0.15)
    b.add_theme_stylebox_override("hover", sbh)
    b.add_theme_stylebox_override("pressed", sbh)
    b.add_theme_color_override("font_color", Color.WHITE)
    b.pressed.connect(cb)
    return b

func _icon_button(text: String, y: float, cb: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.add_theme_font_size_override("font_size", 34)
    b.position = Vector2(1179 - 40 - 110, y)
    b.custom_minimum_size = Vector2(110, 110)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.12, 0.10, 0.14, 0.5)
    for c in ["corner_radius_top_left", "corner_radius_top_right", "corner_radius_bottom_left", "corner_radius_bottom_right"]:
        sb.set(c, 55)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_color_override("font_color", Color.WHITE)
    b.pressed.connect(cb)
    return b

func _refresh_gyro() -> void:
    _gyro_btn.text = "GYRO" if level.gyro_enabled else "DRAG"
    _gyro_btn.visible = level.gyro_available

## The app went to the background: pause behind the menu so Resume is one tap away.
func pause_for_background() -> void:
    if level.phase == Level.Phase.FINISHED or level.is_paused:
        return
    level.set_paused(true)
    _pause_menu.visible = true

func _toggle_pause() -> void:
    if level.phase == Level.Phase.FINISHED:
        return
    var p := not level.is_paused
    level.set_paused(p)
    _pause_menu.visible = p

func _process(delta: float) -> void:
    _refresh()
    _cover.visible = level.phase == Level.Phase.LOADING
    if _cover.visible:
        _loading.progress = 0.3 + 0.7 * clampf(level.time / Tuning.LOADING_DURATION, 0.0, 1.0)
    _intro.visible = level.phase == Level.Phase.INTRO
    if _flash.color.a > 0.0:
        _flash.color.a = maxf(0.0, _flash.color.a - delta * 1.6)
    # Load hint on level 1 after idle seconds.
    var idle := level.time - _last_interaction > 3.0
    var want := int(level.data.id) == 1 and level.shots_used == 0 and level.phase == Level.Phase.AIMING and level.power < 0.02 and idle
    _load_hint.visible = want
    if want:
        var t := (sin(level.time * 3.0) + 1.0) * 0.5
        var e := t * t * (3.0 - 2.0 * t)
        _knob.position.y = -10 + 330 * e
        _track_fill.size.y = 20 + 330 * e

func _refresh() -> void:
    var parts: Array[String] = []
    parts.append(level.sea_description())
    if not level.data.get("enemyCannons", []).is_empty() or not level.data.get("enemyShips", []).is_empty():
        var hearts := ""
        for i in Tuning.MAX_HULL_HITS:
            hearts += "♥" if i < Tuning.MAX_HULL_HITS - level.hull_hits else "♡"
        parts.append(hearts)
    if not level.data.targets.is_empty():
        parts.append("☠ %d" % level.targets_remaining)
    if not level.data.get("enemyShips", []).is_empty():
        parts.append("⛵ %d" % level.ships_remaining)
    parts.append("◎ %d/%d" % [level.shots_used, int(level.data.par)])
    _stats.text = "   ".join(parts)
    if level.shots_used != _ammo_shown:
        _ammo_shown = level.shots_used
        _build_ammo()
    _power_label.text = "%d%%" % int(level.power * 100)
    _power_fill.size.y = maxf(4, 416 * level.power)
    _power_fill.position.y = 420 - _power_fill.size.y
    var hint := ""
    if level.shots_used == 0 and level.phase == Level.Phase.AIMING:
        hint = str(level.data.get("hint", ""))
    _hint.text = hint

## Cannonballs left: round balls with a highlight, the next one larger, spent ones faded.
func _build_ammo() -> void:
    for c in _ammo.get_children():
        c.queue_free()
    var n := int(level.data.projectiles)
    for i in n:
        var color: Color = Tuning.AMMO[level.ammo_for(i)].color
        var sz := 36 if i == level.shots_used else 28
        var ball := Panel.new()
        ball.custom_minimum_size = Vector2(sz, sz)
        ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        var sb := StyleBoxFlat.new()
        sb.bg_color = color
        sb.set_corner_radius_all(sz / 2)
        sb.border_color = color.lightened(0.45)
        sb.set_border_width_all(2)
        sb.anti_aliasing = true
        ball.add_theme_stylebox_override("panel", sb)
        # Shine.
        var shine := Panel.new()
        var ss := StyleBoxFlat.new()
        ss.bg_color = Color(1, 1, 1, 0.55)
        ss.set_corner_radius_all(sz / 8)
        shine.add_theme_stylebox_override("panel", ss)
        shine.position = Vector2(sz * 0.24, sz * 0.2)
        shine.size = Vector2(sz * 0.26, sz * 0.22)
        ball.add_child(shine)
        ball.modulate.a = 0.25 if i < level.shots_used else 1.0
        _ammo.add_child(ball)
    if level.shots_used < n:
        _ammo.add_child(_label(Tuning.AMMO[level.next_ammo()].name, 28))

func _on_event(name: String, d: Dictionary) -> void:
    match name:
        "power":
            if float(d.power) > 0.02:
                _last_interaction = level.time
        "fired":
            _last_interaction = level.time
        "blast":
            _flash.color.a = 0.6
        "thunder":
            _flash.color.a = 0.4
        "target":
            _pop.text = "+1000"
            _pop.visible = true
            _pop.modulate.a = 1.0
            _pop.scale = Vector2(0.4, 0.4)
            var tw := create_tween()
            tw.tween_property(_pop, "scale", Vector2(1, 1), 0.2).set_ease(Tween.EASE_OUT)
            tw.tween_interval(0.6)
            tw.tween_property(_pop, "modulate:a", 0.0, 0.3)
            tw.tween_callback(func(): _pop.visible = false)
        "finished":
            _show_result(bool(d.won), int(d.shots), int(d.remaining))

func _show_result(did_win: bool, shots: int, remaining: int) -> void:
    for c in _result.get_children():
        c.queue_free()
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.45)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    _result.add_child(dim)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var pm := PanelContainer.new()
    pm.add_theme_stylebox_override("panel", _panel(36, 0.92))
    pm.custom_minimum_size = Vector2(880, 0)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 22)
    var par := int(level.data.par)
    var stars := 0
    if did_win:
        stars = 3 if shots <= par else (2 if shots <= par + 1 else 1)
    var head := _label("Castle looted!" if did_win else ("Hull breached" if level.hull_hits >= Tuning.MAX_HULL_HITS else "Out of cannonballs"), 64, Color.WHITE, true)
    head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(head)
    var sub := _label(level.data.name, 32, Color(1, 1, 1, 0.6))
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(sub)
    # Three big stars that pop in one after another.
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 30)
    for i in 3:
        var star := _label("★", 140, Color(1.0, 0.85, 0.2) if i < stars else Color(1, 1, 1, 0.18), true)
        star.pivot_offset = Vector2(70, 90)
        star.scale = Vector2(0.2, 0.2) if i < stars else Vector2.ONE
        row.add_child(star)
        if i < stars:
            var tw := create_tween()
            tw.tween_interval(0.25 + 0.3 * i)
            tw.tween_property(star, "scale", Vector2(1.25, 1.25), 0.22).set_ease(Tween.EASE_OUT)
            tw.tween_property(star, "scale", Vector2.ONE, 0.12)
    v.add_child(row)
    var score: int = (level.data.targets.size() - level.targets_remaining) * 1000 + remaining * 250 + level.blocks_broken * 15
    var sc := _label("Score %d   ·   %d shots, par %d" % [score, shots, par], 30, Color(1, 1, 1, 0.75))
    sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(sc)
    var gap := Control.new()
    gap.custom_minimum_size = Vector2(0, 10)
    v.add_child(gap)
    if did_win:
        v.add_child(_button("Next castle", func(): next_level.emit(), true))
    v.add_child(_button("Replay", func(): replay.emit(), did_win == false))
    v.add_child(_button("Castles", func(): quit.emit()))
    pm.add_child(v)
    center.add_child(pm)
    _result.add_child(center)
    _result.visible = true
    _load_hint.visible = false
    level.get_parent().call_deferred("record_result", int(level.data.id), did_win, stars, score)
