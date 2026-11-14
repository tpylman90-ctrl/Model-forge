# Model Forge

**Model Forge** is a free, MIT-licensed, native Android GLB geometry editor designed to make real 3D edits practical on a phone. It serves Neon Forge Racing vehicle work, but there are no vehicle-specific formats or paid dependencies.

## Version 0.5 — direct-touch geometry editing and surface shaping

The phone-first interface provides four context-sensitive pages. The model stays visible while editing; touch targets are deliberately large. The 3D view fills wide and narrow Android displays without fixed-aspect black bars.

| Page | Your task | Primary tools |
| --- | --- | --- |
| **SHAPE** | Refine body curvature | Select a part or vertex; arm EDIT POINTS deliberately; choose ROUND BRUSH, BODY SECTION, or KEEP HARD EDGES with adjustable radius, MIRROR X and SMOOTH |
| **MOVE** | Assemble independently engineered components | Drag large colored **3D gizmo handles on the model**: red X, green Y, blue Z. Tap a component to select it; switch between WHOLE PART and SELECTED POINT, or use precision XYZ buttons, rotation and scale |
| **VIEW** | Inspect geometry and form | FIT ALL, FOCUS PART, FRONT/SIDE/TOP/3/4; actual triangle-edge **WIREFRAME**, material-neutral **CLAY**, temporary SOLO PART, SHOW ALL, a floating photo reference |
| **FILES** | Protect and share your work | OPEN GLB, EXPORT GLB, SAVE DRAFT, RESTORE DRAFT, import reference photo, demo model and help |

The top bar always exposes **OPEN**, **EXPORT GLB**, **UNDO** and **REDO**. A project label displays the active model and whether it has unsaved changes.

### Quick start: editing a body panel
1. Tap **OPEN** and choose a `.glb` file from Android's document picker (or use FILES → DEMO MODEL).
2. In **SHAPE**, choose the component from the part dropdown, then tap a point. **EDIT POINTS** is off by default so orbiting cannot accidentally deform the mesh.
3. Enable **EDIT POINTS** to drag the selected vertex. Switch **SOFT SHAPE** on for broader changes and choose a profile: **ROUND BRUSH** (spherical falloff), **BODY SECTION** (a slice along X/Y/Z, ideal for body width, roof height or longitudinal shape), or **KEEP HARD EDGES** (avoids moving vertices with sharply different normal directions). Adjust Radius to control influence. **MIRROR X** is symmetric about the current mesh's local X=0 plane.
4. In **MOVE**, choose WHOLE PART to position a booster, body panel or other component, or SELECTED POINT to move an individual mesh vertex. **Tap and drag the colored X/Y/Z handles directly on the model** for constrained movement. Use the six XYZ buttons for precise numerical movement; rotate/scale parts with the larger buttons. Tap a visible component in MOVE to select it directly.
5. Inspect in **VIEW** using clay, wireframe and orthographic-like preset angles. **SOLO PART** temporarily hides other meshes, and exporting restores all parts first.
6. In **FILES**, use **SAVE DRAFT** to keep a private working copy on the phone and **EXPORT GLB** to write a shareable version through Android's file picker.

### Storage and export

Godot 4.5.2's built-in Android picker could report valid file selections as canceled when it could not map a document URI to a filesystem path. This project includes the original, MIT-licensed **ModelForgeFiles** Android bridge: it uses Android's Storage Access Framework and streams the selected URI with `ContentResolver` into private working storage, without requesting unrestricted storage permissions. Export likewise uses Android's Create Document flow.

Drafts are kept under app-private `user://` storage and may be lost if the app is uninstalled or app data is cleared. **Export important work as a GLB.** Imported source files are not overwritten automatically. When opening another model or replacing the current one with the demo, the app attempts to back up unsaved work in the local draft. The UI provides one draft slot.

Material-neutral CLAY and SOLO PART are inspection-only views. Export restores actual materials and includes all parts. The wireframe is drawn as triangle edges; dense models display a sampled overlay for phone performance.

