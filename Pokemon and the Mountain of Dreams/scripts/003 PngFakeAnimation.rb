# Makes a folder of PNG frames loop as a fake-gif animation, callable from a
# map event via "Call Script", non-blocking (the map keeps updating normally
# while it plays). Self-contained - no other file needed.
#
# Call from an event's "Call Script" - use $game_map.request_gif_loop, not
# $scene.spriteset.start_gif_loop directly (see the safety note below):
#   $game_map.request_gif_loop('wind_animation', 16, 100)
#   $game_map.request_gif_loop('wind_animation', 16, 100, velocity_x: 1)  # scrolls 1px/frame, off-screen (wrap defaults false)
#   $game_map.request_gif_loop('wind_animation', 16, 100, velocity_x: 1, wrap: true)  # seamless loop instead
#   $game_map.request_gif_loop('wind_animation', 16, 100, zoom_x: 2, zoom_y: 2)
#   $game_map.request_gif_loop('wind_animation', 16, 100, x: 160, y: 80)  # custom position
#   $game_map.request_gif_loop('wind_animation', 16, 100, frame_format: 'frame_%02d')
#   $game_map.request_gif_loop_stop
#
# Once it's running, these adjust it live and are fine to call directly
# (they're for tweaking something already on screen, not starting it):
#   $scene.spriteset.set_gif_loop_position(50, 30)          # move an already-running animation
#   $scene.spriteset.move_gif_loop(10, 0)                   # relative displacement
#   $scene.spriteset.set_gif_loop_zoom(1.5)                 # rezoom an already-running animation
#   $scene.spriteset.set_gif_loop_velocity(1, 0)            # start/change continuous movement
#
# start_gif_loop(folder, frame_count, speed_ms, velocity_x: 0, velocity_y: 0, wrap: false,
#                 zoom_x: 1.0, zoom_y: 1.0, x: 0, y: 0, frame_format: '%02d', id: :default)
#   folder       - subfolder of Graphics/pictures/ containing the frames
#   frame_count  - number of frames
#   speed_ms     - milliseconds each frame is shown (converted internally to
#                  game frames via Graphics.frame_rate, so playback speed is
#                  consistent regardless of the target frame rate)
#   velocity_x/velocity_y - continuous pixels/frame movement, default 0 (still).
#                  This is what gives the "animated panorama" scrolling effect -
#                  set velocity_x: 1 for a steady 1px/frame drift, same idea as
#                  the panorama auto-scroll from earlier, just applied to a
#                  sprite instead of a Plane's tiling shader.
#   wrap         - if true, uses Sprite_GifLoopWrap instead of Sprite_GifLoop:
#                  several copies tile edge-to-edge and snap back once fully
#                  past the viewport, so the animation loops forever in
#                  whichever direction(s) velocity_x/velocity_y point. Default
#                  false, meaning it just scrolls off-screen and stops instead.
#                  Only matters when velocity is nonzero.
#   zoom_x/zoom_y - scale factors, default 1.0 (no zoom)
#   x, y         - screen position, default (0, 0)
#   frame_format - printf-style format (no extension) for each frame's filename,
#                  default '%02d' expects 01.png..NN.png. Examples:
#                    '%d'        -> 1.png, 2.png, ...
#                    'frame_%02d' -> frame_01.png, frame_02.png, ...
#                    'wind_%d'    -> wind_1.png, wind_2.png, ...
#   id           - identifier; lets several animations run at once under
#                  different ids. Starting a new one under an id that's already
#                  running disposes the previous Sprite_GifLoop for that id first.
#
# Render priority (z) isn't an argument here - it's fixed at 10_000 on creation
# so the animation draws above every tile layer regardless of priority/row
# (tile z can reach into the low thousands on tall maps: (row + priority) * 32).
# Use set_gif_loop_z afterward if you need it lower (e.g. behind some tiles/characters).
#
# set_gif_loop_position(x, y, id: :default) / move_gif_loop(dx, dy, id: :default) /
# set_gif_loop_zoom(zoom_x, zoom_y = zoom_x, id: :default) / set_gif_loop_z(z, id: :default)
# all act on an already-running animation without restarting it (no dispose/reload).
#
# IMPORTANT - calling $scene.spriteset directly from an event is only safe once
# the map scene is actually live. Right after loading a save, the event that
# starts the animation can run while $scene is still GamePlay::Load (the save
# screen), which has no #spriteset and raises NoMethodError. Use
# $game_map.request_gif_loop(...) instead - it's always safe to call:
#   $game_map.request_gif_loop('wind_animation', 37, 200, velocity_x: 1, wrap: true)
#   $game_map.request_gif_loop_stop
# It records the request on $game_map (which survives save/load, and is only
# cleared when you actually walk into a different map - not on a same-map
# reload), and applies it immediately if the scene is already live. Whenever
# Spriteset_Map is (re)created - including right after a save loads - it
# replays whatever's still pending, so the animation reliably resumes.

