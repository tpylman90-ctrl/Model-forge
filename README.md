# Model Forge

**Model Forge** is a free and open-source touchscreen GLB mesh editor for Android, built with Godot 4.5.2. Its main purpose is to let users correct a generated vehicle's real 3D shape without needing a desktop.

## Current milestone: v0.2 touch-first editor

The editor has four large, clearly labeled tool tabs with the model viewport taking most of the screen.

| Tab | What it does |
| --- | --- |
| **SHAPE** | Choose a mesh, tap or cycle through vertices, drag to reshape, switch on soft-selection falloff and optional mirrored editing, or tap **SMOOTH** to relax uneven geometry |
| **MOVE** | Move the selected vertex in exact positive/negative X, Y, and Z steps; set the movement distance or lock touch-drag to an axis |
| **VIEW** | Fit the model, jump to Front/Side/Top/3/4 cameras, show wireframe, orbit without editing, or rebuild normals |
| **MORE** | Load or show/hide a floating reference photo, open a sample hovercraft, or see the quick-start help |

A simple top bar keeps **OPEN GLB**, **SAVE GLB**, **UNDO**, **REDO**, and **HELP** visible.

### What works in source and automated tests
- Android-native file selection for binary GLB imports and exports
- Three-dimensional orbit, two-finger pan/zoom, camera presets, model framing
- Per-mesh vertex picking, numerical movement, drag editing and X-axis mirroring
- **New:** adjustable-radius soft brush (smooth falloff of nearby mesh vertices)
- **New:** undoable one-click localized vertex smoothing
- Reference-photo overlay supporting PNG, JPG, WebP
- Editable demo hovercraft mesh
- Test suite: vertex edit/undo/redo/GLB binary export/reimport, soft falloff, mirror, smoothing and layout regression checks
- GitHub Actions build with automatic ARM64 Android APK artifacts

### Install a test APK

Visit [Model Forge Android Builds](https://github.com/tpylman90-ctrl/Model-forge/actions/workflows/android.yml). Open the newest **successful** workflow run; download **ModelForge-Android-APK** from its Artifacts section, unzip, and install the APK on your phone.

The debug key is generated per run. If Android reports a signature mismatch when installing a newer build, uninstall the old experimental build first.

### Quick-start

1. Open **MORE → DEMO MODEL** to practice, or **OPEN GLB** to select your own file.
2. In **SHAPE**, tap a point and drag it. Toggle **SOFT** to affect neighboring points; use the **Radius** slider to control the falloff.
3. Toggle **MIRROR** if the mesh is centered on the X axis and you want symmetrical edits.
4. In **MOVE**, use X/Y/Z +/- buttons for precise changes.
5. In **VIEW**, switch to a front, side, top or 3/4 view. Choose **CAMERA ONLY** to orbit without accidentally dragging vertices.
6. Use **UNDO** for unwanted mesh edits. **SAVE GLB** and choose a new file name. Reopen the exported model to confirm changes.

### Known limitations

This is a **v0.2 experimental build**, not a full Blender alternative. It is primarily a vertex-coordinate editor; it cannot yet add/cut faces, extrude, bevel, insert edge loops or retopologize. Multi-mesh undo is not global: selecting another mesh resets the current mesh's undo history. On complex GLBs, Godot's glTF importer/exporter may not faithfully round-trip nonstandard extensions, shader and material setups, rigging, animations, metadata, morph targets and other auxiliary data. Keep **backup copies** of the original GLB. Physical Android touch ergonomics and full-file SAF workflows still need device testing.

A soft brush uses a **local-space radius** on the selected mesh. Smoothing uses a local triangle-neighbor average and can blunt sharp edges; use it gently and undo if unsuitable. With **MIRROR**, symmetry is measured from the selected mesh's local X=0 plane. Normals are not automatically rebuilt during deformations; VIEW → REBUILD NORMALS is a separate shading operation and not part of vertex undo history. Large meshes can lag during vertex picking, soft edits and mesh rebuilds.

### Free development

Godot Engine and Model Forge code use the MIT license; dependencies and contributions must be legally redistributable. The free GitHub Actions workflow provides headless tests and the Android debug APK export.

### Roadmap

1. Verify opening/editing/exporting our vehicle GLBs on a physical Android phone.
2. Add improved occlusion-aware picking, editable mesh history across objects and customizable touch target sizing.
3. Add selectable control cages, proportional editing handles and crease-aware edge smoothing.
4. Implement topology editing tools and UV/material inspection.
5. Add AssetWright-compatible geometry feedback and side-by-side GLB comparison.

Feedback and pull requests are welcome.
