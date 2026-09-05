# UnitPrototype

Entity that moves around and attacks players, for example [biters and spitters](https://wiki.factorio.com/Enemies#Creatures).

**Parent:** [EntityWithOwnerPrototype](EntityWithOwnerPrototype.md)
**Type name:** `unit`

## Properties

### run_animation

**Type:** `RotatedAnimation`

**Required:** Yes

### steering

**Type:** `SteeringSettings`

**Optional:** Yes

### attack_parameters

Requires `animation` in attack_parameters. Requires `ammo_type` in attack_parameters.

**Type:** `AttackParameters`

**Required:** Yes

### warcry

A sound this unit makes when it sets out to attack.

**Type:** `Sound`

**Optional:** Yes

### movement_speed

Movement speed of this unit in the world, in tiles per tick. Must be equal to or greater than 0.

**Type:** `float`

**Required:** Yes

### distance_per_frame

How fast the `run_animation` frames are advanced. The animations are advanced animation_speed frames per `distance_per_frame` that the unit moves.

`frames_advanced = (distance_moved ÷ distance_per_frame) * animation_speed`

**Type:** `float`

**Required:** Yes

### distraction_cooldown

**Type:** `uint32`

**Required:** Yes

### vision_distance

Max is 100.

Note: Setting to 50 or above can lead to undocumented behavior of individual units creating groups on their own when attacking or being attacked.

**Type:** `double`

**Required:** Yes

### rotation_speed

**Type:** `float`

**Optional:** Yes

**Default:** 0.025

### dying_sound

The sound file to play this unit dies.

**Type:** `Sound`

**Optional:** Yes

### min_pursue_time

In ticks.

**Type:** `uint32`

**Optional:** Yes

**Default:** 600

### has_belt_immunity

If this unit is immune to movement by belts.

**Type:** `boolean`

**Optional:** Yes

**Default:** False

### max_pursue_distance

**Type:** `double`

**Optional:** Yes

**Default:** 50

### radar_range

In chunks. The radius of how many chunks this unit charts around itself.

**Type:** `uint32`

**Optional:** Yes

**Default:** 0

### ai_settings

**Type:** `UnitAISettings`

**Optional:** Yes

### move_while_shooting

**Type:** `boolean`

**Optional:** Yes

**Default:** False

### can_open_gates

**Type:** `boolean`

**Optional:** Yes

**Default:** False

### affected_by_tiles

Whether this unit is affected by tile [walking speed modifiers](prototype:TilePrototype::walking_speed_modifier).

**Type:** `boolean`

**Optional:** Yes

**Default:** False

### render_layer

**Type:** `RenderLayer`

**Optional:** Yes

**Default:** "object"

### light

**Type:** `LightDefinition`

**Optional:** Yes

### absorptions_to_join_attack

The pollution amount that has to be absorbed by the unit's [spawner](prototype:EnemySpawnerPrototype) before the unit will leave the spawner and attack the source of the pollution.

**Type:** Dictionary[`AirbornePollutantID`, `float`]

**Optional:** Yes

### spawning_time_modifier

Multiplier for the [EnemySpawnerPrototype::spawning_cooldown](prototype:EnemySpawnerPrototype::spawning_cooldown) after it spawns this unit.

**Type:** `double`

**Optional:** Yes

**Default:** 1

### buildable_entities

A list of entity prototypes that this unit can build when given the build base command.

If empty or not specified, the unit cannot build anything.

**Type:** Array[`EntityID`]

**Optional:** Yes

### walking_sound

**Type:** `Sound`

**Optional:** Yes

### alternative_attacking_frame_sequence

**Type:** `UnitAlternativeFrameSequence`

**Optional:** Yes

### running_sound_animation_positions

List of positions in the `run_animation` when the `walking_sound` is played.

Only loaded if `walking_sound` is defined.

**Type:** Array[`float`]

**Optional:** Yes

### is_military_target

Whether this prototype should be a high priority target for enemy forces. See [Military units and structures](https://wiki.factorio.com/Military_units_and_structures).

**Type:** `True`

**Optional:** Yes

**Default:** True

**Overrides parent:** Yes

### allow_run_time_change_of_is_military_target

If this is true, this entities `is_military_target property` can be changed runtime (on the entity, not on the prototype itself).

**Type:** `False`

**Optional:** Yes

**Default:** False

**Overrides parent:** Yes

