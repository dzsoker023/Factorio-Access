# FluidProductPrototype

A fluid product definition.

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### type

**Type:** `"fluid"`

**Required:** Yes

### name

The name of a [FluidPrototype](prototype:FluidPrototype).

**Type:** `FluidID`

**Required:** Yes

### amount

Can not be `< 0`.

**Type:** `FluidAmount`

**Optional:** Yes

### amount_min

Only loaded, and mandatory if `amount` is not defined.

Can not be `< 0`.

**Type:** `FluidAmount`

**Optional:** Yes

### amount_max

Only loaded, and mandatory if `amount` is not defined.

If set to a number that is less than `amount_min`, the game will use `amount_min` instead.

**Type:** `FluidAmount`

**Optional:** Yes

### ignored_by_stats

Amount that should not be included in the fluid production statistics, typically with a matching ingredient having the same amount set as [ignored_by_stats](prototype:FluidIngredientPrototype::ignored_by_stats).

If `ignored_by_stats` is larger than the amount crafted (for instance due to probability) it will instead show as consumed.

Products with `ignored_by_stats` defined will not be set as recipe through the circuit network when using the product's fluid-signal.

**Type:** `FluidAmount`

**Optional:** Yes

**Default:** 0

### ignored_by_productivity

Amount that should be deducted from any productivity induced bonus crafts.

This value can safely be set larger than the maximum expected craft amount, any excess is ignored.

This value is ignored when [allow_productivity](prototype:RecipePrototype::allow_productivity) is `false`.

**Type:** `FluidAmount`

**Optional:** Yes

**Default:** "Value of `ignored_by_stats`"

### temperature

The temperature of the fluid product.

**Type:** `float`

**Optional:** Yes

### fluidbox_index

Used to specify which [CraftingMachinePrototype::fluid_boxes](prototype:CraftingMachinePrototype::fluid_boxes) this product should use. It will use this one fluidbox. The index is 1-based and separate for input and output fluidboxes.

**Type:** `uint32`

**Optional:** Yes

**Default:** 0

### fluidbox_multiplier

Used to set crafting machine fluidbox volumes. Must be at least 1.

**Type:** `uint8`

**Optional:** Yes

**Default:** 3

### optional_fluidbox_indexes

Additional fluid boxes that will be also used by this fluid product. If a machine does not have a fluid box with that index, then this index will be silently skipped without making recipe uncraftable.

Only loaded if `fluidbox_index` is defined.

**Type:** Array[`uint32`]

**Optional:** Yes

