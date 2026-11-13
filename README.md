# Model Forge

**Model Forge** is a free, MIT-licensed, touchscreen-first GLB geometry editor for Android. Our goal is to correct real vehicle mesh geometry on a phone, not merely view or paint models.

## Current status

**v0.1 experimental:** Source code and automated Android APK pipeline are implemented. This is early software, and physical phone testing is still required. Builds that pass CI publish a downloadable debug APK.

### Implemented in source
- Native Android file picker to import and export binary GLB files (Android 10+)
- 3D preview with drag-to-orbit, pinch/scroll zoom and frame-model control
- Mesh and vertex selection (tap near a vertex or cycle with buttons)
- Drag editing on the view plane or locked X/Y/Z axis
- Precision X/Y/Z movement steps, mirroring around local X=0, seam-aware movement
- Per-mesh undo/redo (20 steps), normal recalculation, wireframe and vertex marker
- Reference-image window supporting PNG, JPG and WebP
- Starter hovercraft hull and multiple selectable parts
- Headless smoke test for vertex movement, undo/redo and GLB export/reimport

### Download test builds

Go to [Model Forge Android Builds](https://github.com/tpylman90-ctrl/Model-forge/actions/workflows/android.yml), open the newest **successful** workflow run and download the **ModelForge-Android-APK** artifact. Extract the archive and install **ModelForge-debug.apk**.

The debug signing key is generated per build. Uninstall an old development APK before installing a new one if Android reports a signing-key mismatch.

### Build locally

Use Godot Engine **4.5.2 stable**. Open the root project.godot and run main.tscn. The CI workflow uses the free godot-ci Docker image and uploads an ARM64 Android debug APK.

The source is licensed under MIT. Godot Engine is independently available under MIT.

### Important limitations

This prototype moves existing mesh vertices but cannot yet extrude faces, insert edge loops, or retopologize. GLB round trips through Godot may not preserve all imported metadata, animations, skins, morph targets, extensions, custom shaders, material appearance, or LODs. Save a copy of every original asset before editing. Source code has not yet been verified on a physical Android device.

High-density GLBs may lag because selection checks projected vertices and movement rebuilds surfaces. Welded seam coordinates within the same mesh are moved together; different MeshInstance3D nodes are not welded. Mirroring assumes the mesh origin is the symmetry plane. Recalculating normals can soften hard edges.

### Roadmap

1. Confirm Android build, install, GLB import and export on a real phone.
2. Accelerate mesh picking and edits with a spatial index and GPU picking.
3. Add proportional editing, soft selection, and curves/control cages.
4. Introduce topology tools: cut, edge loop, bevel, face extrusion, panel separation.
5. Add structured markup export and direct AssetWright feedback integration.

## Contributing

PRs and bug reports are welcome. Keep dependencies free and legally redistributable. Include a license for any asset you add.
