extends Control
## Model Forge v0.4: Android-first part and surface editing.
const MeshEdit = preload("res://scripts/mesh_editor.gd")
const AxisGizmo = preload("res://scripts/axis_gizmo.gd")
const DARK := Color("#101924")
const PANEL := Color("#162231")
const ACCENT := Color("#3ddbc1")
const MUTED := Color("#9aafc2")

var edit = MeshEdit.new()
var editor_by_mesh: Dictionary = {}
var undo_history: Array = []
var redo_history: Array = []
var dirty: bool = false
var project_name: String = "Untitled"
var project_label: Label
var move_target_picker: OptionButton
var part_info_label: Label
var mirror_toggle: CheckButton
var soft_toggle: CheckButton
var grid_node: MeshInstance3D
var clay_toggle: CheckButton
var clay_enabled: bool = false
var previous_overrides: Dictionary = {}
var clay_material: StandardMaterial3D
var isolate_active: bool = false
var saved_visibility: Dictionary = {}
const DRAFT_PATH := "user://model-forge-working-draft.glb"
const HISTORY_LIMIT := 20
var canvas: SubViewportContainer
var scene_view: SubViewport
var camera: Camera3D
var scene_world: Node3D
var asset_host: Node3D
var helpers: Node3D
var marker: MeshInstance3D
var wire_preview: MeshInstance3D
var mesh_nodes: Array = []
var mesh_picker: OptionButton
var vertex_label: Label
var status_label: Label
var step_box: SpinBox
var axis_picker: OptionButton
var edit_toggle: CheckButton
var touch_hint: Label
var wire_toggle: CheckButton
var reference_preview: TextureRect
var reference_window: PanelContainer
var tool_panels: Array = []
var tab_buttons: Array = []
var active_tab: int = 0
var soft_radius_slider: HSlider
var soft_radius_label: Label
var surface_profile_picker: OptionButton
var section_axis_picker: OptionButton
var gizmo_root
var gizmo_handles: Array = []
var gizmo_axis: int = -1
var gizmo_drag_active: bool = false
var gizmo_drag_part: bool = false
var gizmo_drag_changed: bool = false
var gizmo_start_transform: Transform3D
var gizmo_start_world: Vector3
var gizmo_world_length: float = 1.0
var gizmo_drag_start_screen: Vector2
var gizmo_drag_axis_screen: Vector2
var gizmo_drag_px_length: float = 1.0
var gizmo_drag_vertex_editor
var gizmo_last_world_delta: Vector3 = Vector3.ZERO
var help_dialog: AcceptDialog
var open_dialog: FileDialog
var open_button: Button
var open_requests: int = 0
var android_file_bridge: Object
var last_picker_route: String = ""
var save_dialog: FileDialog
var image_dialog: FileDialog
var orbit_yaw := 0.55
var orbit_pitch := 0.35
var orbit_distance := 7.0
var orbit_center := Vector3.ZERO
var pointer_down := false
var pointer_dragging_vertex := false
var pointer_origin := Vector2.ZERO
var pointer_last := Vector2.ZERO
var stroke_moved := false
var last_rebuild_ms := 0
var touch_positions: Dictionary = {}
var last_pinch_distance := 0.0
var last_pinch_midpoint := Vector2.ZERO

func _ready() -> void:
    get_viewport().gui_release_focus()
    _create_ui()
    _create_scene()
    _create_file_dialogs()
    _connect_android_file_bridge()
    _create_demo()
    _mark_clean()
    _notify("Ready. Select a part, then tap a point or use MOVE.")

