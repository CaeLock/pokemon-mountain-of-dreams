# Lets the player type a Pokemon species name (via the standard name-input
# keyboard UI) and receive that Pokemon, with validation against evolutionary
# stage and a restricted species list, and full starter/egg handling.
#
# Requires pokemon_starter_flag.rb (for PFM::Pokemon#starter=/#starter?) to be
# loaded somewhere in the project - load order between the two files doesn't
# matter, since starter= is only called inside a method body here, not at load time.
#
# Call from an event's "Call Script":
#   give_pokemon_by_name(5)                                     # level 5, starter, not an egg
#   give_pokemon_by_name(20, is_starter: false)                 # ordinary Pokemon, not protected/no assured IVs
#   give_pokemon_by_name(1, is_egg: true)                       # given as an egg (always created at level 1, ignores the level argument)
#
# If you already know the species (no typed input needed), call the lower-level
# give_named_pokemon(db_symbol_or_id, level, is_starter: true, is_egg: false) directly.
#
# Validation rules (checked against the ACTUAL Studio database, not a static list):
#   - The species must not be in GIVE_NAMED_POKEMON_RESTRICTED_SPECIES below
#   - The species must be a first stage / standalone species: it's rejected if
#     ANY other species has an evolution pointing to it (e.g. Pikachu is
#     rejected because Pichu evolves into it; Pichu and Absol are both fine)
#
# Language handling: species name matching compares against Studio::Creature#name,
# which already resolves through the currently active $options.language (confirmed
# in 3_Studio.rb: "load text in the correct lang ($options.language or LANG in
# game.ini)") - so whatever language the game (and therefore its UI) is running
# in is automatically the language the match is made against. No per-language
# code needed on top of that.
#
# Note: this only matches against the base species name (form 0). Alternate
# forms with their own distinct display name (e.g. certain regional/special
# forms) aren't separately matched by typed name.
class Interpreter
  # Species that can never be given via give_named_pokemon/give_pokemon_by_name
  GIVE_NAMED_POKEMON_RESTRICTED_SPECIES = %i[
    mewtwo mew articuno zapdos moltres
    suicune raikou entei
    regigigas regirock regice registeel
    tornadus thundurus landorus
    tapukoko tapulele tapubulu tapufini
    lugia hooh celebi
    rayquaza kyogre groudon latios latias
    kyurem zekrom reshiram keldeo cobalion terrakion virizion
    manaphy jirachi shaymin magearna meloetta volcanion
    uxie mesprit azelf victini hoopa phione
    cresselia darkrai heatran
    yveltal xerneas zygarde
    genesect marshadow deoxys diancie zeraora
    arceus giratina dialga palkia
    typenull silvally meltan melmetal
    buzzwole guzzlord celesteela pheromosa xurkitree kartana blacephalon
    nihilego stakataka poipole naganadel necrozma cosmog cosmoem solgaleo lunala
    zamazenta zacian eternatus
    kubfu urshifu zarude regieleki regidrago glastrier spectrier calyrex enamorus
    greattusk screamtail brutebonnet fluttermane sandyshocks irontreads ironbundle ironhands
    ironjugulis ironmoth ironthorns wochien tinglu chiyu chienpao roaringmoon ironvaliant
    koraidon miraidon walkingwake ironleaves okidogi munkidori fezandipiti ogerpon gougingfire
    ragingbolt ironboulder ironcrown terapagos pecharunt
  ].freeze

  # Message shown when the typed name doesn't resolve to a givable species
  GIVE_NAMED_POKEMON_INVALID_MESSAGE = "That Pokémon can't be given this way."

  # Prompt shown when asking which form to give
  GIVE_NAMED_POKEMON_FORM_PROMPT = 'Which form would you like?'

  # @return [Boolean] whether db_symbol has no other species evolving into it (first stage/standalone)
  def first_stage_species?(db_symbol)
    each_data_creature.none? { |creature| creature.forms.any? { |form| form.evolutions.any? { |evo| evo.db_symbol == db_symbol } } }
  end

  # @param db_symbol [Symbol]
  # @return [Boolean] whether db_symbol is allowed to be given via give_named_pokemon/give_pokemon_by_name
  def named_pokemon_species_allowed?(db_symbol)
    return false unless db_symbol
    return false if data_creature(db_symbol).db_symbol != db_symbol # species doesn't actually exist
    return false if GIVE_NAMED_POKEMON_RESTRICTED_SPECIES.include?(db_symbol)
    return false unless first_stage_species?(db_symbol)

    true
  end

  # Resolves a typed name to a species db_symbol by matching against the
  # currently active language's creature names (see language handling note above)
  # @param typed_name [String]
  # @return [Symbol, nil]
  # Some species names use a typographic apostrophe (Farfetch'd, Sirfetch'd,
