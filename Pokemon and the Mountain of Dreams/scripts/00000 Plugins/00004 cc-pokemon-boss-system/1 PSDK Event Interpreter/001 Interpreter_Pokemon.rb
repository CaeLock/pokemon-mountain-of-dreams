class Interpreter
  # Starts a Boss battle
  # @param pokemons [Array<PFM::Pokemon>] The Pokemons to battle
  # @param battle_id [Integer] id of the scenarize battle
  def call_battle_boss(*pokemons, battle_id: 1)
    pokemons.compact!

    raise ArgumentError, 'At least one Pokémon is required' if pokemons.empty?
    raise ArgumentError, 'A maximum of 3 Pokémon is allowed' if pokemons.size > 3

    $wild_battle.start_boss_battle(*pokemons, battle_id: battle_id)
    @wait_count = 2
  end
end
