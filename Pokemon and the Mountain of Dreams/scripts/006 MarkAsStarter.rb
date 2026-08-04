# Adds a "starter" flag to PFM::Pokemon: a plain persisted attribute (saved
# automatically along with everything else on the Pokemon object, same as any
# other ivar) plus a #starter? predicate usable anywhere - including as a
# Script-type event page condition, e.g. an NPC's page condition could check
# `$actors[0]&.starter?` the same way you'd check a switch or variable.
#
# Also blocks starters from being released from the PC/Party storage screen,
# mirroring the same early-return-with-message pattern the engine already
# uses to block releasing an Absofusion'd Kyurem (GamePlay::PokemonStorage#release_pokemon).
module PFM
  class Pokemon
    # @return [Boolean] whether this Pokemon is marked as a starter
    attr_writer :starter

    # @return [Boolean]
    def starter?
      @starter == true
    end
  end
end

module GamePlay
  class PokemonStorage
    # Message shown when trying to release a starter
    STARTER_RELEASE_BLOCKED_MESSAGE = 'This Pokémon cannot be released.'

    # Blocks starters from being released, single or multi-select
    module StarterReleaseBlock
      # Release a Pokemon (blocks starters first)
      def release_pokemon
        return display_message(STARTER_RELEASE_BLOCKED_MESSAGE) if @current_pokemon.starter?

        super
      end

      # Release the selected Pokemon (blocks the whole action if any selected Pokemon is a starter)
      def release_selected_pokemon
        return display_message(STARTER_RELEASE_BLOCKED_MESSAGE) if @current_pokemons.compact.any?(&:starter?)

        super
      end
    end
    prepend StarterReleaseBlock
  end
end