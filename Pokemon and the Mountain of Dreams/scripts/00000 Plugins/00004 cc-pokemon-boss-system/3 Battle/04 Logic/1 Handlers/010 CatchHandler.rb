module Battle
  class Logic
    class CatchHandler < ChangeHandlerBase
      # Check if the ball is blocked because the target is a boss
      # @param target [PFM::PokemonBattler]
      # @param ball [Studio::BallItem]
      # @return [Boolean] if the ball was blocked
      def ball_blocked_for_boss?(target, ball)
        return false unless target.boss?
        return false if target.nb_bars_hp == 1 && !$game_switches[Yuki::Sw::NO_CATCH_BOSS]

        @scene.visual.show_catch_blocked_animation(target, ball)
        $bag.add_item(ball.db_symbol)
        @scene.display_message_and_wait(parse_text_with_pokemon(10_000, 16, target))

        return true
      end

      module CatchHandlerBossPatch
        # Check if the ball is blocked
        # @param target [PFM::PokemonBattler]
        # @param ball [Studio::BallItem]
        # @return [Boolean] if the ball was blocked
        def ball_blocked?(target, ball)
          result = super
          result ||= ball_blocked_for_boss?(target, ball)
          return result
        end
      end

      prepend CatchHandlerBossPatch
    end
  end
end
