# Model Forge

**Model Forge** is a free, MIT-licensed, native Android GLB geometry editor designed to make real 3D edits practical on a phone. It serves Neon Forge Racing vehicle work, but there are no vehicle-specific formats or paid dependencies.

## Version 0.9.1 — improved studio-quality editing viewport

A selected component now has an **amber tinted surface and visible 3D bounding outline**, making it obvious which of hundreds of independent GLB parts will be edited. Type part names or numbers into the **Find part** field to filter large assemblies, then select by tapping or the dropdown.

v0.7 introduced **frontmost-triangle part picking** in place of picking from overlapping bounding boxes, **normal-based simulated zebra reflection bands** for inspecting smooth body-panel transitions, and **swipeable horizontal tool rows** so even small phones can reach every command without hiding the model. These are viewport-only tools.

v0.8 enlarges the **actual 3D and 2D touch targets** rather than merely the surrounding scroll rows: both sliders now have 56-pixel procedural high-contrast thumbs, thicker tracks, and at least 265×76 logical-pixel touch surfaces. Dropdowns, toggles, tabs, numeric fields and toolbar buttons have larger tap areas and fonts; dropdown popups have increased row separation. Shape Radius, Zebra Bands and Move Step each gain prominent **+/− buttons** as a precise alternative to tiny drag gestures. On-model XYZ grip spheres and touch tolerance are enlarged as well. Controls remain in sideways-swipeable strips so the editing viewport keeps adequate space.

v0.8.1 addresses washed-out Clay mode: a non-exported **studio inspection shader** uses geometric triangle normals as a fallback for inconsistent imported vertex normals, stronger key/fill contrast, a restrained specular band, and an adjustable LIGHT direction (large left/right buttons). **SHOW FACETS** enables plane-normal inspection; toggle it off to favor the original smooth normals. **The amber selected-part tint is suppressed in Clay**, leaving its clear 3D bounding outline so body shapes are visible. The true material and selection tint return when Clay is switched off. The shading is analytical rather than physically accurate PBR, and it cannot reveal geometry that is not present in the mesh.

**v0.9:** The native Android editor now has a dedicated BUILD tab. Add independent BOX, CYLINDER, SPHERE and CAPSULE objects, assign custom part names, apply X/Y/Z dimensions in local GLB units, duplicate editable components, and delete/restore parts with undo. Every piece is real 3D geometry included in exported GLB models. Resizing uses per-part local transform scale, not destructive re-topology or CAD shell generation. Rotated objects may have a larger world-space bounding box than the entered local-axis dimensions. Import/export validation covers new geometry.

**v0.9 picking fix:** Shape tap selection ray-tests **the frontmost visible triangle** and restricts the selected vertex to the three vertices of that face. This prevents selecting projected points through the outer body into an internal part. For dense meshes, touch raycasts still run CPU triangle checks and may need a cached BVH in a future release.

**v0.9 textured preview:** View removes the amber tint while retaining the selection outline. Subdued ambient illumination plus separated key and fill lights restores more visible body shading; **TEXTURE CONTRAST** slider and SOFTER/MORE DEPTH buttons adjust only the editor lighting, not GLB materials. This cannot invent detail or repair wrong normals or missing maps.

**v0.9.1 studio viewport:** Editing uses a generated floating-point panorama of four softbox strips for real Godot Mobile image-based specular reflection, with filmic tone mapping, subtle color grading, directional key/fill/rim lights and one shadow-casting key. The background stays neutral dark. **STUDIO PBR** can be disabled for a simpler low-power fallback; **4× AA** toggles higher edge antialiasing (2× is default); GRID is hidden by default but can be enabled for placement. **LIGHT ◀/▶** sweeps the actual studio lights even in textured mode. Camera FIT ALL now fits projected screen extents instead of a large bounding-box diagonal, so long/low vehicles occupy more of the viewport. Texture Contrast remains adjustable. All are viewport-only effects. No textures, normal maps, roughness, metallic values, shader overrides, or geometry of an imported GLB are rewritten by the studio rig. Godot Mobile does not support screen-space SSR, SSAO or SSIL, so these are not claimed. Reflection quality and frame rate require on-device review.

The phone-first interface provides five context-sensitive pages. The model stays visible while editing; touch targets are deliberately large. The 3D view fills wide and narrow Android displays without fixed-aspect black bars.

