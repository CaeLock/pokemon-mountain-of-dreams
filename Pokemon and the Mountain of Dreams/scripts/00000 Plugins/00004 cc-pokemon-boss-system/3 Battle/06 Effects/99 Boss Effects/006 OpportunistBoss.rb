module Battle
  module Effects
    class Boss
      class Opportunist < Boss
        # Function called when a stat_change has been applied.
        # Only on_stat_change_post reaches the boss for a player self-buff (it dispatches over every
        # battler, unlike the prevention/on_stat_change hooks limited to target and launcher).
        # @param handler [Battle::Logic::StatChangeHandler]
        # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @param power [Integer] power of the stat change
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_stat_change_post(handler, stat, power, target, launcher, skill)
          return if target.bank == @target.bank
          return if launcher.nil? && skill.nil?
          return if power == 0

          absorb(handler, stat, power, target)
          return nil
        end

        private

        # Reset the player's stat to neutral and claim its magnitude as a boss gain.
        # The reset is a direct set (no second animation), the boss gain caps at +6.
        # @param handler [Battle::Logic::StatChangeHandler]
        # @param stat [Symbol]
        # @param power [Integer] the change the player just received
        # @param target [PFM::PokemonBattler] the player battler
        def absorb(handler, stat, power, target)
          handler.scene.visual.show_boss(@target)
          handler.scene.display_message_and_wait(parse_text_with_pokemon(10_000, 32, @target))

          target.set_stat_stage(Battle::Logic::StatChangeHandler::STAT_INDEX[stat], 0)
          handler.stat_change_with_process(stat, power.abs, @target)
        end
      end

      register(:opportunist_boss, Opportunist)
    end
  end
end
