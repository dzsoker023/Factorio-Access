# SoundAccent

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### sound

**Type:** `Sound`

**Optional:** Yes

### frame

**Type:** `uint16`

**Optional:** Yes

**Default:** 0

### play_for_working_visualisation

Play the `sound` for a working visualisation of a given [WorkingVisualisation::name](prototype:WorkingVisualisation::name).

The name cannot be empty.

**Type:** `string`

**Optional:** Yes

### play_for_directions

The `sound` is played when the entity has one the specified direction.

**Type:** Array[`defines.direction`]

**Optional:** Yes

