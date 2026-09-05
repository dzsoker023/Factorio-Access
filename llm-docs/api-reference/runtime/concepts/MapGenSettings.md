# MapGenSettings

When reading MapGenSettings, all properties will always be present, but they can be omitted when writing.

**Type:** Table

## Parameters

### autoplace_controls

Indexed by autoplace control prototype name.

**Type:** Dictionary[`string`, `AutoplaceControl`]

**Optional:** Yes

### autoplace_settings

Each setting in this dictionary maps the string type to the settings for that type.

**Type:** Dictionary[`"entity"` | `"tile"` | `"decorative"`, `AutoplaceSettings`]

**Optional:** Yes

### cliff_settings

Map generation settings for entities of the type "cliff".

**Type:** `CliffPlacementSettings`

**Optional:** Yes

### default_enable_all_autoplace_controls

Whether undefined `autoplace_controls` should fall back to the default controls or not. Defaults to `true`.

**Type:** `boolean`

**Optional:** Yes

### height

Height in tiles. If `0`, the map has 'infinite' height, with the actual limitation being one million tiles in each direction from the center.

**Type:** `uint32`

**Optional:** Yes

### no_enemies_mode

Whether enemy creatures will not naturally spawn from spawners, map gen, or trigger effects.

**Type:** `boolean`

**Optional:** Yes

### peaceful_mode

Whether enemy creatures will not attack unless the player first attacks them.

**Type:** `boolean`

**Optional:** Yes

### property_expression_names

Overrides for tile property value generators.

**Type:** `PropertyExpressionNames`

**Optional:** Yes

### seed

) The random seed used to generated this map.

**Type:** `uint32`

**Optional:** Yes

### starting_area

Size of the starting area. Defaults to `1`.

**Type:** `MapGenSize`

**Optional:** Yes

### starting_points

Positions of the starting areas.

**Type:** Array[`MapPosition`]

**Optional:** Yes

### territory_settings

**Type:** `TerritorySettings`

**Optional:** Yes

### width

) Width in tiles. If `0`, the map has 'infinite' width, with the actual limitation being one million tiles in each direction from the center.

**Type:** `uint32`

**Optional:** Yes

## Examples

```
```
-- Assuming a NamedNoiseExpression with the name "my-alternate-grass1-probability" is defined...
local surface = game.player.surface
local mgs = surface.map_gen_settings
mgs.property_expression_names["tile:grass1:probability"] = "my-alternate-grass1-probability"
surface.map_gen_settings = mgs
-- ...would override the probability of grass1 being placed at any given point on the current surface.
```
```

```
```
-- To make there be no deep water on (newly generated chunks) a surface
local surface = game.player.surface
local mgs = surface.map_gen_settings
mgs.property_expression_names["tile:deepwater:probability"] = -1000
surface.map_gen_settings = mgs
-- This does not require a NamedNoiseExpression to be defined, since literal numbers (and strings naming literal
-- numbers, e.g. `"123"`) are understood to stand for constant value expressions.
```
```

