module PFM
  # Class defining a Pokemon during a battle, it aims to copy its properties but also to have the methods related to the battle.
  class PokemonBattler < Pokemon
    module PokemonBattlerBossPatch
      # Create a new PokemonBattler from a Pokemon.
      # @param original [PFM::Pokemon] original Pokemon. (protected during the battle)
      # @param scene [Battle::Scene] current battle scene.
      # @param max_level [Integer] new max level for Online battle.
      def initialize(original, scene, max_level = Float::INFINITY)
        super
        @boss = original.boss || false
        @nb_bars_hp = original.nb_bars_hp || 0
        @boss_aura = original.boss_aura
        @boss_effects_db_symbols = original.boss_effects_db_symbols.dup
        @boss_aura_flared = false
      end

      # Tell whether the aura of the Boss already flared up during this battle, a battler being
      # built for one battle and kept across its switches.
      # @return [Boolean]
      def boss_aura_flared?
        return @boss_aura_flared == true
      end

      # Remember whether the aura of the Boss already flared up during this battle
      # @param flared [Boolean]
      def boss_aura_flared=(flared)
        @boss_aura_flared = flared
      end

      # Return if the Pokemon is a Boss.
      # @return [Boolean]
      def boss?
        return @boss
      end

      # Label shown on the boss banner (BattleUI::BossBar).
      # @return [String]
      def boss_bar_name
        return PFM::Text.boss_name(self)
      end
    end

    prepend PokemonBattlerBossPatch
  end
end
