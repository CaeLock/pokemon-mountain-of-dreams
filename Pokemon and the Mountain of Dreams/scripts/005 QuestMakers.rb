# Adds a [quest=N] event-name tag that shows an icon floating above an NPC's
# head reflecting the state of quest N:
#   - not started : Graphics/pictures/quest_icon.png
#   - in progress : Graphics/pictures/quest_icon_in_progress.png (optional -
#                    falls back to quest_icon.png if that file doesn't exist)
#   - finished/failed : icon hidden
#
# Usage: in the map editor, put "[quest=3]" anywhere in the event's NAME field
# - not a comment. This follows the exact same convention PSDK already uses
# for its other event-name tags (see Game_Event, 4_Systems_003_Map_Engine.rb):
# [z=5], [offset_y=-8], [alias=some_name], etc. all work by embedding a
# bracketed code directly in the event's name and parsing it once when the
# event is created (Game_Event#initialize_parse_name).
#
# State is read straight from PFM.game_state.quests: "in progress" means the
# quest is in active_quests (PFM::Quests#active_quest returns non-nil);
# "finished"/"failed" hide the icon entirely; anything else (quest exists but
# hasn't been started yet) shows the base quest_icon.png.
#
# On top of the automatic state above, a quest's icon can also be forced
# on/off remotely (e.g. from a Call Script) via QuestIconPlugin.set_visibility
# or Interpreter#show_quest_icon, regardless of the quest's actual progress.
# This override is checked first; when no override is set for a given quest
# id, behavior is 100% unchanged from before.
#
# Overrides are stored directly on PFM::Quests (icon_visibility_overrides),
# not in QuestIconPlugin itself, so they get saved/loaded along with the rest
# of the quest data automatically - no separate save-file hook needed. The
# accessor is lazily initialized (@icon_visibility_overrides ||= {}), so save
# files created before this feature existed still load fine.

class Game_Event < Game_Character
  # Tag that marks this event as tied to a quest; shows the quest icon above its head
  # while that quest is active (not finished/failed)
  QUEST_TAG = /\[quest=(\d+)\]/
  # @return [Integer, nil] the quest id tied to this event via [quest=N], if any
  attr_reader :quest_id

  alias original_initialize_parse_name_quest_tag initialize_parse_name
  # Parse the event name in order to setup the event particularity (adds quest_id parsing)
  def initialize_parse_name
    original_initialize_parse_name_quest_tag
    return unless (name = @event.name)

    name.sub(QUEST_TAG) { @quest_id = Regexp.last_match(1).to_i }
  end
end

# Adds/updates/disposes the floating quest icon on top of Sprite_Character's
# existing lifecycle hooks (init/update/dispose), the same way the engine's
# own shadow sprite is handled.
module QuestIconPlugin
  # Vertical gap in pixels between the top of the character sprite and the icon
  QUEST_ICON_MARGIN = 0

  class << self
    # Whether Graphics/pictures/quest_icon_in_progress.png exists. Checked once
    # and memoized, since asset presence doesn't change during gameplay - avoids
    # re-checking every frame for every quest-tagged NPC on screen.
    # @return [Boolean]
    def in_progress_icon_available?
      return @in_progress_icon_available if defined?(@in_progress_icon_available)

      @in_progress_icon_available = RPG::Cache.picture_exist?('quest_icon_in_progress')
    end

    # Manual show/hide overrides per quest id, bypassing the automatic
    # finished/failed/in-progress state. nil (no key) = no override = automatic.
    # Backed by PFM::Quests#icon_visibility_overrides so it survives save/load.
    # @return [Hash{Integer=>Boolean}]
    def visibility_overrides
      PFM.game_state.quests.icon_visibility_overrides
    end

    # Force the quest icon tied to +quest_id+ to show or hide, regardless of the
    # quest's actual progress.
    # @param quest_id [Integer]
    # @param visible [Boolean] true = always show, false = always hide
    def set_visibility(quest_id, visible)
      visibility_overrides[quest_id] = visible
    end

    # Remove a manual override for +quest_id+, restoring the automatic
    # quest-state-based behavior.
    # @param quest_id [Integer]
    def clear_visibility_override(quest_id)
      visibility_overrides.delete(quest_id)
    end
  end

  # Initialize the specific parameters of the Sprite_Character (adds the quest icon)
  # @param character [Game_Character, Game_Event, Game_Player] the character shown
  def init(character)
    super
    dispose_quest_icon
    init_quest_icon if character.respond_to?(:quest_id) && character.quest_id
  end

  # Create the quest icon sprite
  def init_quest_icon
    @quest_icon = Sprite.new(viewport)
    @quest_icon_filename = nil
  end

  # Dispose the quest icon sprite, if any
  def dispose_quest_icon
    @quest_icon&.dispose
    @quest_icon = nil
  end

  # Update every information about the Sprite_Character (adds the quest icon update)
  def update
    super
    update_quest_icon if @quest_icon
  end

  # Update the quest icon's graphic, visibility and position based on quest state
  def update_quest_icon
    quest_id = @character.quest_id
    override = QuestIconPlugin.visibility_overrides[quest_id]
    if override == false
      @quest_icon.visible = false
      return
    end
    quests = PFM.game_state.quests
    if override.nil? && (quests.finished?(quest_id) || quests.failed?(quest_id) && @quest_icon.visible)
      @quest_icon.visible = false
      return
    end
    @quest_icon.visible = true
    in_progress = !quests.active_quest(quest_id).nil?
    filename = in_progress && QuestIconPlugin.in_progress_icon_available? ? 'quest_icon_in_progress' : 'quest_icon'
    if @quest_icon_filename != filename
      @quest_icon_filename = filename
      @quest_icon.bitmap = RPG::Cache.picture(filename)
      @quest_icon.ox = @quest_icon.bitmap.width / 2
      @quest_icon.oy = @quest_icon.bitmap.height
    end
    @quest_icon.x = @character.screen_x * @tile_zoom
    @quest_icon.y = @character.screen_y * @tile_zoom - @height - QUEST_ICON_MARGIN
    @quest_icon.z = z + 1
  end

  # Dispose the Sprite_Character (adds quest icon disposal)
  def dispose
    dispose_quest_icon
    super
  end
end
Sprite_Character.prepend(QuestIconPlugin)

# Pure addition, no override of existing PFM::Quests behavior: a lazily-created
# hash living directly on the quests save data, so Marshal picks it up as part
# of the normal save/load of PFM.game_state.quests without any extra wiring.
class PFM::Quests
  # @return [Hash{Integer=>Boolean}] manual quest-icon visibility overrides, keyed by quest id
  def icon_visibility_overrides
    @icon_visibility_overrides ||= {}
  end
end

class Interpreter
  # Force the quest icon tied to +quest_id+ to show or hide remotely, regardless
  # of the quest's actual progress (e.g. useful for scripted cutscenes). Persists
  # across save/load.
  # @param quest_id [Integer] the quest id, as used in the event's [quest=N] tag
  # @param visible [Boolean] true = always show the icon, false = always hide it
  # @return [void]
  def show_quest_icon(quest_id, visible)
    QuestIconPlugin.set_visibility(quest_id, visible)
  end

  # Remove a manual override set with #show_quest_icon, restoring the automatic
  # quest-state-based icon behavior for +quest_id+.
  # @param quest_id [Integer]
  # @return [void]
  def reset_quest_icon(quest_id)
    QuestIconPlugin.clear_visibility_override(quest_id)
  end
end