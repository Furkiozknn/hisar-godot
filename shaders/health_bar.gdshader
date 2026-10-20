shader_type spatial;
// Camera-facing health bar for a MultiMesh. The instance's z scale is the remaining HP
// fraction (the quad is flat, so z scale is otherwise unused).
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled, skip_vertex_transform;

varying float frac;

void vertex() {
	frac = length(MODEL_MATRIX[2].xyz);
	// billboard: keep the instance origin and x scale, face the camera (output in view space)
	float sx = length(MODEL_MATRIX[0].xyz);
	vec3 center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 world = center + INV_VIEW_MATRIX[0].xyz * VERTEX.x * sx + INV_VIEW_MATRIX[1].xyz * VERTEX.y;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
}

void fragment() {
	vec3 good = vec3(0.13, 0.77, 0.37);
	vec3 bad = vec3(0.86, 0.15, 0.15);
	vec3 mid = vec3(0.98, 0.75, 0.14);
	vec3 col = frac > 0.5 ? mix(mid, good, (frac - 0.5) * 2.0) : mix(bad, mid, frac * 2.0);
	float edge = step(0.06, UV.x) * step(UV.x, 0.94) * step(0.18, UV.y) * step(UV.y, 0.82);
	float fill = step((UV.x - 0.06) / 0.88, frac);
	vec3 back = vec3(0.14, 0.1, 0.07);
	ALBEDO = mix(back, col, fill * edge);
	ALPHA = 0.92;
}
