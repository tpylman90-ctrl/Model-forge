extends SceneTree
## Editing workflow regression on Android-first v0.4 UI:
## part movement, undo/redo across parts, non-destructive inspection and draft.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene = load("res://main.tscn")
    if scene == null:
        _fail("main.tscn unavailable")
        return
    var app = scene.instantiate()
    root.add_child(app)
    if app.tab_buttons.size() != 4 or app.move_target_picker == null:
        _fail("four-tab mobile editor not initialized")
        return
    if not bool(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand"):
        _fail("UI is not configured for variable-width phone screens")
        return
    if app.move_target_picker.selected != 1:
        _fail("part movement should be the default precision mode")
        return
    if app.mesh_nodes.size() < 2:
        _fail("demo model does not have multiple selectable parts")
        return
    var part0: MeshInstance3D = app.mesh_nodes[0]
    var part1: MeshInstance3D = app.mesh_nodes[1]
    app._choose_mesh(0)
    var editor0 = app.edit
    var part_before: Transform3D = part0.transform
    app._nudge(Vector3.RIGHT)
    if part0.position.distance_to(part_before.origin + Vector3(0.10, 0.0, 0.0)) > 0.00001:
        _fail("whole-part X movement was not applied")
        return
    app._do_undo()
    if part0.transform != part_before:
        _fail("whole-part move undo failed")
        return
    app._do_redo()
    if part0.position.distance_to(part_before.origin + Vector3(0.10, 0.0, 0.0)) > 0.00001:
        _fail("whole-part move redo failed")
        return

    app._choose_mesh(1)
    var editor1 = app.edit
    app._choose_mesh(0)
    if editor0 != app.edit or editor1 == app.edit:
        _fail("switching parts discarded previous geometry edit session")
        return
    app.move_target_picker.select(0)
    var start_point: Vector3 = app.edit.vertex_position()
    app.edit.move_step(Vector3(0.05, 0.02, 0.0))
    if app.edit.vertex_position().distance_to(start_point + Vector3(0.05, 0.02, 0.0)) > 0.00001:
        _fail("point mode no longer edits geometry")
        return
    app._choose_mesh(1)
    app._do_undo()
    if app.edit.target != part0 or app.edit.vertex_position().distance_to(start_point) > 0.00001:
        _fail("cross-part geometry undo failed")
        return
    app._do_redo()
    if app.edit.vertex_position().distance_to(start_point + Vector3(0.05, 0.02, 0.0)) > 0.00001:
        _fail("cross-part geometry redo failed")
        return

    var original_override: Material = part0.material_override
    app._set_clay(true)
    if not app.clay_enabled or part0.material_override == original_override:
        _fail("non-destructive clay preview did not apply")
        return
    app._wire_changed(true)
    if app.wire_preview.mesh == null or app.wire_preview.mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_LINES:
        _fail("wireframe is not drawing actual triangle edges")
        return
    if not app._save_glb("user://model-forge-workflow-export.glb", false):
        _fail("GLB export failed with inspection overlay active")
        return
    if not app.clay_enabled:
        _fail("export unexpectedly cleared clay preview")
        return
    app._set_clay(false)
    if part0.material_override != original_override:
        _fail("clay preview did not restore original materials")
        return

    app._choose_mesh(0)
    app._toggle_isolate()
    if not app.isolate_active or part1.visible:
        _fail("solo view failed to hide other parts")
        return
    if not app._save_glb("user://model-forge-workflow-solo.glb", false):
        _fail("export failed in solo mode")
        return
    if app.isolate_active or not part1.visible:
        _fail("solo view was accidentally preserved in model export")
        return

    app._mark_dirty()
    app._save_draft()
    if not FileAccess.file_exists("user://model-forge-working-draft.glb"):
        _fail("local working draft was not created")
        return
    app._restore_draft()
    if app.project_name != "Recovered draft" or app.mesh_nodes.size() < 2:
        _fail("local draft was not restored")
        return
    if not app.dirty:
        _fail("restored draft must still require a permanent GLB export")
        return

    print("MODEL_FORGE_WORKFLOW: PASS part edit, history, real wire, clay, solo, draft, full-width UI")
    app.queue_free()
    quit(0)

func _fail(reason: String) -> void:
    push_error("MODEL_FORGE_WORKFLOW: FAIL " + reason)
    quit(1)
