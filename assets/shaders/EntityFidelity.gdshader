shader_type canvas_item;

uniform float threshold_r : hint_range(0.0, 1.0) = 0.18;
uniform float threshold_g : hint_range(0.0, 1.0) = 0.18;
uniform float threshold_b : hint_range(0.0, 1.0) = 0.32;
uniform float brightness_threshold : hint_range(0.0, 1.0) = 0.32;

uniform float outline_width : hint_range(0.0, 10.0) = 1.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 0.45);

varying float hit_flash;

void vertex() {
    hit_flash = INSTANCE_CUSTOM.x;
}

bool is_cutout(vec4 c) {
    float b = max(c.r, max(c.g, c.b));
    return (c.a < 0.01 || (c.r < threshold_r && c.g < threshold_g && c.b < threshold_b && b < brightness_threshold));
}

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    vec4 tint = COLOR;
    
    bool self_cutout = is_cutout(col);
    
    if (self_cutout) {
        // Outline logic: check neighbors
        vec2 ps = TEXTURE_PIXEL_SIZE * outline_width;
        bool has_neighbor = false;
        if (!is_cutout(texture(TEXTURE, UV + vec2(ps.x, 0)))) has_neighbor = true;
        else if (!is_cutout(texture(TEXTURE, UV + vec2(-ps.x, 0)))) has_neighbor = true;
        else if (!is_cutout(texture(TEXTURE, UV + vec2(0, ps.y)))) has_neighbor = true;
        else if (!is_cutout(texture(TEXTURE, UV + vec2(0, -ps.y)))) has_neighbor = true;
        
        if (has_neighbor) {
            COLOR = outline_color;
        } else {
            discard;
        }
    } else {
        vec3 final_rgb = mix(col.rgb * tint.rgb, vec3(1.0, 1.0, 1.0), hit_flash);
        COLOR = vec4(final_rgb, col.a * tint.a);
    }
}
