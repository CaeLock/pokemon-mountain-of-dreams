module Battle
  module Effects
    class Boss
      class Siphon < Boss
        # Create a new boss effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the boss effect
        def initialize(logic, target, db_symbol)
          super
          @starting_bars = target.nb_bars_hp
        end

        # Function called after damages were applied and when target died (post_damage_death)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage_death(handler, hp, target, launcher, skill)
          return if @target.dead?
          return if target.bank == @target.bank

          siphon(handler)
        end

        # Heal ratio applied to the computed absorption (tune down for a gentler boss).
        # @return [Float]
        def feed_ratio
          return 1.0
        end

        private

        # Absorb the fallen foe's vital energy: heal the boss by the inverse-scaled amount, announced.
        # @param handler [Battle::Logic::DamageHandler]
        def siphon(handler)
          amount = feed_amount
          return if amount <= 0

          handler.scene.visual.show_boss(@target)
          handler.heal_boss(@target, amount)
          handler.scene.display_message_and_wait(parse_text_with_pokemon(10_000, 44, @target))
        end

        # The inverse-scaled heal amount, clamped to the room left up to the starting bars.
        # @return [Integer]
        def feed_amount
          return 0 if @starting_bars <= 0

          max_hp = @target.max_hp
          starting_max = @starting_bars * max_hp
          current_total = @target.total_hp
          rate = current_total.to_f / starting_max
          heal = [((1.0 - 0.5 * rate) * max_hp * feed_ratio).to_i, 1].max
          return [heal, starting_max - current_total].min
        end
      end

      register(:siphon_boss, Siphon)
    end
  end
end