func _create_ui() -> void:
    # Four large tool tabs replace the two cramped permanent sidebars.
    var whole := VBoxContainer.new()
    whole.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    whole.add_theme_constant_override("separation", 0)
    add_child(whole)
    var header := PanelContainer.new()
    _panel_style(header, DARK)
    whole.add_child(header)
    var toolbar := HBoxContainer.new()
    toolbar.add_theme_constant_override("separation", 8)
    header.add_child(toolbar)
    var brand := _label(toolbar, "MODEL FORGE", 22, ACCENT)
    brand.custom_minimum_size.x = 198
    project_label = _label(toolbar, "Untitled • SAVED", 14, MUTED)
    project_label.custom_minimum_size.x = 220
    project_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    project_label.clip_text = true
    open_button = _button(toolbar, "OPEN", _request_open_glb)
    open_button.custom_minimum_size.x = 145
    _button(toolbar, "EXPORT GLB", _request_save_glb)
    _button(toolbar, "UNDO", _do_undo)
    _button(toolbar, "REDO", _do_redo)
    _button(toolbar, "?", _show_help)

    var viewport_area := Control.new()
    viewport_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
    whole.add_child(viewport_area)
    canvas = SubViewportContainer.new()
    canvas.stretch = true
    canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    canvas.mouse_filter = Control.MOUSE_FILTER_STOP
    canvas.gui_input.connect(_canvas_input)
    viewport_area.add_child(canvas)
    touch_hint = _label(viewport_area, "VIEW MODE • Drag to rotate • Tap SHAPE for points", 17, Color("#d3e6f2"))
    touch_hint.position = Vector2(16, 12)
    touch_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE

    reference_window = PanelContainer.new()
    _panel_style(reference_window, Color("#172536"))
    reference_window.anchor_left = 1.0
    reference_window.anchor_right = 1.0
    reference_window.offset_left = -435
    reference_window.offset_right = -12
    reference_window.offset_top = 10
    reference_window.offset_bottom = 265
    viewport_area.add_child(reference_window)
    var ref_column := VBoxContainer.new()
    reference_window.add_child(ref_column)
    var ref_header := HBoxContainer.new()
    ref_column.add_child(ref_header)
    _label(ref_header, "REFERENCE IMAGE", 17, ACCENT)
    _button(ref_header, "HIDE", _toggle_reference)
    reference_preview = TextureRect.new()
    reference_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    reference_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    reference_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
    ref_column.add_child(reference_preview)
    reference_window.visible = false

    var dock := PanelContainer.new()
    _panel_style(dock, PANEL)
    whole.add_child(dock)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 7)
    dock.add_child(stack)
    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 8)
    stack.add_child(tabs)
    for tab_name in ["SHAPE", "MOVE", "VIEW", "FILES"]:
        var index: int = tab_buttons.size()
        var tab := _button(tabs, tab_name, func(): _show_tab(index))
        tab_buttons.append(tab)
    var pages := Control.new()
    pages.custom_minimum_size.y = 204
    stack.add_child(pages)
    for i in range(4):
        var page := VBoxContainer.new()
        page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        page.add_theme_constant_override("separation", 8)
        pages.add_child(page)
        page.visible = false
        tool_panels.append(page)

    # Shape: choose a part, select a point, optionally bend its neighbors.
    var shape_row := HBoxContainer.new()
    tool_panels[0].add_child(shape_row)
    mesh_picker = OptionButton.new()
    mesh_picker.custom_minimum_size = Vector2(260, 56)
    mesh_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    mesh_picker.item_selected.connect(_choose_mesh)
    shape_row.add_child(mesh_picker)
    _button(shape_row, "◀ PART", func(): _cycle_part(-1))
    _button(shape_row, "PART ▶", func(): _cycle_part(1))
    _button(shape_row, "◀ POINT", func(): _cycle_vertex(-1))
    _button(shape_row, "POINT ▶", func(): _cycle_vertex(1))
    vertex_label = _label(shape_row, "No point", 15, Color.WHITE)
    vertex_label.custom_minimum_size.x = 198
    var shape_options := HBoxContainer.new()
    shape_options.add_theme_constant_override("separation", 12)
    tool_panels[0].add_child(shape_options)
    edit_toggle = CheckButton.new()
    edit_toggle.text = "EDIT POINTS"
    edit_toggle.button_pressed = false
    edit_toggle.toggled.connect(_edit_toggled)
    edit_toggle.custom_minimum_size.x = 195
    shape_options.add_child(edit_toggle)
    mirror_toggle = CheckButton.new()
    mirror_toggle.text = "MIRROR X"
    mirror_toggle.toggled.connect(func(enabled: bool): edit.mirror_enabled = enabled)
    shape_options.add_child(mirror_toggle)
    soft_toggle = CheckButton.new()
    soft_toggle.text = "SOFT SHAPE"
    soft_toggle.toggled.connect(_soft_changed)
    shape_options.add_child(soft_toggle)
    soft_radius_label = _label(shape_options, "Radius 0.75", 16, MUTED)
    soft_radius_slider = HSlider.new()
    soft_radius_slider.custom_minimum_size.x = 180
    soft_radius_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    soft_radius_slider.min_value = 0.15
    soft_radius_slider.max_value = 4.0
    soft_radius_slider.step = 0.05
    soft_radius_slider.value = 0.75
    soft_radius_slider.editable = false
    soft_radius_slider.value_changed.connect(_radius_changed)
    shape_options.add_child(soft_radius_slider)
    _button(shape_options, "SMOOTH", _smooth_selection)
    var surface_row := HBoxContainer.new()
    surface_row.add_theme_constant_override("separation", 12)
    tool_panels[0].add_child(surface_row)
    _label(surface_row, "SURFACE", 16, ACCENT)
    surface_profile_picker = OptionButton.new()
    surface_profile_picker.custom_minimum_size = Vector2(260, 54)
    surface_profile_picker.add_item("ROUND BRUSH")
    surface_profile_picker.add_item("BODY SECTION")
    surface_profile_picker.add_item("KEEP HARD EDGES")
    surface_profile_picker.item_selected.connect(_profile_changed)
    surface_row.add_child(surface_profile_picker)
    _label(surface_row, "SECTION AXIS", 14, MUTED)
    section_axis_picker = OptionButton.new()
    section_axis_picker.custom_minimum_size = Vector2(165, 54)
    for item in ["X WIDTH", "Y HEIGHT", "Z LENGTH"]:
        section_axis_picker.add_item(item)
    section_axis_picker.select(2)
    section_axis_picker.disabled = true
    section_axis_picker.item_selected.connect(_section_axis_changed)
    surface_row.add_child(section_axis_picker)
    var profile_hint := _label(surface_row, "Body Section reshapes a slice; Keep Hard Edges protects creases.", 15, MUTED)
    profile_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    profile_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    # Move: explicitly choose whole-part placement or point adjustments.
    var target_row := HBoxContainer.new()
    tool_panels[1].add_child(target_row)
    _label(target_row, "EDIT", 17, ACCENT)
    move_target_picker = OptionButton.new()
    move_target_picker.custom_minimum_size = Vector2(275, 52)
    move_target_picker.add_item("SELECTED POINT")
    move_target_picker.add_item("WHOLE PART")
    move_target_picker.select(1)
    move_target_picker.item_selected.connect(_move_target_changed)
    target_row.add_child(move_target_picker)
    part_info_label = _label(target_row, "Hull", 16, Color.WHITE)
    part_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _button(target_row, "ROTATE −5°", func(): _rotate_part(-5.0))
    _button(target_row, "ROTATE +5°", func(): _rotate_part(5.0))
    _button(target_row, "SMALLER", func(): _scale_part(0.95))
    _button(target_row, "BIGGER", func(): _scale_part(1.05))
    var move_row := HBoxContainer.new()
    tool_panels[1].add_child(move_row)
    for item in [
        ["X −", Vector3.LEFT], ["X +", Vector3.RIGHT],
        ["Y −", Vector3.DOWN], ["Y +", Vector3.UP],
        ["Z −", Vector3(0, 0, -1)], ["Z +", Vector3(0, 0, 1)]
    ]:
        var direction: Vector3 = item[1]
        _button(move_row, item[0], func(): _nudge(direction))
    var move_settings := HBoxContainer.new()
    tool_panels[1].add_child(move_settings)
    _label(move_settings, "STEP SIZE", 17, MUTED)
    step_box = SpinBox.new()
    step_box.custom_minimum_size = Vector2(180, 56)
    step_box.min_value = 0.0
    step_box.max_value = 20.0
    step_box.step = 0.01
    step_box.value = 0.10
    move_settings.add_child(step_box)
    _label(move_settings, "DRAG ALONG", 17, MUTED)
    axis_picker = OptionButton.new()
    axis_picker.custom_minimum_size = Vector2(225, 56)
    axis_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for axis in ["SCREEN", "X AXIS", "Y AXIS", "Z AXIS"]:
        axis_picker.add_item(axis)
    move_settings.add_child(axis_picker)
    _label(move_settings, "DRAG X RED  •  Y GREEN  •  Z BLUE handles directly on the model", 15, ACCENT)

    # View: preset cameras, wireframe inspection and orbit-only mode.
    var views := HBoxContainer.new()
    tool_panels[2].add_child(views)
    _button(views, "FIT ALL", _frame_model)
    _button(views, "FOCUS PART", _focus_part)
    _button(views, "FRONT", func(): _preset_view(0))
    _button(views, "SIDE", func(): _preset_view(1))
    _button(views, "TOP", func(): _preset_view(2))
    _button(views, "3/4", func(): _preset_view(3))
    var view_row := HBoxContainer.new()
    tool_panels[2].add_child(view_row)
    wire_toggle = CheckButton.new()
    wire_toggle.text = "WIREFRAME"
    wire_toggle.toggled.connect(_wire_changed)
    view_row.add_child(wire_toggle)
    clay_toggle = CheckButton.new()
    clay_toggle.text = "CLAY"
    clay_toggle.toggled.connect(_set_clay)
    view_row.add_child(clay_toggle)
    _button(view_row, "SOLO PART", _toggle_isolate)
    _button(view_row, "SHOW ALL", _show_all_parts)
    _button(view_row, "PHOTO", _toggle_reference)
    _button(view_row, "NORMALS", _recalculate_normals)
    _label(view_row, "Drag = rotate • pinch = zoom • two-finger drag = pan", 15, MUTED)

    # Files: clear separation between a private working draft and exported GLB.
    var file_row := HBoxContainer.new()
    tool_panels[3].add_child(file_row)
    _button(file_row, "OPEN GLB", _request_open_glb)
    _button(file_row, "EXPORT GLB", _request_save_glb)
    _button(file_row, "SAVE DRAFT", _save_draft)
    _button(file_row, "RESTORE DRAFT", _restore_draft)
    var more_buttons := HBoxContainer.new()
    tool_panels[3].add_child(more_buttons)
    _button(more_buttons, "LOAD PHOTO", _request_reference)
    _button(more_buttons, "SHOW PHOTO", _toggle_reference)
    _button(more_buttons, "DEMO MODEL", _create_demo)
    _button(more_buttons, "HELP", _show_help)
    var tip := _label(more_buttons, "Draft stays in the app. EXPORT GLB creates a shareable file.", 15, MUTED)
    tip.custom_minimum_size.x = 360

    var footer := PanelContainer.new()
    _panel_style(footer, DARK)
    whole.add_child(footer)
    status_label = _label(footer, "Model Forge ready", 15, MUTED)
    help_dialog = AcceptDialog.new()
    help_dialog.title = "Model Forge • Quick Guide"
    help_dialog.dialog_text = "MODEL FORGE — START HERE\n\n1. OPEN a GLB (or FILES > DEMO MODEL).\n2. SHAPE: pick a PART and tap a vertex. Enable EDIT POINTS to pull it; OFF is safer camera mode.\n3. SOFT SHAPE: ROUND BRUSH adjusts a local area, BODY SECTION adjusts a cross-section (choose X/Y/Z), KEEP HARD EDGES avoids crossing strong normal changes. MIRROR X affects the opposite side.\n4. MOVE: WHOLE PART or SELECTED POINT. Touch and drag a colored handle directly on the model: X red, Y green, Z blue. Or use the precision X/Y/Z buttons.\n5. VIEW: Front, Side, Top, 3/4. CLAY and WIREFRAME reveal geometry, SOLO PART isolates temporarily.\n6. FILES: SAVE DRAFT keeps one working version on the phone; EXPORT GLB creates the shareable model.\n\nPinch to zoom and two-finger drag to pan. Imported GLB files are not overwritten automatically."
    add_child(help_dialog)
    _show_tab(0)

