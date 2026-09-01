module UI
  # Entrance animation of a Boss aura, ported from the AURAFLARE common animation of Elite Battle DX.
  class BossAuraFlare < SpriteStack
    # Blend type of an additive shader, the value the engine writes for its own additive cells
    ADDITIVE_BLEND = 1
    # How much of its opacity an additive sprite gives up on a pale aura, whose light blows out first
    LIGHT_DAMPING = 0.35
    # Pitch of the sound opening the charge
    HARDEN_PITCH = 100
    # Pitch of the second sound, the charge tightening
    TWINE_PITCH = 112
    # Pitch of the third, right before everything stops
    REFRESH_PITCH = 125
    # Sound of the impact, the sound that opens the charge played far below itself: of the three the
    # plugin owns it is the only one with a real transient, 12 ms to full level, and the only one
    # whose energy is front loaded, which is what an impact is made of
    IMPACT_SE = 'boss-aura/anim_harden'
    # Volume of the impact sound
    IMPACT_SE_VOLUME = 110
    # Pitch of the impact sound, low enough to land as a blow and not as the shimmer it is up high
    IMPACT_SE_PITCH = 55
    # Turns the impact sprite makes over the whole time it is on screen
    IMPACT_TURNS = 1.5
    # Opacity the ghost double rests at between two beats
    GHOST_BASE_OPACITY = 90
    # Opacity the ghost double reaches on a beat
    GHOST_PEAK_OPACITY = 200
    # Zoom the ghost double starts the charge at, relative to the battler
    GHOST_START_ZOOM = 1.0
    # Zoom the ghost double reaches at the end of the charge, relative to the battler
    GHOST_FINAL_ZOOM = 1.18
    # Extra zoom a beat swells the ghost double by
    GHOST_BEAT_SWELL = 0.05
    # Duration of one heartbeat of the ghost double in seconds, an effect of ours and not a ported cadence
    GHOST_BEAT_PERIOD = 0.6
    # Share of the period one beat lasts
    GHOST_BEAT_SHARE = 0.16
    # Share of the period the two beats rest between them, so the dip is felt and not just crossed
    GHOST_BEAT_GAP = 0.07
    # Share of the first beat the second one reaches
    GHOST_SECOND_BEAT_RATIO = 0.65
    # Share of a beat spent rising, the rest being the fall
    GHOST_BEAT_ATTACK = 0.35

    # Duration of one source frame in seconds. Every duration below is a source frame count times
    # this one, so the whole flare follows the cadence EBDX actually runs at today, 60 frames per
    # second on a modern Essentials. Put 1.0 / 40 back here to return to the authoring cadence.
    SOURCE_FRAME_DURATION = 1.0 / 60
    # Ratio of our screen to the one the source was drawn for, defined once for the whole port
    SCREEN_SCALE = BattleUI::BossAuraColors::SCREEN_SCALE
    # Duration of the opening wait in seconds, 16 source frames
    OPENING_DURATION = 16 * SOURCE_FRAME_DURATION
    # Duration of the charge in seconds, 104 source frames
    CHARGE_DURATION = 104 * SOURCE_FRAME_DURATION
    # Duration of the impact in seconds, 24 source frames
    IMPACT_DURATION = 24 * SOURCE_FRAME_DURATION
    # Silence held between the charge and the impact, six source frames of nothing at all
    SILENCE_DURATION = 6 * SOURCE_FRAME_DURATION
    # Duration of the fall off in seconds, 16 source frames
    FALL_OFF_DURATION = 16 * SOURCE_FRAME_DURATION
    # Time the target takes to reach its full tint in seconds, the whole charge rather than a third of it
    TINT_DURATION = 104 * SOURCE_FRAME_DURATION
    # Highest alpha the target tint reaches
    TINT_ALPHA = 1.0
    # Time the second sound of the charge plays at, source frame 40
    TWINE_SE_DELAY = 40 * SOURCE_FRAME_DURATION
    # Time the third sound of the charge plays at, source frame 56
    REFRESH_SE_DELAY = 56 * SOURCE_FRAME_DURATION
    # Number of spark sprites, sized so the last one still appears before the spawn window closes
    NB_SPARKS = 9
    # Delay between the first appearance of two sparks in seconds, 8 source frames
    SPARK_DELAY = 8 * SOURCE_FRAME_DURATION
    # Lifetime of a spark in seconds, 16 source frames
    SPARK_LIFETIME = 16 * SOURCE_FRAME_DURATION
    # Time after which a spark that faded out does not appear again, source frame 72
    SPARK_WINDOW = 72 * SOURCE_FRAME_DURATION
    # Radius of the disc the sparks spawn in, relative to the horizontal zoom of the target
    SPARK_RADIUS = 96 * SCREEN_SCALE
    # Share of the distance left a spark covers per source frame
    SPARK_CONVERGENCE_RATE = 0.1
    # Time distortion of the spark convergence, slowing the spark down as it nears the target
    SPARK_CONVERGENCE = proc { |progress| 1 - ((1 - SPARK_CONVERGENCE_RATE)**(progress * SPARK_LIFETIME / SOURCE_FRAME_DURATION)) }
    # Number of ray sprites, sized so the last one still appears before the spawn window closes
    NB_RAYS = 6
    # Delay between the first appearance of two rays in seconds, 16 source frames
    RAY_DELAY = 16 * SOURCE_FRAME_DURATION
    # Lifetime of a ray in seconds, 64 source frames
    RAY_LIFETIME = 64 * SOURCE_FRAME_DURATION
    # Time after which a ray that faded out does not appear again, source frame 96
    RAY_WINDOW = 96 * SOURCE_FRAME_DURATION
    # Zoom a ray reaches at the end of its life
    RAY_FINAL_ZOOM = 3.2 * SCREEN_SCALE
    # Angle between two rays in degrees
    RAY_ANGLE_STEP = 45
    # Angle the first ray is offset by, in degrees
    RAY_ANGLE_OFFSET = 15
    # Number of ripples
    NB_RIPPLES = 3
    # Time the first ripple starts at, source frame 32
    RIPPLE_START = 32 * SOURCE_FRAME_DURATION
    # Delay between two ripples in seconds, 12 source frames
    RIPPLE_DELAY = 12 * SOURCE_FRAME_DURATION
    # Zoom a ripple starts at, relative to the horizontal zoom of the target
    RIPPLE_START_ZOOM = 2.0 * SCREEN_SCALE
    # Lifetime of a ripple in seconds, the 40 source frames its zoom takes to reach zero
    RIPPLE_LIFETIME = 40 * SOURCE_FRAME_DURATION
    # Time a ripple takes to reach its highest opacity, the 9 source frames its zoom takes to cross the fade threshold
    RIPPLE_GROWTH_DURATION = 9 * SOURCE_FRAME_DURATION
    # Highest opacity a ripple reaches
    RIPPLE_PEAK_OPACITY = 144
    # Opacity a ripple still has when its zoom reaches zero
    RIPPLE_END_OPACITY = 45
    # Share of the image color the aura color replaces on the rays and the ripples, full the way the source tints them
    COLOR_ALPHA = 1.0
    # Half period of the impact spin in seconds, 4 source frames
    IMPACT_SPIN_PERIOD = 4 * SOURCE_FRAME_DURATION
    # Pixels the scene moves per source frame during the impact, the two of the source brought to our screen
    SHAKE_STEP = 1.25
    # Number of source frames the shake keeps the same direction
    SHAKE_HALF_PERIOD_FRAMES = 4

    # Create a new flare
    # @param viewport [Viewport]
    # @param scene [Battle::Scene]
    # @param target [PFM::PokemonBattler]
    # @param target_sprite [BattleUI::PokemonSprite]
    # @param style [Symbol, Boolean, nil] aura style driving the color
    def initialize(viewport, scene, target, target_sprite, style)
      super(viewport)
      @scene = scene
      @target = target
      @target_sprite = target_sprite
      @style = style
      @color = BattleUI::BossAuraColors.resolve_floats(style) + [COLOR_ALPHA]
      @light_damping = light_damping_of(@color)
      @default_cache = :animation
      @disposed = false
      @info_bars_hidden = false
      @tone_handed_over = false
      @viewport_color = [viewport.color.red, viewport.color.green, viewport.color.blue, viewport.color.alpha]
      # The source reads the horizontal zoom of the target once and scales the whole flare with it
      @zoom_factor = target_sprite.zoom_x
      @center_x = target_sprite.x
      @center_y = target_sprite.y - (target_sprite.oy * target_sprite.zoom_y / 2)
      @sparks = Array.new(NB_SPARKS) { |index| create_spark(index) }
      @rays = Array.new(NB_RAYS) { create_ray }
      @ripples = Array.new(NB_RIPPLES) { create_ripple }
      @ghost = create_ghost
      @impact = create_impact
    end

    # Build the whole flare
    # @return [Yuki::Animation::Player]
    def flare_animation
      ya = Yuki::Animation
      return ya.player(
        opening_animation,
        charge_animation,
        silence_animation,
        impact_animation,
        fall_off_animation
      )
    end

    # Dispose the sprites, undoing whatever the flare put on the scene and did not give back yet
    def dispose
      return if @disposed

      @disposed = true
      @scene.visual.restore_shake_origins
      @viewport.color.set(*@viewport_color)
      show_info_bars
      release_target_tone
      super
    end

    private

    # Hide the info bars and let the camera reach the target
    # @return [Yuki::Animation::Player]
    def opening_animation
      ya = Yuki::Animation
      return ya.player(
        ya.send_command_to(self, :hide_info_bars),
        ya.send_command_to(self, :center_camera_on_target),
        ya.wait(OPENING_DURATION)
      )
    end

    # Push the camera onto the target, a no operation when the battle camera is flat
    def center_camera_on_target
      return unless Battle::BATTLE_CAMERA_3D

      @scene.visual.center_target(@target.bank, @target.position)
    end

    # Paint the target, play the sounds and run the three sprite families
    # @return [Yuki::Animation::Player]
    def charge_animation
      ya = Yuki::Animation
      return ya.parallel(
        tint_animation,
        ya.se_play('boss-aura/anim_harden', 100, HARDEN_PITCH),
        ya.player(ya.wait(TWINE_SE_DELAY), ya.se_play('boss-aura/anim_twine', 80, TWINE_PITCH)),
        ya.player(ya.wait(REFRESH_SE_DELAY), ya.se_play('boss-aura/anim_refresh', 100, REFRESH_PITCH)),
        *sparks_animations,
        *rays_animations,
        *ripples_animations,
        ghost_animation,
        ya.player(ya.wait(CHARGE_DURATION), ya.send_command_to(self, :hide_charge_sprites))
      )
    end

    # Paint the target with the aura color
    # @return [Yuki::Animation::TimedAnimation]
    def tint_animation
      red, green, blue = BattleUI::BossAuraColors.resolve_floats(@style)
      updater = proc { |alpha| @target_sprite.set_tone_to(red, green, blue, alpha) }
      return Yuki::Animation.scalar(TINT_DURATION, updater, :call, 0, TINT_ALPHA)
    end

    # One animation per spark, each entering after the previous one then appearing again as soon as it faded out
    # @return [Array<Yuki::Animation::Player>]
    def sparks_animations
      ya = Yuki::Animation
      return @sparks.each_with_index.map do |spark, index|
        start = index * SPARK_DELAY
        ya.player(ya.wait(start), *Array.new(spark_nb_lives(start)) { spark_life_animation(spark) })
      end
    end

    # Number of times a spark appears before the spawn window closes
    # @param start [Float] time the spark first appears at, in seconds
    # @return [Integer]
    def spark_nb_lives(start)
      return 0 if start >= SPARK_WINDOW

      return ((SPARK_WINDOW - start) / SPARK_LIFETIME).ceil
    end

    # One appearance of a spark, spawning it anywhere in the disc around the target then converging
    # @param spark [Sprite]
    # @return [Yuki::Animation::Player]
    def spark_life_animation(spark)
      ya = Yuki::Animation
      angle = rand * 2 * Math::PI
      distance = rand * SPARK_RADIUS * @zoom_factor
      x = @center_x + (Math.cos(angle) * distance)
      y = @center_y + (Math.sin(angle) * distance)
      return ya.player(
        ya.send_command_to(spark, :set_position, x, y),
        ya.send_command_to(spark, :opacity=, 255 * @light_damping),
        ya.parallel(
          ya.move(SPARK_LIFETIME, spark, x, y, @center_x, @center_y, distortion: SPARK_CONVERGENCE),
          ya.opacity_change(SPARK_LIFETIME, spark, 255 * @light_damping, 0)
        )
      )
    end

    # One animation per ray, appearing again as soon as it faded out, at an angle drawn among the ones spread around the target
    # @return [Array<Yuki::Animation::Player>]
    def rays_animations
      ya = Yuki::Animation
      angles = (360 / RAY_ANGLE_STEP).times.map { |index| (RAY_ANGLE_STEP * index) + RAY_ANGLE_OFFSET }.shuffle
      return @rays.each_with_index.map do |ray, index|
        starts = ray_life_starts(index * RAY_DELAY)
        ya.player(
          ya.wait(starts.first),
          ya.send_command_to(ray, :angle=, angles[index]),
          *starts.map { |start| ray_life_animation(ray, start) }
        )
      end
    end

    # Times a ray appears at, the source giving it a new life as soon as it faded out
    # @param first_start [Float] time the ray first appears at, in seconds
    # @return [Array<Float>]
    def ray_life_starts(first_start)
      starts = []
      start = first_start
      while start < RAY_WINDOW
        starts << start
        start += RAY_LIFETIME
      end
      return starts
    end

    # One appearance of a ray, growing and fading at once
    # @param ray [Sprite]
    # @param start [Float] time the appearance begins at, in seconds
    # @return [Yuki::Animation::Player]
    def ray_life_animation(ray, start)
      ya = Yuki::Animation
      # The source destroys every ray still alive when the charge ends, so the last ones play a fraction of their life
      played_duration = [[RAY_LIFETIME, CHARGE_DURATION - start].min, 0].max
      fraction = played_duration / RAY_LIFETIME
      return ya.player(
        ya.send_command_to(ray, :opacity=, 255),
        ya.parallel(
          ya.scalar(played_duration, ray, :zoom=, 0, RAY_FINAL_ZOOM * fraction),
          ya.opacity_change(played_duration, ray, 255, 255 * (1 - fraction))
        )
      )
    end

    # One animation per ripple, each contracting until it vanishes, its opacity turning back down on the way
    # @return [Array<Yuki::Animation::Player>]
    def ripples_animations
      ya = Yuki::Animation
      fade_duration = RIPPLE_LIFETIME - RIPPLE_GROWTH_DURATION
      return @ripples.each_with_index.map do |ripple, index|
        start = RIPPLE_START + (index * RIPPLE_DELAY)
        ya.player(
          ya.wait(start),
          ya.parallel(
            ya.scalar(RIPPLE_LIFETIME, ripple, :zoom=, RIPPLE_START_ZOOM * @zoom_factor, 0),
            ya.player(
              ya.opacity_change(RIPPLE_GROWTH_DURATION, ripple, 0, RIPPLE_PEAK_OPACITY),
              ya.opacity_change(fade_duration, ripple, RIPPLE_PEAK_OPACITY, RIPPLE_END_OPACITY)
            )
          )
        )
      end
    end

    # The ghost double breathing through the charge
    # @return [Yuki::Animation::TimedAnimation]
    def ghost_animation
      updater = proc { |progress| update_ghost(progress) }
      return Yuki::Animation.scalar(CHARGE_DURATION, updater, :call, 0, 1)
    end

    # Follow the battler, beat, and grow a little over the charge
    # @param progress [Float] progression of the charge, from 0 to 1
    def update_ghost(progress)
      beat = heartbeat((progress * CHARGE_DURATION / GHOST_BEAT_PERIOD) % 1)
      zoom = GHOST_START_ZOOM + ((GHOST_FINAL_ZOOM - GHOST_START_ZOOM) * progress) + (GHOST_BEAT_SWELL * beat)
      # The battler animates its own transformations, so they are copied at every frame and not once
      @ghost.set_position(@target_sprite.x, @target_sprite.y)
      @ghost.zoom_x = @target_sprite.zoom_x * zoom
      @ghost.zoom_y = @target_sprite.zoom_y * zoom
      @ghost.opacity = GHOST_BASE_OPACITY + ((GHOST_PEAK_OPACITY - GHOST_BASE_OPACITY) * beat)
    end

    # Heartbeat of the ghost double, a beat, a weaker one right behind it, then a rest
    # @param phase [Float] position inside one period, from 0 to 1
    # @return [Float] from 0 to 1
    def heartbeat(phase)
      return beat_shape(phase / GHOST_BEAT_SHARE) if phase < GHOST_BEAT_SHARE
      return 0.0 if phase < GHOST_BEAT_SHARE + GHOST_BEAT_GAP

      second = (phase - GHOST_BEAT_SHARE - GHOST_BEAT_GAP) / GHOST_BEAT_SHARE
      return GHOST_SECOND_BEAT_RATIO * beat_shape(second) if second < 1

      return 0.0
    end

    # Rise then fall of a single beat
    # @param progress [Float] position inside the beat, from 0 to 1
    # @return [Float] from 0 to 1
    def beat_shape(progress)
      return progress / GHOST_BEAT_ATTACK if progress < GHOST_BEAT_ATTACK

      return (1 - progress) / (1 - GHOST_BEAT_ATTACK)
    end

    # Put the ghost double out, the impact taking the stage
    def hide_ghost
      @ghost.opacity = 0
    end

    # Create the ghost double, an additive copy of the battler sprite painted in the aura color
    # @return [Sprite::WithColor]
    def create_ghost
      sprite = add_sprite(@target_sprite.x, @target_sprite.y, nil, type: Sprite::WithColor)
      sprite.bitmap = @target_sprite.bitmap
      sprite.set_origin(@target_sprite.ox, @target_sprite.oy)
      sprite.opacity = 0
      sprite.set_color(@color)
      # Just under the battler, so the battler stays sharp and the ghost only shows past its edges
      sprite.z = @target_sprite.z - 1
      apply_3d_settings_keeping_color(sprite)
      burn(sprite)
      return sprite
    end

    # Cut everything off and hold a beat of silence, so the impact lands on nothing
    # @return [Yuki::Animation::Player]
    def silence_animation
      ya = Yuki::Animation
      return ya.player(
        ya.send_command_to(Audio, :se_stop),
        ya.wait(SILENCE_DURATION)
      )
    end

    # Flash, shake, cry, and hand the scene over to the persistent aura
    # @return [Yuki::Animation::Player]
    def impact_animation
      ya = Yuki::Animation
      return ya.parallel(
        ya.se_play(IMPACT_SE, IMPACT_SE_VOLUME, IMPACT_SE_PITCH),
        ya.send_command_to(self, :hide_ghost),
        ya.send_command_to(self, :hand_over_to_aura),
        ya.send_command_to(@target_sprite, :cry),
        ya.scalar(IMPACT_DURATION * 2 / 3, self, :flash_alpha=, 255, 0),
        ya.opacity_change(IMPACT_DURATION / 6, @impact, 0, 255 * @light_damping),
        spin_animation(IMPACT_DURATION),
        shake_animation(IMPACT_DURATION),
        ya.wait(IMPACT_DURATION)
      )
    end

    # Wipe the impact out and give the info bars back
    # @return [Yuki::Animation::Player]
    def fall_off_animation
      ya = Yuki::Animation
      return ya.player(
        ya.parallel(
          ya.opacity_change(FALL_OFF_DURATION / 4, @impact, 255 * @light_damping, 0),
          spin_animation(FALL_OFF_DURATION, IMPACT_TURNS * IMPACT_DURATION / (IMPACT_DURATION + FALL_OFF_DURATION)),
          ya.wait(FALL_OFF_DURATION)
        ),
        ya.send_command_to(self, :show_info_bars),
        ya.send_command_to(self, :dispose)
      )
    end

    # Turn the impact sprite, a steady rotation instead of the angle blinking of the source, the
    # mirror still flipping at the cadence it had
    # @param duration [Float]
    # @param from [Float] turns already made when this leg starts
    # @return [Yuki::Animation::TimedAnimation]
    def spin_animation(duration, from = 0)
      steps = (duration / IMPACT_SPIN_PERIOD).round
      turns = IMPACT_TURNS * duration / (IMPACT_DURATION + FALL_OFF_DURATION)
      updater = proc do |progress|
        @impact.angle = 360 * (from + (turns * progress))
        @impact.mirror = ((progress * steps) + 0.5).floor.odd?
      end
      return Yuki::Animation.scalar(duration, updater, :call, 0, 1)
    end

    # Shift the whole scene, battlers and arena, the way the source does during the impact
    # @param duration [Float]
    # @return [Yuki::Animation::Player]
    def shake_animation(duration)
      ya = Yuki::Animation
      visual = @scene.visual
      updater = proc { |progress| visual.apply_shake_offset(shake_offset((progress * duration / SOURCE_FRAME_DURATION).floor)) }
      return ya.player(
        ya.send_command_to(visual, :capture_shake_origins),
        ya.scalar(duration, updater, :call, 0, 1),
        ya.send_command_to(visual, :restore_shake_origins)
      )
    end

    # Offset reached after a number of source frames, a constant step every frame with the direction reversed every half period
    # @param frame [Integer]
    # @return [Float]
    def shake_offset(frame)
      period = SHAKE_HALF_PERIOD_FRAMES * 2
      cycle = frame % period
      return (period - cycle) * SHAKE_STEP if cycle > SHAKE_HALF_PERIOD_FRAMES

      return cycle * SHAKE_STEP
    end

    # Set the alpha of the white flash
    # @param alpha [Numeric]
    def flash_alpha=(alpha)
      @viewport.color.set(255, 255, 255, alpha)
    end

    # Hide every spark, ray and ripple still visible when the charge ends, the way the source destroys them all at once
    def hide_charge_sprites
      @sparks.each { |spark| spark.opacity = 0 }
      @rays.each { |ray| ray.opacity = 0 }
      @ripples.each { |ripple| ripple.opacity = 0 }
    end

    # Release the tone channel and light the persistent aura
    def hand_over_to_aura
      @tone_handed_over = true
      @target_sprite.release_tone_channel
      @target_sprite.start_boss_aura(@style)
    end

    # Hide the info bars until the flare gives them back
    def hide_info_bars
      @info_bars_hidden = true
      @scene.visual.hide_info_bars(true)
    end

    # Give the info bars back, unless they already are
    def show_info_bars
      return unless @info_bars_hidden

      @info_bars_hidden = false
      @scene.visual.show_info_bars
    end

    # Give the tone channel back, unless the hand over to the persistent aura already did
    def release_target_tone
      return if @tone_handed_over

      @target_sprite.release_tone_channel
    end

    # Create one spark
    # @param index [Integer]
    # @return [Sprite::WithColor]
    def create_spark(index)
      sprite = add_sprite(@center_x, @center_y, "boss-aura/aura_spark_#{(index % 4) + 1}", type: Sprite::WithColor)
      sprite.set_origin(sprite.bitmap.width / 2, sprite.bitmap.height / 2)
      sprite.opacity = 0
      sprite.set_color(@color)
      sprite.z = @target_sprite.z + 10
      apply_3d_settings_keeping_color(sprite)
      burn(sprite)
      return sprite
    end

    # Create one ray
    # @return [Sprite::WithColor]
    def create_ray
      sprite = add_sprite(@center_x, @center_y, 'boss-aura/aura_ray', type: Sprite::WithColor, ox: 0, oy: 24)
      sprite.opacity = 0
      sprite.zoom = 0
      sprite.set_color(@color)
      sprite.z = @target_sprite.z + 2
      apply_3d_settings_keeping_color(sprite)
      burn(sprite)
      return sprite
    end

    # Create one ripple
    # @return [Sprite::WithColor]
    def create_ripple
      sprite = add_sprite(@center_x, @center_y, 'boss-aura/aura_ripple', type: Sprite::WithColor, ox: 64, oy: 64)
      sprite.opacity = 0
      sprite.set_color(@color)
      sprite.z = @target_sprite.z + 1
      apply_3d_settings_keeping_color(sprite)
      burn(sprite)
      return sprite
    end

    # Create the impact sprite. It covers the screen and never joins the 3D pass, so it wears the
    # color shader of its own class and nothing else.
    # @return [Sprite::WithColor]
    def create_impact
      sprite = add_sprite(@viewport.rect.width / 2, @viewport.rect.height / 2, 'boss-aura/aura_impact',
                          type: Sprite::WithColor, ox: 256, oy: 192)
      sprite.opacity = 0
      sprite.set_color(@color)
      # The sheet was drawn to cover the screen of the source exactly, so it is fitted to ours
      sprite.zoom = @viewport.rect.width / sprite.bitmap.width.to_f
      sprite.z = 999
      burn(sprite)
      return sprite
    end

    # Have a sprite burn instead of cover, the blend going on the shader in place and never on the sprite
    # @param sprite [Sprite]
    def burn(sprite)
      sprite.shader.blend_type = ADDITIVE_BLEND
    end

    # How much of its light a pale aura gives up, additive white blowing the middle out first
    # @param color [Array<Float>] the aura color, its components from 0 to 1
    # @return [Float]
    def light_damping_of(color)
      red, green, blue = color
      return 1 - (LIGHT_DAMPING * ((0.299 * red) + (0.587 * green) + (0.114 * blue)))
    end

    # Register a tinted sprite in the 3D pass, laying its color back on the shader the pass installs
    # @param sprite [Sprite::WithColor]
    def apply_3d_settings_keeping_color(sprite)
      apply_3d_settings(sprite)
      return unless Battle::BATTLE_CAMERA_3D

      sprite.shader.set_float_uniform('color', @color)
    end

    # Register a sprite in the 3D pass when the battle camera asks for it
    # @param sprite [Sprite]
    def apply_3d_settings(sprite)
      return unless Battle::BATTLE_CAMERA_3D

      sprite.shader = Shader.create(:fake_3d)
      @scene.visual.sprites3D.append(sprite)
      sprite.shader.set_float_uniform('z', @target_sprite.shader_z_position)
    end
  end
end
