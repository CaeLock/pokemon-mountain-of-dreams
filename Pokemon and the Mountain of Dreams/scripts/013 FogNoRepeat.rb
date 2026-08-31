# Adds a second Plane shader, :plane_no_repeat, identical to the engine's own
# :plane shader (Plane::SHADER, 0_Dependencies.rb) except the coordinate wrap
# ( mod(origin + screenCoord / zoom, textureSize) ) is replaced with a bounds
# check: anything outside the texture's own single instance is discarded
# (fully transparent) instead of being wrapped/repeated. Everything else
# (tone/color mixing, alpha) is copied verbatim from the original so it stays
# a drop-in swap.
#
# Pure addition (new registered shader), no prepend needed.
class Shader
  PLANE_NO_REPEAT_FRAG = <<~GLSL
    uniform vec4 tone;
    uniform vec4 color;
    uniform vec2 zoom;
    uniform vec2 origin;
    uniform vec2 textureSize;
    uniform sampler2D texture;
    uniform sampler2D planeTexture;
    uniform vec2 screenSize;
    const vec3 lumaF = vec3(.299, .587, .114);
    #ifdef GL_ES
    varying vec2 v_factor_npot;
    #else
    const vec2 v_factor_npot = vec2(1.0, 1.0);
    #endif
    void main()
    {
      vec2 screenCoord = gl_TexCoord[0].xy * v_factor_npot * screenSize;
      vec2 rawCoord = origin + screenCoord / zoom;
      if (rawCoord.x < 0.0 || rawCoord.y < 0.0 || rawCoord.x >= textureSize.x || rawCoord.y >= textureSize.y) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
      } else {
        vec2 bmpCoord = rawCoord / textureSize;
        vec4 frag = texture2D(planeTexture, bmpCoord);
        frag.rgb = mix(frag.rgb, color.rgb, color.a);
        float luma = dot(frag.rgb, lumaF);
        frag.rgb += tone.rgb;
        frag.rgb = mix(frag.rgb, vec3(luma), tone.w);
        frag.a *= gl_Color.a;
        gl_FragColor = frag * texture2D(texture, gl_TexCoord[0].xy);
      }
    }
  GLSL
  register(:plane_no_repeat, PLANE_NO_REPEAT_FRAG)
end

# update_fog_sprite_parameters (untouchable) always sends a COMBINED origin:
#   (display_x/8 + fog_ox)/2 , (display_y/8 + fog_oy)/2
# display_x/display_y is the camera-scroll term (moves as the player walks);
# fog_ox/fog_oy is the fog graphic's own SX/SY-driven autonomous term.
# Subtracting the camera term back out here, at set_origin itself (a base
# engine method, not part of the untouchable plugin), leaves only the fog's
# own SX/SY movement:
#   - SX/SY != 0  -> still scrolls at its own speed, no longer pans with the camera
#   - SX/SY == 0  -> fog_ox/fog_oy never change, so after removing the camera
#                    term there's nothing left to move it: fully static
class NoDriftPlane < Plane
  def set_origin(ox, oy)
    corrected_ox = ox - ($game_map.display_x / 16.0)
    corrected_oy = oy - ($game_map.display_y / 16.0)
    super(corrected_ox, corrected_oy)
  end
end
=begin
# Switch 109 ON -> :plane_no_repeat (single instance, no tiling)
# Switch 109 OFF -> :plane (normal tiling/repeating fog)
class Spriteset_Map
  module FogPlugin
    def init_sprites
      super
      @fog = NoDriftPlane.new(@viewport1)
      @fog.shader = Shader.create($game_switches[109] ? :plane_no_repeat : :plane)
      @fog.z = 3000
    end
  end
end
=end