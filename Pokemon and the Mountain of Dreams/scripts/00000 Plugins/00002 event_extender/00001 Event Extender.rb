# Event Extender
#
# Author : Raty
# License : MIT
#
# PSDK plugin that can extend event collision and trigger range.
#
# https://github.com/RatyHub/Event-Extender
#
# Supported tags:
# [hitbox_left: 1]
# [hitbox_right: 1]
# [hitbox_up: 1]
# [hitbox_down: 1]
# [hitbox_left: 1, hitbox_right: 1, hitbox_up: 1, hitbox_down: 1]

module EventExtender
  INLINE_TAG_REGEXP = /\[([^\]]+)\]/
  INLINE_ARGUMENT_REGEXP = /\bhitbox_(left|right|up|down)\s*:\s*(\d+)\b/
  DIRECTIONS = {
    'left' => :left,
    'right' => :right,
    'up' => :up,
    'down' => :down
  }.freeze
  DEFAULT_HITBOX = {
    left: 0,
    right: 0,
    up: 0,
    down: 0
  }.freeze

  module_function

  def parse(event_name)
    hitbox = DEFAULT_HITBOX.dup
    event_name = event_name.to_s
    event_name.scan(INLINE_TAG_REGEXP) do |raw_content|
      raw_content.first.to_s.scan(INLINE_ARGUMENT_REGEXP) do |direction, raw_amount|
        key = DIRECTIONS[direction.downcase]
        hitbox[key] = raw_amount.to_i if key
      end
    end
    return hitbox
  end

  def enabled?(hitbox)
    return false unless hitbox

    return hitbox.any? { |_direction, amount| amount.positive? }
  end

  def blocked?(x, y, z, game_map, self_character = nil)
    game_map.events.each_value do |event|
      next if event.equal?(self_character)
      next if event.through
      next unless event.respond_to?(:event_extender_hitbox_contact?)

      return true if event.event_extender_hitbox_contact?(x, y, z)
    end
    return false
  end
end

class Game_Event
  attr_reader :event_extender_hitbox

  module EventExtenderEventPatch
    def initialize_parse_name
      super
      @event_extender_hitbox = EventExtender.parse(@event&.name)
    end

    def event_extender_hitbox_enabled?
      return EventExtender.enabled?(@event_extender_hitbox)
    end

    def event_extender_hitbox_contact?(x, y, z)
      return false unless event_extender_hitbox_enabled?
      return false if (@z - z).abs > 1

      return x >= @x - @event_extender_hitbox[:left] &&
             x <= @x + @event_extender_hitbox[:right] &&
             y >= @y - @event_extender_hitbox[:up] &&
             y <= @y + @event_extender_hitbox[:down]
    end
  end

  prepend EventExtenderEventPatch
end

class Game_Character
  module EventExtenderCharacterPatch
    def event_passable_check?(new_x, new_y, z, game_map)
      return false unless super

      return !EventExtender.blocked?(new_x, new_y, z, game_map, self)
    end
  end

  prepend EventExtenderCharacterPatch
end

class Game_Player
  module EventExtenderPlayerPatch
    def event_passable_check?(new_x, new_y, z, game_map)
      return false unless super

      return !EventExtender.blocked?(new_x, new_y, z, game_map, self)
    end

    def check_event_trigger_there(triggers)
      return true if super

      d = @direction
      new_x = @x + (d == 6 ? 1 : d == 4 ? -1 : 0)
      new_y = @y + (d == 2 ? 1 : d == 8 ? -1 : 0) + (@direction == 4 ? slope_check_left(false) : @direction == 6 ? slope_check_right(false) : 0)
      z = @z
      result = event_extender_check_hitbox_trigger_at(new_x, new_y, z, triggers)
      return true if result

      if $game_map.counter?(new_x, new_y)
        new_x += (d == 6 ? 1 : d == 4 ? -1 : 0)
        new_y += (d == 2 ? 1 : d == 8 ? -1 : 0)
        result = event_extender_check_hitbox_trigger_at(new_x, new_y, z, triggers)
      end
      return result
    end

    def check_event_trigger_touch(x, y)
      return true if super

      return event_extender_check_hitbox_trigger_at(x, y, @z, [1, 2])
    end

    private

    def event_extender_check_hitbox_trigger_at(x, y, z, triggers)
      result = false
      return false if $game_system.map_interpreter.running?

      $game_map.events.each_value do |event|
        next unless event.respond_to?(:event_extender_hitbox_contact?)
        next unless event.event_extender_hitbox_contact?(x, y, z)
        next unless triggers.include?(event.trigger)
        next if event.jumping?

        event.start
        result = true
      end
      return result
    end
  end

  prepend EventExtenderPlayerPatch
end

if defined?(Pathfinding::Cursor)
  module Pathfinding
    class Cursor
      module EventExtenderCursorPatch
        def event_passable_check?(new_x, new_y, z, game_map)
          return false unless super

          return !EventExtender.blocked?(new_x, new_y, z, game_map, @character)
        end
      end

      prepend EventExtenderCursorPatch
    end
  end
end
