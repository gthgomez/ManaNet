shader_type canvas_item;

uniform vec4 color1 : source_color = vec4(0.08, 0.10, 0.12, 1.0);
uniform vec4 color2 : source_color = vec4(0.12, 0.15, 0.16, 1.0);
uniform float speed : hint_range(0.0, 2.0) = 0.15;
uniform float scale : hint_range(0.1, 10.0) = 2.5;

void fragment() {
	vec2 uv = UV * scale;
	float t = TIME * speed;
	
	// Layered plasma noise
	float noise = sin(uv.x + t) * 0.5 + 0.5;
	noise += sin(uv.y + t * 0.8 + noise) * 0.5 + 0.5;
	noise += sin((uv.x + uv.y) * 0.5 + t * 1.2) * 0.5 + 0.5;
	noise /= 3.0;
	
	// Refraction-like distortion
	vec2 dist_uv = UV + vec2(sin(UV.y * 10.0 + t), cos(UV.x * 10.0 + t)) * 0.01;
	
	vec4 final_color = mix(color1, color2, noise);
	
	// Add a slight vignette
	float vignette = distance(UV, vec2(0.5));
	final_color.rgb *= (1.0 - vignette * 0.5);
	
	COLOR = final_color;
}
