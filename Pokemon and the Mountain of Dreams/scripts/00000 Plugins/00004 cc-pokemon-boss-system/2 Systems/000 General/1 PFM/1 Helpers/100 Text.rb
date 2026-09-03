module PFM
  # Module that helps the game to get text in various langages
  module Text
    # Patch naming a Boss as such in every battle message, whatever the language.
    #
    # The engine already picks the variant of a battle text naming a wild or an opposing Pokemon.
    # Instead of duplicating every one of those texts for Bosses, this patch rewrites the fragment
    # naming the Pokemon with the rules of the BOSS_TEXT_FILE_ID text file.
    module BossTextPatch
      # ID of the text file holding the Boss naming rules
      BOSS_TEXT_FILE_ID = 10_003
      # ID of the text naming a Boss outside of a sentence
      BOSS_LABEL_ID = 0
      # Token standing for the Pokemon name inside the rules, as written in the engine text files
      NAME_ANCHOR = '[VAR PKNICK(0000)]'

      # Parse a text from the text database with specific informations and a pokemon
      # @param file_id [Integer] ID of the text file
      # @param text_id [Integer] ID of the text in the file
      # @param pokemon [PFM::Pokemon] pokemon that will introduce an offset on text_id (its name is also used)
      # @param additionnal_var [nil, Hash{String => String}] additional remplacements in the text
      # @return [String] the text parsed and ready to be displayed
      def parse_with_pokemon(file_id, text_id, pokemon, additionnal_var = nil)
        return name_bosses(super, pokemon)
      end

      # Parse a text from the text database with 2 pokemon & specific information
      # @param file_id [Integer] ID of the text file
      # @param text_id [Integer] ID of the text in the file
      # @param pokemon1 [PFM::Pokemon] pokemon we're talking about
      # @param pokemon2 [PFM::Pokemon] pokemon who originated the "problem" (eg. bind)
      # @param additionnal_var [nil, Hash{String => String}] additional remplacements in the text
      # @return [String] the text parsed and ready to be displayed
      def parse_with_2pokemon(file_id, text_id, pokemon1, pokemon2, additionnal_var)
        return name_bosses(super, pokemon1, pokemon2)
      end

      # Parse a text from the text database with specific informations and two Pokemon
      # @param file_id [Integer] ID of the text file
      # @param text_id [Integer] ID of the text in the file
      # @param pokemon [PFM::Pokemon] pokemon that will introduce an offset on text_id (its name is also used)
      # @param pokemon2 [PFM::Pokemon] second pokemon that will introduce an offset on text_id (its name is also used)
      # @param additionnal_var [nil, Hash{String => String}] additional remplacements in the text
      # @return [String] the text parsed and ready to be displayed
      def parse_with_pokemons(file_id, text_id, pokemon, pokemon2, additionnal_var = nil)
        return name_bosses(super, pokemon, pokemon2)
      end

      # Name a Boss outside of a sentence, for the battle UI.
      # @param pokemon [PFM::PokemonBattler] the Boss to name
      # @return [String] the name to display
      def boss_name(pokemon)
        label = text_get(BOSS_TEXT_FILE_ID, BOSS_LABEL_ID).to_s
        return pokemon.name if label.empty?

        return label.sub(NAME_ANCHOR, pokemon.name)
      end

      private

      # Rewrite a parsed text so every Boss it talks about is named as one.
      # @param text [String] the text the engine parsed
      # @param pokemon [Array<PFM::Pokemon, nil>] the Pokemon the text was parsed with
      # @return [String] the text naming the Bosses
      def name_bosses(text, *pokemon)
        pokemon.each { |target| text = name_boss(text, target) }
        return text
      end

      # Rewrite the fragment naming a Boss, the first matching rule wins since a message names a
      # given Pokemon one way only.
      # @param text [String] the text the engine parsed
      # @param pokemon [PFM::Pokemon, nil] the Pokemon the text was parsed with
      # @return [String] the text naming the Boss
      def name_boss(text, pokemon)
        return text unless pokemon.is_a?(PFM::PokemonBattler) && pokemon.boss?
        return text unless enemy_pokemon?(pokemon)

        boss_naming_rules.each do |fragment, replacement|
          next if fragment.to_s.empty? || replacement.to_s.empty?

          named = text.gsub(fragment.sub(NAME_ANCHOR, pokemon.given_name)) { replacement.sub(NAME_ANCHOR, pokemon.given_name) }
          return named unless named == text
        end
        return text
      end

      # Get the fragments naming an enemy Pokemon in the langage of the game, each with the way a
      # Boss is named instead. A langage left untranslated has no rule, its messages stay as the
      # engine wrote them.
      # @return [Array<Array(String, String)>] the naming rules, most common wording first
      def boss_naming_rules
        rules = text_file_get(BOSS_TEXT_FILE_ID)
        return [] unless rules.is_a?(Array)

        return rules.drop(1).each_slice(2).to_a
      end
    end

    singleton_class.prepend(BossTextPatch)
  end
end
