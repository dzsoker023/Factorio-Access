# PipeConnectionDefinition

**Type:** Table

## Parameters

### alt_direction

Only provided if different from `direction`.

**Type:** `defines.direction`

**Optional:** Yes

### alt_position

Only provided if different from first position inside of `positions`.

**Type:** `MapPosition`

**Optional:** Yes

### connection_category

**Type:** Array[`string`]

**Required:** Yes

### connection_type

**Type:** `PipeConnectionType`

**Required:** Yes

### direction

**Type:** `defines.direction`

**Required:** Yes

### flow_direction

**Type:** `FluidFlowDirection`

**Required:** Yes

### hide_connection_info

**Type:** `boolean`

**Required:** Yes

### linked_connection_id

Only provided if `connection_type` is `"linked"`.

**Type:** `uint32`

**Optional:** Yes

### max_underground_distance

The maximum tile distance this underground connection can connect.

**Type:** `uint32`

**Optional:** Yes

### positions

The 4 cardinal direction connection points for this pipe.

**Type:** Array[`MapPosition`]

**Required:** Yes

