extends Control
## Model Forge v0.7: precise part picking, zebra inspection and scrollable phone tools.
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
var part_search: LineEdit
var filtered_mesh_indices: Array = []
var selected_mesh_index: int = -1
var highlight_toggle: CheckButton
var selection_overlay_material: StandardMaterial3D
var selection_outline: MeshInstance3D
var selected_overlay_mesh: MeshInstance3D
var selected_original_overlay: Material
var selection_highlight_enabled: bool = true
var gizmo_drag_model: bool = false
var gizmo_model_before: Array = []
var mirror_toggle: CheckButton
var soft_toggle: CheckButton
var grid_node: MeshInstance3D
var clay_toggle: CheckButton
var zebra_toggle: CheckButton
var zebra_slider: HSlider
var zebra_material: ShaderMaterial
var zebra_enabled: bool = false
var zebra_overrides: Dictionary = {}
var zebra_band_count: float = 12.0
var clay_enabled: bool = false
var previous_overrides: Dictionary = {}
var clay_material: ShaderMaterial
var clay_facets_toggle: CheckButton
var clay_light_angle: float = 0.45
var scene_environment: Environment
var studio_key: DirectionalLight3D
var studio_fill: DirectionalLight3D
var texture_detail_slider: HSlider
var texture_detail_level: float = 0.70
var build_kind_picker: OptionButton
var build_name: LineEdit
var build_width: SpinBox
var build_height: SpinBox
var build_length: SpinBox
var build_size_label: Label
var build_counter: int = 0
var clay_facets_enabled: bool = true
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
    _apply_touch_ui(self)
    _create_scene()
    _create_file_dialogs()
    _connect_android_file_bridge()
    _create_demo()
    _mark_clean()
    _notify("Ready. Select a part, then tap a point or use MOVE.")

