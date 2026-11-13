extends SceneTree
## CI: boot the editor, move mesh vertex, undo/redo, export and re-import.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://main.tscn")
    if packed == null:
        _fail("main scene could not load")
        return
    var editor_ui = packed.instantiate()
    root.add_child(editor_ui)
    var editor = editor_ui.edit
    if editor.target == null or editor.vertex_count() < 12:
        _fail("demo mesh not initialized")
        return
    var original: Vector3 = editor.vertex_position()
    var delta := Vector3(0.08, 0.04, 0.03)
    editor.move_step(delta)
    if editor.vertex_position().distance_to(original + delta) > 0.00001:
        _fail("vertex translation not applied")
        return
    editor.undo()
    if editor.vertex_position().distance_to(original) > 0.00001:
        _fail("undo did not restore original position")
        return
    editor.redo()
    if editor.vertex_position().distance_to(original + delta) > 0.00001:
        _fail("redo did not apply translation")
        return
    var document := GLTFDocument.new()
    var state := GLTFState.new()
    var status := document.append_from_scene(editor_ui.asset_host, state)
    if status != OK:
        _fail("glTF export failed: " + str(status))
        return
    var glb := document.generate_buffer(state)
    if glb.size() < 32 or glb.slice(0, 4).get_string_from_ascii() != "glTF":
        _fail("exported data does not have GLB header")
        return
    var import_document := GLTFDocument.new()
    var import_state := GLTFState.new()
    if import_document.append_from_buffer(glb, "", import_state) != OK:
        _fail("GLB re-import failed")
        return
    if import_document.generate_scene(import_state) == null:
        _fail("GLB re-import generated empty scene")
        return
    print("MODEL_FORGE_SMOKE: PASS vertex edit / undo / redo / GLB round trip")
    quit(0)

func _fail(reason: String) -> void:
    push_error("MODEL_FORGE_SMOKE: FAIL " + reason)
    quit(1)
