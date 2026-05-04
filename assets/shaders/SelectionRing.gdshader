shader_type canvas_item;

uniform vec4 ring_color : source_color = vec4(0.22, 0.88, 0.95, 1.0);
uniform float inner_radius : hint_range(0.0, 1.0) = 0.4;
uniform float thickness : hint_range(0.0, 0.5) = 0.05;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float grid_intensity : hint_range(0.0, 1.0) = 0.4;

void fragment() {
    vec2 center = vec2(0.5);
    float dist = distance(UV, center);
    
    // Outer ring
    float ring = smoothstep(inner_radius, inner_radius + 0.01, dist) - 
                 smoothstep(inner_radius + thickness, inner_radius + thickness + 0.01, dist);
    
    // Inner scanning grid effect
    float grid = 0.0;
    if (dist < inner_radius + thickness) {
        float line_v = step(0.95, fract(UV.x * 20.0));
        float line_h = step(0.95, fract(UV.y * 20.0));
        grid = (line_v + line_h) * grid_intensity * (1.0 - dist / inner_radius);
    }
    
    float pulse = 0.7 + 0.3 * sin(TIME * pulse_speed);
    float final_alpha = (ring + grid) * ring_color.a * pulse;
    
    COLOR = vec4(ring_color.rgb, final_alpha);
}
