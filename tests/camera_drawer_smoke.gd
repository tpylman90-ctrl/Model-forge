extends SceneTree
## v0.9.2: the right joystick controls ONLY camera orbit, and the bottom
## drawer collapses to a reachable tab without losing active editor state.

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
    await process_frame
    if app.camera_joystick == null or app.tool_drawer == null or app.tool_drawer_toggle == null:
        _fail("Camera joystick or bottom drawer is missing")
        return
    if not app.tool_drawer_open or not app.tool_drawer.visible:
        _fail("Editor no longer starts with editing tools accessible")
        return
    if app.camera_joystick.get_parent() == null:
        _fail("Camera joystick not mounted in viewport")
        return
    if not app.camera_joystick.mouse_filter == Control.MOUSE_FILTER_STOP:
        _fail("Joystick doesn't block touch rays from reaching geometry")
        return

    var initial_height: float = app.canvas.size.y
    var selected: MeshInstance3D = app.edit.target
    var initial_transform: Transform3D = selected.transform
    var initial_mesh: Mesh = selected.mesh
    var initial_edits: int = app.undo_history.size()
    var initial_yaw: float = app.orbit_yaw
    var initial_pitch: float = app.orbit_pitch

    # Simulate an analog stick drag and multiple display frames.
    var pad: Control = app.camera_joystick
    var center: Vector2 = pad.size * 0.5
    var down := InputEventMouseButton.new()
    down.button_index = MOUSE_BUTTON_LEFT
    down.pressed = true
    down.position = center + Vector2(37.0, -20.0)
    pad._gui_input(down)
    if app.camera_stick_direction.x <= 0.2 or app.camera_stick_direction.y >= -0.1:
        _fail("Joystick press wasn't captured with both axes")
        return
    for i in range(12):
        app._process(1.0 / 60.0)
    if absf(app.orbit_yaw - initial_yaw) < 0.01 or absf(app.orbit_pitch - initial_pitch) < 0.01:
        _fail("Joystick isn't continuously orbiting camera while held")
        return
    if selected.mesh != initial_mesh or not selected.transform.is_equal_approx(initial_transform):
        _fail("Joystick changed model geometry or part transform")
        return
    if app.undo_history.size() != initial_edits:
        _fail("Joystick created geometry edits")
        return
    var up := InputEventMouseButton.new()
    up.button_index = MOUSE_BUTTON_LEFT
    up.pressed = false
    up.position = center
    pad._gui_input(up)
    if app.camera_stick_direction.length_squared() > 0.00001:
        _fail("Joystick stayed latched after release")
        return
    var stopped_yaw: float = app.orbit_yaw
    app._process(0.2)
    if absf(app.orbit_yaw - stopped_yaw) > 0.00001:
        _fail("Camera keeps rotating after releasing joystick")
        return

    # On-screen, drawer toggle must remain reachable while the 5 tool pages
    # are hidden, not be nested inside the panel that disappears.
    app._set_tool_drawer_open(false)
    await process_frame
    await process_frame
    if app.tool_drawer.visible or app.tool_drawer_open:
        _fail("Collapsed drawer still occupies screen")
        return
    if not app.tool_drawer_toggle.visible or not app.tool_drawer_toggle.is_visible_in_tree():
        _fail("Bottom tools tab vanished while tools were hidden")
        return
    if app.canvas.size.y < initial_height + 100.0:
        _fail("Collapsing bottom dock did not significantly enlarge viewport")
        return
    if app.tool_panels.size() != 5 or app.active_tab != 0:
        _fail("Drawer collapse reset editor tabs")
        return

    var collapsed_yaw := app.orbit_yaw
    pad._gui_input(down)
    for i in range(6):
        app._process(1.0 / 60.0)
    pad._gui_input(up)
    if absf(app.orbit_yaw - collapsed_yaw) < 0.005:
        _fail("Joystick stopped working while tool drawer was closed")
        return

    # Real GUI button tap, not just direct _toggle_tool_drawer() call.
    var bounds: Rect2 = app.tool_drawer_toggle.get_global_rect()
    if bounds.size.y < 50.0 or bounds.size.y > 78.0:
        _fail("Drawer handle is not a compact finger-friendly button")
        return
    var screen_down := InputEventMouseButton.new()
    screen_down.button_index = MOUSE_BUTTON_LEFT
    screen_down.pressed = true
    screen_down.position = bounds.get_center()
    screen_down.global_position = screen_down.position
    root.push_input(screen_down, true)
    await process_frame
    var screen_up := InputEventMouseButton.new()
    screen_up.button_index = MOUSE_BUTTON_LEFT
    screen_up.pressed = false
    screen_up.position = bounds.get_center()
    screen_up.global_position = screen_up.position
    root.push_input(screen_up, true)
    await process_frame
    await process_frame
    if not app.tool_drawer.visible or not app.tool_drawer_open:
        _fail("Tap on bottom tab failed to reopen the controls")
        return
    if app.canvas.size.y > initial_height + 12.0:
        _fail("Reopened drawer did not return tools to bottom panel")
        return

    app._show_tab(3)
    app._set_tool_drawer_open(false)
    if app.active_tab != 3:
        _fail("Drawer lost View mode")
        return
    app._set_tool_drawer_open(true)
    if not app.tool_panels[3].visible:
        _fail("Drawer did not restore View page after reopening")
        return
    if app.edit_toggle.button_pressed:
        _fail("Camera drawer unexpectedly armed vertex edit mode")
        return

    # Native touch path on Android; mouse emulation is ignored there.
    var finger_down := InputEventScreenTouch.new()
    finger_down.index = 5
    finger_down.pressed = true
    finger_down.position = center + Vector2(25, -25)
    pad._gui_input(finger_down)
    if app.camera_stick_direction.length_squared() < 0.05:
        _fail("Native screen touch did not engage joystick")
        return
    var finger_up := InputEventScreenTouch.new()
    finger_up.index = 5
    finger_up.pressed = false
    finger_up.position = center
    pad._gui_input(finger_up)
    if app.camera_stick_direction != Vector2.ZERO:
        _fail("Native touch release did not neutralize camera joystick")
        return

    print("MODEL_FORGE_CAMERA_DRAWER: PASS joystick orbit, model edit isolation, release safety, compact drawer button, expanded viewport, GUI reopening, touch")
    app.queue_free()
    quit(0)

func _fail(message: String) -> void:
    push_error("MODEL_FORGE_CAMERA_DRAWER: FAIL " + message)
    quit(1)