func _create_ui() -> void:
    # Five task-specific, swipeable native Android tool tabs.
    var whole := VBoxContainer.new()
    whole.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    whole.add_theme_constant_override("separation", 0)
    add_child(whole)
    var header := PanelContainer.new()
    _panel_style(header, DARK)
    whole.add_child(header)
    var toolbar := HBoxContainer.new()
    toolbar.add_theme_constant_override("separation", 8)
    var toolbar_scroll := ScrollContainer.new()
    toolbar_scroll.custom_minimum_size.y = 76
    toolbar_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    toolbar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    toolbar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    header.add_child(toolbar_scroll)
    toolbar_scroll.add_child(toolbar)
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
    for tab_name in ["SHAPE", "MOVE", "BUILD", "VIEW", "FILES"]:
        var index: int = tab_buttons.size()
        var tab := _button(tabs, tab_name, func(): _show_tab(index))
        tab_buttons.append(tab)
    var pages := Control.new()
    pages.custom_minimum_size.y = 266
    stack.add_child(pages)
    for i in range(5):
        var page := VBoxContainer.new()
        page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        page.add_theme_constant_override("separation", 8)
        pages.add_child(page)
        page.visible = false
        tool_panels.append(page)

    # Shape: choose a part, select a point, optionally bend its neighbors.
    var shape_row := _mobile_row(tool_panels[0])
    mesh_picker = OptionButton.new()
    mesh_picker.custom_minimum_size = Vector2(205, 56)
    mesh_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    mesh_picker.item_selected.connect(_choose_filtered_mesh)
    shape_row.add_child(mesh_picker)
    part_search = LineEdit.new()
    part_search.placeholder_text = "Find part..."
    part_search.custom_minimum_size = Vector2(190, 56)
    part_search.add_theme_font_size_override("font_size", 19)
    part_search.text_changed.connect(_part_search_changed)
    shape_row.add_child(part_search)
    _button(shape_row, "◀ PART", func(): _cycle_part(-1))
    _button(shape_row, "PART ▶", func(): _cycle_part(1))
    _button(shape_row, "◀ POINT", func(): _cycle_vertex(-1))
    _button(shape_row, "POINT ▶", func(): _cycle_vertex(1))
    _button(shape_row, "FOCUS", _focus_part)
    _button(shape_row, "SOLO", _toggle_isolate)
    vertex_label = _label(shape_row, "No point", 15, Color.WHITE)
    vertex_label.custom_minimum_size.x = 158
    var shape_options := _mobile_row(tool_panels[0])
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
    soft_radius_slider.custom_minimum_size.x = 265
    soft_radius_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    soft_radius_slider.min_value = 0.15
    soft_radius_slider.max_value = 4.0
    soft_radius_slider.step = 0.05
    soft_radius_slider.value = 0.75
    soft_radius_slider.editable = false
    soft_radius_slider.value_changed.connect(_radius_changed)
    shape_options.add_child(soft_radius_slider)
    _button(shape_options, "RADIUS −", func(): _nudge_radius(-0.05))
    _button(shape_options, "RADIUS +", func(): _nudge_radius(0.05))
    _button(shape_options, "SMOOTH", _smooth_selection)
    var surface_row := _mobile_row(tool_panels[0])
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
    var target_row := _mobile_row(tool_panels[1])
    _label(target_row, "EDIT", 17, ACCENT)
    move_target_picker = OptionButton.new()
    move_target_picker.custom_minimum_size = Vector2(275, 52)
    move_target_picker.add_item("SELECTED POINT")
    move_target_picker.add_item("WHOLE PART")
    move_target_picker.add_item("WHOLE MODEL")
    move_target_picker.select(1)
    move_target_picker.item_selected.connect(_move_target_changed)
    target_row.add_child(move_target_picker)
    part_info_label = _label(target_row, "Hull", 16, Color.WHITE)
    part_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _button(target_row, "ROTATE −5°", func(): _rotate_part(-5.0))
    _button(target_row, "ROTATE +5°", func(): _rotate_part(5.0))
    _button(target_row, "SMALLER", func(): _scale_part(0.95))
    _button(target_row, "BIGGER", func(): _scale_part(1.05))
    var move_row := _mobile_row(tool_panels[1])
    for item in [
        ["X −", Vector3.LEFT], ["X +", Vector3.RIGHT],
        ["Y −", Vector3.DOWN], ["Y +", Vector3.UP],
        ["Z −", Vector3(0, 0, -1)], ["Z +", Vector3(0, 0, 1)]
    ]:
        var direction: Vector3 = item[1]
        _button(move_row, item[0], func(): _nudge(direction))
    var move_settings := _mobile_row(tool_panels[1])
    _label(move_settings, "STEP SIZE", 17, MUTED)
    step_box = SpinBox.new()
    step_box.custom_minimum_size = Vector2(235, 76)
    step_box.min_value = 0.0
    step_box.max_value = 20.0
    step_box.step = 0.01
    step_box.value = 0.10
    move_settings.add_child(step_box)
    _button(move_settings, "− STEP", func(): _nudge_step(-0.01))
    _button(move_settings, "+ STEP", func(): _nudge_step(0.01))
    _label(move_settings, "DRAG ALONG", 17, MUTED)
    axis_picker = OptionButton.new()
    axis_picker.custom_minimum_size = Vector2(225, 56)
    axis_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for axis in ["SCREEN", "X AXIS", "Y AXIS", "Z AXIS"]:
        axis_picker.add_item(axis)
    move_settings.add_child(axis_picker)
    _label(move_settings, "RED X • GREEN Y • BLUE Z: drag to move. WHOLE MODEL moves every part.", 15, ACCENT)

    # View: preset cameras, wireframe inspection and orbit-only mode.
    var views := _mobile_row(tool_panels[3])
    _button(views, "FIT ALL", _frame_model)
    _button(views, "FOCUS PART", _focus_part)
    _button(views, "FRONT", func(): _preset_view(0))
    _button(views, "SIDE", func(): _preset_view(1))
    _button(views, "TOP", func(): _preset_view(2))
    _button(views, "3/4", func(): _preset_view(3))
    var view_row := _mobile_row(tool_panels[3])
    wire_toggle = CheckButton.new()
    wire_toggle.text = "WIREFRAME"
    wire_toggle.toggled.connect(_wire_changed)
    view_row.add_child(wire_toggle)
    clay_toggle = CheckButton.new()
    clay_toggle.text = "CLAY"
    clay_toggle.toggled.connect(_set_clay)
    view_row.add_child(clay_toggle)
    clay_facets_toggle = CheckButton.new()
    clay_facets_toggle.text = "SHOW FACETS"
    clay_facets_toggle.button_pressed = true
    clay_facets_toggle.toggled.connect(_clay_facets_changed)
    view_row.add_child(clay_facets_toggle)
    _button(view_row, "LIGHT ◀", func(): _sweep_clay_light(-0.35))
    _button(view_row, "LIGHT ▶", func(): _sweep_clay_light(0.35))
    zebra_toggle = CheckButton.new()
    zebra_toggle.text = "ZEBRA STRIPES"
    zebra_toggle.toggled.connect(_set_zebra)
    view_row.add_child(zebra_toggle)
    _label(view_row, "BANDS", 15, MUTED)
    zebra_slider = HSlider.new()
    zebra_slider.custom_minimum_size.x = 265
    zebra_slider.min_value = 4.0
    zebra_slider.max_value = 25.0
    zebra_slider.step = 1.0
    zebra_slider.value = 12.0
    zebra_slider.value_changed.connect(_zebra_bands_changed)
    view_row.add_child(zebra_slider)
    _button(view_row, "BANDS −", func(): _nudge_zebra(-1.0))
    _button(view_row, "BANDS +", func(): _nudge_zebra(1.0))
    highlight_toggle = CheckButton.new()
    highlight_toggle.text = "HIGHLIGHT PART"
    highlight_toggle.button_pressed = true
    highlight_toggle.toggled.connect(_highlight_toggled)
    view_row.add_child(highlight_toggle)
    _button(view_row, "SOLO PART", _toggle_isolate)
    _button(view_row, "SHOW ALL", _show_all_parts)
    _button(view_row, "PHOTO", _toggle_reference)
    _button(view_row, "NORMALS", _recalculate_normals)
    _label(view_row, "Drag = rotate • pinch = zoom • two-finger drag = pan", 15, MUTED)

    # BUILD: true independent editable meshes and exact local-axis sizing.
    var build_create := _mobile_row(tool_panels[2])
    _label(build_create, "CREATE PART", 18, ACCENT)
    build_kind_picker = OptionButton.new()
    for primitive_name in ["BOX", "CYLINDER", "SPHERE", "CAPSULE"]:
        build_kind_picker.add_item(primitive_name)
    build_create.add_child(build_kind_picker)
    build_name = LineEdit.new()
    build_name.placeholder_text = "New part name"
    build_name.custom_minimum_size.x = 235
    build_create.add_child(build_name)
    _button(build_create, "+ ADD OBJECT", _add_object)
    _button(build_create, "DUPLICATE", _duplicate_selected_part)
    _button(build_create, "DELETE PART", _delete_selected_part)

    var dimension_row := _mobile_row(tool_panels[2])
    _label(dimension_row, "SIZE  (GLB units)", 18, ACCENT)
    build_width = _build_dimension_field(dimension_row, "X WIDTH")
    build_height = _build_dimension_field(dimension_row, "Y HEIGHT")
    build_length = _build_dimension_field(dimension_row, "Z LENGTH")
    _button(dimension_row, "APPLY SIZE", _apply_part_dimensions)
    _button(dimension_row, "READ PART", _update_dimensions_fields)

    var build_info := _mobile_row(tool_panels[2])
    build_size_label = _label(build_info, "Select a part to resize, or enter dimensions to create an object.", 18, MUTED)
    _button(build_info, "FOCUS PART", _focus_part)
    _button(build_info, "BACK TO MOVE", func(): _show_tab(1))

    var contrast_row := _mobile_row(tool_panels[3])
    _label(contrast_row, "TEXTURE CONTRAST", 18, ACCENT)
    texture_detail_slider = HSlider.new()
    texture_detail_slider.min_value = 0.0
    texture_detail_slider.max_value = 1.0
    texture_detail_slider.step = 0.05
    texture_detail_slider.value = texture_detail_level
    texture_detail_slider.custom_minimum_size.x = 280.0
    texture_detail_slider.value_changed.connect(_texture_detail_changed)
    contrast_row.add_child(texture_detail_slider)
    _button(contrast_row, "SOFTER", func(): _nudge_texture_detail(-0.15))
    _button(contrast_row, "MORE DEPTH", func(): _nudge_texture_detail(0.15))
    _label(contrast_row, "Changes editor lighting only, not the GLB's real materials.", 16, MUTED)

    # Files: clear separation between a private working draft and exported GLB.
    var file_row := _mobile_row(tool_panels[4])
    _button(file_row, "OPEN GLB", _request_open_glb)
    _button(file_row, "EXPORT GLB", _request_save_glb)
    _button(file_row, "SAVE DRAFT", _save_draft)
    _button(file_row, "RESTORE DRAFT", _restore_draft)
    var more_buttons := _mobile_row(tool_panels[4])
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
    help_dialog.dialog_text = "MODEL FORGE — START HERE\n\n1. OPEN a GLB or use the demo.\n2. SHAPE: tap an exterior triangle to select its nearest vertex. Hidden internal points cannot be picked through the surface. Enable EDIT POINTS only when ready to deform.\n3. MOVE: select POINT, WHOLE PART or WHOLE MODEL. Drag colored XYZ handles or use precision buttons.\n4. BUILD: add Box, Cylinder, Sphere or Capsule parts, choose a name, duplicate or delete selected parts, and apply precise local X / Y / Z dimensions (GLB units). Undo restores deleted parts.\n5. VIEW: use TEXTURE CONTRAST to reduce flat lighting while retaining the model's materials; Clay and Zebra are inspection-only, and View shows the selection outline without tinting textures.\n6. FILES: save drafts and export all modeled parts to a new GLB.\n\nPinch to zoom; two-finger drag pans. Import materials are not overwritten by the VIEW lighting controls."
    add_child(help_dialog)
    _show_tab(0)