### Current technical scope
- Godot 4.5.2 Mobile renderer, GDScript, Android Gradle build and native Java SAF bridge.
- Per-mesh edit sessions with a 20-operation cross-part undo/redo stack for geometry moves, smoothing and part transforms.
- On-model **red X, green Y, blue Z gizmos** that move a part or point with a single undoable gesture; screen-space hit regions are generous for finger input and handles remain visible in front of geometry.
- Tap-to-select entire mesh parts using ray/bounds intersection, in addition to the part dropdown.
- Imported mesh vertex editing, seam-aware changes, symmetry and three soft-shape profiles: spherical, station-band cross-section, or normal-guarded brush. Crease protection also applies to localized smoothing.
- Whole-part translation, rotation around local Y and uniform scaling.
- Demo geometry, reference image display, focus camera, mobile-friendly four-page interface, and gizmo/surface regression tests.
- GitHub Actions CI smoke tests for geometry, GUI taps, GLB import/export, Android picker callbacks and the full editing workflow.
- An ARM64 debug APK is published by every **successful** build.

### Test APK
Open the [Model Forge Android build workflow](https://github.com/tpylman90-ctrl/Model-forge/actions/workflows/android.yml), select a successful run, and download its `ModelForge-Android-APK` artifact. Extract the ZIP and install the APK on your phone. Debug keys may change between CI runs, requiring uninstall of older debug builds.

### Important limitations
- v0.5 is still an experimental **vertex/part editor**, not complete polygon, automotive Class-A, or subdivision modeling software. Edge-loop insertion, face extrusion, bevel tools, UV edits, advanced material editing, skinning, animation preservation and sculpting remain future work.
- Godot's glTF importer/exporter may not preserve every GLB extension, animation, morph target, rig, metadata item, shader, custom material or LOD. Always back up source assets and re-open exported files for validation.
- The SOFT SHAPE radius is local to the selected mesh; if you want to affect multiple independent parts, edit those parts separately. Imported mesh symmetry depends on its local X=0 plane.
- Large/dense assets may be slow during vertex selection and rebuilding. The viewport wireframe samples overly dense meshes to cap memory use.
- Draft storage is private to the app; exporting is the way to retain and share work outside the app.
- A successful headless build and CI test **does not substitute for physical Android-device testing**, particularly Android Storage Access Framework provider behavior and touch ergonomics.

### Roadmap
1. Real-phone import/edit/export verification of several production GLBs from Neon Forge Racing and other sources.
2. Visible gizmo handles, occlusion-aware mesh/vertex picking, selection by tapping model parts and customizable editing sensitivity.
3. True editable low-poly control cages and automotive reflection/highlight inspection, with multi-view reference layouts.
4. Cut/extrude/bevel and topology tools, mesh-specific materials and UV/texture inspectors.
5. Portable structured feedback format and AssetWright/AI-assisted revision integration.

## License
Model Forge code is MIT-licensed; Godot Engine is also MIT-licensed. Third-party contributions must include their own appropriate licenses. All dependencies are free and legally redistributable.


### Automotive surface control: what it does and does not do

**BODY SECTION** moves mesh vertices within a soft longitudinal (or X/Y) station band. This helps refine the width and stance of a roofline, fender or nose. It is **not** a procedural NURBS rebuild and does not guarantee surface continuity. Work on one independent mesh at a time; cross-section strokes may also move disconnected islands of that same mesh with similar station coordinates.

**KEEP HARD EDGES** relies on available vertex normals and a 35° normal-angle threshold. It avoids influencing adjacent sharply different normals when shaping or smoothing, while preserving same-position UV seam duplicates during movement. This is a practical first guard, not a full topological crease-classification solver. When imported meshes lack normals or use inconsistent normals, its protection is limited.

The colored gizmos use global XYZ directions and maintain a roughly constant finger-friendly projected size as the camera moves. The touch drag is constrained to one axis; no rotation or scaling gizmos yet. Part movements, as well as point movements, enter the undo history on finger release.
