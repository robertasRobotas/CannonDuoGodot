## A white arrow that hovers near a powder store and bobs: it points the player at the powder.
## It follows the block it belongs to (at a fixed offset, so it can stand out in front of a
## fort), never tilts with it, and draws on top of everything so rain and haze never hide it.
extends Node3D

var offset := Vector3(0.0, 1.0, 0.0)   # from the block's centre to the arrow's tip
var amp := 0.12                         # how high it bobs
var size := 1.0                         # the arrow's scale
var _t := randf() * TAU  # each arrow bobs on its own beat
var _base: Node3D

func _ready() -> void:
    top_level = true
    _base = get_parent() as Node3D
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(1.0, 1.0, 1.0)
    mat.no_depth_test = true
    mat.render_priority = 10
    # The head: a cone pointing down at the powder.
    var head := MeshInstance3D.new()
    var hm := CylinderMesh.new()
    hm.top_radius = 0.32
    hm.bottom_radius = 0.0
    hm.height = 0.4
    hm.radial_segments = 12
    head.mesh = hm
    head.material_override = mat
    head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    head.position.y = 0.2
    add_child(head)
    # The shaft above it.
    var shaft := MeshInstance3D.new()
    var sm := CylinderMesh.new()
    sm.top_radius = 0.12
    sm.bottom_radius = 0.12
    sm.height = 0.52
    sm.radial_segments = 10
    shaft.mesh = sm
    shaft.material_override = mat
    shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    shaft.position.y = 0.4 + 0.26
    add_child(shaft)
    _place(0.0)

func _process(delta: float) -> void:
    _t += delta * 3.2
    _place(amp * (0.5 + 0.5 * sin(_t)))

func _place(bob: float) -> void:
    if _base == null or not is_instance_valid(_base):
        return
    global_transform = Transform3D(Basis().scaled(Vector3.ONE * size), _base.global_position + offset + Vector3(0.0, bob, 0.0))
