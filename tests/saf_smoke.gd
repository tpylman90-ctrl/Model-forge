extends SceneTree
## Tests the Godot integration with the native SAF bridge's result signals.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var source: PackedScene = load("res://main.tscn")
    if source == null:
        _fail("Could not load editor")
        return
    var app = source.instantiate()
    root.add_child(app)
    var model := "user://saf-test-vehicle.glb"
    app._save_glb(model)
    if not FileAccess.file_exists(model):
        _fail("Could not write test model")
        return
    app._android_document_result("model", model, "ok")
    if app.mesh_nodes.size() < 2 or app.edit.target == null:
        _fail("Native document bridge callback did not import model")
        return
    var old_count: int = app.mesh_nodes.size()
    app._android_document_result("model", "", "canceled")
    if app.mesh_nodes.size() != old_count:
        _fail("Cancel erased existing model")
        return
    app._android_document_result("model", "", "error: cannot open document")
    if app.status_label.text.find("error:") == -1:
        _fail("Android file error was presented as cancellation")
        return
    var photo := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
    photo.fill(Color.BLUE)
    var photo_path := "user://saf-test-photo.image"
    if photo.save_png(photo_path) != OK:
        _fail("Cannot create extensionless photo test")
        return
    app._android_document_result("photo", photo_path, "ok")
    if app.reference_preview.texture == null:
        _fail("Extensionless photo stream not displayed")
        return
    app._android_document_result("save", "content://android.documents/fake", "ok")
    if not app.status_label.text.contains("saved"):
        _fail("Native save status not communicated")
        return
    print("MODEL_FORGE_SAF: PASS callback import, photo stream, save and error handling")
    app.queue_free()
    quit(0)

func _fail(msg: String) -> void:
    push_error("MODEL_FORGE_SAF: FAIL " + msg)
    quit(1)
