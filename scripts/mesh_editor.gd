extends RefCounted
## Editable triangle-mesh geometry with seam-aware vertex movement and 20-step undo.
## v0.1 intentionally does not preserve blend shapes, LODs or skin weights.
signal geometry_changed
signal edit_committed

var target: MeshInstance3D
var surfaces: Array = []
var selected_surface: int = -1
var selected_vertex: int = -1
var mirror_enabled: bool = false
var soft_enabled: bool = false
var soft_radius: float = 0.75
# 0 = radial falloff, 1 = station/section band, 2 = radial with hard-normal guard.
var soft_profile: int = 0
var section_axis: int = 2
var guard_angle_degrees: float = 35.0


var _weld: Array = []
var _mirror_weld: Array = []
var _stroke_before: Array = []
var _stroke_influences: Array = []
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
    _stroke_influences = _build_influences(_stroke_before)
    _stroke_active = true
    _stroke_changed = false
    return true

func _falloff(distance: float) -> float:
    if distance > soft_radius:
        return 0.0
    var t: float = clampf(1.0 - distance / maxf(soft_radius, 0.0001), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

func _section_coordinate(point: Vector3) -> float:
    match section_axis:
        0:
            return point.x
        1:
            return point.y
        _:
            return point.z

func _passes_hard_normal_guard(surface_index: int, index: int, reference: Vector3) -> bool:
    var arr: Array = surfaces[surface_index]["arrays"]
    var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
    if normals.size() <= index:
        return true
    var candidate: Vector3 = normals[index]
    if candidate.length_squared() < 0.5 or reference.length_squared() < 0.5:
        return true
    return candidate.normalized().dot(reference.normalized()) >= cos(deg_to_rad(guard_angle_degrees))

func _build_influences(snapshot: Array) -> Array:
    var result: Array = []
    if not has_selection():
        return result
    var center: Vector3 = snapshot[selected_surface][selected_vertex]
    var reflected := Vector3(-center.x, center.y, center.z)
    var source_array: Array = surfaces[selected_surface]["arrays"]
    var source_normals: PackedVector3Array = source_array[Mesh.ARRAY_NORMAL] if source_array[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
    var reference_normal := Vector3.ZERO
    if source_normals.size() > selected_vertex:
        reference_normal = source_normals[selected_vertex]
    for s in range(snapshot.size()):
        var vertices: PackedVector3Array = snapshot[s]
        for i in range(vertices.size()):
            var pos: Vector3 = vertices[i]
            var mirrored := false
            var distance := pos.distance_to(center)
            # Only use the reflected brush on the opposite side of the X plane.
            if mirror_enabled and absf(center.x) > 0.0002 and pos.x * center.x < -0.000001:
                distance = pos.distance_to(reflected)
                mirrored = true
            var weight := 0.0
            var welded: bool = distance * distance <= WELD_EPSILON_SQUARED
            if soft_enabled:
                if soft_profile == 1:
                    var station_center: float = _section_coordinate(reflected if mirrored else center)
                    distance = absf(_section_coordinate(pos) - station_center)
                weight = _falloff(distance)
                if soft_profile == 2 and not welded:
                    var guard_normal: Vector3 = reference_normal
                    if mirrored:
                        guard_normal.x = -guard_normal.x
                    if not _passes_hard_normal_guard(s, i, guard_normal):
                        weight = 0.0
            elif welded:
                weight = 1.0
            # Keep UV seam duplicates together regardless of their normal orientation.
            if welded:
                weight = 1.0
            if weight <= 0.0:
                continue
            result.append({"surface": s, "index": i, "weight": weight, "mirrored": mirrored})
    return result

func apply_stroke_delta(delta: Vector3) -> void:
    if not _stroke_active:
        return
    for s in range(surfaces.size()):
        var arrays: Array = surfaces[s]["arrays"]
        arrays[Mesh.ARRAY_VERTEX] = _stroke_before[s].duplicate()
        surfaces[s]["arrays"] = arrays
    for influence in _stroke_influences:
        var s: int = influence["surface"]
        var index: int = influence["index"]
        var original: Vector3 = _stroke_before[s][index]
        var displacement: Vector3 = delta * float(influence["weight"])
        if bool(influence["mirrored"]):
            displacement.x = -displacement.x
        if mirror_enabled and absf(original.x) <= 0.0002:
            displacement.x = 0.0
        var vertices: PackedVector3Array = surfaces[s]["arrays"][Mesh.ARRAY_VERTEX]
        vertices[index] = original + displacement
        surfaces[s]["arrays"][Mesh.ARRAY_VERTEX] = vertices
    _stroke_changed = delta.length_squared() > 0.0000000001
    _rebuild()

func relax_selected(strength: float = 0.28) -> void:
    # Lightweight Laplacian relaxation of the influenced region.
    if not has_selection() or _stroke_active:
        return
    var before: Array = _snapshot()
    var influences: Array = _build_influences(before)
    var changes := 0
    for s in range(surfaces.size()):
        var arrays: Array = surfaces[s]["arrays"]
        var verts: PackedVector3Array = before[s]
        var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
        var neighbors: Array = []
        for i in range(verts.size()):
            neighbors.append([])
        var n: int = indices.size() if not indices.is_empty() else verts.size()
        for k in range(0, n - 2, 3):
            var a: int = indices[k] if not indices.is_empty() else k
            var b: int = indices[k + 1] if not indices.is_empty() else k + 1
            var c: int = indices[k + 2] if not indices.is_empty() else k + 2
            if a < 0 or b < 0 or c < 0 or a >= verts.size() or b >= verts.size() or c >= verts.size():
                continue
            neighbors[a].append(b)
            neighbors[a].append(c)
            neighbors[b].append(a)
            neighbors[b].append(c)
            neighbors[c].append(a)
            neighbors[c].append(b)
        var changed_vertices: PackedVector3Array = verts.duplicate()
        var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
        var normal_limit: float = cos(deg_to_rad(guard_angle_degrees))
        for influence in influences:
            if int(influence["surface"]) != s:
                continue
            var at: int = influence["index"]
            var near: Array = neighbors[at]
            if near.is_empty():
                continue
            var average := Vector3.ZERO
            var contributing := 0
            for neighbor_index in near:
                if soft_profile == 2 and normals.size() == verts.size():
                    var current_normal: Vector3 = normals[at]
                    var neighbor_normal: Vector3 = normals[neighbor_index]
                    if current_normal.length_squared() > 0.5 and neighbor_normal.length_squared() > 0.5:
                        if current_normal.normalized().dot(neighbor_normal.normalized()) < normal_limit:
                            continue
                average += verts[neighbor_index]
                contributing += 1
            if contributing == 0:
                continue
            average /= float(contributing)
            var blend: float = clampf(strength * float(influence["weight"]), 0.0, 1.0)
            var smoothed: Vector3 = verts[at].lerp(average, blend)
            if mirror_enabled and absf(verts[at].x) <= 0.0002:
                smoothed.x = 0.0
            if smoothed.distance_squared_to(verts[at]) > 0.000000000001:
                changed_vertices[at] = smoothed
                changes += 1
        arrays[Mesh.ARRAY_VERTEX] = changed_vertices
        surfaces[s]["arrays"] = arrays
    if changes > 0:
        _undo_stack.append(before)
        if _undo_stack.size() > MAX_HISTORY:
            _undo_stack.pop_front()
        _redo_stack.clear()
        _rebuild()
        _refresh_weld()
        edit_committed.emit()

func end_stroke() -> void:
    if not _stroke_active:
        return
    if _stroke_changed:
        _undo_stack.append(_stroke_before)
        if _undo_stack.size() > MAX_HISTORY:
            _undo_stack.pop_front()
        _redo_stack.clear()
        _refresh_weld()
        edit_committed.emit()
    _stroke_before = []
    _stroke_influences.clear()
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
    # Normal rebuilding is a destructive shading operation, not position history.
    _redo_stack.clear()
    for s in range(surfaces.size()):
        var arr: Array = surfaces[s]["arrays"]
        var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
        var indices: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
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
