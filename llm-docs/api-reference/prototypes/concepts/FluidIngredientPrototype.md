# FluidIngredientPrototype

A fluid ingredient definition.

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

Can not be `<= 0`.

**Type:** `FluidAmount`

**Required:** Yes

### temperature

Sets the expected temperature of the fluid ingredient.

**Type:** `float`

**Optional:** Yes

### minimum_temperature

If `temperature` is not set, this sets the expected minimum temperature of the fluid ingredient.

**Type:** `float`

**Optional:** Yes

### maximum_temperature

If `temperature` is not set, this sets the expected maximum temperature of the fluid ingredient.

**Type:** `float`

**Optional:** Yes

### ignored_by_stats

Amount that should not be included in the consumption statistics, typically with a matching product having the same amount set as [ignored_by_stats](prototype:FluidProductPrototype::ignored_by_stats).

**Type:** `FluidAmount`

**Optional:** Yes

**Default:** 0

### fluidbox_index

Used to specify which [CraftingMachinePrototype::fluid_boxes](prototype:CraftingMachinePrototype::fluid_boxes) this ingredient should use. It will use this one fluidbox. The index is 1-based and separate for input and output fluidboxes.

**Type:** `uint32`

**Optional:** Yes

**Default:** 0

### optional_fluidbox_indexes

Additional fluid boxes that will be also used by this fluid ingredient. If a machine does not have a fluid box with that index, then this index will be silently skipped without making recipe uncraftable.

Only loaded if `fluidbox_index` is defined.

**Type:** Array[`uint32`]

**Optional:** Yes

### fluidbox_multiplier

Used to set crafting machine fluidbox volumes. Must be at least 1.

**Type:** `uint8`

**Optional:** Yes

**Default:** 3

## Examples

```
```
{type="fluid", name="water", amount=50}
```
```

