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
    if bounds.size.x < 25.0 or bounds.size.y < 50.0:
        _fail("Tab bounds invalid: " + str(bounds))
        return

    # Android's emulated left-click should reach the GUI button.
    var down := InputEventMouseButton.new()
    down.button_index = MOUSE_BUTTON_LEFT
    down.pressed = true
    down.position = bounds.get_center()
    Input.parse_input_event(down)
    await process_frame
    var up := InputEventMouseButton.new()
    up.button_index = MOUSE_BUTTON_LEFT
    up.pressed = false
    up.position = bounds.get_center()
    Input.parse_input_event(up)
    await process_frame
    if app.active_tab != 1:
        _fail("Mouse tap did not switch to MOVE; active=" + str(app.active_tab))
        return

    var view_button: Button = app.tab_buttons[2]
    bounds = view_button.get_global_rect()
    down.position = bounds.get_center()
    up.position = bounds.get_center()
    Input.parse_input_event(down)
    await process_frame
    Input.parse_input_event(up)
    await process_frame
    if app.active_tab != 2:
        _fail("Mouse tap did not switch to VIEW; active=" + str(app.active_tab))
        return
    if app.pointer_down or app.pointer_dragging_vertex:
        _fail("Tab switching caused a latched viewport drag")
        return

    print("MODEL_FORGE_GUI: PASS simulated button taps MOVE/VIEW, safe idle navigation")
    app.queue_free()
    quit(0)

func _fail(reason: String) -> void:
    push_error("MODEL_FORGE_GUI: FAIL " + reason)
    quit(1)
