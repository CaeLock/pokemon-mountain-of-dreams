module PFM
  class Wild_Battle
    # Start a Boss battle
    # @param pokemons [Array<PFM::Pokemon>] The Pokemons to battle
    # @param battle_id [Integer] id of the scenarize battle to get the right Boss Effect
    def start_boss_battle(*pokemons, battle_id: 1)
      $game_temp.battle_can_lose = false
      init_boss_battle(*pokemons)
      Graphics.freeze
      $scene = Battle::Scene.new(setup(battle_id))
      Yuki::FollowMe.set_battle_entry
    end

    # Initialize a Boss battle
    # @param pokemons [Array<PFM::Pokemon>] The Pokemons to battle
    def init_boss_battle(*pokemons)
      @forced_wild_battle = []

      pokemons.each do |pokemon|
        @forced_wild_battle << pokemon if pokemon.is_a?(PFM::Pokemon)
      end
    end
  end
end
