# Adds Game_Character#move_random_within_radius(radius_x, radius_y), a
# wrapper around the native move_random_within_zone that never needs absolute
# tile coordinates - it remembers the character's own position the FIRST
# time it's called (its spawn/home tile) and computes the zone bounds from
# that automatically. radius_x and radius_y are separate, so the allowed
# area doesn't have to be a square - e.g. move_random_within_radius(5, 1)
# keeps it within 5 tiles horizontally but only 1 tile vertically.
#
# Usage: in the event's Move Route (Custom, repeating), add a Script step:
#   move_random_within_radius(3, 3)   # square, 3 tiles in every direction
#   move_random_within_radius(5, 1)   # wide and shallow
# That's the whole setup - no coordinates to compute or hardcode, and it
# works the same regardless of where the event happens to be placed on the map.
#
# reset_radius_home clears the remembered position, so the NEXT
# move_random_within_radius call re-captures wherever the character currently
# is as the new home tile - useful if you move/warp the event elsewhere on
# the same map and want its wandering zone to follow.
class Game_Character
  # Moves randomly, staying within radius_x/radius_y tiles (per axis) of
  # wherever this character was positioned the first time this method was called
  # @param radius_x [Integer] max horizontal distance (in tiles) from home
  # @param radius_y [Integer] max vertical distance (in tiles) from home
  def move_random_within_radius(radius_x, radius_y)
    @radius_home_x ||= @x
    @radius_home_y ||= @y
    move_random_within_zone(@radius_home_x - radius_x, @radius_home_x + radius_x, @radius_home_y - radius_y, @radius_home_y + radius_y)
  end

  # Forgets the remembered home tile, so the next move_random_within_radius
  # call re-captures the character's CURRENT position as its new home
  def reset_radius_home
    @radius_home_x = @radius_home_y = nil
  end
end