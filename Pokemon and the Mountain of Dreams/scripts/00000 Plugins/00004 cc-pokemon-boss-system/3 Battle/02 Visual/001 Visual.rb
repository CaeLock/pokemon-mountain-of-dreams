module Battle
  # Class that manage all the thing that are visually seen on the screen.
  class Visual
    # Play the gauge movement of a Boss whose HP cross one or more bar boundaries, in either direction.
    # Counterpart of show_hp_animations, which only ever knows a single bar.
    # @param target [PFM::PokemonBattler]
    # @param path [PFM::BossHPPath] path the HP take across the bars
    # @param effectiveness [Float, nil] effectiveness of the hit, nil when it carries no impact feedback
    # @param messages [Proc] messages shown once the gauge has settled
    def show_boss_hp_animation(target, path, effectiveness = nil, &messages)
      lock do
        wait_for_animation
        show_info_bar(target)
        play_hit_feedback(target, effectiveness)
        animation = BossHPAnimation.new(self, target, path)
        animation.start
        scene_update_proc { animation.update } until animation.done?
        messages&.call
        show_kos([target])
      end
    end

    # Extinguish the reserve pip of the bar a Boss just lost.
    # @param target [PFM::PokemonBattler]
    def boss_bar_lost(target)
      @info_bars[target.bank][target.position].bars_hp[target.nb_bars_hp].switch_state(filled: false)
    end

    # Light the reserve pip of the bar a Boss just gained.
    # @param target [PFM::PokemonBattler]
    def boss_bar_gained(target)
      @info_bars[target.bank][target.position].bars_hp[target.nb_bars_hp - 1].switch_state
    end

    private

    # Play the sound and the flinch of a hit alongside the gauge, the way create_hp_animation_handler
    # bundles them for a single bar. Deliberately kept out of the gauge animation: the player waits on
    # its parallel animations, so a flinch longer than the first bar would hold the whole cascade back.
    # @param target [PFM::PokemonBattler]
    # @param effectiveness [Float, nil]
    def play_hit_feedback(target, effectiveness)
      return unless effectiveness

      target_sprite = battler_sprite(target.bank, target.position)
      feedback = [UI::HitSoundAnimation.new.create_animation(effectiveness)]
      feedback << UI::HurtAnimation.new.create_animation(target_sprite) if target_sprite
      feedback.each do |animation|
        animation.start
        @animations << animation
      end
    end
  end
end
