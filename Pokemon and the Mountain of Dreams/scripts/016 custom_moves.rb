module Battle
  module Effects
    # Same recurring-bind mechanic as Effects::Bind, but the periodic damage
    # is calculated as Electric-type damage (via the move's own type_modifier)
    # instead of a flat, typeless fraction of max HP.
    class ElectricBind < Bind
      # Function called at the end of a turn
      # @param logic [Battle::Logic] logic of the battle
      # @param scene [Battle::Scene] battle scene
      # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
      def on_end_turn_event(logic, scene, battlers)
        return kill if @origin.dead?
        return if @pokemon.dead?
        return if @pokemon.has_ability?(:magic_guard)

        multiplier = @move.type_modifier(@origin, @pokemon)
        if multiplier.zero?
          scene.display_message_and_wait("#{@pokemon.given_name} is unaffected by the storm!")
          return
        end

        scene.display_message(message)
        damage = (@pokemon.max_hp / hp_factor * multiplier).clamp(1, Float::INFINITY).round
        logic.damage_handler.damage_change(damage, @pokemon)
      end

      # @return [Symbol]
      def name
        return :electric_bind
      end

      private

      # @return [String]
      def message
        return "#{@pokemon.given_name} is buffeted by the storm's electric current!"
      end
    end
  end
end

module Battle
  class Move
    # Against the Storm: binds all enemy Pokémon like Wrap, but the recurring
    # damage is calculated as Electric-type (respects weaknesses, resistances,
    # and immunities), instead of the flat typeless fraction Bind/Sand Tomb/
    # Wrap/etc. normally deal. Also summons Rain, exactly like Rain Dance.
    class AgainstTheStorm < BasicWithSuccessfulEffect
      private
      # The secondary effect always triggers - weather is set regardless of
      # whether every target could actually be bound (e.g. already bound).
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        true
      end

      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        nb_turn = user.hold_item?(:damp_rock) ? 8 : 5
        logic.weather_change_handler.weather_change_with_process(:rain, nb_turn)

        turn_count = user.hold_item?(:grip_claw) ? 7 : logic.generic_rng.rand(4..5)
        actual_targets.each do |target|
          next if target.effects.has?(:bind)
          target.effects.add(Effects::ElectricBind.new(logic, target, user, turn_count, self))
        end
      end
    end
    Move.register(:s_against_the_storm, AgainstTheStorm)
  end
end

module Battle
  class Move
    # Luminous Trail: creates a Substitute like normal, but its HP depends on
    # a speed check against the fastest living opponent on the field:
    #  - user faster than the fastest opposing Pokémon -> normal Substitute (clamped at 170 HP)
    #  - user not faster (tied or slower) -> Substitute created with only 1 HP
    class LuminousTrail < Substitute
      private

      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do
          next if user.hp_rate <= (1.0 / factor)

          fastest_foe_spd = logic.foes_of(user).map(&:spd).max || 0
          if user.spd > fastest_foe_spd
            hp = (user.max_hp / factor).floor.clamp(1, 170)
            log_data("[Luminous Trail] #{user.given_name} is faster (#{user.spd} vs #{fastest_foe_spd}) - Substitute created with #{hp} HP")
          else
            hp = 1
          end

          logic.damage_handler.damage_change(hp, user)
          user.effects.add(Effects::CustomHPSubstitute.new(logic, user, hp))
          scene.display_message_and_wait(parse_text_with_pokemon(19, 785, user))
        end
      end
    end
    Move.register(:s_luminous_trail, LuminousTrail)
  end
end

module Battle
  module Effects
    # Same as Effects::Substitute, but with a caller-specified HP amount
    # instead of the fixed max_hp / 4.
    class CustomHPSubstitute < Substitute
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param hp [Integer] the exact HP to give this substitute
      def initialize(logic, pokemon, hp)
        super(logic, pokemon)
        @hp = @max_hp = hp
      end
    end
  end
end