shader_type canvas_item;

uniform float discard_threshold : hint_range(0.0, 1.0) = 0.04;
uniform vec4 glow_color : source_color = vec4(0.58, 0.42, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 10.0) = 2.5;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    vec4 tint = COLOR;
    
    // Calculate brightness (Luminance)
    float luma = dot(col.rgb, vec3(0.299, 0.587, 0.114));
    
    // Chromakey: Discard dark backgrounds (assuming dark navy/black background in JPG)
    if (luma < discard_threshold) {
        discard;
    }
    
    // Core Emissive Glow
    // We pulse the intensity to give it "Tactile Juice"
    float pulse = 0.8 + 0.2 * sin(TIME * pulse_speed);
    
    // Apply glow more strongly to the brighter parts of the sprite
    vec3 emissive = glow_color.rgb * glow_intensity * pulse * luma;
    
    // Final color: Original sprite (tinted) + Emissive pulse
    COLOR = vec4((col.rgb * tint.rgb) + emissive, col.a * tint.a);
}
