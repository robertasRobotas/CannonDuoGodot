## Ground from a heightfield: a grid of quads with smooth normals, each vertex coloured for
## the ground shader (rgb tint, alpha = turf over rock), so cliffs read as stone and gentle
## ground as grass with no seam between them. The caller gives the height and the colour
## as functions of place, and gets one mesh back.
class_name Terrain

static var _mat: ShaderMaterial

static func material() -> ShaderMaterial:
    if _mat == null:
        _mat = ShaderMaterial.new()
        _mat.shader = load("res://shaders/ground.gdshader")
        _mat.set_shader_parameter("rock", load("res://assets/ph/tex/coast_sand_rocks_02.jpg"))
        _mat.set_shader_parameter("grass", load("res://assets/ph/tex/leafy_grass.jpg"))
    return _mat

## The grid over [x0, x1] x [z0, z1] in `step` metre quads. `height(x, z) -> float`;
## `colour(p: Vector3, slope: float) -> Color`, slope being 0 flat to 1 vertical, and the
## colour's alpha the share of turf over rock.
static func build(x0: float, x1: float, z0: float, z1: float, step: float, height: Callable, colour: Callable) -> MeshInstance3D:
    var nx := maxi(int(ceil(absf(x1 - x0) / step)), 1)
    var nz := maxi(int(ceil(absf(z1 - z0) / step)), 1)
    var w := nx + 1
    var pts := PackedVector3Array()
    pts.resize(w * (nz + 1))
    for j in nz + 1:
        var z := lerpf(z0, z1, float(j) / nz)
        for i in w:
            var x := lerpf(x0, x1, float(i) / nx)
            pts[j * w + i] = Vector3(x, float(height.call(x, z)), z)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for j in nz + 1:
        for i in w:
            var p := pts[j * w + i]
            var il := pts[j * w + maxi(i - 1, 0)]
            var ir := pts[j * w + mini(i + 1, nx)]
            var jb := pts[maxi(j - 1, 0) * w + i]
            var jf := pts[mini(j + 1, nz) * w + i]
            var n := (ir - il).cross(jf - jb)
            if n.y < 0.0:
                n = -n
            n = n.normalized()
            st.set_normal(n)
            st.set_color(colour.call(p, 1.0 - n.y))
            st.add_vertex(p)
    # Wound to face up whichever way the grid runs.
    var flip := (x1 - x0) * (z1 - z0) > 0.0
    for j in nz:
        for i in nx:
            var a := j * w + i
            var b := a + 1
            var c := a + w
            var d := c + 1
            for tri: Array in [[a, b, c], [b, d, c]]:
                if flip:
                    tri.reverse()
                for k: int in tri:
                    st.add_index(k)
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    mi.material_override = material()
    return mi

## The slope of a height function at (x, z): 0 flat, 1 vertical.
static func slope_at(height: Callable, x: float, z: float) -> float:
    var gx := (float(height.call(x + 0.5, z)) - float(height.call(x - 0.5, z)))
    var gz := (float(height.call(x, z + 0.5)) - float(height.call(x, z - 0.5)))
    return 1.0 - 1.0 / sqrt(1.0 + gx * gx + gz * gz)
