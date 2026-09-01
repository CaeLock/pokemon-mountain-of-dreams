module Battle
  class Logic
    class DamageHandler < ChangeHandlerBase
      # Function that proceeds to heal a Pokemon.
      # @param target [PFM::PokemonBattler] The Pokemon that will be healed.
      # @param hp [Integer] The number of HP to heal.
      # @param test_heal_block [Boolean] Whether to test if healing is blocked. Defaults to true.
      # @param animation_id [Symbol, Integer] The animation to use instead of the default one. Optional.
      # @return [Boolean] True if the heal was successful, false otherwise.
      def heal_boss(target, hp, test_heal_block: true, animation_id: nil)
        return false unless can_heal_boss?(target, test_heal_block)

        heal_amount = hp.clamp(1, total_heal_capacity(target))
        process_boss_healing(target, heal_amount, animation_id)

        return true
      end

      private

      # Total HP a heal can restore: the room left up to a full set of bars.
      # @param target [PFM::PokemonBattler] The Pokemon that will be healed.
      # @return [Integer]
      def total_heal_capacity(target)
        return PFM::Pokemon::MAX_BOSS_BARS * target.max_hp - target.total_hp
      end

      # Check if the target can be healed.
      # @param target [PFM::PokemonBattler] The Pokemon that will be healed.
      # @param test_heal_block [Boolean] Whether to test if healing is blocked. Defaults to true.
      # @return [Boolean] True if the target can be healed, false otherwise.
      def can_heal_boss?(target, test_heal_block)
        if target.effects.has?(:heal_block) && test_heal_block
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 890, target))
          return false
        end

        return true if target.hp < target.max_hp
        return true if target.nb_bars_hp < PFM::Pokemon::MAX_BOSS_BARS

        @scene.display_message_and_wait(parse_text_with_pokemon(19, 884, target))
        return false
      end

      # Process the healing logic for the target.
      # @param target [PFM::PokemonBattler] The Pokemon that will be healed.
      # @param heal_amount [Integer] The number of HP to heal.
      # @param animation_id [Symbol, Integer] The animation to use instead of the default one. Optional.
      def process_boss_healing(target, heal_amount, animation_id)
        return add_bar(target, heal_amount) if can_add_bar?(target, heal_amount)

        apply_boss_healing_effect(target, heal_amount, animation_id)
      end

      # Check if the Boss can regenerate at least one bar.
      # @param target [PFM::PokemonBattler] The Pokemon that will be healed.
      # @param heal_amount [Integer] The number of HP to heal.
      # @return [Boolean] True if a bar can be added, false otherwise.
      def can_add_bar?(target, heal_amount)
        return false if heal_amount + target.hp < target.max_hp + 1
        return false if target.nb_bars_hp >= PFM::Pokemon::MAX_BOSS_BARS

        return true
      end

      # Add one or more bars for the Boss, playing the continuous cross-bar heal animation.
      # @param target [PFM::PokemonBattler] The Pokemon that will be healed.
      # @param heal_amount [Integer] The number of HP to heal.
      def add_bar(target, heal_amount)
        path = target.boss_hp_path(heal_amount)

        @scene.visual.show_boss_hp_animation(target, path)
        @scene.display_message_and_wait(parse_text_with_pokemon(19, 387, target))
        # 8 = "gained a life bar", 12 = "gained several life bars" (each has 3 ally/wild/foe variants)
        bar_text_id = path.crossings > 1 ? 12 : 8
        @scene.display_message_and_wait(parse_text_with_pokemon(10_000, bar_text_id, target))
      end

      # Apply the healing effect to the target.
      # @param target [PFM::PokemonBattler] The Pokemon that will receive the healing effect.
      # @param heal_amount [Integer] The actual amount of HP to apply.
      # @param animation_id [Symbol, Integer] The animation to use for the healing effect. Optional.
      # @yieldparam heal_amount [Integer] The actual amount of HP healed, passed to the block if provided.
      def apply_boss_healing_effect(target, heal_amount, animation_id)
        show_hp_animations(-heal_amount, target)

        @scene.display_message_and_wait(parse_text_with_pokemon(19, 387, target))
      end
    end
  end
end
