# Relentless Boss - Pokemon Boss System extension
#
# - Auto-cures its own status after 3 turns (4 if poisoned/badly poisoned)
# - Infinite PP
# - Multiple attacks per turn, count set by a game variable (default 1)
#
# Also includes scale_boss_level, a general level-scaling helper usable on any
# boss (not Relentless-specific), called before the battle starts.
#
# Usage:
#   boss = PFM::Pokemon.new(:whatever, 50)
#   scale_boss_level(boss)
#   boss.boss = true
#   boss.nb_bars_hp = 3
#   boss.boss_effects_db_symbols += [:relentless_boss]
#   call_battle_boss(boss)

module Battle
  module Effects
    class Boss
      class Relentless < Boss
        STATUS_CURE_DURATION = { poison: 4, toxic: 4 }.freeze
        DEFAULT_STATUS_CURE_DURATION = 3

        def initialize(logic, target, db_symbol)
          super
          @tracked_status = target.status
          @turns_with_status = 0
        end

        # Function called at the end of a turn
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target)
          return if @target.dead?

          current_status = @target.status
          if current_status != @tracked_status
            @tracked_status = current_status
            @turns_with_status = 0
            return
          end
          return if current_status.zero?

          @turns_with_status += 1
          threshold = STATUS_CURE_DURATION[Configs.states.symbol(current_status)] || DEFAULT_STATUS_CURE_DURATION
          return if @turns_with_status < threshold

          scene.visual.show_boss(@target)
          logic.status_change_handler.status_change(:cure, @target)
          @turns_with_status = 0
        end
      end

      register(:relentless_boss, Relentless)
    end
  end
end

module Battle
  class Move
    # Patches Move#decrease_pp: adds the infinite-PP case for Relentless bosses,
    # delegates to the original behavior for everyone else.
    module RelentlessInfinitePP
      def decrease_pp(user, targets)
        return super unless user.boss? && user.boss_effects.any? { |e| e.is_a?(Effects::Boss::Relentless) }
      end
    end
    prepend RelentlessInfinitePP
  end
end

module Battle
  class Logic
    # Patches Logic#sort_actions and Logic#perform_next_action: grants Relentless
    # bosses extra attacks per turn. Both always call super first; this only adds
    # behavior on top, it never blocks the original.
    module RelentlessMultiAction
      # Game variable controlling attacks/turn for Relentless bosses. 0 or unset = default of 1.
      ATTACKS_PER_TURN_VARIABLE_ID = 900

      def sort_actions
        super
        all_alive_battlers.each do |battler|
          next unless battler.boss? && battler.boss_effects.any? { |e| e.is_a?(Effects::Boss::Relentless) }
          attacks = $game_variables[ATTACKS_PER_TURN_VARIABLE_ID]
          battler.instance_variable_set(:@relentless_attacks_left, (attacks && attacks > 0) ? attacks : 1)
        end
      end

      def perform_next_action
        action = @actions.last
        result = super
        return result unless action.is_a?(Actions::Attack)

        launcher = action.launcher
        return result unless launcher.alive? && launcher.boss? && launcher.boss_effects.any? { |e| e.is_a?(Effects::Boss::Relentless) }

        attacks_left = (launcher.instance_variable_get(:@relentless_attacks_left) || 1) - 1
        launcher.instance_variable_set(:@relentless_attacks_left, attacks_left)
        if attacks_left > 0
          target_bank = action.instance_variable_get(:@target_bank)
          target_position = action.instance_variable_get(:@target_position)
          @actions.push(Actions::Attack.new(@scene, action.move, launcher, target_bank, target_position))
        end
        return result
      end
    end
    prepend RelentlessMultiAction
  end
end

class Interpreter
  # new_level = base_level + (gap to the party's strongest member, rounded to nearest 5)
  # @param pokemon [PFM::Pokemon]
  def scale_boss_level(pokemon)
    highest_party_level = $actors.map(&:level).max || pokemon.level
    return if pokemon.level >= highest_party_level

    gap = highest_party_level - pokemon.level
    rounded_gap = (gap / 5.0).round * 5
    pokemon.level += rounded_gap
    pokemon.hp = pokemon.max_hp
  end
end