func _build_dimension_field(row: HBoxContainer, caption: String) -> SpinBox:
    _label(row, caption, 17, MUTED)
    var spin := SpinBox.new()
    spin.min_value = 0.01
    spin.max_value = 10000.0
    spin.step = 0.01
    spin.value = 1.0
    spin.custom_minimum_size = Vector2(205, 76)
    row.add_child(spin)
    return spin

func _texture_detail_changed(value: float) -> void:
    texture_detail_level = clampf(value, 0.0, 1.0)
    _apply_texture_detail()

func _nudge_texture_detail(delta: float) -> void:
    texture_detail_slider.value = clampf(texture_detail_slider.value + delta, 0.0, 1.0)

func _apply_texture_detail() -> void:
    # Lighting-only (no model material rewrite). Broad fill conceals normals;
    # directional key/fill separation exposes real panel curvature.
    if scene_environment == null or studio_key == null or studio_fill == null:
        return
    scene_environment.ambient_light_energy = lerpf(0.70, 0.22, texture_detail_level)
    studio_key.light_energy = lerpf(1.15, 1.65, texture_detail_level)
    studio_fill.light_energy = lerpf(0.55, 0.19, texture_detail_level)

func _desired_dimensions() -> Vector3:
    return Vector3(float(build_width.value), float(build_height.value), float(build_length.value))

func _part_local_dimensions(part: MeshInstance3D) -> Vector3:
    if part == null or part.mesh == null:
        return Vector3.ZERO
    var dims: Vector3 = part.get_aabb().size
    return Vector3(dims.x * absf(part.scale.x), dims.y * absf(part.scale.y), dims.z * absf(part.scale.z))

func _update_dimensions_fields() -> void:
    if build_width == null or build_height == null or build_length == null:
        return
    if edit.target == null or edit.target.mesh == null:
        return
    var dims: Vector3 = _part_local_dimensions(edit.target)
    for target_field in [[build_width, dims.x], [build_height, dims.y], [build_length, dims.z]]:
        var field: SpinBox = target_field[0]
        field.set_value_no_signal(maxf(float(target_field[1]), 0.01))
    if build_size_label != null:
        build_size_label.text = "Selected %s: %.3f × %.3f × %.3f (local GLB units)" % [
            edit.target.name, dims.x, dims.y, dims.z
        ]

func _apply_part_dimensions() -> void:
    var part: MeshInstance3D = _selected_part()
    if part == null or part.mesh == null:
        _notify("Choose a part to dimension.")
        return
    var current: Vector3 = _part_local_dimensions(part)
    if minf(current.x, minf(current.y, current.z)) <= 0.000001:
        _notify("Cannot dimension a zero-thickness axis. Use a solid primitive.")
        return
    var desired: Vector3 = _desired_dimensions()
    if minf(desired.x, minf(desired.y, desired.z)) < 0.01:
        _notify("Dimensions must be at least 0.01 GLB units.")
        return
    var factor: Vector3 = desired / current
    if factor.is_equal_approx(Vector3.ONE):
        return
    var before: Transform3D = part.transform
    part.scale *= factor
    _push_history({"kind":"part", "node":part, "before":before, "after":part.transform})
    _mark_dirty()
    _geometry_changed()
    _update_dimensions_fields()
    _notify("Sized %s to X %.2f / Y %.2f / Z %.2f GLB units." % [part.name, desired.x, desired.y, desired.z])

func _new_mesh_material() -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#4b778a")
    material.metallic = 0.46
    material.roughness = 0.38
    return material

func _add_object() -> void:
    var part := MeshInstance3D.new()
    var new_mesh: PrimitiveMesh
    match build_kind_picker.selected:
        1:
            new_mesh = CylinderMesh.new()
        2:
            new_mesh = SphereMesh.new()
        3:
            new_mesh = CapsuleMesh.new()
        _:
            new_mesh = BoxMesh.new()
    new_mesh.material = _new_mesh_material()
    part.mesh = new_mesh
    build_counter += 1
    var requested_name: String = build_name.text.strip_edges()
    part.name = requested_name if not requested_name.is_empty() else "%s_%03d" % [
        ["Box","Cylinder","Sphere","Capsule"][build_kind_picker.selected], build_counter
    ]
    var raw: Vector3 = part.get_aabb().size
    var desired: Vector3 = _desired_dimensions()
    part.scale = Vector3(
        desired.x / maxf(raw.x, 0.0001),
        desired.y / maxf(raw.y, 0.0001),
        desired.z / maxf(raw.z, 0.0001)
    )
    # Add at the camera's current orbit target so newly created parts are seen.
    part.position = asset_host.to_local(orbit_center)
    _register_added_part(part, asset_host, true)
    build_name.text = ""
    _notify("Added editable %s. Use MOVE for XYZ placement or BUILD for exact dimensions." % part.name)

func _duplicate_selected_part() -> void:
    var original: MeshInstance3D = _selected_part()
    if original == null or original.mesh == null:
        _notify("Select a part to duplicate.")
        return
    var parent: Node3D = original.get_parent() as Node3D
    if parent == null:
        return
    var new_part := MeshInstance3D.new()
    new_part.name = original.name + "_Copy"
    new_part.mesh = original.mesh.duplicate(true) as Mesh
    new_part.transform = original.transform
    new_part.position.x += maxf(0.10, original.get_aabb().size.x * 0.15)
    if previous_overrides.has(original):
        new_part.material_override = previous_overrides[original]
    elif zebra_overrides.has(original):
        new_part.material_override = zebra_overrides[original]
    else:
        new_part.material_override = original.material_override
    _register_added_part(new_part, parent, true)
    _notify("Duplicated %s; move the copy with XYZ handles." % original.name)

