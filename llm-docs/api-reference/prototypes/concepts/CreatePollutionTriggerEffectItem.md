# CreatePollutionTriggerEffectItem

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### type

**Type:** `"create-pollution"`

**Required:** Yes

### amount

This may be negative which will reduce pollution when run.

**Type:** `double`

**Required:** Yes

### entity

If not defined, and use_entity_from_trigger is false, the pollution does not show in statistics.

**Type:** `EntityID`

**Optional:** Yes

### use_entity_from_trigger

If not set, and entity is not set, the pollution does not show in statistics.

**Type:** `boolean`

**Optional:** Yes

**Default:** True