func _show_tab(index: int) -> void:
    # Switching tools must never leave a 3D drag captured.
    if gizmo_drag_active:
        _finish_gizmo_drag()
        pointer_down = false
        pointer_dragging_vertex = false
    active_tab = index
    for i in range(tool_panels.size()):
        tool_panels[i].visible = (i == index)
        tab_buttons[i].modulate = Color.WHITE if i == index else Color("#879cab")
    # Never silently arm geometry pulling when changing tool tabs.
    if edit_toggle != null and index != 0:
        edit_toggle.button_pressed = false
    _update_touch_hint()
    _update_marker()
    if status_label != null:
        var messages := [
            "SHAPE • Choose a part; tap a point; enable EDIT POINTS to drag.",
            "MOVE • Choose WHOLE PART or SELECTED POINT; use X/Y/Z buttons.",
            "VIEW • Camera angles, wireframe, part isolation and reference photo.",
            "FILES • Open, export, save/restore a draft, load a reference image."
        ]
        _notify(messages[index])

func _edit_toggled(enabled: bool) -> void:
    if not enabled and pointer_dragging_vertex:
        _pointer_end()
    _update_touch_hint()
    if enabled:
        _notify("EDIT ON: drag a point to reshape it. Tap EDIT POINTS to exit.")
    else:
        _notify("VIEW ON: drag to orbit. Tap a point to select it in SHAPE.")


func _update_touch_hint() -> void:
    if touch_hint == null:
        return
    if edit_toggle != null and edit_toggle.button_pressed:
        touch_hint.text = "EDIT MODE • Drag a point to pull • Switch EDIT POINTS off to orbit"
    elif active_tab == 0:
        touch_hint.text = "SHAPE • Tap a point to select • EDIT POINTS ON to reshape • Drag to orbit while OFF"
    elif active_tab == 1:
        touch_hint.text = "MOVE • Tap any part to select • Drag RED X / GREEN Y / BLUE Z handle"
    else:
        touch_hint.text = "VIEW • Drag to rotate • Two fingers to zoom / pan"


func _move_target_changed(index: int) -> void:
    _notify("Moving whole part" if index == 1 else "Moving selected mesh point")
    _update_marker()

func _wire_changed(enabled: bool) -> void:
    if wire_preview != null:
        wire_preview.visible = enabled
        if enabled:
            _rebuild_wire_overlay()
    _notify("Wireframe overlay ON" if enabled else "Wireframe overlay OFF")

func _soft_changed(enabled: bool) -> void:
    edit.soft_enabled = enabled
    soft_radius_slider.editable = enabled
    _notify("SOFT on: controlled surface deformation" if enabled else "SOFT off: single point movement")

func _profile_changed(index: int) -> void:
    edit.soft_profile = index
    section_axis_picker.disabled = index != 1
    if index != 0 and not soft_toggle.button_pressed:
        soft_toggle.button_pressed = true
    _notify(["Round brush shaping", "Body section shaping along chosen axis", "Hard-edge guarded brush shaping"][index])

func _section_axis_changed(index: int) -> void:
    edit.section_axis = index
    _notify("Body section axis: " + ["X width", "Y height", "Z length"][index])

func _radius_changed(value: float) -> void:
    edit.soft_radius = value
    soft_radius_label.text = "Radius %.2f" % value

func _smooth_selection() -> void:
    if not edit.has_selection():
        _notify("Select a point first.")
        return
    edit.relax_selected(0.28)
    _notify("Smoothed selection — tap UNDO if needed.")

func _focus_part() -> void:
    var instance := _selected_part()
    if instance == null:
        _notify("Choose a part to focus on.")
        return
    var bounds: AABB = instance.get_aabb()
    var world_bounds: AABB = AABB()
    var first := true
    for x in [0.0, 1.0]:
        for y in [0.0, 1.0]:
            for z in [0.0, 1.0]:
                var point: Vector3 = instance.to_global(bounds.position + bounds.size * Vector3(x, y, z))
                if first:
                    world_bounds = AABB(point, Vector3.ZERO)
                    first = false
                else:
                    world_bounds = world_bounds.expand(point)
    orbit_center = world_bounds.get_center()
    orbit_distance = clampf(world_bounds.size.length() * 1.65, 0.6, 900.0)
    _update_camera()
    _update_marker()
    _notify("Focused on part: %s" % instance.name)

func _set_clay(enabled: bool) -> void:
    if clay_enabled == enabled:
        return
    if enabled:
        clay_material = StandardMaterial3D.new()
        clay_material.albedo_color = Color("#b8c2cf")
        clay_material.roughness = 0.32
        clay_material.metallic = 0.15
        previous_overrides.clear()
        for instance in mesh_nodes:
            previous_overrides[instance] = instance.material_override
            instance.material_override = clay_material
    else:
        for instance in previous_overrides:
            if is_instance_valid(instance):
                instance.material_override = previous_overrides[instance]
        previous_overrides.clear()
    clay_enabled = enabled
    if clay_toggle != null:
        clay_toggle.set_pressed_no_signal(enabled)
    if status_label != null:
        _notify("Clay preview: material colors temporarily hidden." if enabled else "Original materials restored.")

func _preset_view(preset: int) -> void:
    match preset:
        0:
            orbit_yaw = 0.0
            orbit_pitch = 0.0
        1:
            orbit_yaw = PI / 2.0
            orbit_pitch = 0.0
        2:
            orbit_yaw = 0.0
            orbit_pitch = 1.40
        3:
            orbit_yaw = 0.55
            orbit_pitch = 0.35
    _update_camera()
    _update_marker()

func _camera_mode() -> void:
    edit_toggle.button_pressed = false
    _update_touch_hint()
    _notify("Camera mode: drag to rotate freely. Go to SHAPE → EDIT POINTS to reshape.")

func _recalculate_normals() -> void:
    if edit.target == null:
        _notify("Open or select a mesh first.")
        return
    edit.recalculate_normals()
    _notify("Normals rebuilt; this shading action is not undoable.")

func _toggle_reference() -> void:
    reference_window.visible = not reference_window.visible

func _show_help() -> void:
    help_dialog.popup_centered(Vector2i(850, 490))

func _panel_style(panel: PanelContainer, color: Color) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.content_margin_left = 10
    style.content_margin_right = 10
    style.content_margin_top = 9
    style.content_margin_bottom = 9
    panel.add_theme_stylebox_override("panel", style)

func _button(parent: Node, caption: String, action: Callable) -> Button:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size.y = 58
    button.add_theme_font_size_override("font_size", 19)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.pressed.connect(action)
    parent.add_child(button)
    return button

func _label(parent: Node, caption: String, font_size: int, tint: Color) -> Label:
    var result := Label.new()
    result.text = caption
    result.add_theme_font_size_override("font_size", font_size)
    result.add_theme_color_override("font_color", tint)
    parent.add_child(result)
    return result

func _spaced(parent: Node, amount: int) -> void:
    var gap := Control.new()
    gap.custom_minimum_size.x = amount
    parent.add_child(gap)

