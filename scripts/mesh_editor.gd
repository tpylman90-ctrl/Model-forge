extends RefCounted
## Editable triangle-mesh geometry with seam-aware vertex movement and 20-step undo.
## v0.1 intentionally does not preserve blend shapes, LODs or skin weights.
signal geometry_changed

var target: MeshInstance3D
var surfaces: Array = []
var selected_surface: int = -1
var selected_vertex: int = -1
var mirror_enabled: bool = false

var _weld: Array = []
var _mirror_weld: Array = []
var _stroke_before: Array = []
var _stroke_active: bool = false
var _stroke_changed: bool = false
var _undo_stack: Array = []
var _redo_stack: Array = []
const MAX_HISTORY := 20
const WELD_EPSILON_SQUARED := 0.00000004

func set_target(instance: MeshInstance3D) -> bool:
    target = null
    surfaces.clear()
    _weld.clear()
    _mirror_weld.clear()
    selected_surface = -1
    selected_vertex = -1
    _undo_stack.clear()
    _redo_stack.clear()
    _stroke_active = false
    if instance == null or instance.mesh == null:
        return false
    var source: Mesh = instance.mesh
    for i in range(source.get_surface_count()):
        var primitive: int = source.surface_get_primitive_type(i)
        if primitive != Mesh.PRIMITIVE_TRIANGLES:
            continue
        var arrays: Array = source.surface_get_arrays(i).duplicate(true)
        if arrays.size() != Mesh.ARRAY_MAX or arrays[Mesh.ARRAY_VERTEX] == null:
            continue
        surfaces.append({
            "arrays": arrays,
            "primitive": primitive,
            "material": source.surface_get_material(i),
            "name": source.surface_get_name(i)
        })
    if surfaces.is_empty():
        return false
    target = instance
    return true

func vertex_count() -> int:
    var total := 0
    for surface in surfaces:
        var positions: PackedVector3Array = surface["arrays"][Mesh.ARRAY_VERTEX]
        total += positions.size()
    return total

func vertex_position() -> Vector3:
    if not has_selection():
        return Vector3.ZERO
    var vertices: PackedVector3Array = surfaces[selected_surface]["arrays"][Mesh.ARRAY_VERTEX]
    return vertices[selected_vertex]

func has_selection() -> bool:
    return target != null and selected_surface >= 0 and selected_surface < surfaces.size() and selected_vertex >= 0

func select_vertex(surface_index: int, vertex_index: int) -> bool:
    if surface_index < 0 or surface_index >= surfaces.size():
        return false
    var positions: PackedVector3Array = surfaces[surface_index]["arrays"][Mesh.ARRAY_VERTEX]
    if vertex_index < 0 or vertex_index >= positions.size():
        return false
    selected_surface = surface_index
    selected_vertex = vertex_index
    _refresh_weld()
    return true

func _refresh_weld() -> void:
    _weld.clear()
    _mirror_weld.clear()
    if not has_selection():
        return
    var point := vertex_position()
    var reflected := Vector3(-point.x, point.y, point.z)
    for s in range(surfaces.size()):
        var vertices: PackedVector3Array = surfaces[s]["arrays"][Mesh.ARRAY_VERTEX]
        for i in range(vertices.size()):
            if vertices[i].distance_squared_to(point) <= WELD_EPSILON_SQUARED:
                _weld.append(Vector2i(s, i))
            elif absf(point.x) > 0.0002 and vertices[i].distance_squared_to(reflected) <= WELD_EPSILON_SQUARED:
                _mirror_weld.append(Vector2i(s, i))

func begin_stroke() -> bool:
    if not has_selection() or _stroke_active:
        return false
    _stroke_before = _snapshot()
    _stroke_active = true
    _stroke_changed = false
    return true

