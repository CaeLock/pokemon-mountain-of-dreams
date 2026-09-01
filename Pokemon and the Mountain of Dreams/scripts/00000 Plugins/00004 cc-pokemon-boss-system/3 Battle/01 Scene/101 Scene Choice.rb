module Battle
  class Scene
    module SceneChoiceBossPatch
      # Begin the Pokemon giving procedure
      # @param battler [PFM::PokemonBattler] pokemon that was just caught
      # @param ball [Studio::BallItem]
      def give_pokemon_procedure(battler, ball)
        super

        creature = battler.original
        creature.boss = false
        creature.nb_bars_hp = 0
        creature.boss_effect_db_symbol = nil
      end
    end

    prepend SceneChoiceBossPatch
  end
end
