## The player's ship: a Dutch ship (Poly Haven) lying broadside to the island, bow to the left,
## so the cannon fires over the starboard (right) rail. The camera looks across the deck from
## the port side. Rides the sea. Exposes the cannon mount in ship space.
class_name Ship
extends Node3D

## Bow to stern along x; long and wide enough that the deck fills the lower screen.
const LENGTH := 13.0
## Cannon distance in from the starboard rail, and along the deck from midships toward the stern:
## between the mainmast (x 1.0) and the raised quarterdeck (x 3.9), on flat deck.
const CANNON_FROM_RAIL := 1.25
const CANNON_AFT := 3.0
## The gun stands on a plank platform so the barrel clears the bulwark.
const PLATFORM_HEIGHT := 0.5

var cannon_mount: Vector3 = Vector3(0, 1.0, 0)
var model: Node3D
var length: float = LENGTH

func setup() -> void:
    model = Models.instance("res://assets/hq/dutch_ship/dutch_ship_medium_1k.gltf")
    add_child(model)
    # The model lies along x with its bow (bowsprit) at +x. Turning it half way puts the bow on
    # the left and the starboard side toward the island at -z.
    model.rotation.y = PI
    var turn := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
    var hull := _hull(model)
    # Measure the hull (in model space) so the bowsprit does not count toward the length.
    var local := Models._relative_transform(model, hull) * hull.mesh.get_aabb() if hull else Models.aabb_of(model)
    var a := turn * local
    var s := length / maxf(a.size.x, 0.01)
    model.scale = Vector3(s, s, s)
    a = Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)), Vector3.ZERO) * a
    # Sink the keel so the deck rides about a metre above the water line.
    model.position = Vector3(-a.get_center().x, -a.position.y - 1.3, -a.get_center().z)
    cannon_mount = Vector3(CANNON_AFT, 1.0, -a.size.z / 2.0 + CANNON_FROM_RAIL)
    # Concave collider so enemy balls and our own dropped balls hit the hull and deck.
    _add_collision(model)
    _tag_rigging(model)
    # Find the deck under the cannon by raycast once we are in the tree.
    call_deferred("_find_deck")

func _hull(node: Node) -> MeshInstance3D:
    for c in node.find_children("*", "MeshInstance3D", true, false):
        if c.name.contains("hull"):
            return c
    return null

## Masts, rigging and sails fade out close to the camera (dithered, so no sorting cost): from
## the gun they are a faint lattice over the view instead of a spar across it, further off
## they are solid, and the fly-in shows the whole ship.
const RIGGING_FADE_NEAR := 3.0
const RIGGING_FADE_FAR := 7.0

func _tag_rigging(node: Node) -> void:
    for c in node.get_children():
        if c is MeshInstance3D and not c.name.contains("hull"):
            var mi := c as MeshInstance3D
            # Sail shadows lay a dark sheet over the water in front of the cannon.
            mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            for i in mi.mesh.get_surface_count():
                var m := mi.get_active_material(i)
                if m is BaseMaterial3D:
                    var d: BaseMaterial3D = m.duplicate()
                    d.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
                    d.distance_fade_min_distance = RIGGING_FADE_NEAR
                    d.distance_fade_max_distance = RIGGING_FADE_FAR
                    mi.set_surface_override_material(i, d)
        _tag_rigging(c)

## Physics layer of the hull. Nothing else masks it: our balls fly out past the bowsprit and
## enemy hits are measured by distance to the cannon. Only the deck raycast looks for it.
const HULL_LAYER := 1 << 2

## Only the hull collides; the rigging is thousands of thin triangles nothing needs to hit.
func _add_collision(node: Node) -> void:
    for c in node.get_children():
        if c is MeshInstance3D and c.name.contains("hull"):
            var mi := c as MeshInstance3D
            mi.create_trimesh_collision()
            for body in mi.find_children("*", "StaticBody3D", false, false):
                (body as StaticBody3D).collision_layer = HULL_LAYER
                (body as StaticBody3D).collision_mask = 0
        _add_collision(c)

signal deck_found

func _find_deck() -> void:
    # The trimesh colliders need a physics step before a ray can see them.
    await get_tree().physics_frame
    await get_tree().physics_frame
    var space := get_world_3d().direct_space_state
    # The lowest of a few rays over the platform footprint is the deck, not a rail or hatch.
    var deck_y := INF
    for dx: float in [-0.5, 0.0, 0.5]:
        for dz: float in [-0.5, 0.0, 0.5]:
            var from := to_global(Vector3(cannon_mount.x + dx, 8.0, cannon_mount.z + dz))
            var to := to_global(Vector3(cannon_mount.x + dx, -3.0, cannon_mount.z + dz))
            var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, HULL_LAYER))
            if hit:
                deck_y = minf(deck_y, to_local(hit.position).y)
    if deck_y < INF:
        _add_platform(deck_y)
        cannon_mount.y = deck_y + PLATFORM_HEIGHT
    deck_found.emit()

func _add_platform(deck_y: float) -> void:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(1.5, PLATFORM_HEIGHT, 1.9)
    mi.mesh = bm
    mi.material_override = Models.tex_material("brown_planks_07", 1.2, Color(0.9, 0.7, 0.55))
    mi.position = Vector3(cannon_mount.x, deck_y + PLATFORM_HEIGHT / 2.0, cannon_mount.z)
    add_child(mi)
