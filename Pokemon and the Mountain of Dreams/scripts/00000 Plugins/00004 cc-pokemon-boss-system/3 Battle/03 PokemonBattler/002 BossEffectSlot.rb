module PFM
  class PokemonBattler < Pokemon
    module PokemonBattlerBossEffectSlot
      # Get the boss effects of the Pokemon (empty when it has none).
      # Memoized outside @effects like ability_effect/item_effect, so it persists across switches.
      # @return [Array<Battle::Effects::Boss>]
      def boss_effects
        @boss_effects ||= boss_effects_db_symbols.map do |db_symbol|
          Battle::Effects::Boss.new(@scene.logic, self, db_symbol)
        end

        return @boss_effects
      end
    end

    prepend PokemonBattlerBossEffectSlot
  end
end
