shader_type canvas_item;

// Alpha cutouts: discard by alpha, never by luma.
// The old luma chromakey punched holes in dark steel on PNG sprites.
uniform float discard_threshold : hint_range(0.0, 1.0) = 0.04;
uniform vec4 glow_color : source_color = vec4(0.58, 0.42, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 10.0) = 0.85;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float glow_luma_gate : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec4 tint = COLOR;

	if (col.a < discard_threshold) {
		discard;
	}

	float luma = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	float pulse = 0.85 + 0.15 * sin(TIME * pulse_speed);
	// Only the bright accent pixels emit. Grey chassis stays chassis.
	float emit_mask = smoothstep(glow_luma_gate, glow_luma_gate + 0.25, luma);
	vec3 emissive = glow_color.rgb * glow_intensity * pulse * emit_mask;

	COLOR = vec4((col.rgb * tint.rgb) + emissive, col.a * tint.a);
}
