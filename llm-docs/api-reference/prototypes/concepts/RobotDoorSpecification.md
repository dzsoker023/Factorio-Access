# RobotDoorSpecification

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### animation

Drawn when a robot brings/takes items from this entity.

**Type:** `Animation`

**Optional:** Yes

### location_offset

The offset from the center of this entity where a robot visually brings/takes items.

**Type:** `Vector`

**Optional:** Yes

### opened_duration

**Type:** `uint8`

**Optional:** Yes

**Default:** 0

### animation_sound

Played when a robot brings/takes items from this entity. Only loaded if `animation` is defined.

**Type:** `Sound`

**Optional:** Yes