# Sprite that cycles through a folder of PNG frames to fake a looping GIF
# animation. Frames are loaded through RPG::Cache.picture - the same cache
# PSDK uses for the "Show Picture" event command - so they're cached/shared
# rather than reloaded from disk each time.
class Sprite_GifLoop < Sprite
  # @param viewport [Viewport]
  # @param folder [String] subfolder of Graphics/pictures/ containing the frames
  # @param frame_count [Integer] number of frames in the animation
  # @param frame_format [String] printf-style format (no extension) for each
  #   frame's filename relative to folder. Default expects 01.png..NN.png.
  # @param frame_duration [Integer] number of game frames each image is held for
  # @param velocity_x [Numeric] pixels moved horizontally per frame, default 0
  # @param velocity_y [Numeric] pixels moved vertically per frame, default 0
  def initialize(viewport, folder, frame_count, frame_format: '%02d', frame_duration: 4, velocity_x: 0, velocity_y: 0)
    super(viewport)
    @frames = (1..frame_count).map { |i| RPG::Cache.picture(format("#{folder}/#{frame_format}", i)) }
    @frame_duration = frame_duration
    @frame_index = 0
    @frame_counter = 0
    self.bitmap = @frames.first
    @velocity_x = velocity_x
    @velocity_y = velocity_y
  end

  # Continuous per-frame movement, in pixels/frame (can be fractional; Sprite
  # coordinates accept floats). Set to 0 to stop moving on that axis.
  attr_accessor :velocity_x
  attr_accessor :velocity_y

  # Advances the animation by one game frame; called every frame from Spriteset_Map's own update
  def update
    super
    self.x += @velocity_x unless @velocity_x.zero?
    self.y += @velocity_y unless @velocity_y.zero?
    @frame_counter += 1
    return if @frame_counter < @frame_duration

    @frame_counter = 0
    @frame_index = (@frame_index + 1) % @frames.size
    self.bitmap = @frames[@frame_index]
  end
end

# Wraps a grid of Sprite_GifLoop copies behind the same public interface
# (x=, y=, z=, zoom_x=, zoom_y=, velocity_x=, velocity_y=, update, dispose) so
# it's a drop-in replacement for Sprite_GifLoop, adding seamless infinite
# scroll along whichever axes have nonzero velocity. Copies are spaced by the
# frame image's own width/height (so they tile edge to edge) and snap back by
# the total covered distance once they've scrolled fully past the viewport in
# the direction of travel - the classic two-(or more-)copy "conveyor" technique.
#
# Diagonal movement (both velocity_x and velocity_y nonzero) is supported via
# a full grid of copies (columns x rows), so corners stay covered too.
class Sprite_GifLoopWrap
  def initialize(viewport, folder, frame_count, frame_format: '%02d', frame_duration: 4, x: 0, y: 0, z: 0,
                  zoom_x: 1.0, zoom_y: 1.0, velocity_x: 0, velocity_y: 0, wrap_width: nil, wrap_height: nil)
    @velocity_x = velocity_x
    @velocity_y = velocity_y
    probe = RPG::Cache.picture(format("#{folder}/#{frame_format}", 1))
    @wrap_width = wrap_width || probe.width
    @wrap_height = wrap_height || probe.height
    @viewport_width = viewport.rect.width
    @viewport_height = viewport.rect.height
    @cols = velocity_x.zero? ? 1 : ((@viewport_width.to_f / @wrap_width).ceil + 1)
    @rows = velocity_y.zero? ? 1 : ((@viewport_height.to_f / @wrap_height).ceil + 1)
    @copies = Array.new(@cols * @rows) do |k|
      col, row = k % @cols, k / @cols
      s = Sprite_GifLoop.new(viewport, folder, frame_count, frame_format: frame_format, frame_duration: frame_duration,
                              velocity_x: velocity_x, velocity_y: velocity_y)
      s.x = x + col * @wrap_width
      s.y = y + row * @wrap_height
      s.z = z
      s.zoom_x = zoom_x
      s.zoom_y = zoom_y
      s
    end
  end

  # @return [Integer] logical x of the group (top-left copy's position)
  def x
    @copies.first.x
  end

  # Shifts every copy so the group's logical position becomes value, keeping spacing intact
  def x=(value)
    delta = value - x
    @copies.each { |s| s.x += delta } unless delta.zero?
  end

  # @return [Integer] logical y of the group (top-left copy's position)
  def y
    @copies.first.y
  end

  # Shifts every copy so the group's logical position becomes value, keeping spacing intact
  def y=(value)
    delta = value - y
    @copies.each { |s| s.y += delta } unless delta.zero?
  end

  def z=(value)
    @copies.each { |s| s.z = value }
  end

  def zoom_x=(value)
    @copies.each { |s| s.zoom_x = value }
  end

  def zoom_y=(value)
    @copies.each { |s| s.zoom_y = value }
  end

  def velocity_x=(value)
    @velocity_x = value
    @copies.each { |s| s.velocity_x = value }
  end

  def velocity_y=(value)
    @velocity_y = value
    @copies.each { |s| s.velocity_y = value }
  end

  # Advances every copy, then wraps any copy that has scrolled fully past the viewport
  def update
    @copies.each(&:update)
    total_width = @cols * @wrap_width
    total_height = @rows * @wrap_height
    @copies.each do |s|
      s.x -= total_width if s.x > @viewport_width
      s.x += total_width if (s.x + @wrap_width) < 0
      s.y -= total_height if s.y > @viewport_height
      s.y += total_height if (s.y + @wrap_height) < 0
    end
  end

  def dispose
    @copies.each(&:dispose)
  end
