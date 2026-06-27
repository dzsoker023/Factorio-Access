# ElevatedCurvedRailBPrototype

An elevated curved-B rail.

**Parent:** [CurvedRailBPrototype](CurvedRailBPrototype.md)
**Type name:** `elevated-curved-rail-b`

## Properties

### name

Unique textual identification of the prototype. May only contain alphanumeric characters, dashes and underscores. May not exceed a length of 200 characters.

Requires Space Age to create prototypes with name not starting with `dummy-`. Dummy prototypes cannot be built.

**Type:** `string`

**Required:** Yes

**Overrides parent:** Yes

### tall

When this is true, this entity prototype will be translucent and unselectable when "Hide tall entities" mode is active.

**Type:** `boolean`

**Optional:** Yes

**Default:** True

**Overrides parent:** Yes

### selection_priority

The entity with the higher number is selectable before the entity with the lower number.

The value `0` will be treated the same as `nil`.

**Type:** `uint8`

**Optional:** Yes

**Default:** 55

**Overrides parent:** Yes

