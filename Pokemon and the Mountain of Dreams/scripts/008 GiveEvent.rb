# Available berry pools
BERRY_POOLS = {
  common: %i[oran_berry cheri_berry chesto_berry pecha_berry rawst_berry aspear_berry persim_berry sitrus_berry leppa_berry],
  uncommon: %i[leppa_berry sitrus_berry lum_berry liechi_berry ganlon_berry salac_berry petaya_berry apicot_berry kee_berry maranga_berry pomeg_berry kelpsy_berry qualot_berry hondew_berry grepa_berry tamato_berry],
  resistance: %i[occa_berry passho_berry wacan_berry rindo_berry yache_berry chople_berry kebia_berry shuca_berry coba_berry payapa_berry tanga_berry charti_berry kasib_berry colbur_berry babiri_berry chilan_berry roseli_berry],
  rare: %i[jaboca_berry rowap_berry lansat_berry micle_berry custap_berry starf_berry enigma_berry]
}.freeze

ITEM_POOLS = {
  common: %i[poke_ball great_ball potion super_potion exp_candy_xs ether tiny_mushroom],
  uncommon: %i[great_ball great_ball ultra_ball super_potion hyper_potion exp_candy_xs exp_candy_s full_heal revive ether tiny_mushroom big_mushroom],
  ball_common: %i[great_ball poke_ball],
  ball_uncommon: %i[great_ball ultra_ball heal_ball repeat_ball timer_ball luxury_ball],
}.freeze

class Interpreter
  # Gives the player a number of random berries from a given pool, then
  # displays a summary message of what was received.
  # @param pool [Symbol] one of BERRY_POOLS' keys (:common, :uncommon, :resistance, :rare)
  # @param number [Integer] how many berries to give
  def give_berries(pool, number)
    chosen_pool = BERRY_POOLS[pool] || BERRY_POOLS[:common] # defaults to common if the pool doesn't exist
    berries_to_give = []

    number.times do
      berries_to_give << chosen_pool.sample
    end

    # Tally how many of each berry were picked, e.g. { oran_berry: 2, sitrus_berry: 1 }
    tally = berries_to_give.tally

    tally.each do |berry, count|
      $bag.add_item(berry, count)
    end

    lines = tally.map { |berry, count| "\\img[#{data_item(berry).icon},icon] #{data_item(berry).name} x#{count}" }
    header = number == 1 ? 'You picked up a berry!' : 'You picked up some berries!'

    # Resize the window to fit the header line plus one line per berry type
    $scene.message_window.line_number_overwrite = lines.size + 2
    # Move the window to the top of the screen for this message only
    # (both overwrites are consumed and reset automatically once the message closes)
    $scene.message_window.position_overwrite = :top
    $scene.display_message("#{header}\n#{lines.join("\n\n")}")
  end

  def give_items(pool, number)
    chosen_pool = ITEM_POOLS[pool] || ITEM_POOLS[:common] # defaults to common if the pool doesn't exist
    items_to_give = []

    number.times do
      items_to_give << chosen_pool.sample
    end

    # Tally how many of each were picked, e.g. { oran_berry: 2, sitrus_berry: 1 }
    tally = items_to_give.tally

    tally.each do |item, count|
      $bag.add_item(item, count)
    end

    lines = tally.map { |item, count| "\\img[#{data_item(item).icon},icon] #{data_item(item).name} x#{count}" }
    header = number == 1 ? 'You picked up an item!' : 'You picked up some items!'

    # Resize the window to fit the header line plus one line per berry type
    $scene.message_window.line_number_overwrite = lines.size + 2
    # Move the window to the top of the screen for this message only
    # (both overwrites are consumed and reset automatically once the message closes)
    $scene.message_window.position_overwrite = :top
    $scene.display_message("#{header}\n#{lines.join("\n\n")}")
  end
end