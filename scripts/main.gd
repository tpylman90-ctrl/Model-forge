extends Control
## Model Forge v0.1: touchscreen GLB geometry editor.
const MeshEdit = preload("res://scripts/mesh_editor.gd")
const DARK := Color("#101924")
const PANEL := Color("#162231")
const ACCENT := Color("#3ddbc1")
const MUTED := Color("#9aafc2")

var edit = MeshEdit.new()
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
var wire_toggle: CheckButton
var reference_preview: TextureRect
var open_dialog: FileDialog
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

func _ready() -> void:
    get_viewport().gui_release_focus()
    _create_ui()
    _create_scene()
    _create_file_dialogs()
    edit.geometry_changed.connect(_geometry_changed)
    _create_demo()
    _notify("Ready. Select a body vertex and drag it, or use the axis buttons.")

func _create_ui() -> void:
    var whole := VBoxContainer.new()
    whole.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    whole.add_theme_constant_override("separation", 0)
    add_child(whole)

    var header := PanelContainer.new()
    _panel_style(header, DARK)
    header.custom_minimum_size.y = 63
    whole.add_child(header)
    var toolbar := HBoxContainer.new()
    toolbar.add_theme_constant_override("separation", 8)
    header.add_child(toolbar)
    _spaced(toolbar, 9)
    var brand := Label.new()
    brand.text = "MODEL FORGE"
    brand.add_theme_color_override("font_color", ACCENT)
    brand.add_theme_font_size_override("font_size", 22)
    toolbar.add_child(brand)
    _spaced(toolbar, 7)
    _button(toolbar, "OPEN GLB", func(): open_dialog.popup_centered_ratio(0.85))
    _button(toolbar, "SAVE GLB", func(): save_dialog.popup_centered_ratio(0.85))
    _button(toolbar, "DEMO", _create_demo)
    _button(toolbar, "UNDO", _do_undo)
    _button(toolbar, "REDO", _do_redo)
    _button(toolbar, "FRAME", _frame_model)

    var workspace := HBoxContainer.new()
    workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
    workspace.add_theme_constant_override("separation", 0)
    whole.add_child(workspace)

    var left := _sidebar(workspace, 234)
    _label(left, "SCENE / GEOMETRY", 16, ACCENT)
    _label(left, "Active mesh", 13, MUTED)
    mesh_picker = OptionButton.new()
    mesh_picker.custom_minimum_size.y = 42
    mesh_picker.item_selected.connect(_choose_mesh)
    left.add_child(mesh_picker)
    _button(left, "PREVIOUS VERTEX", func(): _cycle_vertex(-1))
    _button(left, "NEXT VERTEX", func(): _cycle_vertex(1))
    vertex_label = _label(left, "Vertex: none", 13, Color.WHITE)
    vertex_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var rule := HSeparator.new()
    left.add_child(rule)
    edit_toggle = CheckButton.new()
    edit_toggle.text = "Vertex edit"
    edit_toggle.button_pressed = true
    left.add_child(edit_toggle)
    var mirror := CheckButton.new()
    mirror.text = "Mirror across X"
    mirror.toggled.connect(func(value: bool): edit.mirror_enabled = value)
    left.add_child(mirror)
    wire_toggle = CheckButton.new()
    wire_toggle.text = "Wire overlay"
    wire_toggle.button_pressed = false
    wire_toggle.toggled.connect(func(value: bool): wire_preview.visible = value if wire_preview != null else false)
    left.add_child(wire_toggle)
    _button(left, "RECALCULATE NORMALS", func():
        edit.recalculate_normals()
        _notify("Normals updated. Undo available.")
    )
    _label(left, "Tap near a visible mesh vertex. Drag it to reshape the surface. Two fingers zoom.", 12, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    canvas = SubViewportContainer.new()
    canvas.stretch = true
    canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
    canvas.mouse_filter = Control.MOUSE_FILTER_STOP
    canvas.gui_input.connect(_canvas_input)
    workspace.add_child(canvas)

    var right := _sidebar(workspace, 250)
    _label(right, "PRECISION EDIT", 16, ACCENT)
    _label(right, "Step distance", 13, MUTED)
    step_box = SpinBox.new()
    step_box.min_value = 0.001
    step_box.max_value = 20.0
    step_box.step = 0.01
    step_box.value = 0.10
    right.add_child(step_box)
    _label(right, "Axis drag lock", 13, MUTED)
    axis_picker = OptionButton.new()
    for item in ["VIEW PLANE", "X AXIS", "Y AXIS", "Z AXIS"]:
        axis_picker.add_item(item)
    right.add_child(axis_picker)
    var row_x := HBoxContainer.new()
    right.add_child(row_x)
    _button(row_x, "X −", func(): _nudge(Vector3.LEFT))
    _button(row_x, "X +", func(): _nudge(Vector3.RIGHT))
    var row_y := HBoxContainer.new()
    right.add_child(row_y)
    _button(row_y, "Y −", func(): _nudge(Vector3.DOWN))
    _button(row_y, "Y +", func(): _nudge(Vector3.UP))
    var row_z := HBoxContainer.new()
    right.add_child(row_z)
    _button(row_z, "Z −", func(): _nudge(Vector3(0, 0, -1)))
    _button(row_z, "Z +", func(): _nudge(Vector3(0, 0, 1)))
    _label(right, "IMAGE REFERENCE", 16, ACCENT)
    _button(right, "LOAD IMAGE", func(): image_dialog.popup_centered_ratio(0.85))
    reference_preview = TextureRect.new()
    reference_preview.custom_minimum_size = Vector2(220, 145)
    reference_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    reference_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    right.add_child(reference_preview)
    _label(right, "Original files remain unchanged until you explicitly export.", 12, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    var footer := PanelContainer.new()
    footer.custom_minimum_size.y = 40
    _panel_style(footer, DARK)
    whole.add_child(footer)
    status_label = Label.new()
    status_label.text = "Model Forge — initialized"
    status_label.add_theme_color_override("font_color", MUTED)
    footer.add_child(status_label)

func _sidebar(parent: Node, width_px: float) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.custom_minimum_size.x = width_px
    panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _panel_style(panel, PANEL)
    parent.add_child(panel)
    var scrolling := ScrollContainer.new()
    scrolling.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.add_child(scrolling)
    var stack := VBoxContainer.new()
    stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stack.add_theme_constant_override("separation", 8)
    scrolling.add_child(stack)
    return stack

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
    button.custom_minimum_size.y = 41
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
    wiremat.wireframe = true
    wiremat.no_depth_test = true
    wire_preview.material_override = wiremat
    wire_preview.visible = false
    helpers.add_child(wire_preview)
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
    var grid_node := MeshInstance3D.new()
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

func _load_glb(path: String) -> void:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        _notify("Cannot read model: %s" % error_string(FileAccess.get_open_error()))
        return
    var bytes := file.get_buffer(file.get_length())
    file.close()
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
    _clear_asset()
    asset_host.add_child(result)
    _index_meshes()
    _frame_model()
    _notify("Loaded %s — %d meshes" % [path.get_file(), mesh_nodes.size()])

func _save_glb(path: String) -> void:
    if asset_host.get_child_count() == 0:
        _notify("Nothing to export.")
        return
    var document := GLTFDocument.new()
    var state := GLTFState.new()
    var problem := document.append_from_scene(asset_host, state)
    if problem != OK:
        _notify("Export error: %s" % error_string(problem))
        return
    var bytes := document.generate_buffer(state)
    if bytes.is_empty():
        _notify("Export failed: generated GLB is empty.")
        return
    var out := FileAccess.open(path, FileAccess.WRITE)
    if out == null:
        _notify("Cannot write GLB: %s" % error_string(FileAccess.get_open_error()))
        return
    out.store_buffer(bytes)
    out.close()
    _notify("Exported %s (%d KiB)" % [path.get_file(), int(bytes.size() / 1024)])

func _load_reference(path: String) -> void:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        _notify("Cannot open reference image.")
        return
    var data := file.get_buffer(file.get_length())
    file.close()
    var picture := Image.new()
    var extension := path.get_extension().to_lower()
    var problem := ERR_FILE_UNRECOGNIZED
    if extension == "png":
        problem = picture.load_png_from_buffer(data)
    elif extension == "jpg" or extension == "jpeg":
        problem = picture.load_jpg_from_buffer(data)
    elif extension == "webp":
        problem = picture.load_webp_from_buffer(data)
    if problem != OK:
        _notify("Unsupported reference image.")
        return
    reference_preview.texture = ImageTexture.create_from_image(picture)
    _notify("Reference image loaded.")

func _clear_asset() -> void:
    edit.set_target(null)
    for child in asset_host.get_children():
        asset_host.remove_child(child)
        child.queue_free()
    mesh_nodes.clear()
    mesh_picker.clear()
    marker.visible = false
    wire_preview.mesh = null

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
    mesh_picker.select(index)
    if edit.set_target(mesh_nodes[index]):
        if edit.vertex_count() > 0:
            edit.select_vertex(0, 0)
    _geometry_changed()
    _notify("Editing %s — %d mesh vertices" % [mesh_nodes[index].name, edit.vertex_count()])

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
    if not edit.has_selection():
        _notify("Select a vertex first.")
        return
    edit.move_step(direction * float(step_box.value))
    _update_marker()

func _do_undo() -> void:
    if not edit.can_undo():
        _notify("No changes to undo on this mesh.")
        return
    edit.undo()
    _update_marker()
    _notify("Undo applied.")

func _do_redo() -> void:
    if not edit.can_redo():
        _notify("No changes to redo on this mesh.")
        return
    edit.redo()
    _update_marker()
    _notify("Redo applied.")

func _geometry_changed() -> void:
    if edit.target != null:
        wire_preview.mesh = edit.target.mesh
        wire_preview.global_transform = edit.target.global_transform
    _update_marker()

func _update_marker() -> void:
    marker.visible = edit.has_selection()
    if not edit.has_selection():
        vertex_label.text = "Vertex: none"
        return
    var point := edit.vertex_position()
    marker.global_position = edit.target.to_global(point)
    marker.scale = Vector3.ONE * maxf(0.035, orbit_distance * 0.011)
    vertex_label.text = "Surface %d / vertex %d\nLocal position:\nX %.3f   Y %.3f   Z %.3f" % [
        edit.selected_surface, edit.selected_vertex, point.x, point.y, point.z]

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

func _canvas_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            orbit_distance *= 0.88
            _update_camera()
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            orbit_distance *= 1.12
            _update_camera()
        elif event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _pointer_start(event.position)
            else:
                _pointer_end()
    elif event is InputEventMouseMotion and pointer_down:
        _pointer_move(event.position)
    elif event is InputEventScreenTouch:
        if event.pressed:
            touch_positions[event.index] = event.position
            if touch_positions.size() == 1:
                _pointer_start(event.position)
            else:
                _pointer_end()
                last_pinch_distance = _touch_span()
        else:
            touch_positions.erase(event.index)
            if touch_positions.is_empty():
                _pointer_end()
            else:
                last_pinch_distance = 0.0
    elif event is InputEventScreenDrag:
        touch_positions[event.index] = event.position
        if touch_positions.size() >= 2:
            var span := _touch_span()
            if last_pinch_distance > 1.0 and span > 1.0:
                orbit_distance *= last_pinch_distance / span
                _update_camera()
            last_pinch_distance = span
        elif pointer_down:
            _pointer_move(event.position)

func _touch_span() -> float:
    var points := touch_positions.values()
    if points.size() < 2:
        return 0.0
    return points[0].distance_to(points[1])

func _pointer_start(position: Vector2) -> void:
    pointer_down = true
    pointer_dragging_vertex = false
    pointer_origin = position
    pointer_last = position
    stroke_moved = false
    if edit_toggle.button_pressed and _pick_vertex(position):
        pointer_dragging_vertex = edit.begin_stroke()
        _update_marker()

func _pointer_move(position: Vector2) -> void:
    if not pointer_down:
        return
    var displacement := position - pointer_last
    pointer_last = position
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
    if pointer_dragging_vertex:
        # The final position is committed even if drag throttling skipped a frame.
        if stroke_moved:
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
    _clear_asset()
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
    _notify("Demo loaded. Try X+ on a hull vertex, then SAVE GLB.")

func _notify(message: String) -> void:
    if status_label != null:
        status_label.text = message
    print("MODEL_FORGE: ", message)
