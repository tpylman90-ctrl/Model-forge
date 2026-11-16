shader_type spatial;
render_mode unshaded, cull_disabled;

// Analysis-only studio clay. No source GLB material or normals are changed.
// Even imperfect/missing imported normals can be inspected using derivative
// normals computed from the actual rasterized triangle positions.
uniform float light_azimuth : hint_range(-3.14159, 3.14159, 0.01) = 0.45;
uniform float facet_strength : hint_range(0.0, 1.0, 0.01) = 0.85;
uniform vec3 clay_tone : source_color = vec3(0.34, 0.35, 0.37);

varying vec3 fragment_world;

void vertex() {
    fragment_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 eye = normalize(CAMERA_POSITION_WORLD - fragment_world);

    vec3 imported_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
    float imported_length = length(imported_normal);
    imported_normal = imported_length > 0.0001
        ? imported_normal / imported_length
        : vec3(0.0, 1.0, 0.0);

    // Unlike per-vertex normal data, this always tracks the triangle's
    // visible plane. Its world-space derivatives expose planar hard edges.
    vec3 dpdx = dFdx(fragment_world);
    vec3 dpdy = dFdy(fragment_world);
    vec3 geometric = cross(dpdx, dpdy);
    float geometric_length = length(geometric);
    geometric = geometric_length > 0.0000001
        ? geometric / geometric_length
        : imported_normal;
    if (dot(geometric, eye) < 0.0) {
        geometric = -geometric;
    }
    if (dot(imported_normal, geometric) < 0.0) {
        imported_normal = -imported_normal;
    }
    vec3 n = normalize(mix(imported_normal, geometric, facet_strength));

    // Strong, movable key light + restrained fill and thin reflection line.
    // These are deterministic independent of mobile ambient/HDR exposure.
    vec3 key = normalize(vec3(cos(light_azimuth), 0.66, sin(light_azimuth)));
    vec3 fill = normalize(vec3(-0.85, 0.22, 0.38));
    float key_diffuse = max(dot(n, key), 0.0);
    float fill_diffuse = max(dot(n, fill), 0.0);
    float diffuse = 0.12 + 0.77 * key_diffuse + 0.08 * fill_diffuse;

    float highlight = pow(max(dot(reflect(-key, n), eye), 0.0), 22.0);
    float grazing = pow(1.0 - max(dot(n, eye), 0.0), 3.0);
    vec3 shaded = clay_tone * diffuse;
    shaded += vec3(0.38, 0.40, 0.44) * highlight * 0.58;
    shaded += vec3(0.055, 0.060, 0.070) * grazing;

    ALBEDO = clamp(shaded, vec3(0.02), vec3(0.90));
}