func _register_added_part(part: MeshInstance3D, parent: Node3D, add_to_history: bool) -> void:
    parent.add_child(part)
    mesh_nodes.append(part)
    _refresh_part_picker()
    _choose_mesh(mesh_nodes.size() - 1)
    if clay_enabled:
        previous_overrides[part] = part.material_override
        part.material_override = clay_material
    elif zebra_enabled:
        zebra_overrides[part] = part.material_override
        part.material_override = zebra_material
    if add_to_history:
        _push_history({"kind":"create", "node":part, "parent":parent})
        _mark_dirty()
    _geometry_changed()

func _detach_part(part: MeshInstance3D) -> void:
    if part == null or not is_instance_valid(part) or part.get_parent() == null:
        return
    _show_all_parts()
    _clear_selection_highlight()
    previous_overrides.erase(part)
    zebra_overrides.erase(part)
    editor_by_mesh.erase(part)
    var previous_index: int = mesh_nodes.find(part)
    mesh_nodes.erase(part)
    part.get_parent().remove_child(part)
    selected_mesh_index = -1
    _refresh_part_picker()
    if not mesh_nodes.is_empty():
        _choose_mesh(clampi(previous_index, 0, mesh_nodes.size() - 1))
    else:
        edit.set_target(null)
        _geometry_changed()

