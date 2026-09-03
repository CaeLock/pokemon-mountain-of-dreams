module Battle
  class Logic
    class DamageHandler < ChangeHandlerBase
      # Updates the damage dealt by the skill and records the last move that hit the target.
      # @param hp [Integer] The amount of damage dealt.
      # @param target [PFM::PokemonBattler] The target Pokémon receiving the damage.
      # @param skill [Battle::Move, nil] The move used to deal the damage.
      def update_skill_damage(hp, target, skill = nil)
        return unless skill

        skill.damage_dealt += hp
        target.last_hit_by_move = skill
      end

      # Show the hp animation on the target.
      # @param hp [Integer] The amount of HP (damage) dealt.
      # @param target [PFM::PokemonBattler] The target Pokémon receiving the damage.
      # @param skill [Battle::Move, nil] The move used, if applicable.
      # @param messages [Proc] The messages shown right before the post-processing.
      def show_hp_animations(hp, target, skill = nil, &messages)
        @scene.visual.show_hp_animations([target], [-hp], [skill&.effectiveness], &messages)
      end

      module DamageHandlerBossPatch
        # Function that actually deal the damage
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @param messages [Proc] messages shown right before the post processing
        def damage_change(hp, target, launcher = nil, skill = nil, &messages)
          return damage_change_boss(hp, target, launcher, skill, &messages) if target.boss?

          return super
        end

        # Function that drains a certain quantity of HP from the target and gives it to the user.
        # @param hp_factor [Integer] The division factor of HP to drain.
        # @param target [PFM::PokemonBattler] The target that gets HP drained.
        # @param launcher [PFM::PokemonBattler] The launcher of a draining move/effect.
        # @param skill [Battle::Move, nil] The potential move used.
        # @param hp_overwrite [Integer, nil] The number of HP drained by the move, if provided.
        # @param drain_factor [Integer] The division factor of HP drained.
        # @param messages [Proc] The messages shown right before the post-processing.
        def drain(hp_factor, target, launcher, skill = nil, hp_overwrite: nil, drain_factor: 1, &messages)
          return drain_boss(hp_factor, target, launcher, skill, hp_overwrite: hp_overwrite, drain_factor: drain_factor, &messages) if target.boss?

          return super
        end

        # Function that proceed the heal of a Pokemon
        # @param target [PFM::PokemonBattler]
        # @param hp [Integer] number of HP to heal
        # @param test_heal_block [Boolean]
        # @param animation_id [Symbol, Integer] animation to use instead of the original one
        # @yieldparam hp [Integer] the actual hp healed
        # @return [Boolean] if the heal was successful or not
        # @note this method yields a block in order to show the message after the animation
        # @note this shows the default message if no block has been given
        def heal(target, hp, test_heal_block: true, animation_id: nil)
          return heal_boss(target, hp, test_heal_block: test_heal_block, animation_id: animation_id) if target.boss?

          return super
        end

        # Whether a battler can be healed
        # @param target [PFM::PokemonBattler]
        # @param test_heal_block [Boolean]
        # @return [Boolean]
        def can_heal?(target, test_heal_block: true)
          return can_heal_boss?(target, test_heal_block) if target.boss?

          return super
        end
      end

      prepend DamageHandlerBossPatch
    end
  end
end
