module Battle
  module Effects
    class Boss
      class Dominant < Boss
        # Function called when a stat_decrease_prevention is checked
        # @param handler [Battle::Logic::StatChangeHandler] handler use to test prevention
        # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the stat decrease cannot apply
        def on_stat_decrease_prevention(handler, stat, target, launcher, skill)
          return if target != @target
          return :prevent if skill && !skill.status?

          return handler.prevent_change do
            handler.scene.visual.show_boss(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(10_000, 24, target))
          end
        end

        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != @target || target == launcher
          return if status == :cure

          return handler.prevent_change do
            handler.scene.visual.show_boss(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(10_000, 28, target))
          end
        end

        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target)
          return if @target.dead?

          foe_bank = @target.bank == 0 ? 1 : 0
          foes = logic.alive_battlers(foe_bank).select { |foe| foe.battle_stage.any?(&:positive?) }
          return if foes.empty?

          scene.visual.show_boss(@target)
          foes.each do |foe|
            foe.battle_stage.map! { |stage| [stage, 0].min }
            scene.display_message_and_wait(parse_text_with_pokemon(19, 195, foe))
          end
        end
      end

      register(:dominant_boss, Dominant)
    end
  end
end
