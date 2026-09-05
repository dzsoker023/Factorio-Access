# PlantPrototype

**Parent:** [TreePrototype](TreePrototype.md)
**Type name:** `plant`
**Visibility:** space_age

## Properties

### growth_ticks

Must be positive.

**Type:** `MapTick`

**Required:** Yes

### harvest_emissions

The burst of pollution to emit when the plant is harvested.

**Type:** Dictionary[`AirbornePollutantID`, `double`]

**Optional:** Yes

### agricultural_tower_tint

**Type:** `RecipeTints`

**Optional:** Yes

### growth_variations

If defined, it can't be empty.

**Type:** Array[`TreeGrowth`]

**Optional:** Yes

### growth_mounds

Mound sprite drawn under growing trees which fades close to full growth. If defined, it can't be empty.

**Type:** Array[`Sprite`]

**Optional:** Yes

