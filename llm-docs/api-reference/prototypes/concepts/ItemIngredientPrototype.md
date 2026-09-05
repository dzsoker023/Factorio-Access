# ItemIngredientPrototype

An item ingredient definition.

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### type

**Type:** `"item"`

**Required:** Yes

### name

**Type:** `ItemID`

**Required:** Yes

### amount

Cannot be `0`.

**Type:** `uint16`

**Required:** Yes

### ignored_by_stats

Amount that should not be included in the consumption statistics, typically with a matching product having the same amount set as [ignored_by_stats](prototype:ItemProductPrototype::ignored_by_stats).

**Type:** `uint16`

**Optional:** Yes

**Default:** 0

### quality_min

Lowest possible quality of ingredient that will be accepted. If not provided but `quality_max` is given, it will be set to the lowest quality from a quality chain to which `quality_max` belongs. When set, if the recipe would require ingredient from a different quality chain (due to quality of the recipe or quality roll), `quality_min` will be used for the quality instead.

**Type:** `QualityID`

**Optional:** Yes

### quality_max

Highest possible quality of ingredient that will be accepted. If not provided but `quality_min` is given, it will be set to the highest quality from a quality chain to which `quality_min` belongs. Must belong to the same quality chain as `quality_min` and be equal or better, meaning later in the chain when following [QualityPrototype::next](prototype:QualityPrototype::next).

**Type:** `QualityID`

**Optional:** Yes

### quality_change

Amount of quality levels up or down this ingredient will be adjusted.

This is the difference between the quality of the recipe and the quality of the ingredient. For a vanilla example, when legendary is selected for recipe quality, an ingredient with quality change `-1` would need to be epic quality, not legendary.

If `quality_min` is equal to `quality_max`, this is silently set to `0` as it does not make sense to define a quality jump when ingredient quality is fixed to one value for all qualities of recipe.

**Type:** `int8`

**Optional:** Yes

**Default:** 0

### spoil_weight

Controls how much spoil percent of this ingredient should influence spoil percent of spoilable products.

Must be in range `[0, 1]`.

**Type:** `float`

**Optional:** Yes

**Default:** 1

## Examples

```
```
{type="item", name="steel-plate", amount=8}
```
```

```
```
{type="item", name="iron-plate", amount=12}
```
```

