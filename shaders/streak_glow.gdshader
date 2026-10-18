shader_type canvas_item;
// A soft glow around the screen edges that grows with the Greaser streak.
uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform float intensity = 0.0;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p * vec2(1.0, 1.55));
	float a = smoothstep(0.30, 0.80, d) * intensity;
	COLOR = vec4(glow_color.rgb, a);
}