func _delete_selected_part() -> void:
    var part: MeshInstance3D = _selected_part()
    if part == null:
        _notify("Select a part to delete.")
        return
    var parent: Node3D = part.get_parent() as Node3D
    if parent == null:
        return
    _detach_part(part)
    _push_history({"kind":"delete", "node":part, "parent":parent})
    _mark_dirty()
    _notify("Deleted part (UNDO restores it).")

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
    _refresh_selection_highlight()
    _update_marker()
    if status_label != null:
        var messages := [
            "SHAPE • Tap visible frontmost triangles to pick exterior vertices.",
            "MOVE • Place one component or WHOLE MODEL using XYZ handles.",
            "BUILD • Add, duplicate or delete parts; enter exact X/Y/Z dimensions.",
            "VIEW • Texture contrast, Clay, Zebra and camera angles.",
            "FILES • Open, export, save or restore a private draft."
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
    elif active_tab == 2:
        touch_hint.text = "BUILD • Add objects and dimension selected parts; edits affect real GLB geometry"
    elif active_tab == 1:
        if _is_whole_model_mode():
            touch_hint.text = "WHOLE MODEL • All parts together • Drag RED X / GREEN Y / BLUE Z"
        else:
            touch_hint.text = "MOVE • Amber highlighted part • Tap part to select • Drag XYZ handle"
    else:
        touch_hint.text = "VIEW • Drag to rotate • Two fingers to zoom / pan"


func _move_target_changed(index: int) -> void:
    if gizmo_drag_active:
        _finish_gizmo_drag()
        pointer_down = false
    _refresh_selection_highlight()
    _update_project_header()
    _update_marker()
    _update_touch_hint()
    var hints := [
        "SELECTED POINT: drag gizmo to change mesh geometry.",
        "WHOLE PART: drag gizmo or rotate/scale one component.",
        "WHOLE MODEL: move, rotate or scale all %d parts together." % mesh_nodes.size()
    ]
    _notify(hints[index])

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

func _nudge_radius(direction: float) -> void:
    soft_radius_slider.value = clampf(
        soft_radius_slider.value + direction, soft_radius_slider.min_value, soft_radius_slider.max_value
    )

func _nudge_zebra(direction: float) -> void:
    zebra_slider.value = clampf(zebra_slider.value + direction, zebra_slider.min_value, zebra_slider.max_value)

func _nudge_step(direction: float) -> void:
    step_box.value = clampf(snappedf(step_box.value + direction, 0.01), step_box.min_value, step_box.max_value)

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

func _clay_facets_changed(enabled: bool) -> void:
    clay_facets_enabled = enabled
    if clay_material != null:
        clay_material.set_shader_parameter("facet_strength", 0.85 if enabled else 0.05)
    _notify("Clay: visible polygon planes" if enabled else "Clay: smooth imported vertex normals")

func _sweep_clay_light(delta: float) -> void:
    clay_light_angle = wrapf(clay_light_angle + delta, -PI, PI)
    if clay_material != null:
        clay_material.set_shader_parameter("light_azimuth", clay_light_angle)
    if not clay_enabled:
        _notify("Turn on CLAY to view the light sweep.")
    else:
        _notify("Clay key light: %.0f°" % rad_to_deg(clay_light_angle))

func _set_clay(enabled: bool) -> void:
    if clay_enabled == enabled:
        return
    if enabled and zebra_enabled:
        _set_zebra(false)
    if enabled:
        # Amber paint across selected polygons hides the very details clay
        # inspection must reveal; the separate amber outline remains visible.
        _clear_selection_highlight()
        if clay_material == null:
            var studio_shader: Shader = load("res://shaders/clay_studio.gdshader")
            if studio_shader == null:
                _notify("Studio Clay shader unavailable; no materials changed.")
                if clay_toggle != null:
                    clay_toggle.set_pressed_no_signal(false)
                return
            clay_material = ShaderMaterial.new()
            clay_material.shader = studio_shader
        clay_material.set_shader_parameter("light_azimuth", clay_light_angle)
        clay_material.set_shader_parameter("facet_strength", 0.85 if clay_facets_enabled else 0.05)
        previous_overrides.clear()
        for instance in mesh_nodes:
            if is_instance_valid(instance):
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
    _refresh_selection_highlight()
    if status_label != null:
        _notify("Studio Clay: drag LIGHT ◀/▶ to sweep detail; SHOW FACETS toggles geometric normals." if enabled else "Original GLB materials restored.")

func _zebra_bands_changed(value: float) -> void:
    zebra_band_count = value
    if zebra_material != null:
        zebra_material.set_shader_parameter("stripe_density", value)
    if zebra_enabled:
        _notify("Zebra inspection: %.0f bands" % value)

func _set_zebra(enabled: bool) -> void:
    if zebra_enabled == enabled:
        return
    if enabled:
        if clay_enabled:
            _set_clay(false)
        _clear_selection_highlight()
        if zebra_material == null:
            var shader: Shader = load("res://shaders/zebra_inspection.gdshader")
            if shader == null:
                _notify("Zebra material unavailable on this build.")
                if zebra_toggle != null:
                    zebra_toggle.set_pressed_no_signal(false)
                return
            zebra_material = ShaderMaterial.new()
            zebra_material.shader = shader
        zebra_material.set_shader_parameter("stripe_density", zebra_band_count)
        zebra_overrides.clear()
        for part in mesh_nodes:
            if is_instance_valid(part):
                zebra_overrides[part] = part.material_override
                part.material_override = zebra_material
    else:
        for part in zebra_overrides:
            if is_instance_valid(part):
                part.material_override = zebra_overrides[part]
        zebra_overrides.clear()
    zebra_enabled = enabled
    if zebra_toggle != null:
        zebra_toggle.set_pressed_no_signal(enabled)
    _refresh_selection_highlight()
    if status_label != null:
        _notify("Zebra: simulated reflection bands show changes in panel normals." if enabled else "Original material appearance restored.")

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

func _touch_knob_texture(active: bool, disabled: bool = false) -> Texture2D:
    # Procedurally paint a 56 px touch handle with a 2 px contrasting rim.
    # Controls remain Android-native Godot widgets; no image asset needed.
    var image := Image.create(56, 56, false, Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
    var outer: Color = Color("#102333")
    var face: Color = Color("#62f2cf") if active else Color("#39cfb1")
    if disabled:
        face = Color("#748895")
    for y in range(56):
        for x in range(56):
            var distance: float = Vector2(float(x) - 27.5, float(y) - 27.5).length()
            if distance > 26.0:
                continue
            var alpha: float = clampf(26.0 - distance, 0.0, 1.0)
            var tint: Color = outer if distance > 23.0 else face
            image.set_pixel(x, y, Color(tint.r, tint.g, tint.b, alpha))
    return ImageTexture.create_from_image(image)

func _touch_track(fill: Color) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = fill
    box.set_corner_radius_all(11)
    box.content_margin_top = 11.0
    box.content_margin_bottom = 11.0
    box.content_margin_left = 8.0
    box.content_margin_right = 8.0
    return box

func _style_touch_slider(slider: HSlider) -> void:
    slider.custom_minimum_size.y = 76.0
    slider.custom_minimum_size.x = maxf(slider.custom_minimum_size.x, 265.0)
    slider.add_theme_icon_override("grabber", _touch_knob_texture(false))
    slider.add_theme_icon_override("grabber_highlight", _touch_knob_texture(true))
    slider.add_theme_icon_override("grabber_disabled", _touch_knob_texture(false, true))
    slider.add_theme_stylebox_override("slider", _touch_track(Color("#304456")))
    slider.add_theme_stylebox_override("grabber_area", _touch_track(Color("#319f8f")))
    slider.add_theme_stylebox_override("grabber_area_highlight", _touch_track(Color("#48cdb4")))
    slider.add_theme_constant_override("grabber_offset", 0)

func _apply_touch_ui(node: Node) -> void:
    # One reusable Android touch scale applied to every current and future tab.
    if node is HSlider:
        _style_touch_slider(node)
    elif node is CheckButton:
        var toggle: CheckButton = node
        toggle.custom_minimum_size.y = maxf(72.0, toggle.custom_minimum_size.y)
        toggle.custom_minimum_size.x = maxf(150.0, toggle.custom_minimum_size.x)
        toggle.add_theme_font_size_override("font_size", 21)
    elif node is OptionButton:
        var picker: OptionButton = node
        picker.custom_minimum_size.y = maxf(74.0, picker.custom_minimum_size.y)
        picker.custom_minimum_size.x = maxf(205.0, picker.custom_minimum_size.x)
        picker.add_theme_font_size_override("font_size", 21)
        var popup_style := Theme.new()
        popup_style.set_font_size("font_size", "PopupMenu", 23)
        popup_style.set_constant("v_separation", "PopupMenu", 16)
        popup_style.set_constant("h_separation", "PopupMenu", 14)
        picker.get_popup().theme = popup_style
    elif node is SpinBox:
        var spin: SpinBox = node
        spin.custom_minimum_size.y = maxf(76.0, spin.custom_minimum_size.y)
        spin.get_line_edit().add_theme_font_size_override("font_size", 23)
    elif node is LineEdit:
        var field: LineEdit = node
        field.custom_minimum_size.y = maxf(74.0, field.custom_minimum_size.y)
        field.add_theme_font_size_override("font_size", 21)
    elif node is Button:
        var btn: Button = node
        btn.custom_minimum_size.y = maxf(70.0, btn.custom_minimum_size.y)
        btn.add_theme_font_size_override("font_size", 21)
    for child in node.get_children():
        if child is Control:
            _apply_touch_ui(child)

func _mobile_row(parent: Node) -> HBoxContainer:
    # Dense editing strips must scroll horizontally on an Android phone.
    # Never shrink or clip the action buttons off the display.
    var strip := ScrollContainer.new()
    strip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    strip.custom_minimum_size.y = 82
    strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(strip)
    var content := HBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    content.add_theme_constant_override("separation", 12)
    strip.add_child(content)
    return content

func _button(parent: Node, caption: String, action: Callable) -> Button:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(96, 70)
    button.add_theme_font_size_override("font_size", 21)
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
    scene_environment = env.environment
    scene_environment.background_mode = Environment.BG_COLOR
    scene_environment.background_color = Color("#1a2837")
    scene_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    scene_environment.ambient_light_color = Color("#b9c8d4")
    scene_world.add_child(env)
    studio_key = DirectionalLight3D.new()
    studio_key.rotation_degrees = Vector3(-43, 35, 0)
    scene_world.add_child(studio_key)
    studio_fill = DirectionalLight3D.new()
    studio_fill.rotation_degrees = Vector3(30, -115, 0)
    scene_world.add_child(studio_fill)
    _apply_texture_detail()
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
    # Non-exportable amber selection cue: transparent surface tint and world-space outline.
    selection_overlay_material = StandardMaterial3D.new()
    selection_overlay_material.albedo_color = Color(1.0, 0.67, 0.24, 0.09)
    selection_overlay_material.emission_enabled = false
    selection_overlay_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    selection_overlay_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    selection_overlay_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
    selection_outline = MeshInstance3D.new()
    selection_outline.name = "SelectedPartOutline"
    var edge_material := StandardMaterial3D.new()
    edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    edge_material.albedo_color = Color("#ffbd52")
    edge_material.no_depth_test = true
    selection_outline.material_override = edge_material
    selection_outline.visible = false
    helpers.add_child(selection_outline)
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
    _clear_selection_highlight()
    var resume_clay := clay_enabled
    var resume_zebra := zebra_enabled
    if resume_zebra:
        _set_zebra(false)
    if resume_clay:
        _set_clay(false)
    # Switching preview modes may automatically restore the amber tint.
    # Clear it AFTER toggling inspectors, before serializing the actual GLB.
    _clear_selection_highlight()
    var document := GLTFDocument.new()
    var state := GLTFState.new()
    var problem := document.append_from_scene(asset_host, state)
    if problem != OK:
        if resume_zebra:
            _set_zebra(true)
        elif resume_clay:
            _set_clay(true)
        _refresh_selection_highlight()
        _notify("Export error: %s" % error_string(problem))
        return false
    var bytes := document.generate_buffer(state)
    if resume_zebra:
        _set_zebra(true)
    elif resume_clay:
        _set_clay(true)
    _refresh_selection_highlight()
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
    _set_zebra(false)
    _set_clay(false)
    _clear_selection_highlight()
    edit.set_target(null)
    editor_by_mesh.clear()
    undo_history.clear()
    redo_history.clear()
    dirty = false
    for child in asset_host.get_children():
        asset_host.remove_child(child)
        child.queue_free()
    mesh_nodes.clear()
    selected_mesh_index = -1
    filtered_mesh_indices.clear()
    mesh_picker.clear()
    if part_search != null:
        part_search.text = ""
    marker.visible = false
    wire_preview.mesh = null
    if gizmo_root != null:
        gizmo_root.visible = false
    gizmo_drag_active = false

func _highlight_toggled(enabled: bool) -> void:
    selection_highlight_enabled = enabled
    _refresh_selection_highlight()
    _notify("Selection highlight ON" if enabled else "Selection highlight OFF")

func _clear_selection_highlight() -> void:
    if selected_overlay_mesh != null and is_instance_valid(selected_overlay_mesh):
        selected_overlay_mesh.material_overlay = selected_original_overlay
    selected_overlay_mesh = null
    selected_original_overlay = null
    if selection_outline != null:
        selection_outline.visible = false
        selection_outline.mesh = null

func _part_world_bounds(parts: Array) -> AABB:
    var result := AABB()
    var first := true
    for instance in parts:
        if not is_instance_valid(instance) or instance.mesh == null:
            continue
        var box: AABB = instance.get_aabb()
        for x in [0.0, 1.0]:
            for y in [0.0, 1.0]:
                for z in [0.0, 1.0]:
                    var point: Vector3 = instance.to_global(box.position + box.size * Vector3(x, y, z))
                    if first:
                        result = AABB(point, Vector3.ZERO)
                        first = false
                    else:
                        result = result.expand(point)
    return result

func _is_whole_model_mode() -> bool:
    return move_target_picker != null and move_target_picker.selected == 2

func _refresh_selection_highlight() -> void:
    if not selection_highlight_enabled or edit.target == null or selection_outline == null:
        _clear_selection_highlight()
        return
    var whole_model := active_tab == 1 and _is_whole_model_mode()
    # VIEW uses clean imported textures; the amber bounding outline alone identifies the part.
    var intended: MeshInstance3D = null if whole_model or zebra_enabled or clay_enabled or active_tab == 3 else edit.target
    if selected_overlay_mesh != intended:
        if selected_overlay_mesh != null and is_instance_valid(selected_overlay_mesh):
            selected_overlay_mesh.material_overlay = selected_original_overlay
        selected_overlay_mesh = null
        selected_original_overlay = null
        if intended != null:
            selected_original_overlay = intended.material_overlay
            selected_overlay_mesh = intended
            intended.material_overlay = selection_overlay_material
    _update_selection_outline()

func _update_selection_outline() -> void:
    if selection_outline == null or not selection_highlight_enabled or edit.target == null:
        if selection_outline != null:
            selection_outline.visible = false
        return
    var targets: Array = mesh_nodes if active_tab == 1 and _is_whole_model_mode() else [edit.target]
    if targets.is_empty():
        selection_outline.visible = false
        return
    var bounds: AABB = _part_world_bounds(targets)
    var margin := maxf(0.012, bounds.size.length() * 0.008)
    bounds = bounds.grow(margin)
    var lo: Vector3 = bounds.position
    var hi: Vector3 = bounds.end
    var corners := [
        Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z),
        Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z),
        Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z),
        Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)
    ]
    var pairs := [
        0,1, 1,2, 2,3, 3,0, 4,5, 5,6, 6,7, 7,4,
        0,4, 1,5, 2,6, 3,7
    ]
    var lines := PackedVector3Array()
    for index in pairs:
        lines.append(corners[index])
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = lines
    var outline := ArrayMesh.new()
    outline.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
    selection_outline.mesh = outline
    selection_outline.global_transform = Transform3D.IDENTITY
    selection_outline.visible = true

