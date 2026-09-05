# HeatPipePrototype

A [heat pipe](https://wiki.factorio.com/Heat_pipe).

**Parent:** [EntityWithOwnerPrototype](EntityWithOwnerPrototype.md)
**Type name:** `heat-pipe`

## Properties

### connection_sprites

**Type:** `ConnectableEntityGraphics`

**Optional:** Yes

### heat_glow_sprites

**Type:** `ConnectableEntityGraphics`

**Optional:** Yes

### heat_buffer

**Type:** `HeatBuffer`

**Required:** Yes

### heating_radius

Must be >= 0.

**Type:** `float`

**Optional:** Yes

**Default:** 1

### selection_priority

The entity with the higher number is selectable before the entity with the lower number.

The value `0` will be treated the same as `nil`.

**Type:** `uint8`

**Optional:** Yes

**Default:** 45

**Overrides parent:** Yes

### circuit_wire_max_distance

The maximum circuit wire distance for this entity.

**Type:** `double`

**Optional:** Yes

**Default:** 0

### draw_copper_wires

**Type:** `boolean`

**Optional:** Yes

**Default:** True

### draw_circuit_wires

**Type:** `boolean`

**Optional:** Yes

**Default:** True

### circuit_connector

Set of 16 circuit connector definitions. They correspond to the following sprites in this exact order: [single](prototype:ConnectableEntityGraphics::single), [ending_up](prototype:ConnectableEntityGraphics::ending_up), [ending_right](prototype:ConnectableEntityGraphics::ending_right), [corner_right_up](prototype:ConnectableEntityGraphics::corner_right_up), [ending_down](prototype:ConnectableEntityGraphics::ending_down), [straight_vertical](prototype:ConnectableEntityGraphics::straight_vertical), [corner_right_down](prototype:ConnectableEntityGraphics::corner_right_down), [t_right](prototype:ConnectableEntityGraphics::t_right), [ending_left](prototype:ConnectableEntityGraphics::ending_left), [corner_left_up](prototype:ConnectableEntityGraphics::corner_left_up), [straight_horizontal](prototype:ConnectableEntityGraphics::straight_horizontal), [t_up](prototype:ConnectableEntityGraphics::t_up), [corner_left_down](prototype:ConnectableEntityGraphics::corner_left_down), [t_left](prototype:ConnectableEntityGraphics::t_left), [t_down](prototype:ConnectableEntityGraphics::t_down), [cross](prototype:ConnectableEntityGraphics::cross).

**Type:** Array[`CircuitConnectorDefinition`]

**Optional:** Yes

### default_temperature_signal

**Type:** `SignalIDConnector`

**Optional:** Yes

