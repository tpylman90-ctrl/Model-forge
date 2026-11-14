shader_type spatial;
render_mode unshaded, cull_disabled;

// Normal-based simulated studio light strips. This is an analysis overlay,
// not an environment reflection probe and not an export material.
uniform float stripe_density : hint_range(2.0, 32.0, 0.5) = 12.0;
uniform float roll : hint_range(-3.14, 3.14, 0.05) = 0.0;
varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 view_normal = normalize(NORMAL);
    vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(view_normal, 0.0)).xyz);
    vec3 to_eye = normalize(CAMERA_POSITION_WORLD - world_position);
    vec3 reflection_vector = normalize(reflect(-to_eye, world_normal));
    float phase = atan(reflection_vector.x, reflection_vector.z) * stripe_density + roll;
    float wave = sin(phase);
    float transition = max(0.012, fwidth(wave) * 0.85);
    float stripe = smoothstep(-transition, transition, wave);
    ALBEDO = mix(vec3(0.012, 0.020, 0.030), vec3(0.92, 0.94, 0.97), stripe);
    ALPHA = 1.0;
}
