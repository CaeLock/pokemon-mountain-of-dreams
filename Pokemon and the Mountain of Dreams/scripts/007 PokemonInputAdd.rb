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

  # Message shown when the typed name doesn't resolve to any known species at all
  GIVE_NAMED_POKEMON_NOT_FOUND_MESSAGE = "That doesn't seem to be the name of any known Pokémon."

  # Message shown when the typed name resolves to a real species, but that
  # species isn't allowed to be given (restricted or not first-stage)
  GIVE_NAMED_POKEMON_INVALID_MESSAGE = 'Thou dost not possess the strength to manifest that dream. Call not upon evolved or unique Pokémon.'

  # Prompt shown when asking which form to give
  GIVE_NAMED_POKEMON_FORM_PROMPT = 'In what form doth thy dream manifest?'

  # @return [Boolean] whether db_symbol has no other species evolving into it (first stage/standalone)
  def first_stage_species?(db_symbol)
    each_data_creature.none? { |creature| creature.forms.any? { |form| form.evolutions.any? { |evo| evo.db_symbol == db_symbol } } }
  end

  # @param db_symbol [Symbol]
  # @return [Boolean] whether db_symbol is allowed to be given via give_named_pokemon/give_pokemon_by_name
  def named_pokemon_species_allowed?(db_symbol)
    return false unless db_symbol
    return false if data_creature(db_symbol).db_symbol != db_symbol # species doesn't actually exist

    # Normalized (underscore-stripped) comparison, so this still blocks the
    # species correctly whether your Studio project's db_symbol convention is
    # e.g. :ironboulder or :iron_boulder - the list above only has to spell
    # it one way, not match your project's exact convention.
    return false if GIVE_NAMED_POKEMON_RESTRICTED_SPECIES.include?(db_symbol.to_s.delete('_').to_sym)
    return false unless first_stage_species?(db_symbol)

    true
  end

  # Some species names use a typographic apostrophe (Farfetch'd, Sirfetch'd,
  # etc.) that a normal keyboard can't type. Normalize both sides to a plain
  # apostrophe so matching doesn't depend on which one the data uses.
  APOSTROPHE_VARIANTS = /['’‘ʼ`]/.freeze

  # Resolves a typed name to a species db_symbol by matching against the
  # currently active language's creature names (see language handling note above)
  # @param typed_name [String]
  # @return [Symbol, nil]
  def resolve_species_from_name(typed_name)
    normalized = typed_name.to_s.strip.downcase.gsub(APOSTROPHE_VARIANTS, "'")
    return nil if normalized.empty?

    each_data_creature.find { |creature| creature.name.strip.downcase.gsub(APOSTROPHE_VARIANTS, "'") == normalized }&.db_symbol
  end

  # @return [Symbol, nil] a random species db_symbol among every species
  #   currently allowed by named_pokemon_species_allowed?, or nil if somehow none qualify
  def random_allowed_species
    each_data_creature.map(&:db_symbol).select { |db_symbol| named_pokemon_species_allowed?(db_symbol) }.sample
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
  # @param pokemon [Symbol, Integer, nil] db_symbol or ID of the species. Ignored
  #   entirely (can be nil) when randomize: true.
  # @param level [Integer] level of the Pokemon (ignored if is_egg is true - eggs are always created at level 1, same as the Daycare)
  # @param is_starter [Boolean] true = marked as starter (protected from release, 3 highest base stats get an assured 16-31 IV)
  # @param is_egg [Boolean] true = given as an unhatched egg
  # @param form [Integer] form index, default 0
  # @param randomize [Boolean] true = ignore +pokemon+ and pick a random species
  #   among everything currently allowed (same rules as named_pokemon_species_allowed?)
  # @return [PFM::Pokemon, nil] the Pokemon that was given, or nil if the species isn't allowed or it couldn't be added
  def give_named_pokemon(pokemon, level, is_starter: true, is_egg: false, form: 0, randomize: false)
    db_symbol = randomize ? random_allowed_species : (pokemon.is_a?(Symbol) ? pokemon : data_creature(pokemon).db_symbol)
    return nil unless named_pokemon_species_allowed?(db_symbol)

    creature_form = data_creature_form(db_symbol, form)
    opts = is_starter ? starter_iv_opts(creature_form) : {}
    new_pokemon = PFM::Pokemon.new(db_symbol, is_egg ? 1 : level, false, false, form, opts)
    new_pokemon.starter = true if is_starter
    new_pokemon.egg_init if is_egg
    # Learn Revealed Power if there's a free slot (< 4 moves); if the moveset is
    # already full, overwrite slot 0 instead of skipping it.
    learned = new_pokemon.learn_skill(:revealed_power)
    new_pokemon.replace_skill_index(0, :revealed_power) if learned.nil?
    added = add_pokemon(new_pokemon)

    if added
      $game_system.me_play(RPG::AudioFile.new('Pokémon caught-evolved - HGSS', 100, 100))
      $scene.message_window.windowskin_overwrite = 'm_18'
      $scene.message_window.auto_skip = true
      $scene.display_message("\\c[18]\\N[1] received \\c[27]#{new_pokemon.name}\\c[18]![WAIT 240]")
    end

    rename_pokemon(added, 12) if added
    return added
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
    if db_symbol.nil?
      $scene.display_message(GIVE_NAMED_POKEMON_NOT_FOUND_MESSAGE)
      return nil
    end
    unless named_pokemon_species_allowed?(db_symbol)
      $scene.display_message(GIVE_NAMED_POKEMON_INVALID_MESSAGE)
      return nil
    end
    form = ask_pokemon_form(db_symbol)
    return give_named_pokemon(db_symbol, level, is_starter: is_starter, is_egg: is_egg, form: form)
  end
end