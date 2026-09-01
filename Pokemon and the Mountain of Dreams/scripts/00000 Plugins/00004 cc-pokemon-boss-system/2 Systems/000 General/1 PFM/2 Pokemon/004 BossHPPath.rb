module PFM
  # Ordered path the HP of a Boss take across its bars, in either direction. Single owner of the bar
  # arithmetic: the damage handler, the heal handler and the gauge animation all read it instead of
  # each deriving where a bar starts and ends.
  class BossHPPath
    # Every leg of the path, one per bar it runs through, from the bar it starts on to the bar it ends on.
    # @return [Array<Array(Integer, Integer)>] pairs of HP values, from and to
    attr_reader :segments
    # Whether the path empties the last bar the creature had.
    # @return [Boolean]
    attr_reader :knocked_out

    # Create a path.
    # @param segments [Array<Array(Integer, Integer)>]
    # @param knocked_out [Boolean]
    # @param descending [Boolean] whether the HP go down
    def initialize(segments, knocked_out, descending)
      @segments = segments
      @knocked_out = knocked_out
      @descending = descending
    end

    # Number of bar boundaries the path crosses, so bars lost when descending and bars gained when not.
    # @return [Integer]
    def crossings
      return @segments.size - 1
    end

    # Whether the HP go down.
    # @return [Boolean]
    def descending?
      return @descending
    end

    # HP the creature is left with once the path is walked.
    # @return [Integer]
    def final_hp
      return @segments.last.last
    end
  end

  class Pokemon
    # Walk a signed HP change across the bars. Damage stops at the bars the creature has, healing may
    # reach up to the bar cap.
    # @param delta [Integer] HP change, negative for damage and positive for healing
    # @return [PFM::BossHPPath]
    def boss_hp_path(delta)
      return delta.negative? ? boss_damage_path(-delta) : boss_heal_path(delta)
    end

    # HP left across every bar the creature still has.
    # @return [Integer]
    def total_hp
      return hp + [nb_bars_hp - 1, 0].max * max_hp
    end

    # HP every bar the creature still has can hold together.
    # @return [Integer]
    def total_max_hp
      return [nb_bars_hp, 1].max * max_hp
    end

    # How much life the creature has left, counting every bar. Equals hp_rate for anything without
    # reserve bars, so it can stand in for it wherever the question is "how close to death is it".
    # @return [Float]
    def total_hp_rate
      return total_hp.to_f / total_max_hp
    end

    private

    # Spread damage over the bars, breaking them one by one until it runs out or the creature falls.
    # A broken bar drains to 1 rather than 0, so only a real knockout ever shows an empty gauge.
    # @param damage [Integer]
    # @return [PFM::BossHPPath]
    def boss_damage_path(damage)
      segments = []
      remaining = damage
      from = hp
      bars_left = [nb_bars_hp, 1].max
      loop do
        return BossHPPath.new(segments << [from, from - remaining], false, true) if remaining < from

        bars_left -= 1
        return BossHPPath.new(segments << [from, 0], true, true) if bars_left <= 0

        segments << [from, 1]
        remaining -= from
        from = max_hp
      end
    end

    # Spread healing over the current bar first, then over every bar it can regenerate up to the cap.
    # A regained bar starts at 1, the HP the boundary crossing leaves in the gauge.
    # @param heal [Integer]
    # @return [PFM::BossHPPath]
    def boss_heal_path(heal)
      segments = [[hp, [hp + heal, max_hp].min]]
      remaining = heal - (max_hp - hp)
      [MAX_BOSS_BARS - nb_bars_hp, 0].max.times do
        break if remaining <= 0

        taken = [remaining, max_hp].min
        segments << [1, (1 + taken).clamp(1, max_hp)]
        remaining -= taken
      end

      return BossHPPath.new(segments, false, false)
    end
  end
end
