# Adds Interpreter#call_battle_wild_group(group_name, battle_id: 1) - forces a
# wild battle against a RANDOM Pokemon picked from a specific named encounter
# group (Studio::Group, the same kind configured per-map/zone in the editor),
# rather than a specific known Pokemon like call_battle_wild does.
#
# Call from an event's "Call Script":
#   call_battle_wild_group(:my_group_name)
#   call_battle_wild_group(:my_group_name, battle_id: 2)   # custom battle scenario id
#
# How it works: PFM::Wild_Battle#current_selected_group normally picks a group
# by matching the player's CURRENT tile (system_tag/terrain_tag) against the
# groups loaded for the map/zone. There's no built-in way to just say "use
# this group". This adds a one-shot override: current_selected_group returns
# the forced group if one is set, otherwise falls back to the normal
# tile-based lookup unchanged. The override is cleared right after #setup
# runs (in an ensure, so it clears even on failure), so it only affects the
# single battle you're triggering, never a later random encounter.
#
# call_battle_wild_group itself mirrors Wild_Battle#start_battle's own body
# (Graphics.freeze, $scene = Battle::Scene.new(...) or Battle::Safari.new(...)
# depending on BT_Mode, Yuki::FollowMe.set_battle_entry) so it behaves exactly
# like any other wild battle trigger - same transition, same Safari-mode
# handling, same follower behavior.
#
# Note: data_group(group_name) doesn't check that the group actually belongs
# to the current map/zone - any defined group can be forced this way. That's
# intentional flexibility, but worth knowing if you want to guard against
# passing the wrong map's group by mistake.
module PFM
  class Wild_Battle
    # @return [Studio::Group, nil] one-shot override for the next #setup call
    attr_writer :forced_group

    # Makes current_selected_group honor a one-shot forced group, and clears
    # it after #setup runs so it never leaks into a later encounter.
    module ForcedGroupPlugin
      # Get the current selected group (forced group takes priority if set)
      # @return [Studio::Group, nil]
      def current_selected_group
        return @forced_group if @forced_group

        super
      end

      # Set the Battle::Info with the right information (clears the forced group afterward)
      # @param battle_id [Integer]
      # @return [Battle::Logic::BattleInfo, nil]
      def setup(battle_id = 1)
        return super
      ensure
        @forced_group = nil
      end
    end
    prepend ForcedGroupPlugin
  end
end

class Interpreter
  # Forces a wild battle against a random Pokemon from a specific named
  # encounter group, instead of one matching the player's current tile.
  # @param group_name [Symbol] db_symbol of the Studio::Group to pick from
  # @param battle_id [Integer] ID of the events to load for the battle scenario
  def call_battle_wild_group(group_name, battle_id: 1)
    $wild_battle.forced_group = data_group(group_name)
    $game_temp.battle_can_lose = false
    battle_info = $wild_battle.setup(battle_id)
    Graphics.freeze
    $scene = $game_variables[Yuki::Var::BT_Mode] == 5 ? Battle::Safari.new(battle_info) : Battle::Scene.new(battle_info)
    Yuki::FollowMe.set_battle_entry
    @wait_count = 2
  end
end 