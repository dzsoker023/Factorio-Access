# PlayMusicSpecification

**Type:** Table

## Parameters

### delay_duration

Number of ticks for the music transition delay.

**Type:** `uint32`

**Optional:** Yes

### dont_transition_from

Don't transition from this music track on surface change. Defaults to `false`.

**Type:** `boolean`

**Optional:** Yes

### fade_in_duration

Number of ticks for the music transition fade in.

**Type:** `uint32`

**Optional:** Yes

### fade_out_duration

Number of ticks for the music transition fade out.

**Type:** `uint32`

**Optional:** Yes

### name

The name of ambient sound to play.

**Type:** `string`

**Required:** Yes

### pause_duration

Number of ticks for the music transition pause.

**Type:** `uint32`

**Optional:** Yes

### skip_natural_pause

Skip the natural pause between music tracks. If there is currently a track playing, this has no effect. Defaults to `false`.

**Type:** `boolean`

**Optional:** Yes

