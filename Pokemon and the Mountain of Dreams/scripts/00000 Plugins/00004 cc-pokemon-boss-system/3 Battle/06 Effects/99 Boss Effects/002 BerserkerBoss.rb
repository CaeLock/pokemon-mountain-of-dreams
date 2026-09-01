module Battle
  module Effects
    class Boss
      class Berserker < Boss
        # Give the atk modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def atk_modifier
          return 2
        end

        # Give the dfe modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def dfe_modifier
          return 0.75
        end

        # Give the ats modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def ats_modifier
          return 2
        end

        # Give the dfs modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def dfs_modifier
          return 0.75
        end

        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          drain(handler, hp, target, launcher, skill)
        end
        alias on_post_damage_death on_post_damage

        # Function called when one of the creature's HP bars breaks, once per bar broken.
        # @param handler [Battle::Logic::DamageHandler]
        # @param target [PFM::PokemonBattler] the creature that lost the bar
        # @param skill [Battle::Move, nil] Potential move used
        def on_bar_break(handler, target, skill)
          rage(handler, target)
        end

        private

        # Drink back part of the damage the boss just dealt with its own move.
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def drain(handler, hp, target, launcher, skill)
          return if launcher != @target || launcher == target
          return if skill.nil?

          heal_amount = (hp * 0.5).to_i
          return if heal_amount <= 0

          handler.scene.visual.show_boss(launcher)
          handler.heal_boss(launcher, heal_amount)
        end

        # Get faster every time one of the boss's own HP bars breaks.
        # @param handler [Battle::Logic::DamageHandler]
        # @param target [PFM::PokemonBattler]
        def rage(handler, target)
          return if target != @target

          handler.scene.visual.show_boss(target)
          handler.logic.stat_change_handler.stat_change_with_process(:spd, 1, target)
        end
      end

      register(:berserker_boss, Berserker)
    end
  end
end
