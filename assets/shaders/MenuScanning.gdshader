shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(0.2, 0.6, 1.0, 0.4);
uniform float line_thickness : hint_range(0.0, 0.05) = 0.005;
uniform float line_speed : hint_range(0.0, 5.0) = 1.0;
uniform float line_spacing : hint_range(0.0, 0.5) = 0.1;
uniform float angle : hint_range(0.0, 360.0) = 45.0;

void fragment() {
    float rad = radians(angle);
    vec2 dir = vec2(cos(rad), sin(rad));
    float pos = dot(UV, dir);
    
    float pulse = step(1.0 - line_thickness, fract(pos / line_spacing + TIME * line_speed));
    
    COLOR = mix(vec4(0.0), line_color, pulse);
}
