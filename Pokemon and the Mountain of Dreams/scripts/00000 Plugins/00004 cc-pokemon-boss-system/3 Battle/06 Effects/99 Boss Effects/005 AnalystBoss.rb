module Battle
  module Effects
    class Boss
      class Analyst < Boss
        # Function called after a battler proceed its two turn move's first turn
        # @param user [PFM::PokemonBattler]
        # @param targets [Array<PFM::PokemonBattler>, nil]
        # @param skill [Battle::Move, nil]
        # @return [Boolean] weither or not the two turns move is executed in one turn
        def on_two_turn_shortcut(user, targets, skill)
          return user == @target
        end

        # Function called when we try to get the definitive type of a move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        # @param type [Integer] current type of the move (potentially after effects)
        # @return [Integer, nil] new type of the move
        def on_move_type_change(user, target, move, type)
          return if user != @target || move.status?

          return super_effective_type_against(target)
        end

        private

        # Get the type that hits the target the hardest (nil if the target has no weakness).
        # @param target [PFM::PokemonBattler]
        # @return [Integer, nil]
        def super_effective_type_against(target)
          defending = [target.type1, target.type2, target.type3]
                      .map { |type_id| data_type(type_id).db_symbol }
                      .reject { |symbol| symbol == :__undef__ }
          best_type = nil
          best_effectiveness = 1.0
          each_data_type do |candidate|
            effectiveness = defending.inject(1.0) { |product, symbol| product * candidate.hit(symbol) }
            next unless effectiveness > best_effectiveness

            best_effectiveness = effectiveness
            best_type = candidate.id
          end

          return best_type
        end
      end

      register(:analyst_boss, Analyst)
    end
  end
end
