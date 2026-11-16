extends SceneTree
## v0.9.1: preserve authentic materials while providing PBR studio reflection,
## filmic lighting, light sweeps, real AA and sensible vehicle framing.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene = load("res://main.tscn")
    if scene == null:
        _fail("Cannot load editor scene")
        return
    var app = scene.instantiate()
    root.add_child(app)
    await process_frame
    await process_frame
    if app.scene_environment == null or app.studio_sky == null:
        _fail("Studio sky resource not attached")
        return
    var env: Environment = app.scene_environment
    if not app.studio_enabled or env.reflected_light_source != Environment.REFLECTION_SOURCE_SKY:
        _fail("PBR sky reflections not enabled by default")
        return
    if env.background_mode != Environment.BG_COLOR:
        _fail("Bright HDR panorama should not replace the dark viewport backdrop")
        return
    if env.sky != app.studio_sky:
        _fail("Studio sky not supplied to Environment resource")
        return
    var sky: Sky = app.studio_sky
    if sky.sky_material == null or not sky.sky_material is PanoramaSkyMaterial:
        _fail("Studio environment does not use a real HDR panorama")
        return
    var panorama: Texture2D = (sky.sky_material as PanoramaSkyMaterial).panorama
    if panorama == null:
        _fail("Studio panorama missing")
        return
    var source: Image = panorama.get_image()
    if source.get_width() < 192 or source.get_height() < 96 or source.get_format() != Image.FORMAT_RGBAF:
        _fail("Studio environment is not floating-point HDR")
        return
    var brightest := 0.0
    var darkest := INF
    for y in range(0, source.get_height(), 9):
        for x in range(0, source.get_width(), 9):
            var c: Color = source.get_pixel(x,y)
            brightest = maxf(brightest, c.r)
            darkest = minf(darkest, c.r)
    if brightest < 1.2 or darkest > 0.3:
        _fail("HDR softbox reflection strips lack real luminance range")
        return
    if env.tonemap_mode != Environment.TONE_MAPPER_FILMIC:
        _fail("Filmic highlight preservation not enabled")
        return
    if not env.adjustment_enabled or env.adjustment_contrast <= 1.02:
        _fail("Editor studio contrast not enabled")
        return
    if app.scene_view.msaa_3d != Viewport.MSAA_2X:
        _fail("Mobile default AA is not 2x")
        return
    app._set_high_quality(true)
    if app.scene_view.msaa_3d != Viewport.MSAA_4X:
        _fail("4x touch AA control failed")
        return
    app._set_high_quality(false)
    if app.scene_view.msaa_3d != Viewport.MSAA_2X:
        _fail("2x AA restoration failed")
        return
    if app.grid_node == null or app.grid_node.visible:
        _fail("Studio preview should hide distracting grid by default")
        return
    app._set_grid(true)
    if not app.grid_node.visible:
        _fail("Grid toggle cannot show alignment grid")
        return
    app._set_grid(false)
    if app.grid_node.visible:
        _fail("Grid toggle cannot hide alignment grid")
        return
    if app.studio_key == null or not app.studio_key.shadow_enabled:
        _fail("Model studio key doesn't cast real mesh shadows")
        return
    var first: MeshInstance3D = app.mesh_nodes[0]
    var original_mat: Material = first.material_override
    var original_mesh: Mesh = first.mesh
    app._show_tab(3)
    if first.material_override != original_mat or first.material_overlay != null:
        _fail("Studio view contaminates source model materials")
        return
    var angle: float = app.studio_key.rotation_degrees.y
    app._sweep_clay_light(0.35)
    if absf(app.studio_key.rotation_degrees.y - angle) < 15.0:
        _fail("View light controls do not sweep textured highlights")
        return
    app._set_studio(false)
    if env.reflected_light_source != Environment.REFLECTION_SOURCE_DISABLED:
        _fail("Basic fallback should disable heavier sky reflections")
        return
    if first.mesh != original_mesh or first.material_override != original_mat:
        _fail("Switching view lighting modified model content")
        return
    app._set_studio(true)
    if env.reflected_light_source != Environment.REFLECTION_SOURCE_SKY:
        _fail("Re-enabling studio doesn't restore sky reflection source")
        return

    # Long low vehicle should fill more viewport than the prior
    # diagonal*1.15 heuristic; no part geometry or hierarchy is changed.
    app._clear_asset()
    var assembly := Node3D.new()
    app.asset_host.add_child(assembly)
    var car := MeshInstance3D.new()
    car.name = "Long_Hover_Body"
    var body := BoxMesh.new()
    body.size = Vector3(3.0,1.0,12.0)
    car.mesh = body
    assembly.add_child(car)
    app._index_meshes()
    app.orbit_yaw = 0.0
    app.orbit_pitch = 0.0
    app._frame_model()
    var old_formula: float = car.get_aabb().size.length() * 1.15
    if app.orbit_distance >= old_formula * 0.83:
        _fail("Camera is still framing narrow vehicles too far away")
        return
    if app.camera.global_position.distance_to(app.orbit_center) < 1.0:
        _fail("Tight auto-fit clipped through a model")
        return

    var path := "user://model-forge-studio-viewport-test.glb"
    if not app._save_glb(path, false):
        _fail("Could not export from Studio viewport")
        return
    var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
    var doc := GLTFDocument.new()
    var gltf := GLTFState.new()
    if bytes.size() < 12 or doc.append_from_buffer(bytes, "", gltf) != OK:
        _fail("Studio viewing contaminated exported GLB bytes")
        return
    var loaded: Node = doc.generate_scene(gltf)
    if loaded == null:
        _fail("Export GLB cannot be loaded")
        return
    loaded.free()
    print("MODEL_FORGE_STUDIO_VIEW: PASS HDR softbox panorama, filmic, shadows, mobile AA, grid, movable light, close framing, clean GLB")
    app.queue_free()
    quit(0)

func _fail(message: String) -> void:
    push_error("MODEL_FORGE_STUDIO_VIEW: FAIL " + message)
    quit(1)