func _create_scene() -> void:
    scene_view = SubViewport.new()
    scene_view.size = Vector2i(900, 600)
    scene_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    scene_view.own_world_3d = true
    canvas.add_child(scene_view)
    scene_world = Node3D.new()
    scene_view.add_child(scene_world)
    asset_host = Node3D.new()
    asset_host.name = "ExportedModel"
    scene_world.add_child(asset_host)
    helpers = Node3D.new()
    helpers.name = "ViewportHelpers"
    scene_world.add_child(helpers)
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 56.0
    camera.near = 0.025
    camera.far = 4000.0
    scene_world.add_child(camera)
    var env := WorldEnvironment.new()
    env.environment = Environment.new()
    env.environment.background_mode = Environment.BG_COLOR
    env.environment.background_color = Color("#1a2837")
    env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color = Color("#cbdced")
    env.environment.ambient_light_energy = 0.7
    scene_world.add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-43, 35, 0)
    sun.light_energy = 1.6
    scene_world.add_child(sun)
    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(30, -115, 0)
    fill.light_energy = 0.55
    scene_world.add_child(fill)
    _make_grid()
    marker = MeshInstance3D.new()
    marker.mesh = SphereMesh.new()
    var highlight := StandardMaterial3D.new()
    highlight.albedo_color = Color("#ffaf52")
    highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    highlight.no_depth_test = true
    marker.material_override = highlight
    marker.visible = false
    helpers.add_child(marker)
    wire_preview = MeshInstance3D.new()
    var wiremat := StandardMaterial3D.new()
    wiremat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    wiremat.albedo_color = Color(0.21, 0.96, 0.83, 0.6)
    wiremat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    # Godot 4 does not support StandardMaterial3D.wireframe; draw real mesh edges.
    wiremat.no_depth_test = true
    wire_preview.material_override = wiremat
    wire_preview.visible = false
    helpers.add_child(wire_preview)
    gizmo_root = AxisGizmo.new()
    helpers.add_child(gizmo_root)
    _update_camera()

func _make_grid() -> void:
    var lines := ImmediateMesh.new()
    lines.surface_begin(Mesh.PRIMITIVE_LINES)
    for i in range(-14, 15):
        var n := float(i)
        lines.surface_add_vertex(Vector3(n, -0.85, -14))
        lines.surface_add_vertex(Vector3(n, -0.85, 14))
        lines.surface_add_vertex(Vector3(-14, -0.85, n))
        lines.surface_add_vertex(Vector3(14, -0.85, n))
    lines.surface_end()
    grid_node = MeshInstance3D.new()
    grid_node.mesh = lines
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color("#405568")
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    grid_node.material_override = mat
    helpers.add_child(grid_node)

func _create_file_dialogs() -> void:
    open_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILE, PackedStringArray(["*.glb;Binary glTF;model/gltf-binary"]))
    open_dialog.file_selected.connect(_load_glb)
    save_dialog = _file_dialog(FileDialog.FILE_MODE_SAVE_FILE, PackedStringArray(["*.glb;Binary glTF;model/gltf-binary"]))
    save_dialog.current_file = "model-forge-edited.glb"
    save_dialog.file_selected.connect(_save_glb)
    image_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILE, PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp;Reference Images;image/png,image/jpeg,image/webp"]))
    image_dialog.file_selected.connect(_load_reference)

func _file_dialog(mode: int, filters: PackedStringArray) -> FileDialog:
    var dialog := FileDialog.new()
    dialog.access = FileDialog.ACCESS_FILESYSTEM
    dialog.file_mode = mode
    dialog.filters = filters
    dialog.use_native_dialog = true
    add_child(dialog)
    return dialog

# Use the Android Storage Access Framework through DisplayServer rather
# than relying on FileDialog popup/window behavior. Always report button taps.
func _connect_android_file_bridge() -> void:
    if OS.get_name() != "Android":
        return
    if Engine.has_singleton("ModelForgeFiles"):
        android_file_bridge = Engine.get_singleton("ModelForgeFiles")
        if not android_file_bridge.file_result.is_connected(_android_document_result):
            android_file_bridge.file_result.connect(_android_document_result)
        print("MODEL_FORGE_SAF: READY")
    else:
        push_warning("MODEL_FORGE_SAF: MISSING native Android file bridge")
        _notify("Android file access module unavailable. Use an APK with ModelForgeFiles installed.")


func _request_open_glb() -> void:
    open_requests += 1
    if OS.get_name() == "Android":
        if android_file_bridge == null:
            _notify("OPEN unavailable: native file bridge missing from this APK.")
            return
        last_picker_route = "android_saf"
        _notify("Opening Android Files… choose your GLB from Downloads or another location.")
        android_file_bridge.openDocument("model")
        return
    _notify("OPEN pressed — choose a .glb model.")
    _show_file_picker("open")


func _request_save_glb() -> void:
    if OS.get_name() == "Android":
        if android_file_bridge == null:
            _notify("SAVE unavailable: native file bridge missing from this APK.")
            return
        var private_path := "user://model-forge-export.glb"
        if not _save_glb(private_path, false):
            _notify("SAVE failed: could not prepare a GLB export.")
            return
        var absolute_path := ProjectSettings.globalize_path(private_path)
        _notify("Choose a location for your edited model.")
        var suggested := project_name.get_basename() + "-edited.glb"
        android_file_bridge.saveDocument(absolute_path, suggested)
        return
    _notify("SAVE pressed — choose where to export your model.")
    _show_file_picker("save")


func _request_reference() -> void:
    if OS.get_name() == "Android":
        if android_file_bridge == null:
            _notify("PHOTO unavailable: native file bridge missing.")
            return
        _notify("Opening Android Files… choose a reference photo.")
        android_file_bridge.openDocument("photo")
        return
    _show_file_picker("photo")


func _android_document_result(kind: String, location: String, status: String) -> void:
    print("MODEL_FORGE_SAF: result kind=", kind, " status=", status,
        " has_path=", not location.is_empty())
    if status == "canceled":
        _notify("File picker closed without selecting a document.")
        return
    if status != "ok":
        _notify("Android file access error: " + status)
        return
    if location.is_empty():
        _notify("Android returned no document path. Try a local file from Downloads.")
        return
    if kind == "model":
        _notify("Document received. Importing GLB…")
        _load_glb(location)
    elif kind == "photo":
        _load_reference(location)
    elif kind == "save":
        _mark_clean()
        _notify("Edited GLB saved to the selected Android document.")


func _show_file_picker(kind: String) -> void:
    var dialog: FileDialog = open_dialog
    var mode: int = DisplayServer.FILE_DIALOG_MODE_OPEN_FILE
    var title := "Choose 3D model"
    var filename := ""
    var filters := PackedStringArray(["*.glb;GLB models;model/gltf-binary"])
    if kind == "save":
        title = "Export edited model"
        filename = "model-forge-edited.glb"
        mode = DisplayServer.FILE_DIALOG_MODE_SAVE_FILE
        dialog = save_dialog
    elif kind == "photo":
        title = "Choose reference image"
        filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp;Images;image/png,image/jpeg,image/webp"])
        dialog = image_dialog

    if OS.get_name() == "Android" and DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
        # Some Android document providers label GLB files application/octet-stream,
        # not model/gltf-binary. Show all files and validate GLB magic after selection.
        if kind == "open":
            filters = PackedStringArray()
        last_picker_route = "android_native"
        var result: Error = DisplayServer.file_dialog_show(title, "", filename, false, mode, filters, _native_picker_result.bind(kind))
        if result == OK:
            _notify("Android Files picker requested. Select a model from Downloads or Documents.")
            return
        _notify("Android picker failed (%s). Trying built-in browser." % error_string(result))
    last_picker_route = "fallback"
    if dialog == null:
        _notify("File browser unavailable. Please restart Model Forge.")
        return
    # Fallback for desktop or Android devices without native picker support.
    dialog.popup_centered_ratio(0.88)
    if not dialog.visible:
        _notify("The file browser could not open on this device.")


func _native_picker_result(ok: bool, paths: PackedStringArray, _filter_index: int, kind: String) -> void:
    if not ok or paths.is_empty():
        _notify("File selection canceled.")
        return
    var location: String = paths[0]
    if kind == "open":
        _load_glb(location)
    elif kind == "save":
        _save_glb(location)
    elif kind == "photo":
        _load_reference(location)


