shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.58, 0.42, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 10.0) = 1.0;
uniform bool is_active = true;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    
    if (is_active) {
        float pulse = 0.8 + 0.2 * sin(TIME * pulse_speed);
        // Additive glow based on alpha of the original sprite
        vec3 glow = glow_color.rgb * glow_intensity * pulse * tex.a;
        COLOR = vec4(tex.rgb + glow, tex.a);
    } else {
        COLOR = tex;
    }
}
