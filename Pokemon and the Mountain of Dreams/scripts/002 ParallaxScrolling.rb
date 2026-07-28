# Adds a toggleable, speed-controllable horizontal auto-scroll to the map panorama.
#
# By default the panorama follows the player (
# see Spriteset_Map::PanoramaPlugin#update_panorama_position). When the loop
# is turned on, the panorama instead scrolls on its own, independent of
# player movement, wrapping seamlessly thanks to Plane's built-in texture tiling.
#
# Usage from an event's "Call Script":
#   $game_map.panorama_auto_scroll = true       # turn the auto-scroll on
#   $game_map.panorama_auto_scroll = false      # back to normal player-following parallax
#   $game_map.panorama_scroll_speed = 2.0       # pixels/frame, tune to taste (default 1.0)
#   $game_map.set_panorama_offset(0, -16)       # manual position nudge, works in EITHER mode
#   $game_map.panorama_offset_x = 32            # same thing, axis by axis
#   $game_map.set_panorama_zoom(2)              # zoom both axes uniformly
#   $game_map.set_panorama_zoom(2, 1)           # zoom x and y independently
#   $game_map.panorama_zoom_x = 1.5             # same thing, axis by axis
#
# Note: the scroll offset is independent from $game_map.display_x, so toggling
# auto-scroll off can cause a visible jump back to the player-following position
# if the two have drifted far apart. Resync @panorama_scroll_offset to
# (display_x / 8) before disabling if you need a seamless handoff (note the
# offset is in raw origin units/pixels, while display_x is still divided by 8
# in the player-following path).
#
# The manual offset (panorama_offset_x/y) is a constant nudge applied on top of
# whichever base position is active (auto-scroll or player-follow). It does not
# accumulate on its own; set it to move the panorama, leave it to hold that shift.
#
# Zoom (panorama_zoom_x/y) maps directly onto Plane#zoom_x=/zoom_y=. Default is 1.0
# (no zoom). Values above 1 zoom in, below 1 zoom out.

# Extends Game_Map with the auto-scroll toggle, speed, offset state, manual nudge, and zoom.
class Game_Map
  # @return [Boolean] whether the panorama is auto-scrolling instead of following the player
  attr_writer :panorama_auto_scroll
  # @return [Float] speed of the auto-scroll, in origin units per frame
  attr_accessor :panorama_scroll_speed
  # @return [Float] current auto-scroll offset
  attr_reader :panorama_scroll_offset
  # @return [Integer] manual horizontal nudge applied on top of the computed position
  attr_accessor :panorama_offset_x
  # @return [Integer] manual vertical nudge applied on top of the computed position
  attr_accessor :panorama_offset_y
  # @return [Float] horizontal zoom factor of the panorama (1.0 = no zoom)
  attr_accessor :panorama_zoom_x
  # @return [Float] vertical zoom factor of the panorama (1.0 = no zoom)
  attr_accessor :panorama_zoom_y

  # @return [Boolean]
  def panorama_auto_scroll?
    @panorama_auto_scroll ||= false
  end

  # Advances the auto-scroll offset by panorama_scroll_speed
  # @return [Integer] the new offset
  def advance_panorama_scroll
    @panorama_scroll_offset = (@panorama_scroll_offset || 0) + (@panorama_scroll_speed || 1)
  end

  # Sets the manual panorama offset in one call
  # @param x [Integer]
  # @param y [Integer]
  def set_panorama_offset(x, y)
    @panorama_offset_x = x
    @panorama_offset_y = y
  end

  # Sets the panorama zoom in one call
  # @param x [Float] horizontal zoom
  # @param y [Float] vertical zoom, defaults to x (uniform zoom)
  def set_panorama_zoom(x, y = x)
    @panorama_zoom_x = x
    @panorama_zoom_y = y
  end

  alias original_setup_panorama_auto_scroll setup
  # Resets the auto-scroll, offset, and zoom state whenever a new map is loaded
  # @param map_id [Integer]
  def setup(map_id)
    original_setup_panorama_auto_scroll(map_id)
    @panorama_auto_scroll = false
    @panorama_scroll_speed = 1.0
    @panorama_scroll_offset = 0.0
    @panorama_offset_x = 0
    @panorama_offset_y = 0
    @panorama_zoom_x = 1.0
    @panorama_zoom_y = 1.0
  end
end

# Plugin overriding panorama positioning when auto-scroll is active, applying
# the manual offset on top regardless of mode, and applying the manual zoom
module PanoramaAutoScrollPlugin
  private

  # Update panorama position: auto-scroll if active, otherwise fall back to
  # the base player-following parallax behavior. Then apply the manual nudge and zoom.
  def update_panorama_position
    if $game_map.panorama_auto_scroll?
      @panorama.set_origin($game_map.advance_panorama_scroll, $game_map.display_y / 8)
    else
      super
    end
    @panorama.set_origin(@panorama.ox + ($game_map.panorama_offset_x || 0), @panorama.oy + ($game_map.panorama_offset_y || 0))
    @panorama.zoom_x = $game_map.panorama_zoom_x || 1.0
    @panorama.zoom_y = $game_map.panorama_zoom_y || 1.0
  end
end
Spriteset_Map.prepend(PanoramaAutoScrollPlugin)