func _load_glb(path: String) -> void:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        _notify("Cannot read model: %s" % error_string(FileAccess.get_open_error()))
        return
    var bytes := file.get_buffer(file.get_length())
    file.close()
    if bytes.size() < 12 or bytes.slice(0, 4).get_string_from_ascii() != "glTF":
        _notify("Not a valid GLB file. Choose an uncompressed .glb model.")
        return
    var document := GLTFDocument.new()
    var state := GLTFState.new()
    var problem: Error = document.append_from_buffer(bytes, "", state)
    if problem != OK:
        _notify("GLB import failed: %s" % error_string(problem))
        return
    var result: Node = document.generate_scene(state)
    if result == null:
        _notify("GLB contains no importable scene.")
        return
    if dirty and path != DRAFT_PATH:
        if not _save_glb(DRAFT_PATH, false):
            _notify("Import canceled: unable to back up current unsaved work.")
            result.free()
            return
    _clear_asset()
    asset_host.add_child(result)
    project_name = path.get_file()
    # SAF copies into a private cache as UUID_original-name.glb.
    # Show the original filename in the project bar.
    if project_name.length() > 37 and project_name.substr(36, 1) == "_":
        project_name = project_name.substr(37)
    _index_meshes()
    _frame_model()
    _mark_clean()
    _notify("Loaded %s — %d mesh parts" % [project_name, mesh_nodes.size()])

func _save_glb(path: String, clear_dirty: bool = true) -> bool:
    if asset_host.get_child_count() == 0:
        _notify("Nothing to export.")
        return false
    # Isolate/Solo is viewport-only; always export the complete model.
    _show_all_parts()
    var resume_clay := clay_enabled
    if resume_clay:
        _set_clay(false)
    var document := GLTFDocument.new()
    var state := GLTFState.new()
    var problem := document.append_from_scene(asset_host, state)
    if problem != OK:
        if resume_clay:
            _set_clay(true)
        _notify("Export error: %s" % error_string(problem))
        return false
    var bytes := document.generate_buffer(state)
    if resume_clay:
        _set_clay(true)
    if bytes.is_empty():
        _notify("Export failed: generated GLB is empty.")
        return false
    var out := FileAccess.open(path, FileAccess.WRITE)
    if out == null:
        _notify("Cannot write GLB: %s" % error_string(FileAccess.get_open_error()))
        return false
    out.store_buffer(bytes)
    out.close()
    if clear_dirty:
        _mark_clean()
    _notify("Exported %s (%d KiB)" % [path.get_file(), int(bytes.size() / 1024)])
    return true

func _load_reference(path: String) -> void:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        _notify("Cannot open reference image.")
        return
    var data := file.get_buffer(file.get_length())
    file.close()
    var picture := Image.new()
    # Android SAF returns content:// URIs without reliable filename extensions.
    var problem: Error = picture.load_png_from_buffer(data)
    if problem != OK:
        problem = picture.load_jpg_from_buffer(data)
    if problem != OK:
        problem = picture.load_webp_from_buffer(data)
    if problem != OK:
        _notify("Unsupported reference image.")
        return
    reference_preview.texture = ImageTexture.create_from_image(picture)
    reference_window.visible = true
    _notify("Reference image loaded. HIDE closes the photo.")

func _clear_asset() -> void:
    _show_all_parts()
    _set_clay(false)
    edit.set_target(null)
    editor_by_mesh.clear()
    undo_history.clear()
    redo_history.clear()
    dirty = false
    for child in asset_host.get_children():
        asset_host.remove_child(child)
        child.queue_free()
    mesh_nodes.clear()
    mesh_picker.clear()
    marker.visible = false
    wire_preview.mesh = null
    if gizmo_root != null:
        gizmo_root.visible = false
    gizmo_drag_active = false

func _index_meshes() -> void:
    mesh_nodes.clear()
    mesh_picker.clear()
    _collect_mesh_nodes(asset_host)
    for instance in mesh_nodes:
        mesh_picker.add_item(instance.name)
    if not mesh_nodes.is_empty():
        _choose_mesh(0)
    else:
        vertex_label.text = "No editable triangle meshes"

func _collect_mesh_nodes(node: Node) -> void:
    if node is MeshInstance3D and node.mesh != null:
        mesh_nodes.append(node)
    for child in node.get_children():
        _collect_mesh_nodes(child)

func _choose_mesh(index: int) -> void:
    if index < 0 or index >= mesh_nodes.size():
        return
    var instance: MeshInstance3D = mesh_nodes[index]
    mesh_picker.select(index)
    if editor_by_mesh.has(instance):
        edit = editor_by_mesh[instance]
    else:
        var next_editor = MeshEdit.new()
        next_editor.soft_enabled = soft_toggle.button_pressed if soft_toggle != null else false
        next_editor.mirror_enabled = mirror_toggle.button_pressed if mirror_toggle != null else false
        next_editor.soft_radius = float(soft_radius_slider.value) if soft_radius_slider != null else 0.75
        next_editor.soft_profile = surface_profile_picker.selected if surface_profile_picker != null else 0
        next_editor.section_axis = section_axis_picker.selected if section_axis_picker != null else 2
        if next_editor.set_target(instance):
            if next_editor.vertex_count() > 0:
                next_editor.select_vertex(0, 0)
        next_editor.geometry_changed.connect(_geometry_changed)
        next_editor.edit_committed.connect(_record_geometry_commit.bind(next_editor))
        editor_by_mesh[instance] = next_editor
        edit = next_editor
    edit.soft_enabled = soft_toggle.button_pressed
    edit.mirror_enabled = mirror_toggle.button_pressed
    edit.soft_radius = float(soft_radius_slider.value)
    edit.soft_profile = surface_profile_picker.selected
    edit.section_axis = section_axis_picker.selected
    _geometry_changed()
    _update_project_header()
    _notify("Part %d/%d: %s • %d vertices" % [index + 1, mesh_nodes.size(), instance.name, edit.vertex_count()])

func _cycle_part(direction: int) -> void:
    if mesh_nodes.is_empty():
        return
    var at: int = mesh_picker.selected
    _choose_mesh(posmod(at + direction, mesh_nodes.size()))

func _record_geometry_commit(source: RefCounted) -> void:
    _push_history({"kind": "geometry", "node": source.target})
    _mark_dirty()

func _push_history(change: Dictionary) -> void:
    undo_history.append(change)
    if undo_history.size() > HISTORY_LIMIT:
        undo_history.pop_front()
    redo_history.clear()

func _mark_dirty() -> void:
    dirty = true
    _update_project_header()

func _mark_clean() -> void:
    dirty = false
    _update_project_header()

func _update_project_header() -> void:
    if project_label != null:
        project_label.text = ("%s%s" % [project_name, " • UNSAVED" if dirty else " • SAVED"])
    if part_info_label != null and edit.target != null:
        part_info_label.text = "%s" % edit.target.name

func _selected_part() -> MeshInstance3D:
    return edit.target if edit != null else null

func _part_transform(direction: Vector3) -> void:
    var node := _selected_part()
    if node == null:
        _notify("Select a part in SHAPE first.")
        return
    var before: Transform3D = node.transform
    node.position += direction * float(step_box.value)
    _push_history({"kind": "part", "node": node, "before": before, "after": node.transform})
    _mark_dirty()
    _geometry_changed()
    _notify("Moved part %s by %.3f" % [node.name, float(step_box.value)])

func _rotate_part(degrees: float) -> void:
    var node := _selected_part()
    if node == null:
        return
    var before: Transform3D = node.transform
    node.rotation_degrees.y += degrees
    _push_history({"kind": "part", "node": node, "before": before, "after": node.transform})
    _mark_dirty()
    _geometry_changed()
    _notify("Rotated %s by %.1f degrees" % [node.name, degrees])

func _scale_part(factor: float) -> void:
    var node := _selected_part()
    if node == null:
        return
    var before: Transform3D = node.transform
    node.scale *= factor
    _push_history({"kind": "part", "node": node, "before": before, "after": node.transform})
    _mark_dirty()
    _geometry_changed()
    _notify("Scaled %s to %.0f%% of prior size" % [node.name, factor * 100.0])

