module Battle
  class Move
    module BossDamageCapPatch
      # Damage the move computed before it was capped to what the target could take
      # @return [Integer, nil]
      attr_reader :uncapped_damage

      # Method calculating the damages done by the actual move
      # @note : I used the 4th Gen formula : https://www.smogon.com/dp/articles/damage_formula
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @note The formula is the following:
      #       (((((((Level * 2 / 5) + 2) * BasePower * [Sp]Atk / 50) / [Sp]Def) * Mod1) + 2) *
      #         CH * Mod2 * R / 100) * STAB * Type1 * Type2 * Mod3)
      # @return [Integer]
      def damages(user, target)
        return super unless cascading_boss?(target)

        # rubocop:disable Layout/ExtraSpacing
        # rubocop:disable Layout/SpaceBeforeSemicolon
        # rubocop:disable Style/Semicolon
        log_data("# damages(#{user}, #{target}) for #{db_symbol}")
        # Reset the effectiveness
        @effectiveness = 1
        @critical = logic.calc_critical_hit(user, target, critical_rate)
        damage = user.level * 2 / 5 + 2                                                    ;
        log_data("damage = #{damage} # #{user.level} * 2 / 5 + 2")
        damage = (damage * calc_base_power(user, target)).floor                            ; log_data("damage = #{damage} # after calc_base_power")
        damage = (damage * calc_sp_atk(user, target)).floor / 50                           ; log_data("damage = #{damage} # after calc_sp_atk / 50")
        damage = (damage / calc_sp_def(user, target)).floor                                ; log_data("damage = #{damage} # after calc_sp_def")
        damage = (damage * calc_mod1(user, target)).floor + 2                              ; log_data("damage = #{damage} # after calc_mod1 + 2")
        damage = (damage * calc_ch(user, target)).floor                                    ; log_data("damage = #{damage} # after calc_ch")
        damage = (damage * calc_mod2(user, target)).floor                                  ; log_data("damage = #{damage} # after calc_mod2")
        damage *= logic.move_damage_rng.rand(calc_r_range)
        damage /= 100                                                                      ; log_data("damage = #{damage} # after rng")
        types = definitive_types(user, target)
        damage = (damage * calc_stab(user, types)).floor                                   ; log_data("damage = #{damage} # after stab")
        damage = (damage * calc_type_n_multiplier(target, :type1, types)).floor            ; log_data("damage = #{damage} # after type1")
        damage = (damage * calc_type_n_multiplier(target, :type2, types)).floor            ; log_data("damage = #{damage} # after type2")
        damage = (damage * calc_type_n_multiplier(target, :type3, types)).floor            ; log_data("damage = #{damage} # after type3")
        damage = (damage * calc_mod3(user, target)).floor                                  ; log_data("damage = #{damage} # after mod3")

        target_hp = target.effects.get(:substitute).hp if target.effects.has?(:substitute) && !user.has_ability?(:infiltrator) && !authentic?
        target_hp ||= target.total_hp
        @uncapped_damage = damage
        damage = damage.clamp(1, target_hp)                                                ; log_data("damage = #{damage} # after boss clamp")

        return damage
        # rubocop:enable Layout/ExtraSpacing
        # rubocop:enable Layout/SpaceBeforeSemicolon
        # rubocop:enable Style/Semicolon
      end

      private

      # Whether the target is a Boss whose hit can cascade through its bars.
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Boolean]
      def cascading_boss?(target)
        return target.boss? && target.nb_bars_hp > 1
      end
    end

    prepend BossDamageCapPatch
  end
end
