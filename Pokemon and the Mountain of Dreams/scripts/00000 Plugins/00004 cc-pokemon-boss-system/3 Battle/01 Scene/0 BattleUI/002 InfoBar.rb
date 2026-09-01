module BattleUI
  class InfoBar < UI::SpriteStack
    module InfoBarBossPatch
      # Get the pokemon HP bars.
      # @return [Array<Sprite>]
      attr_reader :bars_hp

      # Create a new InfoBar.
      # @param viewport [Viewport]
      # @param scene [Battle::Scene]
      # @param pokemon [PFM::Pokemon]
      # @param bank [Integer]
      # @param position [Integer]
      def initialize(viewport, scene, pokemon, bank, position)
        @bars_hp = []
        super
      end

      private

      # Creates all the sprites used by the InfoBar.
      # Reserve HP bar slots are created on every enemy info bar so a boss switched in
      # after a non-boss (or after another boss with a different nb_bars_hp) gets the right display.
      def create_sprites
        super
        create_reserve_hp if enemy?
      end

      # Creates the five reserve HP bar slots. Each slot is data-aware and updates
      # its own visibility and filled/empty state from the pokemon currently shown.
      def create_reserve_hp
        total_bars = PFM::Pokemon::MAX_BOSS_BARS
        x_start    = @is_triple_battle ? 43 : 73
        x_offset   = 11

        total_bars.times do |index|
          bar = add_sprite(x_start + index * x_offset, 21, self.class::NO_INITIAL_IMAGE, index, type: ReserveHP)
          @bars_hp << bar
        end
      end
    end

    prepend InfoBarBossPatch

    class Background < ShaderedSprite
      module BackgroundBossPatch
        # Bars the engine dresses itself, the only ones the boss state is entitled to replace
        # @return [Array<String>]
        ENGINE_BACKGROUNDS = %w[battle/battlebar_enemy battle/battlebar_actor battle/battlebar_ally]

        # Gets the filename for the background image.
        # Uses a different background if the Pokemon is a boss, unless the bar is already dressed by
        # someone that knows the creature better than its boss state does.
        # @param pokemon [PFM::Pokemon] The Pokemon data.
        # @return [String] The filename of the background image.
        def background_filename(pokemon)
          filename = super
          return filename unless ENGINE_BACKGROUNDS.include?(filename.delete_suffix('_3v3'))
          return "battle/boss/battlebar_boss#{suffix_3v3}" if pokemon.boss? && !pokemon.from_party?

          return filename
        end

        # Return a suffix for 3v3 battle resources
        # @return [String]
        def suffix_3v3
          return $game_temp.vs_type == 3 ? '_3v3' : ''
        end
      end

      prepend BackgroundBossPatch
    end

    class PokemonCaughtSprite < ShaderedSprite
      module PokemonCaughtSpriteBossPatch
        # Set the Pokemon Data
        # @param pokemon [PFM::Pokemon]
        def data=(pokemon)
          self.visible = should_show_caught_sprite?(pokemon)
        end

        private

        # Determines if the caught sprite should be visible
        # @param pokemon [PFM::Pokemon]
        # @return [Boolean]
        def should_show_caught_sprite?(pokemon)
          return false if pokemon.bank == 0
          return false if pokemon.boss?
          return false unless $pokedex.creature_caught?(pokemon.id, pokemon.form)

          return true
        end
      end

      prepend PokemonCaughtSpriteBossPatch
    end

    class ReserveHP < ShaderedSprite
      # Create a new ReserveHP sprite.
      # @param viewport [Viewport]
      # @param index [Integer] slot position of this reserve bar (0..4)
      def initialize(viewport, index)
        super(viewport)
        @index = index
        set_bitmap(reserve_hp_filename, :interface)
      end

      # Refresh the bar based on the pokemon currently shown in the InfoBar.
      # Hides the slot for non-boss pokemons and sets the filled/empty image
      # according to the boss remaining bar count.
      # @param pokemon [PFM::PokemonBattler]
      def data=(pokemon)
        self.visible = pokemon.boss? && !pokemon.from_party?
        return unless visible

        switch_state(filled: @index < pokemon.nb_bars_hp)
      end

      # Switches the sprite to the filled or empty HP bar image.
      # @param filled [Boolean] whether the HP bar should be filled or empty.
      def switch_state(filled: true)
        set_bitmap(filled ? reserve_hp_filename : empty_hp_filename, :interface)
      end

      # Gets the filename for the filled reserve HP bar image.
      # @return [String]
      def reserve_hp_filename
        return 'battle/boss/hp_bar_filled'
      end

      # Gets the filename for the empty reserve HP bar image.
      # @return [String]
      def empty_hp_filename
        return 'battle/boss/hp_bar_empty'
      end
    end
  end
end
