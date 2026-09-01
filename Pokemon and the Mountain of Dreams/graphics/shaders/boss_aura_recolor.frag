uniform sampler2D texture;
uniform vec4 auraColor;

// Convert a color to hue, saturation and value
vec3 toHsv(vec3 color) {
  vec4 constants = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
  vec4 first = mix(vec4(color.bg, constants.wz), vec4(color.gb, constants.xy), step(color.b, color.g));
  vec4 second = mix(vec4(first.xyw, color.r), vec4(color.r, first.yzx), step(first.x, color.r));
  float delta = second.x - min(second.w, second.y);
  float epsilon = 1.0e-10;
  return vec3(abs(second.z + (second.w - second.y) / (6.0 * delta + epsilon)), delta / (second.x + epsilon), second.x);
}

// Convert hue, saturation and value back to a color
vec3 toRgb(vec3 hsv) {
  vec4 constants = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 ramp = abs(fract(hsv.xxx + constants.xyz) * 6.0 - constants.www);
  return hsv.z * mix(constants.xxx, clamp(ramp - constants.xxx, 0.0, 1.0), hsv.y);
}

void main() {
  vec4 frag = texture2D(texture, gl_TexCoord[0].xy);
  vec3 pixel = toHsv(frag.rgb);
  vec3 target = toHsv(auraColor.rgb);
  // Take the hue of the aura, multiply the two saturations so a dull type stays dull, keep the
  // brightness of the pixel so the bright heart of the flame stays bright
  vec3 recolored = toRgb(vec3(target.x, pixel.y * target.y, pixel.z));
  gl_FragColor = vec4(recolored, frag.a) * gl_Color;
}
