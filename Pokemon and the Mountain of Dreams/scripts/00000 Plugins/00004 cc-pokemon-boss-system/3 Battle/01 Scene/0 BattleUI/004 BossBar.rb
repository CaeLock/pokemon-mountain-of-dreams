module BattleUI
  class BossBar < AbilityBar
    private

    def create_text
      add_text(*text_coordinates, 0, 16, :boss_bar_name, color: 10, type: SymText)
    end
  end
end
