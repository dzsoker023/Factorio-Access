# CargoBayPrototype

**Parent:** [EntityWithOwnerPrototype](EntityWithOwnerPrototype.md)
**Type name:** `cargo-bay`
**Visibility:** space_age

## Properties

### graphics_set

**Type:** `CargoBayConnectableGraphicsSet`

**Optional:** Yes

### platform_graphics_set

A special variant which renders on space platforms. If not specified, the game will fall back to the regular graphics set.

**Type:** `CargoBayConnectableGraphicsSet`

**Optional:** Yes

### inventory_size_bonus

Cannot be 0.

**Type:** `ItemStackIndex`

**Required:** Yes

### has_direction

**Type:** `boolean`

**Optional:** Yes

**Default:** False

### allow_unloading

When set to `true`, inserters will be able to take items out of this cargo bay when it is connected to a cargo landing pad.

**Type:** `boolean`

**Optional:** Yes

**Default:** False

### use_unloading_distance_limit

Only relevant for cargo bays that have [allow_unloading](prototype:CargoBayPrototype::allow_unloading) set.

When `false` this cargo bay will allow item unloading regardless of distance as long as it is connected to a cargo landing pad.

When `true` this cargo bay will allow item unloading only when connected to a cargo landing pad and cargo bay is within distance limit set by [MaxCargoBayUnloadingDistanceModifier](prototype:MaxCargoBayUnloadingDistanceModifier) from that cargo landing pad.

**Type:** `boolean`

**Optional:** Yes

**Default:** False

### hatch_definitions

**Type:** Array[`CargoHatchDefinition`]

**Optional:** Yes

### build_grid_size

Has to be 2 for 2x2 grid.

**Type:** `2`

**Optional:** Yes

**Default:** 2

**Overrides parent:** Yes

