# RocketSiloRocketShadowPrototype

The shadow of the rocket inside the rocket silo.

**Parent:** [EntityPrototype](EntityPrototype.md)
**Type name:** `rocket-silo-rocket-shadow`

## Examples

```
{
  type = "rocket-silo-rocket-shadow",
  name = "rocket-silo-rocket-shadow",
  flags = {"not-on-map"},
  hidden = true,
  collision_mask = {layers={}, not_colliding_with_itself=true},
  collision_box = {{0, 0}, {10, 3.5}},
  selection_box = {{0, 0}, {0, 0}}
}
```

## Properties

### selection_priority

The entity with the higher number is selectable before the entity with the lower number.

The value `0` will be treated the same as `nil`.

**Type:** `uint8`

**Optional:** Yes

**Default:** 19

**Overrides parent:** Yes

