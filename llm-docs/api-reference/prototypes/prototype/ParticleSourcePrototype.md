# ParticleSourcePrototype

Creates particles.

**Parent:** [EntityPrototype](EntityPrototype.md)
**Type name:** `particle-source`

## Properties

### time_to_live

**Type:** `float`

**Required:** Yes

### time_before_start

**Type:** `float`

**Required:** Yes

### height

**Type:** `float`

**Required:** Yes

### vertical_speed

**Type:** `float`

**Required:** Yes

### horizontal_speed

**Type:** `float`

**Required:** Yes

### particle

Mandatory if `smoke` is not defined.

**Type:** `ParticleID`

**Optional:** Yes

### smoke

Mandatory if `particle` is not defined.

**Type:** Array[`SmokeSource`]

**Optional:** Yes

### time_to_live_deviation

**Type:** `float`

**Optional:** Yes

**Default:** 0

### time_before_start_deviation

**Type:** `float`

**Optional:** Yes

**Default:** 0

### height_deviation

**Type:** `float`

**Optional:** Yes

**Default:** 0

### vertical_speed_deviation

**Type:** `float`

**Optional:** Yes

**Default:** 0

### horizontal_speed_deviation

**Type:** `float`

**Optional:** Yes

**Default:** 0

### selection_priority

The entity with the higher number is selectable before the entity with the lower number.

The value `0` will be treated the same as `nil`.

**Type:** `uint8`

**Optional:** Yes

**Default:** 20

**Overrides parent:** Yes

