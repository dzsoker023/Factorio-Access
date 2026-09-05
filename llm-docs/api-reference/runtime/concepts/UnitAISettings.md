# UnitAISettings

**Type:** Table

## Parameters

### allow_try_return_to_spawner

If enabled, units that have nothing else to do will attempt to return to a spawner.

**Type:** `boolean`

**Required:** Yes

### destroy_when_commands_fail

If enabled, units that repeatedly fail to succeed at commands will be destroyed.

**Type:** `boolean`

**Required:** Yes

### do_separation

If enabled, units will try to separate themselves from nearby friendly units.

**Type:** `boolean`

**Required:** Yes

### join_attacks

If enabled, the unit is permitted to join attack groups.

**Type:** `boolean`

**Required:** Yes

### path_resolution_modifier

Must be between -8 and 8.

**Type:** `int8`

**Required:** Yes

### size_in_group

The amount of slots in a unit group this unit takes up. For example, a unit with `groupingSize` of 2 will count as 2 normal-sized units when filling up a unit group. Must be greater than 0.

**Type:** `float`

**Required:** Yes

### strafe_settings

**Type:** `PrototypeStrafeSettings`

**Optional:** Yes

