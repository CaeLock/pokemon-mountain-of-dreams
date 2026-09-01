module Battle
  module Effects
    class Boss
      class Mega < Boss
        # Species that revert to a Primal form instead of Mega Evolving.
        # @return [Array<Symbol>]
        PRIMAL_SPECIES = %i[groudon kyogre]

        # Form index taken when the boss Mega Evolves (31 is the second Mega form of Charizard and Mewtwo).
        # @return [Integer]
        def mega_form
          return 30
        end

        # Function called when one of the creature's HP bars breaks, once per bar broken.
        # @param handler [Battle::Logic::DamageHandler]
        # @param target [PFM::PokemonBattler] the creature that lost the bar
        # @param skill [Battle::Move, nil] Potential move used
        def on_bar_break(handler, target, skill)
          return if target != @target
          return if @transformed

          transform(handler.scene)
        end

        private

        # Take the last stand form: Primal Reversion for the species that have one, Mega Evolution otherwise.
        # @param scene [Battle::Scene]
        def transform(scene)
          return primal_reversion(scene) if PRIMAL_SPECIES.include?(@target.db_symbol)

          mega_evolution(scene)
        end

        # Mega Evolve without the Mega Stone, doing nothing when the species has no such form.
        # @param scene [Battle::Scene]
        def mega_evolution(scene)
          return unless @target.boss_mega_evolve(mega_form)

          @transformed = true
          scene.visual.show_boss(@target)
          scene.visual.show_mega_animation(@target)
          scene.display_message_and_wait(parse_text_with_pokemon(19, 1168, @target, PFM::Text::PKNAME[1] => @target.given_name))
          refresh_ability(scene)
        end

        # Revert to the Primal form, which needs no orb either.
        # @param scene [Battle::Scene]
        def primal_reversion(scene)
          return if @target.form == @target.primal_form(:primal)

          @target.primal_evolve
          @transformed = true
          scene.visual.show_boss(@target)
          scene.visual.show_switch_form_animation(@target)
          scene.display_message_and_wait(parse_text_with_pokemon(19, 1241, @target))
          refresh_ability(scene)
        end

        # Re-trigger the switch-in hook of the ability the new form brought in, like Actions::Mega does.
        # @param scene [Battle::Scene]
        def refresh_ability(scene)
          @target.ability_effect.on_switch_event(scene.logic.switch_handler, @target, @target)
        end
      end

      register(:mega_boss, Mega)
    end
  end
end
