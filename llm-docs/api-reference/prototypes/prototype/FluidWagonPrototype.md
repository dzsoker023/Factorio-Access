# FluidWagonPrototype

A [fluid wagon](https://wiki.factorio.com/Fluid_wagon).

**Parent:** [RollingStockPrototype](RollingStockPrototype.md)
**Type name:** `fluid-wagon`

## Properties

### capacity

**Type:** `FluidAmount`

**Required:** Yes

### quality_affects_capacity

**Type:** `boolean`

**Optional:** Yes

**Default:** False

### tank_count

Must be positive.

**Type:** `uint8`

**Optional:** Yes

**Default:** 3

### tank_spacing

Must be > 0.1.

**Type:** `float`

**Optional:** Yes

**Default:** 2.0

### base_valve_z_offset_projected_when_horizontal

Projected height of valves when the wagon is oriented east/west.

**Type:** `float`

**Optional:** Yes

**Default:** -1.375

### base_valve_z_offset_projected_when_vertical

Projected height of valves when the wagon is oriented north/south.

**Type:** `float`

**Optional:** Yes

**Default:** -0.65

### connection_category

Pumps are only allowed to connect to this fluid wagon if the pump's [fluid box connection](prototype:PipeConnectionDefinition) and this fluid wagon share a connection category. Pump may have different connection categories on the input and output side, connection categories will be taken from the connection that is facing towards fluid wagon.

**Type:** `string` | Array[`string`]

**Optional:** Yes

**Default:** "default"

### valve_to_valve_offset_when_horizontal

Projected offset between valves when the wagon is oriented east/west.

**Type:** `Vector`

**Optional:** Yes

**Default:** "`{2, 0}`"

### valve_to_valve_offset_when_vertical

Projected offset between valves when the wagon is oriented north/south.

**Type:** `Vector`

**Optional:** Yes

**Default:** "`{0, 1.775}`"

### base_valve_xy_offset_when_horizontal

Horizontal (xy) offset of the central valve from the wagon position when it is oriented east/west.

**Type:** `Vector`

**Optional:** Yes

**Default:** "`{0, 0}`"

### base_valve_xy_offset_when_vertical

Horizontal (xy) offset of the central valve from the wagon position when it is oriented north/south.

**Type:** `Vector`

**Optional:** Yes

**Default:** "`{0, 0}`"

