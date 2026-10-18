shader_type canvas_item;
// Fog / rain haze laid over the 3D view (under the HUD). The camera looks side-on, so how far something is from the
// plane is just its horizontal distance on screen: pixels further than vis_start (world units) from the plane fade toward
// the fog colour, reaching `strength` at vis_end.
uniform vec4 fog_color : source_color = vec4(0.8, 0.85, 0.9, 1.0);
uniform float plane_px = 270.0;      // the plane's screen x (virtual pixels)
uniform float px_per_unit = 10.0;    // screen pixels per world unit
uniform float view_px = 1080.0;      // virtual screen width
uniform float vis_start = 20.0;
uniform float vis_end = 140.0;
uniform float strength = 0.97;
uniform float base_haze = 0.0;       // a thin haze everywhere (rain)

void fragment() {
	float x_px = UV.x * view_px;
	float d = abs(x_px - plane_px) / max(px_per_unit, 0.001);
	float a = smoothstep(vis_start, vis_end, d) * strength;
	a = max(a, base_haze);
	COLOR = vec4(fog_color.rgb, a);
}
