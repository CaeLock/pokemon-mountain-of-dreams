module PFM
  class PokemonBattler < Pokemon
    module PokemonBattlerBossFormRevert
      # Copy all the properties back to the original pokemon
      # @note @form is part of BACK_PROPERTIES, so a transformed boss must drop its form first: the engine
      #   only reverts the player's creatures, and a caught boss would keep its Mega form for good.
      def copy_properties_back_to_original
        return super unless boss?

        unmega_evolve
        unprimal_evolve

        return super
      end
    end

    prepend PokemonBattlerBossFormRevert
  end
end
