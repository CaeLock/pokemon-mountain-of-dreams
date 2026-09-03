module BattleUI
  # Rising particles of the Boss aura, ported from the charged particles of Elite Battle DX.
  class BossAuraEmitter
    Shader.register(:boss_aura_recolor, 'graphics/shaders/boss_aura_recolor.frag')
    Shader.register(:boss_aura_recolor_3d, 'graphics/shaders/boss_aura_recolor.frag', 'graphics/shaders/fake_3d.vert')

    # One size family of flames, the large slow ones carrying the shape and the small fast ones the light
    Family = Struct.new(:zoom_ratio, :growth_ratio, :lifetime_min, :lifetime_max, :additive_share, :share)
    # Everything one particle owns, so that no two of them ever run in step
    Particle = Struct.new(:sprite, :family, :age, :lifetime, :resting, :birth_x, :birth_y,
                          :birth_zoom_y, :birth_opacity, :drift_phase, :drift_amplitude)

    # The three families, from the large slow flames to the small fast ones
    FAMILIES = [
      Family.new(1.25, 0.7, 0.55, 0.80, 0.0, 3),
      Family.new(0.85, 1.0, 0.35, 0.60, 0.5, 6),
      Family.new(0.50, 1.4, 0.25, 0.45, 1.0, 8)
    ]
    # Bitmap pixels of body one particle stands for, the density the count is derived from
    AREA_PER_PARTICLE = 150
    # Fewest particles, however small the Pokemon
    MIN_COUNT = 8
    # Most particles, however large the Pokemon
    MAX_COUNT = 24
    # Number of frames held by the particle sheet
    NB_FRAMES = 4
    # Vertical zoom gained per second, relative to the vertical zoom of the sprite
    GROWTH_PER_SECOND = 4.0
    # Lowest opacity a particle spawns with
    MIN_OPACITY = 166
    # Width of the opacity range a particle spawns with
    OPACITY_RANGE = 90
    # Period of the breath gathering the flames into waves, in seconds
    PUFF_PERIOD = 2.0
    # Shortest rest a dead particle takes, at the top of the breath
    PUFF_MIN_REST = 0.02
    # Longest rest a dead particle takes, at the bottom of the breath
    PUFF_MAX_REST = 0.45
    # Radians per second the lateral drift of a particle runs at
    DRIFT_SPEED = 4.0
    # Narrowest lateral drift of a particle, in pixels
    DRIFT_MIN_AMPLITUDE = 1.0
    # Widest lateral drift of a particle, in pixels
    DRIFT_MAX_AMPLITUDE = 3.0
    # Ratio of the sprite height a particle can spawn in, when the body of the Pokemon is unknown
    SPAWN_HEIGHT_RATIO = 0.8
    # Ratio of the sprite origin the spawn band starts at, when the body of the Pokemon is unknown
    SPAWN_ORIGIN_RATIO = 0.7
    # Ratio of the body width the spawn band is wide, the frame to body relation of the source
    SPAWN_BODY_WIDTH_RATIO = 1.245
    # Ratio of the body height the top of the spawn band sits above the feet of the Pokemon
    SPAWN_BODY_TOP_RATIO = 0.888
    # Ratio of the body height the spawn band is tall
    SPAWN_BODY_HEIGHT_RATIO = 1.015
    # Half of what the source envelope adds to the body width, spread on both sides of a spawn spot
    SPAWN_SPILL_WIDTH_RATIO = (SPAWN_BODY_WIDTH_RATIO - 1) / 2
    # How far below the feet the source envelope hangs, the spawn spots spilling down by as much
    SPAWN_SPILL_BOTTOM_RATIO = SPAWN_BODY_HEIGHT_RATIO - SPAWN_BODY_TOP_RATIO
    # Vertical zoom a particle spawns with, relative to the vertical zoom of the sprite
    INITIAL_ZOOM_RATIO = 0.6
    # Blend type of an additive shader, the value the engine writes for its own additive cells
    ADDITIVE_BLEND = 1
    # Name of the particle sheet inside the animation cache
    SHEET = 'boss-aura/aura_particle'

    # Create a new emitter
    # @param viewport [Viewport]
    # @param sprite [BattleUI::PokemonSprite] sprite the particles turn around
    # @param scene [Battle::Scene] scene holding the 3D pass the particles join
    # @param style [Symbol, Boolean, nil] aura style driving the color of the flames
    def initialize(viewport, sprite, scene, style)
      @viewport = viewport
      @sprite = sprite
      @scene = scene
      @style = style
      @color = BossAuraColors.resolve_floats(style) + [1.0]
      @visible = true
      @elapsed = 0
      @last_time = Graphics.current_time
      @body_shape = BossAuraBodyShape.for(sprite)
      @particles = create_particles
      @pending_3d = Battle::BATTLE_CAMERA_3D
    end

    # Update every particle
    def update
      join_3d_pass
      now = Graphics.current_time
      delta = now - @last_time
      @last_time = now
      @elapsed += delta
      @particles.each { |particle| update_particle(particle, delta) }
    end

    # Set the visibility of every particle
    # @param visible [Boolean]
    def visible=(visible)
      @visible = visible
      @particles.each { |particle| particle.sprite.visible = visible && particle.resting <= 0 }
    end

    # Move every particle along the sprite depth
    # @param z [Numeric]
    def z=(z)
      @particles.each_with_index { |particle, index| particle.sprite.z = z + (index.even? ? 1 : -1) }
      return unless Battle::BATTLE_CAMERA_3D

      @particles.each { |particle| particle.sprite.shader.set_float_uniform('z', @sprite.shader_z_position) }
    end

    # Dispose every particle
    def dispose
      @particles.each { |particle| particle.sprite.dispose }
      @particles.clear
    end

    private

    # Join the 3D pass, put off to the first update because the visual is not built yet when a
    # sprite lights its aura while the scene is being set up
    def join_3d_pass
      return unless @pending_3d

      @pending_3d = false
      @particles.each { |particle| @scene.visual.sprites3D.append(particle.sprite) }
    end

    # Build the whole swarm, each family taking its share of a count the body decides
    # @return [Array<Particle>]
    def create_particles
      particles = []
      family_counts.each_with_index do |count, index|
        count.times { particles << create_particle(FAMILIES[index]) }
      end
      return particles
    end

    # How many particles each family gets
    # @return [Array<Integer>]
    def family_counts
      total = total_count
      shares = FAMILIES.map(&:share)
      counts = shares.map { |share| (total * share.to_f / shares.sum).round }
      # What the rounding left over goes to the small ones, so the total is exactly the one asked for
      counts[-1] += total - counts.sum
      return counts
    end

    # Number of particles the body of this Pokemon carries, from its area and inside the bounds
    # @return [Integer]
    def total_count
      return MIN_COUNT unless @body_shape

      return (@body_shape.width * @body_shape.height / AREA_PER_PARTICLE).clamp(MIN_COUNT, MAX_COUNT)
    end

    # Create one particle of a family and start it somewhere in the middle of its own cycle
    # @param family [Family]
    # @return [Particle]
    def create_particle(family)
      sprite = SpriteSheet.new(@viewport, NB_FRAMES, 1)
      sprite.bitmap = RPG::Cache.animation(SHEET)
      sprite.set_origin(sprite.width / 2, sprite.height)
      sprite.opacity = 0
      sprite.visible = false
      apply_particle_shader(sprite, additive?(family))
      particle = Particle.new(sprite, family, 0, 0, 0, 0, 0, 0, 0, 0, 0)
      spawn(particle)
      # A random age spreads the swarm over its cycles from the very first frame
      particle.age = rand * particle.lifetime
      return particle
    end

    # Tell whether a particle of a family burns in additive blending
    # @param family [Family]
    # @return [Boolean]
    def additive?(family)
      return rand < family.additive_share
    end

    # Dress a particle with the shader its situation calls for, and feed that shader
    # @param sprite [SpriteSheet]
    # @param additive [Boolean]
    def apply_particle_shader(sprite, additive)
      name = particle_shader_name(additive)
      return unless name

      sprite.shader = Shader.create(name)
      sprite.shader.set_float_uniform('auraColor', @color) if recolored?
      sprite.shader.set_float_uniform('z', @sprite.shader_z_position) if Battle::BATTLE_CAMERA_3D
      # Last of all, since a sprite carries no blend type of its own, only the shader in place does
      sprite.shader.blend_type = ADDITIVE_BLEND if additive
    end

    # Shader a particle wears: the recolor one when the aura has a color of its own, the camera
    # projection when the battle is in 3D, and the neutral one of the engine when only the blending
    # needs a shader to sit on
    # @param additive [Boolean]
    # @return [Symbol, nil]
    def particle_shader_name(additive)
      return :boss_aura_recolor_3d if Battle::BATTLE_CAMERA_3D && recolored?
      return :fake_3d if Battle::BATTLE_CAMERA_3D
      return :boss_aura_recolor if recolored?
      return :color_shader if additive

      return nil
    end

    # Tell whether the flames need recoloring, the default crimson being the color of the sheet itself
    # @return [Boolean]
    def recolored?
      return BossAuraColors.resolve(@style) != BossAuraColors::DEFAULT
    end

    # Update one particle, resting it once its life is over and bringing it back when the breath allows
    # @param particle [Particle]
    # @param delta [Float] seconds elapsed since the last update
    def update_particle(particle, delta)
      return wait_out_rest(particle, delta) if particle.resting.positive?

      particle.age += delta
      return start_rest(particle) if particle.age >= particle.lifetime

      draw_particle(particle)
    end

    # Count the rest of a dead particle down, giving it a new life once the wait is over
    # @param particle [Particle]
    # @param delta [Float] seconds elapsed since the last update
    def wait_out_rest(particle, delta)
      particle.resting -= delta
      particle.sprite.visible = false
      return if particle.resting.positive?

      spawn(particle)
      draw_particle(particle)
    end

    # Send a dead particle to rest, briefly at the top of the breath and at length at its bottom
    # @param particle [Particle]
    def start_rest(particle)
      particle.resting = rest_duration
      particle.sprite.visible = false
    end

    # How long a particle rests before coming back, the breath gathering the flames into waves
    # @return [Float]
    def rest_duration
      breath = (Math.sin(2 * Math::PI * @elapsed / PUFF_PERIOD) + 1) / 2
      return PUFF_MAX_REST - ((PUFF_MAX_REST - PUFF_MIN_REST) * breath)
    end

    # Give a particle a whole new life, nothing of the previous one being kept
    # @param particle [Particle]
    def spawn(particle)
      family = particle.family
      zoom_x = @sprite.zoom_x
      zoom_y = @sprite.zoom_y
      particle.age = 0
      particle.resting = 0
      particle.lifetime = family.lifetime_min + (rand * (family.lifetime_max - family.lifetime_min))
      particle.birth_x, particle.birth_y = spawn_position(zoom_x, zoom_y)
      particle.birth_zoom_y = INITIAL_ZOOM_RATIO * BossAuraColors::SCREEN_SCALE * zoom_y * family.zoom_ratio
      particle.birth_opacity = MIN_OPACITY + rand(OPACITY_RANGE)
      particle.drift_phase = rand * 2 * Math::PI
      particle.drift_amplitude = DRIFT_MIN_AMPLITUDE + (rand * (DRIFT_MAX_AMPLITUDE - DRIFT_MIN_AMPLITUDE))
      particle.sprite.select(rand(NB_FRAMES), 0)
      particle.sprite.zoom_x = BossAuraColors::SCREEN_SCALE * zoom_x * family.zoom_ratio
      particle.sprite.mirror = rand < 0.5
    end

    # Place a particle where its own age says it should be
    # @param particle [Particle]
    def draw_particle(particle)
      drift = Math.sin(particle.drift_phase + (particle.age * DRIFT_SPEED)) * particle.drift_amplitude
      particle.sprite.set_position(particle.birth_x + drift, particle.birth_y)
      particle.sprite.zoom_y = particle.birth_zoom_y + (GROWTH_PER_SECOND * BossAuraColors::SCREEN_SCALE *
                               @sprite.zoom_y * particle.family.growth_ratio * particle.age)
      particle.sprite.opacity = particle.birth_opacity * (1 - (particle.age / particle.lifetime))
      particle.sprite.visible = @visible && @sprite.visible
    end

    # Draw the spot a particle spawns at
    # @param zoom_x [Float]
    # @param zoom_y [Float]
    # @return [Array(Float, Float)]
    def spawn_position(zoom_x, zoom_y)
      return canvas_spawn_position(zoom_x, zoom_y) unless @body_shape
      return body_spawn_position(zoom_x, zoom_y) unless @body_shape.mask_cells

      return silhouette_spawn_position(zoom_x, zoom_y)
    end

    # Draw a spot on the silhouette of the Pokemon, then let it spill around the way the envelope of
    # the source spreads past the body
    # @param zoom_x [Float]
    # @param zoom_y [Float]
    # @return [Array(Float, Float)]
    def silhouette_spawn_position(zoom_x, zoom_y)
      bitmap_x, bitmap_y = silhouette_sample
      x = @sprite.x + ((bitmap_x - @sprite.ox) * zoom_x)
      y = @sprite.y + ((bitmap_y - @sprite.oy) * zoom_y)
      return x + spill_x(zoom_x), y + spill_y(zoom_y)
    end

    # Draw a point inside one of the cells the silhouette fills, in bitmap pixels
    # @return [Array(Float, Float)]
    def silhouette_sample
      cell = @body_shape.mask_cells.sample
      column = cell % @body_shape.mask_columns
      row = cell / @body_shape.mask_columns
      cell_size = BossAuraBodyShape::MASK_CELL_SIZE
      return (column * cell_size) + (rand * cell_size), (row * cell_size) + (rand * cell_size)
    end

    # Sideways spill, half of what the source envelope adds to the body width on each side
    # @param zoom_x [Float]
    # @return [Float]
    def spill_x(zoom_x)
      return ((rand * 2) - 1) * SPAWN_SPILL_WIDTH_RATIO * @body_shape.width * zoom_x
    end

    # Downward spill, the source envelope hanging below the feet and never above the head
    # @param zoom_y [Float]
    # @return [Float]
    def spill_y(zoom_y)
      return rand * SPAWN_SPILL_BOTTOM_RATIO * @body_shape.height * zoom_y
    end

    # Draw a spot over the box of the body, the way the tightly cropped frames of the source do
    # @param zoom_x [Float]
    # @param zoom_y [Float]
    # @return [Array(Float, Float)]
    def body_spawn_position(zoom_x, zoom_y)
      center_x = @sprite.x + ((@body_shape.x + (@body_shape.width / 2.0) - @sprite.ox) * zoom_x)
      feet_y = @sprite.y + ((@body_shape.y + @body_shape.height - @sprite.oy) * zoom_y)
      width = SPAWN_BODY_WIDTH_RATIO * @body_shape.width * zoom_x
      height = SPAWN_BODY_HEIGHT_RATIO * @body_shape.height * zoom_y
      top = feet_y - (SPAWN_BODY_TOP_RATIO * @body_shape.height * zoom_y)
      return center_x - (width / 2) + (rand * width), top + (rand * height)
    end

    # Draw a spot over the whole canvas, what the emitter falls back to when no body box is known
    # @param zoom_x [Float]
    # @param zoom_y [Float]
    # @return [Array(Float, Float)]
    def canvas_spawn_position(zoom_x, zoom_y)
      x = @sprite.x - (@sprite.ox * zoom_x) + (rand * @sprite.bitmap.width * zoom_x)
      y = @sprite.y - (@sprite.oy * SPAWN_ORIGIN_RATIO * zoom_y) + (rand * @sprite.bitmap.height * SPAWN_HEIGHT_RATIO * zoom_y)
      return x, y
    end
  end
end
