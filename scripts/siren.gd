## A mermaid on a rock in the ship's road. She sits quiet until the ship comes near, then
## sings (a soft wordless voice, synthesised, so no recording ships with the game) and the
## helm feels a faint pull toward her rock. VoyageLevel owns the pull; this is the figure, the
## voice and the glow.
class_name Siren
extends Node3D

const MIX_RATE := 22050.0
## A slow pentatonic phrase: [frequency, seconds]. Each siren starts somewhere else in it.
const PHRASE := [[440.0, 1.4], [523.25, 0.9], [587.33, 0.9], [659.25, 1.7], [783.99, 1.2], [659.25, 0.9], [587.33, 0.9], [523.25, 2.0]]

var singing := false
var _level := 0.0            # 0 silent .. 1 full voice, eased
var _player: AudioStreamPlayer3D
var _gen: AudioStreamGeneratorPlayback
var _phase := 0.0
var _note := 0
var _note_t := 0.0
var _freq := 440.0
var _pitch := 1.0
var _t := 0.0
var _hair: Node3D
var _fin: Node3D
var _body: Node3D
var _light: OmniLight3D

func setup(index: int, sound_on: bool) -> void:
    _pitch = [1.0, 1.06, 0.94, 1.12, 0.89][index % 5]
    _note = index % PHRASE.size()
    _freq = float(PHRASE[_note][0]) * _pitch
    _t = float(index) * 1.7
    var skin := Models.flat_material(Color(0.95, 0.78, 0.66), 0.65)
    var hair := Models.flat_material(Color(0.16, 0.36, 0.34), 0.8)
    var scale_mat := Models.flat_material(Color(0.22, 0.62, 0.6), 0.35, 0.5)
    var dark := Models.flat_material(Color(0.1, 0.08, 0.1), 0.8)
    _body = Node3D.new()
    add_child(_body)
    # The tail lies along the rock and curls up into a fin.
    _part(_body, CapsuleMesh.new(), scale_mat, Vector3(0, 0.12, 0.28), Vector3(0.2, 0.48, 0.2), Vector3(deg_to_rad(80.0), 0, 0))
    _fin = Node3D.new()
    _fin.position = Vector3(0, 0.2, 0.78)
    _body.add_child(_fin)
    for side: float in [-1.0, 1.0]:
        _part(_fin, SphereMesh.new(), scale_mat, Vector3(side * 0.12, 0.12, 0.04), Vector3(0.1, 0.2, 0.05), Vector3(0, 0, side * 0.5))
    # Torso, head, long hair, two arms resting on the rock.
    _part(_body, CapsuleMesh.new(), skin, Vector3(0, 0.46, 0), Vector3(0.28, 0.4, 0.26))
    _part(_body, SphereMesh.new(), scale_mat, Vector3(0, 0.5, 0.0), Vector3(0.3, 0.14, 0.28))
    _part(_body, SphereMesh.new(), skin, Vector3(0, 0.85, 0), Vector3(0.26, 0.26, 0.26))
    for side: float in [-1.0, 1.0]:
        _part(_body, SphereMesh.new(), dark, Vector3(side * 0.05, 0.87, 0.11), Vector3(0.035, 0.045, 0.03))
        _part(_body, CapsuleMesh.new(), skin, Vector3(side * 0.2, 0.42, 0.08), Vector3(0.08, 0.3, 0.08), Vector3(0, 0, side * 0.35))
    _hair = Node3D.new()
    _hair.position = Vector3(0, 0.9, -0.04)
    _body.add_child(_hair)
    _part(_hair, SphereMesh.new(), hair, Vector3(0, 0.05, -0.02), Vector3(0.3, 0.24, 0.3))
    _part(_hair, CapsuleMesh.new(), hair, Vector3(0, -0.32, -0.16), Vector3(0.22, 0.6, 0.12))
    _light = OmniLight3D.new()
    _light.light_color = Color(0.5, 0.95, 0.9)
    _light.light_energy = 0.0
    _light.omni_range = 4.0
    _light.shadow_enabled = false
    _light.position = Vector3(0, 0.9, 0.3)
    add_child(_light)
    if sound_on:
        _player = AudioStreamPlayer3D.new()
        var gen := AudioStreamGenerator.new()
        gen.mix_rate = MIX_RATE
        gen.buffer_length = 0.3
        _player.stream = gen
        _player.bus = &"Sfx"
        _player.unit_size = 12.0
        _player.max_db = -3.0
        _player.volume_db = -30.0
        _player.position = Vector3(0, 0.9, 0)
        add_child(_player)

func set_singing(on: bool) -> void:
    singing = on

func _process(delta: float) -> void:
    _t += delta
    _level = move_toward(_level, 1.0 if singing else 0.0, delta / (1.6 if singing else 1.2))
    # She sways with the water and flicks her fin; singing, she lifts her head and glows.
    var sway := sin(_t * 1.1) * 0.05
    _body.rotation = Vector3(-0.18 * _level + sway * 0.5, sin(_t * 0.7) * 0.08, sway)
    _fin.rotation.x = sin(_t * 2.3) * 0.35 - 0.3
    _hair.rotation.x = sin(_t * 1.6 + 1.0) * 0.08
    _light.light_energy = _level * (0.9 + 0.3 * sin(_t * 3.0))
    _voice()

func _voice() -> void:
    if _player == null:
        return
    if _level <= 0.001:
        if _player.playing:
            _player.stop()
            _gen = null
        return
    if not _player.playing:
        _player.play()
        _gen = _player.get_stream_playback()
    if _gen == null:
        return
    _player.volume_db = lerpf(-30.0, -6.0, _level)
    var frames := _gen.get_frames_available()
    if frames <= 0:
        return
    var dt := 1.0 / MIX_RATE
    var buf := PackedVector2Array()
    buf.resize(frames)
    for i in frames:
        var dur := float(PHRASE[_note][1])
        _note_t += dt
        if _note_t >= dur:
            _note_t = 0.0
            _note = (_note + 1) % PHRASE.size()
            dur = float(PHRASE[_note][1])
        # Glide into each note, then hold it with a slow vibrato.
        var target := float(PHRASE[_note][0]) * _pitch
        _freq += (target - _freq) * minf(dt * 18.0, 1.0)
        var vib := 1.0 + 0.009 * sin(_phase * 0.0 + _note_t * TAU * 5.2) * clampf((_note_t - 0.25) * 2.0, 0.0, 1.0)
        _phase += TAU * _freq * vib * dt
        if _phase > TAU * 1000.0:
            _phase -= TAU * 1000.0
        var env := minf(_note_t / 0.22, 1.0) * minf((dur - _note_t) / 0.3, 1.0)
        var s := sin(_phase) * 0.6 + sin(_phase * 2.0) * 0.28 + sin(_phase * 3.0) * 0.12 + sin(_phase * 5.0) * 0.04
        var a := s * env * 0.32
        buf[i] = Vector2(a, a)
    _gen.push_buffer(buf)

func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    mi.scale = scl
    mi.rotation = rot
    parent.add_child(mi)
