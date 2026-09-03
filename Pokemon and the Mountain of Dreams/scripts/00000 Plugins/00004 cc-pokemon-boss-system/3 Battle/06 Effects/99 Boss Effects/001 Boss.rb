module Battle
  module Effects
    # Base class describing a boss effect
    class Boss < EffectBase
      # Get the db_symbol of the boss effect (:__undef__ when the battler has none)
      # @return [Symbol]
      attr_reader :db_symbol
      # Get the battler this boss effect is tied to
      # @return [PFM::PokemonBattler]
      attr_reader :target

      @registered_bosses = {}

      # Create a new boss effect
      # @param logic [Battle::Logic]
      # @param target [PFM::PokemonBattler]
      # @param db_symbol [Symbol] db_symbol of the boss effect
      def initialize(logic, target, db_symbol)
        super(logic)
        @target = target
        @db_symbol = db_symbol
      end

      # Function called when one of the creature's HP bars breaks, once per bar broken. The creature
      # survives it, so this is not a knockout: the engine's death hooks stay out of it.
      # @param handler [Battle::Logic::DamageHandler]
      # @param target [PFM::PokemonBattler] the creature that lost the bar
      # @param skill [Battle::Move, nil] Potential move used
      def on_bar_break(handler, target, skill)
        nil && handler && target && skill
      end

      class << self
        # Register a boss effect
        # @param db_symbol [Symbol] db_symbol of the boss effect
        # @param klass [Class<Boss>] class of the boss effect
        def register(db_symbol, klass)
          @registered_bosses[db_symbol] = klass
        end

        # Create a new boss effect matching the db_symbol (base Boss when unregistered)
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol]
        # @return [Boss]
        def new(logic, target, db_symbol)
          klass = @registered_bosses[db_symbol] || Boss
          object = klass.allocate
          object.send(:initialize, logic, target, db_symbol)
          return object
        end
      end
    end
  end
end