func _index_meshes() -> void:
    mesh_nodes.clear()
    selected_mesh_index = -1
    _collect_mesh_nodes(asset_host)
    _refresh_part_picker()
    if not mesh_nodes.is_empty():
        _choose_mesh(0)
    else:
        vertex_label.text = "No editable triangle meshes"
        _clear_selection_highlight()

func _collect_mesh_nodes(node: Node) -> void:
    if node is MeshInstance3D and node.mesh != null:
        mesh_nodes.append(node)
    for child in node.get_children():
        _collect_mesh_nodes(child)

func _refresh_part_picker() -> void:
    if mesh_picker == null:
        return
    mesh_picker.clear()
    filtered_mesh_indices.clear()
    var query: String = part_search.text.strip_edges().to_lower() if part_search != null else ""
    for index in range(mesh_nodes.size()):
        var node: MeshInstance3D = mesh_nodes[index]
        if query.is_empty() or query in node.name.to_lower() or query in str(index + 1):
            filtered_mesh_indices.append(index)
            mesh_picker.add_item("%d / %d • %s" % [index + 1, mesh_nodes.size(), node.name])
    if filtered_mesh_indices.is_empty():
        mesh_picker.add_item("No matching parts")
        mesh_picker.set_item_disabled(0, true)
    else:
        var found: int = filtered_mesh_indices.find(selected_mesh_index)
        mesh_picker.select(found if found >= 0 else 0)

func _choose_filtered_mesh(visible_index: int) -> void:
    if visible_index >= 0 and visible_index < filtered_mesh_indices.size():
        _choose_mesh(filtered_mesh_indices[visible_index])

