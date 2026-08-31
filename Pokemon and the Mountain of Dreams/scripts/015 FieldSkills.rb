# Dedicated HM-eligibility check, kept fully separate from has_skill? so
# nothing else that might call has_skill? elsewhere in the project is
# affected. You'll need to update the six HM common events yourself (see the
# exact lines to change below) - nothing here does that automatically.
#
# A party Pokemon qualifies for a given HM/field move if it's CAPABLE of
# learning it (by level-up, tech item i.e. TM/HM, or egg move), even if it
# doesn't currently know it - excluding fainted Pokemon and eggs.
#
# Pure addition (new method name), no prepend/override involved.
module PFM
  class GameState
    # @param id [Integer, Symbol] ID or db_symbol of the move in the database
    # @param index [Boolean] if true, return the index of the qualifying Pokemon instead of a boolean
    # @return [Boolean, Integer, false]
    def can_use_hm_skill?(id, index = false)
      move_db_symbol = id.is_a?(Symbol) ? id : data_move(id).db_symbol
      @actors.each_with_index do |pokemon, i|
        next unless pokemon
        next if pokemon.egg? || pokemon.dead?

        creature_form = data_creature_form(pokemon.db_symbol, pokemon.form)
        eligible = creature_form.move_set.any? do |learnable_move|
          learnable_move.move == move_db_symbol &&
            (learnable_move.level_learnable? || learnable_move.tech_learnable? || learnable_move.breed_learnable?)
        end
        return index ? i : true if eligible
      end
      return false
    end
  end
end