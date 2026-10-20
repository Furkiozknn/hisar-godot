shader_type spatial;
// Faceted low-poly sea: vertex waves, flat face normals, shallow-to-deep tint and shore foam.

uniform vec4 shallow : source_color = vec4(0.36, 0.69, 0.76, 1.0);
uniform vec4 deep : source_color = vec4(0.16, 0.45, 0.62, 1.0);
uniform vec4 foam : source_color = vec4(0.96, 0.93, 0.85, 1.0);
uniform float shore_x = 41.0;

varying vec3 world_pos;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(w.x * 0.35 + TIME * 1.1) * 0.12 + cos(w.z * 0.28 + TIME * 0.8) * 0.1;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	float depth = smoothstep(shore_x, shore_x + 22.0, world_pos.x);
	vec3 col = mix(shallow.rgb, deep.rgb, depth);
	float f = 1.0 - smoothstep(shore_x - 1.0, shore_x + 3.0 + sin(world_pos.z * 0.3 + TIME) * 0.8, world_pos.x);
	col = mix(col, foam.rgb, clamp(f, 0.0, 1.0) * 0.75);
	ALBEDO = col;
	ALPHA = mix(0.78, 0.92, depth);
	ROUGHNESS = 0.18;
	SPECULAR = 0.6;
}