func _show_all_parts() -> void:
    if not isolate_active:
        return
    for part in saved_visibility:
        if is_instance_valid(part):
            part.visible = bool(saved_visibility[part])
    saved_visibility.clear()
    isolate_active = false

func _toggle_isolate() -> void:
    if isolate_active:
        _show_all_parts()
        _notify("All parts visible again.")
        return
    var node := _selected_part()
    if node == null:
        return
    saved_visibility.clear()
    for part in mesh_nodes:
        saved_visibility[part] = part.visible
        part.visible = (part == node)
    isolate_active = true
    _notify("Solo view: %s. Tap SHOW ALL to restore." % node.name)

func _save_draft() -> void:
    if _save_glb(DRAFT_PATH, false):
        _notify("Working draft saved on this phone. Project remains unsaved for export.")

func _restore_draft() -> void:
    if not FileAccess.file_exists(DRAFT_PATH):
        _notify("No working draft yet. Use SAVE DRAFT first.")
        return
    _load_glb(DRAFT_PATH)
    project_name = "Recovered draft"
    _mark_dirty()
    _notify("Working draft restored. Export GLB to keep a permanent copy.")


func _cycle_vertex(direction: int) -> void:
    if edit.target == null:
        return
    var s: int = edit.selected_surface
    var i: int = edit.selected_vertex
    if s < 0:
        s = 0
        i = 0
    else:
        i += direction
        if i < 0:
            s = (s - 1 + edit.surfaces.size()) % edit.surfaces.size()
            var prev: PackedVector3Array = edit.surfaces[s]["arrays"][Mesh.ARRAY_VERTEX]
            i = prev.size() - 1
        else:
            var current: PackedVector3Array = edit.surfaces[s]["arrays"][Mesh.ARRAY_VERTEX]
            if i >= current.size():
                s = (s + 1) % edit.surfaces.size()
                i = 0
    if edit.select_vertex(s, i):
        _update_marker()

func _nudge(direction: Vector3) -> void:
    if move_target_picker != null and move_target_picker.selected == 1:
        _part_transform(direction)
        return
    if not edit.has_selection():
        _notify("Select a point in SHAPE first, or choose WHOLE PART.")
        return
    edit.move_step(direction * float(step_box.value))
    _update_marker()

func _do_undo() -> void:
    if undo_history.is_empty():
        _notify("Nothing to undo yet.")
        return
    var operation: Dictionary = undo_history.pop_back()
    redo_history.append(operation)
    var node: MeshInstance3D = operation["node"]
    if not is_instance_valid(node):
        _notify("Undo target is no longer available.")
        return
    if operation["kind"] == "geometry":
        _select_part_node(node)
        edit.undo()
    elif operation["kind"] == "part":
        node.transform = operation["before"]
    _geometry_changed()
    _mark_dirty()
    _notify("Undid last edit.")

func _do_redo() -> void:
    if redo_history.is_empty():
        _notify("Nothing to redo.")
        return
    var operation: Dictionary = redo_history.pop_back()
    undo_history.append(operation)
    var node: MeshInstance3D = operation["node"]
    if not is_instance_valid(node):
        _notify("Redo target is no longer available.")
        return
    if operation["kind"] == "geometry":
        _select_part_node(node)
        edit.redo()
    elif operation["kind"] == "part":
        node.transform = operation["after"]
    _geometry_changed()
    _mark_dirty()
    _notify("Redid last edit.")

func _select_part_node(node: MeshInstance3D) -> void:
    var index: int = mesh_nodes.find(node)
    if index >= 0:
        _choose_mesh(index)

func _geometry_changed() -> void:
    if edit.target != null:
        wire_preview.global_transform = edit.target.global_transform
        if wire_preview.visible:
            _rebuild_wire_overlay()
    _update_marker()

func _rebuild_wire_overlay() -> void:
    if edit.target == null:
        wire_preview.mesh = null
        return
    # Draw actual triangle edges. Cap the line count for mobile performance.
    var points := PackedVector3Array()
    var max_tris_per_surface := maxi(250, 15000 / maxi(edit.surfaces.size(), 1))
    for surface in edit.surfaces:
        var arrays: Array = surface["arrays"]
        var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
        var tri_count: int = (ids.size() if not ids.is_empty() else verts.size()) / 3
        var stride: int = maxi(1, ceili(float(tri_count) / float(max_tris_per_surface)))
        for t in range(0, tri_count, stride):
            var at: int = t * 3
            var a: int = ids[at] if not ids.is_empty() else at
            var b: int = ids[at + 1] if not ids.is_empty() else at + 1
            var c: int = ids[at + 2] if not ids.is_empty() else at + 2
            if a >= verts.size() or b >= verts.size() or c >= verts.size():
                continue
            points.append_array(PackedVector3Array([
                verts[a], verts[b], verts[b], verts[c], verts[c], verts[a]
            ]))
    if points.is_empty():
        wire_preview.mesh = null
        return
    var line_arrays: Array = []
    line_arrays.resize(Mesh.ARRAY_MAX)
    line_arrays[Mesh.ARRAY_VERTEX] = points
    var overlay := ArrayMesh.new()
    overlay.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, line_arrays)
    wire_preview.mesh = overlay
    wire_preview.global_transform = edit.target.global_transform

func _update_marker() -> void:
    if marker == null:
        return
    marker.visible = edit.has_selection() and (active_tab == 0 or (active_tab == 1 and move_target_picker != null and move_target_picker.selected == 0))
    if not edit.has_selection():
        vertex_label.text = "Vertex: none"
        _update_gizmo()
        return
    var point: Vector3 = edit.vertex_position()
    marker.global_position = edit.target.to_global(point)
    marker.scale = Vector3.ONE * maxf(0.035, orbit_distance * 0.011)
    vertex_label.text = "Point %d\n%.2f, %.2f, %.2f" % [edit.selected_vertex, point.x, point.y, point.z]
    _update_gizmo()

func _frame_model() -> void:
    if mesh_nodes.is_empty():
        return
    var bounds := AABB()
    var found := false
    for instance in mesh_nodes:
        var local_bounds: AABB = instance.get_aabb()
        for x in [0.0, 1.0]:
            for y in [0.0, 1.0]:
                for z in [0.0, 1.0]:
                    var corner: Vector3 = instance.to_global(local_bounds.position + local_bounds.size * Vector3(x, y, z))
                    if not found:
                        bounds = AABB(corner, Vector3.ZERO)
                        found = true
                    else:
                        bounds = bounds.expand(corner)
    if found:
        orbit_center = bounds.get_center()
        orbit_distance = clampf(bounds.size.length() * 1.15, 2.0, 900.0)
        _update_camera()
        _update_marker()

func _update_camera() -> void:
    orbit_pitch = clampf(orbit_pitch, -1.40, 1.40)
    orbit_distance = clampf(orbit_distance, 0.25, 1500.0)
    var look_from := Vector3(
        sin(orbit_yaw) * cos(orbit_pitch),
        sin(orbit_pitch),
        cos(orbit_yaw) * cos(orbit_pitch)
    ) * orbit_distance
    camera.global_position = orbit_center + look_from
    camera.look_at(orbit_center, Vector3.UP)
    _update_gizmo()

func _canvas_to_viewport(position: Vector2) -> Vector2:
    var dimensions: Vector2 = canvas.size
    return position * Vector2(scene_view.size) / Vector2(maxf(dimensions.x, 1.0), maxf(dimensions.y, 1.0))

