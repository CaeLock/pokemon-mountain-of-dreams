# Fixes the map's BGM restarting from the beginning after a battle, instead
# of resuming from where it was when the battle started.
#
# Root cause (verified against source, not assumed): battle music is played
# via Game_System#temporary_bgm_play (5_Battle_01_Scene.rb, Scene#pre_transition),
# which deliberately does NOT overwrite @playing_bgm - so the game correctly
# keeps remembering the map's track name throughout the battle. But nothing
# in Scene#battle_end (or anywhere else in the return-to-map path) ever
# actually calls anything to resume it - no bgm_restore, no bgm_play, no
# Game_Map#autoplay (that's only ever called from transfer_player_end, i.e.
# actual map-to-map transfers, never from a battle returning to the same map).
#
# PSDK already ships the exact tool needed for this - Game_System#bgm_memorize2
# / #bgm_restore2 (1_RMXP_Scripts.rb) - which captures both the track AND the
# exact Audio.bgm_position, then resumes from that precise point. It's just
# never called anywhere in the battle system. This wires it in:
#   - memorize right before the battle switches the audio to its own BGM
#     (Scene#pre_transition, same spot temporary_bgm_play is called from)
#   - restore right before returning to the map (Scene#battle_end)
module Battle
  class Scene
    module RestoreMapBgmPlugin
      # Method that call @visual.show_pre_transition and change @next_update
      # to :transition_animation (adds memorizing the map's BGM position first)
      def pre_transition
        $game_system.bgm_memorize2 unless ARGV.include?('ai_sim')
        super
      end

      # Called when the battle ends and returns to the last scene (adds
      # restoring the map's BGM from the exact position it was memorized at)
      def battle_end
        $game_system.bgm_restore2 unless ARGV.include?('ai_sim')
        super
      end
    end
    prepend RestoreMapBgmPlugin
  end
end