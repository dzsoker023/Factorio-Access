# PipeToGroundPrototype

A [pipe to ground](https://wiki.factorio.com/Pipe_to_ground).

**Parent:** [EntityWithOwnerPrototype](EntityWithOwnerPrototype.md)
**Type name:** `pipe-to-ground`

## Properties

### fluid_box

**Type:** `FluidBox`

**Required:** Yes

### pictures

**Type:** `Sprite4Way`

**Optional:** Yes

### frozen_patch

**Type:** `Sprite4Way`

**Optional:** Yes

### visualization

**Type:** `Sprite4Way`

**Optional:** Yes

### disabled_visualization

**Type:** `Sprite4Way`

**Optional:** Yes

### circuit_connector

**Type:** (`CircuitConnectorDefinition`, `CircuitConnectorDefinition`, `CircuitConnectorDefinition`, `CircuitConnectorDefinition`)

**Optional:** Yes

### circuit_wire_max_distance

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

### default_fluid_temperature_signal

**Type:** `SignalIDConnector`

**Optional:** Yes

### draw_fluid_icon_override

Causes fluid icon to always be drawn, ignoring the usual pair requirement.

**Type:** `boolean`

**Optional:** Yes

**Default:** False

### show_fluid_visualization_when_in_cursor

When this is true, fluid pipelines will be visualized when this entity is held in the cursor.

**Type:** `boolean`

**Optional:** Yes

**Default:** True

**Overrides parent:** Yes

