module Battle
  module Effects
    class Boss
      class Stall < Boss
        # Give the dfe modifier given to the Pokemon with this effect
        # @return [Float] multiplier
        def dfe_modifier
          return 1.5
        end

        # Give the dfs modifier given to the Pokemon with this effect
        # @return [Float] multiplier
        def dfs_modifier
          return 1.5
        end

        # Tell if the effect prevents a critical hit
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @return [Boolean]
        def prevent_critical_hit?(user, target)
          return target == @target
        end

        # Function called before drain were applied (to potentially prevent healing)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param hp_healed [Integer] number of hp healed
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the drain cannot be applied
        def on_drain_prevention(handler, hp, hp_healed, target, launcher, skill)
          return if target != @target

          return handler.prevent_change do
            handler.scene.visual.show_boss(@target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(10_000, 20, @target))
          end
        end

        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target)
          return if @target.dead?

          scene.visual.show_boss(@target)
          logic.damage_handler.heal_boss(@target, @target.max_hp / 8)
        end
      end

      register(:stall_boss, Stall)
    end
  end
end
