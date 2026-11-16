extends SceneTree
## v0.7 tests precise face picking, non-destructive zebra and scrollable phone strips.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://main.tscn")
    if packed == null:
        _fail("Editor scene failed to load")
        return
    var app = packed.instantiate()
    root.add_child(app)
    await process_frame
    await process_frame

    if app.zebra_toggle == null or app.zebra_slider == null:
        _fail("Zebra controls are absent from VIEW")
        return
    var strip_count: int = _count_scroll_containers(app)
    if strip_count < 10:
        _fail("Only %d scrolling toolbar strips exist" % strip_count)
        return

    app._clear_asset()
    # Front triangle's bounding box includes (0.25,0.25), but the triangle
    # does not. The rear triangle actually covers that tap point.
    var front := MeshInstance3D.new()
    front.name = "FrontBoundingBoxDecoy"
    front.mesh = _tri(
        Vector3(-1.0,-1.0,0.0),
        Vector3(1.0,-1.0,0.0),
        Vector3(-1.0,1.0,0.0))
    var rear := MeshInstance3D.new()
    rear.name = "RearVisibleTriangle"
    rear.mesh = _tri(
        Vector3(0.10,0.10,-0.8),
        Vector3(0.85,0.10,-0.8),
        Vector3(0.10,0.85,-0.8))
    var group := Node3D.new()
    group.name = "PickingTestAssembly"
    app.asset_host.add_child(group)
    group.add_child(front)
    group.add_child(rear)
    app._index_meshes()
    app.orbit_center = Vector3.ZERO
    app.orbit_yaw = 0.0
    app.orbit_pitch = 0.0
    app.orbit_distance = 6.0
    app._update_camera()

    var chosen_world := Vector3(0.25, 0.25, -0.8)
    var tap: Vector2 = _screen_from_world(app, chosen_world)
    var origin: Vector3 = app.camera.project_ray_origin(app._canvas_to_viewport(tap))
    var direction: Vector3 = app.camera.project_ray_normal(app._canvas_to_viewport(tap))
    var from_front: float = app._ray_triangle_depth(front, origin, direction)
    var from_rear: float = app._ray_triangle_depth(rear, origin, direction)
    if from_front != INF or from_rear == INF:
        _fail("Triangle ray test still thinks front AABB is a real front surface")
        return
    app._show_tab(1)
    if not app._pick_part(tap) or app.edit.target != rear:
        _fail("Tap did not select the rear visible triangle")
        return
    if front.material_overlay != null or rear.material_overlay != app.selection_overlay_material:
        _fail("Selection tint did not follow the actually visible face")
        return

    # A genuine closer face must win when two parts overlap in projection.
    front.mesh = _tri(
        Vector3(0.10,0.10,0.0),
        Vector3(0.85,0.10,0.0),
        Vector3(0.10,0.85,0.0))
    if not app._pick_part(tap) or app.edit.target != front:
        _fail("Depth-correct triangle selection ignored frontmost mesh")
        return

    app._show_tab(3)
    var old_front: Material = front.material_override
    var old_rear: Material = rear.material_override
    app._set_zebra(true)
    if not app.zebra_enabled or app.zebra_material == null:
        _fail("Zebra mode failed to activate")
        return
    if front.material_override != app.zebra_material or rear.material_override != app.zebra_material:
        _fail("Zebra inspection is not visible across all parts")
        return
    if app.selected_overlay_mesh != null or front.material_overlay != null:
        _fail("Amber tint obscures zebra surface reflection bands")
        return
    if not app.selection_outline.visible:
        _fail("Part outline was lost in zebra mode")
        return
    app._zebra_bands_changed(19.0)
    if absf(float(app.zebra_material.get_shader_parameter("stripe_density")) - 19.0) > 0.001:
        _fail("Zebra density slider isn't wired")
        return

    var output := "user://model-forge-v07-zebra-test.glb"
    if not app._save_glb(output, false):
        _fail("GLB export failed with zebra inspection enabled")
        return
    if not app.zebra_enabled or front.material_override != app.zebra_material:
        _fail("Export did not restore visual-only inspection")
        return
    var bytes := FileAccess.get_file_as_bytes(output)
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    if bytes.size() < 12 or doc.append_from_buffer(bytes, "", state) != OK:
        _fail("Exported GLB cannot be reopened")
        return
    var imported: Node = doc.generate_scene(state)
    if imported == null:
        _fail("Exported GLB has no scene")
        return
    if _contains_shader_overlay(imported):
        _fail("Export included temporary amber or zebra inspection material")
        return
    imported.free()

    app._set_zebra(false)
    if app.zebra_enabled or front.material_override != old_front or rear.material_override != old_rear:
        _fail("Zebra OFF did not restore existing materials")
        return
    if front.material_overlay != app.selection_overlay_material:
        _fail("Selected highlight was not restored after Zebra OFF")
        return
    app._set_zebra(true)
    app._set_clay(true)
    if app.zebra_enabled or !app.clay_enabled:
        _fail("Clay and Zebra modes should not overlap")
        return
    app._set_clay(false)

    print("MODEL_FORGE_PRECISION: PASS precise triangle selection, 10+ swipe strips, zebra, GLB cleanliness")
    app.queue_free()
    quit(0)

func _tri(a: Vector3, b: Vector3, c: Vector3) -> ArrayMesh:
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([a,b,c])
    arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2])
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

func _screen_from_world(app: Control, world: Vector3) -> Vector2:
    return app.camera.unproject_position(world) * app.canvas.size / Vector2(app.scene_view.size)

func _count_scroll_containers(root_node: Node) -> int:
    var count := 1 if root_node is ScrollContainer else 0
    for child in root_node.get_children():
        if child is SubViewport:
            continue
        count += _count_scroll_containers(child)
    return count

func _contains_shader_overlay(node: Node) -> bool:
    if node is MeshInstance3D:
        if node.material_override is ShaderMaterial or node.material_overlay is ShaderMaterial:
            return true
        if node.material_overlay != null:
            return true
    for child in node.get_children():
        if _contains_shader_overlay(child):
            return true
    return false

func _fail(why: String) -> void:
    push_error("MODEL_FORGE_PRECISION: FAIL " + why)
    quit(1)
