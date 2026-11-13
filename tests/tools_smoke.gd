extends SceneTree
## User-facing tool regression: editable geometry, soft brush, symmetry, UI tabs.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene = load("res://main.tscn")
    if scene == null:
        _fail("main scene cannot load")
        return
    var app = scene.instantiate()
    root.add_child(app)
    if app.tool_panels.size() != 4 or app.tab_buttons.size() != 4:
        _fail("four-tool layout not initialized")
        return
    for button in app.tab_buttons:
        if button.custom_minimum_size.y < 55:
            _fail("tool tab touch target too small")
            return
    if not bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch")):
        _fail("Android touch-to-mouse emulation is disabled")
        return
    if app.edit_toggle.button_pressed:
        _fail("editor starts with accidental pull/edit mode armed")
        return
    app._show_tab(2)
    if app.edit_toggle.button_pressed:
        _fail("view mode still edits vertices")
        return
    app._show_tab(0)
    if app.edit_toggle.button_pressed:
        _fail("shape tab auto-arms vertex pulling")
        return
    app.edit_toggle.button_pressed = true
    if not app.edit_toggle.button_pressed:
        _fail("explicit EDIT POINTS toggle does not engage")
        return
    app._show_tab(1)
    if app.edit_toggle.button_pressed:
        _fail("changing tool tabs leaves vertex drag armed")
        return

    var editor = app.edit
    if not editor.select_vertex(0, 0):
        _fail("demo vertex missing")
        return
    var source: PackedVector3Array = editor.surfaces[0]["arrays"][Mesh.ARRAY_VERTEX]
    var center: Vector3 = source[0]
    var neighbor: Vector3 = source[1]
    var far: Vector3 = source[12]
    editor.mirror_enabled = false
    editor.soft_enabled = true
    editor.soft_radius = 1.0
    editor.move_step(Vector3(0.0, 0.20, 0.0))
    var result: PackedVector3Array = editor.surfaces[0]["arrays"][Mesh.ARRAY_VERTEX]
    if result[0].distance_to(center + Vector3(0, 0.2, 0)) > 0.0001:
        _fail("soft brush did not fully move selected vertex")
        return
    if result[1].y <= neighbor.y or result[1].y >= neighbor.y + 0.2:
        _fail("soft brush does not fall off smoothly")
        return
    if result[12].distance_to(far) > 0.0001:
        _fail("soft brush moved far-away vertex")
        return
    editor.undo()
    if editor.vertex_position().distance_to(center) > 0.0001:
        _fail("soft brush could not undo")
        return

    editor.soft_enabled = false
    editor.mirror_enabled = true
    var opposite: Vector3 = editor.surfaces[0]["arrays"][Mesh.ARRAY_VERTEX][2]
    editor.move_step(Vector3(0.07, 0.03, 0.0))
    result = editor.surfaces[0]["arrays"][Mesh.ARRAY_VERTEX]
    if result[2].distance_to(opposite + Vector3(-0.07, 0.03, 0)) > 0.0001:
        _fail("mirror mode did not reflect the X delta")
        return
    editor.undo()
    if editor.vertex_position().distance_to(center) > 0.0001:
        _fail("mirror mode could not undo")
        return

    editor.mirror_enabled = false
    editor.soft_enabled = true
    editor.soft_radius = 1.0
    editor.relax_selected(0.4)
    if editor.vertex_position().distance_to(center) < 0.00001:
        _fail("smooth tool did not change vertex")
        return
    editor.undo()
    if editor.vertex_position().distance_to(center) > 0.0001:
        _fail("smooth tool could not undo")
        return
    print("MODEL_FORGE_TOOLS: PASS touch emulation + explicit navigation/edit safety + soft falloff + mirror + smooth + undo")
    app.queue_free()
    quit(0)

func _fail(reason: String) -> void:
    push_error("MODEL_FORGE_TOOLS: FAIL " + reason)
    quit(1)
