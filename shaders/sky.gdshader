shader_type canvas_item;
// The sky behind the world: a vertical gradient, a sun glow, a haze band on the horizon, stars at night. One draw, no textures.
uniform vec4 top : source_color = vec4(0.28, 0.55, 0.95, 1.0);
uniform vec4 mid : source_color = vec4(0.56, 0.78, 0.98, 1.0);
uniform vec4 horizon : source_color = vec4(0.84, 0.93, 1.0, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform vec2 sun_pos = vec2(0.78, 0.30);
uniform float sun_size = 0.05;
uniform float sun_glow = 0.35;
uniform float stars = 0.0;
uniform float horizon_y = 0.62;
uniform float time_s = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float v = clamp(UV.y / horizon_y, 0.0, 1.0);
	vec3 c = mix(top.rgb, mid.rgb, smoothstep(0.0, 0.62, v));
	c = mix(c, horizon.rgb, smoothstep(0.55, 1.0, v));
	// the sun: a glow that falls off with distance (aspect-corrected) and a small disc
	vec2 d = (UV - sun_pos) * vec2(1.0, 1.78);
	float r = length(d);
	c += sun_color.rgb * sun_glow * exp(-r * 5.5);
	c = mix(c, sun_color.rgb, smoothstep(sun_size, sun_size * 0.8, r) * step(0.001, sun_glow));
	// stars: a sparse grid of small twinkling points, strongest high in the sky
	vec2 cell = UV * vec2(150.0, 267.0);
	vec2 g = floor(cell);
	float h = hash(g);
	vec2 centre = vec2(0.3 + 0.4 * hash(g + 7.3), 0.3 + 0.4 * hash(g + 3.1));
	float dist = length(fract(cell) - centre);
	float tw = 0.6 + 0.4 * sin(time_s * 2.0 + h * 40.0);
	float star = step(0.975, h) * smoothstep(0.22, 0.0, dist) * tw * (1.0 - v) * stars;
	c += vec3(star);
	COLOR = vec4(c, 1.0);
}