| Page | Your task | Primary tools |
| --- | --- | --- |
| **SHAPE** | Refine body curvature | Search by part name/number, clearly highlight the selected part, then select a vertex; arm EDIT POINTS deliberately; choose ROUND BRUSH, BODY SECTION, or KEEP HARD EDGES with adjustable radius, MIRROR X and SMOOTH |
| **MOVE** | Assemble independently engineered components | Drag large colored **3D gizmo handles on the model**: red X, green Y, blue Z. Tap a component to select it; switch between WHOLE PART, SELECTED POINT, and WHOLE MODEL, or use precision XYZ buttons, rotation and scale |
| **VIEW** | Inspect geometry and form | FIT ALL, FOCUS PART, FRONT/SIDE/TOP/3/4; triangle-edge WIREFRAME, material-neutral CLAY, **ZEBRA STRIPES** with adjustable band count, SOLO PART, SHOW ALL, reference photo |
| **BUILD** | Extend the actual 3D model | Add independent solids, enter exact dimensions, resize chosen parts, duplicate components or undo-delete parts |
| **FILES** | Protect and share your work | OPEN GLB, EXPORT GLB, SAVE DRAFT, RESTORE DRAFT, import reference photo, demo model and help |

The top bar always exposes **OPEN**, **EXPORT GLB**, **UNDO** and **REDO**. A project label displays the active model and whether it has unsaved changes.

### Quick start: editing a body panel
1. Tap **OPEN** and choose a `.glb` file from Android's document picker (or use FILES → DEMO MODEL).
2. In **SHAPE**, type part of a component's name (or number) into **Find part**, pick the match in the dropdown, or tap a component. An amber tint and outline identify the active mesh. Then tap a point. **EDIT POINTS** is off by default so orbiting cannot accidentally deform the mesh.
3. Enable **EDIT POINTS** to drag the selected vertex. Switch **SOFT SHAPE** on for broader changes and choose a profile: **ROUND BRUSH** (spherical falloff), **BODY SECTION** (a slice along X/Y/Z, ideal for body width, roof height or longitudinal shape), or **KEEP HARD EDGES** (avoids moving vertices with sharply different normal directions). Adjust Radius to control influence. **MIRROR X** is symmetric about the current mesh's local X=0 plane.
4. In **MOVE**, choose WHOLE PART to position a booster, body panel or other component, SELECTED POINT to adjust a mesh vertex, or WHOLE MODEL to translate/rotate/scale the complete imported assembly without welding or distorting its components. **Tap and drag the colored X/Y/Z handles directly on the model** for constrained movement. Use the six XYZ buttons for precise numerical movement; rotate/scale parts with the larger buttons. Tap a visible component in MOVE to select it directly.
5. Inspect in **VIEW** using clay, wireframe, orthographic-like preset angles, the **HIGHLIGHT PART** toggle, and **ZEBRA STRIPES**. Zebra mode uses the surface normal and reflected view direction to simulate alternating studio reflection strips; orbit the camera to find kinks or shading discontinuities. Move the Bands slider to change the inspection frequency. **SOLO PART** temporarily hides other meshes, and exporting restores all parts first.
6. In **FILES**, use **SAVE DRAFT** to keep a private working copy on the phone and **EXPORT GLB** to write a shareable version through Android's file picker.

### Storage and export

Godot 4.5.2's built-in Android picker could report valid file selections as canceled when it could not map a document URI to a filesystem path. This project includes the original, MIT-licensed **ModelForgeFiles** Android bridge: it uses Android's Storage Access Framework and streams the selected URI with `ContentResolver` into private working storage, without requesting unrestricted storage permissions. Export likewise uses Android's Create Document flow.

Drafts are kept under app-private `user://` storage and may be lost if the app is uninstalled or app data is cleared. **Export important work as a GLB.** Imported source files are not overwritten automatically. When opening another model or replacing the current one with the demo, the app attempts to back up unsaved work in the local draft. The UI provides one draft slot.

The amber selection tint and 3D bounding outline are also inspection-only and excluded from GLB export. In MOVE → WHOLE MODEL, the amber outline surrounds the complete model rather than one mesh. Material-neutral CLAY and SOLO PART are inspection-only views. Export restores actual materials and includes all parts. The wireframe is drawn as triangle edges; dense models display a sampled overlay for phone performance.

