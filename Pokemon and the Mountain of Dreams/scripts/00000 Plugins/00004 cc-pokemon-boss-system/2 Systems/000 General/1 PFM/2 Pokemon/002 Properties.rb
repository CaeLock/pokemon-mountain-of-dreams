module PFM
  class Pokemon
    # Maximum number of HP bars a Boss can have.
    # @return [Integer]
    MAX_BOSS_BARS = 5

    # Return if the Pokemon is a Boss.
    # @return [Boolean]
    attr_accessor :boss
    # The number of hp bars the Pokemon has.
    # @return [Integer]
    attr_accessor :nb_bars_hp
    # Style of the aura shown around the boss, a type symbol, true for the default color, nil for none
    # @return [Symbol, Boolean, nil]
    attr_accessor :boss_aura

    # Get the aura style under its former name
    # @return [Symbol, Boolean, nil]
    def boss_halo
      return @boss_aura
    end

    # Set the aura style under its former name
    # @param style [Symbol, Boolean, nil]
    def boss_halo=(style)
      @boss_aura = style
    end

    # The db_symbols of the boss effects attached to the Pokemon (empty = none).
    # @return [Array<Symbol>]
    def boss_effects_db_symbols
      @boss_effects_db_symbols ||= []
      return @boss_effects_db_symbols
    end

    # Set the boss effects, clearing the memoized battle list so it rebuilds.
    # @param db_symbols [Array<Symbol>]
    def boss_effects_db_symbols=(db_symbols)
      @boss_effects_db_symbols = db_symbols
      @boss_effects = nil
    end

    # The first boss effect attached to the Pokemon (nil = none).
    # @return [Symbol, nil]
    def boss_effect_db_symbol
      return boss_effects_db_symbols.first
    end

    # Set a single boss effect (nil clears every boss effect).
    # @param db_symbol [Symbol, nil]
    def boss_effect_db_symbol=(db_symbol)
      self.boss_effects_db_symbols = db_symbol ? [db_symbol] : []
    end
  end
end
