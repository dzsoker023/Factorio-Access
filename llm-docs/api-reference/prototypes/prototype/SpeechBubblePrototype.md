# SpeechBubblePrototype

A speech bubble. It floats in the world and can display text.

**Parent:** [EntityPrototype](EntityPrototype.md)
**Type name:** `speech-bubble`

## Properties

### style

Needs a style of the type "speech_bubble_style", defined inside the gui styles.

**Type:** `string`

**Required:** Yes

### wrapper_flow_style

Needs a style of the type "flow_style", defined inside the gui styles.

**Type:** `string`

**Optional:** Yes

**Default:** "flow_style"

### y_offset

**Type:** `double`

**Optional:** Yes

**Default:** 0

### fade_in_out_ticks

**Type:** `uint32`

**Optional:** Yes

**Default:** 60

### selection_priority

The entity with the higher number is selectable before the entity with the lower number.

The value `0` will be treated the same as `nil`.

**Type:** `uint8`

**Optional:** Yes

**Default:** 20

**Overrides parent:** Yes

