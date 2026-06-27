# PlatformBackdropHeroCloud

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### sprite_index

1, 2, 3 use cloud sprites 1, 2, 3 respectively. 0 will disable this cloud. Anything else is invalid.

**Type:** `uint8`

**Optional:** Yes

**Default:** 0

### size

Cloud size as a proportion of the total planet size, meaning `1` spans whole planet.

**Type:** `Vector`

**Optional:** Yes

**Default:** "`{0.5, 0.5}`"

### rotation_speed

**Type:** `float`

**Optional:** Yes

**Default:** 0.0

### rotate_with_planet

**Type:** `boolean`

**Optional:** Yes

**Default:** True

### starting_frame_offset

Random frame offset of the cloud animation if the graphic is an animation.

**Type:** `uint16`

**Optional:** Yes

**Default:** 0

### position_deviation

Random position offset of the cloud animation. Refreshed every loop.

**Type:** `Vector`

**Optional:** Yes

**Default:** "`{0, 0}`"

### rotation_deviation

**Type:** `float`

**Optional:** Yes

**Default:** 0.0

### projection_style

**Type:** `"none"` | `"front-only"` | `"front-and-back"` | `"front-and-back-inverted"`

**Optional:** Yes

**Default:** "front-only"

### positions

With each planet revolution, the cloud smoothly travels along this path by approximating the provided points. If only single position is provided, it remains stationary at that point.

**Type:** Array[`Vector`]

**Optional:** Yes