func _update_gizmo() -> void:
    if gizmo_root == null or camera == null:
        return
    if active_tab != 1 or edit.target == null:
        gizmo_root.visible = false
        return
    var node: MeshInstance3D = edit.target
    var pivot: Vector3
    if move_target_picker != null and move_target_picker.selected == 0:
        if not edit.has_selection():
            gizmo_root.visible = false
            return
        pivot = node.to_global(edit.vertex_position())
    else:
        pivot = node.to_global(node.get_aabb().get_center())
    var length: float = clampf(camera.global_position.distance_to(pivot) * 0.13, 0.20, 80.0)
    gizmo_root.place(pivot, length)
    gizmo_root.visible = true

func _pick_gizmo_axis(position: Vector2) -> int:
    if gizmo_root == null or not gizmo_root.visible:
        return -1
    return gizmo_root.hit_axis(_canvas_to_viewport(position), camera)

func _begin_gizmo_drag(axis: int, position: Vector2) -> bool:
    if axis < 0 or axis > 2 or edit.target == null:
        return false
    gizmo_drag_part = move_target_picker.selected == 1
    if not gizmo_drag_part and not edit.begin_stroke():
        return false
    gizmo_axis = axis
    gizmo_drag_active = true
    gizmo_drag_changed = false
    gizmo_last_world_delta = Vector3.ZERO
    gizmo_start_transform = edit.target.transform
    gizmo_start_world = gizmo_root.center_world()
    gizmo_world_length = gizmo_root.handle_length
    gizmo_drag_start_screen = _canvas_to_viewport(position)
    gizmo_drag_axis_screen = camera.unproject_position(gizmo_root.tip_world(axis)) - camera.unproject_position(gizmo_start_world)
    gizmo_drag_px_length = gizmo_drag_axis_screen.length_squared()
    gizmo_drag_vertex_editor = edit
    _notify("Drag the %s handle to move %s." % [["X (red)", "Y (green)", "Z (blue)"][axis], "part" if gizmo_drag_part else "point"])
    return true

func _gizmo_delta_for_position(position: Vector2) -> Vector3:
    var moved_pixels: Vector2 = _canvas_to_viewport(position) - gizmo_drag_start_screen
    var units: float
    if gizmo_drag_px_length > 225.0:
        units = moved_pixels.dot(gizmo_drag_axis_screen) / gizmo_drag_px_length * (gizmo_world_length * 1.03)
    else:
        units = -moved_pixels.y * gizmo_world_length / 110.0
    units = clampf(units, -100.0, 100.0)
    match gizmo_axis:
        0:
            return Vector3(units, 0, 0)
        1:
            return Vector3(0, units, 0)
        _:
            return Vector3(0, 0, units)

func _apply_gizmo_drag(position: Vector2, force: bool = false) -> void:
    if not gizmo_drag_active or edit.target == null:
        return
    if not force and Time.get_ticks_msec() - last_rebuild_ms < 40:
        return
    var delta: Vector3 = _gizmo_delta_for_position(position)
    if delta.is_equal_approx(gizmo_last_world_delta):
        return
    gizmo_last_world_delta = delta
    gizmo_drag_changed = delta.length_squared() > 0.00000001
    if gizmo_drag_part:
        var parent: Node3D = edit.target.get_parent() as Node3D
        if parent == null:
            return
        edit.target.transform = gizmo_start_transform
        edit.target.position += parent.global_transform.basis.inverse() * delta
        _geometry_changed()
    else:
        var local_delta: Vector3 = edit.target.global_transform.basis.inverse() * delta
        edit.apply_stroke_delta(local_delta)
    last_rebuild_ms = Time.get_ticks_msec()

func _finish_gizmo_drag() -> void:
    if not gizmo_drag_active:
        return
    if gizmo_drag_part:
        var node: MeshInstance3D = edit.target
        if node != null and not node.transform.is_equal_approx(gizmo_start_transform):
            _push_history({"kind":"part", "node":node, "before":gizmo_start_transform, "after":node.transform})
            _mark_dirty()
    elif gizmo_drag_vertex_editor != null:
        gizmo_drag_vertex_editor.end_stroke()
    gizmo_drag_active = false
    gizmo_drag_part = false
    gizmo_axis = -1
    gizmo_drag_vertex_editor = null
    _update_gizmo()

func _pick_part(position: Vector2) -> bool:
    if mesh_nodes.is_empty():
        return false
    var screen: Vector2 = _canvas_to_viewport(position)
    var ray_origin: Vector3 = camera.project_ray_origin(screen)
    var ray_direction: Vector3 = camera.project_ray_normal(screen)
    var best_depth: float = INF
    var best_part := -1
    for i in range(mesh_nodes.size()):
        var part: MeshInstance3D = mesh_nodes[i]
        if not part.visible or part.mesh == null:
            continue
        var local_start: Vector3 = part.to_local(ray_origin)
        var local_direction: Vector3 = part.global_transform.basis.inverse() * ray_direction
        var hit: Variant = part.get_aabb().grow(0.06).intersects_ray(local_start, local_direction)
        if hit is Vector3:
            var hit_world: Vector3 = part.to_global(hit)
            var depth: float = hit_world.distance_squared_to(ray_origin)
            if depth < best_depth:
                best_depth = depth
                best_part = i
    if best_part >= 0:
        _choose_mesh(best_part)
        return true
    return false

func _canvas_input(event: InputEvent) -> void:
    # Android generates both native touch and synthesized mouse events when
    # mouse-from-touch is enabled. Route touch exclusively to viewport gestures;
    # synthesized mouse remains available for Godot's regular GUI buttons.
    var native_android: bool = OS.get_name() == "Android"
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            orbit_distance *= 0.88
            _update_camera()
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            orbit_distance *= 1.12
            _update_camera()
        elif event.button_index == MOUSE_BUTTON_LEFT and not native_android:
            if event.pressed:
                _pointer_start(event.position)
            else:
                _pointer_end()
    elif event is InputEventMouseMotion and pointer_down and not native_android:
        _pointer_move(event.position)
    elif event is InputEventScreenTouch:
        if event.pressed:
            touch_positions[event.index] = event.position
            if touch_positions.size() == 1:
                _pointer_start(event.position)
            else:
                _pointer_end()
                last_pinch_distance = _touch_span()
                last_pinch_midpoint = _touch_midpoint()
        else:
            touch_positions.erase(event.index)
            if touch_positions.is_empty():
                _pointer_end()
            else:
                last_pinch_distance = 0.0
                last_pinch_midpoint = Vector2.ZERO
    elif event is InputEventScreenDrag:
        touch_positions[event.index] = event.position
        if touch_positions.size() >= 2:
            var span := _touch_span()
            var midpoint := _touch_midpoint()
            if last_pinch_distance > 1.0 and span > 1.0:
                orbit_distance *= last_pinch_distance / span
                if last_pinch_midpoint != Vector2.ZERO:
                    var shift := midpoint - last_pinch_midpoint
                    orbit_center -= camera.global_transform.basis.x * shift.x * orbit_distance * 0.0017
                    orbit_center += camera.global_transform.basis.y * shift.y * orbit_distance * 0.0017
                _update_camera()
            last_pinch_distance = span
            last_pinch_midpoint = midpoint
        elif pointer_down:
            _pointer_move(event.position)

func _touch_span() -> float:
    var points := touch_positions.values()
    if points.size() < 2:
        return 0.0
    return points[0].distance_to(points[1])

func _touch_midpoint() -> Vector2:
    var points := touch_positions.values()
    if points.size() < 2:
        return Vector2.ZERO
    return (points[0] + points[1]) * 0.5

func _pointer_start(position: Vector2) -> void:
    pointer_down = true
    pointer_dragging_vertex = false
    pointer_origin = position
    pointer_last = position
    stroke_moved = false
    if active_tab == 1:
        var hit_axis: int = _pick_gizmo_axis(position)
        if hit_axis >= 0 and _begin_gizmo_drag(hit_axis, position):
            return
    if edit_toggle.button_pressed and active_tab == 0 and _pick_vertex(position):
        pointer_dragging_vertex = edit.begin_stroke()
        _update_marker()

