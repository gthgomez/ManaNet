shader_type canvas_item;

uniform float sweep_pos : hint_range(-1.0, 2.0) = -1.0;
uniform float sweep_width : hint_range(0.0, 0.5) = 0.1;
uniform vec4 sweep_color : source_color = vec4(1.0, 1.0, 1.0, 0.3);

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    float sweep = smoothstep(sweep_pos - sweep_width, sweep_pos, UV.x) - smoothstep(sweep_pos, sweep_pos + sweep_width, UV.x);
    COLOR = mix(color, sweep_color, sweep * color.a);
}
