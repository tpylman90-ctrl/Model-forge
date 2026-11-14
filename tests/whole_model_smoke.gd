extends SceneTree
## v0.6 regression: 100+ part identification and whole-model transforms/export.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene = load("res://main.tscn")
    if scene == null:
        _fail("Editor scene missing")
        return
    var app = scene.instantiate()
    root.add_child(app)
    await process_frame
    await process_frame
    if app.highlight_toggle == null or not app.highlight_toggle.button_pressed:
        _fail("Highlight not enabled by default")
        return
    if app.selection_outline == null:
        _fail("Selection outline not initialized")
        return

    # Synthetic GLB-like assembly: 120 distinct named components in two root nodes.
    var root_a: Node3D = app.asset_host.get_child(0)
    var root_b := Node3D.new()
    root_b.name = "AdditionalAssemblyRoot"
    root_b.position = Vector3(4, 0, 0)
    app.asset_host.add_child(root_b)
    var shared: Mesh = BoxMesh.new()
    for i in range(120):
        var part := MeshInstance3D.new()
        part.name = "Panel_%03d" % i
        part.mesh = shared
        part.position = Vector3(float(i % 12) * 0.15, float(i / 12) * 0.08, float(i % 5) * 0.20)
        root_b.add_child(part)
    app._index_meshes()
    if app.mesh_nodes.size() < 124 or app.filtered_mesh_indices.size() < 124:
        _fail("Part list failed to index 120+ meshes")
        return

    var first: MeshInstance3D = app.mesh_nodes[0]
    app._choose_mesh(0)
    if first.material_overlay != app.selection_overlay_material or not app.selection_outline.visible:
        _fail("Selected part has no tint or outline")
        return
    var second: MeshInstance3D = app.mesh_nodes[1]
    app._choose_mesh(1)
    if first.material_overlay != null or second.material_overlay != app.selection_overlay_material:
        _fail("Part selection failed to clear the previous highlight")
        return

    app.part_search.text = "Panel_097"
    app._part_search_changed(app.part_search.text)
    if app.filtered_mesh_indices.size() != 1 or app.edit.target.name != "Panel_097":
        _fail("Find part did not select the correct component")
        return
    if app.mesh_picker.get_item_count() != 1:
        _fail("Part search did not filter dropdown entries")
        return
    app.part_search.text = ""
    app._part_search_changed("")
    if app.filtered_mesh_indices.size() != app.mesh_nodes.size():
        _fail("Clearing search failed to restore all components")
        return
    if app.selected_mesh_index != app.mesh_nodes.find(app.edit.target):
        _fail("Filtered part selection index is wrong")
        return
    app._highlight_toggled(false)
    if app.selection_outline.visible or app.edit.target.material_overlay != null:
        _fail("Highlight OFF did not clear non-destructive overlay")
        return
    app._highlight_toggled(true)
    if not app.selection_outline.visible or app.edit.target.material_overlay == null:
        _fail("Highlight ON did not restore selection")
        return

    app._show_tab(1)
    app.move_target_picker.select(2)
    app._move_target_changed(2)
    if app.part_info_label.text.find("ALL") < 0 or not app.selection_outline.visible:
        _fail("Whole-model selection has no visible group indication")
        return
    if app.edit.target.material_overlay != null:
        _fail("Whole-model mode should not tint just one component")
        return
    var a_before: Transform3D = root_a.transform
    var b_before: Transform3D = root_b.transform
    app._nudge(Vector3.RIGHT)
    if root_a.position.distance_to(a_before.origin + Vector3(0.10,0,0)) > 0.00001:
        _fail("Whole model X move did not affect first GLB root")
        return
    if root_b.position.distance_to(b_before.origin + Vector3(0.10,0,0)) > 0.00001:
        _fail("Whole model X move did not affect second GLB root")
        return
    app._do_undo()
    if not root_a.transform.is_equal_approx(a_before) or not root_b.transform.is_equal_approx(b_before):
        _fail("Whole-model move did not undo all roots")
        return
    app._do_redo()
    if root_b.position.distance_to(b_before.origin + Vector3(0.10,0,0)) > 0.00001:
        _fail("Whole-model move did not redo")
        return

    var before_rotate: Transform3D = root_b.transform
    app._rotate_part(5.0)
    if root_b.transform.is_equal_approx(before_rotate):
        _fail("Whole model rotation changed nothing")
        return
    app._do_undo()
    if not root_b.transform.is_equal_approx(before_rotate):
        _fail("Whole model rotation could not undo")
        return
    app._do_redo()
    var before_scale: Transform3D = root_b.transform
    app._scale_part(1.05)
    if root_b.transform.is_equal_approx(before_scale):
        _fail("Whole model scaling changed nothing")
        return
    app._do_undo()
    if not root_b.transform.is_equal_approx(before_scale):
        _fail("Whole model scaling could not undo")
        return

    var touch_start: Vector2 = _grip_screen(app, 1)
    if app._pick_gizmo_axis(touch_start) != 1:
        _fail("Whole-model gizmo not selectable")
        return
    var before_drag: Transform3D = root_a.transform
    var axis_vector: Vector2 = _screen_axis(app, 1)
    if axis_vector.length_squared() <= 1.0:
        _fail("Whole-model gizmo projected size too small")
        return
    app._pointer_start(touch_start)
    app._pointer_move(touch_start + axis_vector.normalized() * 60.0)
    app._pointer_end()
    if root_a.transform.is_equal_approx(before_drag):
        _fail("Whole-model on-screen handle did not move assembly")
        return
    app._do_undo()
    if not root_a.transform.is_equal_approx(before_drag):
        _fail("Whole-model gizmo drag cannot undo")
        return

    # Inspections cannot contaminate exported GLB materials or mesh selection.
    var export_file := "user://model-forge-whole-model-test.glb"
    if not app._save_glb(export_file, false):
        _fail("Export failed with model group highlight enabled")
        return
    var glb := FileAccess.get_file_as_bytes(export_file)
    if glb.size() < 100 or glb.slice(0,4).get_string_from_ascii() != "glTF":
        _fail("Export GLB bytes invalid")
        return
    var document := GLTFDocument.new()
    var state := GLTFState.new()
    if document.append_from_buffer(glb, "", state) != OK:
        _fail("Cannot re-import highlighted model GLB")
        return
    var imported: Node = document.generate_scene(state)
    if imported == null:
        _fail("Exported assembly has no scene")
        return
    var imported_parts: int = _count_meshes(imported)
    if imported_parts < 124:
        _fail("Whole-model editing/export lost meshes: " + str(imported_parts))
        return
    imported.free()
    app._show_tab(0)
    if app.edit.target.material_overlay != app.selection_overlay_material:
        _fail("Selected part highlight did not return on Shape tab")
        return

    print("MODEL_FORGE_ASSEMBLY: PASS 124+ parts, search, tint, outline, whole-model XYZ/rotate/scale/gizmo/undo/GLB")
    app.queue_free()
    quit(0)

func _count_meshes(node: Node) -> int:
    var result := 1 if node is MeshInstance3D else 0
    for child in node.get_children():
        result += _count_meshes(child)
    return result

func _grip_screen(app: Control, axis: int) -> Vector2:
    var point: Vector2 = app.camera.unproject_position(app.gizmo_root.tip_world(axis))
    return point * app.canvas.size / Vector2(app.scene_view.size)

func _screen_axis(app: Control, axis: int) -> Vector2:
    var origin: Vector2 = app.camera.unproject_position(app.gizmo_root.center_world())
    var tip: Vector2 = app.camera.unproject_position(app.gizmo_root.tip_world(axis))
    return (tip-origin) * app.canvas.size / Vector2(app.scene_view.size)

func _fail(message: String) -> void:
    push_error("MODEL_FORGE_ASSEMBLY: FAIL " + message)
    quit(1)
