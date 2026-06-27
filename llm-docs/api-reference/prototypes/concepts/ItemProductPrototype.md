# ItemProductPrototype

An item product definition.

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### type

**Type:** `"item"`

**Required:** Yes

### name

The name of an [ItemPrototype](prototype:ItemPrototype).

**Type:** `ItemID`

**Required:** Yes

### amount

**Type:** `uint16`

**Optional:** Yes

### amount_min

Only loaded, and mandatory if `amount` is not defined.

**Type:** `uint16`

**Optional:** Yes

### amount_max

Only loaded, and mandatory if `amount` is not defined.

If set to a number that is less than `amount_min`, the game will use `amount_min` instead.

**Type:** `uint16`

**Optional:** Yes

### ignored_by_stats

Amount that should not be included in the item production statistics, typically with a matching ingredient having the same amount set as [ignored_by_stats](prototype:ItemIngredientPrototype::ignored_by_stats).

If `ignored_by_stats` is larger than the amount crafted (for instance due to probability) it will instead show as consumed.

Products with `ignored_by_stats` defined will not be set as recipe through the circuit network when using the product's item-signal.

**Type:** `uint16`

**Optional:** Yes

**Default:** 0

### ignored_by_productivity

Amount that should be deducted from any productivity induced bonus crafts.

This value can safely be set larger than the maximum expected craft amount, any excess is ignored.

This value is ignored when [allow_productivity](prototype:RecipePrototype::allow_productivity) is `false`.

**Type:** `uint16`

**Optional:** Yes

**Default:** "Value of `ignored_by_stats`"

### extra_count_fraction

Probability that a craft will yield one additional product. Also applies to bonus crafts caused by productivity.

**Type:** `float`

**Optional:** Yes

**Default:** 0

### percent_spoiled

Must be >= `0` and < `1`.

**Type:** `float`

**Optional:** Yes

**Default:** 0

### always_fresh

When set to true, the item produced will be produced fresh (using percent_spoiled) even when ingredients were spoiled.

Note: This may not work as expected outside of recipes (e.g. in mining drills).

**Type:** `boolean`

**Optional:** Yes

**Default:** False

### reset_freshness_on_craft

When set to true, if the recipe successfully finishes crafting without spoiling, the result is produced fresh (non-spoiled).

Note: This may not work as expected outside of recipes (e.g. in mining drills).

**Type:** `boolean`

**Optional:** Yes

**Default:** False

### quality_min

Lowest possible quality of item that will be given. If not provided but `quality_max` is given, it will be set to the lowest quality from a quality chain to which `quality_max` belongs. When set, if the recipe would produce items from a different quality chain (due to quality of the recipe or quality roll), `quality_min` will be used for the quality instead.

Note: If this is used outside of recipes (e.g. by mining drills), setting this to a custom quality chain will discard the quality roll.

**Type:** `QualityID`

**Optional:** Yes

### quality_max

Highest possible quality of item that will be given. If not provided but `quality_min` is given, it will be set to the highest quality from a quality chain to which `quality_min` belongs. Must belong to the same quality chain as `quality_min` and be equal or better, meaning later in the chain when following [QualityPrototype::next](prototype:QualityPrototype::next).

Note: If this is used outside of recipes (e.g. by mining drills), setting this to a custom quality chain will discard the quality roll.

**Type:** `QualityID`

**Optional:** Yes

### quality_change

Amount of quality levels up or down this product will be adjusted.

This is the difference between the quality of the recipe and the quality of the product. For a vanilla example, when epic is selected for recipe quality, a product with quality change `1` would be legendary quality, not epic.

Note: This may not work as expected outside of recipes (e.g. in mining drills).

**Type:** `int8`

**Optional:** Yes

**Default:** 0

### affected_by_quality

Whether quality roll affects quality of products given. If set to `false`, result of a quality roll will be ignored and an item of quality based on quality of selected recipe will be given.

Note: This may not work as expected outside of recipes (e.g. in mining drills).

**Type:** `boolean`

**Optional:** Yes

**Default:** True