func _pointer_move(position: Vector2) -> void:
    if not pointer_down:
        return
    var displacement := position - pointer_last
    pointer_last = position
    if gizmo_drag_active:
        _apply_gizmo_drag(position)
        return
    if pointer_dragging_vertex:
        var delta_pixels := position - pointer_origin
        var scale := orbit_distance * 0.0017
        var delta_world := camera.global_transform.basis.x * delta_pixels.x * scale
        delta_world += camera.global_transform.basis.y * -delta_pixels.y * scale
        var delta_local: Vector3 = edit.target.global_transform.basis.inverse() * delta_world
        match axis_picker.selected:
            1:
                delta_local = Vector3(delta_pixels.x * scale, 0, 0)
            2:
                delta_local = Vector3(0, -delta_pixels.y * scale, 0)
            3:
                delta_local = Vector3(0, 0, delta_pixels.x * scale)
        if Time.get_ticks_msec() - last_rebuild_ms > 45:
            edit.apply_stroke_delta(delta_local)
            last_rebuild_ms = Time.get_ticks_msec()
            stroke_moved = true
    else:
        orbit_yaw -= displacement.x * 0.007
        orbit_pitch += displacement.y * 0.007
        _update_camera()

func _pointer_end() -> void:
    if not pointer_down:
        return
    if gizmo_drag_active:
        _apply_gizmo_drag(pointer_last, true)
        _finish_gizmo_drag()
        pointer_down = false
        pointer_dragging_vertex = false
        return
    if not pointer_dragging_vertex and pointer_last.distance_squared_to(pointer_origin) < 100.0:
        if active_tab == 1:
            _pick_part(pointer_origin)
        elif active_tab == 0:
            if not _pick_vertex(pointer_origin):
                _pick_part(pointer_origin)
            _update_marker()
    if pointer_dragging_vertex:
        # The final position is committed even if drag throttling skipped a frame.
        if pointer_last.distance_squared_to(pointer_origin) > 4.0:
            var px := pointer_last - pointer_origin
            var scale := orbit_distance * 0.0017
            var d_world := camera.global_transform.basis.x * px.x * scale
            d_world += camera.global_transform.basis.y * -px.y * scale
            var d_local: Vector3 = edit.target.global_transform.basis.inverse() * d_world
            match axis_picker.selected:
                1:
                    d_local = Vector3(px.x * scale, 0, 0)
                2:
                    d_local = Vector3(0, -px.y * scale, 0)
                3:
                    d_local = Vector3(0, 0, px.x * scale)
            edit.apply_stroke_delta(d_local)
        edit.end_stroke()
        _update_marker()
    pointer_down = false
    pointer_dragging_vertex = false

func _notification(what: int) -> void:
    # A lost window focus must never leave a vertex stroke or drag captured.
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        if pointer_down:
            _pointer_end()
        touch_positions.clear()
        last_pinch_distance = 0.0
        last_pinch_midpoint = Vector2.ZERO

func _pick_vertex(position: Vector2) -> bool:
    if edit.target == null:
        return false
    var viewport_size := Vector2(scene_view.size)
    var canvas_size := canvas.size
    var mapped := position * viewport_size / Vector2(maxf(canvas_size.x, 1), maxf(canvas_size.y, 1))
    var best_distance := 30.0
    var best_depth := INF
    var best_s := -1
    var best_v := -1
    for s in range(edit.surfaces.size()):
        var vertices: PackedVector3Array = edit.surfaces[s]["arrays"][Mesh.ARRAY_VERTEX]
        var stride := maxi(1, ceili(float(vertices.size()) / 30000.0))
        for i in range(0, vertices.size(), stride):
            var world: Vector3 = edit.target.to_global(vertices[i])
            if camera.is_position_behind(world):
                continue
            var point := camera.unproject_position(world)
            var dist := point.distance_to(mapped)
            var depth := camera.global_position.distance_squared_to(world)
            if dist <= best_distance and (dist < best_distance - 1.0 or depth < best_depth):
                best_distance = dist
                best_depth = depth
                best_s = s
                best_v = i
    if best_s < 0:
        return false
    return edit.select_vertex(best_s, best_v)

func _create_demo() -> void:
    if dirty and asset_host.get_child_count() > 0:
        if not _save_glb(DRAFT_PATH, false):
            _notify("Demo canceled: unable to back up your unsaved work.")
            return
    _clear_asset()
    project_name = "Hovercraft Demo"
    var demo := Node3D.new()
    demo.name = "Hovercraft_Demo"
    asset_host.add_child(demo)
    var positions := PackedVector3Array()
    var widths := [0.53, 0.83, 1.14, 1.43, 1.27, 0.95]
    var stations := [-2.5, -1.6, -0.6, 0.4, 1.45, 2.4]
    for n in range(stations.size()):
        var w: float = widths[n]
        var z: float = stations[n]
        for x_factor in [-1.0, 0.0, 1.0]:
            var rise: float = 0.20 if x_factor != 0 else 0.43
            positions.append(Vector3(w * x_factor, rise, z))
    for n in range(stations.size()):
        var w: float = widths[n]
        var z: float = stations[n]
        for x_factor in [-1.0, 0.0, 1.0]:
            positions.append(Vector3(w * x_factor, -0.18, z))
    var faces := PackedInt32Array()
    for layer in range(2):
        var offset := layer * 18
        for n in range(5):
            for col in range(2):
                var a := offset + n * 3 + col
                var b := offset + (n + 1) * 3 + col
                if layer == 0:
                    faces.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
                else:
                    faces.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
    for n in range(5):
        var a := n * 3
        var b := (n + 1) * 3
        faces.append_array(PackedInt32Array([a, b, a + 18, a + 18, b, b + 18]))
        faces.append_array(PackedInt32Array([a + 2, a + 20, b + 2, a + 20, b + 20, b + 2]))
    for col in range(2):
        faces.append_array(PackedInt32Array([col, col + 18, col + 1, col + 1, col + 18, col + 19]))
        faces.append_array(PackedInt32Array([15 + col, 16 + col, 33 + col, 16 + col, 34 + col, 33 + col]))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = positions
    arrays[Mesh.ARRAY_INDEX] = faces
    var hull := ArrayMesh.new()
    hull.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var paint := StandardMaterial3D.new()
    paint.albedo_color = Color("#2dc4b5")
    paint.metallic = 0.55
    paint.roughness = 0.27
    paint.cull_mode = BaseMaterial3D.CULL_DISABLED
    hull.surface_set_material(0, paint)
    var body := MeshInstance3D.new()
    body.name = "Hull_Control_Cage"
    body.mesh = hull
    demo.add_child(body)

    var canopy := MeshInstance3D.new()
    canopy.name = "Cabin"
    var cabin_box := BoxMesh.new()
    cabin_box.size = Vector3(1.1, 0.48, 1.35)
    canopy.mesh = cabin_box
    canopy.position = Vector3(0, 0.55, 0.18)
    canopy.rotation.x = 0.09
    var glass := StandardMaterial3D.new()
    glass.albedo_color = Color("#32617e")
    glass.metallic = 0.48
    glass.roughness = 0.16
    canopy.material_override = glass
    demo.add_child(canopy)
    for side in [-1.0, 1.0]:
        var pod := MeshInstance3D.new()
        pod.name = "Repulsor_L" if side < 0 else "Repulsor_R"
        var pod_box := BoxMesh.new()
        pod_box.size = Vector3(0.53, 0.35, 1.7)
        pod.mesh = pod_box
        pod.position = Vector3(side * 1.25, -0.24, 0.58)
        var charcoal := StandardMaterial3D.new()
        charcoal.albedo_color = Color("#566475")
        charcoal.metallic = 0.7
        charcoal.roughness = 0.32
        pod.material_override = charcoal
        demo.add_child(pod)
    _index_meshes()
    _frame_model()
    _mark_clean()
    _notify("Demo loaded. Try moving a booster PART, then EXPORT GLB.")

func _notify(message: String) -> void:
    if status_label != null:
        status_label.text = message
    print("MODEL_FORGE: ", message)
