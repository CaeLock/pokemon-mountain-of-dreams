module Battle
  class Logic
    class DamageHandler < ChangeHandlerBase
      # Processes the damage dealt to a boss or another Pokémon.
      # @param hp [Integer] The amount of HP (damage) dealt.
      # @param target [PFM::PokemonBattler] The target Pokémon receiving the damage.
      # @param launcher [PFM::PokemonBattler, nil] The Pokémon that launched the move, if applicable.
      # @param skill [Battle::Move, nil] The move used, if applicable.
      # @param messages [Proc] The messages shown right before the post-processing.
      def damage_change_boss(hp, target, launcher = nil, skill = nil, &messages)
        handle_damage(hp, target, launcher, skill, &messages)

        target.add_damage_to_history(hp, launcher, skill, target.dead?)
        log_data("# damage_change(#{hp}, #{target}, #{launcher}, #{skill}, #{target.dead?})")
        @scene.visual.refresh_info_bar(target)
      end

      # Function that drains a certain quantity of HP from the target and gives it to the user.
      # @param hp_factor [Integer] The division factor of HP to drain.
      # @param target [PFM::PokemonBattler] The target that gets HP drained.
      # @param launcher [PFM::PokemonBattler] The launcher of a draining move/effect.
      # @param skill [Battle::Move, nil] The potential move used.
      # @param hp_overwrite [Integer, nil] The number of HP drained by the move, if provided.
      # @param drain_factor [Integer] The division factor of HP drained.
      # @param messages [Proc] The messages shown right before the post-processing.
      def drain_boss(hp_factor, target, launcher, skill = nil, hp_overwrite: nil, drain_factor: 1, &messages)
        hp = hp_overwrite || (target.max_hp / hp_factor).clamp(1, Float::INFINITY)
        handle_damage(hp, target, launcher, skill, drain_factor: drain_factor, source: :drain, &messages)

        target.add_damage_to_history(hp, launcher, skill, target.dead?)
        log_data("# drain_boss(#{hp}, #{target}, #{launcher}, #{skill}, #{target.dead?})")
        @scene.visual.refresh_info_bar(target)
      end

      private

      # Calculates the damage dealt, checks for knockout, and updates the skill damage if applicable.
      # @param hp [Integer] The amount of HP (damage) dealt.
      # @param target [PFM::PokemonBattler] The target Pokémon receiving the damage.
      # @param launcher [PFM::PokemonBattler, nil] The Pokémon that launched the move, if applicable.
      # @param skill [Battle::Move, nil] The move used, if applicable.
      # @param drain_factor [Integer] The division factor of HP drained.
      # @param source [:default, :drain] The source of the damage calculation.
      # @param messages [Proc] The messages shown right before the post-processing.
      def handle_damage(hp, target, launcher, skill, drain_factor: 1, source: :default, &messages)
        update_skill_damage(hp, target, skill)

        return handle_knockout(hp, target, launcher, skill, drain_factor, source, &messages) if hp >= target.hp

        show_hp_animations(hp, target, skill, &messages)
        handle_drain_effects(hp, target, launcher, skill, drain_factor) if source == :drain
        handle_post_damage_events(hp, target, launcher, skill)
      end

      # Handles the specific logic for draining HP and transferring it to the launcher.
      # @param hp [Integer] The amount of HP (damage) dealt.
      # @param target [PFM::PokemonBattler] The target Pokémon receiving the damage.
      # @param launcher [PFM::PokemonBattler] The launcher of a draining move/effect.
      # @param skill [Battle::Move, nil] The move used, if applicable.
      # @param drain_factor [Integer] The division factor of HP drained.
      def handle_drain_effects(hp, target, launcher, skill, drain_factor)
        hp_multiplier = 1.0
        log_data("# drain hp_multiplier = #{hp_multiplier} before pre_drain hook")
        hp_multiplier *= calculate_pre_drain_multiplier(hp, target, launcher, skill)
        log_data("# drain hp_multiplier = #{hp_multiplier} after pre_drain hook")

        hp_healed = (hp * hp_multiplier / drain_factor).to_i.clamp(1, Float::INFINITY)
        result = handle_drain_prevention(hp, hp_healed, target, launcher, skill)
        return false if result == :prevent

        hp_healed = result if result.is_a?(Integer)
        log_data("# drain drain_appliable? #{hp_healed > 0} after drain_prevention hook")

        return if hp_healed <= 0 || launcher.dead?
        return unless can_heal?(launcher) && heal(launcher, hp_healed) {}

        @scene.display_message_and_wait(parse_text_with_pokemon(19, 905, target))
      end

      # Handles the knockout of a Pokémon, considering special cases for bosses.
      # @param hp [Integer] The amount of HP (damage) dealt.
      # @param target [PFM::PokemonBattler] The target Pokémon receiving the damage.
      # @param launcher [PFM::PokemonBattler, nil] The Pokémon that launched the move, if applicable.
      # @param skill [Battle::Move, nil] The move used, if applicable.
      # @param drain_factor [Integer] The division factor of HP drained.
      # @param source [:default, :drain] The source of the damage calculation.
      # @param messages [Proc] The messages shown right before the post-processing.
      def handle_knockout(hp, target, launcher, skill, drain_factor, source, &messages)
        return handle_boss_bar_removal(hp, target, launcher, skill, drain_factor, source, &messages) if target.nb_bars_hp > 1

        show_hp_animations(hp, target, skill, &messages)
        handle_drain_effects(hp, target, launcher, skill, drain_factor) if source == :drain
        handle_post_damage_death_events(hp, target, launcher, skill)
        target.ko_count += 1
      end

      # Handles the removal of one or more health bars from a boss, cascading the overkill through the
      # bars. Each broken bar the boss survives is not a real KO; only the last bar (if the overkill
      # reaches it) is a true KO.
      # @param hp [Integer] The amount of HP (damage) dealt.
      # @param target [PFM::PokemonBattler] The target Pokémon receiving the damage.
      # @param launcher [PFM::PokemonBattler, nil] The Pokémon that launched the move, if applicable.
      # @param skill [Battle::Move, nil] The move used, if applicable.
      # @param drain_factor [Integer] The division factor of HP drained.
      # @param source [:default, :drain] The source of the damage calculation.
      # @param messages [Proc] The messages shown right before the post-processing.
      def handle_boss_bar_removal(hp, target, launcher, skill, drain_factor, source, &messages)
        path = target.boss_hp_path(-hp)
        breaks = path.crossings

        # One timeline for the whole hit: the bars cascading and the drain on the bar the boss ends on.
        @scene.visual.show_boss_hp_animation(target, path, skill&.effectiveness, &messages)

        # Then the after-effects, so the bar-loss recap message only lands once the animation is over.
        handle_drain_effects(hp, target, launcher, skill, drain_factor) if source == :drain
        breaks.times { handle_bar_break_event(target, skill) }

        if path.knocked_out
          handle_post_damage_death_events(hp, target, launcher, skill)
          target.ko_count += 1
          return
        end

        # The creature survived the hit, so it is an ordinary non-lethal damage event for the engine.
        display_bar_loss_message(target, breaks)
        handle_post_damage_events(hp, target, launcher, skill)
      end

      # Show the bar-loss recap message, choosing the singular or plural variant by count.
      # @param target [PFM::PokemonBattler] The target Pokémon that lost bars.
      # @param breaks [Integer] number of bars lost during the hit.
      def display_bar_loss_message(target, breaks)
        # 0 = "lost a life bar", 4 = "lost several life bars" (each has 3 ally/wild/foe variants)
        bar_text_id = breaks > 1 ? 4 : 0
        @scene.display_message_and_wait(parse_text_with_pokemon(10_000, bar_text_id, target))
      end

      # Tell the boss effects a single bar broke. Only they hear it: a broken bar is not a KO, so the
      # engine's death hooks are none of its business.
      # @param target [PFM::PokemonBattler] The target Pokémon that lost the bar.
      # @param skill [Battle::Move, nil] The move used, if applicable.
      def handle_bar_break_event(target, skill)
        logic.all_alive_battlers.each do |battler|
          battler.boss_effects.each { |effect| effect.on_bar_break(self, target, skill) }
        end
      end
    end
  end
end
