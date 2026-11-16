extends SceneTree
## v0.8.1: studio clay must reveal normals without masking with amber paint
## or changing model material/geometry on export.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene = load("res://main.tscn")
    if scene == null:
        _fail("Editor scene unavailable")
        return
    var app = scene.instantiate()
    root.add_child(app)
    await process_frame
    await process_frame
    if app.mesh_nodes.size() < 2:
        _fail("Demo contains fewer than two parts")
        return
    app._choose_mesh(0)
    var a: MeshInstance3D = app.edit.target
    var b: MeshInstance3D = app.mesh_nodes[1]
    var old_a: Material = a.material_override
    var old_b: Material = b.material_override
    var old_overlay: Material = a.material_overlay
    if old_overlay != app.selection_overlay_material:
        _fail("Selected part is not highlighted before Clay")
        return
    app._show_tab(3)
    app._set_clay(true)
    if not app.clay_enabled or app.clay_material == null:
        _fail("Studio Clay did not activate")
        return
    if not app.clay_material is ShaderMaterial:
        _fail("Clay is still using the flat standard material")
        return
    if a.material_override != app.clay_material or b.material_override != app.clay_material:
        _fail("Clay material is not active on all mesh parts")
        return
    if a.material_overlay != null or app.selected_overlay_mesh != null:
        _fail("Old amber selection tint is still washing over Clay")
        return
    if not app.selection_outline.visible:
        _fail("Outline vanished in clay inspection mode")
        return
    var shader: Shader = app.clay_material.shader
    if shader == null or not shader.code.contains("dFdx") or not shader.code.contains("light_azimuth"):
        _fail("Normal-derivative studio inspection shader not attached")
        return
    if absf(float(app.clay_material.get_shader_parameter("facet_strength")) - 0.85) > 0.01:
        _fail("Default faceted inspection did not use geometry normals")
        return
    var old_angle: float = app.clay_light_angle
    app._sweep_clay_light(0.35)
    if app.clay_light_angle <= old_angle + 0.2:
        _fail("LIGHT sweep did not change direction")
        return
    if absf(float(app.clay_material.get_shader_parameter("light_azimuth")) - app.clay_light_angle) > 0.001:
        _fail("Light angle was not applied to the shader")
        return
    app._clay_facets_changed(false)
    if absf(float(app.clay_material.get_shader_parameter("facet_strength")) - 0.05) > 0.01:
        _fail("Smooth normals toggle did not affect shader")
        return
    app._clay_facets_changed(true)

    # Export in inspection mode. Shader must be removed before glTF generation
    # and restored immediately afterwards; the original GLB must remain clean.
    var output := "user://model-forge-studio-clay-clean.glb"
    if not app._save_glb(output, false):
        _fail("Could not export while in Studio Clay")
        return
    if not app.clay_enabled or a.material_override != app.clay_material:
        _fail("Export did not restore Studio Clay appearance")
        return
    if a.material_overlay != null:
        _fail("Export restored amber paint on top of the clay")
        return
    var glb: PackedByteArray = FileAccess.get_file_as_bytes(output)
    var document := GLTFDocument.new()
    var state := GLTFState.new()
    if glb.size() < 12 or document.append_from_buffer(glb, "", state) != OK:
        _fail("Studio Clay exported invalid GLB")
        return
    var imported: Node = document.generate_scene(state)
    if imported == null:
        _fail("Studio Clay exported an empty model")
        return
    if _has_preview_material(imported):
        _fail("Preview shader or amber tint was exported")
        return
    imported.free()

    # Regular appearance must return exactly, including user's original
    # overlay, without changing any mesh or part transforms.
    app._set_clay(false)
    if app.clay_enabled or a.material_override != old_a or b.material_override != old_b:
        _fail("Disabling Clay did not restore original part materials")
        return
    if a.material_overlay != null or not app.selection_outline.visible:
        _fail("VIEW should preserve the outline without tinting the textured model")
        return
    app._show_tab(0)
    if a.material_overlay != old_overlay:
        _fail("Shape tab did not restore its editable-part indicator")
        return
    app._show_tab(3)
    app._set_clay(true)
    app._set_zebra(true)
    if app.clay_enabled or not app.zebra_enabled:
        _fail("Zebra and Studio Clay are both enabled")
        return
    app._set_zebra(false)
    if a.material_override != old_a:
        _fail("Inspection modes did not restore original part material")
        return
    app.queue_free()
    print("MODEL_FORGE_STUDIO: PASS geometric-normal shader, facets, moving light, outline-only selection, clean GLB, material restoration")
    quit(0)

func _has_preview_material(root_node: Node) -> bool:
    if root_node is MeshInstance3D:
        var mesh_node: MeshInstance3D = root_node
        if mesh_node.material_override is ShaderMaterial or mesh_node.material_overlay is ShaderMaterial:
            return true
        if mesh_node.material_overlay != null:
            return true
    for child in root_node.get_children():
        if _has_preview_material(child):
            return true
    return false

func _fail(message: String) -> void:
    push_error("MODEL_FORGE_STUDIO: FAIL " + message)
    quit(1)
