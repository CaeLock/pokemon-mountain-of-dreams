# Overrides the boss-naming text from cc-pokemon-boss-system's own
# PFM::Text::BossTextPatch (2 Systems/000 General/1 PFM/1 Helpers/100 Text.rb)
# to say "Vestigial Pokémon" wherever it would say "Boss Pokémon", via
# monkey-patching per PSDK convention:
# https://docs.pokemonworkshop.com/getting-started/customize-psdk/monkey-patching-in-psdk/
# rather than editing the plugin's text file (file 10003) directly - so this
# survives a plugin update instead of being silently overwritten with it.
#
# How it works: BossTextPatch already builds the boss-labeled text from text
# file 10003 (boss_name for the standalone banner label, name_boss for text
# rewritten mid-sentence). This module prepends on TOP of that (both are
# prepended onto PFM::Text's singleton class, same as the plugin's own patch),
# calls super to get whatever text the plugin's own text-file-driven system
# produced, then substitutes each (old word => new word) pair in
# WORD_REPLACEMENTS in the result. Add more pairs there if your text file's
# other-language entries use a different word for "Boss" that also needs
# replacing - this only catches the literal English word by default.
module PFM
  module Text
    module VestigialPokemonPatch
      # Word substitutions applied to boss-related text this module produces
      WORD_REPLACEMENTS = {
        'Boss' => 'Vestigial'
      }.freeze

      # Name a Boss outside of a sentence, for the battle UI (adds the word substitution)
      # @param pokemon [PFM::PokemonBattler] the Boss to name
      # @return [String] the name to display
      def boss_name(pokemon)
        return apply_vestigial_wording(super)
      end

      private

      # Rewrite the fragment naming a Boss (adds the word substitution, only
      # when the text actually got boss-rewritten - never touches text for a
      # non-boss Pokemon, to avoid rewriting an unrelated coincidental match)
      # @param text [String] the text the engine parsed
      # @param pokemon [PFM::Pokemon, nil] the Pokemon the text was parsed with
      # @return [String] the text naming the Boss
      def name_boss(text, pokemon)
        result = super
        return result unless pokemon.is_a?(PFM::PokemonBattler) && pokemon.boss?

        return apply_vestigial_wording(result)
      end

      # Applies every WORD_REPLACEMENTS pair to the given text
      # @param text [String]
      # @return [String]
      def apply_vestigial_wording(text)
        WORD_REPLACEMENTS.each { |old_word, new_word| text = text.gsub(old_word, new_word) }
        return text
      end
    end

    singleton_class.prepend(VestigialPokemonPatch)
  end
end