func _part_search_changed(_query: String) -> void:
    _refresh_part_picker()
    if filtered_mesh_indices.is_empty():
        _notify("No matching mesh part. Clear Find part to see them all.")
        return
    if not filtered_mesh_indices.has(selected_mesh_index):
        _choose_mesh(filtered_mesh_indices[0])

func _choose_mesh(index: int) -> void:
    if index < 0 or index >= mesh_nodes.size():
        return
    _clear_selection_highlight()
    var instance: MeshInstance3D = mesh_nodes[index]
    selected_mesh_index = index
    var shown_index: int = filtered_mesh_indices.find(index)
    if shown_index >= 0:
        mesh_picker.select(shown_index)
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
    _refresh_selection_highlight()
    _geometry_changed()
    _update_project_header()
    _update_dimensions_fields()
    _notify("SELECTED %d/%d: %s • %d vertices" % [index + 1, mesh_nodes.size(), instance.name, edit.vertex_count()])

func _cycle_part(direction: int) -> void:
    if mesh_nodes.is_empty():
        return
    if not filtered_mesh_indices.is_empty():
        var current: int = filtered_mesh_indices.find(selected_mesh_index)
        _choose_mesh(filtered_mesh_indices[posmod(current + direction, filtered_mesh_indices.size())])
    else:
        _choose_mesh(posmod(selected_mesh_index + direction, mesh_nodes.size()))

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
    if part_info_label != null:
        if active_tab == 1 and _is_whole_model_mode():
            part_info_label.text = "ALL %d PARTS" % mesh_nodes.size()
        elif edit.target != null:
            part_info_label.text = "%d/%d • %s" % [selected_mesh_index + 1, mesh_nodes.size(), edit.target.name]

func _selected_part() -> MeshInstance3D:
    return edit.target if edit != null else null

func _capture_model_roots() -> Array:
    # Imported GLB is normally one top-level scene root. This also handles
    # multiple top-level roots without flattening or damaging per-part hierarchy.
    var snapshots: Array = []
    for child in asset_host.get_children():
        if child is Node3D:
            snapshots.append({"node": child, "transform": child.transform})
    return snapshots

func _set_model_roots(snapshot: Array) -> void:
    for item in snapshot:
        var node: Node3D = item["node"]
        if is_instance_valid(node):
            node.transform = item["transform"]

func _apply_model_affine(snapshot: Array, affine: Transform3D) -> void:
    for item in snapshot:
        var node: Node3D = item["node"]
        if is_instance_valid(node):
            node.transform = affine * item["transform"]

func _commit_model_edit(before: Array) -> bool:
    var after: Array = _capture_model_roots()
    var changed := false
    for i in range(mini(before.size(), after.size())):
        var old_transform: Transform3D = before[i]["transform"]
        var new_transform: Transform3D = after[i]["transform"]
        if not old_transform.is_equal_approx(new_transform):
            changed = true
            break
    if changed:
        # Deep-copy the snapshot dictionaries. The drag gesture owns its
        # temporary array and must not erase undo history when it resets.
        _push_history({"kind": "model", "before": before.duplicate(true), "after": after.duplicate(true)})
        _mark_dirty()
    _geometry_changed()
    return changed

func _whole_model_affine(kind: String, parameter: Variant) -> void:
    if mesh_nodes.is_empty():
        _notify("Open a model first.")
        return
    var before: Array = _capture_model_roots()
    if before.is_empty():
        return
    var pivot_world: Vector3 = _part_world_bounds(mesh_nodes).get_center()
    var pivot: Vector3 = asset_host.to_local(pivot_world)
    var affine := Transform3D.IDENTITY
    if kind == "move":
        var delta_world: Vector3 = parameter
        affine.origin = asset_host.global_transform.basis.inverse() * delta_world
    elif kind == "rotate":
        var rotate := Transform3D(Basis(Vector3.UP, deg_to_rad(float(parameter))), Vector3.ZERO)
        affine = Transform3D(Basis.IDENTITY, pivot) * rotate * Transform3D(Basis.IDENTITY, -pivot)
    elif kind == "scale":
        var factor: float = float(parameter)
        var scaling := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * factor), Vector3.ZERO)
        affine = Transform3D(Basis.IDENTITY, pivot) * scaling * Transform3D(Basis.IDENTITY, -pivot)
    else:
        return
    _apply_model_affine(before, affine)
    if _commit_model_edit(before):
        _notify("WHOLE MODEL %s • %d parts moved as one assembly." % [kind, mesh_nodes.size()])

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
    if _is_whole_model_mode():
        _whole_model_affine("rotate", degrees)
        return
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
    if _is_whole_model_mode():
        _whole_model_affine("scale", factor)
        return
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
    if _is_whole_model_mode():
        _whole_model_affine("move", direction * float(step_box.value))
        return
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
    if operation["kind"] == "model":
        _set_model_roots(operation["before"])
    elif operation["kind"] == "create":
        _detach_part(operation["node"])
    elif operation["kind"] == "delete":
        _register_added_part(operation["node"], operation["parent"], false)
    else:
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
    _update_dimensions_fields()
    _mark_dirty()
    _notify("Undid last edit.")

func _do_redo() -> void:
    if redo_history.is_empty():
        _notify("Nothing to redo.")
        return
    var operation: Dictionary = redo_history.pop_back()
    undo_history.append(operation)
    if operation["kind"] == "model":
        _set_model_roots(operation["after"])
    elif operation["kind"] == "create":
        _register_added_part(operation["node"], operation["parent"], false)
    elif operation["kind"] == "delete":
        _detach_part(operation["node"])
    else:
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
    _update_dimensions_fields()
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
    _update_selection_outline()

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
    if _is_whole_model_mode():
        pivot = _part_world_bounds(mesh_nodes).get_center()
    elif move_target_picker != null and move_target_picker.selected == 0:
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
    gizmo_drag_model = _is_whole_model_mode()
    gizmo_drag_part = move_target_picker.selected == 1
    gizmo_model_before = _capture_model_roots() if gizmo_drag_model else []
    if gizmo_drag_model and gizmo_model_before.is_empty():
        return false
    if not gizmo_drag_part and not gizmo_drag_model and not edit.begin_stroke():
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
    var mode_label := "whole model" if gizmo_drag_model else ("part" if gizmo_drag_part else "point")
    _notify("Drag the %s handle to move %s." % [["X (red)", "Y (green)", "Z (blue)"][axis], mode_label])
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
    if gizmo_drag_model:
        var affine := Transform3D(Basis.IDENTITY, asset_host.global_transform.basis.inverse() * delta)
        _apply_model_affine(gizmo_model_before, affine)
        _geometry_changed()
    elif gizmo_drag_part:
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
    if gizmo_drag_model:
        _commit_model_edit(gizmo_model_before)
    elif gizmo_drag_part:
        var node: MeshInstance3D = edit.target
        if node != null and not node.transform.is_equal_approx(gizmo_start_transform):
            _push_history({"kind":"part", "node":node, "before":gizmo_start_transform, "after":node.transform})
            _mark_dirty()
    elif gizmo_drag_vertex_editor != null:
        gizmo_drag_vertex_editor.end_stroke()
    gizmo_drag_active = false
    gizmo_drag_model = false
    gizmo_model_before = []
    gizmo_drag_part = false
    gizmo_axis = -1
    gizmo_drag_vertex_editor = null
    _update_gizmo()

