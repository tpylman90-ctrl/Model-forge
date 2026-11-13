extends SceneTree
## Simulate real Godot GUI tap routing, rather than directly calling callbacks.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene = load("res://main.tscn")
    if scene == null:
        _fail("Could not load main scene")
        return
    var app = scene.instantiate()
    root.add_child(app)
    await process_frame
    await process_frame
    if app.active_tab != 0:
        _fail("Startup tab is not SHAPE")
        return
    if app.edit_toggle.button_pressed:
        _fail("App booted in pull/edit mode")
        return
    if not bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", false)):
        _fail("Touch-to-mouse emulation disabled")
        return
    var button: Button = app.tab_buttons[1]
    var bounds: Rect2 = button.get_global_rect()
    print("MODEL_FORGE_GUI: root=", root.size, " move_rect=", bounds)
    if bounds.size.x < 25.0 or bounds.size.y < 50.0:
        _fail("Tab bounds invalid: " + str(bounds))
        return

    # Android's emulated left-click should reach the GUI button.
    var down := InputEventMouseButton.new()
    down.button_index = MOUSE_BUTTON_LEFT
    down.pressed = true
    down.position = bounds.get_center()
    down.global_position = down.position
    root.push_input(down, true)
    await process_frame
    var up := InputEventMouseButton.new()
    up.button_index = MOUSE_BUTTON_LEFT
    up.pressed = false
    up.position = bounds.get_center()
    up.global_position = up.position
    root.push_input(up, true)
    await process_frame
    if app.active_tab != 1:
        _fail("Mouse tap did not switch to MOVE; active=" + str(app.active_tab))
        return

    var view_button: Button = app.tab_buttons[2]
    bounds = view_button.get_global_rect()
    down.position = bounds.get_center()
    up.position = bounds.get_center()
    root.push_input(down, true)
    await process_frame
    root.push_input(up, true)
    await process_frame
    if app.active_tab != 2:
        _fail("Mouse tap did not switch to VIEW; active=" + str(app.active_tab))
        return
    if app.pointer_down or app.pointer_dragging_vertex:
        _fail("Tab switching caused a latched viewport drag")
        return

    # Test the real OPEN GLB toolbar surface, not just its callback.
    var open_button: Button = app.open_button
    var open_bounds: Rect2 = open_button.get_global_rect()
    if open_bounds.size.x < 80.0 or open_bounds.size.y < 50.0:
        _fail("OPEN GLB touch target is too small: " + str(open_bounds))
        return
    var requests_before: int = app.open_requests
    down.position = open_bounds.get_center()
    down.global_position = down.position
    up.position = down.position
    up.global_position = up.position
    root.push_input(down, true)
    await process_frame
    root.push_input(up, true)
    await process_frame
    if app.open_requests != requests_before + 1:
        _fail("OPEN GLB button did not receive a GUI tap")
        return
    if app.last_picker_route != "fallback":
        _fail("Headless picker should use fallback; got " + app.last_picker_route)
        return
    if not app.open_dialog.visible:
        _fail("OPEN GLB tapped but fallback dialog did not appear")
        return
    app.open_dialog.hide()
    print("MODEL_FORGE_GUI: PASS tabs, OPEN GLB tap and fallback dialog")
    app.queue_free()
    quit(0)

func _fail(reason: String) -> void:
    push_error("MODEL_FORGE_GUI: FAIL " + reason)
    quit(1)