func apply_stroke_delta(delta: Vector3) -> void:
    if not _stroke_active:
        return
    for s in range(surfaces.size()):
        var arrays: Array = surfaces[s]["arrays"]
        arrays[Mesh.ARRAY_VERTEX] = _stroke_before[s].duplicate()
        surfaces[s]["arrays"] = arrays
    for address in _weld:
        var verts: PackedVector3Array = surfaces[address.x]["arrays"][Mesh.ARRAY_VERTEX]
        verts[address.y] = _stroke_before[address.x][address.y] + delta
        surfaces[address.x]["arrays"][Mesh.ARRAY_VERTEX] = verts
    if mirror_enabled:
        var reflected_delta := Vector3(-delta.x, delta.y, delta.z)
        for address in _mirror_weld:
            var verts: PackedVector3Array = surfaces[address.x]["arrays"][Mesh.ARRAY_VERTEX]
            verts[address.y] = _stroke_before[address.x][address.y] + reflected_delta
            surfaces[address.x]["arrays"][Mesh.ARRAY_VERTEX] = verts
    _stroke_changed = delta.length_squared() > 0.0000000001
    _rebuild()

func end_stroke() -> void:
    if not _stroke_active:
        return
    if _stroke_changed:
        _undo_stack.append(_stroke_before)
        if _undo_stack.size() > MAX_HISTORY:
            _undo_stack.pop_front()
        _redo_stack.clear()
        _refresh_weld()
    _stroke_before = []
    _stroke_active = false
    _stroke_changed = false

func move_step(delta: Vector3) -> void:
    if begin_stroke():
        apply_stroke_delta(delta)
        end_stroke()

func can_undo() -> bool:
    return not _undo_stack.is_empty()

func can_redo() -> bool:
    return not _redo_stack.is_empty()

func undo() -> void:
    if _undo_stack.is_empty():
        return
    end_stroke()
    _redo_stack.append(_snapshot())
    _restore(_undo_stack.pop_back())

func redo() -> void:
    if _redo_stack.is_empty():
        return
    end_stroke()
    _undo_stack.append(_snapshot())
    _restore(_redo_stack.pop_back())

func recalculate_normals() -> void:
    if target == null:
        return
    end_stroke()
    _undo_stack.append(_snapshot())
    if _undo_stack.size() > MAX_HISTORY:
        _undo_stack.pop_front()
    _redo_stack.clear()
    for s in range(surfaces.size()):
        var arr: Array = surfaces[s]["arrays"]
        var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
        var indices: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
        var normals := PackedVector3Array()
        normals.resize(verts.size())
        var count: int = indices.size() if not indices.is_empty() else verts.size()
        for j in range(0, count - 2, 3):
            var a: int = indices[j] if not indices.is_empty() else j
            var b: int = indices[j + 1] if not indices.is_empty() else j + 1
            var c: int = indices[j + 2] if not indices.is_empty() else j + 2
            var weighted_normal := (verts[b] - verts[a]).cross(verts[c] - verts[a])
            normals[a] += weighted_normal
            normals[b] += weighted_normal
            normals[c] += weighted_normal
        for i in range(normals.size()):
            normals[i] = normals[i].normalized() if normals[i].length_squared() > 0.00000001 else Vector3.UP
        arr[Mesh.ARRAY_NORMAL] = normals
        arr[Mesh.ARRAY_TANGENT] = null
        surfaces[s]["arrays"] = arr
    _rebuild()

func _snapshot() -> Array:
    var result: Array = []
    for surface in surfaces:
        var vertices: PackedVector3Array = surface["arrays"][Mesh.ARRAY_VERTEX]
        result.append(vertices.duplicate())
    return result

func _restore(snapshot: Array) -> void:
    for s in range(mini(snapshot.size(), surfaces.size())):
        var arrays: Array = surfaces[s]["arrays"]
        arrays[Mesh.ARRAY_VERTEX] = snapshot[s].duplicate()
        surfaces[s]["arrays"] = arrays
    _rebuild()
    _refresh_weld()

func _rebuild() -> void:
    if target == null:
        return
    var result := ArrayMesh.new()
    for surface in surfaces:
        var index := result.get_surface_count()
        result.add_surface_from_arrays(surface["primitive"], surface["arrays"])
        var material: Material = surface["material"]
        if material != null:
            result.surface_set_material(index, material)
        result.surface_set_name(index, surface["name"])
    target.mesh = result
    geometry_changed.emit()
