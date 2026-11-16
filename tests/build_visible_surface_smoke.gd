extends SceneTree
## v0.9: independent geometry creation and exact dimensional editing,
## frontmost-only touch picking and textured preview material safety.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://main.tscn")
    if packed == null:
        _fail("Scene missing")
        return
    var app = packed.instantiate()
    root.add_child(app)
    await process_frame
    await process_frame

    if app.tab_buttons.size() != 5 or app.tool_panels.size() != 5:
        _fail("BUILD fifth tab absent")
        return
    if app.scene_environment == null or app.texture_detail_slider == null:
        _fail("Textured preview contrast controls absent")
        return
    if float(app.scene_environment.ambient_light_energy) >= 0.55:
        _fail("High washed-out ambient light still enabled by default")
        return
    var old_ambient: float = app.scene_environment.ambient_light_energy
    app._texture_detail_changed(1.0)
    if app.scene_environment.ambient_light_energy >= old_ambient:
        _fail("Textured contrast slider does not lower flat ambient light")
        return
    app._texture_detail_changed(0.7)
    var part0: MeshInstance3D = app.edit.target
    var old_mat: Material = part0.material_override
    app._show_tab(3)
    if part0.material_overlay != null or not app.selection_outline.visible:
        _fail("VIEW still washes texture with amber unshaded paint")
        return
    if part0.material_override != old_mat:
        _fail("VIEW lighting altered imported material")
        return

    app._show_tab(2)
    app.build_width.value = 2.40
    app.build_height.value = 1.20
    app.build_length.value = 3.60
    app.build_name.text = "EngineHousing"
    app.build_kind_picker.select(0)
    var count_before: int = app.mesh_nodes.size()
    app._add_object()
    if app.mesh_nodes.size() != count_before + 1:
        _fail("New object did not become part of editable scene")
        return
    var created: MeshInstance3D = app.edit.target
    if created.name != "EngineHousing" or created.mesh == null:
        _fail("Named independent BOX was not created")
        return
    if not _dimensions_match(app._part_local_dimensions(created), Vector3(2.40,1.20,3.60)):
        _fail("Created object does not have exact dimensions")
        return
    app._do_undo()
    if created.get_parent() != null or app.mesh_nodes.has(created):
        _fail("Create object cannot undo")
        return
    app._do_redo()
    if created.get_parent() == null or app.edit.target != created:
        _fail("Create object cannot redo")
        return

    app.build_width.value = 4.0
    app.build_height.value = 1.8
    app.build_length.value = 2.1
    app._apply_part_dimensions()
    if not _dimensions_match(app._part_local_dimensions(created), Vector3(4,1.8,2.1)):
        _fail("Exact part dimensions not applied to real mesh transform")
        return
    app._do_undo()
    if not _dimensions_match(app._part_local_dimensions(created), Vector3(2.4,1.2,3.6)):
        _fail("Dimension edit cannot undo")
        return
    app._do_redo()
    if not _dimensions_match(app._part_local_dimensions(created), Vector3(4,1.8,2.1)):
        _fail("Dimension edit cannot redo")
        return
    app._duplicate_selected_part()
    var copy: MeshInstance3D = app.edit.target
    if copy == created or copy.mesh == created.mesh:
        _fail("Duplicate uses shared mesh or wasn't created")
        return
    app._delete_selected_part()
    if app.mesh_nodes.has(copy) or copy.get_parent() != null:
        _fail("Delete part did not detach object")
        return
    app._do_undo()
    if not app.mesh_nodes.has(copy) or copy.get_parent() == null:
        _fail("Delete did not undo")
        return
    app._do_redo()
    if app.mesh_nodes.has(copy):
        _fail("Delete did not redo")
        return

    # Check each additional real mesh primitive and GLB round-trip.
    app.build_width.value = 0.75
    app.build_height.value = 1.65
    app.build_length.value = 0.95
    for kind in [1,2,3]:
        app.build_kind_picker.select(kind)
        app._add_object()
        var item: MeshInstance3D = app.edit.target
        if item.mesh == null or item.mesh.get_surface_count() < 1:
            _fail("Primitive %d failed to create geometry" % kind)
            return
        if not _dimensions_match(app._part_local_dimensions(item), Vector3(0.75,1.65,0.95)):
            _fail("Primitive %d dimensions incorrect" % kind)
            return
    var output := "user://model-forge-build-v09.glb"
    if not app._save_glb(output, false):
        _fail("GLB export failed after building and resizing")
        return
    var data: PackedByteArray = FileAccess.get_file_as_bytes(output)
    var document := GLTFDocument.new()
    var state := GLTFState.new()
    if data.size() < 12 or document.append_from_buffer(data, "", state) != OK:
        _fail("GLB re-import failed after adding primitives")
        return
    var scene: Node = document.generate_scene(state)
    if scene == null or _mesh_count(scene) < count_before + 4:
        _fail("GLB round trip lost independently added objects")
        return
    scene.free()

    # Front polygon must win even when far-side vertices project closer to
    # the finger. Also test that tapping outside every visible polygon fails.
    app._clear_asset()
    var group := Node3D.new()
    app.asset_host.add_child(group)
    var front := MeshInstance3D.new()
    front.name = "VisibleHood"
    front.mesh = _triangle(
        Vector3(-1.0,-1.0,0), Vector3(1.0,-1.0,0), Vector3(-1.0,1.0,0)
    )
    group.add_child(front)
    var rear := MeshInstance3D.new()
    rear.name = "InternalBracket"
    rear.mesh = _triangle(
        Vector3(-0.36,-0.36,-0.4), Vector3(0.3,-0.36,-0.4), Vector3(-0.36,0.3,-0.4)
    )
    group.add_child(rear)
    app._index_meshes()
    app._show_tab(0)
    app.orbit_center = Vector3.ZERO
    app.orbit_yaw = 0.0
    app.orbit_pitch = 0.0
    app.orbit_distance = 6.0
    app._update_camera()
    var touch_world := Vector3(-0.3, -0.3, 0)
    var canvas_position: Vector2 = app.camera.unproject_position(touch_world) * app.canvas.size / Vector2(app.scene_view.size)
    var hit: Dictionary = app._frontmost_triangle_at(canvas_position)
    if hit.is_empty() or hit["node"] != front:
        _fail("Actual nearest surface did not win touch ray")
        return
    app._choose_mesh(1)
    if not app._pick_vertex(canvas_position) or app.edit.target != front:
        _fail("Shape touch selected hidden rear mesh instead of visible skin")
        return
    var picked_local: Vector3 = app.edit.vertex_position()
    if absf(picked_local.z) > 0.0001:
        _fail("Interior vertex selected through outer surface")
        return
    print("MODEL_FORGE_BUILD: PASS 5 tabs, texture contrast, visible-only selection, primitives, dimensions, undo/redo, GLB")
    app.queue_free()
    quit(0)

func _triangle(a: Vector3, b: Vector3, c: Vector3) -> ArrayMesh:
    var data: Array = []
    data.resize(Mesh.ARRAY_MAX)
    data[Mesh.ARRAY_VERTEX] = PackedVector3Array([a,b,c])
    data[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2])
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
    return mesh

func _mesh_count(node: Node) -> int:
    var count := 1 if node is MeshInstance3D else 0
    for child in node.get_children():
        count += _mesh_count(child)
    return count

func _dimensions_match(a: Vector3, b: Vector3) -> bool:
    return a.distance_to(b) < 0.015

func _fail(reason: String) -> void:
    push_error("MODEL_FORGE_BUILD: FAIL " + reason)
    quit(1)
