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
#
# Depends on Effects::CustomHPSubstitute, already defined in the custom-moves
# file (used there by Luminous Trail) - not redefined here to avoid two
# copies of the same class drifting apart. Load order between the two files
# doesn't matter, since it's only referenced inside a method body here
# (create_substitute), not at load time.
#
# Fixed from the original: set_moveset used to call
# PFM::Pokemon#replace_skill_index, which writes a raw, un-wrapped
# PFM::Skill into @skills_set. That's correct for editing a Pokemon's
# moveset OUTSIDE battle, but @target here is a PokemonBattler - since
# PokemonBattler doesn't override that method, it inherited the
# PFM::Pokemon one and mutated @skills_set directly. PokemonBattler#copy_moveset
# sets @skills_set and @moveset to the SAME array, so that corrupted the live
# battle moveset with a raw PFM::Skill in one slot instead of a proper
# Battle::Move wrapper - crashing the AI's move_unusable? on that slot's
# missing #disable_reason. set_moveset now builds a real Battle::Move the
# same way PokemonBattler#copy_moveset does (using Studio::Move#pp for both
# the starting pp and pp max passed to Battle::Move.new - Studio::Move has
# no separate pp_max field).
module Battle
  module Effects
    class Boss
      class Tempest < Boss
        BEFORE_BAR_BREAK_MOVES = %i[agility thunder_shock luminous_trail dive].freeze
        AFTER_BAR_BREAK_MOVES = %i[against_the_storm water_pulse abyssal_fluorescence dazzling_gleam].freeze

        def initialize(logic, target, db_symbol)
          super
          @bar_broken = false
          set_moveset(logic, BEFORE_BAR_BREAK_MOVES)
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
          set_moveset(handler.logic, AFTER_BAR_BREAK_MOVES)
        end

        private

        # Overwrites the boss's 4 moves in place, properly wrapped as Battle::Move -
        # NOT via PFM::Pokemon#replace_skill_index, which writes a raw PFM::Skill.
        # @target here is a PokemonBattler; its @moveset/@skills_set (what's
        # actually read during battle) need Battle::Move instances, exactly
        # like PokemonBattler#copy_moveset builds them.
        # @param logic [Battle::Logic]
        # @param moves [Array<Symbol>]
        def set_moveset(logic, moves)
          moves.each_with_index do |db_symbol, index|
            move_data = data_move(db_symbol)
            @target.moveset[index] = Battle::Move[db_symbol].new(move_data.db_symbol, move_data.pp, move_data.pp, logic.scene)
          end
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