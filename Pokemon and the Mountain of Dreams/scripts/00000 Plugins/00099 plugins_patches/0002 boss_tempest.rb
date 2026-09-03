# Tempest Boss - Pokemon Boss System extension
#
# - On each HP bar break: creates a Substitute worth 25% of its max HP (free,
#   no HP cost), summons Rain, and swaps its moveset from BEFORE_BAR_BREAK_MOVES
#   to AFTER_BAR_BREAK_MOVES.
#
# Usage:
#   boss = PFM::Pokemon.new(:whatever, 50)
#   boss.boss = true
#   boss.nb_bars_hp = 3
#   boss.boss_effects_db_symbols += [:tempest_boss]
#   call_battle_boss(boss)

module Battle
  module Effects
    # Same as Effects::Substitute, but with a caller-specified HP amount
    # instead of the fixed max_hp / 4. Used by Tempest's bar-break Substitute.
    class CustomHPSubstitute < Substitute
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param hp [Integer] the exact HP to give this substitute
      def initialize(logic, pokemon, hp)
        super(logic, pokemon)
        @hp = @max_hp = hp
      end
    end
  end
end

module Battle
  module Effects
    class Boss
      class Tempest < Boss
        BEFORE_BAR_BREAK_MOVES = %i[agility thunder_shock luminous_trail dive].freeze
        AFTER_BAR_BREAK_MOVES = %i[against_the_storm water_pulse abyssal_fluorescence dazzling_gleam].freeze

        def initialize(logic, target, db_symbol)
          super
          @bar_broken = false
          set_moveset(BEFORE_BAR_BREAK_MOVES)
        end

        # @return [Boolean] whether this boss has broken a bar yet (read by the
        #   battle event to pick which move-priority table to use)
        def bar_broken?
          return @bar_broken
        end

        # Function called when one of the creature's HP bars breaks, once per bar broken.
        # @param handler [Battle::Logic::DamageHandler]
        # @param target [PFM::PokemonBattler] the creature that lost the bar
        # @param skill [Battle::Move, nil] Potential move used
        def on_bar_break(handler, target, skill)
          return if target != @target

          @bar_broken = true
          $scene.visual.show_boss_aura_flare(@boss)
          create_substitute(handler)
          summon_rain(handler)
          set_moveset(AFTER_BAR_BREAK_MOVES)
        end

        private

        # Overwrites the boss's 4 moves in place.
        # @param moves [Array<Symbol>]
        def set_moveset(moves)
          moves.each_with_index { |db_symbol, index| @target.replace_skill_index(index, db_symbol) }
        end

        # Creates a Substitute worth 25% of the boss's max HP, at no HP cost to the boss.
        # @param handler [Battle::Logic::DamageHandler]
        def create_substitute(handler)
          return if @target.effects.has?(:substitute)

          hp = (@target.max_hp * 0.25).round.clamp(1, Float::INFINITY)
          handler.scene.visual.show_boss(@target)
          @target.effects.add(Effects::CustomHPSubstitute.new(handler.logic, @target, hp))
        end

        # Summons Rain, same duration rules as Rain Dance (Damp Rock extends it).
        # @param handler [Battle::Logic::DamageHandler]
        def summon_rain(handler)
          nb_turn = @target.hold_item?(:damp_rock) ? 8 : 5
          handler.logic.weather_change_handler.weather_change_with_process(:rain, nb_turn)
        end
      end

      register(:tempest_boss, Tempest)
    end
  end
end