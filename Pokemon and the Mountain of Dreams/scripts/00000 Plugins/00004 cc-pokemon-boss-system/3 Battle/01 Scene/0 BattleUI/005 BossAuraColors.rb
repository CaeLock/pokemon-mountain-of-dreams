module BattleUI
  # Colors of the Boss aura resolved from the boss_aura property of a Pokemon, and the constants the
  # whole EBDX port shares.
  module BossAuraColors
    # Ratio of our screen to the one the source was drawn for, 320 / 512, its sheets being shared as is
    SCREEN_SCALE = 0.625
    # Color used when no type is given, the crimson of the EBDX Totem aura
    DEFAULT = [221, 68, 92]

    # Aura color of each type, second stop of the gradients the halo sheets were generated from
    BY_TYPE = {
      normal: [170, 165, 140],
      fire: [240, 110, 30],
      water: [50, 135, 240],
      grass: [70, 190, 55],
      electric: [245, 205, 35],
      ice: [100, 210, 230],
      fighting: [195, 55, 38],
      poison: [155, 60, 180],
      ground: [215, 185, 95],
      flying: [155, 135, 238],
      psychic: [238, 78, 130],
      bug: [168, 178, 35],
      rock: [190, 165, 60],
      ghost: [110, 80, 160],
      dragon: [108, 50, 232],
      dark: [110, 85, 68],
      steel: [180, 180, 205],
      fairy: [235, 140, 165]
    }

    module_function

    # Resolve the color of an aura
    # @param style [Symbol, Boolean, nil] value of the boss_aura property
    # @return [Array<Integer>] red, green and blue components
    def resolve(style)
      return DEFAULT unless style.is_a?(Symbol)

      return BY_TYPE[style] || DEFAULT
    end

    # Resolve the color of an aura as shader components
    # @param style [Symbol, Boolean, nil] value of the boss_aura property
    # @return [Array<Float>] red, green and blue components, from 0 to 1
    def resolve_floats(style)
      return resolve(style).map { |component| component / 255.0 }
    end
  end
end