func _ray_triangle_hit(instance: MeshInstance3D, ray_origin: Vector3, ray_direction: Vector3) -> Dictionary:
    if instance == null or not instance.visible or instance.mesh == null:
        return {}
    var mesh: Mesh = instance.mesh
    var local_origin: Vector3 = instance.to_local(ray_origin)
    var local_direction: Vector3 = instance.global_transform.basis.inverse() * ray_direction
    if local_direction.length_squared() < 0.000000001:
        return {}
    if instance.get_aabb().grow(0.02).intersects_ray(local_origin, local_direction) == null:
        return {}
    var closest := INF
    var nearest: Dictionary = {}
    for surface_index in range(mesh.get_surface_count()):
        if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
            continue
        var data: Array = mesh.surface_get_arrays(surface_index)
        if data.size() <= Mesh.ARRAY_VERTEX or data[Mesh.ARRAY_VERTEX] == null:
            continue
        var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
        var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX] if data[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
        var count: int = (indices.size() if not indices.is_empty() else vertices.size()) / 3
        for triangle in range(count):
            var t: int = triangle * 3
            var ia: int = indices[t] if not indices.is_empty() else t
            var ib: int = indices[t + 1] if not indices.is_empty() else t + 1
            var ic: int = indices[t + 2] if not indices.is_empty() else t + 2
            if ia < 0 or ib < 0 or ic < 0 or ia >= vertices.size() or ib >= vertices.size() or ic >= vertices.size():
                continue
            var intersection: Variant = Geometry3D.ray_intersects_triangle(
                local_origin, local_direction, vertices[ia], vertices[ib], vertices[ic]
            )
            if intersection is Vector3:
                var world_point: Vector3 = instance.to_global(intersection)
                var depth: float = (world_point - ray_origin).dot(ray_direction)
                if depth > camera.near * 0.5 and depth < closest:
                    closest = depth
                    nearest = {
                        "node": instance, "surface": surface_index, "triangle": PackedInt32Array([ia, ib, ic]),
                        "depth": depth, "world": world_point
                    }
    return nearest

func _ray_triangle_depth(instance: MeshInstance3D, ray_origin: Vector3, ray_direction: Vector3) -> float:
    var detail: Dictionary = _ray_triangle_hit(instance, ray_origin, ray_direction)
    return float(detail["depth"]) if not detail.is_empty() else INF

func _frontmost_triangle_at(position: Vector2) -> Dictionary:
    if mesh_nodes.is_empty():
        return {}
    var screen: Vector2 = _canvas_to_viewport(position)
    var ray_origin: Vector3 = camera.project_ray_origin(screen)
    var ray_direction: Vector3 = camera.project_ray_normal(screen)
    var candidates: Array = []
    for part in mesh_nodes:
        if not is_instance_valid(part) or not part.visible or part.mesh == null:
            continue
        var local_origin: Vector3 = part.to_local(ray_origin)
        var local_direction: Vector3 = part.global_transform.basis.inverse() * ray_direction
        if local_direction.length_squared() < 0.000000001:
            continue
        var entry: Variant = part.get_aabb().grow(0.02).intersects_ray(local_origin, local_direction)
        if entry is Vector3:
            var entry_depth: float = (part.to_global(entry) - ray_origin).dot(ray_direction)
            candidates.append({"part":part, "entry":maxf(entry_depth, 0.0)})
    candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return float(left["entry"]) < float(right["entry"]))
    var closest := INF
    var best: Dictionary = {}
    for candidate in candidates:
        if float(candidate["entry"]) > closest + 0.02:
            break
        var hit: Dictionary = _ray_triangle_hit(candidate["part"], ray_origin, ray_direction)
        if not hit.is_empty() and float(hit["depth"]) < closest:
            closest = float(hit["depth"])
            best = hit
    return best

func _pick_part(position: Vector2) -> bool:
    var hit: Dictionary = _frontmost_triangle_at(position)
    if hit.is_empty():
        return false
    if active_tab == 1 and _is_whole_model_mode():
        _notify("WHOLE MODEL active. Switch to WHOLE PART for component selection.")
        return true
    var part: MeshInstance3D = hit["node"]
    var index: int = mesh_nodes.find(part)
    if index < 0:
        return false
    _choose_mesh(index)
    return true

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
            _pick_vertex(pointer_origin)
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
    # Only choose among the three real vertices of the FRONTMOST face under
    # the finger. Projecting all mesh vertices previously picked hidden
    # interior or far-side points through the exterior shell.
    var hit: Dictionary = _frontmost_triangle_at(position)
    if hit.is_empty():
        return false
    var part: MeshInstance3D = hit["node"]
    if part != edit.target:
        var index: int = mesh_nodes.find(part)
        if index < 0:
            return false
        _choose_mesh(index)
    if edit.target != part:
        return false
    var surface: int = int(hit["surface"])
    if surface < 0 or surface >= edit.surfaces.size():
        return false
    var face: PackedInt32Array = hit["triangle"]
    var positions: PackedVector3Array = edit.surfaces[surface]["arrays"][Mesh.ARRAY_VERTEX]
    var mapped: Vector2 = _canvas_to_viewport(position)
    var nearest := INF
    var point_index := -1
    for vertex_index in face:
        if vertex_index < 0 or vertex_index >= positions.size():
            continue
        var point_world: Vector3 = part.to_global(positions[vertex_index])
        var point_screen: Vector2 = camera.unproject_position(point_world)
        var dist: float = point_screen.distance_squared_to(mapped)
        if dist < nearest:
            nearest = dist
            point_index = vertex_index
    if point_index < 0:
        return false
    return edit.select_vertex(surface, point_index)

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
