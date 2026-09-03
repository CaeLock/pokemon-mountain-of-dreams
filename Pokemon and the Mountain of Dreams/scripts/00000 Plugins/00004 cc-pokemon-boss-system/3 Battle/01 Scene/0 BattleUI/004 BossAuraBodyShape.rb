module BattleUI
  # Body of a battler read from its resource, the opaque box and the silhouette the Boss aura spawns its particles on.
  class BossAuraBodyShape
    # Side of a silhouette mask cell, in bitmap pixels
    MASK_CELL_SIZE = 4

    # Left edge of the opaque box, in bitmap pixels
    # @return [Integer]
    attr_reader :x
    # Top edge of the opaque box, in bitmap pixels
    # @return [Integer]
    attr_reader :y
    # Width of the opaque box, in bitmap pixels
    # @return [Integer]
    attr_reader :width
    # Height of the opaque box, in bitmap pixels
    # @return [Integer]
    attr_reader :height
    # Number of cells one row of the mask holds
    # @return [Integer, nil]
    attr_reader :mask_columns
    # Cells the silhouette fills, packed as row times mask_columns plus column
    # @return [Array<Integer>, nil]
    attr_reader :mask_cells

    class << self
      # Body of the battler a sprite shows, scanned once per resource then shared by every emitter
      # afterwards, the resources that cannot be read being remembered as unknown just the same
      # @param sprite [BattleUI::PokemonSprite]
      # @return [BossAuraBodyShape, nil]
      def for(sprite)
        key = resource_key(sprite.pokemon)
        return nil unless key
        return shapes[key] if shapes.key?(key)

        return shapes[key] = scan(sprite, key)
      end

      private

      # Bodies already scanned, keyed by the battler resource they were read from, a resource the scan
      # gave up on being kept with a nil body so it is not scanned again
      # @return [Hash{Array => BossAuraBodyShape}]
      def shapes
        @shapes ||= {}
      end

      # Resource the sprite loaded its battler from, which the box depends on, form and shiny included
      # @param pokemon [PFM::PokemonBattler, nil]
      # @return [Array(String, String, Integer), nil] filename, path inside Graphics, and hue
      def resource_key(pokemon)
        return nil unless pokemon

        hue = pokemon.shiny? ? 1 : 0
        arguments = [pokemon.id, pokemon.form, pokemon.female?, pokemon.shiny?, pokemon.egg?]
        return [PFM::Pokemon.back_filename(*arguments), RPG::Cache::Pokedex_PokeBack_Path[hue], hue] if pokemon.bank == 0

        return [PFM::Pokemon.front_filename(*arguments), RPG::Cache::Pokedex_PokeFront_Path[hue], hue]
      rescue StandardError
        return nil
      end

      # Read the alpha of the battler resource, an Image exposing the pixels a Texture keeps to itself
      # @param sprite [BattleUI::PokemonSprite]
      # @param key [Array(String, String, Integer)]
      # @return [BossAuraBodyShape, nil]
      def scan(sprite, key)
        filename, path, hue = key
        image = RPG::Cache.load_image({}, filename, path, file_data(sprite.bank, hue), LiteRGSS::Image)
        # A resource the engine could not read comes back as a placeholder of another size
        return nil unless image.width == sprite.bitmap.width && image.height == sprite.bitmap.height

        return read(image)
      rescue StandardError
        return nil
      ensure
        image.dispose if image.is_a?(LiteRGSS::Image) && !image.disposed?
      end

      # Virtual directory the engine reads the battlers from when the project ships them packed
      # @param bank [Integer]
      # @param hue [Integer]
      # @return [Yuki::VD, nil]
      def file_data(bank, hue)
        data = RPG::Cache.instance_variable_get(bank == 0 ? :@poke_back_data : :@poke_front_data)
        return data && data[hue]
      end

      # Smallest box holding every pixel that is not fully transparent, and the cells of the grid the
      # silhouette fills, both read in the same pass over the alpha
      # @param image [LiteRGSS::Image]
      # @return [BossAuraBodyShape, nil]
      def read(image)
        left = image.width
        top = image.height
        right = -1
        bottom = -1
        columns = (image.width / MASK_CELL_SIZE.to_f).ceil
        cells = {}
        image.height.times do |y|
          image.width.times do |x|
            next if image.get_pixel(x, y).alpha <= 0

            left = x if x < left
            right = x if x > right
            top = y if y < top
            bottom = y if y > bottom
            cells[((y / MASK_CELL_SIZE) * columns) + (x / MASK_CELL_SIZE)] = true
          end
        end
        return nil if right < 0

        return new(left, top, right - left + 1, bottom - top + 1, columns, cells.keys)
      end
    end

    # Create a new body shape
    # @param x [Integer] left edge of the opaque box, in bitmap pixels
    # @param y [Integer] top edge of the opaque box, in bitmap pixels
    # @param width [Integer] width of the opaque box, in bitmap pixels
    # @param height [Integer] height of the opaque box, in bitmap pixels
    # @param mask_columns [Integer, nil] number of cells one row of the mask holds
    # @param mask_cells [Array<Integer>, nil] cells the silhouette fills
    def initialize(x, y, width, height, mask_columns, mask_cells)
      @x = x
      @y = y
      @width = width
      @height = height
      @mask_columns = mask_columns
      @mask_cells = mask_cells
    end
  end
end
