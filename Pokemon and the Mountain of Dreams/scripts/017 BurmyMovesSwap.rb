class PFM::Pokemon
  module BurmyFormMoveSwap
    BURMY_FORM_MOVES = {
      4 => {0 => :absorb, 1 => :mud_slap, 2 => :intercepting_laser},
      17 => {0 => :mega_drain, 1 => :mud_bomb, 2 => :mirror_shot},
      31 => {0 => :giga_drain, 1 => :earth_power, 2 => :flash_cannon}
    }.freeze

    # FORM_GENERATION[:burmy] mutates @form directly as a side effect
    # (`next(@form = 2) if ...`), BEFORE the caller ever assigns the result
    # via form=. Hooking form= alone is too late - @form has already changed
    # by the time form= runs, making old/new always look identical. Hooking
    # form_generation itself, capturing @form before calling super, catches
    # the mutation at its actual source.
    def form_generation(form, old_value = nil)
      old_form = @form
      result = super
      swap_burmy_cloak_moves(result) if db_symbol == :burmy && result != old_form
      return result
    end

    # Kept as a second entry point for a DIRECT manual form change
    # (e.g. `pokemon.form = 2` from an event script), which doesn't go
    # through form_generation at all. Harmless overlap with the path above:
    # by the time handle_burmy_form_generation's own `pokemon.form = result`
    # runs, @form already equals result, so this simply no-ops there.
    def form=(value)
      old_form = @form
      super
      swap_burmy_cloak_moves(@form) if db_symbol == :burmy && @form != old_form
    end

    private

    def swap_burmy_cloak_moves(new_form)
      target = respond_to?(:original) ? original : self

      BURMY_FORM_MOVES.each do |_level, moves_by_form|
        new_move = moves_by_form[new_form]
        next unless new_move

        index = target.skills_set.find_index { |skill| skill && moves_by_form.value?(skill.db_symbol) }
        next unless index
        next if target.skills_set[index].db_symbol == new_move

        target.replace_skill_index(index, new_move)
      end
    end
  end
  prepend BurmyFormMoveSwap
end