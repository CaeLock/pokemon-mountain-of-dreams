module Battle
  class Visual
    # The whole gauge movement of a Boss whose HP cross one or more bar boundaries, in either direction.
    # The engine's HPAnimation only ever knows one bar, so a Boss owns its own timeline.
    class BossHPAnimation < Yuki::Animation::Player
      # Create the animation of a HP path.
      # @param visual [Battle::Visual] visual holding the battle sprites and info bars
      # @param target [PFM::PokemonBattler] creature whose gauge moves
      # @param path [PFM::BossHPPath] path the HP take across the bars
      def initialize(visual, target, path)
        @visual = visual
        @target = target
        @path = path
        super(build_stack(path))
      end

      # Update the animation
      def update
        super
        @visual.refresh_info_bar(@target)
      end

      private

      # Build the stack: one leg per bar the path runs through, a boundary crossing in between, then the
      # snap and the beat the engine leaves once a gauge has settled.
      # @param path [PFM::BossHPPath]
      # @return [Array<Yuki::AnimationMixin>]
      def build_stack(path)
        stack = []
        path.segments.each_with_index do |(from, to), index|
          stack << Yuki::Animation.send_command_to(self, :cross_boundary) if index.positive?
          stack << Yuki::Animation.discreet(leg_duration(to - from), @target, :hp=, from, to)
        end
        stack << Yuki::Animation.send_command_to(self, :snap_final_hp)
        stack << Yuki::Animation.wait(settle_duration(path))

        return stack
      end

      # Cross one bar boundary: move the bar count, switch its reserve pip, and send the gauge to the end
      # the next leg starts from. Both directions are the same gesture mirrored, hence one method.
      def cross_boundary
        descending = @path.descending?
        @target.nb_bars_hp += descending ? -1 : 1
        descending ? @visual.boss_bar_lost(@target) : @visual.boss_bar_gained(@target)
        @target.hp = descending ? @target.max_hp : 1
        @visual.refresh_info_bar(@target)
      end

      # Snap the gauge to the exact final HP, the way HPAnimation refreshes once it is done.
      def snap_final_hp
        @target.hp = @path.final_hp
        @visual.refresh_info_bar(@target)
      end

      # Duration of one leg, proportional to the HP moved (mirrors HPAnimation#main_duration).
      # @param quantity [Integer] HP moved during the leg
      # @return [Float]
      def leg_duration(quantity)
        return (quantity.abs.to_f / 60).clamp(0.2, 1)
      end

      # The beat HPAnimation leaves after a gauge settles, so a Boss reads on the rhythm of any other hit.
      # @param path [PFM::BossHPPath]
      # @return [Float]
      def settle_duration(path)
        return 0.1 if path.final_hp <= 0

        from, to = path.segments.last
        return (1 - leg_duration(to - from)).clamp(0.25, 1)
      end
    end
  end
end
