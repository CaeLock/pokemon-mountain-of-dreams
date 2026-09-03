module Battle
  module Effects
    class Boss
      class Adaptive < Boss
        # Create a new boss effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the boss effect
        def initialize(logic, target, db_symbol)
          super
          @type_uses = Hash.new(0)
        end

        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || target == launcher
          return if skill.nil? || skill.multi_hit? && !skill.last_hit?

          announce_adaptation(handler, skill) if hardens?(skill)
          @type_uses[data_type(skill.type).db_symbol] += 1
        end

        # Function that computes an overwrite of the type multiplier
        # @param target [PFM::PokemonBattler]
        # @param target_type [Integer] one of the type of the target
        # @param type [Integer] one of the type of the move
        # @param move [Battle::Move]
        # @return [Float, nil] overwriten type multiplier
        def on_single_type_multiplier_overwrite(target, target_type, type, move)
          return nil if target != @target || move.status?
          # Anchor the whole reduction on the first type so the total effectiveness is driven once.
          return nil unless target_type == target.type1

          uses = @type_uses[data_type(type).db_symbol]
          return if uses <= 0

          natural = natural_effectiveness(type)
          return if natural.zero?

          adapted = [floor, natural * (halving**uses)].max
          natural_others = natural / data_type(type).hit(data_type(target.type1).db_symbol)
          return adapted / natural_others
        end

        # Lowest effectiveness a saturated type can reach.
        # @return [Float]
        def floor
          return 0.25
        end

        # Factor applied to a type's effectiveness per use.
        # @return [Float]
        def halving
          return 0.5
        end

        private

        # Product of the move type's natural effectiveness over the boss's types.
        # @param type [Integer] the move type
        # @return [Float]
        def natural_effectiveness(type)
          types = [@target.type1, @target.type2, @target.type3].reject(&:zero?)
          return types.inject(1.0) { |product, target_type| product * data_type(type).hit(data_type(target_type).db_symbol) }
        end

        # Whether one more use of this move's type would tighten its resistance (not yet floored).
        # @param skill [Battle::Move]
        # @return [Boolean]
        def hardens?(skill)
          natural = natural_effectiveness(skill.type)
          return false if natural.zero?

          uses = @type_uses[data_type(skill.type).db_symbol]
          return [floor, natural * halving**(uses + 1)].max < [floor, natural * halving**uses].max
        end

        # Tell the player the boss now resists this move's type better.
        # @param handler [Battle::Logic::DamageHandler]
        # @param skill [Battle::Move]
        def announce_adaptation(handler, skill)
          handler.scene.visual.show_boss(@target)
          handler.scene.display_message_and_wait(parse_text_with_pokemon(10_000, 48, @target, { '[TYPE]' => data_type(skill.type).name }))
        end
      end

      register(:adaptive_boss, Adaptive)
    end
  end
end
