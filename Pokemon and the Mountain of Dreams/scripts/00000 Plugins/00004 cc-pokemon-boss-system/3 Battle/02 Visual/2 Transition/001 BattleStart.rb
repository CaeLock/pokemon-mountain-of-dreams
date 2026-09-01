module Battle
  module Message
    FILE_ID = 10_001

    module_function

    # Shows the correct message when wild Pokémon appear in battle.
    # This method collects all enemy Pokémon and prepares the message text.
    def wild_battle_appearance
      pokemons = [@logic.battler(1, 0), @logic.battler(1, 1), @logic.battler(1, 2)].compact
      @text.reset_variables
      params = message_params(pokemons)
      @text.parse(*params)
    end

    # Chooses the correct message and its parameters based on the number of wild Pokémon.
    #
    # @param pokemons [Array<PFM::Pokemon>] List of opponent Pokémon.
    # @return [Array] Parameters to use with @text.parse.
    def message_params(pokemons)
      names = pokemon_names_hash(pokemons)
      case pokemons.size
      when 1 then single_battle_params(pokemons.first, names)
      when 2 then double_battle_params(pokemons, names)
      when 3 then triple_battle_params(pokemons, names)
      end
    end

    # Returns the parameters for a single wild Pokémon encounter.
    #
    # @param pokemon [PFM::Pokemon] The opponent Pokémon.
    # @param names [Hash{Symbol => String}] Pokémon name(s) to insert in the message.
    # @return [Array] Parameters for @text.parse.
    def single_battle_params(pokemon, names)
      index = pokemon.boss? ? 3 : 2
      return [FILE_ID, index - 2, names]
    end

    # Maps boss combinations to message indexes.
    DOUBLE_MAP = {
      [false, false] => 5,
      [true,  false] => 6,
      [false, true] => 7,
      [true,  true] => 8
    }.freeze

    # Returns the parameters for a double wild Pokémon encounter.
    #
    # @param pokemons [Array<PFM::Pokemon>] The opponent Pokémon.
    # @param names [Hash{Symbol => String}] Pokémon names to insert in the message.
    # @return [Array] Parameters for @text.parse.
    def double_battle_params(pokemons, names)
      boss_flags = pokemons.map(&:boss?)
      [FILE_ID, DOUBLE_MAP[boss_flags] - 2, names]
    end

    # Maps boss combinations to message indexes.
    TRIPLE_MAP = {
      [false, false, false] => 10,
      [true, false, false] => 11,
      [false, true, false] => 12,
      [false, false, true] => 13,
      [true, true, false] => 14,
      [false, true, true] => 15,
      [true, false, true] => 16,
      [true, true, true] => 17
    }.freeze

    # Returns the parameters for a triple wild Pokémon encounter.
    #
    # @param pokemons [Array<PFM::Pokemon>] The opponent Pokémon.
    # @param names [Hash{Symbol => String}] Pokémon names to insert in the message.
    # @return [Array] Parameters for @text.parse.
    def triple_battle_params(pokemons, names)
      boss_flags = pokemons.map(&:boss?)
      [FILE_ID, TRIPLE_MAP[boss_flags] - 2, names]
    end

    # Builds a hash that links Pokémon position symbols to their names.
    # Example: { :pk1 => "Pikachu", :pk2 => "Eevee" }
    #
    # @param pokemons [Array<PFM::Pokemon>] The opponent Pokémon.
    # @return [Hash{Symbol => String}] Pokémon names hash.
    def pokemon_names_hash(pokemons)
      pokemons.each_with_index.to_h { |pokemon, index| [PFM::Text::PKNAME[index], pokemon.name] }
    end
  end
end