### Current technical scope
- Godot 4.5.2 Mobile renderer, GDScript, Android Gradle build and native Java SAF bridge.
- Per-mesh edit sessions with a 20-operation cross-part undo/redo stack for geometry moves, smoothing and part transforms.
- On-model **red X, green Y, blue Z gizmos** that move a part or point with a single undoable gesture; screen-space hit regions are generous for finger input and handles remain visible in front of geometry.
- Tap-to-select entire mesh parts with AABB broad-phase and **exact triangle intersection** for visible-surface ranking, or use the searchable part dropdown for large GLBs. The selected mesh is visibly tinted amber and boxed in an outline without replacing original materials.
- Whole-model mode moves, rotates around the model's combined bounding center, or uniformly scales all imported top-level GLB roots, preserving the hierarchy and relative component placement. X/Y/Z gizmos and numeric controls work on the assembly, with unified undo/redo.
- Imported mesh vertex editing, seam-aware changes, symmetry and three soft-shape profiles: spherical, station-band cross-section, or normal-guarded brush. Crease protection also applies to localized smoothing.
- Whole-part translation, rotation around local Y and uniform scaling.
- Demo geometry, reference image display, focus camera, swipe-scrollable mobile command strips, 56 px slider grabbers with thick tracks, and automated touch-target/real GUI tap tests.
- GitHub Actions CI smoke tests for geometry, GUI taps, GLB import/export, Android picker callbacks and the full editing workflow.
- An ARM64 debug APK is published by every **successful** build.

### Test APK
Open the [Model Forge Android build workflow](https://github.com/tpylman90-ctrl/Model-forge/actions/workflows/android.yml), select a successful run, and download its `ModelForge-Android-APK` artifact. Extract the ZIP and install the APK on your phone. Debug keys may change between CI runs, requiring uninstall of older debug builds.

### Important limitations
- v0.9.1 is still an experimental **vertex/part editor**, not complete polygon, automotive Class-A, or subdivision modeling software. Edge-loop insertion, face extrusion, bevel tools, UV edits, advanced material editing, skinning, animation preservation and sculpting remain future work.
- Godot's glTF importer/exporter may not preserve every GLB extension, animation, morph target, rig, metadata item, shader, custom material or LOD. Always back up source assets and re-open exported files for validation.
- WHOLE MODEL changes the assembly's transform and is **not yet a multi-mesh soft sculpt**. BODY SECTION and SOFT SHAPE still operate on one selected mesh at a time.
- The SOFT SHAPE radius is local to the selected mesh; if you want to affect multiple independent parts, edit those parts separately. Imported mesh symmetry depends on its local X=0 plane.
- Precise triangle selection walks triangle data on a finger tap and may take longer on very dense meshes; it does not yet use a cached triangle BVH. Meshes without accessible triangle arrays are not triangle-pickable, but remain accessible in the part list.
- Zebra is **simulated** studio-reflection banding based on surface normals, not a calibrated physically correct automotive light-tunnel or real environmental HDR reflection. It intentionally temporarily overrides appearance and is never exported.
- Large/dense assets may be slow during vertex selection and rebuilding. The viewport wireframe samples overly dense meshes to cap memory use.
- Draft storage is private to the app; exporting is the way to retain and share work outside the app.
- A successful headless build and CI test **does not substitute for physical Android-device testing**, particularly Android Storage Access Framework provider behavior and touch ergonomics.

### Roadmap
1. Real-phone import/edit/export verification of several production GLBs from Neon Forge Racing and other sources.
2. Visible gizmo handles, occlusion-aware mesh/vertex picking, selection by tapping model parts and customizable editing sensitivity.
3. Fast cached triangle BVH for dense imported meshes, selectable reflection-line direction, and true editable low-poly control cages with automotive continuity inspection and multi-view reference layouts.
4. Cut/extrude/bevel and topology tools, mesh-specific materials and UV/texture inspectors.
5. Portable structured feedback format and AssetWright/AI-assisted revision integration.

## License
Model Forge code is MIT-licensed; Godot Engine is also MIT-licensed. Third-party contributions must include their own appropriate licenses. All dependencies are free and legally redistributable.


### Automotive surface control: what it does and does not do

**BODY SECTION** moves mesh vertices within a soft longitudinal (or X/Y) station band. This helps refine the width and stance of a roofline, fender or nose. It is **not** a procedural NURBS rebuild and does not guarantee surface continuity. Work on one independent mesh at a time; cross-section strokes may also move disconnected islands of that same mesh with similar station coordinates.

**KEEP HARD EDGES** relies on available vertex normals and a 35° normal-angle threshold. It avoids influencing adjacent sharply different normals when shaping or smoothing, while preserving same-position UV seam duplicates during movement. This is a practical first guard, not a full topological crease-classification solver. When imported meshes lack normals or use inconsistent normals, its protection is limited.

The colored gizmos use global XYZ directions and maintain a roughly constant finger-friendly projected size as the camera moves. The touch drag is constrained to one axis; no rotation or scaling gizmos yet. Part movements, as well as point movements, enter the undo history on finger release.
