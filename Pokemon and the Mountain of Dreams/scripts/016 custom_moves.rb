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
        return :bind
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
          scene.display_message_and_wait("#{target.given_name} is trapped by the thunderstorm!")
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
    #  - user faster than the fastest opposing Pokémon -> normal Substitute (fixed at 180 HP)
    #  - user not faster (tied or slower) -> Substitute created with only 1 HP
    #
    # The cost paid (COST_FACTOR of max HP) and the Substitute's resulting HP
    # are INTENTIONALLY independent - the cost is a flat toll paid either way,
    # the reward is a separate fixed value depending only on the speed check.
    #
    # Fixed: sub_hp used to be derived from cost (`cost.clamp(1, 180)`), so it
    # was literally equal to cost whenever cost was under 180 - meaning
    # lowering COST_FACTOR (cheaper to use) silently also shrank the
    # Substitute's HP, even though the reward was never supposed to depend on
    # the amount paid. sub_hp is now a flat 180 in the faster branch,
    # completely decoupled from cost/factor.
    class LuminousTrail < Substitute
      # 1 / COST_FACTOR of max HP. Shared with the Tempest AI script's HP check
      # below, via this constant, so both always agree on the actual cost.
      COST_FACTOR = 5 # 20%

      private

      def deal_effect(user, actual_targets)
        actual_targets.each do
          next if user.hp_rate <= (1.0 / factor)

          cost = (user.max_hp / factor).floor.clamp(1, Float::INFINITY)
          fastest_foe_spd = logic.foes_of(user).map(&:spd).max || 0
          if user.spd > fastest_foe_spd
            sub_hp = (user.spd - fastest_foe_spd).clamp(1, 180)
            log_data("[Luminous Trail] #{user.given_name} is faster (#{user.spd} vs #{fastest_foe_spd}) - Substitute created with #{sub_hp} HP")
          else
            sub_hp = 1
          end

          logic.damage_handler.damage_change(cost, user)
          user.effects.add(Effects::CustomHPSubstitute.new(logic, user, sub_hp))
          scene.display_message_and_wait(parse_text_with_pokemon(19, 785, user))
        end
      end

      def factor
        return COST_FACTOR
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