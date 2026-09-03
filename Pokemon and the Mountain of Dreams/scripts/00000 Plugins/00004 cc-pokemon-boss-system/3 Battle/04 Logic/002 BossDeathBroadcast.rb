module Battle
  class Logic
    class DamageHandler < ChangeHandlerBase
      module BossDeathBroadcast
        # Function handling the post damage death events
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def handle_post_damage_death_events(hp, target, launcher, skill)
          super
          logic.all_alive_battlers.each do |battler|
            next if battler == launcher || battler == target

            battler.boss_effects.each { |effect| effect.on_post_damage_death(self, hp, target, launcher, skill) }
          end
        end
      end

      prepend BossDeathBroadcast
    end
  end
end
