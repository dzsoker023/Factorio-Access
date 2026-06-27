# NeighbourConnectableConnection

**Type:** Table

## Parameters

### direction

**Type:** `defines.direction`

**Required:** Yes

### first

If multiple connections are connected to the same target, only one connection is marked as first and provides neighbour bonuses.

**Type:** `boolean`

**Optional:** Yes

### position

**Type:** `MapPosition`

**Required:** Yes

### target

Entity to which this connection is connected to, if any.

**Type:** `LuaEntity`

**Optional:** Yes

### target_real

Whether connected entity is real or ghost.

**Type:** `boolean`

**Optional:** Yes

