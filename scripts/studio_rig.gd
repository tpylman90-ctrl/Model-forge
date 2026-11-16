extends RefCounted
## Lightweight offline HDR studio softbox panorama for Godot Mobile PBR.
## Generates a static floating-point environment without external assets
## or any material overrides. Keep the background dark separately.

static func make_panorama() -> ImageTexture:
    const WIDTH: int = 384
    const HEIGHT: int = 192
    var pixels := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBAF)
    for y in range(HEIGHT):
        var v: float = (float(y) + 0.5) / float(HEIGHT)
        for x in range(WIDTH):
            var u: float = (float(x) + 0.5) / float(WIDTH)
            # Dark panoramic studio ceiling / low bounce to keep body cavities
            # shaded. Rectangle softboxes become genuine specular reflections.
            var base: Vector3 = Vector3(0.040, 0.046, 0.058)
            base += Vector3(0.065, 0.072, 0.083) * pow(clampf(1.0 - absf(v - 0.42) * 1.9, 0.0, 1.0), 2.0)
            var panel: float = 0.0
            # Broad front-left softbox, tight overhead slit, and broad side rim.
            panel += _softbox(u, v, 0.18, 0.40, 0.145, 0.26, 0.019) * 3.0
            panel += _softbox(u, v, 0.44, 0.24, 0.22, 0.060, 0.011) * 2.6
            panel += _softbox(u, v, 0.78, 0.48, 0.075, 0.28, 0.018) * 1.7
            panel += _softbox(u, v, 0.92, 0.37, 0.035, 0.17, 0.007) * 1.0
            # Floor is dark neutral with a little lift: no pure black reflections.
            if v > 0.64:
                base = base.lerp(Vector3(0.11, 0.115, 0.125), clampf((v - 0.64) * 1.6, 0.0, 1.0))
            var color: Vector3 = base + Vector3(1.0, 0.96, 0.91) * panel
            pixels.set_pixel(x, y, Color(color.x, color.y, color.z, 1.0))
    return ImageTexture.create_from_image(pixels)

static func _softbox(u: float, v: float, center_u: float, center_v: float, half_u: float, half_v: float, blur: float) -> float:
    var dx: float = absf(u - center_u)
    dx = minf(dx, 1.0 - dx)
    var dy: float = absf(v - center_v)
    var x_coverage: float = 1.0 - smoothstep(half_u - blur, half_u + blur, dx)
    var y_coverage: float = 1.0 - smoothstep(half_v - blur, half_v + blur, dy)
    return x_coverage * y_coverage

static func make_sky() -> Sky:
    var material := PanoramaSkyMaterial.new()
    material.panorama = make_panorama()
    var sky := Sky.new()
    sky.sky_material = material
    sky.radiance_size = Sky.RADIANCE_SIZE_128
    sky.process_mode = Sky.PROCESS_MODE_QUALITY
    return sky
