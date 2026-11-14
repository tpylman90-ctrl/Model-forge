extends Node3D
## Model Forge 3-axis touch manipulator. Visual helpers never enter GLB exports.
## X=red, Y=green, Z=blue; generous touch hit regions for phones.

const AXIS_X := Vector3(1.0, 0.0, 0.0)
const AXIS_Y := Vector3(0.0, 1.0, 0.0)
const AXIS_Z := Vector3(0.0, 0.0, 1.0)
const AXES := [AXIS_X, AXIS_Y, AXIS_Z]
const TINTS := [
    Color("#ff6172"),
    Color("#55f0a7"),
    Color("#67acff")
]
var handle_length: float = 1.0

func _ready() -> void:
    name = "TouchAxisHandles"
    for axis_index in range(3):
        var direction: Vector3 = AXES[axis_index]
        var material := StandardMaterial3D.new()
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.albedo_color = TINTS[axis_index]
        material.no_depth_test = true

        var shaft := MeshInstance3D.new()
        shaft.name = ["X_Red", "Y_Green", "Z_Blue"][axis_index] + "_Shaft"
        var shaft_mesh := CylinderMesh.new()
        shaft_mesh.top_radius = 0.032
        shaft_mesh.bottom_radius = 0.032
        shaft_mesh.height = 0.78
        shaft_mesh.radial_segments = 10
        shaft.mesh = shaft_mesh
        shaft.material_override = material
        shaft.position = direction * 0.54
        shaft.quaternion = Quaternion(Vector3.UP, direction)
        add_child(shaft)

        var grip := MeshInstance3D.new()
        grip.name = ["X", "Y", "Z"][axis_index] + "_DragGrip"
        var sphere := SphereMesh.new()
        sphere.radius = 0.15
        sphere.height = 0.30
        sphere.radial_segments = 12
        sphere.rings = 6
        grip.mesh = sphere
        grip.material_override = material
        grip.position = direction * 1.03
        add_child(grip)
    visible = false

func place(world_center: Vector3, world_length: float) -> void:
    global_position = world_center
    handle_length = maxf(world_length, 0.02)
    scale = Vector3.ONE * handle_length

func tip_world(axis_index: int) -> Vector3:
    return to_global(AXES[axis_index] * 1.03)

func center_world() -> Vector3:
    return global_position

func hit_axis(viewport_position: Vector2, view_camera: Camera3D) -> int:
    if not visible:
        return -1
    var origin: Vector3 = center_world()
    if view_camera.is_position_behind(origin):
        return -1
    var origin_px: Vector2 = view_camera.unproject_position(origin)
    var best_axis := -1
    var best_distance := 37.0
    for a in range(3):
        var tip: Vector3 = tip_world(a)
        if view_camera.is_position_behind(tip):
            continue
        var tip_px: Vector2 = view_camera.unproject_position(tip)
        var segment: Vector2 = tip_px - origin_px
        if segment.length_squared() < 160.0:
            continue
        var t: float = clampf((viewport_position - origin_px).dot(segment) / segment.length_squared(), 0.25, 1.15)
        var projected: Vector2 = origin_px + segment * t
        var dist: float = viewport_position.distance_to(projected)
        if dist < best_distance:
            best_distance = dist
            best_axis = a
    return best_axis

func drag_delta(axis_index: int, from_screen: Vector2, to_screen: Vector2, view_camera: Camera3D) -> Vector3:
    if axis_index < 0 or axis_index >= 3:
        return Vector3.ZERO
    var center: Vector3 = center_world()
    var tip: Vector3 = tip_world(axis_index)
    var screen_axis: Vector2 = view_camera.unproject_position(tip) - view_camera.unproject_position(center)
    var travel: Vector2 = to_screen - from_screen
    var world_units: float = 0.0
    if screen_axis.length_squared() > 225.0:
        world_units = travel.dot(screen_axis) / screen_axis.length_squared() * (handle_length * 1.03)
    else:
        # Axis almost directly faces the camera: vertical drag fallback.
        world_units = -travel.y * handle_length / 110.0
    return AXES[axis_index] * clampf(world_units, -1000.0, 1000.0)
