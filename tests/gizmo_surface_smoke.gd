extends SceneTree
## Regression for touch gizmos, station-section falloff, and sharp-edge safety.
const MeshEdit = preload("res://scripts/mesh_editor.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://main.tscn")
    if packed == null:
        _fail("Could not load Model Forge")
        return
    var app = packed.instantiate()
    root.add_child(app)
    await process_frame
    await process_frame

    app._show_tab(1)
    if app.gizmo_root == null or not app.gizmo_root.visible:
        _fail("3D touch handles are not visible in MOVE mode")
        return
    if app.move_target_picker.selected != 1:
        _fail("MOVE should default to whole-part handling")
        return

    var node: MeshInstance3D = app.edit.target
    var original: Transform3D = node.transform
    var start: Vector2 = _grip_screen(app, 0)
    if app._pick_gizmo_axis(start) != 0:
        _fail("X gizmo grip is not selectable via screen-space hit testing")
        return
    var travel: Vector2 = _screen_axis(app, 0).normalized() * 56.0
    app._pointer_start(start)
    if not app.gizmo_drag_active:
        _fail("X gizmo pointer down did not start drag")
        return
    app._pointer_move(start + travel)
    app._pointer_end()
    if node.position.x <= original.origin.x + 0.005:
        _fail("X gizmo drag did not translate part in +X")
        return
    if absf(node.position.y - original.origin.y) > 0.00001 or absf(node.position.z - original.origin.z) > 0.00001:
        _fail("Axis-constrained gizmo unexpectedly moved Y or Z")
        return
    if app.gizmo_drag_active:
        _fail("Gizmo remained latched after touch release")
        return
    app._do_undo()
    if not node.transform.is_equal_approx(original):
        _fail("Gizmo part movement did not undo")
        return
    app._do_redo()
    if node.position.x <= original.origin.x + 0.005:
        _fail("Gizmo part movement did not redo")
        return

    # The same handles must move mesh points instead of parts in POINT mode.
    app.move_target_picker.select(0)
    app._move_target_changed(0)
    var before_point: Vector3 = app.edit.vertex_position()
    var before_transform: Transform3D = node.transform
    start = _grip_screen(app, 2)
    if app._pick_gizmo_axis(start) != 2:
        _fail("Z point handle not selectable")
        return
    travel = _screen_axis(app, 2).normalized() * 60.0
    app._pointer_start(start)
    app._pointer_move(start + travel)
    app._pointer_end()
    if app.edit.vertex_position().z <= before_point.z + 0.005:
        _fail("Z gizmo drag did not move selected mesh vertex")
        return
    if not node.transform.is_equal_approx(before_transform):
        _fail("Vertex gizmo changed entire part transform")
        return
    app._do_undo()
    if app.edit.vertex_position().distance_to(before_point) > 0.00001:
        _fail("Gizmo vertex edit cannot undo")
        return

    app._show_tab(0)
    var model_editor = app.edit
    model_editor.select_vertex(0, 0)
    model_editor.soft_enabled = true
    model_editor.soft_profile = 1
    model_editor.section_axis = 2
    model_editor.soft_radius = 0.8
    var source: PackedVector3Array = model_editor.surfaces[0]["arrays"][Mesh.ARRAY_VERTEX]
    var station_neighbor: Vector3 = source[2]
    var distant_station: Vector3 = source[3]
    model_editor.move_step(Vector3(0, 0.2, 0))
    var changed: PackedVector3Array = model_editor.surfaces[0]["arrays"][Mesh.ARRAY_VERTEX]
    if absf(changed[2].y - station_neighbor.y - 0.2) > 0.00001:
        _fail("Body section failed to move the entire same-Z station")
        return
    if changed[3].distance_to(distant_station) > 0.00001:
        _fail("Body section deformed geometry beyond its longitudinal width")
        return
    model_editor.undo()

    # Edge guard uses imported custom vertex normals and preserves sharp changes.
    var test_instance := MeshInstance3D.new()
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
        Vector3.ZERO, Vector3(0.5, 0, 0), Vector3(0, 0.5, 0), Vector3(0.5, 0.5, 0)
    ])
    arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
        Vector3.UP, Vector3.UP, Vector3.RIGHT, Vector3.RIGHT
    ])
    arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2])
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    test_instance.mesh = mesh
    app.scene_world.add_child(test_instance)
    var guard_editor = MeshEdit.new()
    if not guard_editor.set_target(test_instance) or not guard_editor.select_vertex(0, 0):
        _fail("Could not initialize synthetic crease-guard mesh")
        return
    guard_editor.soft_enabled = true
    guard_editor.soft_profile = 2
    guard_editor.soft_radius = 1.0
    guard_editor.move_step(Vector3(0, 0, 0.2))
    var after_guard: PackedVector3Array = guard_editor.surfaces[0]["arrays"][Mesh.ARRAY_VERTEX]
    if after_guard[1].z < 0.01:
        _fail("Normal-compatible neighbor did not follow guarded shaping")
        return
    if absf(after_guard[2].z) > 0.00001:
        _fail("Hard-edge guard crossed a 90-degree normal discontinuity")
        return
    guard_editor.undo()
    if absf(guard_editor.surfaces[0]["arrays"][Mesh.ARRAY_VERTEX][1].z) > 0.00001:
        _fail("Guarded deformation did not undo")
        return

    print("MODEL_FORGE_GIZMO: PASS part+vertex handles, release safety, undo, section brush, guarded creases")
    app.queue_free()
    quit(0)

func _grip_screen(app: Control, axis: int) -> Vector2:
    var view_point: Vector2 = app.camera.unproject_position(app.gizmo_root.tip_world(axis))
    return view_point * app.canvas.size / Vector2(app.scene_view.size)

func _screen_axis(app: Control, axis: int) -> Vector2:
    var origin: Vector2 = app.camera.unproject_position(app.gizmo_root.center_world())
    var tip: Vector2 = app.camera.unproject_position(app.gizmo_root.tip_world(axis))
    return (tip - origin) * app.canvas.size / Vector2(app.scene_view.size)

func _fail(message: String) -> void:
    push_error("MODEL_FORGE_GIZMO: FAIL " + message)
    quit(1)
