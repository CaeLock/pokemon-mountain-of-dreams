module PFM
  class Wild_Battle
    private

    # Configure the Wild battle
    # @param enemy_array [Array<PFM::Pokemon>] Array of enemy Pokemon to battle.
    # @param battle_id [Integer] ID of the events to load for the battle scenario.
    # @return [Battle::Logic::BattleInfo, nil]
    def configure_battle(enemy_array, battle_id)
      return if (!enemy_array.is_a? Array) || !enemy_array || enemy_array&.empty?

      battle_info = Battle::Logic::BattleInfo.new
      battle_info.add_party(0, *battle_info.player_basic_info)
      add_ally_trainer(battle_info, $game_variables[Yuki::Var::Allied_Trainer_ID])
      add_ally_trainer(battle_info, $game_variables[Yuki::Var::Second_Allied_Trainer_ID])
      battle_info.add_party(1, enemy_array, nil, nil, nil, nil, nil, pokemon_ai(enemy_array))
      battle_info.battle_id = battle_id
      battle_info.fishing = !@fish_battle.nil?
      battle_info.vs_type = determine_vs_type(enemy_array)
      return battle_info
    end

    # Determine the AI level for the enemy Pokémon.
    # @param enemy_array [Array<PFM::Pokemon>] Array of enemy Pokémon to evaluate.
    # @return [Integer] Returns the AI level:
    #   - -1 if any Pokémon is roaming,
    #   - 7 if any Pokémon is a boss,
    #   - 0 as the default AI level.
    def pokemon_ai(enemy_array)
      return -1 if enemy_array.any? { |pokemon| roaming?(pokemon) }
      return 7 if enemy_array.any?(&:boss)

      return 0
    end

    # Determine the vs_type
    # @param enemy_array [Array<PFM::Pokemon>] Array of enemy Pokemon to battle.
    # @return [Integer]
    def determine_vs_type(enemy_array)
      return 3 if enemy_array.size == 3 || $game_switches[Yuki::Sw::FORCE_3V_BATTLE]
      return 2 if enemy_array.size == 2 || $game_switches[Yuki::Sw::FORCE_2V_BATTLE]

      return 1
    end
  end
end