end
module GifLoopPlugin
  private

  # Initialize all the spriteset map sprites
  def init_sprites
    super
    @gif_loops = {}
    # Replay any gif loops that were requested and are still pending - covers
    # both a genuine map (re)entry and resuming right after a save load
    ($game_map.gif_loop_requests || {}).each do |id, params|
      params = params.dup
      folder = params.delete(:folder)
      frame_count = params.delete(:frame_count)
      speed_ms = params.delete(:speed_ms)
      start_gif_loop(folder, frame_count, speed_ms, **params, id: id)
    end
  end

  # Dispose all the sprites
  def dispose_sprites
    super
    @gif_loops.each_value(&:dispose)
  end

  # Update all the sprites
  def update_sprites
    super
    @gif_loops.each_value(&:update)
  end

  public

  # Starts (or restarts) a looping fake-gif animation
  # @param folder [String] subfolder of Graphics/pictures/ containing the frames
  # @param frame_count [Integer] number of frames
  # @param speed_ms [Integer] milliseconds each frame is shown
  # @param velocity_x [Numeric] pixels moved horizontally per frame, default 0
  # @param velocity_y [Numeric] pixels moved vertically per frame, default 0
  # @param wrap [Boolean] if true, seamlessly loops instead of scrolling off-screen
  #   (see Sprite_GifLoopWrap); only matters when velocity_x/velocity_y is nonzero. Default false.
  # @param zoom_x [Float] horizontal scale, default 1.0
  # @param zoom_y [Float] vertical scale, default 1.0
  # @param x [Integer] screen x position, default 0
  # @param y [Integer] screen y position, default 0
  # @param frame_format [String] printf-style filename format, default '%02d' (01.png..NN.png)
  # @param id [Symbol] identifier, lets several animations run at once
  def start_gif_loop(folder, frame_count, speed_ms, velocity_x: 0, velocity_y: 0, wrap: false,
                      zoom_x: 1.0, zoom_y: 1.0, x: 0, y: 0, frame_format: '%02d', id: :default)
    @gif_loops[id]&.dispose
    frame_duration = (speed_ms / 1000.0 * Graphics.frame_rate).round.clamp(1, nil)
    klass = wrap ? Sprite_GifLoopWrap : Sprite_GifLoop
    gif = klass.new(@viewport1, folder, frame_count, frame_format: frame_format, frame_duration: frame_duration,
                     velocity_x: velocity_x, velocity_y: velocity_y)
    gif.x = x
    gif.y = y
    gif.z = 10_000
    gif.zoom_x = zoom_x
    gif.zoom_y = zoom_y
    @gif_loops[id] = gif
  end

  # Stops and disposes a running fake-gif animation
  # @param id [Symbol]
  def stop_gif_loop(id: :default)
    @gif_loops[id]&.dispose
    @gif_loops.delete(id)
  end

  # Moves a running fake-gif animation to an absolute position
  # @param x [Integer]
  # @param y [Integer]
  # @param id [Symbol]
  def set_gif_loop_position(x, y, id: :default)
    gif = @gif_loops[id]
    return unless gif

    gif.x = x
    gif.y = y
  end

  # Displaces a running fake-gif animation relative to its current position
  # @param dx [Integer]
  # @param dy [Integer]
  # @param id [Symbol]
  def move_gif_loop(dx, dy, id: :default)
    gif = @gif_loops[id]
    return unless gif

    gif.x += dx
    gif.y += dy
  end

  # Sets the zoom of a running fake-gif animation
  # @param zoom_x [Float]
  # @param zoom_y [Float] defaults to zoom_x (uniform zoom)
  # @param id [Symbol]
  def set_gif_loop_zoom(zoom_x, zoom_y = zoom_x, id: :default)
    gif = @gif_loops[id]
    return unless gif

    gif.zoom_x = zoom_x
    gif.zoom_y = zoom_y
  end

  # Sets the render priority (z) of a running fake-gif animation
  # @param z [Integer]
  # @param id [Symbol]
  def set_gif_loop_z(z, id: :default)
    gif = @gif_loops[id]
    return unless gif

    gif.z = z
  end

  # Sets the continuous per-frame movement of a running fake-gif animation
  # @param velocity_x [Numeric] pixels moved horizontally per frame
  # @param velocity_y [Numeric] pixels moved vertically per frame
  # @param id [Symbol]
  def set_gif_loop_velocity(velocity_x, velocity_y, id: :default)
    gif = @gif_loops[id]
    return unless gif

    gif.velocity_x = velocity_x
    gif.velocity_y = velocity_y
  end
