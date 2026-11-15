extends SceneTree
## v0.8 Android controls: verify real touch-area dimensions, large visible
## slider thumbs, dropdowns and precision step buttons.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene = load("res://main.tscn")
    if scene == null:
        _fail("Missing editor scene")
        return
    var app = scene.instantiate()
    root.add_child(app)
    await process_frame
    await process_frame

    for slider in [app.soft_radius_slider, app.zebra_slider]:
        if slider.custom_minimum_size.y < 76.0 or slider.custom_minimum_size.x < 265.0:
            _fail("Slider touch surface below 265 x 76")
            return
        for name in ["grabber", "grabber_highlight", "grabber_disabled"]:
            var icon: Texture2D = slider.get_theme_icon(name)
            if icon == null or icon.get_width() < 54 or icon.get_height() < 54:
                _fail("Slider %s is using a tiny thumb" % name)
                return
        var track: StyleBox = slider.get_theme_stylebox("slider")
        if track == null or track.get_content_margin(SIDE_TOP) < 10.0:
            _fail("Slider track is too thin")
            return

    for picker in [app.mesh_picker, app.move_target_picker, app.surface_profile_picker, app.section_axis_picker, app.axis_picker]:
        if picker.custom_minimum_size.y < 74.0:
            _fail("Dropdown touch height is under 74")
            return
        var popup_theme: Theme = picker.get_popup().theme
        if popup_theme == null or popup_theme.get_font_size("font_size", "PopupMenu") < 22:
            _fail("Dropdown popup text remained too small")
            return

    for toggle in [
        app.edit_toggle, app.mirror_toggle, app.soft_toggle, app.wire_toggle,
        app.clay_toggle, app.zebra_toggle, app.highlight_toggle
    ]:
        if toggle.custom_minimum_size.y < 72.0:
            _fail("Toggle is below 72-height finger target: " + toggle.text)
            return
        if toggle.get_theme_font_size("font_size") < 20:
            _fail("Toggle text too small: " + toggle.text)
            return

    if app.step_box.custom_minimum_size.y < 76.0 or app.step_box.get_line_edit().get_theme_font_size("font_size") < 22:
        _fail("Precision numeric step field is too small")
        return
    if app.part_search.custom_minimum_size.y < 74.0:
        _fail("Part search field is too small")
        return
    for button in app.tab_buttons:
        if button.custom_minimum_size.y < 70.0:
            _fail("Tool tab hit target is too small")
            return
    if app.open_button.custom_minimum_size.y < 70.0:
        _fail("File open hit target is too small")
        return
    var rows: Array = []
    _gather_scrollbars(app, rows)
    if rows.size() < 10:
        _fail("Lost scrollable mobile command rows")
        return
    for strip in rows:
        if strip.custom_minimum_size.y > 0.0 and strip.custom_minimum_size.y < 75.0:
            _fail("An editing toolbar still has a cramped touch height")
            return

    # Precision +/- controls stay active even when moving a thumb is hard.
    var radius_initial: float = app.soft_radius_slider.value
    app._nudge_radius(0.05)
    if absf(app.soft_radius_slider.value - radius_initial - 0.05) > 0.001:
        _fail("Radius + button does not adjust correctly")
        return
    app._nudge_radius(-0.05)
    if absf(app.soft_radius_slider.value - radius_initial) > 0.001:
        _fail("Radius - button does not restore previous value")
        return
    app._nudge_radius(-100.0)
    if app.soft_radius_slider.value < app.soft_radius_slider.min_value:
        _fail("Radius - can exceed slider min")
        return

    var zebra_initial: float = app.zebra_slider.value
    app._nudge_zebra(1.0)
    if absf(app.zebra_slider.value - zebra_initial - 1.0) > 0.001:
        _fail("Bands + button does not adjust correctly")
        return
    app._nudge_zebra(-1.0)
    if absf(app.zebra_slider.value - zebra_initial) > 0.001:
        _fail("Bands - button does not restore previous value")
        return
    var step_initial: float = app.step_box.value
    app._nudge_step(0.01)
    if absf(app.step_box.value - step_initial - 0.01) > 0.001:
        _fail("Precision + button does not adjust numeric step")
        return
    app._nudge_step(-0.01)
    if absf(app.step_box.value - step_initial) > 0.001:
        _fail("Precision - button does not restore numeric step")
        return

    # Check actual on-screen slider interaction through GUI input, not a
    # direct call to _radius_changed.
    app._show_tab(0)
    app.soft_toggle.button_pressed = true
    await process_frame
    await process_frame
    var slider: HSlider = app.soft_radius_slider
    var scroll: ScrollContainer = slider.get_parent().get_parent() as ScrollContainer
    scroll.scroll_horizontal = maxi(0, int(slider.position.x) - 160)
    await process_frame
    var bounds: Rect2 = slider.get_global_rect()
    var click: Vector2 = bounds.position + Vector2(bounds.size.x * 0.72, bounds.size.y * 0.5)
    var visible: Rect2 = scroll.get_global_rect()
    if not visible.has_point(click):
        _fail("Scrolled slider is still outside finger reach")
        return
    var earlier: float = slider.value
    var down := InputEventMouseButton.new()
    down.button_index = MOUSE_BUTTON_LEFT
    down.pressed = true
    down.position = click
    down.global_position = click
    root.push_input(down, true)
    await process_frame
    var up := InputEventMouseButton.new()
    up.button_index = MOUSE_BUTTON_LEFT
    up.pressed = false
    up.position = click
    up.global_position = click
    root.push_input(up, true)
    await process_frame
    if absf(slider.value - earlier) < 0.01:
        _fail("Finger-size radius slider did not respond to actual GUI tap")
        return

    print("MODEL_FORGE_TOUCH: PASS large slider thumbs/tracks, toggles, dropdowns, tabs, numeric buttons, real slider GUI tap")
    app.queue_free()
    quit(0)

func _gather_scrollbars(node: Node, list: Array) -> void:
    if node is ScrollContainer:
        list.append(node)
    for child in node.get_children():
        _gather_scrollbars(child, list)

func _fail(why: String) -> void:
    push_error("MODEL_FORGE_TOUCH: FAIL " + why)
    quit(1)
