@tool
extends EditorPlugin

var _exporter: EditorExportPlugin

func _enter_tree() -> void:
    _exporter = ModelForgeAndroidExport.new()
    add_export_plugin(_exporter)

func _exit_tree() -> void:
    if _exporter != null:
        remove_export_plugin(_exporter)
        _exporter = null

class ModelForgeAndroidExport extends EditorExportPlugin:
    func _supports_platform(platform: EditorExportPlatform) -> bool:
        return platform is EditorExportPlatformAndroid

    func _get_name() -> String:
        return "ModelForgeFiles"

    func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
        if debug:
            return PackedStringArray(["ModelForgeFiles/bin/debug/ModelForgeFiles-debug.aar"])
        return PackedStringArray(["ModelForgeFiles/bin/release/ModelForgeFiles-release.aar"])