end
Spriteset_Map.prepend(GifLoopPlugin)

# Safe entry point for events: records the request on Game_Map (which is what
# actually gets persisted/restored across a save, not Spriteset_Map, which is
# torn down and recreated on every scene change including a save load) and
# applies it immediately if the scene is already live.
class Game_Map
  # @return [Hash{Symbol => Hash}] pending/active gif loop requests, keyed by id
  attr_reader :gif_loop_requests

  # Requests a looping fake-gif animation. Safe to call at any time, including
  # right after a save loads, before Scene_Map/Spriteset_Map exist yet.
  # Same parameters as Spriteset_Map#start_gif_loop.
  def request_gif_loop(folder, frame_count, speed_ms, velocity_x: 0, velocity_y: 0, wrap: false,
                        zoom_x: 1.0, zoom_y: 1.0, x: 0, y: 0, frame_format: '%02d', id: :default)
    @gif_loop_requests ||= {}
    params = {folder: folder, frame_count: frame_count, speed_ms: speed_ms, velocity_x: velocity_x, velocity_y: velocity_y,
              wrap: wrap, zoom_x: zoom_x, zoom_y: zoom_y, x: x, y: y, frame_format: frame_format}
    @gif_loop_requests[id] = params
    return unless $scene.respond_to?(:spriteset)

    $scene.spriteset.start_gif_loop(folder, frame_count, speed_ms, velocity_x: velocity_x, velocity_y: velocity_y, wrap: wrap,
                                     zoom_x: zoom_x, zoom_y: zoom_y, x: x, y: y, frame_format: frame_format, id: id)
  end

  # Requests a running fake-gif animation to stop. Safe to call at any time.
  # @param id [Symbol]
  def request_gif_loop_stop(id: :default)
    @gif_loop_requests ||= {}
    @gif_loop_requests.delete(id)
    $scene.spriteset.stop_gif_loop(id: id) if $scene.respond_to?(:spriteset)
  end

  alias original_setup_gif_loop_requests setup
  # Resets pending gif loop requests only when actually entering a different
  # map. Setup also runs when resuming a save on the SAME map
  # ($game_map.setup($game_map.map_id) in the load flow) - in that case the
  # requests must survive so init_sprites can replay them.
  # @param map_id [Integer]
  def setup(map_id)
    same_map = (@map_id == map_id)
    original_setup_gif_loop_requests(map_id)
    @gif_loop_requests = {} unless same_map
    @gif_loop_requests ||= {}
  end
end