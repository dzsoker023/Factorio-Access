# CharacterCorpsePrototype

The corpse of a [CharacterPrototype](prototype:CharacterPrototype).

**Parent:** [EntityPrototype](EntityPrototype.md)
**Type name:** `character-corpse`

## Properties

### time_to_live

In ticks. 0 for infinite.

**Type:** `uint32`

**Required:** Yes

### render_layer

**Type:** `RenderLayer`

**Optional:** Yes

**Default:** "object"

### pictures

Mandatory if `picture` is not defined.

**Type:** `AnimationVariations`

**Optional:** Yes

### picture

Only loaded, and mandatory if `pictures` is not defined.

**Type:** `Animation`

**Optional:** Yes

### armor_picture_mapping

A mapping of [ArmorPrototype](prototype:ArmorPrototype) name to a number. The number is the Animation that is associated with the armor, e.g. using `1` will associate the armor with the first Animation in the `pictures` table.

This mapping can be empty to have no sprite changes based on armor.

**Type:** Dictionary[`ItemID`, `int32`]

**Optional:** Yes

