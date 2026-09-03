module Battle
  class Visual
    # Adds a Boss banner (BattleUI::BossBar), mirroring the ability/item bar lifecycle.
    module BossBarVisual
      # Init the boss banner store (like the engine inits @ability_bars/@item_bars).
      def initialize(*args)
        @boss_bars = {}
        super
      end

      # Show the boss banner (mirrors show_ability, with the "Boss <name>" label).
      # @param target [PFM::PokemonBattler]
      def show_boss(target)
        $game_system.se_play(Configs.sounds.effect_activation_se)
        boss_bar = @boss_bars.dig(target.bank, target.position)
        return unless boss_bar

        boss_bar.data = target
        boss_bar.go_in_ability
        stack_bar_on_top(boss_bar, target)
      end

      # Show the ability bar, then keep it above any active boss banner (3-way z consistency).
      # @param target [PFM::PokemonBattler]
      # @param no_go_out [Boolean]
      def show_ability(target, no_go_out = false)
        super
        bar = @ability_bars.dig(target.bank, target.position)
        stack_bar_on_top(bar, target) if bar
      end

      # Show the item bar, then keep it above any active boss banner (3-way z consistency).
      # @param target [PFM::PokemonBattler]
      def show_item(target)
        super
        bar = @item_bars.dig(target.bank, target.position)
        stack_bar_on_top(bar, target) if bar
      end

      # Create the battler sprites (Trainer + Pokemon), then a boss banner per Pokemon position.
      def create_battlers
        super
        infos = @scene.battle_info
        @scene.logic.bank_count.times do |bank|
          infos.vs_type.times { |position| create_boss_bar(bank, position) }
        end
      end

      # Update the visuals
      def update
        super
        update_boss_bars
      end

      # Create the animations
      def create_animations
        super
        create_animation_boss_bars
      end

      private

      # Create a boss banner bar
      # @param bank [Integer]
      # @param position [Integer]
      def create_boss_bar(bank, position)
        @boss_bars[bank] ||= []
        @boss_bars[bank][position] = sprite = BattleUI::BossBar.new(@viewport_sub, @scene, bank, position)
        @animatable << sprite
      end

      # Create the boss banners animations
      def create_animation_boss_bars
        @boss_bars.each_value do |boss_bars|
          boss_bars.each(&:create_animation)
          boss_bars.each { |boss_bar| boss_bar.go_out(-3600) }
        end
      end

      # Update the boss banners
      def update_boss_bars
        @boss_bars.each_value do |boss_bars|
          boss_bars.each(&:update)
        end
      end

      # Put `bar` above every OTHER ability/item/boss bar still on screen at that slot, so the
      # bar shown most recently ends up on top (generalizes the engine's pairwise ability/item z).
      # @param bar [BattleUI::AbilityBar]
      # @param target [PFM::PokemonBattler]
      def stack_bar_on_top(bar, target)
        others = [@ability_bars.dig(target.bank, target.position),
                  @item_bars.dig(target.bank, target.position),
                  @boss_bars.dig(target.bank, target.position)]
        others = others.compact.reject { |other| other.equal?(bar) || other.done? }
        bar.z = others.empty? ? 0 : (others.map(&:z).max + 1)
      end
    end

    prepend BossBarVisual
  end

  # Mock stub so show_boss is a no-op during AI simulation (mirrors show_ability).
  module VisualMock
    # Show the boss banner
    # @param target [PFM::PokemonBattler]
    def show_boss(target)
      return
    end

    # Light the aura of a Boss reaching the field
    # @param pokemon [PFM::PokemonBattler, nil]
    # @note Every switch runs its events during simulation too, and they reach the aura entry.
    def show_boss_aura_on_entry(pokemon)
      return
    end

    # Show the mega evolution animation
    # @param target [PFM::PokemonBattler]
    # @note The engine mock stubs show_switch_form_animation but not this one, and a boss can Mega Evolve
    #   mid-simulation, which would reach the real animation and its disposed viewport.
    def show_mega_animation(target)
      return
    end

    # Play the gauge movement of a Boss across its bars
    # @param target [PFM::PokemonBattler]
    # @param path [PFM::BossHPPath]
    # @param effectiveness [Float, nil]
    # @param messages [Proc]
    # @note Counterpart of the engine's show_hp_animations stub: simulated damage reaches it too.
    def show_boss_hp_animation(target, path, effectiveness = nil, &messages)
      return
    end
  end
end
