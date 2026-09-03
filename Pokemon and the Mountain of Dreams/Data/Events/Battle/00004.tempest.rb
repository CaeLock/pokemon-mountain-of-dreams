# Data/Events/Battle/0004 Tempest.rb
#
# Scripted AI for the Tempest boss, for this specific encounter only.
# The five digits in the filename ARE the battle_id - rename the file (and set
# the trainer's Battle Group ID in Studio, or `bi.battle_id = 42` from script)
# to match whichever battle_id this fight actually uses.
#
# Before bar break: Agility on turn 1; Luminous Trail once no Substitute is up
# and (Agility was just used or Speed is maxed); Agility again every 5th turn
# while Speed isn't maxed; otherwise normal AI (level 5 equivalent).
#
# After bar break: Against the Storm if foes aren't both bound or it isn't
# raining; Abyssal Fluorescence if foes aren't both confused or any foe raised
# evasion above +1; otherwise normal AI (level 5 equivalent).
#
# Depends on Effects::Boss::Tempest (for #bar_broken?) from the Tempest boss script.

module Battle
  class Scene
    register_event(:AI_force_action) do |scene, ai, index|
      tempest = ai.controlled_pokemon.find { |pkmn| pkmn.boss_effects.any? { |e| e.is_a?(Effects::Boss::Tempest) } }
      next nil unless tempest

      tempest_effect = tempest.boss_effects.find { |e| e.is_a?(Effects::Boss::Tempest) }
      move_db_symbol = tempest_effect.bar_broken? ? scene.tempest_after_bar_break_move(tempest) : scene.tempest_before_bar_break_move(tempest)
      scene.instance_variable_set(:@tempest_used_agility_last_turn, move_db_symbol == :agility)

      if move_db_symbol.nil?
        ai5 = Battle::AI.registered(5).new(scene, tempest.bank, tempest.party_id, 5)
        next [ai5.send(:battle_action_for, tempest)]
      end

      move = tempest.skills_set.find { |skill| skill&.db_symbol == move_db_symbol }
      raise "Tempest boss is missing move #{move_db_symbol} in its moveset" unless move

      target = %i[agility luminous_trail].include?(move_db_symbol) ? tempest : scene.logic.foes_of(tempest).find(&:alive?)
      next nil unless target

      next [Battle::Actions::Attack.new(scene, move, tempest, target.bank, target.position)]
    end

    # @param tempest [PFM::PokemonBattler]
    # @return [Symbol, nil] move to force before the first bar breaks, nil = fall back to normal AI
    def tempest_before_bar_break_move(tempest)
      return :agility if tempest.turn_count <= 1

      no_substitute = !tempest.effects.has?(:substitute)
      agility_maxed = tempest.spd_stage >= 6
      used_agility_last_turn = instance_variable_get(:@tempest_used_agility_last_turn)
      return :luminous_trail if no_substitute && (used_agility_last_turn || agility_maxed)

      return :agility if !agility_maxed && (tempest.turn_count % 5).zero?

      return nil
    end

    # @param tempest [PFM::PokemonBattler]
    # @return [Symbol, nil] move to force after a bar has broken, nil = fall back to normal AI
    def tempest_after_bar_break_move(tempest)
      foes = logic.foes_of(tempest)

      no_binds = foes.all? { |foe| !foe.effects.has?(:bind) }
      not_raining = !logic.current_weather?(:rain)
      return :against_the_storm if no_binds || not_raining

      no_confusion = foes.all? { |foe| !foe.confused? }
      evasion_boosted = foes.any? { |foe| foe.eva_stage > 1 }
      return :abyssal_fluorescence if no_confusion || evasion_boosted

      return nil
    end
  end
end