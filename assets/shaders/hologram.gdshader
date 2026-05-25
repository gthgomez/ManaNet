shader_type canvas_item;

uniform vec4 holo_color : source_color = vec4(0.29, 0.56, 0.85, 0.82);
uniform float scanline_speed : hint_range(0.1, 5.0) = 1.6;
uniform float scanline_scale : hint_range(10.0, 200.0) = 90.0;
uniform float flicker_amount : hint_range(0.0, 0.2) = 0.04;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    // Dynamic horizontal scanline sweep
    float scanline = sin(UV.y * scanline_scale - TIME * scanline_speed * 4.0) * 0.18 + 0.82;
    // Micro-flicker over time
    float flicker = 1.0 - flicker_amount + sin(TIME * 24.0) * flicker_amount;

    // Tint with glow intensity, maintaining transparency
    vec4 result = tex * holo_color * scanline * flicker;
    // Add subtle ambient rim glow based on alpha edges
    float edge = tex.a * (1.0 - texture(TEXTURE, UV + vec2(0.0, 0.02)).a);
    result.rgb += holo_color.rgb * edge * 0.4;

    COLOR = result;
}
