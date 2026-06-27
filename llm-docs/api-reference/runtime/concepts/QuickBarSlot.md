# QuickBarSlot

**Type:** Table

## Parameters

### filter

Only present and mandatory when `type` is `remote` or `filter`. Name must be present (cannot be a quality only item filter).

**Type:** `ItemFilter`

**Optional:** Yes

### item

Only present and mandatory when `type` is `item`.

**Type:** `LuaItem`

**Optional:** Yes

### record

Only present and mandatory when `type` is `record`.

**Type:** `LuaRecord`

**Optional:** Yes

### selection

Only present and mandatory  when `type` is `remote`. Entities must be spider-vehicles.

**Type:** Array[`LuaEntity`]

**Optional:** Yes

### type

Type of slot content

**Type:** `"record"` | `"remote"` | `"filter"` | `"item"`

**Required:** Yes

