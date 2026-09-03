module Battle
  module Effects
    class Boss
      class Enrage < Boss
        # Create a new boss effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the boss effect
        def initialize(logic, target, db_symbol)
          super
          @incoming_announced = false
          @enrage_announced = false
        end

        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target)
          return if @target.dead?

          announce_incoming_enrage(scene)
          announce_enrage(scene)
        end

        # Function called when we try to check if the effect changes the definitive priority of the move
        # @param user [PFM::PokemonBattler]
        # @param priority [Integer]
        # @param move [Battle::Move]
        # @return [Integer, nil] the new priority, nil when unchanged
        def on_move_priority_change(user, priority, move)
          return nil if user != @target
          return nil unless hard_enraged?

          return priority + hard_enrage_priority
        end

        # Give the move mod3 multiplier (after everything)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def mod3_multiplier(user, target, move)
          return 1 if user != @target

          return ramp_multiplier
        end

        # Number of opening turns kept at x1.0 before the ramp begins.
        # @return [Integer]
        def grace_turns
          return 1
        end

        # Damage multiplier gained each turn once the ramp began.
        # @return [Float]
        def step
          return 0.2
        end

        # Highest damage multiplier the ramp can reach.
        # @return [Float]
        def cap
          return 3.0
        end

        # Turn on which the boss hard-enrages and gains priority, nil disables it.
        # @return [Integer, nil]
        def hard_enrage_turn
          return 6
        end

        # Priority bonus granted once hard-enraged.
        # @return [Integer]
        def hard_enrage_priority
          return 1
        end

        private

        # Current damage multiplier from the turn ramp.
        # @return [Float]
        def ramp_multiplier
          active_turns = [@target.turn_count - grace_turns, 0].max
          return [1 + active_turns * step, cap].min
        end

        # Whether the boss has reached its hard-enrage turn.
        # @return [Boolean]
        def hard_enraged?
          return false if hard_enrage_turn.nil?

          return @target.turn_count >= hard_enrage_turn
        end

        # Telegraph the hard-enrage the turn before it lands.
        # @param scene [Battle::Scene] battle scene
        def announce_incoming_enrage(scene)
          return if @incoming_announced
          return if hard_enrage_turn.nil?
          return unless @target.turn_count == hard_enrage_turn - 1

          @incoming_announced = true
          scene.visual.show_boss(@target)
          scene.display_message_and_wait(parse_text_with_pokemon(10_000, 36, @target))
        end

        # Announce the hard-enrage on the turn it lands.
        # @param scene [Battle::Scene] battle scene
        def announce_enrage(scene)
          return if @enrage_announced
          return if hard_enrage_turn.nil?
          return unless @target.turn_count >= hard_enrage_turn

          @enrage_announced = true
          scene.visual.show_boss(@target)
          scene.display_message_and_wait(parse_text_with_pokemon(10_000, 40, @target))
        end
      end

      register(:enrage_boss, Enrage)
    end
  end
end
