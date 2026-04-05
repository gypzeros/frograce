shader_type spatial;
// Sombras reales activadas

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float edge_width : hint_range(0.5, 8.0) = 3.0;

void fragment() {
	vec2 uv = UV;
	vec2 fw = fwidth(uv);
	// Aristas consistentes independiente del tamano de la cara
	vec2 edge = smoothstep(vec2(0.0), fw * edge_width, uv) *
	            smoothstep(vec2(0.0), fw * edge_width, vec2(1.0) - uv);
	float e = min(edge.x, edge.y);
	ALBEDO = mix(vec3(0.0), albedo_color.rgb, e);
}
