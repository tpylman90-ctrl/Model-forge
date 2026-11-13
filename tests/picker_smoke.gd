extends SceneTree
## Checks import/export call paths used by the Android native picker callback.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var source: PackedScene = load("res://main.tscn")
    if source == null:
        _fail("Cannot load editor")
        return
    var app = source.instantiate()
    root.add_child(app)
    var target := "user://picker-test-model.glb"
    app._native_picker_result(true, PackedStringArray([target]), 0, "save")
    if not FileAccess.file_exists(target):
        _fail("Native save callback did not create a GLB")
        return
    var f := FileAccess.open(target, FileAccess.READ)
    if f == null:
        _fail("Cannot reopen exported file")
        return
    var header := f.get_buffer(4).get_string_from_ascii()
    f.close()
    if header != "glTF":
        _fail("Exported file has invalid header")
        return
    app._native_picker_result(true, PackedStringArray([target]), 0, "open")
    if app.mesh_nodes.is_empty() or app.edit.target == null:
        _fail("Native open callback did not load exported GLB")
        return
    var photo := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
    photo.fill(Color.CYAN)
    var photo_file := "user://picker-test-photo.png"
    if photo.save_png(photo_file) != OK:
        _fail("Cannot create reference image for test")
        return
    app._native_picker_result(true, PackedStringArray([photo_file]), 0, "photo")
    if app.reference_preview.texture == null:
        _fail("Native photo selection did not load image")
        return
    var previous: int = app.mesh_nodes.size()
    app._native_picker_result(false, PackedStringArray(), 0, "open")
    if app.mesh_nodes.size() != previous:
        _fail("Cancel unexpectedly discarded the loaded model")
        return
    print("MODEL_FORGE_PICKER: PASS native callback GLB save/open, photo, cancel")
    app.queue_free()
    quit(0)

func _fail(reason: String) -> void:
    push_error("MODEL_FORGE_PICKER: FAIL " + reason)
    quit(1)
