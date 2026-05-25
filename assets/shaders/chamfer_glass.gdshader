shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.068, 0.108, 0.195, 0.65);
uniform vec4 border_color : source_color = vec4(0.290, 0.565, 0.851, 0.72);
uniform vec4 border_glow_color : source_color = vec4(0.290, 0.565, 0.851, 0.28);
uniform float border_width : hint_range(0.5, 10.0) = 2.0;
uniform float chamfer_size : hint_range(0.0, 100.0) = 24.0;
uniform float glow_size : hint_range(0.0, 50.0) = 12.0;
uniform vec2 panel_size = vec2(600.0, 400.0);

float sdChamferedBox(vec2 p, vec2 b, float c) {
    p = abs(p);
    float d1 = max(p.x - b.x, p.y - b.y);
    float d2 = (p.x + p.y) - (b.x + b.y - c);
    return max(d1, d2);
}

void fragment() {
    vec2 p = (UV - 0.5) * panel_size;
    vec2 half_size = panel_size * 0.5;
    float dist = sdChamferedBox(p, half_size, chamfer_size);

    if (dist > 0.0) {
        float glow = exp(-dist / (glow_size * 0.6));
        COLOR = vec4(border_glow_color.rgb, border_glow_color.a * glow);
    } else {
        vec4 col = bg_color;
        float border_mask = smoothstep(-border_width - 1.0, -border_width, dist) - smoothstep(-0.5, 0.0, dist);

        // Soft reflective sweep
        float reflection = smoothstep(0.4, 0.44, UV.y + sin(UV.x - TIME * 0.4) * 0.15) *
                           (1.0 - smoothstep(0.44, 0.48, UV.y + sin(UV.x - TIME * 0.4) * 0.15)) * 0.08;

        col.rgb += vec3(reflection);
        col = mix(col, border_color, border_mask);
        COLOR = col;
    }
}
