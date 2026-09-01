module PFM
  class Pokemon
    # Mega Evolve into the given form, ignoring the Mega Stone requirement since a boss holds none.
    # @param form [Integer] form index to take
    # @return [Boolean] whether the Pokemon took the form
    def boss_mega_evolve(form)
      return false if mega_evolved?
      return false unless data_creature(db_symbol).forms.any? { |creature_form| creature_form.form == form }

      @mega_evolved = @form
      @form = form
      @ability = data_ability(data.abilities.sample).id
      self.ability = nil if is_a?(PFM::PokemonBattler)

      return true
    end
  end
end
