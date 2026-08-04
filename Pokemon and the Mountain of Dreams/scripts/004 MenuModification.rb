module GamePlay
  class Menu
    # Real index 7: the engine only pre-registers 7 buttons (indices 0~6:
    # Dex, Party, Bag, Trainer card, Options, Save, Quit), so this is the
    # 8th button, real_index 7.
    register_button(:open_quests) { true }

    # Force this specific button (real_index 7) to use QuestMenuButton instead
    # of the default UI::PSDKMenuButtonBase, so it reads its icon from row 8
    # of menu_icons.png instead of row 7 (row 7 is already used by the
    # engine's own UI::GirlBagMenuButton).
    register_button_overwrite(7) { UI::QuestMenuButton }

    private

    # Open the quest journal UI
    def open_quests
      GamePlay.open_quest_ui
    end
  end
end

module UI
  class PSDKMenuButtonBase
    # Patch to add the text of the quest button (real_index 7)
    module QuestButtonText
      # Get the text based on the index
      # @return [String]
      def text
        return 'Quests' if @index == 7

        super
      end
    end

    # menu_icons.png now has 9 rows instead of the engine's default 8 (row 8
    # holds the new Quests icon, row 7 is still the girl-bag variant). The
    # row count is hardcoded inside create_icon with no clean extension
    # point, so the whole method is reimplemented here with 8 -> 9; every
    # line besides that one argument is identical to the base method.
    module NineRowMenuIcons
      private

      def create_icon
        @icon = add_sprite(12, 0, 'menu_icons', 2, 9, type: SpriteSheet)
        @icon.select(0, icon_index)
        @icon.set_origin(@icon.width / 2, @icon.height / 2)
        @icon.set_position(@icon.x + @icon.ox, @icon.y + @icon.oy)
      end
    end

    prepend QuestButtonText
    prepend NineRowMenuIcons
  end

  # Button class for the Quests entry: identical to the default button,
  # except its icon comes from row 8 of menu_icons.png (real_index 7 would
  # normally point to row 7, which UI::GirlBagMenuButton already owns).
  class QuestMenuButton < PSDKMenuButtonBase
    private

    # @return [Integer]
    def icon_index
      8
    end
  end
end