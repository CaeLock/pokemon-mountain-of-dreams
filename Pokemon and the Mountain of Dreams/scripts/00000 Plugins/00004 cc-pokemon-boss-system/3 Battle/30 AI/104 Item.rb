module Battle
  module AI
    class Base
      # Teaches the trainer AI that a Boss has more life than the bar it is standing on. Only the AI
      # levels that heal read these, so it changes nothing for a wild Boss (level 5 never heals).
      module BaseBossHealPatch
        private

        # Generate the item action for the pokemon
        # @param pokemon [PFM::PokemonBattler]
        # @param move_heuristics [Array<Float>]
        # @return [Array<[Float, Actions::Item]>]
        # @note Copied from 5 Battle/30 AI/104 Item.rb:37, with total_hp_rate in place of hp_rate.
        def item_actions_for(pokemon, move_heuristics)
          actions = boost_item_actions_for(pokemon, move_heuristics)
          actions.concat(heal_item_actions_for(pokemon, move_heuristics)) if @can_heal && pokemon.total_hp_rate <= @heal_threshold && !pokemon.dead?
          actions.concat(status_heal_item_actions_for(pokemon, move_heuristics)) if @can_heal && pokemon.status != 0

          return actions
        end

        # Generate the heal item action for the pokemon
        # @param pokemon [PFM::PokemonBattler]
        # @param move_heuristics [Array<Float>]
        # @return [Array<[Float, Actions::Item]>]
        # @note Copied from 5 Battle/30 AI/104 Item.rb:71, with the healed share taken over every bar.
        def heal_item_actions_for(pokemon, move_heuristics)
          HEALING_ITEMS.select { |item| pokemon.bag.contain_item?(item) }.map do |item|
            wrapper = PFM::ItemDescriptor.actions(item)
            wrapper.bind(@scene, pokemon)
            factor = healed_share(wrapper.item, pokemon) * 2.0
            next [factor, Actions::Item.new(@scene, wrapper, pokemon.bag, pokemon)]
          end.compact
        end

        # Share of the creature's whole life a healing item restores. A potion worth a quarter of a bar
        # is worth a lot less to a Boss standing on three of them.
        # @param item [Studio::Item]
        # @param pokemon [PFM::PokemonBattler]
        # @return [Float]
        def healed_share(item, pokemon)
          healed = item.is_a?(Studio::ConstantHealItem) ? item.hp_count.to_f : item.hp_rate * pokemon.max_hp

          return healed / pokemon.total_max_hp
        end
      end

      prepend BaseBossHealPatch
    end
  end
end
