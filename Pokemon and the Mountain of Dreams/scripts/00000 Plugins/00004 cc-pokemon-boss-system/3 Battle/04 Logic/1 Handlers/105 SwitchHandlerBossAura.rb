module Battle
  class Logic
    class SwitchHandler < ChangeHandlerBase
      # Lights the aura of a Boss reaching the field, on the first turn as well as after a switch.
      module BossAuraSwitchPatch
        # Perform the switch between two Pokemon
        # @param who [PFM::PokemonBattler] Pokemon who is switched out
        # @param with [PFM::PokemonBattler, nil] Pokemon who is switched in
        # @note In the event we're starting the battle who & with should be identic, this help to process effect like Intimidate
        def execute_switch_events(who, with)
          super
          scene.visual.show_boss_aura_on_entry(with)
        end
      end

      prepend BossAuraSwitchPatch
    end
  end
end
