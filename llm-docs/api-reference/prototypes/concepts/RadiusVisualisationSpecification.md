# RadiusVisualisationSpecification

Sprite to be shown around the entity when it is selected/held in the cursor.

**Type:** `Struct`

## Properties

*These properties apply when the value is a struct/table.*

### sprite

The sprite to show.

This sprite is silently overwritten by prototypes with a custom radius picture: [AgriculturalTowerPrototype::radius_visualisation_picture](prototype:AgriculturalTowerPrototype::radius_visualisation_picture), [AsteroidCollectorPrototype::radius_visualisation_picture](prototype:AsteroidCollectorPrototype::radius_visualisation_picture), [BeaconPrototype::radius_visualisation_picture](prototype:BeaconPrototype::radius_visualisation_picture), [CargoLandingPadPrototype::radius_visualisation_picture](prototype:CargoLandingPadPrototype::radius_visualisation_picture), [ElectricPolePrototype::radius_visualisation_picture](prototype:ElectricPolePrototype::radius_visualisation_picture), [MiningDrillPrototype::radius_visualisation_picture](prototype:MiningDrillPrototype::radius_visualisation_picture).

**Type:** `Sprite`

**Optional:** Yes

### distance

Must be greater than or equal to 0.

This distance is silently overwritten by prototypes with a custom distance: [AgriculturalTowerPrototype::radius](prototype:AgriculturalTowerPrototype::radius), [AsteroidCollectorPrototype::collection_radius](prototype:AsteroidCollectorPrototype::collection_radius), [BeaconPrototype::supply_area_distance](prototype:BeaconPrototype::supply_area_distance), [ElectricPolePrototype::supply_area_distance](prototype:ElectricPolePrototype::supply_area_distance), [MiningDrillPrototype::resource_searching_radius](prototype:MiningDrillPrototype::resource_searching_radius).

**Type:** `double`

**Optional:** Yes

**Default:** 0

### offset

Offset of the sprite from the position of the entity. The offset is rotated by the entity's current direction.

This offset is silently overwritten by prototypes with a custom offset: [MiningDrillPrototype::resource_searching_offset](prototype:MiningDrillPrototype::resource_searching_offset).

**Type:** `Vector`

**Optional:** Yes

### draw_in_cursor

**Type:** `boolean`

**Optional:** Yes

**Default:** True

### draw_on_selection

**Type:** `boolean`

**Optional:** Yes

**Default:** True

### distance_quality_multiplier

Each value must be >= 0.01.

If value is not provided for a quality, then `1` will be used as a multiplier instead.

This does not affect the visualisation of prototypes with a custom distance specification because their distance automatically scales based on quality: agricultural tower (no quality scaling), [asteroid collector](prototype:QualityPrototype::asteroid_collector_collection_radius_bonus), [beacon](prototype:QualityPrototype::beacon_supply_area_distance_bonus), cargo landing pad (no quality scaling), [electric pole](prototype:QualityPrototype::electric_pole_supply_area_distance_bonus), and [mining drill](prototype:QualityPrototype::mining_drill_mining_radius_bonus).

**Type:** Dictionary[`QualityID`, `double`]

**Optional:** Yes

## Examples

```
```
radius_visualisation_specification =
{
  sprite =
  {
    filename = "__base__/graphics/entity/electric-mining-drill/electric-mining-drill-radius-visualization.png",
    size = 10
  },
  distance = 5,
  offset = {0, -5}
}
```
```

