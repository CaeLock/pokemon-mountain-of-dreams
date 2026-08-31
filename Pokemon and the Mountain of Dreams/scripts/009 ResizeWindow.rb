module UI
  module Message
    module Layout
      # Patch to always recompute the window size and position on every call,
      # instead of only when the windowskin name itself changes. This lets
      # line_number_overwrite, width_overwrite and position_overwrite actually
      # take effect, and lets the window return to its default size afterwards.
      module ResizeOnOverwritePatch
        # Recompute the window's size and position from current settings
        def update_windowskin
          self.window_builder = current_window_builder
          self.windowskin = RPG::Cache.windowskin(@windowskin_name = current_windowskin)
          set_size(window_width, window_height)
          calculate_position
        end
      end
      prepend ResizeOnOverwritePatch
    end
  end
end

module PFM
  module Message
    module State
      # Patch to refresh the message window's size and position before every
      # single message, since the base engine only does this once when the
      # window is first created.
      module RefreshWindowOnNewMessagePatch
        # Parse the new message, refreshing the window layout first
        def parse_and_show_new_message
          update_windowskin
          super
        end
      end
      prepend RefreshWindowOnNewMessagePatch
    end
  end
end