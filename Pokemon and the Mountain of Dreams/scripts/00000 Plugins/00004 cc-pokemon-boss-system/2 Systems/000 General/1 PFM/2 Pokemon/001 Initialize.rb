module PFM
  class Pokemon
    module PokemonBossPatch
      # Create a new Pokemon with specific parameters.
      # @param id [Integer, Symbol] ID of the Pokemon in the database.
      # @param level [Integer] Level of the Pokemon.
      # @param force_shiny [Boolean] If the Pokemon have 100% chance to be shiny.
      # @param no_shiny [Boolean] If the Pokemon have 0% chance to be shiny. (override force_shiny)
      # @param form [Integer] Form index of the Pokemon. (-1 = automatic generation)
      # @param opts [Hash] Hash describing optional value you want to assign to the Pokemon.
      def initialize(id, level, force_shiny = false, no_shiny = false, form = -1, opts = {})
        super
        @boss = opts[:boss] || false
        @nb_bars_hp = (opts[:nb_bars_hp] || 0).clamp(0, MAX_BOSS_BARS)
        @boss_aura = opts.key?(:boss_aura) ? opts[:boss_aura] : opts[:boss_halo]
        @boss_effects_db_symbols = Array(opts[:boss_effects] || opts[:boss_effect_db_symbol]).compact
      end
    end

    prepend PokemonBossPatch
  end
end