# etc.) that a normal keyboard can't type. Normalize both sides to a plain
# apostrophe so matching doesn't depend on which one the data uses.
APOSTROPHE_VARIANTS = /['’‘ʼ`]/.freeze

def resolve_species_from_name(typed_name)
  normalized = typed_name.to_s.strip.downcase.gsub(APOSTROPHE_VARIANTS, "'")
  return nil if normalized.empty?

  each_data_creature.find { |creature| creature.name.strip.downcase.gsub(APOSTROPHE_VARIANTS, "'") == normalized }&.db_symbol
end

  # Builds the opts[:stats] IV array that assures the 3 highest base stats a
  # random 16-31 IV (the remaining 3 stay fully random, same as any other Pokemon)
  # @param creature_form [Studio::CreatureForm]
  # @return [Hash]
  def starter_iv_opts(creature_form)
    stats = Configs.stats
    base = {stats.hp_index => creature_form.base_hp, stats.atk_index => creature_form.base_atk, stats.dfe_index => creature_form.base_dfe,
            stats.spd_index => creature_form.base_spd, stats.ats_index => creature_form.base_ats, stats.dfs_index => creature_form.base_dfs}
    top3_indexes = base.sort_by { |_, value| -value }.first(3).map(&:first)
    stats_array = Array.new(6)
    top3_indexes.each { |index| stats_array[index] = rand(16..31) }
    return {stats: stats_array}
  end

  # Creates and gives a Pokemon of a known, already-validated species
  # @param pokemon [Symbol, Integer] db_symbol or ID of the species
  # @param level [Integer] level of the Pokemon (ignored if is_egg is true - eggs are always created at level 1, same as the Daycare)
  # @param is_starter [Boolean] true = marked as starter (protected from release, 3 highest base stats get an assured 16-31 IV)
  # @param is_egg [Boolean] true = given as an unhatched egg
  # @param form [Integer] form index, default 0
  # @return [PFM::Pokemon, nil] the Pokemon that was given, or nil if the species isn't allowed or it couldn't be added
  def give_named_pokemon(pokemon, level, is_starter: true, is_egg: false, form: 0)
    db_symbol = pokemon.is_a?(Symbol) ? pokemon : data_creature(pokemon).db_symbol
    return nil unless named_pokemon_species_allowed?(db_symbol)

    creature_form = data_creature_form(db_symbol, form)
    opts = is_starter ? starter_iv_opts(creature_form) : {}
    new_pokemon = PFM::Pokemon.new(db_symbol, is_egg ? 1 : level, false, false, form, opts)
    new_pokemon.starter = true if is_starter
    new_pokemon.egg_init if is_egg
    return add_pokemon(new_pokemon)
  end

  # Asks the player which form to give, but only for species with known
  # regional forms (PFM::Pokedex::REGIONAL_FORMS, the same list the Dex
  # itself uses to know which alternate forms are regional variants rather
  # than something else like Mega Evolution). Any other species is always
  # given as its base form - no prompt, no other form types offered.
  # @param db_symbol [Symbol]
  # @return [Integer] the chosen form index (0 if not applicable or only one form)
  def ask_pokemon_form(db_symbol)
    return 0 unless PFM::Pokedex::REGIONAL_FORMS.include?(db_symbol)

    forms = data_creature(db_symbol).forms
    return 0 if forms.size <= 1

    labels = forms.map { |form| form.form.zero? ? 'Normal' : form.form_name }
    choice = $scene.display_message_and_wait(GIVE_NAMED_POKEMON_FORM_PROMPT, 1, *labels)
    return forms[(choice || 0)].form
  end

  # Prompts for a Pokemon species name via the keyboard, validates it, and gives it to the player
  # @param level [Integer] level of the Pokemon (ignored if is_egg is true)
  # @param is_starter [Boolean] true = marked as starter (protected from release, assured IVs on its 3 highest base stats)
  # @param is_egg [Boolean] true = given as an unhatched egg
  # @return [PFM::Pokemon, nil] the Pokemon that was given, or nil if the typed name didn't resolve to a givable species
  def give_pokemon_by_name(level, is_starter: true, is_egg: false)
    typed_name = nil
    $scene.call_scene(GamePlay.string_input_class, '', 12, nil, phrase: 'Enter the name of a Pokémon:') { |scene| typed_name = scene.return_name }
    db_symbol = resolve_species_from_name(typed_name)
    unless named_pokemon_species_allowed?(db_symbol)
      $scene.display_message(GIVE_NAMED_POKEMON_INVALID_MESSAGE)
      return nil
    end
    form = ask_pokemon_form(db_symbol)
    return give_named_pokemon(db_symbol, level, is_starter: is_starter, is_egg: is_egg, form: form)
  end
end