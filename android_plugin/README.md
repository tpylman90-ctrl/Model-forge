# ModelForgeFiles — Android file access bridge

The built-in file picker of Godot 4.5.2 maps document URIs to MediaStore filesystem paths. Valid selections from document providers can map to null, causing a false cancellation. This free MIT-licensed bridge launches ACTION_OPEN_DOCUMENT / ACTION_CREATE_DOCUMENT, then streams the selected URI directly using ContentResolver.

For Open GLB and reference photos the file is copied into the app-private cache. For export, a temporary private GLB is streamed into the document chosen with Android's Save picker. The app requests no broad storage permissions.

CI builds this v2 Android plugin as an AAR, copies it into addons/ModelForgeFiles/bin/debug, enables Godot's Gradle export, and exports the Android APK. It depends on the official Godot 4.5.2 engine library for compilation, without packaging another copy of Godot.

A real Android document-provider smoke test is needed to confirm the full OS picker round trip.
