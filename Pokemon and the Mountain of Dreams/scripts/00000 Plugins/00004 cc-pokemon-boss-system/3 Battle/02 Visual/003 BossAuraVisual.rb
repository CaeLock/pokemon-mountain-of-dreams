module Battle
  class Visual
    # ID of the text file holding the Boss messages
    BOSS_AURA_FILE_ID = 10_000
    # ID of the text announcing an aura flaring up
    BOSS_AURA_FLARE_TEXT_ID = 52

    # Light the aura of a Boss reaching the field, its flare the first time, silently afterwards.
    # @param pokemon [PFM::PokemonBattler, nil]
    def show_boss_aura_on_entry(pokemon)
      return unless pokemon&.boss? && pokemon.boss_aura
      return light_boss_aura(pokemon) if pokemon.boss_aura_flared?

      show_boss_aura_flare(pokemon)
    end

    # Light the aura of a Boss straight away, with neither flare nor message.
    # @param pokemon [PFM::PokemonBattler]
    def light_boss_aura(pokemon)
      battler_sprite(pokemon.bank, pokemon.position)&.start_boss_aura(pokemon.boss_aura)
    end

    # Play the flare of a Boss aura, then leave the aura lit around it.
    # @param pokemon [PFM::PokemonBattler]
    # @param style [Symbol, Boolean, nil] aura style, defaults to the one carried by the Pokemon
    def show_boss_aura_flare(pokemon, style = nil)
      sprite = battler_sprite(pokemon.bank, pokemon.position)
      return unless sprite

      # Reached from the intro, from a switch and from scripts, so the lock is taken the way the engine takes it where it may already be held
      was_locked = locking?
      lock unless was_locked
      begin
        wait_for_animation
        flare = UI::BossAuraFlare.new(@viewport, @scene, pokemon, sprite, style || pokemon.boss_aura || true)
        animation = flare.flare_animation
        flare_played = false
        begin
          animation.start
          scene_update_proc { animation.update } until animation.done?
          flare_played = true
        ensure
          flare.dispose
          reset_boss_aura_camera unless flare_played
        end
        @scene.display_message_and_wait(parse_text_with_pokemon(BOSS_AURA_FILE_ID, BOSS_AURA_FLARE_TEXT_ID, pokemon))
        reset_boss_aura_camera
        pokemon.boss_aura_flared = true
      ensure
        unlock unless was_locked
      end
    end

    # Give the camera its default framing back, the flare having pushed it onto the Boss.
    def reset_boss_aura_camera
      return unless Battle::BATTLE_CAMERA_3D

      start_center_animation
    end

    # Put the aura of a Boss out.
    # @param pokemon [PFM::PokemonBattler]
    def hide_boss_aura(pokemon)
      battler_sprite(pokemon.bank, pokemon.position)&.stop_boss_aura
    end

    # List the sprites of the Pokemon standing on the field, leaving the trainer sprites out.
    # @return [Array<BattleUI::PokemonSprite>]
    def battler_sprites
      return @battlers.each_value.flat_map(&:values).grep(BattleUI::PokemonSprite)
    end

    # Remember where everything a screen shake moves sits, the battler sprites and the arena behind them.
    def capture_shake_origins
      @shake_sprites = battler_sprites + [background].compact
      @shake_origins = @shake_sprites.map(&:y)
    end

    # Move every sprite of the scene away from where the shake found it.
    # @param offset [Float]
    def apply_shake_offset(offset)
      @shake_sprites&.each_with_index { |sprite, index| sprite.y = @shake_origins[index] + offset }
    end

    # Put every sprite of the scene back where the shake found it, twice over if need be.
    def restore_shake_origins
      apply_shake_offset(0)
      @shake_sprites = nil
      @shake_origins = nil
    end

    # Gives the scene shake of the aura flare somewhere to start from.
    module BossAuraShakePatch
      # Create a new visual instance
      # @param scene [Scene] scene that hold the logic object
      def initialize(scene)
        @shake_sprites = nil
        @shake_origins = nil
        super
      end
    end

    prepend BossAuraShakePatch

    # Puts the aura of a fallen Boss out, its sprite fading out without ever turning invisible.
    module BossAuraKoPatch
      # Show KO animations
      # @param targets [Array<PFM::PokemonBattler>]
      def show_kos(targets)
        targets.select(&:dead?).each { |target| hide_boss_aura(target) }
        super
      end
    end

    prepend BossAuraKoPatch
  end
end
