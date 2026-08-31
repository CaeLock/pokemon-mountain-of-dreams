# Caps the effective BST (sum of the 6 base stats) of the player's Pokemon -
# party AND PC storage - while they're under-leveled for their power, to stop
# an early lucky catch/starter pick from trivializing the early game.
# Wild/trainer Pokemon are never touched, only ones actually owned by the
# player (checked via $actors and PFM::Storage#any_pokemon?).
#
# Tiers (checked in order, first match wins):
#   level < 20          : BST capped at ~400, applies even to evolved Pokemon
#   20 <= level < 25     : BST capped at ~450, evolved Pokemon are exempt
#   25 <= level <= 30    : BST capped at ~500, evolved Pokemon are exempt
#   level > 30           : no cap
#
# "~400/450/500" because the reduction is spread as an EQUAL flat amount
# across all 6 stats (not proportional), so the exact target is usually only
# reachable within a few points depending on how evenly 6 divides the
# required reduction - this is within the allowed +/-5 margin. No single
# stat is ever reduced below 1.
#
# The cap is fully recomputed (not just applied once) every time it could
# change - on becoming owned, leveling up, or evolving - always starting
# from the Pokemon's real species base stats, so it correctly lifts itself
# once the Pokemon grows past level 30 or evolves into an exempt case, and
# correctly re-tightens if a Rare Candy jumps it across a tier boundary.
module PFM
  class Pokemon
    # BST reduction tiers, checked in order. evolved_exempt: true means an
    # evolved Pokemon in this tier is NOT capped.
    BST_CAP_TIERS = [
      {max_level: 19, bst_cap: 400, evolved_exempt: false},
      {max_level: 24, bst_cap: 450, evolved_exempt: true},
      {max_level: 30, bst_cap: 500, evolved_exempt: true}
    ].freeze

    # The 6 stats that make up BST, in the order they're reduced
    BST_STAT_METHODS = %i[base_hp base_atk base_dfe base_spd base_ats base_dfs].freeze

    # Adds the BST cap hooks to Pokemon lifecycle events that can change
    # whether/how much it should apply (becoming owned, leveling, evolving),
    # and makes the base_X stat methods honor an active cap.
    module BSTCapPlugin
      # @param id [Integer, Symbol]
      # @param level [Integer]
      def initialize(id, level, force_shiny = false, no_shiny = false, form = -1, opts = {})
        super
        update_bst_cap
      end

      # Refresh the level-up stats (adds a BST cap recompute after leveling up)
      def level_up_stat_refresh
        result = super
        update_bst_cap
        return result
      end

      # Change the level of the Pokemon (adds a BST cap recompute)
      # @param lvl [Integer]
      def level=(lvl)
        super
        update_bst_cap
      end

      # Evolve the Pokemon (adds a BST cap recompute, since species/exemption changes)
      def evolve(id, form)
        super
        update_bst_cap
      end

      # @return [Boolean] whether this Pokemon is currently in the player's party or PC storage
      def owned_by_player?
        return true if $actors&.include?(self)

        PFM.game_state.storage&.any_pokemon? { |pokemon| pokemon.equal?(self) } == true
      end

      # @return [Boolean] whether this species has evolved from another (i.e. is not first-stage)
      def evolved_species?
        each_data_creature.any? { |creature| creature.forms.any? { |form| form.evolutions.any? { |evo| evo.db_symbol == db_symbol } } }
      end

      # Recomputes (or clears) the BST cap override based on current level,
      # evolution status, and the Pokemon's real (uncapped) species BST.
      # Safe/idempotent to call any time - always starts fresh from species data.
      # Also rebalances current HP if the cap change moved max_hp, using the
      # same missing-HP-preserving technique as the native level_up_stat_refresh,
      # so a Pokemon exiting the cap doesn't end up looking "damaged" just
      # because its max HP jumped back up.
      def update_bst_cap
        old_max_hp = max_hp
        apply_bst_cap_overrides
        rebalance_hp_after_cap_change(old_max_hp)
      end

      private

      # Pure recompute step: decides and applies (or clears) @bst_cap_overrides.
      # No HP side effects - update_bst_cap handles that separately.
      def apply_bst_cap_overrides
        return clear_bst_cap unless owned_by_player?

        tier = BST_CAP_TIERS.find { |t| level <= t[:max_level] }
        return clear_bst_cap unless tier
        return clear_bst_cap if tier[:evolved_exempt] && evolved_species?

        original = BST_STAT_METHODS.map { |method_name| data.send(method_name) }
        total = original.sum
        return clear_bst_cap if total <= tier[:bst_cap]

        per_stat_reduction = ((total - tier[:bst_cap]) / 6.0).round
        @bst_cap_overrides = BST_STAT_METHODS.each_with_index.to_h do |method_name, index|
          [method_name, [original[index] - per_stat_reduction, 1].max]
        end
      end

      # Preserves the amount of missing HP (rather than the HP ratio) across a
      # max_hp change caused by the cap being applied/tightened/loosened/cleared -
      # identical logic to what level_up_stat_refresh already does for a normal
      # level's max_hp growth.
      # @param old_max_hp [Integer] max_hp before the cap was recomputed
      def rebalance_hp_after_cap_change(old_max_hp)
        new_max_hp = max_hp
        return if new_max_hp == old_max_hp
        return unless @hp && @hp > 0

        hp_diff = old_max_hp - @hp
        self.hp = new_max_hp - hp_diff
      end

      public

      # Removes any active BST cap override, restoring the Pokemon's real species stats
      def clear_bst_cap
        @bst_cap_overrides = nil
      end

      # @return [Integer]
      def base_hp
        @bst_cap_overrides ? @bst_cap_overrides[:base_hp] : super
      end

      # @return [Integer]
      def base_atk
        @bst_cap_overrides ? @bst_cap_overrides[:base_atk] : super
      end

      # @return [Integer]
      def base_dfe
        @bst_cap_overrides ? @bst_cap_overrides[:base_dfe] : super
      end

      # @return [Integer]
      def base_spd
        @bst_cap_overrides ? @bst_cap_overrides[:base_spd] : super
      end

      # @return [Integer]
      def base_ats
        @bst_cap_overrides ? @bst_cap_overrides[:base_ats] : super
      end

      # @return [Integer]
      def base_dfs
        @bst_cap_overrides ? @bst_cap_overrides[:base_dfs] : super
      end
    end
    prepend BSTCapPlugin
  end
end

module PFM
  class GameState
    # Adds a BST cap recompute whenever a Pokemon becomes owned by the player
    # (covers scripted gifts, battle captures, GTS, quest rewards, shop eggs -
    # every acquisition path funnels through this one method).
    module BSTCapOnAcquirePlugin
      # @param pkmn [PFM::Pokemon]
      def add_pokemon(pkmn)
        result = super
        pkmn.update_bst_cap
        return result
      end
    end
    prepend BSTCapOnAcquirePlugin
  end
end