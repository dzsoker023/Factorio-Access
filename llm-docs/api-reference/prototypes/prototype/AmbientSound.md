# AmbientSound

This prototype is used to make sound while playing the game. This includes the [base game's music](https://store.steampowered.com/app/436090/Factorio__Soundtrack/), composed by Daniel James Taylor and the [Space Age's music](https://store.steampowered.com/app/3311770/Factorio_Space_Age__Soundtrack/), composed by Petr Wajsar.

**Type name:** `ambient-sound`

## Examples

```
{
  type = "ambient-sound",
  name = "world-ambience-4",
  track_type = "interlude",
  sound =
  {
    filename = "__base__/sound/ambient/world-ambience-4.ogg",
    volume = 1.2
  }
}
```

## Properties

### type

Specification of the type of the prototype.

**Type:** `"ambient-sound"`

**Required:** Yes

### name

Unique textual identification of the prototype.

**Type:** `string`

**Required:** Yes

### title

Alternative name of the track. It doesn't need to be unique.

**Type:** `string`

**Optional:** Yes

### weight

Cannot be less than zero.

Cannot be defined if `track_type` is `"hero-track"` or `"script-track"`.

**Type:** `double`

**Optional:** Yes

**Default:** 1

### track_type

**Type:** `AmbientSoundType`

**Required:** Yes

### planets

The track can play only on specified planets.

If neither `planets` nor `surface_names` is given, the track plays on space platforms and in the space map.

Cannot be defined if `track_type` is `"script-track"`.

Cannot be defined when `play_on_all_surfaces` is true.

**Type:** Array[`SpaceLocationID`]

**Optional:** Yes

### surface_names

The track can play only on surfaces with specified names. It's enough if the specified name is a sub-string of the surface name.

If neither `planets` nor `surface_names` is given, the track plays on space platforms and in the space map.

Cannot be defined if `track_type` is `"hero-track"` or `"script-track"`.

Cannot be defined when `play_on_all_surfaces` is true.

**Type:** Array[`string`]

**Optional:** Yes

### play_on_all_surfaces

The track can play everywhere.

Cannot be defined if `track_type` is `"hero-track"` or `"script-track"`.

Cannot be true if `planets` or `surface_names` are defined.

**Type:** `boolean`

**Optional:** Yes

**Default:** False

### exclude_planets

The track cannot play on specified planets.

Can be used only if `play_on_all_surfaces` is true or `surface_names` are defined.

Cannot be used when `planets` are defined.

**Type:** Array[`SpaceLocationID`]

**Optional:** Yes

### exclude_surface_names

The track cannot play on surfaces with specified name. It's enough if the specified name is a sub-string of the surface name.

Can be used only if `play_on_all_surfaces` is true or `surface_names` are defined.

Cannot exclude a name given in `surface_names`.

**Type:** Array[`string`]

**Optional:** Yes

### sound

Static music track.

One of `sound` or `variable_sound` must be defined. Both cannot be defined together.

**Type:** `Sound`

**Optional:** Yes

### variable_sound

Variable music track.

One of `sound` or `variable_sound` must be defined. Both cannot be defined together.

**Type:** `VariableAmbientSoundVariableSound`

**Optional:** Yes

