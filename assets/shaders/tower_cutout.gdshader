// Port of Kivy _TRIM_FS chromakey shader from draw_kivy.py (lines 18-47).
// Discards dark navy background pixels from tower sprite sheets,
// leaving only the tower art visible.
shader_type canvas_item;

uniform float threshold_r : hint_range(0.0, 1.0) = 0.18;
uniform float threshold_g : hint_range(0.0, 1.0) = 0.18;
uniform float threshold_b : hint_range(0.0, 1.0) = 0.32;
uniform float brightness_threshold : hint_range(0.0, 1.0) = 0.32;

void fragment() {
	vec4 tint = COLOR;
	vec4 col = texture(TEXTURE, UV);
	float brightness = max(col.r, max(col.g, col.b));
	if (col.a < 0.01 || (col.r < threshold_r && col.g < threshold_g && col.b < threshold_b && brightness < brightness_threshold)) {
		discard;
	}
	// Subtle additive boost for brighter colors (Juice)
	COLOR = (col * tint) + (col * 0.1);
}
