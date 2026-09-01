module BattleUI
  class PokemonSprite < ShaderedSprite
    # Persistent aura of a Boss, the charged state of the Elite Battle DX Totem battles.
    module BossAuraPatch
      # Lowest alpha of the pulse, over 255 as the tone uniform expects a ratio
      PULSE_MIN_ALPHA = 8 / 255.0
      # Highest alpha of the pulse
      PULSE_MAX_ALPHA = 128 / 255.0
      # Duration of one direction of the pulse in seconds
      PULSE_DURATION = 3.0

      # Create a new PokemonSprite
      # @param viewport [Viewport]
      # @param scene [Battle::Scene]
      def initialize(viewport, scene)
        @boss_aura_emitter = nil
        @boss_aura_animation = nil
        @boss_aura_style = nil
        super
      end

      # Set the Pokemon
      # @param pokemon [PFM::PokemonBattler]
      def pokemon=(pokemon)
        # The Mega Evolution animation hands the very same battler back to the sprite, only another one replaces it
        stop_boss_aura unless pokemon.equal?(@pokemon)
        super
      end

      # Light the aura around the Pokemon
      # @param style [Symbol, Boolean, nil] aura style, a type symbol or true for the default color
      def start_boss_aura(style)
        stop_boss_aura
        @boss_aura_style = style
        @boss_aura_emitter = BossAuraEmitter.new(viewport, self, scene, style)
        @boss_aura_emitter.z = z
        start_boss_aura_pulse
      end

      # Put the aura out, doing nothing when the sprite never wore one
      def stop_boss_aura
        return unless @boss_aura_emitter

        @boss_aura_animation = nil
        @boss_aura_emitter.dispose
        @boss_aura_emitter = nil
        @boss_aura_style = nil
        release_tone_channel
      end

      # Update the sprite
      def update
        super
        @boss_aura_emitter&.update
        @boss_aura_animation&.update
        suspend_boss_aura_pulse_on_status
      end

      # Set the visibility of the sprite
      # @param visible [Boolean]
      def visible=(visible)
        super
        @boss_aura_emitter&.visible = visible
      end

      # Set the z position of the sprite
      # @param z [Numeric]
      def z=(z)
        super
        @boss_aura_emitter&.z = z
      end

      # Dispose the sprite
      def dispose
        stop_boss_aura
        super
      end

      # Give the tone channel back to the status, clearing it when nothing paints the sprite
      def release_tone_channel
        return reset_tone_status if status_tinted?

        self.stop_status_tone = false
        remove_tone_animation
      end

      private

      # Start the tone loop of the aura
      def start_boss_aura_pulse
        red, green, blue = BossAuraColors.resolve_floats(@boss_aura_style)
        updater = proc { |alpha| shader.set_float_uniform('color', [red, green, blue, alpha]) }
        ya = Yuki::Animation
        @boss_aura_animation = ya.timed_loop_animation(PULSE_DURATION * 2, [
                                                         ya.scalar(PULSE_DURATION, updater, :call, PULSE_MIN_ALPHA, PULSE_MAX_ALPHA),
                                                         ya.scalar(PULSE_DURATION, updater, :call, PULSE_MAX_ALPHA, PULSE_MIN_ALPHA)
                                                       ])
        @boss_aura_animation.resolver = self
        @boss_aura_animation.start
      end

      # Hand the tone channel over to the status tint while the Pokemon suffers from one, the way
      # EBDX only paints the aura color when the battler has no status.
      def suspend_boss_aura_pulse_on_status
        return unless @boss_aura_emitter

        tinted = status_tinted?
        return start_boss_aura_pulse if !tinted && @boss_aura_animation.nil?
        return unless tinted && @boss_aura_animation

        @boss_aura_animation = nil
        set_tone_status(pokemon.status, true)
      end

      # Tell whether the status of the Pokemon paints its sprite, the way PokemonSprite short circuits
      # the no status case before reading the tone table
      # @note Mirrors the tone table guard of PokemonSprite#set_tone_status, 5 Battle/01 Scene/0 BattleUI/100 PokemonSprite.rb:277-278
      # @return [Boolean]
      def status_tinted?
        status = pokemon&.status
        return false if status.nil? || status == 0

        # A state added by the maker has no symbol, hence no tone, and would make set_tone_status raise
        tone = STATUS_TONE[Configs.states.symbol(status)]
        return false if tone.nil?

        return tone != [0, 0, 0, 0, 0]
      end
    end

    prepend BossAuraPatch
  end
end
